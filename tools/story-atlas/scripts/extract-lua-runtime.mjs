#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import luaparse from "luaparse";

const EXTRACTOR_VERSION = 1;
const TRACKED_ROOTS = new Set(["R", "Runtime", "State"]);

function decodeLuaString(node) {
  if (!node || node.type !== "StringLiteral") return null;
  const raw = node.raw || "";
  if (raw.startsWith('"') && raw.endsWith('"')) {
    try {
      return JSON.parse(raw);
    } catch {
      return raw.slice(1, -1);
    }
  }
  if (raw.startsWith("'") && raw.endsWith("'")) {
    return raw.slice(1, -1)
      .replace(/\\'/g, "'")
      .replace(/\\\\/g, "\\");
  }
  return typeof node.value === "string" ? node.value : null;
}

function literalValue(node) {
  if (!node) return { known: false, value: null };
  if (node.type === "StringLiteral") return { known: true, value: decodeLuaString(node) };
  if (node.type === "NumericLiteral" || node.type === "BooleanLiteral") {
    return { known: true, value: node.value };
  }
  if (node.type === "NilLiteral") return { known: true, value: null };
  return { known: false, value: null };
}

function memberPath(node) {
  if (!node) return null;
  if (node.type === "Identifier") return node.name;
  if (node.type === "MemberExpression") {
    const base = memberPath(node.base);
    const key = node.identifier?.name;
    return base && key ? `${base}.${key}` : null;
  }
  if (node.type === "IndexExpression") {
    const base = memberPath(node.base);
    const key = literalValue(node.index);
    return base && key.known && (typeof key.value === "string" || typeof key.value === "number")
      ? `${base}.${key.value}`
      : null;
  }
  return null;
}

function normalizeStatePath(value) {
  return value === "R" ? "Runtime" : value?.startsWith("R.") ? `Runtime${value.slice(1)}` : value;
}

function isScenePath(value) {
  const normalized = normalizeStatePath(value);
  return normalized === "Runtime.scene";
}

function renderExpression(node) {
  if (!node) return "";
  const pathValue = memberPath(node);
  if (pathValue) return pathValue;
  const literal = literalValue(node);
  if (literal.known) return JSON.stringify(literal.value);
  if (node.type === "UnaryExpression") return `${node.operator} ${renderExpression(node.argument)}`;
  if (node.type === "BinaryExpression" || node.type === "LogicalExpression") {
    return `${renderExpression(node.left)} ${node.operator} ${renderExpression(node.right)}`;
  }
  if (node.type === "CallExpression") {
    return `${renderExpression(node.base)}(${(node.arguments || []).map(renderExpression).join(", ")})`;
  }
  if (node.type === "TableConstructorExpression") return "{…}";
  return node.type;
}

function evidence(filePath, node, functionName, kind) {
  return {
    path: filePath,
    line: node.loc?.start?.line || 1,
    column: node.loc?.start?.column || 0,
    functionName,
    kind,
  };
}

function uniqueSorted(values) {
  return [...new Set(values)].sort();
}

function conditionFacts(node, allScenes, channel) {
  const equals = new Set();
  const excludes = new Set();
  const events = new Set();

  function visit(value) {
    if (!value || typeof value !== "object") return;
    if (value.type === "BinaryExpression" && ["==", "~="].includes(value.operator)) {
      const leftPath = memberPath(value.left);
      const rightPath = memberPath(value.right);
      const leftLiteral = literalValue(value.left);
      const rightLiteral = literalValue(value.right);
      const sceneLiteral = isScenePath(leftPath) && rightLiteral.known
        ? rightLiteral.value
        : isScenePath(rightPath) && leftLiteral.known
          ? leftLiteral.value
          : null;
      if (typeof sceneLiteral === "string") {
        (value.operator === "==" ? equals : excludes).add(sceneLiteral);
      }

      const eventPath = leftPath === "key" || leftPath === "button"
        ? leftPath
        : rightPath === "key" || rightPath === "button"
          ? rightPath
          : null;
      const eventLiteral = eventPath === leftPath ? rightLiteral : leftLiteral;
      if (eventPath && value.operator === "==" && typeof eventLiteral.value === "string") {
        events.add(`${channel || eventPath}:${eventLiteral.value}`);
      }
    }
    for (const [key, child] of Object.entries(value)) {
      if (key === "loc" || key === "range" || key === "raw") continue;
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === "object") visit(child);
    }
  }

  visit(node);
  let scenes = [...equals];
  if (!scenes.length && excludes.size) {
    scenes = allScenes.filter((scene) => !excludes.has(scene));
  }
  return {
    scenes: uniqueSorted(scenes),
    events: uniqueSorted(events),
    guards: node ? [renderExpression(node)] : [],
  };
}

function mergeContext(parent, child) {
  const parentScenes = parent.scenes || [];
  const childScenes = child.scenes || [];
  let scenes = childScenes.length ? childScenes : parentScenes;
  if (parentScenes.length && childScenes.length) {
    scenes = parentScenes.filter((scene) => childScenes.includes(scene));
  }
  return {
    scenes: uniqueSorted(scenes),
    events: uniqueSorted([...(parent.events || []), ...(child.events || [])]),
    guards: uniqueSorted([...(parent.guards || []), ...(child.guards || [])]),
  };
}

function collectCalls(node, output) {
  if (!node || typeof node !== "object") return;
  if (node.type === "CallExpression") output.push(node);
  for (const [key, child] of Object.entries(node)) {
    if (key === "loc" || key === "range" || key === "raw") continue;
    if (Array.isArray(child)) child.forEach((item) => collectCalls(item, output));
    else if (child && typeof child === "object") collectCalls(child, output);
  }
}

function flattenTableWrites(prefix, table, filePath, functionName, output) {
  for (const field of table.fields || []) {
    let key = null;
    if (field.type === "TableKeyString") key = field.key?.name;
    if (field.type === "TableKey") {
      const literal = literalValue(field.key);
      if (literal.known) key = String(literal.value);
    }
    if (!key) continue;
    const target = `${prefix}.${key}`;
    const literal = literalValue(field.value);
    output.push({
      path: normalizeStatePath(target),
      valueKnown: literal.known,
      value: literal.known ? literal.value : renderExpression(field.value),
      evidence: evidence(filePath, field, functionName, "state-initializer"),
    });
    if (field.value?.type === "TableConstructorExpression") {
      flattenTableWrites(target, field.value, filePath, functionName, output);
    }
  }
}

function functionChannel(name) {
  if (name === "Input.onKey") return "keyboard";
  if (name === "Input.onGamepad") return "gamepad";
  if (["Input.onBottomTouch", "Input.onTouch", "Input.onMouse"].includes(name)) return "touch";
  return null;
}

function analyzeFunction(functionRecord, allScenes) {
  const actions = [];
  const stateWrites = [];
  const sceneReads = [];
  const channel = functionChannel(functionRecord.name);

  function addCalls(node, context) {
    const calls = [];
    collectCalls(node, calls);
    for (const call of calls) {
      const target = memberPath(call.base);
      if (!target) {
        actions.push({
          kind: "unresolved-call",
          target: renderExpression(call.base),
          ...context,
          evidence: evidence(functionRecord.path, call, functionRecord.name, "dynamic-call"),
        });
        continue;
      }
      actions.push({
        kind: "call",
        target,
        ...context,
        evidence: evidence(functionRecord.path, call, functionRecord.name, "call"),
      });
    }
  }

  function handleAssignment(statement, context, initial = false) {
    statement.variables.forEach((variable, index) => {
      const rawPath = memberPath(variable);
      const valueNode = statement.init[index] || statement.init[statement.init.length - 1];
      if (!rawPath) return;
      const root = rawPath.split(".")[0];
      if (!TRACKED_ROOTS.has(root)) return;
      const normalized = normalizeStatePath(rawPath);
      const literal = literalValue(valueNode);
      const write = {
        path: normalized,
        valueKnown: literal.known,
        value: literal.known ? literal.value : renderExpression(valueNode),
        evidence: evidence(
          functionRecord.path,
          variable,
          functionRecord.name,
          initial ? "state-initializer" : "state-write",
        ),
      };
      stateWrites.push(write);
      if (valueNode?.type === "TableConstructorExpression") {
        flattenTableWrites(rawPath, valueNode, functionRecord.path, functionRecord.name, stateWrites);
      }
      if (isScenePath(rawPath)) {
        if (literal.known && typeof literal.value === "string") {
          actions.push({
            kind: "scene-write",
            target: literal.value,
            ...context,
            evidence: evidence(functionRecord.path, variable, functionRecord.name, "scene-write"),
          });
        } else {
          actions.push({
            kind: "unresolved-scene-write",
            target: renderExpression(valueNode),
            ...context,
            evidence: evidence(functionRecord.path, variable, functionRecord.name, "dynamic-scene-write"),
          });
        }
      }
    });
    statement.init.forEach((node) => addCalls(node, context));
  }

  function visitStatements(statements, context) {
    for (const statement of statements || []) {
      if (statement.type === "FunctionDeclaration") continue;
      if (statement.type === "IfStatement") {
        for (const clause of statement.clauses || []) {
          const facts = clause.condition
            ? conditionFacts(clause.condition, allScenes, channel)
            : { scenes: [], events: [], guards: [] };
          facts.scenes.forEach((scene) => {
            sceneReads.push({
              scene,
              evidence: evidence(functionRecord.path, clause.condition, functionRecord.name, "scene-guard"),
            });
          });
          visitStatements(clause.body, mergeContext(context, facts));
        }
        continue;
      }
      if (statement.type === "AssignmentStatement") {
        handleAssignment(statement, context);
        continue;
      }
      if (statement.type === "LocalStatement") {
        statement.variables.forEach((variable, index) => {
          const rawPath = memberPath(variable);
          const valueNode = statement.init[index];
          if (rawPath && TRACKED_ROOTS.has(rawPath) && valueNode?.type === "TableConstructorExpression") {
            flattenTableWrites(rawPath, valueNode, functionRecord.path, functionRecord.name, stateWrites);
          }
        });
        statement.init.forEach((node) => addCalls(node, context));
        continue;
      }
      if (["WhileStatement", "RepeatStatement"].includes(statement.type)) {
        const facts = conditionFacts(statement.condition, allScenes, channel);
        visitStatements(statement.body, mergeContext(context, facts));
        addCalls(statement.condition, context);
        continue;
      }
      if (["ForNumericStatement", "ForGenericStatement", "DoStatement"].includes(statement.type)) {
        visitStatements(statement.body, context);
        continue;
      }
      addCalls(statement, context);
    }
  }

  visitStatements(functionRecord.body, { scenes: [], events: channel ? [channel] : [], guards: [] });
  return { ...functionRecord, actions, stateWrites, sceneReads };
}

function collectFunctionDeclarations(ast, filePath) {
  const functions = [];
  const topLevel = {
    id: `${filePath}::<module>`,
    name: `<module:${filePath}>`,
    path: filePath,
    body: ast.body,
    evidence: { path: filePath, line: 1, column: 0, functionName: "<module>", kind: "module" },
  };
  functions.push(topLevel);

  function visit(node) {
    if (!node || typeof node !== "object") return;
    if (node.type === "FunctionDeclaration") {
      const name = memberPath(node.identifier) || `<anonymous@${node.loc?.start?.line || 1}>`;
      functions.push({
        id: `${filePath}::${name}`,
        name,
        path: filePath,
        body: node.body,
        evidence: evidence(filePath, node, name, "function"),
      });
    }
    for (const [key, child] of Object.entries(node)) {
      if (key === "loc" || key === "range" || key === "raw") continue;
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === "object") visit(child);
    }
  }
  ast.body.forEach(visit);
  return functions;
}

function collectSceneLiterals(ast) {
  const scenes = new Set();
  function visit(node) {
    if (!node || typeof node !== "object") return;
    if (node.type === "AssignmentStatement") {
      node.variables.forEach((variable, index) => {
        if (!isScenePath(memberPath(variable))) return;
        const literal = literalValue(node.init[index] || node.init[node.init.length - 1]);
        if (literal.known && typeof literal.value === "string") scenes.add(literal.value);
      });
    }
    if (node.type === "BinaryExpression" && ["==", "~="].includes(node.operator)) {
      const left = memberPath(node.left);
      const right = memberPath(node.right);
      const opposite = isScenePath(left) ? literalValue(node.right) : isScenePath(right) ? literalValue(node.left) : null;
      if (opposite?.known && typeof opposite.value === "string") scenes.add(opposite.value);
    }
    for (const [key, child] of Object.entries(node)) {
      if (key === "loc" || key === "range" || key === "raw") continue;
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === "object") visit(child);
    }
  }
  visit(ast);
  return scenes;
}

function contextKey(context) {
  return `${context.source}|${uniqueSorted(context.events || []).join(",")}`;
}

function deriveTransitions(functions, allScenes) {
  const byName = new Map();
  for (const fn of functions) {
    if (!byName.has(fn.name)) byName.set(fn.name, fn);
  }
  const contexts = new Map(functions.map((fn) => [fn.name, new Map()]));
  const transitions = [];
  const unresolved = [];

  function addContext(functionName, context) {
    const bucket = contexts.get(functionName);
    if (!bucket) return false;
    const key = contextKey(context);
    if (bucket.has(key)) return false;
    bucket.set(key, context);
    return true;
  }

  for (const fn of functions) {
    const channel = functionChannel(fn.name);
    if (channel) {
      addContext(fn.name, {
        source: null,
        events: [channel],
        guards: [],
        chain: [fn.name],
        evidence: [fn.evidence],
      });
    }
  }

  let changed = true;
  let rounds = 0;
  while (changed && rounds < 50) {
    changed = false;
    rounds += 1;
    for (const fn of functions) {
      const inherited = [...(contexts.get(fn.name)?.values() || [])];
      for (const action of fn.actions) {
        let actionContexts = inherited;
        if (action.scenes?.length) {
          const narrowed = inherited.flatMap((context) =>
            context.source === null
              ? action.scenes.map((source) => ({ ...context, source }))
              : action.scenes.includes(context.source)
                ? [context]
                : [],
          );
          actionContexts = narrowed.length
            ? narrowed
            : action.scenes.map((source) => ({
              source,
              events: [],
              guards: [],
              chain: [fn.name],
              evidence: [],
            }));
        }
        actionContexts = actionContexts.map((context) => ({
          ...context,
          events: uniqueSorted([...(context.events || []), ...(action.events || [])]),
          guards: uniqueSorted([...(context.guards || []), ...(action.guards || [])]),
          evidence: [...(context.evidence || []), action.evidence],
        }));

        if (action.kind === "call" && byName.has(action.target)) {
          for (const context of actionContexts) {
            if (addContext(action.target, {
              ...context,
              chain: [...context.chain, action.target],
            })) changed = true;
          }
        } else if (action.kind === "scene-write") {
          for (const context of actionContexts) {
            if (context.source === null) {
              unresolved.push({
                kind: "unknown-source-transition",
                expression: `? -> ${action.target}`,
                evidence: action.evidence,
              });
              continue;
            }
            if (context.source === action.target) continue;
            transitions.push({
              from: context.source,
              to: action.target,
              events: context.events,
              guards: context.guards,
              callChain: context.chain,
              evidence: context.evidence,
            });
          }
        } else if (action.kind.startsWith("unresolved")) {
          unresolved.push({
            kind: action.kind,
            expression: action.target,
            evidence: action.evidence,
          });
        }
      }
    }
  }

  const merged = new Map();
  for (const transition of transitions) {
    const key = `${transition.from}->${transition.to}`;
    const existing = merged.get(key);
    if (!existing) {
      merged.set(key, {
        ...transition,
        events: new Set(transition.events),
        guards: new Set(transition.guards),
        evidence: new Map(transition.evidence.map((item) => [`${item.path}:${item.line}:${item.kind}`, item])),
      });
      continue;
    }
    transition.events.forEach((item) => existing.events.add(item));
    transition.guards.forEach((item) => existing.guards.add(item));
    transition.evidence.forEach((item) => existing.evidence.set(`${item.path}:${item.line}:${item.kind}`, item));
    if (transition.callChain.length < existing.callChain.length) existing.callChain = transition.callChain;
  }

  return {
    transitions: [...merged.values()]
      .sort((a, b) => `${a.from}->${a.to}`.localeCompare(`${b.from}->${b.to}`))
      .map((item, index) => ({
        id: `LUA-TRANS-${String(index + 1).padStart(4, "0")}`,
        from: item.from,
        to: item.to,
        events: uniqueSorted([...item.events]),
        guards: uniqueSorted([...item.guards]),
        callChain: item.callChain,
        evidence: [...item.evidence.values()].sort((a, b) =>
          `${a.path}:${a.line}`.localeCompare(`${b.path}:${b.line}`),
        ),
      })),
    unresolved: [...new Map(unresolved.map((item) => [
      `${item.kind}:${item.evidence.path}:${item.evidence.line}:${item.expression}`,
      item,
    ])).values()],
    propagationRounds: rounds,
  };
}

function listLuaFiles(gameRoot) {
  const files = [];
  function visit(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const fullPath = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(fullPath);
      else if (entry.isFile() && entry.name.endsWith(".lua")) files.push(fullPath);
    }
  }
  visit(gameRoot);
  return files.sort();
}

export function extractRuntimeGraph(rootPath) {
  const gameRoot = path.join(rootPath, "game");
  const files = listLuaFiles(gameRoot);
  const parsed = [];
  const parseErrors = [];
  for (const file of files) {
    const repoPath = path.relative(rootPath, file).split(path.sep).join("/");
    try {
      const ast = luaparse.parse(fs.readFileSync(file, "utf8"), {
        comments: false,
        locations: true,
        luaVersion: "5.3",
      });
      parsed.push({ path: repoPath, ast });
    } catch (error) {
      parseErrors.push({ path: repoPath, message: String(error.message || error) });
    }
  }

  const sceneSet = new Set();
  parsed.forEach(({ ast }) => collectSceneLiterals(ast).forEach((scene) => sceneSet.add(scene)));
  const allScenes = [...sceneSet].sort();

  const rawFunctions = parsed.flatMap(({ ast, path: filePath }) =>
    collectFunctionDeclarations(ast, filePath),
  );
  const functions = rawFunctions.map((fn) => analyzeFunction(fn, allScenes));
  const derived = deriveTransitions(functions, allScenes);

  const stateByPath = new Map();
  for (const fn of functions) {
    for (const write of fn.stateWrites) {
      const item = stateByPath.get(write.path) || { path: write.path, initialValues: [], writes: [] };
      if (write.evidence.kind === "state-initializer" && write.valueKnown) {
        if (!item.initialValues.some((value) => JSON.stringify(value) === JSON.stringify(write.value))) {
          item.initialValues.push(write.value);
        }
      } else {
        item.writes.push(write);
      }
      stateByPath.set(write.path, item);
    }
  }

  const sceneRows = allScenes.map((scene) => ({
    id: scene,
    reads: functions.flatMap((fn) => fn.sceneReads.filter((item) => item.scene === scene)),
    writes: functions.flatMap((fn) => fn.actions
      .filter((item) => item.kind === "scene-write" && item.target === scene)
      .map((item) => item.evidence)),
  }));

  return {
    meta: {
      schemaVersion: 1,
      extractorVersion: EXTRACTOR_VERSION,
      parser: "luaparse",
      generatedAt: new Date().toISOString(),
      fileCount: files.length,
      propagationRounds: derived.propagationRounds,
    },
    scenes: sceneRows,
    stateVariables: [...stateByPath.values()].sort((a, b) => a.path.localeCompare(b.path)),
    functions: functions.map((fn) => ({
      id: fn.id,
      name: fn.name,
      path: fn.path,
      evidence: fn.evidence,
      calls: fn.actions.filter((item) => item.kind === "call").map((item) => ({
        target: item.target,
        scenes: item.scenes,
        events: item.events,
        guards: item.guards,
        evidence: item.evidence,
      })),
      sceneWrites: fn.actions.filter((item) => item.kind === "scene-write").map((item) => ({
        target: item.target,
        scenes: item.scenes,
        events: item.events,
        guards: item.guards,
        evidence: item.evidence,
      })),
      stateWrites: fn.stateWrites,
    })),
    transitions: derived.transitions,
    unresolved: [...parseErrors.map((item) => ({ kind: "parse-error", ...item })), ...derived.unresolved],
  };
}

export function writeRuntimeGraph(rootPath, outputPath) {
  const graph = extractRuntimeGraph(rootPath);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(graph, null, 2)}\n`, "utf8");
  return graph;
}

const isMain = process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;
if (isMain) {
  const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
  const root = path.resolve(scriptDirectory, "../../..");
  const output = path.join(root, "tools/story-atlas/data/lua-runtime-graph.json");
  const graph = writeRuntimeGraph(root, output);
  console.log(
    `Lua runtime graph: ${graph.scenes.length} scenes / ${graph.stateVariables.length} states / ` +
    `${graph.transitions.length} transitions / ${graph.meta.fileCount} files`,
  );
  if (graph.unresolved.some((item) => item.kind === "parse-error")) process.exitCode = 1;
}
