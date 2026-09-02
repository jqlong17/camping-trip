import { describe, expect, it } from "vitest";
import { sortResources } from "./resourceSort";
import type { ResourceItem } from "./types";

function resource(
  id: string,
  createdAt: string,
  size: [number, number] | null,
  bytes: number,
): ResourceItem {
  return {
    id,
    path: id,
    name: id,
    kind: "image",
    category: "test",
    displayRole: "runtime-media",
    status: "active",
    inferredStatus: "active",
    reviewNote: "",
    size,
    bytes,
    createdAt,
    previewable: true,
    pairedT3x: true,
    nodeIds: [],
    codeRefs: [],
    sourceCandidates: [],
    provenance: [],
  };
}

describe("资源排序", () => {
  const items = [
    resource("RES-1", "2026-09-01T00:00:00Z", [100, 100], 500),
    resource("RES-2", "2026-09-02T00:00:00Z", [50, 50], 1500),
    resource("RES-3", "2026-08-31T00:00:00Z", [200, 100], 1000),
  ];

  it("支持创建时间、分辨率和大小倒序", () => {
    expect(sortResources(items, "created-desc").map((item) => item.id)).toEqual(["RES-2", "RES-1", "RES-3"]);
    expect(sortResources(items, "resolution-desc").map((item) => item.id)).toEqual(["RES-3", "RES-1", "RES-2"]);
    expect(sortResources(items, "size-desc").map((item) => item.id)).toEqual(["RES-2", "RES-3", "RES-1"]);
  });
});
