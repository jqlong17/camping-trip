import dagre from "@dagrejs/dagre";
import {
  Handle,
  Position,
  type Edge,
  type Node,
  type NodeProps,
  type NodeTypes
} from "@xyflow/react";
import { useEffect, useMemo, useState } from "react";
import type {
  CustomViewDefinition,
  InstanceEntity,
  InstanceRelation,
  NodeFieldConfig,
  ViewCondition,
  ViewConditionOperator,
  ViewDisplayMode
} from "./types";

export const OBJECT_TYPE_OPTIONS = [
  ["ONT-101", "故事场景"], ["ONT-102", "故事分镜"], ["ONT-103", "条件选择"],
  ["ONT-104", "玩法动作"], ["ONT-105", "仪式阶段"], ["ONT-106", "内容页面"],
  ["ONT-107", "图鉴条目"], ["ONT-201", "运行时场景"], ["ONT-202", "状态变量"],
  ["ONT-108", "目的地"], ["ONT-109", "场景资源组"], ["ONT-110", "场景摆放实例"],
  ["ONT-203", "运行时覆盖层"], ["ONT-301", "图片资源"], ["ONT-302", "音频资源"],
  ["ONT-303", "字体资源"], ["ONT-304", "纹理资源"], ["ONT-305", "文本资源"],
  ["ONT-306", "制作源资源"], ["ONT-401", "可编辑文案"], ["ONT-501", "资产构建管线"]
] as const;

export const RELATION_TYPE_OPTIONS = [
  ["ONT-601", "故事关系"], ["ONT-602", "运行时跳转"], ["ONT-603", "节点使用资源"],
  ["ONT-604", "运行时映射"], ["ONT-605", "资源派生"], ["ONT-606", "管线生成"],
  ["ONT-607", "节点包含文案"]
  ,["ONT-608", "场景采用目的地"], ["ONT-609", "目的地包含资源组"],
  ["ONT-610", "资源组包含定义"], ["ONT-611", "资源组包含摆放"],
  ["ONT-612", "摆放使用资源"]
] as const;

const CONDITION_FIELDS = [
  ["id", "编号"], ["label", "名称"], ["source", "数据来源"], ["entityKind", "实例类别"],
  ["attributes.kind", "kind"], ["attributes.chapter", "章节"], ["attributes.visibility", "可见层级"],
  ["attributes.status", "资源状态"], ["attributes.category", "资源分类"], ["attributes.path", "路径"],
  ["attributes.runtimeScene", "运行时场景"], ["attributes.hasProvenance", "具有制作血缘"]
] as const;

const OPERATORS: Array<[ViewConditionOperator, string]> = [
  ["eq", "等于"], ["neq", "不等于"], ["contains", "包含"], ["in", "属于列表"],
  ["exists", "存在"], ["gt", "大于"], ["lt", "小于"]
];

const DISPLAY_MODES: Array<[ViewDisplayMode, string]> = [
  ["graph", "关系图"], ["workflow", "工作流"], ["grid", "网格"], ["table", "表格"]
];

const NODE_FIELD_SOURCES = [
  ["id", "编号"], ["label", "名称"], ["ontologyTypeId", "对象类型编号"], ["source", "数据来源"],
  ["entityKind", "实例类别"], ["attributes.subtitle", "subtitle"], ["attributes.chapter", "章节"],
  ["attributes.visibility", "可见层级"], ["attributes.description", "描述"],
  ["attributes.path", "文件路径"], ["attributes.status", "资源状态"], ["attributes.category", "资源分类"]
] as const;

const NODE_FIELD_RENDERERS = [
  ["text", "文本"], ["image", "图片"], ["identifier", "编号"], ["badge", "标签"]
] as const;

export const DEFAULT_NODE_FIELDS: NodeFieldConfig[] = [
  { id: "field-id", title: "编号", renderer: "identifier", source: { kind: "field", field: "id" } },
  { id: "field-label", title: "label", renderer: "text", source: { kind: "field", field: "label" } },
  { id: "field-type", title: "对象类型", renderer: "badge", source: { kind: "field", field: "ontologyTypeId" } }
];

export interface CustomViewResult {
  entities: InstanceEntity[];
  relations: InstanceRelation[];
}

function fieldValue(entity: InstanceEntity, field: string): unknown {
  if (field.startsWith("attributes.")) return entity.attributes[field.slice("attributes.".length)];
  return entity[field as keyof InstanceEntity];
}

function matchesCondition(entity: InstanceEntity, condition: ViewCondition) {
  const current = fieldValue(entity, condition.field);
  const expected = condition.value;
  switch (condition.operator) {
    case "eq": return String(current ?? "") === expected;
    case "neq": return String(current ?? "") !== expected;
    case "contains": return String(current ?? "").toLowerCase().includes(expected.toLowerCase());
    case "in": return expected.split(",").map((item) => item.trim()).includes(String(current ?? ""));
    case "exists": return current !== null && current !== undefined && current !== "";
    case "gt": return Number(current) > Number(expected);
    case "lt": return Number(current) < Number(expected);
  }
}

export function applyCustomView(
  view: CustomViewDefinition,
  entities: InstanceEntity[],
  relations: InstanceRelation[]
): CustomViewResult {
  const selected = entities.filter((entity) => {
    const hasType = view.objectTypeIds.includes(entity.ontologyTypeId)
      || entity.roleTypeIds?.some((type) => view.objectTypeIds.includes(type));
    if (!hasType) return false;
    if (!view.conditions.length) return true;
    const results = view.conditions.map((condition) => matchesCondition(entity, condition));
    return view.conditionMode === "any" ? results.some(Boolean) : results.every(Boolean);
  });
  const ids = new Set(selected.map((entity) => entity.id));
  return {
    entities: selected,
    relations: relations.filter((relation) =>
      view.relationTypeIds.includes(relation.ontologyTypeId)
      && ids.has(relation.source)
      && ids.has(relation.target)
    )
  };
}

export interface GenericNodeData extends Record<string, unknown> {
  entity: InstanceEntity;
  fields: Array<{
    config: NodeFieldConfig;
    value: unknown;
  }>;
}

function typeLabel(id: string) {
  return OBJECT_TYPE_OPTIONS.find(([typeId]) => typeId === id)?.[1] || id;
}

export function GenericEntityCard({ data, selected }: NodeProps<Node<GenericNodeData>>) {
  const entity = data.entity;
  return (
    <article className={`generic-entity-node ${selected ? "is-selected" : ""}`}>
      <Handle type="target" position={Position.Left} />
      {data.fields.map(({ config, value }) => {
        const displayValue = config.source.kind === "field" && config.source.field === "ontologyTypeId"
          ? typeLabel(String(value))
          : String(value ?? "—");
        if (config.renderer === "image") {
          return typeof value === "string" && value ? (
            <div className="generic-node-image" key={config.id}>
              <img src={`/api/file?path=${encodeURIComponent(value)}`} alt={config.title} loading="lazy" />
            </div>
          ) : null;
        }
        return (
          <div className={`generic-node-field renderer-${config.renderer}`} key={config.id}>
            <span>{config.title}：</span>
            {config.renderer === "identifier" ? <code>{displayValue}</code>
              : config.renderer === "badge" ? <em>{displayValue}</em>
                : <strong>{displayValue}</strong>}
          </div>
        );
      })}
      <Handle type="source" position={Position.Right} />
    </article>
  );
}

export const genericNodeTypes: NodeTypes = { genericEntity: GenericEntityCard };

function resolveNodeFields(
  entity: InstanceEntity,
  fields: NodeFieldConfig[],
  entities: InstanceEntity[],
  relations: InstanceRelation[]
) {
  const byId = new Map(entities.map((item) => [item.id, item]));
  return fields.map((config) => {
    if (config.source.kind === "field") {
      return { config, value: fieldValue(entity, config.source.field) };
    }
    const source = config.source;
    const relation = relations.find((item) => {
      if (item.ontologyTypeId !== source.relationTypeId) return false;
      if (source.direction === "outgoing" ? item.source !== entity.id : item.target !== entity.id) return false;
      const targetId = source.direction === "outgoing" ? item.target : item.source;
      const candidate = byId.get(targetId);
      return candidate?.ontologyTypeId === source.targetTypeId
        || candidate?.roleTypeIds?.includes(source.targetTypeId);
    });
    const targetId = relation ? (source.direction === "outgoing" ? relation.target : relation.source) : undefined;
    const target = targetId ? byId.get(targetId) : undefined;
    return {
      config,
      value: target ? fieldValue(target, source.targetField) : undefined
    };
  });
}

export function toGenericFlow(
  result: CustomViewResult,
  fields: NodeFieldConfig[],
  allEntities: InstanceEntity[],
  allRelations: InstanceRelation[]
) {
  const graph = new dagre.graphlib.Graph().setDefaultEdgeLabel(() => ({}));
  graph.setGraph({ rankdir: "LR", ranksep: 90, nodesep: 35, marginx: 45, marginy: 45 });
  const width = 226;
  const height = fields.some((field) => field.renderer === "image") ? 190 : 126;
  result.entities.forEach((entity) => graph.setNode(entity.id, { width, height }));
  result.relations.forEach((relation) => graph.setEdge(relation.source, relation.target));
  dagre.layout(graph);
  const nodes: Array<Node<GenericNodeData>> = result.entities.map((entity) => {
    const point = graph.node(entity.id) || { x: 0, y: 0 };
    return {
      id: entity.id,
      type: "genericEntity",
      position: { x: point.x - width / 2, y: point.y - height / 2 },
      data: { entity, fields: resolveNodeFields(entity, fields, allEntities, allRelations) }
    };
  });
  const edges: Edge[] = result.relations.map((relation) => ({
    id: relation.id,
    source: relation.source,
    target: relation.target,
    label: relation.label,
    type: "default",
    className: `custom-relation relation-${relation.ontologyTypeId.toLowerCase()}`
  }));
  return { nodes, edges };
}

function toggle(values: string[], value: string) {
  return values.includes(value) ? values.filter((item) => item !== value) : [...values, value];
}

function emptyView(): CustomViewDefinition {
  return {
    id: `VIEW-${Date.now().toString(36).toUpperCase()}`,
    name: "",
    objectTypeIds: ["ONT-101"],
    relationTypeIds: ["ONT-601"],
    conditionMode: "all",
    conditions: [],
    displayMode: "workflow",
    nodeFields: DEFAULT_NODE_FIELDS.map((field) => ({ ...field, source: { ...field.source } }))
  };
}

export function CustomViewDialog({
  open,
  initial,
  preview,
  onClose,
  onSave,
  onDelete
}: {
  open: boolean;
  initial: CustomViewDefinition | null;
  preview: (view: CustomViewDefinition) => CustomViewResult;
  onClose: () => void;
  onSave: (view: CustomViewDefinition) => Promise<void>;
  onDelete?: (id: string) => Promise<void>;
}) {
  const [draft, setDraft] = useState<CustomViewDefinition>(emptyView);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    if (open) {
      setDraft(initial ? {
        ...initial,
        conditions: initial.conditions.map((item) => ({ ...item })),
        nodeFields: (initial.nodeFields || DEFAULT_NODE_FIELDS).map((field) => ({ ...field, source: { ...field.source } }))
      } : emptyView());
      setError("");
    }
  }, [open, initial]);
  const result = useMemo(() => preview(draft), [draft, preview]);
  if (!open) return null;

  const save = async () => {
    if (!draft.name.trim()) return setError("请填写视图名称");
    if (!draft.objectTypeIds.length) return setError("至少选择一种对象类型");
    if (!draft.nodeFields.length) return setError("至少配置一个节点字段");
    if ((draft.displayMode === "graph" || draft.displayMode === "workflow") && !draft.relationTypeIds.length) {
      return setError("关系图或工作流至少选择一种关系类型");
    }
    setSaving(true);
    try {
      await onSave({ ...draft, name: draft.name.trim() });
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "保存失败");
    } finally {
      setSaving(false);
    }
  };
  const updateRelationField = (
    index: number,
    change: Partial<Extract<NodeFieldConfig["source"], { kind: "relation" }>>
  ) => {
    const field = draft.nodeFields[index];
    if (field.source.kind !== "relation") return;
    const nodeFields = [...draft.nodeFields];
    nodeFields[index] = { ...field, source: { ...field.source, ...change } };
    setDraft({ ...draft, nodeFields });
  };

  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={(event) => {
      if (event.target === event.currentTarget) onClose();
    }}>
      <section className="custom-view-dialog" role="dialog" aria-modal="true" aria-label="配置自定义视图">
        <header>
          <div><span>视图配置</span><h2>{initial ? "编辑视图" : "新建视图"}</h2></div>
          <button onClick={onClose}>关闭</button>
        </header>
        <div className="dialog-content">
          <label className="dialog-field">视图名称
            <input value={draft.name} maxLength={40} onChange={(event) => setDraft({ ...draft, name: event.target.value })} placeholder="例如：手冲资源血缘" />
          </label>

          <fieldset>
            <legend>显示的对象类型</legend>
            <div className="checkbox-grid">
              {OBJECT_TYPE_OPTIONS.map(([id, label]) => (
                <label key={id}><input type="checkbox" checked={draft.objectTypeIds.includes(id)} onChange={() => setDraft({ ...draft, objectTypeIds: toggle(draft.objectTypeIds, id) })} /><span>{label}</span><code>{id}</code></label>
              ))}
            </div>
          </fieldset>

          <fieldset>
            <legend>条件</legend>
            <div className="condition-toolbar">
              <select value={draft.conditionMode} onChange={(event) => setDraft({ ...draft, conditionMode: event.target.value as "all" | "any" })}>
                <option value="all">全部满足</option><option value="any">任一满足</option>
              </select>
              <button onClick={() => setDraft({ ...draft, conditions: [...draft.conditions, { field: "label", operator: "contains", value: "" }] })}>添加条件</button>
            </div>
            <div className="condition-list">
              {draft.conditions.map((condition, index) => (
                <div key={`${condition.field}-${index}`}>
                  <select value={condition.field} onChange={(event) => {
                    const conditions = [...draft.conditions]; conditions[index] = { ...condition, field: event.target.value }; setDraft({ ...draft, conditions });
                  }}>{CONDITION_FIELDS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select>
                  <select value={condition.operator} onChange={(event) => {
                    const conditions = [...draft.conditions]; conditions[index] = { ...condition, operator: event.target.value as ViewConditionOperator }; setDraft({ ...draft, conditions });
                  }}>{OPERATORS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select>
                  <input value={condition.value} disabled={condition.operator === "exists"} onChange={(event) => {
                    const conditions = [...draft.conditions]; conditions[index] = { ...condition, value: event.target.value }; setDraft({ ...draft, conditions });
                  }} placeholder="条件值" />
                  <button onClick={() => setDraft({ ...draft, conditions: draft.conditions.filter((_, itemIndex) => itemIndex !== index) })}>删除</button>
                </div>
              ))}
            </div>
          </fieldset>

          <fieldset>
            <legend>关系类型</legend>
            <div className="checkbox-grid relation-checkbox-grid">
              {RELATION_TYPE_OPTIONS.map(([id, label]) => (
                <label key={id}><input type="checkbox" checked={draft.relationTypeIds.includes(id)} onChange={() => setDraft({ ...draft, relationTypeIds: toggle(draft.relationTypeIds, id) })} /><span>{label}</span><code>{id}</code></label>
              ))}
            </div>
          </fieldset>

          <fieldset>
            <legend>节点字段配置</legend>
            <p className="fieldset-hint">字段按下方顺序显示在节点卡片中。关系查询无需把目标资源加入当前视图。</p>
            <div className="node-field-list">
              {draft.nodeFields.map((field, index) => (
                <div className="node-field-row" key={field.id}>
                  <div className="node-field-order">
                    <b>{index + 1}</b>
                    <button disabled={index === 0} title="上移" onClick={() => {
                      const nodeFields = [...draft.nodeFields];
                      [nodeFields[index - 1], nodeFields[index]] = [nodeFields[index], nodeFields[index - 1]];
                      setDraft({ ...draft, nodeFields });
                    }}>↑</button>
                    <button disabled={index === draft.nodeFields.length - 1} title="下移" onClick={() => {
                      const nodeFields = [...draft.nodeFields];
                      [nodeFields[index], nodeFields[index + 1]] = [nodeFields[index + 1], nodeFields[index]];
                      setDraft({ ...draft, nodeFields });
                    }}>↓</button>
                  </div>
                  <label>字段标题
                    <input value={field.title} maxLength={30} onChange={(event) => {
                      const nodeFields = [...draft.nodeFields];
                      nodeFields[index] = { ...field, title: event.target.value };
                      setDraft({ ...draft, nodeFields });
                    }} />
                  </label>
                  <label>数据来源
                    <select value={field.source.kind === "field" ? `field:${field.source.field}` : "relation"} onChange={(event) => {
                      const nodeFields = [...draft.nodeFields];
                      nodeFields[index] = event.target.value === "relation"
                        ? {
                            ...field,
                            renderer: "image",
                            source: {
                              kind: "relation", relationTypeId: "ONT-603", direction: "outgoing",
                              targetTypeId: "ONT-301", targetField: "attributes.path", take: "first"
                            }
                          }
                        : { ...field, source: { kind: "field", field: event.target.value.slice("field:".length) } };
                      setDraft({ ...draft, nodeFields });
                    }}>
                      {NODE_FIELD_SOURCES.map(([value, label]) => <option value={`field:${value}`} key={value}>{label}</option>)}
                      <option value="relation">通过关系查询</option>
                    </select>
                  </label>
                  <label>渲染方式
                    <select value={field.renderer} onChange={(event) => {
                      const nodeFields = [...draft.nodeFields];
                      nodeFields[index] = { ...field, renderer: event.target.value as NodeFieldConfig["renderer"] };
                      setDraft({ ...draft, nodeFields });
                    }}>
                      {NODE_FIELD_RENDERERS.map(([value, label]) => <option value={value} key={value}>{label}</option>)}
                    </select>
                  </label>
                  {field.source.kind === "relation" && (
                    <div className="relation-field-query">
                      <span>沿</span>
                      <select value={field.source.relationTypeId} onChange={(event) => {
                        updateRelationField(index, { relationTypeId: event.target.value });
                      }}>{RELATION_TYPE_OPTIONS.map(([value, label]) => <option value={value} key={value}>{value} {label}</option>)}</select>
                      <select value={field.source.direction} onChange={(event) => {
                        updateRelationField(index, { direction: event.target.value as "outgoing" | "incoming" });
                      }}><option value="outgoing">沿出边</option><option value="incoming">沿入边</option></select>
                      <span>找到</span>
                      <select value={field.source.targetTypeId} onChange={(event) => {
                        updateRelationField(index, { targetTypeId: event.target.value });
                      }}>{OBJECT_TYPE_OPTIONS.map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select>
                      <span>取第一条的</span>
                      <select value={field.source.targetField} onChange={(event) => {
                        updateRelationField(index, { targetField: event.target.value });
                      }}>{NODE_FIELD_SOURCES.map(([value, label]) => <option value={value} key={value}>{label}</option>)}</select>
                    </div>
                  )}
                  <button className="remove-node-field" onClick={() => setDraft({
                    ...draft,
                    nodeFields: draft.nodeFields.filter((_, fieldIndex) => fieldIndex !== index)
                  })}>删除</button>
                </div>
              ))}
            </div>
            <button disabled={draft.nodeFields.length >= 10} onClick={() => setDraft({
              ...draft,
              nodeFields: [...draft.nodeFields, {
                id: `field-${Date.now().toString(36)}`,
                title: "字段",
                renderer: "text",
                source: { kind: "field", field: "label" }
              }]
            })}>+ 添加字段</button>
          </fieldset>

          <fieldset>
            <legend>展示方式</legend>
            <div className="display-mode-grid">
              {DISPLAY_MODES.map(([id, label]) => (
                <label key={id}><input type="radio" name="display-mode" checked={draft.displayMode === id} onChange={() => setDraft({ ...draft, displayMode: id })} /><strong>{label}</strong></label>
              ))}
            </div>
          </fieldset>
        </div>
        <footer>
          <span>当前匹配 <b>{result.entities.length}</b> 个实例、<b>{result.relations.length}</b> 条关系</span>
          <div>
            {initial && onDelete && <button className="danger-button" onClick={() => void onDelete(initial.id)}>删除视图</button>}
            <button onClick={onClose}>取消</button>
            <button className="primary-button" disabled={saving} onClick={() => void save()}>{saving ? "保存中…" : "保存视图"}</button>
          </div>
          {error && <p>{error}</p>}
        </footer>
      </section>
    </div>
  );
}

export function GenericEntityInspector({
  entity,
  relations
}: {
  entity: InstanceEntity | undefined;
  relations: InstanceRelation[];
}) {
  if (!entity) return <aside className="inspector empty-panel"><span className="eyebrow">实例详情</span><h2>选择一个实例</h2><p>这里会显示统一实例图中的字段、来源和关系。</p></aside>;
  const linked = relations.filter((relation) => relation.source === entity.id || relation.target === entity.id);
  return (
    <aside className="inspector">
      <div className="inspector-head"><span className="id-badge">{entity.id}</span><span>{typeLabel(entity.ontologyTypeId)}</span></div>
      <h2>{entity.label}</h2>
      <p className="lead">数据来源：{entity.source}</p>
      {entity.ontologyTypeId === "ONT-110" && typeof entity.attributes.resourcePath === "string" && (
        <img
          className="placement-resource-preview"
          src={`/api/file?path=${encodeURIComponent(entity.attributes.resourcePath)}`}
          alt={entity.label}
        />
      )}
      <section><h3>实例字段</h3><dl className="generic-attributes">
        {Object.entries(entity.attributes).map(([key, value]) => <div key={key}><dt>{key}</dt><dd>{typeof value === "object" ? JSON.stringify(value) : String(value ?? "—")}</dd></div>)}
      </dl></section>
      <section><h3>关联关系 · {linked.length}</h3><div className="generic-relations">
        {linked.slice(0, 80).map((relation) => <div key={relation.id}><code>{relation.id}</code><strong>{relation.label}</strong><small>{relation.source} → {relation.target}</small></div>)}
      </div></section>
    </aside>
  );
}
