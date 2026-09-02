import { spawn, spawnSync } from "node:child_process";
import { createReadStream, readFileSync, renameSync, statSync, writeFileSync } from "node:fs";
import { extname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig, type Plugin } from "vite";
import { createPathPolicy } from "./server/pathPolicy.ts";

const repoRoot = fileURLToPath(new URL("../..", import.meta.url));
const policy = createPathPolicy(repoRoot);
const reviewFile = resolve(repoRoot, "tools/story-atlas/data/review-status.json");
const customViewsFile = resolve(repoRoot, "tools/story-atlas/data/custom-views.json");

const VIEW_OBJECT_TYPES = new Set([
  "ONT-101", "ONT-102", "ONT-103", "ONT-104", "ONT-105", "ONT-106", "ONT-107",
  "ONT-201", "ONT-202", "ONT-203",
  "ONT-301", "ONT-302", "ONT-303", "ONT-304", "ONT-305", "ONT-306",
  "ONT-401", "ONT-501"
]);
const VIEW_RELATION_TYPES = new Set([
  "ONT-601", "ONT-602", "ONT-603", "ONT-604", "ONT-605", "ONT-606", "ONT-607"
]);
const VIEW_OPERATORS = new Set(["eq", "neq", "contains", "in", "exists", "gt", "lt"]);
const VIEW_DISPLAY_MODES = new Set(["graph", "workflow", "grid", "table"]);
const NODE_FIELD_RENDERERS = new Set(["text", "image", "identifier", "badge"]);
const DEFAULT_NODE_FIELDS = [
  { id: "field-id", title: "编号", renderer: "identifier", source: { kind: "field", field: "id" } },
  { id: "field-label", title: "label", renderer: "text", source: { kind: "field", field: "label" } },
  { id: "field-type", title: "类型", renderer: "badge", source: { kind: "field", field: "ontologyTypeId" } }
];

const MIME: Record<string, string> = {
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".mp3": "audio/mpeg",
  ".wav": "audio/wav",
  ".ttf": "font/ttf",
  ".txt": "text/plain; charset=utf-8",
  ".lua": "text/plain; charset=utf-8",
  ".py": "text/plain; charset=utf-8",
  ".md": "text/markdown; charset=utf-8"
};

function sendJson(response: import("node:http").ServerResponse, status: number, data: unknown) {
  response.statusCode = status;
  response.setHeader("Content-Type", "application/json; charset=utf-8");
  response.end(JSON.stringify(data));
}

async function readJson(request: import("node:http").IncomingMessage) {
  let body = "";
  for await (const chunk of request) {
    body += chunk;
    if (body.length > 131_072) throw new Error("请求过大");
  }
  return JSON.parse(body || "{}") as {
    path?: string;
    status?: string;
    note?: string;
    line?: number;
    oldText?: string;
    newText?: string;
    views?: unknown;
  };
}

function validateCustomViews(value: unknown) {
  if (!Array.isArray(value)) throw new Error("views 必须是数组");
  if (value.length > 24) throw new Error("自定义视图最多 24 个");
  const ids = new Set<string>();
  return value.map((raw) => {
    if (!raw || typeof raw !== "object") throw new Error("视图配置无效");
    const item = raw as Record<string, unknown>;
    const id = String(item.id || "");
    const name = String(item.name || "").trim();
    if (!/^VIEW-[A-Z0-9-]{4,40}$/.test(id)) throw new Error(`视图编号无效：${id}`);
    if (ids.has(id)) throw new Error(`视图编号重复：${id}`);
    ids.add(id);
    if (!name || name.length > 40) throw new Error("视图名称长度必须为 1–40 字");
    const objectTypeIds = Array.isArray(item.objectTypeIds) ? item.objectTypeIds.map(String) : [];
    const relationTypeIds = Array.isArray(item.relationTypeIds) ? item.relationTypeIds.map(String) : [];
    if (!objectTypeIds.length || objectTypeIds.some((type) => !VIEW_OBJECT_TYPES.has(type))) {
      throw new Error(`${name} 包含无效对象类型`);
    }
    if (relationTypeIds.some((type) => !VIEW_RELATION_TYPES.has(type))) {
      throw new Error(`${name} 包含无效关系类型`);
    }
    const conditionMode = item.conditionMode === "any" ? "any" : "all";
    const conditions = Array.isArray(item.conditions) ? item.conditions : [];
    if (conditions.length > 12) throw new Error(`${name} 的条件不能超过 12 条`);
    const normalizedConditions = conditions.map((rawCondition) => {
      if (!rawCondition || typeof rawCondition !== "object") throw new Error(`${name} 包含无效条件`);
      const condition = rawCondition as Record<string, unknown>;
      const field = String(condition.field || "");
      const operator = String(condition.operator || "");
      if (!/^(id|label|source|entityKind|attributes\.[A-Za-z][A-Za-z0-9]*)$/.test(field)) {
        throw new Error(`${name} 包含无效筛选字段`);
      }
      if (!VIEW_OPERATORS.has(operator)) throw new Error(`${name} 包含无效操作符`);
      return { field, operator, value: String(condition.value ?? "").slice(0, 200) };
    });
    const displayMode = String(item.displayMode || "");
    if (!VIEW_DISPLAY_MODES.has(displayMode)) throw new Error(`${name} 的展示方式无效`);
    const rawNodeFields = Array.isArray(item.nodeFields) ? item.nodeFields : DEFAULT_NODE_FIELDS;
    if (!rawNodeFields.length || rawNodeFields.length > 10) throw new Error(`${name} 的节点字段必须为 1–10 个`);
    const nodeFields = rawNodeFields.map((rawField, fieldIndex) => {
      if (!rawField || typeof rawField !== "object") throw new Error(`${name} 包含无效节点字段`);
      const field = rawField as Record<string, unknown>;
      const fieldId = String(field.id || `field-${fieldIndex + 1}`);
      const title = String(field.title || "").trim().slice(0, 30);
      const renderer = String(field.renderer || "");
      if (!title || !NODE_FIELD_RENDERERS.has(renderer)) throw new Error(`${name} 的节点字段标题或渲染方式无效`);
      const rawSource = field.source;
      if (!rawSource || typeof rawSource !== "object") throw new Error(`${name} 的节点字段缺少数据来源`);
      const source = rawSource as Record<string, unknown>;
      if (source.kind === "field") {
        const sourceField = String(source.field || "");
        if (!/^(id|label|source|entityKind|ontologyTypeId|attributes\.[A-Za-z][A-Za-z0-9]*)$/.test(sourceField)) {
          throw new Error(`${name} 的节点字段来源无效`);
        }
        return { id: fieldId, title, renderer, source: { kind: "field", field: sourceField } };
      }
      if (source.kind === "relation") {
        const relationTypeId = String(source.relationTypeId || "");
        const targetTypeId = String(source.targetTypeId || "");
        const targetField = String(source.targetField || "attributes.path");
        const direction = source.direction === "incoming" ? "incoming" : "outgoing";
        if (!VIEW_RELATION_TYPES.has(relationTypeId) || !VIEW_OBJECT_TYPES.has(targetTypeId)) {
          throw new Error(`${name} 的关系字段类型无效`);
        }
        if (!/^(id|label|source|entityKind|ontologyTypeId|attributes\.[A-Za-z][A-Za-z0-9]*)$/.test(targetField)) {
          throw new Error(`${name} 的关系目标字段无效`);
        }
        return {
          id: fieldId,
          title,
          renderer,
          source: { kind: "relation", relationTypeId, direction, targetTypeId, targetField, take: "first" }
        };
      }
      throw new Error(`${name} 的节点字段来源类型无效`);
    });
    return { id, name, objectTypeIds, relationTypeIds, conditionMode, conditions: normalizedConditions, displayMode, nodeFields };
  });
}

function localFilePlugin(): Plugin {
  return {
    name: "story-atlas-local-files",
    configureServer(server) {
      server.middlewares.use(async (request, response, next) => {
        if (!request.url?.startsWith("/api/")) return next();
        const url = new URL(request.url, "http://127.0.0.1");

        try {
          if (url.pathname === "/api/health") {
            return sendJson(response, 200, { ok: true, platform: process.platform });
          }

          if (url.pathname === "/api/views" && request.method === "GET") {
            const stored = JSON.parse(readFileSync(customViewsFile, "utf-8")) as { version: number; views: unknown };
            return sendJson(response, 200, {
              version: 1,
              views: validateCustomViews(stored.views)
            });
          }

          if (url.pathname === "/api/views" && request.method === "PUT") {
            const body = await readJson(request);
            const views = validateCustomViews(body.views);
            const temporary = `${customViewsFile}.tmp`;
            writeFileSync(temporary, `${JSON.stringify({ version: 1, views }, null, 2)}\n`, "utf-8");
            renameSync(temporary, customViewsFile);
            return sendJson(response, 200, { ok: true, views });
          }

          if (url.pathname === "/api/file" && request.method === "GET") {
            const absolute = policy.resolveRepoFile(url.searchParams.get("path") || "");
            const stat = statSync(absolute);
            if (!stat.isFile()) throw new Error("目标不是文件");
            response.statusCode = 200;
            response.setHeader("Content-Type", MIME[extname(absolute).toLowerCase()] || "application/octet-stream");
            response.setHeader("Cache-Control", "no-cache");
            createReadStream(absolute).pipe(response);
            return;
          }

          if (url.pathname === "/api/reveal" && request.method === "POST") {
            if (process.platform !== "darwin") throw new Error("Finder 定位仅支持 macOS");
            const body = await readJson(request);
            const absolute = policy.resolveRepoFile(body.path || "");
            const child = spawn("open", ["-R", absolute], {
              detached: true,
              stdio: "ignore"
            });
            child.unref();
            return sendJson(response, 200, { ok: true, path: policy.toRepoPath(absolute) });
          }

          if (url.pathname === "/api/review" && request.method === "POST") {
            const body = await readJson(request);
            policy.resolveRepoFile(body.path || "");
            const reviews = JSON.parse(readFileSync(reviewFile, "utf-8")) as Record<
              string,
              { status: string; note: string }
            >;
            if (!body.status) {
              delete reviews[body.path || ""];
            } else {
              if (!["review", "remake"].includes(body.status)) {
                throw new Error("人工状态只允许 review 或 remake");
              }
              reviews[body.path || ""] = {
                status: body.status,
                note: String(body.note || "").slice(0, 500)
              };
            }
            writeFileSync(reviewFile, `${JSON.stringify(reviews, null, 2)}\n`, "utf-8");
            return sendJson(response, 200, { ok: true });
          }

          if (url.pathname === "/api/copy" && request.method === "POST") {
            const body = await readJson(request);
            const absolute = policy.resolveRepoFile(body.path || "");
            const repoPath = policy.toRepoPath(absolute);
            if (!repoPath.startsWith("game/") || extname(absolute).toLowerCase() !== ".lua") {
              throw new Error("只允许修改 game 目录内的 Lua 文案");
            }
            if (!Number.isInteger(body.line) || Number(body.line) < 1) {
              throw new Error("文案行号无效");
            }
            const oldText = String(body.oldText ?? "");
            const newText = String(body.newText ?? "");
            if (newText.length > 500) throw new Error("单条文案不能超过 500 字");
            if (/[\r\n]/.test(newText)) throw new Error("单条游戏文案不能包含换行，请拆成多条");

            const source = readFileSync(absolute, "utf-8");
            const lines = source.split("\n");
            const lineIndex = Number(body.line) - 1;
            if (lineIndex >= lines.length) throw new Error("原文件行号已经变化，请刷新图谱后重试");
            const oldLiteral = JSON.stringify(oldText);
            const newLiteral = JSON.stringify(newText);
            const sourceLine = lines[lineIndex];
            if (!sourceLine.includes(oldLiteral)) {
              throw new Error("原文已经变化，请刷新图谱后重试");
            }
            if (sourceLine.indexOf(oldLiteral) !== sourceLine.lastIndexOf(oldLiteral)) {
              throw new Error("同一行存在重复文案，已停止写入");
            }
            lines[lineIndex] = sourceLine.replace(oldLiteral, newLiteral);
            writeFileSync(absolute, lines.join("\n"), "utf-8");

            const extract = spawnSync(
              "node",
              [resolve(repoRoot, "tools/story-atlas/scripts/extract-lua-runtime.mjs")],
              { cwd: repoRoot, encoding: "utf-8" }
            );
            if (extract.status !== 0) {
              return sendJson(response, 500, {
                error: extract.stderr || extract.stdout || "Lua AST 提取失败"
              });
            }
            const scan = spawnSync("python3", [resolve(repoRoot, "scripts/scan-story-atlas.py")], {
              cwd: repoRoot,
              encoding: "utf-8"
            });
            return sendJson(response, 200, {
              ok: true,
              path: repoPath,
              line: body.line,
              scanOk: scan.status === 0
            });
          }

          return sendJson(response, 404, { error: "未知接口" });
        } catch (error) {
          const message = error instanceof Error ? error.message : "本地文件操作失败";
          return sendJson(response, 400, { error: message });
        }
      });
    }
  };
}

export default defineConfig({
  plugins: [react(), localFilePlugin()],
  server: {
    fs: { allow: [repoRoot] }
  },
  resolve: {
    alias: { "@": resolve(repoRoot, "tools/story-atlas/src") }
  }
});
