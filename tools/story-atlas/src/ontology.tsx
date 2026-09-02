import dagre from "@dagrejs/dagre";
import {
  Handle,
  Position,
  type Edge,
  type Node,
  type NodeProps,
  type NodeTypes
} from "@xyflow/react";
import type { GraphIndex } from "./types";

export type OntologyGroup =
  | "root"
  | "abstract"
  | "narrative"
  | "runtime"
  | "resource"
  | "content"
  | "engineering"
  | "relation";

export interface OntologyType {
  id: string;
  label: string;
  group: OntologyGroup;
  abstract?: boolean;
  description: string;
  instanceCount: number;
  properties: string[];
  examples: OntologyExample[];
}

export interface OntologyInstanceTarget {
  type: "node" | "resource";
  id: string;
}

export interface OntologyExample {
  label: string;
  target?: OntologyInstanceTarget;
}

export interface OntologyNodeData extends Record<string, unknown> {
  ontology: OntologyType;
}

export interface OntologyModel {
  types: OntologyType[];
  nodes: Array<Node<OntologyNodeData>>;
  edges: Edge[];
}

const GROUP_LABELS: Record<OntologyGroup, string> = {
  root: "本体根",
  abstract: "抽象类型",
  narrative: "叙事对象",
  runtime: "运行时对象",
  resource: "资源对象",
  content: "内容对象",
  engineering: "工程对象",
  relation: "关系类型"
};

const STORY_TYPE_LABELS: Record<string, string> = {
  scene: "故事场景",
  beat: "故事分镜",
  choice: "条件选择",
  action: "玩法动作",
  phase: "仪式阶段",
  page: "内容页面",
  entry: "图鉴条目"
};

const RESOURCE_TYPE_LABELS: Record<string, string> = {
  image: "图片资源",
  audio: "音频资源",
  font: "字体资源",
  texture: "纹理资源",
  text: "文本资源"
};

function examples(values: OntologyExample[]) {
  return values.slice(0, 5);
}

function type(
  id: string,
  label: string,
  group: OntologyGroup,
  description: string,
  instanceCount: number,
  properties: string[],
  sample: OntologyExample[],
  abstract = false
): OntologyType {
  return { id, label, group, description, instanceCount, properties, examples: examples(sample), abstract };
}

export function buildOntology(index: GraphIndex): OntologyModel {
  const storyExample = (id: string, label: string): OntologyExample => ({
    label: `${id} ${label}`,
    target: { type: "node", id }
  });
  const resourceExample = (id: string, label: string): OntologyExample => ({
    label: `${id} ${label}`,
    target: { type: "resource", id }
  });
  const runtimeExample = (runtimeId: string): OntologyExample => {
    const binding = index.nodes.find((node) => node.runtimeScene === runtimeId || node.runtimeOverlay === runtimeId);
    return {
      label: runtimeId,
      target: binding ? { type: "node", id: binding.id } : undefined
    };
  };
  const storyByKind = new Map<string, typeof index.nodes>();
  for (const node of index.nodes) {
    const bucket = storyByKind.get(node.kind) || [];
    bucket.push(node);
    storyByKind.set(node.kind, bucket);
  }
  const resourcesByKind = new Map<string, typeof index.resources>();
  for (const resource of index.resources) {
    const bucket = resourcesByKind.get(resource.kind) || [];
    bucket.push(resource);
    resourcesByKind.set(resource.kind, bucket);
  }

  const copyEntries = index.nodes.flatMap((node) =>
    node.copyEntries.map((entry) => ({ ...entry, nodeId: node.id }))
  );
  const pipelineScripts = Array.from(new Set(index.resources.flatMap((resource) =>
    (resource.provenance || []).map((item) => item.scriptPath)
  ))).sort();
  const runtimeMappings = index.nodes.filter((node) => node.runtimeScene || node.runtimeOverlay);
  const provenanceEdges = index.resources.reduce((sum, resource) =>
    sum + (resource.provenance || []).reduce((count, item) => count + item.sources.length, 0), 0
  );
  const generatedByEdges = index.resources.reduce((sum, resource) =>
    sum + new Set((resource.provenance || []).map((item) => item.scriptPath)).size, 0
  );
  const assetUsageEdges = index.nodes.reduce((sum, node) => sum + node.resourceIds.length, 0);
  const relationInstances = index.instanceGraph.meta.relationCount;
  const sourceResources = index.resources.filter((resource) => resource.status === "source");
  const rootInstances = index.instanceGraph.meta.entityCount + relationInstances;
  const instancesOf = (ontologyTypeId: string) =>
    index.instanceGraph.entities.filter((entity) => entity.ontologyTypeId === ontologyTypeId);
  const relationsOf = (ontologyTypeId: string) =>
    index.instanceGraph.relations.filter((relation) => relation.ontologyTypeId === ontologyTypeId);

  const types: OntologyType[] = [
    type("ONT-000", "游戏知识对象", "root", "Story Atlas 中所有可被编号、查询或建立关系的记录。", rootInstances, ["id", "type", "origin"], [], true),
    type("ONT-100", "叙事对象", "abstract", "策划视角的场景、分镜、选择、玩法和内容结构。", index.nodes.length, ["id", "label", "chapter", "visibility"], index.nodes.map((node) => storyExample(node.id, node.label)), true),
    type("ONT-200", "运行时对象", "abstract", "由 Lua AST 证明的场景与状态结构。", index.runtimeGraph.scenes.length + index.runtimeGraph.stateVariables.length, ["codeLocator", "evidence"], index.runtimeGraph.scenes.map((scene) => runtimeExample(scene.id)), true),
    type("ONT-300", "媒体资源", "abstract", "磁盘中可扫描、预览、构建或发布的媒体文件。", index.resources.length, ["path", "kind", "status", "bytes"], index.resources.map((item) => resourceExample(item.id, item.name)), true),
    type("ONT-400", "文案内容", "abstract", "从源码范围内提取并可受控回写的文本。", copyEntries.length, ["path", "line", "text"], copyEntries.map((item) => ({ label: `${item.id} ${item.text}`, target: { type: "node", id: item.nodeId } })), true),
    type("ONT-500", "工程对象", "abstract", "负责生成、转换和验证游戏内容的工程实体。", pipelineScripts.length, ["path", "version"], pipelineScripts.map((label) => ({ label })), true),
    type("ONT-600", "关系实例", "relation", "连接对象实例的有向关系及其证据。", relationInstances, ["source", "target", "kind", "evidence"], [], true),

    ...Object.entries(STORY_TYPE_LABELS).map(([kind, label], offset) => {
      const items = storyByKind.get(kind) || [];
      return type(
        `ONT-1${String(offset + 1).padStart(2, "0")}`,
        label,
        "narrative",
        `${label}实例；属于人工设计语义层。`,
        items.length,
        ["id", "label", "subtitle", "chapter"],
        items.map((item) => storyExample(item.id, item.label))
      );
    }),
    type("ONT-108", "目的地", "narrative", "可选择的环境包；共享露营玩法，只替换地图、生态、声景与时间事件。", instancesOf("ONT-108").length, ["id", "key", "status", "sceneNodeId"], instancesOf("ONT-108").map((item) => ({ label: `${item.id} ${item.label}`, target: { type: "node", id: item.id } }))),
    type("ONT-109", "场景资源组", "narrative", "目的地内地表、水系、植被、自然物、动态生物与合成产物六组。", instancesOf("ONT-109").length, ["id", "destinationId", "resourceCount", "placementCount"], instancesOf("ONT-109").map((item) => ({ label: `${item.id} ${item.label}` }))),
    type("ONT-110", "场景摆放实例", "narrative", "资源定义在目的地地图坐标上的一次确定性使用。", instancesOf("ONT-110").length, ["id", "x", "y", "variant", "resourceId"], instancesOf("ONT-110").map((item) => ({ label: item.id }))),

    type("ONT-201", "运行时场景", "runtime", "Lua 中 Runtime.scene 的可证明取值。", index.runtimeGraph.scenes.length, ["id", "reads", "writes"], index.runtimeGraph.scenes.map((scene) => runtimeExample(scene.id))),
    type("ONT-202", "状态变量", "runtime", "Runtime、R 或 State 上被初始化或写入的字段。", index.runtimeGraph.stateVariables.length, ["path", "initialValues", "writes"], index.runtimeGraph.stateVariables.map((item) => ({ label: item.path }))),
    type("ONT-203", "运行时覆盖层", "runtime", "跨场景复用、但不改变 Runtime.scene 的交互状态。", new Set(index.nodes.map((node) => node.runtimeOverlay).filter(Boolean)).size, ["id", "statePath"], index.nodes.filter((node) => node.runtimeOverlay).map((node) => runtimeExample(node.runtimeOverlay || ""))),

    ...Object.entries(RESOURCE_TYPE_LABELS).map(([kind, label], offset) => {
      const items = resourcesByKind.get(kind) || [];
      return type(
        `ONT-3${String(offset + 1).padStart(2, "0")}`,
        label,
        "resource",
        `按媒体格式识别的${label}。`,
        items.length,
        ["id", "path", "status", "bytes"],
        items.map((item) => resourceExample(item.id, item.name))
      );
    }),
    type("ONT-306", "制作源资源", "resource", "作为加工输入或设计参考的资源角色，可与图片等媒体类型重叠。", sourceResources.length, ["id", "path", "status=source"], sourceResources.map((item) => resourceExample(item.id, item.name))),

    type("ONT-401", "可编辑文案", "content", "具有源码位置和受控写回入口的文案实例。", copyEntries.length, ["id", "nodeId", "path", "line", "text"], copyEntries.map((item) => ({ label: `${item.id} ${item.text}`, target: { type: "node", id: item.nodeId } }))),
    type("ONT-501", "资产构建管线", "engineering", "声明输入、处理方式和输出资源的构建脚本。", pipelineScripts.length, ["scriptPath", "operation", "outputs"], pipelineScripts.map((label) => ({ label }))),

    type("ONT-601", "故事关系", "relation", "人工 manifest 中的故事推进、分支、选择和返回关系。", index.edges.length, ["id", "source", "target", "kind", "label"], index.edges.map((edge) => ({ label: `${edge.id} ${edge.source}→${edge.target}`, target: { type: "node", id: edge.source } }))),
    type("ONT-602", "运行时跳转", "relation", "Lua AST 通过调用链证明的跨场景转换。", index.runtimeGraph.transitions.length, ["id", "from", "to", "events", "guards", "evidence"], index.runtimeGraph.transitions.map((item) => ({ ...runtimeExample(item.from), label: `${item.id} ${item.from}→${item.to}` }))),
    type("ONT-603", "节点使用资源", "relation", "故事节点与画面、音频等资源之间的使用关系。", assetUsageEdges, ["nodeId", "resourceId", "usage"], index.nodes.flatMap((node) => node.resourceIds.slice(0, 1).map((id) => ({ label: `${node.id}→${id}`, target: { type: "node" as const, id: node.id } })))),
    type("ONT-604", "运行时映射", "relation", "叙事节点到 runtime scene 或 overlay 的映射。", runtimeMappings.length, ["nodeId", "runtimeScene", "runtimeOverlay"], runtimeMappings.map((node) => ({ label: `${node.id}→${node.runtimeScene || node.runtimeOverlay}`, target: { type: "node", id: node.id } }))),
    type("ONT-605", "资源派生", "relation", "运行时资源到仓库内制作源的确定性血缘。", provenanceEdges, ["resourceId", "sourceId", "operation"], index.resources.filter((item) => item.sourceCandidates.length).map((item) => ({ label: `${item.id}→${item.sourceCandidates[0]}`, target: { type: "resource", id: item.id } }))),
    type("ONT-606", "管线生成", "relation", "构建脚本与输出资源之间的生成关系。", generatedByEdges, ["scriptPath", "resourceId", "operation"], pipelineScripts.map((label) => ({ label }))),
    type("ONT-607", "节点包含文案", "relation", "叙事节点与从其源码范围提取的可编辑文案关系。", copyEntries.length, ["nodeId", "copyId", "path", "line"], copyEntries.map((item) => ({ label: `${item.nodeId}→${item.id}`, target: { type: "node", id: item.nodeId } }))),
    type("ONT-608", "场景采用目的地", "relation", "故事营地场景采用一个 Destination Pack。", relationsOf("ONT-608").length, ["sceneNodeId", "destinationId"], []),
    type("ONT-609", "目的地包含资源组", "relation", "目的地包含六类场景资源组。", relationsOf("ONT-609").length, ["destinationId", "groupId"], []),
    type("ONT-610", "资源组包含定义", "relation", "资源组引用稳定 RES 资源定义。", relationsOf("ONT-610").length, ["groupId", "resourceId"], []),
    type("ONT-611", "资源组包含摆放", "relation", "资源组包含地图摆放实例。", relationsOf("ONT-611").length, ["groupId", "placementId"], []),
    type("ONT-612", "摆放使用资源", "relation", "摆放实例使用一个可复用资源定义。", relationsOf("ONT-612").length, ["placementId", "resourceId"], [])
  ];

  const hierarchy: Array<[string, string]> = [
    ["ONT-000", "ONT-100"], ["ONT-000", "ONT-200"], ["ONT-000", "ONT-300"],
    ["ONT-000", "ONT-400"], ["ONT-000", "ONT-500"], ["ONT-000", "ONT-600"],
    ...types.filter((item) => item.group === "narrative").map((item) => ["ONT-100", item.id] as [string, string]),
    ...types.filter((item) => item.group === "runtime").map((item) => ["ONT-200", item.id] as [string, string]),
    ...types.filter((item) => item.group === "resource").map((item) => ["ONT-300", item.id] as [string, string]),
    ["ONT-400", "ONT-401"], ["ONT-500", "ONT-501"],
    ...types.filter((item) => item.group === "relation" && item.id !== "ONT-600").map((item) => ["ONT-600", item.id] as [string, string])
  ];
  const semantic: Array<[string, string, string]> = [
    ["ONT-100", "ONT-201", `映射到 · ${runtimeMappings.length}`],
    ["ONT-100", "ONT-300", `使用 · ${assetUsageEdges}`],
    ["ONT-100", "ONT-401", `包含文案 · ${copyEntries.length}`],
    ["ONT-300", "ONT-501", `由管线生成 · ${generatedByEdges}`],
    ["ONT-201", "ONT-202", "读取 / 写入"],
    ["ONT-600", "ONT-100", "定义关系域"]
  ];

  const graph = new dagre.graphlib.Graph().setDefaultEdgeLabel(() => ({}));
  graph.setGraph({ rankdir: "LR", ranksep: 86, nodesep: 28, edgesep: 18, marginx: 50, marginy: 50 });
  const width = 226;
  const height = 126;
  types.forEach((item) => graph.setNode(item.id, { width, height }));
  hierarchy.forEach(([source, target]) => graph.setEdge(source, target));
  semantic.forEach(([source, target]) => graph.setEdge(source, target));
  dagre.layout(graph);

  const nodes: Array<Node<OntologyNodeData>> = types.map((item) => {
    const point = graph.node(item.id) || { x: 0, y: 0 };
    return {
      id: item.id,
      type: "ontology",
      position: { x: point.x - width / 2, y: point.y - height / 2 },
      data: { ontology: item }
    };
  });
  const edges: Edge[] = [
    ...hierarchy.map(([source, target], indexValue) => ({
      id: `ONT-IS-A-${indexValue + 1}`,
      source,
      target,
      label: "包含类型",
      type: "default",
      className: "ontology-edge ontology-edge-hierarchy"
    })),
    ...semantic.map(([source, target, label], indexValue) => ({
      id: `ONT-REL-${indexValue + 1}`,
      source,
      target,
      label,
      type: "default",
      className: "ontology-edge ontology-edge-semantic"
    }))
  ];
  return { types, nodes, edges };
}

export function OntologyCard({ data, selected }: NodeProps<Node<OntologyNodeData>>) {
  const item = data.ontology;
  return (
    <article
      className={`ontology-node ontology-${item.group} ${item.abstract ? "is-abstract" : ""} ${selected ? "is-selected" : ""}`}
      role="button"
      aria-label={`${item.label}，${item.instanceCount} 个实例`}
    >
      <Handle type="target" position={Position.Left} />
      <div className="ontology-node-head">
        <span>{item.id}</span>
        <small>{GROUP_LABELS[item.group]}</small>
      </div>
      <strong>{item.label}</strong>
      <b>{item.instanceCount}</b>
      <small>实例</small>
      <Handle type="source" position={Position.Right} />
    </article>
  );
}

export const ontologyNodeTypes: NodeTypes = { ontology: OntologyCard };

export function OntologyInspector({
  selectedId,
  model,
  onSelect,
  onOpenInstance
}: {
  selectedId: string | null;
  model: OntologyModel;
  onSelect: (id: string) => void;
  onOpenInstance: (target: OntologyInstanceTarget) => void;
}) {
  const item = model.types.find((candidate) => candidate.id === selectedId) || model.types[0];
  if (!item) return null;
  return (
    <aside className="inspector ontology-inspector">
      <div className="inspector-head">
        <span className="id-badge">{item.id}</span>
        <span>{GROUP_LABELS[item.group]}</span>
      </div>
      <h2>{item.label}</h2>
      <p className="lead">{item.description}</p>
      <dl className="facts">
        <div><dt>实例数量</dt><dd>{item.instanceCount}</dd></div>
        <div><dt>类型性质</dt><dd>{item.abstract ? "抽象类型" : "可实例化类型"}</dd></div>
      </dl>
      <section>
        <h3>标准属性</h3>
        <div className="option-chips">
          {item.properties.map((property) => <span key={property}>{property}</span>)}
        </div>
      </section>
      {!!item.examples.length && (
        <section>
          <h3>实例样例</h3>
          <div className="ontology-examples">
            {item.examples.map((example) => example.target ? (
              <button key={example.label} onClick={() => onOpenInstance(example.target!)}>
                <code>{example.label}</code>
                <span>定位实例</span>
              </button>
            ) : (
              <code key={example.label}>{example.label}</code>
            ))}
          </div>
        </section>
      )}
      <section>
        <h3>同层对象类型</h3>
        <div className="ontology-peer-list">
          {model.types.filter((candidate) => candidate.group === item.group && candidate.id !== item.id).map((candidate) => (
            <button key={candidate.id} onClick={() => onSelect(candidate.id)}>
              <span>{candidate.id}</span>
              <strong>{candidate.label}</strong>
              <small>{candidate.instanceCount}</small>
            </button>
          ))}
        </div>
      </section>
    </aside>
  );
}
