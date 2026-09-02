# 露营之旅 · 代码注释审计 SPEC

版本：1.0  
状态：首轮审计完成，尚未批量补注释

## 1. 目标

为维护者和 Agent 补足代码中无法仅靠命名推断的背景，包括：

- 为什么采用当前实现。
- LovePotion、Nintendo 3DS、Old 3DS 和双屏运行时限制。
- 状态机入口、退出条件及跨模块副作用。
- 资源构建、CIA、T3X、SD 部署和本地文件写回的安全边界。
- 修改某段代码时必须同时维护的文件和不变量。

本项目不以“每个函数都有中文注释”为目标。简单函数被机械注释后，会增加阅读噪声，并容易在代码变化后留下错误说明。

## 2. 审计评分

“注释必要性”只衡量缺少背景说明时的维护风险，不代表代码质量。

- **5 分——必须补充**：平台约束、安全边界、稳定编号、状态机契约、跨模块副作用；误改可能导致真机启动失败、存档错误或源码误写。
- **4 分——高优先级**：非显然的加载顺序、性能策略、取消/重置语义和布局规则。
- **3 分——按关键函数补充**：模块整体可读，但少数算法、绘制约束或完成回调需要解释。
- **2 分——少量即可**：已有 SPEC 或类型定义能够承担主要说明。
- **1 分——通常不补**：配置表、样式映射、测试用例或自解释数据。
- **0 分——禁止机械补充**：getter、索引移动、路径拼接、简单 hit test 和标准 React 渲染。

评分时综合考虑四项：隐含背景、修改影响范围、运行时风险、现有文档覆盖度。

## 3. 注释写作规则

### 3.1 应写

- 模块顶部写职责、运行环境和权威数据来源。
- 复杂函数上方写目的、前置条件、完成后的副作用和不能破坏的不变量。
- 函数内部只在关键分支前解释原因，例如兼容性、加载顺序、坐标转换或失败回退。
- Python 使用中文 docstring；Lua、TypeScript 和 Shell 使用短块注释。
- 详细流程已经存在于 SPEC 时，代码只写摘要和 `@see` 路径，避免复制整段文档。

### 3.2 不应写

- 不逐行翻译代码。
- 不重复函数名、变量名或用户界面文案。
- 不在数据表每一项旁边重复标签含义。
- 不为简单函数强行写“背景”。
- 不写无法由测试或代码验证的历史猜测。

### 3.3 示例

不推荐：

```lua
-- 移动图鉴索引
runtime.codex.i = runtime.codex.i + delta
```

推荐：

```lua
-- 2/8 都表示可进入的溪面；这里允许通行是为了支持“趟溪”，
-- 不能按普通碰撞地图把所有水格阻挡。
```

## 4. 首轮评分结果

### 4.1 游戏运行时 `game/`

审计基线：35 个 Lua 文件，约 6748 行；现有注释约 40 行，多数只是 SPEC 链接。

**5 分**

- `bindings.lua`：集中注入 host 的原因和各 host 的职责。
- `runtime.lua`：运行态与持久状态边界；真机判定和性能开关。
- `input.lua`：键盘、手柄、触摸和双屏坐标路由；B 键优先级。
- `session.lua`：仪式模块读写运行态的唯一桥接契约；杯与壶的状态链。
- `scene_flow.lua`：新旅程重置、中途退出、日记提交写档的差异。
- `gear_play.lua`：仪式分发、夜间优先动作和帐篷改写地图的副作用。
- `camp_map.lua`：tile 编号语义、可走水面和帐篷地面恢复规则。

**4 分**

- `persist.lua`：手写 JSON 的容错范围、历史上限和写档时机。
- `time.lua`：时段推进对回家条件、BGM、火堆和冻结状态的影响。
- `assets.lua`、`camp_preload.lua`：SD 根目录、懒加载、POT 裁切和真机内存策略。
- `audio.lua`：桌面与真机不同的 BGM、环境音和延迟加载策略。
- `draw/init.lua`：LovePotion 双屏调用与桌面模拟画布。

**3 分**

- 六个仪式模块：不注释每个 phase，只注释 `start`、`finish`、`cancel` 的状态写入。
- `camp_world.lua`、`camp_render.lua`：生态状态机和 Y-sort 绘制顺序。
- `draw/story.lua`、`draw/camp_tiles.lua`：3DS 有效区、日记排版和帐篷落地像素约束。

**0–2 分**

- `scenes/menu.lua`、`scenes/codex.lua`、`scenes/cast.lua`。
- `ui_toast.lua`、`asset_paths.lua` 和简单 getter。
- `PHASES`、菜单项、角色项等自解释数据表。

### 4.2 构建、CIA 与部署

**5 分**

- `scripts/build-cia.sh`：RomFS 双份布局、Title ID、banner 单变量实验和 makerom 参数。
- `cia/info.rsf`：Old 3DS 的 `Legacy / 268MHz / L2 off / Core2 off / 64MB` 约束。

**4 分**

- `scripts/deploy-to-sd.sh`：静态底图→T3X→复制→验证→安全弹出的顺序。
- `scripts/build-3ds-textures.py`：运行时 PNG 筛选、T3X 参数和增量构建。
- `scripts/pad-pot-textures.py`：POT 范围、透明 padding 和目录迁移约束。
- `scripts/build-camp-static-base.py`：512×256 输出与运行时地图同步。
- `scripts/ensure-cia-tools.sh`：macOS 工具编译和 lz11 clang 补丁背景。

**3 分**

- `scripts/verify-3ds-install.py`：检查项分组和每类真机失败的对应原因。
- `scripts/gen_slice_common.py`：背景抠除启发式及帐篷沙色例外。
- `scripts/build-cia-icon.py`：SMDH 48×48、banner 256×128 和硬像素缩放。
- 像素风格审计脚本：阈值含义和资源目录边界。

**1–2 分**

- 一次性迁移脚本、简单资产清单和多数模块专用切片脚本。
- 已有高质量 docstring 的 `build-tent-assets.py` 只需保持，不重复扩写。

### 4.3 故事资源图谱

**5 分**

- `scripts/scan-story-atlas.py`：稳定资源编号、tombstone、PNG/T3X 合并、文案提取和结构审计。
- `tools/story-atlas/server/pathPolicy.ts`：仓库白名单、路径穿越和符号链接逃逸防护。
- `tools/story-atlas/vite.config.ts`：本地 API 只在开发服务器存在；文案精确写回、人工状态写盘和重扫副作用。

**4 分**

- `tools/story-atlas/src/layout.ts`：dagre 左到右布局、return 边不参与排版及关系类型到样式的契约。

**3 分**

- `tools/story-atlas/src/App.tsx`：三套 localStorage 布局、层级过滤、节点聚焦和写回后的内存更新。

**2 分**

- `tools/story-atlas/src/types.ts`：`status` 与 `inferredStatus`、持久编号与扫描期编号的差异。

**0–1 分**

- `main.tsx`、简单 JSX、标签映射、样式声明和路径安全测试用例。

## 5. 建议实施批次

### P0：先建立安全护栏

目标：约 25–35 条高价值注释。

- `game/bindings.lua`
- `game/runtime.lua`
- `game/input.lua`
- `game/session.lua`
- `game/scene_flow.lua`
- `game/gear_play.lua`
- `game/camp_map.lua`
- `scripts/scan-story-atlas.py`
- `tools/story-atlas/server/pathPolicy.ts`
- `tools/story-atlas/vite.config.ts`

### P1：补真机和构建背景

目标：约 25–35 条。

- `scripts/build-cia.sh`
- `cia/info.rsf`
- `scripts/deploy-to-sd.sh`
- `scripts/build-3ds-textures.py`
- `scripts/pad-pot-textures.py`
- `scripts/build-camp-static-base.py`
- `scripts/ensure-cia-tools.sh`
- `game/persist.lua`
- `game/time.lua`
- `game/assets.lua`
- `game/camp_preload.lua`
- `game/audio.lua`

### P2：补玩法完成副作用和绘制约束

目标：约 15–25 条。

- 六个仪式模块的 `start/finish/cancel`。
- `game/camp_world.lua`、`game/camp_render.lua`。
- `game/draw/init.lua`、`game/draw/story.lua`、`game/draw/camp_tiles.lua`。
- `tools/story-atlas/src/layout.ts`、`App.tsx` 和少量类型 JSDoc。

预计用约 65–95 条中文注释覆盖大部分维护风险，而不是覆盖每个函数。

## 6. 审计中发现的同步风险

这些问题不是“缺注释”，但会让新增注释立即过时，应在正式补注释前确认：

- `pad-pot-textures.py` 仍有旧的 `story/` 路径判断，当前资源位于 `scenes/**/story/`。
- `enforce-pixel-style.py`、`patch-story-cast-slots.py`、`build-camp-tiles.py` 存在目录迁移前路径。
- 部分旧文档仍写 New 3DS 的 124MB 配置，现行 CIA 使用 Old 3DS 兼容配置。
- 图鉴“做饭”条目当前文案描述的是扇风，与玩法不一致。

修复这些事实错误与补注释应拆成不同提交，避免把行为改动伪装成文档修改。

## 7. 验收标准

- 注释新增后不改变运行结果、资源产物或存档格式。
- 每条注释至少回答“为什么、受什么限制、会影响什么”中的一个问题。
- P0 完成后，维护者无需先读完全部 SPEC，也能说明一次旅程的状态流、写档时机、帐篷地图副作用、双屏输入和图谱写回边界。
- 注释引用的路径、常量和配置必须由搜索或测试验证。
- 代码变化时，同一提交同步修改相关注释。
- 简单函数不因本计划被强制添加注释。

## 8. 本轮边界

本文件只定义评分、优先级和执行规范。本轮不批量修改源代码注释，不修复审计中发现的行为或路径问题。
