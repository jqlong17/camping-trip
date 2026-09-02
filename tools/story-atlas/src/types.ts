export type StoryKind = "scene" | "beat" | "choice" | "action" | "phase" | "page" | "entry";
export type Visibility = "main" | "branch" | "auxiliary";

export interface CopyEntry {
  id: string;
  path: string;
  line: number;
  text: string;
}

export interface StoryNode {
  id: string;
  kind: StoryKind;
  label: string;
  subtitle: string;
  chapter: string;
  visibility: Visibility;
  description: string;
  options?: string[];
  assetPaths: string[];
  assetGlobs?: string[];
  sourcePaths: string[];
  resourceIds: string[];
  copyEntries: CopyEntry[];
  runtimeScene?: string;
  runtimeOverlay?: string;
}

export interface StoryEdge {
  id: string;
  source: string;
  target: string;
  kind: string;
  label: string;
}

export type ResourceStatus =
  | "active"
  | "unlinked"
  | "legacy"
  | "backup"
  | "source"
  | "review"
  | "remake"
  | "missing";

export interface ResourceItem {
  id: string;
  path: string;
  name: string;
  kind: "image" | "audio" | "font" | "texture" | "text";
  category: string;
  displayRole: "top-preview" | "directory-icon" | "catalog-icon" | "top-frame" | "runtime-media";
  status: ResourceStatus;
  inferredStatus: ResourceStatus;
  reviewNote: string;
  size: [number, number] | null;
  bytes: number;
  createdAt: string;
  previewable: boolean;
  pairedT3x: boolean | null;
  nodeIds: string[];
  codeRefs: string[];
  sourceCandidates: string[];
  provenance: Array<{
    sources: string[];
    scriptPath: string;
    operation: string;
  }>;
}

export interface AuditData {
  duplicateNodeIds: string[];
  brokenEdges: StoryEdge[];
  missingAssets: Array<{ nodeId: string; path: string }>;
  missingT3x: string[];
  unlinkedResourceIds: string[];
  legacyResourceIds: string[];
  backupResourceIds: string[];
  duplicateRuntimeBindings: Array<{
    nodeId: string;
    firstScene: string;
    secondScene: string;
  }>;
  unboundRuntimeScenes: string[];
  missingRuntimeScenes: string[];
  runtimeTransitionsMissingInManifest: RuntimeTransition[];
  manifestTransitionsMissingInRuntime: Array<{
    from: string;
    to: string;
    edgeIds: string[];
  }>;
  unresolvedLuaFacts: Array<Record<string, unknown>>;
}

export interface LuaEvidence {
  path: string;
  line: number;
  column: number;
  functionName: string;
  kind: string;
}

export interface RuntimeTransition {
  id: string;
  from: string;
  to: string;
  events: string[];
  guards: string[];
  callChain: string[];
  evidence: LuaEvidence[];
}

export interface RuntimeScene {
  id: string;
  reads: Array<{ scene: string; evidence: LuaEvidence }>;
  writes: LuaEvidence[];
}

export interface RuntimeStateVariable {
  path: string;
  initialValues: unknown[];
  writes: Array<{
    path: string;
    valueKnown: boolean;
    value: unknown;
    evidence: LuaEvidence;
  }>;
}

export interface InstanceEntity {
  id: string;
  ontologyTypeId: string;
  roleTypeIds?: string[];
  entityKind: "story" | "resource" | "runtimeScene" | "runtimeState" | "runtimeOverlay" | "copy" | "pipeline" | "destination" | "sceneGroup" | "placement";
  label: string;
  source: string;
  attributes: Record<string, unknown>;
}

export interface ScenePlacement {
  id: string;
  kind: string;
  label: string;
  kindLabel: string;
  x: number;
  y: number;
  variant: number | string | null;
  layer: string;
  resourcePath: string;
  resourceId: string;
  contextImagePath?: string;
  source: string;
  evidence: Array<Record<string, unknown>>;
}

export interface SceneCompositionGroup {
  id: string;
  key: string;
  label: string;
  resourcePaths: string[];
  resourceIds: string[];
  placements: ScenePlacement[];
}

export interface SceneComposition {
  id: string;
  key: string;
  label: string;
  sceneNodeId: string;
  status: string;
  source: string;
  tileSize: number;
  mapSize: [number, number];
  contextImagePath?: string;
  placementKindLabels: Record<string, string>;
  groups: SceneCompositionGroup[];
  futurePacks?: Array<Record<string, unknown>>;
}

export interface InstanceRelation {
  id: string;
  ontologyTypeId: string;
  source: string;
  target: string;
  label: string;
  attributes: Record<string, unknown>;
  evidence: Array<Record<string, unknown>>;
}

export type ViewDisplayMode = "graph" | "workflow" | "grid" | "table";
export type ViewConditionOperator = "eq" | "neq" | "contains" | "in" | "exists" | "gt" | "lt";

export interface ViewCondition {
  field: string;
  operator: ViewConditionOperator;
  value: string;
}

export type NodeFieldRenderer = "text" | "image" | "identifier" | "badge";

export interface NodeFieldConfig {
  id: string;
  title: string;
  renderer: NodeFieldRenderer;
  source:
    | {
        kind: "field";
        field: string;
      }
    | {
        kind: "relation";
        relationTypeId: string;
        direction: "outgoing" | "incoming";
        targetTypeId: string;
        targetField: string;
        take: "first";
      };
}

export interface CustomViewDefinition {
  id: string;
  name: string;
  objectTypeIds: string[];
  relationTypeIds: string[];
  conditionMode: "all" | "any";
  conditions: ViewCondition[];
  displayMode: ViewDisplayMode;
  nodeFields: NodeFieldConfig[];
}

export interface GraphIndex {
  meta: {
    version: number;
    generatedAt: string;
    resourceCount: number;
    nodeCount: number;
    edgeCount: number;
    runtimeSceneCount: number;
    runtimeTransitionCount: number;
    statusCounts: Record<string, number>;
  };
  nodes: StoryNode[];
  edges: StoryEdge[];
  resources: ResourceItem[];
  sceneCompositions: SceneComposition[];
  instanceGraph: {
    meta: {
      entityCount: number;
      relationCount: number;
      droppedRelationCount: number;
    };
    entities: InstanceEntity[];
    relations: InstanceRelation[];
  };
  runtimeGraph: {
    meta: {
      schemaVersion: number;
      extractorVersion: number;
      parser: string;
      generatedAt: string;
      fileCount: number;
      propagationRounds: number;
    };
    scenes: RuntimeScene[];
    stateVariables: RuntimeStateVariable[];
    transitions: RuntimeTransition[];
    unresolved: Array<Record<string, unknown>>;
  };
  audits: AuditData;
}

export type Selection =
  | { type: "node"; id: string }
  | { type: "resource"; id: string }
  | null;
