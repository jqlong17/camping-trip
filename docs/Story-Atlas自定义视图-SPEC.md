# Story Atlas 自定义视图 SPEC

## 1. 目标

Story Atlas 将“本体”和“实例视图”统一成可配置的查询模型。固定入口为：

1. 本体视图：显示对象类型、关系类型及类型间关系。
2. 故事实例视图：显示叙事对象与故事关系，保留主线、含玩法、全部预设。
3. 资源库实例视图：显示媒体资源实例，默认使用网格。
4. 自定义视图：用户选择对象类型、条件、关系类型与展示方式。

遗漏审计是质量工具，不属于实例视图，保留独立入口。

## 2. 统一实例图

扫描器在 `graph-index.json` 中生成 `instanceGraph`：

- `entities`：所有可独立查询的实例。
- `relations`：端点明确、来源可追溯的实例关系。

实体必须包含：

- `id`：实例稳定编号或 canonical ID。
- `ontologyTypeId`：所属对象类型。
- `label`：面向界面的名称。
- `entityKind`：story、resource、runtimeScene、runtimeState、runtimeOverlay、copy、pipeline。
- `attributes`：可筛选字段。
- `source`：事实来源。

关系必须包含：

- `id`、`ontologyTypeId`、`source`、`target`、`label`。
- `attributes` 与可选 `evidence`。
- source/target 必须存在于 entities；无法证明端点的事实进入 audit，不生成伪关系。

首版关系类型：

- ONT-601 故事关系
- ONT-602 运行时跳转
- ONT-603 节点使用资源
- ONT-604 运行时映射
- ONT-605 资源派生
- ONT-606 管线生成
- ONT-607 节点包含文案

## 3. 视图配置

项目级自定义视图存储在 `tools/story-atlas/data/custom-views.json`，纳入版本管理。

每个视图包含：

- `id`：`VIEW-` 前缀的稳定 ID。
- `name`：1–40 字。
- `objectTypeIds`：具体对象类型多选。
- `relationTypeIds`：关系类型多选。
- `conditionMode`：`all` 或 `any`。
- `conditions`：字段、操作符和值。
- `displayMode`：`graph`、`workflow`、`grid`、`table`。

支持的条件操作符：

- `eq`、`neq`
- `contains`
- `in`
- `exists`
- `gt`、`lt`

关系图和工作流采用诱导子图：先按对象类型和条件选择实体，再保留两端都在结果集中的所选关系。系统不自动补齐未选择类型的端点，避免视图结果超出用户配置。

## 4. 展示约束

- `graph`：通用关系图，允许多种关系。
- `workflow`：有向关系工作流，使用 Dagre 从左到右布局。
- `grid`：平铺实例，不显示连线。
- `table`：按编号、类型、名称和关键属性显示。
- 空结果必须解释是对象条件为空，还是所选关系没有完整端点。
- 自定义图节点使用通用卡片；选择后右侧显示字段、来源及关联关系。

## 5. 持久化与安全

- `/api/views` 只读写固定的 `custom-views.json`。
- 服务端执行完整 schema 校验，不接受任意路径。
- 最多 24 个自定义视图、每个最多 12 个条件。
- 写入使用临时文件加 rename，避免部分写入。
- 删除视图只删除配置与对应本地布局，不删除实例数据。
- 顶部视图必须写入 URL 查询参数：固定视图使用 `view`，场景布局附加 `scene`，
  自定义视图附加 `customView`；刷新、分享链接及浏览器前进/后退须恢复对应视图。

## 6. 固定视图等价配置

- 故事实例视图：ONT-101…107 + ONT-601；`visibility` 由主线/含玩法/全部预设控制；workflow。
- 资源库实例视图：ONT-301…305；无关系；grid。
- 本体视图继续使用类型图，不通过实例查询模拟。

## 7. 验收

- 三个固定视图顺序和命名正确。
- 新建视图弹窗可配置全部字段，并显示匹配实例/关系数量。
- 自定义视图刷新后仍存在，可编辑和删除。
- 每个固定/自定义标签 URL 不同，直接访问与浏览器历史导航均能恢复。
- 统一实例图的实体 ID 唯一，所有关系端点存在。
- 本体与实例之间的双向定位、文案编辑、资源审查和遗漏审计无回归。
