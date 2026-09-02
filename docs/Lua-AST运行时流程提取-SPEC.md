# Story Atlas — Lua AST 运行时流程提取 SPEC

> 状态：v1 实施规格  
> 日期：2026-09-01  
> 目标：让故事图谱同时展示“设计声明”和“代码可证明事实”，并持续报告两者漂移。

## 1. 背景

当前 Story Atlas 的节点、故事边、说明和章节来自人工维护的
`tools/story-atlas/data/story-manifest.json`。扫描器能发现资源、文案和资产血缘，
但不能证明 manifest 中的场景跳转与 Lua 运行时代码一致。

首版引入真正的 Lua AST 解析，不用正则表达式模拟语法。它负责提取：

- 运行时场景值；
- `Runtime`、`R`、`State` 上的状态字段和明确写入；
- 函数、调用关系和场景赋值；
- 能由调用上下文证明的场景跳转、输入事件和条件；
- 代码运行时图与人工故事图折叠后的差异。

## 2. 原则

1. **事实与设计分层**：AST 结果是代码事实；manifest 仍负责章节、叙事含义和视觉组织。
2. **只报告可证明内容**：动态下标、反射调用、无法静态求值的目标保留为 unresolved，不猜测。
3. **每条事实带证据**：包含文件、行列、所属函数、调用链和提取器版本。
4. **不执行游戏代码**：只读取并解析 Lua；扫描不会触发 LÖVE、文件 IO 副作用或存档。
5. **先对账，不自动改代码**：首版只生成运行时图和审计，不根据推断重写 manifest。

## 3. 权威边界

### 3.1 AST 可作为高置信事实

- `R.scene = "play"`、多重赋值中的同类字面量场景写入；
- `R.scene == "title"`、`or` 组合中的场景条件；
- `Flow.goPlay()` 等可静态解析的成员函数调用；
- `Runtime.scene = "title"` 等初始状态；
- `R.canGoHome = false`、`State.save.data.castChosen = true` 等明确状态写入；
- Lua 表字面量中的初始状态字段；
- 从已知入口上下文，经静态调用链到场景写入形成的转换。

### 3.2 仍属于人工设计声明

- 节点标题、描述、章节、主线/支线层级；
- 一个运行时场景内部应拆成多少分镜、步骤和图鉴条目；
- 玩家体验层面的边标签；
- 多个 Story Atlas 节点与同一 runtime scene 的映射。

### 3.3 首版不做

- 求值任意 Lua 表达式或执行函数；
- 证明随机分支一定可达；
- 展开 metatable、`loadstring`、反射和动态模块名；
- 自动解析每个仪式内部 phase 状态机；
- 自动修改 manifest 或 Lua。

## 4. 提取器架构

新增纯 Node 脚本：

```text
tools/story-atlas/scripts/extract-lua-runtime.mjs
```

使用 `luaparse` 将 `game/**/*.lua` 解析为 AST，输出：

```text
tools/story-atlas/data/lua-runtime-graph.json
```

`npm run scan` 的顺序：

```text
Lua AST 提取 → Python 资源/故事扫描 → graph-index.json
```

Python 扫描器只消费提取结果，不自行重复解析 Lua。

## 5. 输出数据模型

```json
{
  "meta": {
    "schemaVersion": 1,
    "extractorVersion": 1,
    "parser": "luaparse",
    "generatedAt": "ISO-8601",
    "fileCount": 0
  },
  "scenes": [
    {
      "id": "play",
      "declarations": [],
      "reads": [],
      "writes": []
    }
  ],
  "stateVariables": [
    {
      "path": "R.canGoHome",
      "initialValues": [false],
      "writes": []
    }
  ],
  "functions": [
    {
      "id": "game/scene_flow.lua::Flow.goPlay",
      "name": "Flow.goPlay",
      "calls": [],
      "sceneWrites": [],
      "stateWrites": []
    }
  ],
  "transitions": [
    {
      "id": "LUA-TRANS-0001",
      "from": "depart",
      "to": "play",
      "events": ["call:Flow.advanceDepart"],
      "guards": [],
      "callChain": ["Flow.advancePrimary", "Flow.advanceDepart", "Flow.goPlay"],
      "evidence": []
    }
  ],
  "unresolved": []
}
```

所有 evidence 至少包含：

```text
path、line、column、functionName、kind
```

## 6. 静态分析规则

### 6.1 场景发现

场景集合由以下 AST 事实合并：

- `Runtime.scene` / `R.scene` 的字符串字面量赋值；
- `Runtime.scene` / `R.scene` 与字符串字面量的比较；
- manifest 的 runtime scene bindings 仅用于对账，不反向创造 AST 场景。

### 6.2 状态字段

追踪根对象：

```text
Runtime、R、State
```

记录其成员路径的初始化和赋值。局部变量、纯绘制常量和无法恢复稳定成员路径的动态下标不进入权威状态列表。

### 6.3 条件上下文

从 `if / elseif` AST 条件中识别：

- `R.scene == "x"`；
- `R.scene ~= "x"`；
- `and / or` 组合；
- 其他状态条件作为 guard 文本和证据保存。

明确的 scene equality 形成来源场景集合。negative 条件只在场景全集已知时计算补集。

### 6.4 跨函数转换

1. 为每个函数记录直接场景写入和静态函数调用。
2. 从含明确 scene guard 的入口调用点传播来源场景。
3. 固定点迭代调用图，直到函数来源上下文不再变化。
4. 来源场景上下文抵达字符串字面量 scene write 时生成转换。
5. 同场景写入不计作跨场景转换，但保留为 state write。

调用目标必须是可静态解析的标识符或成员路径；动态调用进入 unresolved。

### 6.5 输入事件

首版识别函数入口：

- `Input.onKey` → `keyboard`；
- `Input.onGamepad` → `gamepad`；
- `Input.onBottomTouch` / `Input.onTouch` / `Input.onMouse` → `touch`。

当条件中出现 `key == "a"`、`button == "x"` 等字符串比较时，将其记录为事件。
事件通过调用链传播到最终转换，但不把坐标范围反推成按钮语义。

## 7. manifest 运行时绑定

manifest 新增顶层 `runtimeSceneBindings`：

```json
{
  "title": ["SCN-001"],
  "prologue": ["BEAT-001", "BEAT-002", "BEAT-003", "CHO-001"],
  "cast": ["SCN-002"],
  "depart": ["BEAT-004", "BEAT-005"],
  "play": ["SCN-003", "ACT-001", "PHASE-001"],
  "homecoming": ["BEAT-006"],
  "diary": ["SCN-004", "PAGE-001", "PAGE-002", "PAGE-003"],
  "codex": ["SCN-005", "CODEX-001"],
  "about": ["SCN-006"]
}
```

一个 runtime scene 可以映射多个叙事节点。扫描器把 manifest 边按绑定折叠为场景边，
只比较跨 runtime scene 的转换；同场景内分镜和 phase 边属于设计层，不要求 Lua scene 切换。

跨场景复用、但不改变 `R.scene` 的覆盖层使用独立绑定：

```json
{
  "runtimeOverlayBindings": {
    "quitConfirm": ["CHO-003"]
  }
}
```

覆盖层不能伪装成某一个 runtime scene。扫描器会把
`scene node → overlay node → target scene node` 折叠成场景转换用于对账。

## 8. 审计输出

`graph-index.json.audits` 新增：

- `unboundRuntimeScenes`：代码存在、manifest 未绑定；
- `missingRuntimeScenes`：manifest 绑定、代码未发现；
- `runtimeTransitionsMissingInManifest`：代码可证明但设计图未覆盖；
- `manifestTransitionsMissingInRuntime`：设计声明了跨场景跳转，但 AST 未证明；
- `unresolvedLuaFacts`：动态调用或动态 scene 写入。

审计条目必须保留证据，不能只输出字符串。

首版 `--check` 规则：

- 未绑定或缺失 runtime scene：失败；
- 代码存在但 manifest 缺失的转换：先警告并在 UI 高亮；共享“返回确认”节点完成跨场景建模后再升级为失败；
- manifest 转换未被 AST 证明：先警告。原因是可能存在首版尚未支持的动态模式。

## 9. UI

遗漏审计页展示 AST 审计数量。节点 Inspector 增加：

- 绑定的 runtime scene；
- 该场景的代码声明/写入证据；
- AST 证明的上游和下游场景。

现有人工故事边继续显示，不用 AST 结果覆盖。

## 10. 测试

至少覆盖：

1. 直接 `R.scene = "play"`；
2. 多重赋值 `R.scene, R.codex.i = "codex", 1`；
3. `if R.scene == "title"` 条件；
4. `or` 场景条件；
5. `Input.onKey` 的按键事件；
6. `Flow.advanceDepart → Flow.goPlay` 跨函数传播；
7. 未知动态写入进入 unresolved；
8. manifest 折叠后同 scene 边不参与转换对账；
9. 当前项目所有 runtime scene 有绑定；
10. `npm run scan`、测试、类型检查和生产构建通过。

## 11. 验收标准

- 解析过程不执行任何 Lua；
- 场景集合覆盖当前九个运行时场景；
- 每条转换至少有一个代码证据和调用链；
- Story Atlas 能区分“人工边”与“AST 运行时转换”；
- 当前项目不存在未绑定 runtime scene；
- 对新增 `R.scene = "new_scene"`，下一次扫描能自动发现并进入审计；
- 不再依靠正则表达式判断 Lua 的语法结构。

## 12. 首版实施基线

当前项目提取结果：

- 解析 `game/**/*.lua` 共 35 个文件；
- 发现 9 个运行时场景；
- 发现 97 个状态字段；
- 证明 19 条跨场景转换；
- runtime scene 未绑定与缺失均为 0；
- 发现 4 条代码存在、故事图尚未表达的退出路径：
  `prologue → title`、`cast → title`、`depart → title`、`homecoming → title`。

这 4 条不是提取错误：`Flow.tryBack()` 和二次确认逻辑确实允许中途返回标题。
共享确认节点已绑定为 `quitConfirm` overlay，当前人工图只从营地连接了它；后续应补充其他来源场景到该 overlay 的设计边，而不是复制四个普通剧情节点。
