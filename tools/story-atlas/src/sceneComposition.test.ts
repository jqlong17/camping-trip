import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import type { GraphIndex } from "./types";

const indexPath = fileURLToPath(new URL("../public/graph-index.json", import.meta.url));
const index = JSON.parse(readFileSync(indexPath, "utf-8")) as GraphIndex;

describe("场景摆放可读性", () => {
  const forest = index.sceneCompositions.find((item) => item.key === "forest");
  const placements = forest?.groups.flatMap((group) => group.placements) || [];

  it("所有摆放都有中文名称和通用上下文图", () => {
    expect(placements.length).toBeGreaterThan(0);
    expect(placements.every((item) =>
      item.label.includes("坐标")
      && item.kindLabel.length > 0
      && item.contextImagePath === forest?.contextImagePath
    )).toBe(true);
  });

  it("鸟巢实例保留稳定 ID、资源和代码证据", () => {
    const nest = placements.find((item) => item.id === "PLACE-FOREST-NEST-03-11-2");
    expect(nest?.label).toBe("鸟巢 · 坐标 3,11 · 变体2");
    expect(nest?.resourceId).toMatch(/^RES-\d+$/);
    expect(nest?.evidence[0]).toMatchObject({
      path: "scripts/build-camp-static-base.py",
      functionName: "build_map"
    });
  });
});
