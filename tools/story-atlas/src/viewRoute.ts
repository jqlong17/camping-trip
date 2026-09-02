export type ViewMode = "flow" | "resources" | "layout" | "custom" | "audit";
export type GraphMode = "instance" | "ontology";

export interface ViewRoute {
  view: ViewMode;
  graphMode: GraphMode;
  customViewId: string | null;
  sceneNodeId: string;
}

const DEFAULT_SCENE = "SCN-003";

export function parseViewRoute(search: string, savedGraphMode: string | null = null): ViewRoute {
  const params = new URLSearchParams(search);
  const requested = params.get("view");
  const fallbackGraphMode: GraphMode = savedGraphMode === "ontology" ? "ontology" : "instance";

  if (requested === "ontology") {
    return { view: "flow", graphMode: "ontology", customViewId: null, sceneNodeId: DEFAULT_SCENE };
  }
  if (requested === "story") {
    return { view: "flow", graphMode: "instance", customViewId: null, sceneNodeId: DEFAULT_SCENE };
  }
  if (requested === "scene-layout") {
    return {
      view: "layout",
      graphMode: fallbackGraphMode,
      customViewId: null,
      sceneNodeId: params.get("scene") || DEFAULT_SCENE,
    };
  }
  if (requested === "resources") {
    return { view: "resources", graphMode: fallbackGraphMode, customViewId: null, sceneNodeId: DEFAULT_SCENE };
  }
  if (requested === "audit") {
    return { view: "audit", graphMode: fallbackGraphMode, customViewId: null, sceneNodeId: DEFAULT_SCENE };
  }
  if (requested === "custom" && params.get("customView")) {
    return {
      view: "custom",
      graphMode: fallbackGraphMode,
      customViewId: params.get("customView"),
      sceneNodeId: DEFAULT_SCENE,
    };
  }
  return { view: "flow", graphMode: fallbackGraphMode, customViewId: null, sceneNodeId: DEFAULT_SCENE };
}

export function serializeViewRoute(route: ViewRoute, currentSearch = ""): string {
  const params = new URLSearchParams(currentSearch);
  params.delete("scene");
  params.delete("customView");

  if (route.view === "flow") {
    params.set("view", route.graphMode === "ontology" ? "ontology" : "story");
  } else if (route.view === "layout") {
    params.set("view", "scene-layout");
    params.set("scene", route.sceneNodeId || DEFAULT_SCENE);
  } else if (route.view === "resources") {
    params.set("view", "resources");
  } else if (route.view === "audit") {
    params.set("view", "audit");
  } else {
    params.set("view", "custom");
    if (route.customViewId) params.set("customView", route.customViewId);
  }
  const query = params.toString();
  return query ? `?${query}` : "";
}
