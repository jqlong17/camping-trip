import {
  Background,
  Controls,
  Handle,
  Panel,
  Position,
  ReactFlow,
  type Node,
  type NodeProps,
  type NodeTypes,
  type ReactFlowInstance,
  useNodesState
} from "@xyflow/react";
import { useCallback, useEffect, useId, useLayoutEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import {
  applyCustomView,
  CustomViewDialog,
  DEFAULT_NODE_FIELDS,
  GenericEntityInspector,
  genericNodeTypes,
  OBJECT_TYPE_OPTIONS,
  toGenericFlow,
  type GenericNodeData
} from "./customViews";
import { toFlowElements, type FlowNodeData } from "./layout";
import {
  resourceSortDetail,
  sortResources,
  type ResourceSortMode
} from "./resourceSort";
import {
  buildOntology,
  OntologyInspector,
  ontologyNodeTypes,
  type OntologyInstanceTarget,
  type OntologyNodeData
} from "./ontology";
import type {
  CopyEntry,
  CustomViewDefinition,
  GraphIndex,
  InstanceEntity,
  ResourceItem,
  ResourceStatus,
  SceneComposition,
  Selection,
  StoryNode
} from "./types";
import {
  parseViewRoute,
  serializeViewRoute,
  type GraphMode,
  type ViewMode,
  type ViewRoute
} from "./viewRoute";

type LayerMode = "main" | "branch" | "all";

const KIND_LABELS: Record<string, string> = {
  scene: "场景",
  beat: "分镜",
  choice: "条件",
  action: "玩法",
  phase: "步骤",
  page: "日记",
  entry: "图鉴条目"
};

const KIND_ONTOLOGY: Record<string, { id: string; label: string }> = {
  scene: { id: "ONT-101", label: "故事场景" },
  beat: { id: "ONT-102", label: "故事分镜" },
  choice: { id: "ONT-103", label: "条件选择" },
  action: { id: "ONT-104", label: "玩法动作" },
  phase: { id: "ONT-105", label: "仪式阶段" },
  page: { id: "ONT-106", label: "内容页面" },
  entry: { id: "ONT-107", label: "图鉴条目" }
};

const STATUS_LABELS: Record<string, string> = {
  active: "使用中",
  unlinked: "未关联",
  legacy: "遗留",
  backup: "备份",
  source: "制作源",
  review: "待检查",
  remake: "待重做",
  missing: "缺失"
};

function fileUrl(path: string) {
  return `/api/file?path=${encodeURIComponent(path)}`;
}

interface ProcessingMethodInfo {
  name: string;
  logic: string;
  meaning: string;
  useWhen: string;
  why: string;
}

const PROCESSING_METHODS: Record<string, ProcessingMethodInfo> = {
  "ECSP edge_connected_background + subject_runs + contain_resize + quantize": {
    name: "ECSP 边缘连通保主体切图",
    logic: "从画布边缘清除连通背景，按真实主体间隔分组，等比缩放并限色。",
    meaning: "只擦掉从图片四周连进来的背景，物体内部即使颜色相近也尽量保留。",
    useWhen: "适合物体有把手、细枝或内部图案，机械分格容易把它切断的图片。",
    why: "这类图片最怕误删主体，所以优先保证物体完整，再做缩放。"
  },
  "background_key + crop + resize + quantize": {
    name: "BKE 背景阈值保主体抠图",
    logic: "按登记的背景颜色阈值建立蒙版，裁取主体后缩放并限色。",
    meaning: "把接近指定背景色的像素当作背景删掉，再留下主要物体。",
    useWhen: "适合背景颜色单一，而且与主体颜色差别明显的单件素材。",
    why: "规则简单、速度快；只有背景足够干净时才可靠。"
  },
  "chroma_key + crop + resize + quantize": {
    name: "CKE 色键抠图",
    logic: "移除绿幕等指定色键，按透明主体裁边、缩放并限色。",
    meaning: "像影视绿幕一样，删除事先约定的一种鲜明背景色。",
    useWhen: "适合专门用纯绿、纯蓝等背景生成的单件物体图片。",
    why: "背景色是刻意设计的，与主体差异最大，通常比猜测奶油色背景更安全。"
  },
  "cover_crop + resize + quantize": {
    name: "CCF 居中铺满裁切",
    logic: "保持比例放大至铺满目标画幅，居中裁去溢出区域后限色。",
    meaning: "把图片等比放大到完全盖住画框，多出来的边缘从四周裁掉。",
    useWhen: "适合标题、分镜和仪式特写等必须铺满整块屏幕的画面。",
    why: "可以避免图片被拉变形，也不会留下难看的空白边。"
  },
  procedural: {
    name: "PROC 代码直接绘制",
    logic: "资源没有上游位图，由构建脚本通过绘制指令直接生成。",
    meaning: "这张图不是从原图裁出来的，而是程序用线条、色块等指令画出来的。",
    useWhen: "适合简单标记、数字、规则图形或临时辅助图。",
    why: "内容结构很简单时，代码生成更稳定，也不需要维护一张原图。"
  },
  "slice_first + crop + resize + quantize": {
    name: "FSE 首区块主体切图",
    logic: "从组合图中提取第一个有效区块，裁边、缩放并限色。",
    meaning: "一张图里有多个区块，但这里只取最前面的第一个物体。",
    useWhen: "适合组合图的第一格就是目标，其余格只是参考或备用的情况。",
    why: "需求只涉及第一格，没有必要处理或输出后面的内容。"
  },
  "slice_grid + background_key + crop + resize + quantize": {
    name: "GKE 网格背景切图",
    logic: "按规则网格拆分组合图，每格执行背景阈值抠图、裁边、缩放和限色。",
    meaning: "像切棋盘一样把整张图分成固定行列，再分别去掉每格背景。",
    useWhen: "适合每个物体严格排在大小相同格子里的标准素材表。",
    why: "格子边界已经确定，按网格切最直接，也能保证输出尺寸一致。"
  },
  "slice_runs + background_key + crop + resize + quantize": {
    name: "RBE 列游程背景切图",
    logic: "依据连续前景列自动分组，再逐组执行背景阈值抠图、裁边、缩放和限色。",
    meaning: "从左到右寻找一段段有物体的区域，自动分组后再删除背景。",
    useWhen: "适合多个物体横向排列、间距不完全一致，且背景颜色较干净的图片。",
    why: "物体没有对齐固定网格，按实际空隙寻找边界比平均切开更准确。"
  },
  "slice_runs + crop + resize + quantize": {
    name: "RSE 列游程主体切图",
    logic: "依据连续非背景列识别主体区间，逐个裁边、缩放并限色。",
    meaning: "从左到右寻找连续出现内容的区域，把每一段当成一个独立物体。",
    useWhen: "适合背景已经透明或足够干净、多个物体横向分开放置的图片。",
    why: "不需要再次猜背景，只根据物体之间的空隙分组，步骤更少。"
  }
};

function processingMethodInfo(operation: string) {
  return PROCESSING_METHODS[operation] || {
    name: "未命名处理管线",
    logic: "该处理步骤尚未加入方法目录，需要补充明确名称与算法说明。",
    meaning: "系统识别到了处理记录，但还没有为它写人能理解的解释。",
    useWhen: "暂未登记。",
    why: "暂未登记；出现这种状态时应补充方法说明，而不是猜测。"
  };
}

function ProcessingMethodHelp({ info }: { info: ProcessingMethodInfo }) {
  const anchorRef = useRef<HTMLSpanElement>(null);
  const tooltipId = useId();
  const [open, setOpen] = useState(false);
  const [position, setPosition] = useState({ left: 12, top: 12 });

  const updatePosition = useCallback(() => {
    const rect = anchorRef.current?.getBoundingClientRect();
    if (!rect) return;
    const width = Math.min(280, window.innerWidth - 24);
    const estimatedHeight = 220;
    const left = Math.max(12, Math.min(rect.right - width, window.innerWidth - width - 12));
    const below = rect.bottom + 8;
    const top = below + estimatedHeight <= window.innerHeight
      ? below
      : Math.max(12, rect.top - estimatedHeight - 8);
    setPosition({ left, top });
  }, []);

  useLayoutEffect(() => {
    if (!open) return;
    updatePosition();
    window.addEventListener("resize", updatePosition);
    document.addEventListener("scroll", updatePosition, true);
    return () => {
      window.removeEventListener("resize", updatePosition);
      document.removeEventListener("scroll", updatePosition, true);
    };
  }, [open, updatePosition]);

  return (
    <>
      <span
        ref={anchorRef}
        className="processing-method-help"
        tabIndex={0}
        aria-label={`${info.name}，悬浮或聚焦查看说明`}
        aria-describedby={open ? tooltipId : undefined}
        onMouseEnter={() => setOpen(true)}
        onMouseLeave={() => setOpen(false)}
        onFocus={() => setOpen(true)}
        onBlur={() => setOpen(false)}
      >
        <strong>{info.name}</strong>
        <i aria-hidden="true">?</i>
      </span>
      {open && createPortal(
        <span
          id={tooltipId}
          className="processing-tooltip is-portal"
          role="tooltip"
          style={position}
        >
          <b>它在做什么</b>
          <span>{info.meaning}</span>
          <b>什么时候用</b>
          <span>{info.useWhen}</span>
          <b>为什么选它</b>
          <span>{info.why}</span>
        </span>,
        document.body
      )}
    </>
  );
}

function StoryCard({ data, selected }: NodeProps<Node<FlowNodeData>>) {
  const story = data.story;
  return (
    <article
      className={`story-node kind-${story.kind} ${selected ? "is-selected" : ""}`}
      role="button"
      aria-label={`${story.id} ${story.label}（画布节点，可拖拽）`}
    >
      <span className={`node-object-type object-type-${story.kind}`}>
        {KIND_ONTOLOGY[story.kind]?.label || KIND_LABELS[story.kind]}
      </span>
      <Handle type="target" position={Position.Left} />
      {data.imagePath ? (
        <div className={`node-image image-fit-${data.imageFit || "cover"}`}>
          <img src={fileUrl(data.imagePath)} alt="" loading="lazy" />
        </div>
      ) : (
        <div className="node-image node-image-empty">无画面</div>
      )}
      <div className="node-copy">
        <div className="node-field">
          <span>编号：</span>
          <code>{story.id}</code>
        </div>
        <div className="node-field">
          <span>label：</span>
          <strong>{story.label}</strong>
        </div>
        <div className="node-field">
          <span>subtitle：</span>
          <small>{story.subtitle}</small>
        </div>
      </div>
      <Handle type="source" position={Position.Right} />
    </article>
  );
}

const nodeTypes: NodeTypes = { story: StoryCard };

const EDGE_LEGEND = [
  ["input", "操作输入"],
  ["next", "顺序推进"],
  ["choice", "玩家选择"],
  ["branch", "进入分支"],
  ["condition", "条件判断"],
  ["browse", "浏览条目"],
  ["return", "返回 / 汇合"]
] as const;

async function copyText(text: string) {
  await navigator.clipboard.writeText(text);
}

async function reveal(path: string) {
  const response = await fetch("/api/reveal", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path })
  });
  const data = (await response.json()) as { error?: string };
  if (!response.ok) throw new Error(data.error || "Finder 定位失败");
}

function PathActions({ path, onError }: { path: string; onError: (message: string) => void }) {
  return (
    <span className="path-actions">
      <button onClick={() => window.open(fileUrl(path), "_blank")}>打开</button>
      <button onClick={() => copyText(path).catch((error) => onError(String(error)))}>复制路径</button>
      <button onClick={() => reveal(path).catch((error) => onError(error.message))}>Finder</button>
    </span>
  );
}

function ResourcePreview({ resource }: { resource: ResourceItem }) {
  if (resource.kind === "image") {
    return <img className="resource-preview" src={fileUrl(resource.path)} alt={resource.name} />;
  }
  if (resource.kind === "audio") {
    return <audio className="audio-preview" src={fileUrl(resource.path)} controls preload="none" />;
  }
  if (resource.kind === "font") {
    return <div className="file-placeholder">TTF 字体</div>;
  }
  if (resource.kind === "texture") {
    return <div className="file-placeholder">T3X<br />3DS 纹理</div>;
  }
  return <div className="file-placeholder">文本资源</div>;
}

function CopyEditor({
  entry,
  onSave,
  onError
}: {
  entry: CopyEntry;
  onSave: (entry: CopyEntry, text: string) => Promise<void>;
  onError: (message: string) => void;
}) {
  const [value, setValue] = useState(entry.text);
  const [saving, setSaving] = useState(false);

  useEffect(() => setValue(entry.text), [entry.id, entry.text]);

  const save = async () => {
    setSaving(true);
    try {
      await onSave(entry, value);
    } catch (error) {
      onError(error instanceof Error ? error.message : "文案保存失败");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="copy-editor">
      <textarea value={value} onChange={(event) => setValue(event.target.value)} />
      <div className="copy-editor-meta">
        <code>{entry.path}:{entry.line}</code>
        <button disabled={saving || value === entry.text} onClick={save}>
          {saving ? "保存中…" : "保存到原文件"}
        </button>
      </div>
    </div>
  );
}

interface InspectorProps {
  selection: Selection;
  index: GraphIndex;
  onSelect: (selection: Selection) => void;
  onError: (message: string) => void;
  onReview: (resource: ResourceItem, status: "" | "review" | "remake", note: string) => Promise<void>;
  onCopySave: (node: StoryNode, entry: CopyEntry, text: string) => Promise<void>;
  onOpenOntology: (ontologyId: string) => void;
  onOpenSceneLayout: (sceneNodeId: string) => void;
}

function Inspector({ selection, index, onSelect, onError, onReview, onCopySave, onOpenOntology, onOpenSceneLayout }: InspectorProps) {
  const node = selection?.type === "node"
    ? index.nodes.find((item) => item.id === selection.id)
    : undefined;
  const resource = selection?.type === "resource"
    ? index.resources.find((item) => item.id === selection.id)
    : undefined;
  const [note, setNote] = useState("");

  useEffect(() => {
    setNote(resource?.reviewNote || "");
  }, [resource?.id, resource?.reviewNote]);

  if (!node && !resource) {
    return (
      <aside className="inspector empty-panel">
        <span className="eyebrow">对象详情</span>
        <h2>选择一个节点或资源</h2>
        <p>这里会显示稳定编号、原图、引用关系与本地文件操作。</p>
      </aside>
    );
  }

  if (node) {
    const ontologyType = KIND_ONTOLOGY[node.kind];
    const composition = index.sceneCompositions.find((item) => item.sceneNodeId === node.id);
    const copyEntries = node.copyEntries || [];
    const linked = node.resourceIds
      .map((id) => index.resources.find((item) => item.id === id))
      .filter(Boolean) as ResourceItem[];
    const sourceResources = Array.from(new Set(
      linked.flatMap((item) => item.sourceCandidates)
    ))
      .map((path) => index.resources.find((item) => item.path === path))
      .filter(Boolean) as ResourceItem[];
    const sourceDetails = new Map(sourceResources.map((source) => {
      const links = linked.flatMap((item) => item.provenance || [])
        .filter((link) => link.sources.includes(source.path));
      return [source.path, {
        operations: Array.from(new Set(links.map((link) => link.operation))),
        scripts: Array.from(new Set(links.map((link) => link.scriptPath)))
      }];
    }));
    const proceduralResources = linked.filter((item) =>
      (item.provenance || []).some((link) => link.operation === "procedural")
    );
    const unresolvedSources = linked.filter(
      (item) => item.kind === "image"
        && item.path.startsWith("game/assets/")
        && !item.sourceCandidates.length
        && !(item.provenance || []).some((link) => link.operation === "procedural")
    );
    const processingMethods = Array.from(linked.reduce((methods, item) => {
      (item.provenance || []).forEach((link) => {
        const key = `${link.scriptPath}\0${link.operation}`;
        const method = methods.get(key) || {
          operation: link.operation,
          scriptPath: link.scriptPath,
          resources: [] as ResourceItem[]
        };
        method.resources.push(item);
        methods.set(key, method);
      });
      return methods;
    }, new Map<string, {
      operation: string;
      scriptPath: string;
      resources: ResourceItem[];
    }>()).values());
    const runtimeScene = node.runtimeScene
      ? index.runtimeGraph?.scenes.find((scene) => scene.id === node.runtimeScene)
      : undefined;
    const runtimeIncoming = node.runtimeScene
      ? (index.runtimeGraph?.transitions || []).filter((transition) => transition.to === node.runtimeScene)
      : [];
    const runtimeOutgoing = node.runtimeScene
      ? (index.runtimeGraph?.transitions || []).filter((transition) => transition.from === node.runtimeScene)
      : [];
    return (
      <aside className="inspector">
        <div className="inspector-head">
          <span className="id-badge">{node.id}</span>
          <span>{KIND_LABELS[node.kind]}</span>
        </div>
        <h2>{node.label}</h2>
        <p className="lead">{node.description}</p>
        <dl className="facts">
          <div>
            <dt>对象类型</dt>
            <dd className="ontology-type-value">
              {ontologyType ? (
                <button onClick={() => onOpenOntology(ontologyType.id)}>
                  <strong>{ontologyType.label}</strong>
                  <code>{ontologyType.id}</code>
                  <span>定位本体</span>
                </button>
              ) : (
                <strong>{KIND_LABELS[node.kind]}</strong>
              )}
            </dd>
          </div>
          <div><dt>章节</dt><dd>{node.chapter}</dd></div>
          <div><dt>操作</dt><dd>{node.subtitle}</dd></div>
        </dl>
        {composition && (
          <section className="scene-composition">
            <div className="scene-composition-heading">
              <div>
                <h3>场景构成 · {composition.label}</h3>
                <p className="muted">故事主图只展开到六个资源组；坐标实例在独立布局视图检查。</p>
              </div>
              <button onClick={() => onOpenSceneLayout(node.id)}>打开场景布局视图</button>
            </div>
            <div className="scene-group-list">
              {composition.groups.map((group) => (
                <details key={group.id}>
                  <summary>
                    <span>{group.label}</span>
                    <small>{group.resourceIds.length} 资源 · {group.placements.length} 摆放</small>
                  </summary>
                  <div className="scene-group-resources">
                    {group.resourceIds.map((resourceId) => {
                      const item = index.resources.find((resourceItem) => resourceItem.id === resourceId);
                      return item ? (
                        <button key={resourceId} onClick={() => onSelect({ type: "resource", id: resourceId })}>
                          <ResourcePreview resource={item} />
                          <code>{resourceId}</code>
                          <span>{item.name}</span>
                        </button>
                      ) : null;
                    })}
                  </div>
                </details>
              ))}
            </div>
          </section>
        )}
        {node.runtimeScene && (
          <section>
            <h3>Lua AST 运行时事实</h3>
            <div className="runtime-scene-head">
              <span>runtime scene</span>
              <strong>{node.runtimeScene}</strong>
              <small>{runtimeIncoming.length} 入 / {runtimeOutgoing.length} 出</small>
            </div>
            {!!runtimeScene?.writes.length && (
              <div className="runtime-evidence">
                {runtimeScene.writes.slice(0, 5).map((item) => (
                  <code key={`${item.path}:${item.line}`}>{item.path}:{item.line} · {item.functionName}</code>
                ))}
              </div>
            )}
            <div className="runtime-transitions">
              {runtimeOutgoing.map((transition) => (
                <div key={transition.id}>
                  <strong>{transition.from} → {transition.to}</strong>
                  <span>{transition.events.join(" · ") || "函数调用"}</span>
                  <small>{transition.callChain.join(" → ")}</small>
                </div>
              ))}
            </div>
          </section>
        )}
        {node.runtimeOverlay && (
          <section>
            <h3>Lua 运行时覆盖层</h3>
            <div className="runtime-scene-head">
              <span>runtime overlay</span>
              <strong>{node.runtimeOverlay}</strong>
              <small>跨场景复用</small>
            </div>
            <p className="muted">该节点不属于单一场景；对账时会折叠“场景 → 覆盖层 → 场景”的跳转。</p>
          </section>
        )}
        {!!node.options?.length && (
          <section>
            <h3>本步骤选项（不拆节点）</h3>
            <div className="option-chips">
              {node.options.map((option) => <span key={option}>{option}</span>)}
            </div>
          </section>
        )}
        <section>
          <h3>画面资源预览 · 点击查看详情</h3>
          {linked.length ? (
            <div className="node-resource-grid">
              {linked.map((item, itemIndex) => (
                <button
                  className="node-resource-card"
                  key={item.id}
                  onClick={() => onSelect({ type: "resource", id: item.id })}
                >
                  <ResourcePreview resource={item} />
                  <span>{item.id} · {{
                    "top-preview": "上屏预览",
                    "directory-icon": "目录图标",
                    "catalog-icon": "选项目录图",
                    "top-frame": "上屏分镜",
                    "runtime-media": "运行时资源",
                  }[item.displayRole]}</span>
                  <strong>
                    {!node.assetGlobs?.length && node.options?.length === linked.length
                      ? node.options[itemIndex]
                      : item.name}
                  </strong>
                  {!node.assetGlobs?.length && node.options?.length === linked.length && <small>{item.name}</small>}
                </button>
              ))}
            </div>
          ) : <p className="muted">这个逻辑节点没有独立画面。</p>}
        </section>
        <section>
          <h3>处理方法</h3>
          {processingMethods.length ? (
            <div className="processing-method-list">
              {processingMethods.map((method) => (
                <article key={`${method.scriptPath}:${method.operation}`}>
                  <div>
                    <ProcessingMethodHelp info={processingMethodInfo(method.operation)} />
                    <span className="processing-method-count">{method.resources.length} 个资源</span>
                  </div>
                  <p className="processing-logic">{processingMethodInfo(method.operation).logic}</p>
                  <code>{method.operation}</code>
                  <small>{method.scriptPath}</small>
                  <p className="processing-resources">{method.resources.map((item) => item.id).join("、")}</p>
                </article>
              ))}
            </div>
          ) : (
            <p className="muted">
              {linked.length ? "这些资源尚未登记处理方法。" : "当前节点没有需要处理的画面资源。"}
            </p>
          )}
        </section>
        {!!(sourceResources.length || unresolvedSources.length) && (
          <section>
            <h3>加工原图 / 制作源 · 点击打开</h3>
            <p className="muted">由当前节点全部运行时图片向上追溯并去重；可进入详情后打开原图或在 Finder 中定位。</p>
            {!!sourceResources.length && (
              <div className="node-resource-grid node-source-grid">
                {sourceResources.map((item) => (
                  <button
                    className="node-resource-card"
                    key={item.id}
                    onClick={() => onSelect({ type: "resource", id: item.id })}
                  >
                    <ResourcePreview resource={item} />
                    <span>{item.id} · 制作源</span>
                    <strong>{item.name}</strong>
                    <small>{sourceDetails.get(item.path)?.operations.join(" / ")}</small>
                    <small>{sourceDetails.get(item.path)?.scripts.join("、")}</small>
                  </button>
                ))}
              </div>
            )}
            {!!proceduralResources.length && (
              <div className="source-procedural">
                <strong>代码直接绘制</strong>
                <span>{proceduralResources.map((item) => item.name).join("、")}</span>
              </div>
            )}
            {!!unresolvedSources.length && (
              <div className="source-missing">
                <strong>尚未登记上游原图</strong>
                <span>{unresolvedSources.map((item) => item.name).join("、")}</span>
                <small>这些图片可能由脚本直接绘制，或制作源仍在仓库外。</small>
              </div>
            )}
          </section>
        )}
        <section>
          <h3>完整文案 · 可直接修改</h3>
          {copyEntries.length ? copyEntries.map((entry) => (
            <CopyEditor
              key={entry.id}
              entry={entry}
              onSave={(item, text) => onCopySave(node, item, text)}
              onError={onError}
            />
          )) : <p className="muted">暂未在该节点的代码范围内识别到可编辑文案。</p>}
          {!!copyEntries.length && (
            <p className="copy-warning">保存会精确修改对应 Lua 字符串；新增汉字仍需在发版前检查字体字形。</p>
          )}
        </section>
        <section>
          <h3>代码与设计来源</h3>
          {node.sourcePaths.map((path) => (
            <div className="source-row" key={path}>
              <code>{path}</code>
              <PathActions path={path} onError={onError} />
            </div>
          ))}
        </section>
      </aside>
    );
  }

  if (!resource) return null;
  return (
    <aside className="inspector">
      <div className="inspector-head">
        <span className="id-badge">{resource.id}</span>
        <span className={`status status-${resource.status}`}>{STATUS_LABELS[resource.status]}</span>
      </div>
      <h2>{resource.name}</h2>
      <ResourcePreview resource={resource} />
      <p className="resource-path">{resource.path}</p>
      <PathActions path={resource.path} onError={onError} />
      <dl className="facts">
        <div><dt>类别</dt><dd>{resource.category}</dd></div>
        <div><dt>格式</dt><dd>{resource.kind}</dd></div>
        <div><dt>尺寸</dt><dd>{resource.size ? resource.size.join(" × ") : "—"}</dd></div>
        <div><dt>文件大小</dt><dd>{resourceSortDetail(resource, "size-desc")}</dd></div>
        <div><dt>创建时间</dt><dd>{resourceSortDetail(resource, "created-desc")}</dd></div>
        <div><dt>3DS 纹理</dt><dd>{resource.pairedT3x == null ? "—" : resource.pairedT3x ? "已配对" : "缺失"}</dd></div>
      </dl>
      <section>
        <h3>人工检查</h3>
        <textarea
          value={note}
          onChange={(event) => setNote(event.target.value)}
          placeholder="例如：边缘模糊，建议重新制作"
        />
        <div className="review-actions">
          <button onClick={() => onReview(resource, "review", note).catch((error) => onError(error.message))}>标记待检查</button>
          <button className="danger" onClick={() => onReview(resource, "remake", note).catch((error) => onError(error.message))}>标记待重做</button>
          {(resource.status === "review" || resource.status === "remake") && (
            <button onClick={() => onReview(resource, "", "").catch((error) => onError(error.message))}>清除标记</button>
          )}
        </div>
      </section>
      <section>
        <h3>出现于节点</h3>
        {resource.nodeIds.length ? resource.nodeIds.map((id) => {
          const item = index.nodes.find((candidate) => candidate.id === id);
          return (
            <button className="linked-item" key={id} onClick={() => onSelect({ type: "node", id })}>
              <span>{id}</span><strong>{item?.label || id}</strong>
            </button>
          );
        }) : <p className="muted">尚未与故事节点建立显式关系。</p>}
      </section>
      <section>
        <h3>代码引用</h3>
        {resource.codeRefs.slice(0, 12).map((path) => (
          <div className="source-row" key={path}>
            <code>{path}</code>
            <PathActions path={path} onError={onError} />
          </div>
        ))}
        {!resource.codeRefs.length && <p className="muted">未找到直接字符串引用，可能由动态路径加载。</p>}
      </section>
      {!!resource.sourceCandidates.length && (
        <section>
          <h3>代码声明的制作源</h3>
          {resource.sourceCandidates.map((path) => {
            const source = index.resources.find((item) => item.path === path);
            return (
              <button
                className="linked-item"
                key={path}
                onClick={() => source && onSelect({ type: "resource", id: source.id })}
              >
                <span>{source?.id || "SRC"}</span><strong>{path}</strong>
              </button>
            );
          })}
        </section>
      )}
    </aside>
  );
}

function AuditView({ index, onSelect }: { index: GraphIndex; onSelect: (selection: Selection) => void }) {
  const runtimeMissing = index.audits.runtimeTransitionsMissingInManifest || [];
  const manifestMissing = index.audits.manifestTransitionsMissingInRuntime || [];
  const cards = [
    ["缺失资源", index.audits.missingAssets.length, "manifest 指向不存在的文件"],
    ["断开连线", index.audits.brokenEdges.length, "起点或终点不存在"],
    ["重复节点编号", index.audits.duplicateNodeIds.length, "编号必须保持唯一"],
    ["PNG 缺 T3X", index.audits.missingT3x.length, "3DS 派生纹理不完整"],
    ["未关联资源", index.audits.unlinkedResourceIds.length, "可能动态加载，也可能遗漏"],
    ["遗留资源", index.audits.legacyResourceIds.length, "旧体系或已被替代"],
    ["备份资源", index.audits.backupResourceIds.length, "不进入当前游戏主线"],
    ["未绑定运行时场景", (index.audits.unboundRuntimeScenes || []).length, "Lua 中存在但 manifest 未映射"],
    ["缺失运行时场景", (index.audits.missingRuntimeScenes || []).length, "manifest 映射但 Lua 中未发现"],
    ["代码独有跳转", runtimeMissing.length, "Lua AST 已证明但故事图尚未覆盖"],
    ["设计独有跳转", manifestMissing.length, "故事图声明但 AST 尚未证明"]
  ] as const;
  return (
    <div className="audit-view">
      <header>
        <span className="eyebrow">自动审计</span>
        <h2>故事与资源完整性</h2>
        <p>结构错误为零时，主流程索引可以安全使用；未关联项仍需人工判断。</p>
      </header>
      <div className="audit-grid">
        {cards.map(([label, count, description]) => (
          <article key={label} className={count ? "audit-card has-items" : "audit-card"}>
            <strong>{count}</strong>
            <h3>{label}</h3>
            <p>{description}</p>
          </article>
        ))}
      </div>
      <section className="audit-list">
        <h3>Lua AST：代码存在但故事图缺失</h3>
        {runtimeMissing.length ? runtimeMissing.map((transition) => (
          <div className="runtime-drift-row" key={transition.id}>
            <strong>{transition.from} → {transition.to}</strong>
            <span>{transition.events.join(" · ")}</span>
            <code>
              {transition.evidence[0]
                ? `${transition.evidence[0].path}:${transition.evidence[0].line}`
                : transition.callChain.join(" → ")}
            </code>
          </div>
        )) : <p className="muted">代码运行时跳转已全部被故事图覆盖。</p>}
      </section>
      <section className="audit-list">
        <h3>优先检查：未关联资源</h3>
        {index.audits.unlinkedResourceIds.slice(0, 40).map((id) => {
          const resource = index.resources.find((item) => item.id === id);
          return resource ? (
            <button key={id} onClick={() => onSelect({ type: "resource", id })}>
              <span>{id}</span>{resource.path}
            </button>
          ) : null;
        })}
      </section>
    </div>
  );
}

function SceneLayoutView({
  composition,
  selectedId,
  onSelect
}: {
  composition: SceneComposition;
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  const [groupKey, setGroupKey] = useState("all");
  const groups = groupKey === "all"
    ? composition.groups
    : composition.groups.filter((group) => group.key === groupKey);
  const placements = groups.flatMap((group) => group.placements);
  const scale = 28;
  return (
    <div className="scene-layout-view">
      <header>
        <div>
          <span className="eyebrow">Destination Pack · {composition.key}</span>
          <h2>{composition.label}场景布局</h2>
          <p>25 × 15 格地图；地表、水系与摆放实例由 {composition.source} 确定性物化。</p>
        </div>
        <div className="scene-layout-filter">
          <button className={groupKey === "all" ? "active" : ""} onClick={() => setGroupKey("all")}>全部</button>
          {composition.groups.filter((group) => group.placements.length > 0).map((group) => (
            <button key={group.id} className={groupKey === group.key ? "active" : ""} onClick={() => setGroupKey(group.key)}>
              {group.label} {group.placements.length}
            </button>
          ))}
        </div>
      </header>
      <div className="scene-map-scroll">
        <div className="scene-map" style={{ width: 25 * scale, height: 15 * scale }}>
          {placements.map((placement) => (
            <button
              key={placement.id}
              className={`${placement.layer} ${selectedId === placement.id ? "selected" : ""}`}
              style={{
                left: placement.x * scale,
                top: placement.y * scale,
                width: scale,
                height: scale,
                zIndex: placement.layer === "ground" ? 1 : placement.layer === "overlay" ? 2 : 3
              }}
              title={placement.label}
              onClick={() => onSelect(placement.id)}
            >
              <img src={fileUrl(placement.resourcePath)} alt="" />
            </button>
          ))}
        </div>
      </div>
      <footer>{placements.length} 个可检查摆放实例 · 点击地图资源查看坐标、变体、RES ID 与源码证据</footer>
    </div>
  );
}

function PixelAssetPreview({ path, label }: { path: string; label: string }) {
  const [size, setSize] = useState({ width: 16, height: 16 });
  return (
    <div className="placement-original-preview">
      <div className="pixel-checker">
        <img
          src={fileUrl(path)}
          alt={label}
          style={{ width: size.width * 8, height: size.height * 8 }}
          onLoad={(event) => setSize({
            width: event.currentTarget.naturalWidth,
            height: event.currentTarget.naturalHeight
          })}
        />
      </div>
      <small>原始 {size.width} × {size.height}px · 8× nearest 放大 · 完整不裁切</small>
    </div>
  );
}

function PlacementContextPreview({
  composition,
  placement
}: {
  composition: SceneComposition;
  placement: SceneComposition["groups"][number]["placements"][number];
}) {
  const regionTiles = 5;
  const scale = 3;
  const [imageSize, setImageSize] = useState({ width: composition.mapSize[0] * composition.tileSize, height: composition.mapSize[1] * composition.tileSize });
  const originX = Math.max(0, Math.min(composition.mapSize[0] - regionTiles, placement.x - 2));
  const originY = Math.max(0, Math.min(composition.mapSize[1] - regionTiles, placement.y - 2));
  const frameSize = regionTiles * composition.tileSize * scale;
  if (!composition.contextImagePath) return null;
  return (
    <div className="placement-context-preview">
      <div className="placement-context-frame" style={{ width: frameSize, height: frameSize }}>
        <img
          src={fileUrl(composition.contextImagePath)}
          alt={`${composition.label}场景合成图`}
          style={{
            width: imageSize.width * scale,
            height: imageSize.height * scale,
            left: -originX * composition.tileSize * scale,
            top: -originY * composition.tileSize * scale
          }}
          onLoad={(event) => setImageSize({
            width: event.currentTarget.naturalWidth,
            height: event.currentTarget.naturalHeight
          })}
        />
        <i
          aria-label="当前摆放坐标"
          style={{
            left: (placement.x - originX) * composition.tileSize * scale,
            top: (placement.y - originY) * composition.tileSize * scale,
            width: composition.tileSize * scale,
            height: composition.tileSize * scale
          }}
        />
      </div>
      <small>周围 5 × 5 地块 · 框内为坐标 {placement.x},{placement.y}</small>
    </div>
  );
}

function ScenePlacementInspector({
  composition,
  placement
}: {
  composition: SceneComposition | undefined;
  placement: SceneComposition["groups"][number]["placements"][number] | undefined;
}) {
  if (!composition || !placement) {
    return <aside className="inspector empty-panel"><span className="eyebrow">摆放实例详情</span><h2>选择一个场景资源</h2><p>点击地图中的树木、鸟巢或地块查看原图和场景上下文。</p></aside>;
  }
  const group = composition.groups.find((candidate) =>
    candidate.placements.some((item) => item.id === placement.id)
  );
  const colocatedProps = composition.groups
    .flatMap((candidate) => candidate.placements)
    .filter((candidate) =>
      candidate.x === placement.x
      && candidate.y === placement.y
      && candidate.layer === "prop"
    );
  return (
    <aside className="inspector placement-inspector">
      <div className="inspector-head"><span className="id-badge">{placement.id}</span><span>场景摆放实例</span></div>
      <h2>{placement.label}</h2>
      <p className="lead">{placement.kindLabel}在 {composition.label}地图中的一次确定性摆放；资源文件与地图实例保持独立身份。</p>
      <section>
        <h3>资源定义原图放大预览</h3>
        <PixelAssetPreview path={placement.resourcePath} label={placement.kindLabel} />
      </section>
      <section>
        <h3>场景合成预览</h3>
        <PlacementContextPreview composition={composition} placement={placement} />
        {colocatedProps.length > 1 && (
          <div className="placement-colocated">
            <strong>同坐标叠加资源</strong>
            <div>
              {colocatedProps.map((item) => (
                <article key={item.id}>
                  <img src={fileUrl(item.resourcePath)} alt={item.kindLabel} />
                  <span>{item.kindLabel} · 变体{String(item.variant ?? "—")}</span>
                  <code>{item.resourceId}</code>
                </article>
              ))}
            </div>
          </div>
        )}
      </section>
      <section>
        <h3>摆放数据</h3>
        <dl className="generic-attributes">
          <div><dt>坐标</dt><dd>{placement.x}, {placement.y}</dd></div>
          <div><dt>变体</dt><dd>{String(placement.variant ?? "—")}</dd></div>
          <div><dt>资源 RES ID</dt><dd>{placement.resourceId}</dd></div>
          <div><dt>所属资源组</dt><dd>{group?.label || "—"} · {group?.id || "—"}</dd></div>
          <div><dt>资源路径</dt><dd>{placement.resourcePath}</dd></div>
          <div><dt>摆放层</dt><dd>{placement.layer}</dd></div>
        </dl>
      </section>
      <section>
        <h3>源代码证据</h3>
        {placement.evidence.map((item, index) => (
          <code className="placement-evidence" key={`${String(item.path)}:${index}`}>
            {String(item.path || placement.source)}{item.functionName ? ` · ${String(item.functionName)}()` : ""}
          </code>
        ))}
      </section>
    </aside>
  );
}

export default function App() {
  const initialRouteRef = useRef<ViewRoute | null>(null);
  if (!initialRouteRef.current) {
    initialRouteRef.current = parseViewRoute(
      window.location.search,
      localStorage.getItem("story-atlas:graph-mode")
    );
  }
  const initialRoute = initialRouteRef.current;
  const [index, setIndex] = useState<GraphIndex | null>(null);
  const [loadError, setLoadError] = useState("");
  const [notice, setNotice] = useState("");
  const [view, setView] = useState<ViewMode>(initialRoute.view);
  const [graphMode, setGraphMode] = useState<GraphMode>(initialRoute.graphMode);
  const [layer, setLayer] = useState<LayerMode>(() => {
    const saved = localStorage.getItem("story-atlas:last-layer");
    return saved === "main" || saved === "branch" || saved === "all" ? saved : "main";
  });
  const [destinationFilter, setDestinationFilter] = useState<"all" | "forest" | "coast">("all");
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("all");
  const [status, setStatus] = useState("all");
  const [resourceSort, setResourceSort] = useState<ResourceSortMode>(() => {
    const saved = localStorage.getItem("story-atlas:resource-sort");
    return saved === "resolution-desc" || saved === "size-desc" ? saved : "created-desc";
  });
  const [selection, setSelection] = useState<Selection>(null);
  const [ontologySelection, setOntologySelection] = useState<string>("ONT-000");
  const [customViews, setCustomViews] = useState<CustomViewDefinition[]>([]);
  const [activeCustomViewId, setActiveCustomViewId] = useState<string | null>(initialRoute.customViewId);
  const [customEntitySelection, setCustomEntitySelection] = useState<string | null>(null);
  const [layoutSceneNodeId, setLayoutSceneNodeId] = useState(initialRoute.sceneNodeId);
  const [viewDialogOpen, setViewDialogOpen] = useState(false);
  const [editingCustomView, setEditingCustomView] = useState<CustomViewDefinition | null>(null);
  const [flowInstance, setFlowInstance] = useState<ReactFlowInstance<Node<FlowNodeData>> | null>(null);
  const [ontologyFlowInstance, setOntologyFlowInstance] = useState<ReactFlowInstance<Node<OntologyNodeData>> | null>(null);
  const [pendingFocus, setPendingFocus] = useState<string | null>(null);
  const [pendingOntologyFocus, setPendingOntologyFocus] = useState<string | null>(null);

  useEffect(() => {
    fetch(`/graph-index.json?t=${Date.now()}`, { cache: "no-store" })
      .then((response) => {
        if (!response.ok) throw new Error("请先运行 npm run scan");
        return response.json() as Promise<GraphIndex>;
      })
      .then(setIndex)
      .catch((error) => setLoadError(error.message));
    fetch("/api/views", { cache: "no-store" })
      .then((response) => response.ok ? response.json() : Promise.reject(new Error("读取自定义视图失败")))
      .then((data: { views: CustomViewDefinition[] }) => setCustomViews(data.views))
      .catch((error) => setLoadError(error.message));
  }, []);

  useEffect(() => {
    localStorage.setItem("story-atlas:last-layer", layer);
  }, [layer]);

  useEffect(() => {
    localStorage.setItem("story-atlas:graph-mode", graphMode);
  }, [graphMode]);

  useEffect(() => {
    localStorage.setItem("story-atlas:resource-sort", resourceSort);
  }, [resourceSort]);

  const applyingHistoryRoute = useRef(false);
  const routeMounted = useRef(false);
  const currentRoute: ViewRoute = {
    view,
    graphMode,
    customViewId: activeCustomViewId,
    sceneNodeId: layoutSceneNodeId,
  };
  const currentRouteRef = useRef(currentRoute);
  currentRouteRef.current = currentRoute;

  useEffect(() => {
    const search = serializeViewRoute(currentRouteRef.current, window.location.search);
    const url = `${window.location.pathname}${search}${window.location.hash}`;
    if (!routeMounted.current) {
      routeMounted.current = true;
      window.history.replaceState(null, "", url);
      return;
    }
    if (applyingHistoryRoute.current) {
      applyingHistoryRoute.current = false;
      return;
    }
    if (window.location.search !== search) {
      window.history.pushState(null, "", url);
    }
  }, [view, graphMode, activeCustomViewId, layoutSceneNodeId]);

  useEffect(() => {
    const onPopState = () => {
      const next = parseViewRoute(
        window.location.search,
        localStorage.getItem("story-atlas:graph-mode")
      );
      const current = currentRouteRef.current;
      if (
        next.view === current.view
        && next.graphMode === current.graphMode
        && next.customViewId === current.customViewId
        && next.sceneNodeId === current.sceneNodeId
      ) return;
      applyingHistoryRoute.current = true;
      setView(next.view);
      setGraphMode(next.graphMode);
      setActiveCustomViewId(next.customViewId);
      setLayoutSceneNodeId(next.sceneNodeId);
      setSelection(null);
      setCustomEntitySelection(null);
    };
    window.addEventListener("popstate", onPopState);
    return () => window.removeEventListener("popstate", onPopState);
  }, []);

  const setTransientNotice = useCallback((message: string) => {
    setNotice(message);
    window.setTimeout(() => setNotice(""), 3200);
  }, []);

  const visibleNodes = useMemo(() => {
    if (!index) return [];
    return index.nodes.filter((node) => {
      const coast = node.id.includes("COAST") || node.chapter.startsWith("海边");
      const forest = ["DEST-FOREST", "BEAT-004", "BEAT-005", "SCN-003"].includes(node.id);
      if (destinationFilter === "forest" && coast) return false;
      if (destinationFilter === "coast" && forest) return false;
      if (layer === "all") return true;
      if (layer === "branch") return node.visibility !== "auxiliary";
      return node.visibility === "main";
    });
  }, [index, layer, destinationFilter]);

  const visibleIds = useMemo(() => new Set(visibleNodes.map((node) => node.id)), [visibleNodes]);
  const visibleEdges = useMemo(
    () => index?.edges.filter((edge) => visibleIds.has(edge.source) && visibleIds.has(edge.target)) || [],
    [index, visibleIds]
  );
  const flow = useMemo(() => toFlowElements(visibleNodes, visibleEdges), [visibleNodes, visibleEdges]);
  const [flowNodes, setFlowNodes, onNodesChange] = useNodesState<Node<FlowNodeData>>([]);
  const ontology = useMemo(() => index ? buildOntology(index) : null, [index]);
  const [ontologyNodes, setOntologyNodes, onOntologyNodesChange] = useNodesState<Node<OntologyNodeData>>([]);
  const activeCustomView = customViews.find((item) => item.id === activeCustomViewId);
  const customResult = useMemo(
    () => index && activeCustomView
      ? applyCustomView(activeCustomView, index.instanceGraph.entities, index.instanceGraph.relations)
      : { entities: [], relations: [] },
    [index, activeCustomView]
  );
  const customFlow = useMemo(() => toGenericFlow(
    customResult,
    activeCustomView?.nodeFields || DEFAULT_NODE_FIELDS,
    index?.instanceGraph.entities || [],
    index?.instanceGraph.relations || []
  ), [activeCustomView, customResult, index]);
  const [customFlowNodes, setCustomFlowNodes, onCustomFlowNodesChange] = useNodesState<Node<GenericNodeData>>([]);

  useEffect(() => {
    setCustomFlowNodes(customFlow.nodes);
    setCustomEntitySelection((current) =>
      current && customResult.entities.some((entity) => entity.id === current) ? current : null
    );
  }, [customFlow.nodes, customResult.entities, setCustomFlowNodes]);

  useEffect(() => {
    const key = `story-atlas-layout:${layer}`;
    let saved: Record<string, { x: number; y: number }> = {};
    try {
      saved = JSON.parse(localStorage.getItem(key) || "{}") as Record<string, { x: number; y: number }>;
    } catch {
      saved = {};
    }
    setFlowNodes(flow.nodes.map((node) => (
      saved[node.id] ? { ...node, position: saved[node.id] } : node
    )));
  }, [flow.nodes, layer, setFlowNodes]);

  useEffect(() => {
    if (!ontology) return;
    let saved: Record<string, { x: number; y: number }> = {};
    try {
      saved = JSON.parse(localStorage.getItem("story-atlas-layout:ontology") || "{}") as Record<string, { x: number; y: number }>;
    } catch {
      saved = {};
    }
    setOntologyNodes(ontology.nodes.map((node) => (
      saved[node.id] ? { ...node, position: saved[node.id] } : node
    )));
  }, [ontology, setOntologyNodes]);

  useEffect(() => {
    if (!pendingFocus || !flowInstance || !flowNodes.some((node) => node.id === pendingFocus)) return;
    const node = flowInstance.getNode(pendingFocus);
    if (!node) return;
    void flowInstance.fitView({
      nodes: [node],
      padding: 0.9,
      minZoom: 0.65,
      maxZoom: 0.9,
      duration: 450
    });
    setPendingFocus(null);
  }, [flowInstance, flowNodes, pendingFocus]);

  useEffect(() => {
    if (!pendingOntologyFocus || !ontologyFlowInstance || !ontologyNodes.some((node) => node.id === pendingOntologyFocus)) return;
    const node = ontologyFlowInstance.getNode(pendingOntologyFocus);
    if (!node) return;
    void ontologyFlowInstance.fitView({
      nodes: [node],
      padding: 1.1,
      minZoom: 0.72,
      maxZoom: 0.95,
      duration: 450
    });
    setPendingOntologyFocus(null);
  }, [ontologyFlowInstance, ontologyNodes, pendingOntologyFocus]);

  const saveDraggedNode = useCallback((_: unknown, node: Node<FlowNodeData>) => {
    const key = `story-atlas-layout:${layer}`;
    let saved: Record<string, { x: number; y: number }> = {};
    try {
      saved = JSON.parse(localStorage.getItem(key) || "{}") as Record<string, { x: number; y: number }>;
    } catch {
      saved = {};
    }
    saved[node.id] = { x: node.position.x, y: node.position.y };
    localStorage.setItem(key, JSON.stringify(saved));
    setTransientNotice(`已保存 ${node.id} 的画布位置`);
  }, [layer, setTransientNotice]);

  const saveDraggedOntologyNode = useCallback((_: unknown, node: Node<OntologyNodeData>) => {
    let saved: Record<string, { x: number; y: number }> = {};
    try {
      saved = JSON.parse(localStorage.getItem("story-atlas-layout:ontology") || "{}") as Record<string, { x: number; y: number }>;
    } catch {
      saved = {};
    }
    saved[node.id] = { x: node.position.x, y: node.position.y };
    localStorage.setItem("story-atlas-layout:ontology", JSON.stringify(saved));
    setTransientNotice(`已保存 ${node.id} 的本体布局`);
  }, [setTransientNotice]);

  const resetLayout = useCallback(() => {
    localStorage.removeItem(`story-atlas-layout:${layer}`);
    setFlowNodes(flow.nodes);
    setTransientNotice("已恢复当前层级的自动布局");
  }, [flow.nodes, layer, setFlowNodes, setTransientNotice]);

  const resetOntologyLayout = useCallback(() => {
    if (!ontology) return;
    localStorage.removeItem("story-atlas-layout:ontology");
    setOntologyNodes(ontology.nodes);
    setTransientNotice("已恢复本体视图自动布局");
  }, [ontology, setOntologyNodes, setTransientNotice]);

  const openOntologyType = useCallback((ontologyId: string) => {
    setView("flow");
    setGraphMode("ontology");
    setOntologySelection(ontologyId);
    setPendingOntologyFocus(ontologyId);
  }, []);

  const openOntologyInstance = useCallback((target: OntologyInstanceTarget) => {
    if (target.type === "resource") {
      setView("resources");
      setSelection({ type: "resource", id: target.id });
      return;
    }
    const targetNode = index?.nodes.find((node) => node.id === target.id);
    setView("flow");
    setGraphMode("instance");
    setSelection({ type: "node", id: target.id });
    setPendingFocus(target.id);
    if (targetNode?.visibility === "branch" && layer === "main") setLayer("branch");
    if (targetNode?.visibility === "auxiliary") setLayer("all");
  }, [index, layer]);

  const persistCustomViews = useCallback(async (views: CustomViewDefinition[]) => {
    const response = await fetch("/api/views", {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ views })
    });
    const data = (await response.json()) as { error?: string; views?: CustomViewDefinition[] };
    if (!response.ok) throw new Error(data.error || "保存自定义视图失败");
    setCustomViews(data.views || views);
  }, []);

  const saveCustomView = useCallback(async (definition: CustomViewDefinition) => {
    const next = customViews.some((item) => item.id === definition.id)
      ? customViews.map((item) => item.id === definition.id ? definition : item)
      : [...customViews, definition];
    await persistCustomViews(next);
    setActiveCustomViewId(definition.id);
    setView("custom");
    setViewDialogOpen(false);
    setEditingCustomView(null);
    setTransientNotice(`已保存视图「${definition.name}」`);
  }, [customViews, persistCustomViews, setTransientNotice]);

  const deleteCustomView = useCallback(async (id: string) => {
    const target = customViews.find((item) => item.id === id);
    await persistCustomViews(customViews.filter((item) => item.id !== id));
    localStorage.removeItem(`story-atlas-layout:${id}`);
    if (activeCustomViewId === id) {
      setView("flow");
      setGraphMode("ontology");
      setActiveCustomViewId(null);
    }
    setViewDialogOpen(false);
    setEditingCustomView(null);
    setTransientNotice(`已删除视图「${target?.name || id}」`);
  }, [activeCustomViewId, customViews, persistCustomViews, setTransientNotice]);

  const previewCustomView = useCallback((definition: CustomViewDefinition) => (
    index
      ? applyCustomView(definition, index.instanceGraph.entities, index.instanceGraph.relations)
      : { entities: [], relations: [] }
  ), [index]);

  const categories = useMemo(
    () => index ? Array.from(new Set(index.resources.map((item) => item.category))).sort() : [],
    [index]
  );
  const normalizedQuery = query.trim().toLowerCase();
  const matchingNodes = useMemo(
    () => visibleNodes.filter((node) =>
      !normalizedQuery || [node.id, node.label, node.subtitle, node.chapter]
        .some((value) => value.toLowerCase().includes(normalizedQuery))
    ),
    [visibleNodes, normalizedQuery]
  );
  const matchingOntologyTypes = useMemo(
    () => ontology?.types.filter((item) =>
      !normalizedQuery || [
        item.id,
        item.label,
        item.description,
        item.group,
        ...item.properties,
        ...item.examples.map((example) => example.label)
      ].some((value) => value.toLowerCase().includes(normalizedQuery))
    ) || [],
    [ontology, normalizedQuery]
  );
  const matchingResources = useMemo(
    () => sortResources(index?.resources.filter((resource) => {
      if (category !== "all" && resource.category !== category) return false;
      if (status !== "all" && resource.status !== status) return false;
      return !normalizedQuery || [
        resource.id,
        resource.path,
        resource.name,
        resource.category,
        resource.reviewNote
      ].some((value) => value.toLowerCase().includes(normalizedQuery));
    }) || [], resourceSort),
    [index, normalizedQuery, category, status, resourceSort]
  );
  const displayedResources = useMemo(() => matchingResources.slice(0, 240), [matchingResources]);
  const matchingCustomEntities = useMemo(
    () => customResult.entities.filter((entity) =>
      !normalizedQuery || [entity.id, entity.label, entity.source, entity.ontologyTypeId]
        .some((value) => value.toLowerCase().includes(normalizedQuery))
    ),
    [customResult.entities, normalizedQuery]
  );
  const customSelectedEntity = customResult.entities.find((entity) => entity.id === customEntitySelection);
  const activeComposition = index?.sceneCompositions.find((item) => item.sceneNodeId === layoutSceneNodeId)
    || index?.sceneCompositions[0];
  const layoutSelectedPlacement = activeComposition?.groups
    .flatMap((group) => group.placements)
    .find((placement) => placement.id === customEntitySelection);

  const openSceneLayout = useCallback((sceneNodeId: string) => {
    setLayoutSceneNodeId(sceneNodeId);
    setCustomEntitySelection(null);
    setView("layout");
  }, []);

  const onReview = useCallback(async (
    resource: ResourceItem,
    nextStatus: "" | "review" | "remake",
    note: string
  ) => {
    const response = await fetch("/api/review", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: resource.path, status: nextStatus, note })
    });
    const result = (await response.json()) as { error?: string };
    if (!response.ok) throw new Error(result.error || "保存检查状态失败");
    setIndex((current) => current ? {
      ...current,
      resources: current.resources.map((item) => item.id === resource.id ? {
        ...item,
        status: (nextStatus || item.inferredStatus) as ResourceStatus,
        reviewNote: nextStatus ? note : ""
      } : item)
    } : current);
    setTransientNotice(nextStatus ? `已保存 ${resource.id} 的人工标记` : `已清除 ${resource.id} 的人工标记`);
  }, [setTransientNotice]);

  const onCopySave = useCallback(async (node: StoryNode, entry: CopyEntry, text: string) => {
    const response = await fetch("/api/copy", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        path: entry.path,
        line: entry.line,
        oldText: entry.text,
        newText: text
      })
    });
    const result = (await response.json()) as { error?: string };
    if (!response.ok) throw new Error(result.error || "保存文案失败");
    setIndex((current) => current ? {
      ...current,
      nodes: current.nodes.map((item) => item.id === node.id ? {
        ...item,
        copyEntries: item.copyEntries.map((copy) => copy.id === entry.id ? {
          ...copy,
          text
        } : copy)
      } : item)
    } : current);
    setTransientNotice(`已写回 ${entry.path}:${entry.line}`);
  }, [setTransientNotice]);

  if (loadError) {
    return <main className="fatal"><h1>故事图谱无法启动</h1><p>{loadError}</p></main>;
  }
  if (!index) {
    return <main className="fatal"><h1>正在整理林间路线…</h1></main>;
  }

  return (
    <div className="app-shell">
      <header className="topbar">
        <div className="brand">
          <img src={fileUrl("cia/icon.png")} alt="" />
          <div><span>Camping Trip</span><strong>故事资源图谱</strong></div>
        </div>
        <div className="top-stats">
          <span><b>{index.meta.nodeCount}</b> 剧情对象</span>
          <span><b>{index.meta.resourceCount}</b> 资源对象</span>
          <span><b>{index.meta.edgeCount}</b> 流程关系</span>
        </div>
        <nav className="view-tabs">
          <button className={view === "flow" && graphMode === "ontology" ? "active" : ""} onClick={() => { setView("flow"); setGraphMode("ontology"); }}>本体视图</button>
          <button className={view === "flow" && graphMode === "instance" ? "active" : ""} onClick={() => { setView("flow"); setGraphMode("instance"); }}>故事实例视图</button>
          <button className={view === "layout" ? "active" : ""} onClick={() => openSceneLayout("SCN-003")}>场景布局视图</button>
          <button className={view === "resources" ? "active" : ""} onClick={() => setView("resources")}>资源库实例视图</button>
          {customViews.map((item) => (
            <button key={item.id} className={view === "custom" && activeCustomViewId === item.id ? "active" : ""} onClick={() => { setActiveCustomViewId(item.id); setView("custom"); }}>
              {item.name}
            </button>
          ))}
          <button className="new-view-button" onClick={() => { setEditingCustomView(null); setViewDialogOpen(true); }}>＋ 新建视图</button>
          <button className={view === "audit" ? "active" : ""} onClick={() => setView("audit")}>遗漏审计</button>
        </nav>
      </header>

      <aside className="sidebar">
        <label className="search-box">
          <span>搜索编号、画面或文件</span>
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder={view === "flow" && graphMode === "ontology" ? "例如运行时场景或 ONT-201" : "例如 BEAT-001 或 tent"}
          />
        </label>
        {view === "flow" ? (
          graphMode === "instance" ? (
            <>
              <div className="layer-switch">
                <button className={layer === "main" ? "active" : ""} onClick={() => setLayer("main")}>主线</button>
                <button className={layer === "branch" ? "active" : ""} onClick={() => setLayer("branch")}>含玩法</button>
                <button className={layer === "all" ? "active" : ""} onClick={() => setLayer("all")}>全部</button>
              </div>
              <div className="layer-switch destination-filter">
                <button className={destinationFilter === "all" ? "active" : ""} onClick={() => setDestinationFilter("all")}>全部</button>
                <button className={destinationFilter === "forest" ? "active" : ""} onClick={() => setDestinationFilter("forest")}>林间</button>
                <button className={destinationFilter === "coast" ? "active" : ""} onClick={() => setDestinationFilter("coast")}>海边</button>
              </div>
              <button className="reset-layout" onClick={resetLayout}>重置当前画布布局</button>
              <div className="sidebar-heading">
                <span>剧情索引</span><b>{matchingNodes.length}</b>
              </div>
              <div className="index-list">
                {matchingNodes.map((node) => (
                  <button
                    key={node.id}
                    className={selection?.type === "node" && selection.id === node.id ? "active" : ""}
                    onClick={() => {
                      setSelection({ type: "node", id: node.id });
                      setPendingFocus(node.id);
                      if (node.visibility === "branch" && layer === "main") setLayer("branch");
                      if (node.visibility === "auxiliary") setLayer("all");
                    }}
                  >
                    <span>{node.id}</span><strong>{node.label}</strong><small>{node.chapter}</small>
                  </button>
                ))}
              </div>
            </>
          ) : (
            <>
              <button className="reset-layout ontology-reset-layout" onClick={resetOntologyLayout}>重置本体视图布局</button>
              <div className="sidebar-heading">
                <span>对象类型</span><b>{matchingOntologyTypes.length}</b>
              </div>
              <div className="index-list ontology-index-list">
                {matchingOntologyTypes.map((item) => (
                  <button
                    key={item.id}
                    className={ontologySelection === item.id ? "active" : ""}
                    onClick={() => openOntologyType(item.id)}
                  >
                    <span>{item.id}</span><strong>{item.label}</strong><small>{item.instanceCount} 个实例</small>
                  </button>
                ))}
              </div>
            </>
          )
        ) : view === "layout" && activeComposition ? (
          <>
            <div className="custom-view-summary">
              <strong>{activeComposition.label} · {activeComposition.key}</strong>
              <span>{activeComposition.groups.length} 个构成组 · {activeComposition.groups.reduce((sum, group) => sum + group.placements.length, 0)} 个摆放</span>
              <small>{activeComposition.source}</small>
            </div>
            <div className="layer-switch">
              {index?.sceneCompositions.map((composition) => (
                <button
                  key={composition.id}
                  className={activeComposition.id === composition.id ? "active" : ""}
                  onClick={() => {
                    setLayoutSceneNodeId(composition.sceneNodeId);
                    setCustomEntitySelection(null);
                  }}
                >
                  {composition.label}
                </button>
              ))}
            </div>
            <div className="sidebar-heading"><span>场景构成组</span><b>{activeComposition.groups.length}</b></div>
            <div className="index-list">
              {activeComposition.groups.map((group) => (
                <button
                  key={group.id}
                  className={customEntitySelection === group.id ? "active" : ""}
                  onClick={() => setCustomEntitySelection(group.id)}
                >
                  <span>{group.key.toUpperCase()}</span>
                  <strong>{group.label}</strong>
                  <small>{group.placements.length} 摆放</small>
                </button>
              ))}
            </div>
          </>
        ) : view === "resources" ? (
          <>
            <label className="filter-label">类别
              <select value={category} onChange={(event) => setCategory(event.target.value)}>
                <option value="all">全部类别</option>
                {categories.map((item) => <option key={item} value={item}>{item}</option>)}
              </select>
            </label>
            <label className="filter-label">状态
              <select value={status} onChange={(event) => setStatus(event.target.value)}>
                <option value="all">全部状态</option>
                {Object.entries(STATUS_LABELS).map(([key, value]) => (
                  <option key={key} value={key}>{value}</option>
                ))}
              </select>
            </label>
            <label className="filter-label">排序
              <select
                value={resourceSort}
                onChange={(event) => setResourceSort(event.target.value as ResourceSortMode)}
              >
                <option value="created-desc">创建时间 · 最新优先</option>
                <option value="resolution-desc">分辨率 · 高到低</option>
                <option value="size-desc">资源大小 · 大到小</option>
              </select>
            </label>
            <div className="sidebar-heading">
              <span>资源索引</span><b>{matchingResources.length}</b>
            </div>
            <div className="index-list resource-index-list">
              {displayedResources.map((resource) => (
                <button
                  key={resource.id}
                  className={selection?.type === "resource" && selection.id === resource.id ? "active" : ""}
                  onClick={() => setSelection({ type: "resource", id: resource.id })}
                >
                  <span>{resource.id}</span>
                  <strong>{resource.name}</strong>
                  <small>{resource.category} · {resourceSortDetail(resource, resourceSort)}</small>
                </button>
              ))}
            </div>
          </>
        ) : view === "custom" && activeCustomView ? (
          <>
            <button className="edit-custom-view" onClick={() => { setEditingCustomView(activeCustomView); setViewDialogOpen(true); }}>
              编辑当前视图
            </button>
            <div className="custom-view-summary">
              <strong>{activeCustomView.name}</strong>
              <span>{customResult.entities.length} 个实例 · {customResult.relations.length} 条关系</span>
              <small>{activeCustomView.displayMode}</small>
            </div>
            <div className="sidebar-heading">
              <span>实例索引</span><b>{matchingCustomEntities.length}</b>
            </div>
            <div className="index-list">
              {matchingCustomEntities.slice(0, 300).map((entity) => (
                <button
                  key={entity.id}
                  className={customEntitySelection === entity.id ? "active" : ""}
                  onClick={() => setCustomEntitySelection(entity.id)}
                >
                  <span>{entity.id}</span><strong>{entity.label}</strong>
                  <small>{OBJECT_TYPE_OPTIONS.find(([id]) => id === entity.ontologyTypeId)?.[1] || entity.ontologyTypeId}</small>
                </button>
              ))}
            </div>
          </>
        ) : (
          <div className="audit-nav">
            <p>结构错误</p>
            <strong>{index.audits.missingAssets.length + index.audits.brokenEdges.length}</strong>
            <p>需要人工判断</p>
            <strong>{index.audits.unlinkedResourceIds.length + index.audits.legacyResourceIds.length}</strong>
          </div>
        )}
      </aside>

      <main className="workspace">
        {view === "flow" && graphMode === "instance" && (
          <ReactFlow
            nodes={flowNodes.map((node) => ({
              ...node,
              selected: selection?.type === "node" && selection.id === node.id
            }))}
            edges={flow.edges}
            nodeTypes={nodeTypes}
            onNodesChange={onNodesChange}
            onNodeDragStop={saveDraggedNode}
            onInit={setFlowInstance}
            defaultViewport={{ x: 24, y: 72, zoom: 0.78 }}
            minZoom={0.2}
            maxZoom={1.8}
            onNodeClick={(_, node: Node<FlowNodeData>) => setSelection({ type: "node", id: node.id })}
          >
            <Background gap={24} size={1} />
            <Panel position="top-right" className="edge-legend">
              <strong>连线图例</strong>
              {EDGE_LEGEND.map(([kind, label]) => (
                <span key={kind}>
                  <i className={`legend-line legend-${kind}`} />
                  {label}
                </span>
              ))}
            </Panel>
            <Controls />
          </ReactFlow>
        )}
        {view === "flow" && graphMode === "ontology" && ontology && (
          <ReactFlow
            nodes={ontologyNodes.map((node) => ({
              ...node,
              selected: ontologySelection === node.id
            }))}
            edges={ontology.edges}
            nodeTypes={ontologyNodeTypes}
            onNodesChange={onOntologyNodesChange}
            onNodeDragStop={saveDraggedOntologyNode}
            onInit={setOntologyFlowInstance}
            onNodeClick={(_, node: Node<OntologyNodeData>) => setOntologySelection(node.id)}
            fitView
            fitViewOptions={{
              nodes: ontologyNodes.filter((node) => node.data.ontology.abstract),
              padding: 0.3,
              minZoom: 0.5,
              maxZoom: 0.72
            }}
            minZoom={0.18}
            maxZoom={1.5}
          >
            <Background gap={24} size={1} />
            <Panel position="top-right" className="edge-legend ontology-legend">
              <strong>本体图例</strong>
              <span><i className="legend-line ontology-legend-type" />包含类型</span>
              <span><i className="legend-line ontology-legend-relation" />类型关系</span>
            </Panel>
            <Controls />
          </ReactFlow>
        )}
        {view === "layout" && activeComposition && (
          <SceneLayoutView
            composition={activeComposition}
            selectedId={customEntitySelection}
            onSelect={setCustomEntitySelection}
          />
        )}
        {view === "resources" && (
          <div className="resource-gallery">
            <header>
              <span className="eyebrow">全量资源库</span>
              <h2>{matchingResources.length} 个匹配项</h2>
              <p>
                运行时 PNG 与 T3X 会显示配对状态；制作源和遗留文件保留独立编号。
                {matchingResources.length > displayedResources.length && ` 当前显示前 ${displayedResources.length} 项，请用搜索或筛选继续缩小范围。`}
              </p>
            </header>
            <div className="resource-grid">
              {displayedResources.map((resource) => (
                <button
                  key={resource.id}
                  className={selection?.type === "resource" && selection.id === resource.id ? "selected" : ""}
                  onClick={() => setSelection({ type: "resource", id: resource.id })}
                >
                  <ResourcePreview resource={resource} />
                  <span>{resource.id}</span>
                  <strong>{resource.name}</strong>
                  <small>
                    {STATUS_LABELS[resource.status]} · {resource.category} · {resourceSortDetail(resource, resourceSort)}
                  </small>
                </button>
              ))}
            </div>
          </div>
        )}
        {view === "custom" && activeCustomView && (
          <>
            {(activeCustomView.displayMode === "graph" || activeCustomView.displayMode === "workflow") && (
              <ReactFlow
                nodes={customFlowNodes.map((node) => ({ ...node, selected: customEntitySelection === node.id }))}
                edges={customFlow.edges}
                nodeTypes={genericNodeTypes}
                onNodesChange={onCustomFlowNodesChange}
                onNodeClick={(_, node: Node<GenericNodeData>) => setCustomEntitySelection(node.id)}
                fitView
                fitViewOptions={{ padding: 0.2, minZoom: 0.25, maxZoom: 0.9 }}
                minZoom={0.15}
                maxZoom={1.8}
              >
                <Background gap={24} size={1} />
                <Panel position="top-right" className="custom-view-canvas-summary">
                  <strong>{activeCustomView.name}</strong>
                  <span>{customResult.entities.length} 实例 · {customResult.relations.length} 关系</span>
                </Panel>
                <Controls />
              </ReactFlow>
            )}
            {activeCustomView.displayMode === "grid" && (
              <div className="generic-entity-grid">
                {customResult.entities.map((entity) => (
                  <button key={entity.id} className={customEntitySelection === entity.id ? "selected" : ""} onClick={() => setCustomEntitySelection(entity.id)}>
                    <span>{entity.id}</span>
                    <strong>{entity.label}</strong>
                    <small>{OBJECT_TYPE_OPTIONS.find(([id]) => id === entity.ontologyTypeId)?.[1] || entity.ontologyTypeId}</small>
                    <code>{entity.source}</code>
                  </button>
                ))}
              </div>
            )}
            {activeCustomView.displayMode === "table" && (
              <div className="generic-entity-table-wrap">
                <table className="generic-entity-table">
                  <thead><tr><th>编号</th><th>对象类型</th><th>名称</th><th>数据来源</th><th>关键字段</th></tr></thead>
                  <tbody>{customResult.entities.map((entity) => (
                    <tr key={entity.id} className={customEntitySelection === entity.id ? "selected" : ""} onClick={() => setCustomEntitySelection(entity.id)}>
                      <td><code>{entity.id}</code></td>
                      <td>{OBJECT_TYPE_OPTIONS.find(([id]) => id === entity.ontologyTypeId)?.[1] || entity.ontologyTypeId}</td>
                      <td>{entity.label}</td>
                      <td>{entity.source}</td>
                      <td><code>{JSON.stringify(entity.attributes)}</code></td>
                    </tr>
                  ))}</tbody>
                </table>
              </div>
            )}
          </>
        )}
        {view === "audit" && <AuditView index={index} onSelect={setSelection} />}
      </main>

      {view === "layout" ? (
        <ScenePlacementInspector composition={activeComposition} placement={layoutSelectedPlacement} />
      ) : view === "custom" ? (
        <GenericEntityInspector entity={customSelectedEntity} relations={customResult.relations} />
      ) : view === "flow" && graphMode === "ontology" && ontology ? (
        <OntologyInspector
          selectedId={ontologySelection}
          model={ontology}
          onSelect={openOntologyType}
          onOpenInstance={openOntologyInstance}
        />
      ) : (
        <Inspector
          selection={selection}
          index={index}
          onSelect={setSelection}
          onError={setTransientNotice}
          onReview={onReview}
          onCopySave={onCopySave}
          onOpenOntology={openOntologyType}
          onOpenSceneLayout={openSceneLayout}
        />
      )}
      <CustomViewDialog
        open={viewDialogOpen}
        initial={editingCustomView}
        preview={previewCustomView}
        onClose={() => { setViewDialogOpen(false); setEditingCustomView(null); }}
        onSave={saveCustomView}
        onDelete={editingCustomView ? deleteCustomView : undefined}
      />
      {notice && <div className="notice">{notice}</div>}
    </div>
  );
}
