import type { ResourceItem } from "./types";

export type ResourceSortMode = "created-desc" | "resolution-desc" | "size-desc";

function resolution(resource: ResourceItem) {
  return resource.size ? resource.size[0] * resource.size[1] : 0;
}

function createdTime(resource: ResourceItem) {
  const parsed = Date.parse(resource.createdAt);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function sortResources(resources: ResourceItem[], mode: ResourceSortMode) {
  return [...resources].sort((left, right) => {
    let difference = 0;
    if (mode === "created-desc") difference = createdTime(right) - createdTime(left);
    else if (mode === "resolution-desc") difference = resolution(right) - resolution(left);
    else difference = right.bytes - left.bytes;
    return difference || right.id.localeCompare(left.id, undefined, { numeric: true });
  });
}

export function resourceSortDetail(resource: ResourceItem, mode: ResourceSortMode) {
  if (mode === "resolution-desc") {
    return resource.size ? `${resource.size[0]} × ${resource.size[1]}` : "无分辨率";
  }
  if (mode === "size-desc") {
    if (resource.bytes >= 1024 * 1024) return `${(resource.bytes / 1024 / 1024).toFixed(1)} MB`;
    if (resource.bytes >= 1024) return `${Math.round(resource.bytes / 1024)} KB`;
    return `${resource.bytes} B`;
  }
  const date = new Date(resource.createdAt);
  return Number.isFinite(date.getTime())
    ? new Intl.DateTimeFormat("zh-CN", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    }).format(date)
    : "时间未知";
}
