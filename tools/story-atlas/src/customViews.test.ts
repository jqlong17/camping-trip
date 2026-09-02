import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { applyCustomView, toGenericFlow } from "./customViews";
import type { CustomViewDefinition, GraphIndex } from "./types";

const indexPath = fileURLToPath(new URL("../public/graph-index.json", import.meta.url));
const index = JSON.parse(readFileSync(indexPath, "utf-8")) as GraphIndex;
const storyNodeIds = new Set(index.nodes.map((node) => node.id));
const storyObjectTypeIds = [...new Set(
  index.instanceGraph.entities
    .filter((entity) => storyNodeIds.has(entity.id))
    .map((entity) => entity.ontologyTypeId)
)];

function view(overrides: Partial<CustomViewDefinition>): CustomViewDefinition {
  return {
    id: "VIEW-TEST",
    name: "测试视图",
    objectTypeIds: ["ONT-101"],
    relationTypeIds: [],
    conditionMode: "all",
    conditions: [],
    displayMode: "grid",
    nodeFields: [
      { id: "field-id", title: "编号", renderer: "identifier", source: { kind: "field", field: "id" } }
    ],
    ...overrides
  };
}

describe("统一实例图", () => {
  it("包含所有当前可查询实体且编号唯一", () => {
    const ids = index.instanceGraph.entities.map((entity) => entity.id);
    expect(ids).toHaveLength(index.instanceGraph.meta.entityCount);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it("每条物化关系都有完整端点", () => {
    const ids = new Set(index.instanceGraph.entities.map((entity) => entity.id));
    expect(index.instanceGraph.relations.length).toBeGreaterThan(700);
    expect(index.instanceGraph.relations.every((relation) =>
      ids.has(relation.source) && ids.has(relation.target)
    )).toBe(true);
    expect(index.instanceGraph.meta.droppedRelationCount).toBe(0);
  });
});

describe("自定义视图查询", () => {
  it("可以重建完整故事实例视图", () => {
    const result = applyCustomView(view({
      objectTypeIds: storyObjectTypeIds,
      relationTypeIds: ["ONT-601"],
      displayMode: "workflow"
    }), index.instanceGraph.entities, index.instanceGraph.relations);
    expect(result.entities.map((entity) => entity.id).sort())
      .toEqual(index.nodes.map((node) => node.id).sort());
    expect(result.relations.map((relation) => relation.id).sort())
      .toEqual(index.edges.map((edge) => edge.id).sort());
  });

  it("支持属性条件和重叠的制作源角色", () => {
    const main = applyCustomView(view({
      objectTypeIds: storyObjectTypeIds,
      conditions: [{ field: "attributes.visibility", operator: "eq", value: "main" }]
    }), index.instanceGraph.entities, index.instanceGraph.relations);
    expect(main.entities.map((entity) => entity.id).sort())
      .toEqual(index.nodes.filter((node) => node.visibility === "main").map((node) => node.id).sort());

    const sources = applyCustomView(view({
      objectTypeIds: ["ONT-306"]
    }), index.instanceGraph.entities, index.instanceGraph.relations);
    expect(sources.entities).toHaveLength(index.meta.statusCounts.source);
    expect(sources.entities.every((entity) => (entity.roleTypeIds || []).includes("ONT-306"))).toBe(true);
    expect(sources.entities.some((entity) => entity.ontologyTypeId === "ONT-302")).toBe(true);
  });

  it("可沿第一条匹配关系取得节点图片", () => {
    const result = applyCustomView(view({
      objectTypeIds: ["ONT-101"],
      relationTypeIds: ["ONT-601"]
    }), index.instanceGraph.entities, index.instanceGraph.relations);
    const flow = toGenericFlow(result, [{
      id: "field-image",
      title: "预览",
      renderer: "image",
      source: {
        kind: "relation",
        relationTypeId: "ONT-603",
        direction: "outgoing",
        targetTypeId: "ONT-301",
        targetField: "attributes.path",
        take: "first"
      }
    }], index.instanceGraph.entities, index.instanceGraph.relations);
    const scene = flow.nodes.find((node) => node.id === "SCN-000");
    expect(scene?.data.fields[0].value).toBe("cia/icon.png");
  });
});
