import { describe, expect, it } from "vitest";
import { parseViewRoute, serializeViewRoute } from "./viewRoute";

describe("视图 URL 路由", () => {
  it("解析固定视图和场景参数", () => {
    expect(parseViewRoute("?view=ontology").view).toBe("flow");
    expect(parseViewRoute("?view=ontology").graphMode).toBe("ontology");
    expect(parseViewRoute("?view=story").graphMode).toBe("instance");
    expect(parseViewRoute("?view=resources").view).toBe("resources");
    expect(parseViewRoute("?view=audit").view).toBe("audit");
    expect(parseViewRoute("?view=scene-layout&scene=SCN-COAST")).toMatchObject({
      view: "layout",
      sceneNodeId: "SCN-COAST",
    });
  });

  it("解析自定义视图并保留无关参数", () => {
    expect(parseViewRoute("?view=custom&customView=view-resource-relations")).toMatchObject({
      view: "custom",
      customViewId: "view-resource-relations",
    });
    expect(serializeViewRoute({
      view: "resources",
      graphMode: "instance",
      customViewId: null,
      sceneNodeId: "SCN-003",
    }, "?debug=1&scene=old")).toBe("?debug=1&view=resources");
  });
});
