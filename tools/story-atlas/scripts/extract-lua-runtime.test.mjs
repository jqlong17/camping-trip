import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { extractRuntimeGraph } from "./extract-lua-runtime.mjs";

function fixture(files) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "lua-runtime-graph-"));
  const game = path.join(root, "game");
  fs.mkdirSync(game, { recursive: true });
  for (const [name, source] of Object.entries(files)) {
    const output = path.join(game, name);
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.writeFileSync(output, source, "utf8");
  }
  return root;
}

describe("Lua AST 运行时流程提取", () => {
  it("提取直接、多重场景赋值与跨函数跳转", () => {
    const root = fixture({
      "runtime.lua": `
        local Runtime = { scene = "title", canGoHome = false }
        return Runtime
      `,
      "scene_flow.lua": `
        local R = require("runtime")
        local Flow = {}
        function Flow.goPlay()
          R.scene = "play"
          R.canGoHome = false
        end
        function Flow.goCodex()
          R.scene, R.codex = "codex", { i = 1 }
        end
        function Flow.start()
          Flow.goPlay()
        end
        return Flow
      `,
      "input.lua": `
        local R = require("runtime")
        local Flow = require("scene_flow")
        local Input = {}
        function Input.onKey(key)
          if R.scene == "title" and key == "a" then
            Flow.start()
          elseif R.scene == "play" and key == "x" then
            Flow.goCodex()
          end
        end
        return Input
      `,
    });

    const graph = extractRuntimeGraph(root);
    expect(graph.scenes.map((scene) => scene.id)).toEqual(["codex", "play", "title"]);
    expect(graph.transitions.map((item) => `${item.from}->${item.to}`)).toEqual([
      "play->codex",
      "title->play",
    ]);
    expect(graph.transitions.find((item) => item.from === "title")?.events).toContain("keyboard:a");
    expect(graph.stateVariables.find((item) => item.path === "Runtime.canGoHome")?.initialValues).toContain(false);
  });

  it("不执行 Lua，并把动态场景写入列为 unresolved", () => {
    const root = fixture({
      "dynamic.lua": `
        local R = require("runtime")
        error("AST 提取时不应执行")
        local Flow = {}
        function Flow.go(name)
          R.scene = name
        end
        return Flow
      `,
    });
    const graph = extractRuntimeGraph(root);
    expect(graph.unresolved.some((item) => item.kind === "unresolved-scene-write")).toBe(true);
  });

  it("当前游戏提取十个场景，并识别含目的地选择的主线转换", () => {
    const root = path.resolve(import.meta.dirname, "../../..");
    const graph = extractRuntimeGraph(root);
    expect(graph.scenes.map((scene) => scene.id)).toEqual([
      "about", "cast", "codex", "depart", "destination", "diary",
      "homecoming", "play", "prologue", "title",
    ]);
    const transitions = new Set(graph.transitions.map((item) => `${item.from}->${item.to}`));
    for (const expected of [
      "title->prologue",
      "prologue->cast",
      "prologue->destination",
      "cast->destination",
      "destination->depart",
      "depart->play",
      "play->homecoming",
      "homecoming->diary",
      "diary->title",
    ]) {
      expect(transitions.has(expected), expected).toBe(true);
    }
  });
});
