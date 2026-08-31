# 露营之旅 — 游戏设计 SPEC

> 状态：设计定稿中（2026-08-30）  
> 平台：Nintendo 3DS Homebrew（LovePotion / LÖVE）  
> 类型：休闲 · 一日露营模拟 · 爱好向（不上架）

正式中文名：**露营之旅**  
曾用名 / 电脑仓库：`linjian`（林间一夜）。对玩家统一用 **露营之旅** / **Camping Trip**；真机 Homebrew 目录与 CIA 文件名用 `CampingTrip`，不用拼音。

---

## 1. 体验一句话

一个夏天上班族，周末逃离城市，带着咖啡器具与露营装备来到有小河的林间；从清晨玩到夜里，点起露营灯过夜，第二天收拾行李回家——**下一周周末再来**，装备与小目标略有不同。

偏 **慢节奏休闲**：不拼操作、不战斗，重点是人物、咖啡道具、帐篷与光线氛围。

---

## 2. 3DS 双屏与「首页」约定

典型 3DS 自制/正版流程：

1. **标题画面（Title）** ← 进入游戏后的第一屏  
2. 主菜单（开始 / 继续 / 图鉴等）  
3. 游戏本体（上屏世界 + 下屏 UI）

### 2.1 标题画面（必做）

| 屏 | 内容 |
|----|------|
| **上屏 400×240** | 漂亮的林间/河岸背景图（可有轻微视差或光影呼吸）；大标题「露营之旅」；小副标如「Weekend Escape」或「夏天 · 林间」 |
| **下屏 320×240** | 菜单：`开始旅程` / `继续`（有存档时） / `装备图鉴` / `关于`；触摸或十字键选择，A 确认 |

参考氛围：午后金光透过树叶、河面反光、角落一角帐篷剪影——**先卖情绪，再进玩法**。

标题页可循环短 BGM（可选，后期）。

### 2.2 游戏中双屏分工

| 屏 | 职责 |
|----|------|
| 上屏 | 俯视 2.5D 像素营地（类三角力量透视感，非林克）：走路、互动、时间光线 |
| 下屏 | 背包 / 当前动作 / 简短提示；触摸选装备、点「点火」「手冲」等 |

---

## 3. 叙事与循环结构

### 3.0 整局流程图（已拍板 · 2026-08-30 · DEV-050 修订）

玩家可见完整一局（**首次**）=
**标题 → 序章 → 选角色 → 出发 → 营地 → 回家 → 书桌日记（存档）→ 标题**。

第二次及以后：**跳过选角色**（可用「切换角色」改）；回家后仍写日记并累计存档。

```mermaid
flowchart TD
  Title[标题画面] -->|开始旅程| Prologue[序章分镜加自言自语按A]
  Prologue -->|首次| Cast[选角色]
  Prologue -->|已有角色| Depart
  Cast -->|确认| Depart[出发过渡]
  Depart --> Camp[抵达营地像素玩法]
  Camp --> DayCycle[白天到夜里点灯]
  DayCycle --> Home[回家过渡]
  Home --> Diary[书桌日记=存档]
  Diary --> Title
```

| 序号 | 场景 ID | 内容 | 上屏 | 下屏 |
|------|---------|------|------|------|
| 1 | `title` | 标题菜单 | 标题风景 + 游戏名 | 开始 / 继续 / 切换角色 / 图鉴 / 关于 |
| 2 | `prologue` | **故事序章** | 文生图分镜（一张一张） | 「A 继续」或台词框；按 A / 触摸下一句 |
| 3 | `cast` | **选角色（仅首次，或从切换角色进入）** | 当前角色大立绘/像素放大 + 短介绍 | 角色列表点选；确认键 |
| 4 | `depart` | **出发过渡** | 文生图 2 张左右（出门→林道） | 可自动或按 A |
| 5 | `play` | 营地本体 | 俯视像素林间 | 背包 / 互动 / 本趟收获条 |
| 6 | `homecoming` | **回家过渡** | 文生图 1～2 张 + 短结算句 | 按 A 进入日记 |
| 7 | `diary` | **书桌日记（存档）** | 日记本/书桌分镜 | 本趟收获 + 累计；A 保存并回标题 |

### 3.0.1 序章对话稿（初稿，可改）

分镜与台词一一对应；**按 A** 前进（真机 A / 触摸下屏）。

| 镜号 | 图资产（建议） | 台词（自言自语） |
|------|----------------|------------------|
| P1 | `story_p1_weekend.png` | 「……终于周末了。」 |
| P2 | `story_p2_pack.png` | 「电脑关上。咖啡器具、帐篷……都带上。」 |
| P3 | `story_p3_door.png` | 「去有小河的那片林子吧。」 |
| P4 | （可复用 P3 或淡出） | 「走。」→ 进入选人 |

### 3.0.2 选角色

- 使用 `docs/characters/summer_v2_*` 角色池（约 9 人）。  
- **首次**：序章后进入选人；确认后写入存档 `castId` / `castChosen=true`。  
- **之后出发**：序章结束后**直接出发**，不再每次选人。  
- **切换角色**：标题菜单独立入口；改完只更新存档角色，不强制立刻进营地。  
- 下屏点选，上屏预览；首次确认后进入出发过渡。

### 3.0.4 营地收获（DEV-050）

| 行为 | 触发 | 限制 | 下屏 |
|------|------|------|------|
| **摘果** | 靠近挂果树按 A（优先于普通装备使用） | 每棵有果树本趟有限（约 1～2 个）；采完提示「这棵没了」 | 收获条显示果子图标与数量 |
| **钓鱼** | 溪边选钓竿 + A | 4 帧仪式；有概率空竿，成功则随机鱼种入账 | 收获条显示鱼种与条数 |
| **手冲/喝咖啡** | 已有 | 配方手冲 + 一壶 3 口；喝空可再冲 | 计入本趟 `coffee` |

**鱼种（初版）**：`ayu` 香鱼 · `trout` 溪鳟 · `carp` 鲤鱼。  
本趟收获存在 `tripHaul`；回家日记写入累计 `totals`。

钓鱼仪式图须与手冲同级：**120×76 硬像素特写**（上屏 ×2 nearest），禁止继续放大糊掉的 56×48 小图。

### 3.0.5 书桌日记 = 存档（DEV-050）

- 回家分镜结束后进入 `diary`，不要直接回标题。  
- 上屏：日记本/书桌分镜 `story/diary.png`（文生图 → 硬像素管线）。  
- 下屏：本趟摘要（果子 / 各鱼种 / 咖啡）+ 累计（露营次数、总果子、总鱼、总咖啡）。  
- 按 A：写入 `save.json`，回标题；「继续」在有存档时可用（再来一个周末，沿用角色）。  
- 存档字段最少包含：`castId`、`castChosen`、`trips`、`totals`、`lastTrip`、`history`（最近若干趟）。

### 3.0.3 文生图分镜规范

- 用途：序章 / 出发 / 回家的**情绪过场**，不是营地玩法贴图。  
- 画幅：按 3DS 上屏约 **400×240（≈5:3）** 构图。  
- **风格锚点（已拍板 · DEV-036）**：运行时全是 **16-bit 硬像素**。题材可参考 `docs/storyboards/style_ref_desired.jpg` / `docs/mockups/`，**禁止把写实厚涂原样进游戏**。  
  - 要：限色（全屏 ≤64 色）、大色块、nearest、一眼能认。  
  - 不要：照片、体积光油画、高斯模糊、抗锯齿脏边。  
  - 管线：构图可文生 → cover 到 400×240 → **可 200×120 再 ×2 nearest** → median-cut 32–48 色 → `scripts/audit-pixel-style.py` 通过才进 `game/assets/story/`。  
  - Skill：`.cursor/skills/linjian-pixel-style/`。

### 3.1 营地内一日流程（play 段）

```mermaid
flowchart LR
  Arrive[抵达林间] --> Day[白天活动]
  Day --> Dusk[黄昏]
  Dusk --> Night[夜里点灯]
  Night --> Morning[次日清晨]
  Morning --> Pack[收拾]
```

| 阶段 | 时间感 | 玩家在做什么 |
|------|--------|--------------|
| 抵达林间 | 清晨～上午 | 走到空地，展开帐篷 |
| 白天活动 | 上午～下午 | 手冲、河边、可选钓鱼 |
| 黄昏 | 傍晚 | 小锅、收束 |
| 夜晚 | 夜里 | **点亮露营灯** |
| 次日清晨 | 早晨 | 起床短演出 |
| 收拾回家 | — | 收帐篷 → 进入 `homecoming` |

### 3.2 多周末循环（meta）

- 每结束一局 = 「又过了一个周末」。
- **下一局装备略有差异**（休闲重复可玩性）：
  - 咖啡豆：浅烘 / 深烘 / 果香水洗 等（影响手冲文案与杯面颜色）
  - 本周末小目标：想钓鱼、想多喝两杯、想早点点灯看星星
  - 可选：背包多一件小道具（扇子、折叠椅等）
- 不做硬核资源管理；失败条件尽量无（最多「灯没点就睡」给温柔吐槽）。

---

## 4. 核心玩法支柱

1. **移动探索**：十字键在林间空地 / 河岸走动（范围小而精，不开放大地图）。  
2. **装备互动**：下屏选中装备 → 上屏对目标点 A 使用（搭帐篷、手冲、点灯…）。  
3. **时间推进**：一天内时段变化（见下）；关键行动或「发呆/等待」推进时间。  
4. **仪式节点**：搭帐篷、手冲一杯、**夜里点露营灯**、次日收摊回家。

非目标：战斗、复杂 RPG 数值、多结局压力。

---

## 5. 时间与光线

上屏 HUD 显示时段（文字 + 小图标即可），例如：

`清晨 → 上午 → 午后 → 黄昏 → 入夜 → 深夜 → 黎明`

| 时段 | 光线倾向 | 备注 |
|------|----------|------|
| 清晨 | 冷蓝雾、长影 | 抵达 / 次日起床 |
| 上午 | 清亮绿 | 搭帐篷、散步 |
| 午后 | 暖黄 | 手冲、河边 |
| 黄昏 | 橙粉 | 收束白天 |
| 入夜 | 深蓝紫 | **可点露营灯** |
| 深夜 | 更暗 + 灯晕 | 休息 |
| 黎明 | 渐亮 | 收拾 |

实现建议（技术）：全局色调叠加（multiply / 半透明色层）+ 灯具局部亮斑；不必真动态全局光。

---

## 6. 角色与美术重点（优先打磨）

### 6.0 完成度目标（已拍板）

- **不对标抄袭**三角力量（A Link to the Past）的具体素材/角色，但**细节与丰富度**要对齐那个量级：地砖有层次、物件不「复读同一棵树」、角色与道具有轮廓光/内阴影/小饰品。  
- **当前画面**（营地色块→早期像素）属于 **功能原型 / 灰盒可玩**，离目标还差一整条美术管线，属正常阶段。  
- 推荐工具：**不强制 Aseprite**（收费）。本项目默认由 Agent 用脚本直接产出 PNG 像素资源进 `game/assets/`，电脑 `love game` 预览即可。若你愿手绘，任意免费工具（LibreSprite / Piskel / Photopea）均可。  
- **资源要先在电脑设计好**再进 `game/assets/`；不要指望在真机上边玩边捏像素。真机只做最终观感验收。  
- 丰富度清单（验收用，非一次做完）：
  1. **Tileset**：草地至少 4～8 变体 + 河岸转角/直边套件 + 浅滩；树 2～3 冠型、可叠层。  
  2. **道具**：帐篷分部件（布面褶皱、门帘、地钉）；手冲分 V60/分享壶/粉层；杯子有液面高光。  
  3. **角色**：四向（或至少左右）走帧；服装缝线、背包扣、鞋底泥点等「闲笔」。  
  4. **场景点缀**：野花、落叶、河面碎光动画 2～3 帧、营火/灯晕。  
  5. **下屏 UI**：羊皮纸纹理、选中框 9-slice、图标独立绘制而非占位块。  
- 制作顺序建议：先 **tileset + 河岸**（一眼变丰富）→ **帐篷/咖啡道具** → **角色动画** → 标题大图精修。  
- 参考：`docs/mockups/` 定情绪；`docs/characters/summer_v2_*` 定人物方向；玩法参考三角力量的是 **透视与信息密度**，题材仍是现代露营。

### 6.1 人物

- 主角：夏天上班族露营造型（现有 summer_v2 角色池可继续用）。  
- **细节优先**：眼镜反光、背包带、袖口卷起、草帽檐、鞋底泥点等。  
- 支持多角色外观（图鉴可选），玩法共用。  
- 四向走（或至少左右翻面 + 前后帧）后期补。  
- **已落地（DEV-023）**：见 [动画与交互-SPEC.md](./动画与交互-SPEC.md)；`c{N}_walk.png` 四向×3 帧；手冲三步仪式；帐篷地图开合。

### 6.2 咖啡道具（招牌细节）

- 手冲壶 / V60 / 分享壶 / 杯子分层绘制。  
- 不同豆子 → 粉层色、汤色、品鉴短句不同。  
- 手冲已落地为多参数配方 + 三步冲煮；工程见 [手冲模块-SPEC.md](./手冲模块-SPEC.md)（`game/drip_brew.lua`）。扩展豆子/滤杯改 catalog + PNG，勿再堆 `main.lua` 分支。

### 6.3 帐篷

- 搭起 / 收起两态；夜灯模式下帐内透光。  
- 门帘、防风绳、地钉等像素点缀。

### 6.4 场景

- 林间空地 + **小河**（右岸或穿场）。  
- 标题背景：可单独高完成度插画/像素大图（400×240 + 下屏呼应）。  
- 参考：`docs/mockups/` 午后等概念图；运行时像素风对齐 `docs/characters/summer_v2_*`。

---

## 7. 界面与存档（摘要）

- **标题菜单**：开始 / 继续 / 图鉴 / 关于。  
- **下屏背包**：本周末携带清单；选中高亮；短说明。  
- **存档**：一档即可（周末序号、装备变体、是否完成点灯）。放 LovePotion `identity` 目录。

---

## 8. 分阶段交付（建议）

| 阶段 | 内容 | 验收 | 状态 |
|------|------|------|------|
| **P0** | 标题画面 + 开始进入现有营地原型；中文 UI | 电脑 `love game` / 真机可进标题再进营地 | **已接入标题页（2026-08-30）** |
| **P1** | 时段切换 + 光线罩；HUD 时间 | 可从午后推到入夜 | 待做 |
| **P2** | 搭帐篷 / 手冲 / **点露营灯** 三件互动 | 夜里点灯有明显反馈 | 待做 |
| **P3** | 次日收拾 → 回城短过场 → 回标题；周末循环 + 豆子变体 | 完整一局闭环 | 待做 |
| **P4** | 角色/咖啡/帐篷细节美术；标题精美背景；可选 BGM | 观感达到「愿意发给朋友」 | 待做 |

下一优先：**P1 时段与光线**。

---

## 9. 技术约束（提醒）

- 引擎：LovePotion 3.0.2；预览：桌面 LÖVE 11。  
- 中文：真机 `chinese` 系统字体；桌面 `game/fonts/zh-ui.ttf`（新增文案需扩展子集字形）。  
- 部署：`.3dsx` + `game/`；暂不打 CIA。  
- 细节见 [项目背景.md](../项目背景.md)。

---

## 10. 开放决策（已拍板）

| 项 | 决定 |
|----|------|
| 玩家可见名称 | **露营之旅** |
| 第一屏 | **标题画面**（上图下文菜单） |
| 核心仪式 | 搭帐篷、手冲、夜里点灯、次日回家 |
| 重复可玩 | 周末循环 + 装备/豆子小差异 |
| 调性 | 休闲、夏天、上班族减压，不虐 |
| 音乐 | **精简为 3 首 BGM**（标题 / 白天营地 / 夜里）+ **游戏音效（SFX）**；见 §11。黄昏/回城等轨不做。 |

---

## 11. 音频设计（精简版）

### 11.1 结论（2026-08-30 拍板）

**不需要 8 首 BGM。** 小品体量够用的是：

| 类型 | ID | 文件 | 状态 | 何时播 |
|------|-----|------|------|--------|
| BGM | **01 标题** | `audio/bgm_01_title.mp3` | ✅ 已接入 | 标题画面循环 |
| BGM | **02 白天** | `audio/bgm_02_morning.mp3` | ✅ 已接入 | 「开始旅程」后营地白天循环（清晨～黄昏可共用这一首） |
| BGM | **03 夜里** | `audio/bgm_03_night.mp3` | ✅ 已接入（《夜营灯光》） | 入夜 / 深夜循环；黎明切回白天曲 |
| SFX | 见下表 | `audio/sfx_*.wav` | ✅ 清单齐 | UI / 脚步 / 帐篷 / 手冲 / 杯子 / 扇子 / 点灯 |
| 环境音 | 鸟 / 虫 / 溪 | `audio/amb_*.mp3` | ✅ 营地循环垫底 | 白天鸟鸣 · 夜里虫鸣 · 溪水常垫 |

原先草案里的黄昏 / 回城 / 手冲专用 BGM / 次日曲 **全部取消**；氛围靠 **换 BGM + SFX + 光线** 即可。

**BGM vs 音效：**

- **BGM**：长时间垫在底下的情绪床（少、能 loop）。  
- **SFX**：玩家一操作就响一声的反馈——露营小品里 **SFX 往往比多几首 BGM 更「像游戏」**。优先做 SFX。

### 11.2 夜里 BGM · 已完成

成品：`game/audio/bgm_03_night.mp3`（《夜营灯光》）。玩法中 `X` 推进到「入夜/深夜」时自动切换；「黎明」切回白天曲。
### 11.3 音效清单（SFX · 优先于再搓 BGM）

| ID | 触发 | 听感参考 | 来源建议 |
|----|------|----------|----------|
| `sfx_ui_ok` | 菜单确认 / 分镜翻页 / 选角确认 | 按钮 click | ✅ `sfx_ui_ok.wav`（Freesound original_sound UI clicks，裁短） |
| `sfx_ui_move` | 菜单上下移 / 选角移动 / 选背包格 | 软 menu tick | ✅ `sfx_ui_move.wav`（Freesound morganpurkis menu-selection） |
| `sfx_step` | 走一格 | 草鞋 / 软土（可 2～3 变体轮换） | ✅ `sfx_step.wav`（Freesound giocosound footstep_grass_5） |
| `sfx_tent` | 搭/收帐篷 | 布面抖开、拉链轻响 | ✅ `sfx_tent.wav`（Freesound kevinkace canvas-tent-4） |
| `sfx_pour` | 手冲注水 | 细水流进滤杯 | ✅ `sfx_pour.wav`（Freesound mullnet pouring_water） |
| `sfx_cup` | 端杯 / 喝一小口反馈 | 瓷杯轻碰 | ✅ `sfx_cup.wav`（Freesound that_finn light-ceramic-cling） |
| `sfx_lantern` | **点亮露营灯** | 咔嗒 + 极短暖嗡（仪式感） | ✅ `sfx_lantern.wav`（Freesound tbrook switch-light-06） |
| `sfx_fan` | 扇一下（可选） | 短风声 | ✅ `sfx_fan.wav`（Freesound liferecorded_archive ceiling-fan，裁短淡出） |

### 11.3b 环境氛围音（ambience · 营地垫底）

长素材已裁成 **24～30 秒** 循环 MP3（mono / 22.05kHz / 64kbps），只在 `play` 与 BGM 叠播、音量更低：

| ID | 文件 | 何时 | 来源 |
|----|------|------|------|
| `amb_birds` | `audio/amb_birds.mp3` | 营地白天（清晨～黄昏、黎明） | guillermo_de_la_matera 鸟鸣林 |
| `amb_crickets` | `audio/amb_crickets.mp3` | 入夜 / 深夜 | felixblume 夜虫 |
| `amb_creek` | `audio/amb_creek.mp3` | 营地全程垫溪水 | robertcrosley 小溪 |

SFX **不必用 Suno**（不擅长短反馈音）。放入 `game/audio/`，P2 互动时挂上。

#### 免费音效网站（推荐）

下载前看每条的 **License**（CC0 最省事；CC-BY 需署名，可在游戏「关于」里写）。

| 网站 | 说明 |
|------|------|
| [Freesound](https://freesound.org/) | 最大社区库；搜 `footsteps grass` / `fabric` / `water pour` / `click soft`；筛 **CC0** |
| [Kenney.nl](https://kenney.nl/assets?q=audio) | 游戏向打包音效，多为 CC0，UI/点击类很全 |
| [OpenGameArt](https://opengameart.org/) | 游戏素材站，音效分类多，注意许可证标签 |
| [Sonniss GDC](https://sonniss.com/gameaudiogdc/) | 每年 GDC 免费大包（体量大，偶尔有环境/道具声） |
| [Pixabay Sound Effects](https://pixabay.com/sound-effects/) | 注册后可下，商用友好（看站内条款） |
| [Mixkit](https://mixkit.co/free-sound-effects/) | 免费音效，条款相对宽松 |
| [BBC Sound Effects](https://sound-effects.bbcrewind.co.uk/) | 海量环境声；**个人/教育等用途受限**，商用要另看条款——爱好向自用一般可查 |

本游戏实用搜索词（英文）：`soft ui click`、`footstep grass`、`tent fabric`、`zipper short`、`water pour cup`、`ceramic tap`、`lantern switch` / `light switch soft`、`whoosh short`。

裁短到 **0.1～0.5 秒**（点灯可稍长），导出 **WAV 或短 MP3**，命名与上表 ID 一致。
### 11.4 旧 8 轨草案

已废弃，不再要求制作。历史提示词若需可查 git；以本精简表为准。

---

## 12. 开发日志（时间顺序 · 标准编号）

> 规则：主线动作用 **`DEV-XXX`** 递增编号；同日多条按实际顺序。后续 Agent **先读最新编号**，再改代码。  
> 状态：`done` / `wip` / `planned`

| 编号 | 日期 | 状态 | 动作摘要 |
|------|------|------|----------|
| **DEV-001** | 2026-08-30 | done | 建立 LovePotion 营地原型（`game/main.lua` 色块地图 + 下屏背包） |
| **DEV-002** | 2026-08-30 | done | 拷贝至 SD `3ds/linjian/`；澄清跑 `.3dsx` 非 FBI/CIA |
| **DEV-003** | 2026-08-30 | done | 真机 HB「无法运行」→ 升级 Luma 13.4 + hbmenu；备份 `_backup_boot_2019` |
| **DEV-004** | 2026-08-30 | done | 修复 `dspfirm.cdc not found`（Dump DSP） |
| **DEV-005** | 2026-08-30 | done | 真机首次跑通原型画面 |
| **DEV-006** | 2026-08-30 | done | 持久化 `项目背景.md` + README 索引 |
| **DEV-007** | 2026-08-30 | done | 桌面 LÖVE 预览；中文字体 `zh-ui.ttf`；像素 assets 接入 |
| **DEV-008** | 2026-08-30 | done | 美术迭代（树深度、岸边、背包图标等） |
| **DEV-009** | 2026-08-30 | done | 定名 **露营之旅**；撰写本 SPEC（完整体验） |
| **DEV-010** | 2026-08-30 | done | **P0** 标题画面（`title_top`/`title_bot` + 菜单 → 营地） |
| **DEV-011** | 2026-08-30 | done | 本 SPEC 写入 **Suno BGM 提示词**（§11）与开发日志制度（§12） |
| **DEV-011b** | 2026-08-30 | done | 明确美术目标：细节丰富度对标三角力量量级（不抄素材）；资源须本地设计后预览再上机（§6.0） |
| **DEV-017** | 2026-08-30 | done | **美术管线落地（无 Aseprite）**：8 草地、4 水动画、河岸套件、3 树、2 石、细化帐篷/道具/角色；邻接岸线绘制 + 水面相位；`love game` 预览 |
| **DEV-018** | 2026-08-30 | done | **自测流程**：`love game --playtest`；文档 `docs/怎么玩.md`；约定此后每次优化必跑 |
| **DEV-015a** | 2026-08-30 | done | 接入标题 BGM：`bgm_01_title.mp3`（《River Camp Echoes》） |
| **DEV-015b** | 2026-08-30 | done | 接入白天 BGM：`bgm_02_morning.mp3`（《Dawn Creek Camp》） |
| **DEV-015c** | 2026-08-30 | done | **音频精简**：只需再做夜里 1 首 BGM + SFX（§11 重写）；取消多轨草案 |
| **DEV-015d** | 2026-08-30 | done | 接入夜里 BGM：`bgm_03_night.mp3`（《夜营灯光》）；入夜/深夜自动切换，黎明回白天曲 |
| **DEV-015e** | 2026-08-30 | done | 接入 UI SFX：`sfx_ui_ok` / `sfx_ui_move`（morganpurkis menu-selection）；标题菜单、选角、分镜确认、选背包格 |
| **DEV-015f** | 2026-08-30 | done | `sfx_ui_ok` 换为按钮 click（original_sound UI clicks）；`sfx_ui_move` 仍用 menu-selection |
| **DEV-015g** | 2026-08-30 | done | 接入 `sfx_cup`（that_finn ceramic cling）；手冲入杯/第一口、杯子道具 |
| **DEV-015h** | 2026-08-30 | done | 接入 `sfx_fan`（ceiling-fan 裁短淡出）；扇风仪式开始与第 3 步 |
| **DEV-015i** | 2026-08-30 | done | **SFX 自检**：发现 `sfx_fan` 曾导出为静音并修复；削波 UI/灯轻微压峰；清单 8 条均已加载且有触发 |
| **DEV-015j** | 2026-08-30 | done | 营地环境音：`amb_birds` / `amb_crickets` / `amb_creek`（长素材裁 24～30s 循环）；白天鸟·夜里虫·溪水常垫 |
| **DEV-019** | 2026-08-30 | done | 整局流程 §3.0；分镜风格：题材参考 `style_ref_desired.jpg`，**最终过场用强降采样旧屏版 `*_3ds.png`**（更糊、限色、大色块） |
| **DEV-020** | 2026-08-30 | done | **完整周末环落地**：`prologue`→`cast`→`depart`→`play`→`homecoming`→标题；旧屏分镜 `assets/story/`；九人角色 `assets/cast/`；营地时段/光线罩/点灯/回家；playtest 全流程 PASS |
| **DEV-021** | 2026-08-30 | done | 分镜可读修复：去掉强降采样+强模糊；改为 400×240 轻像素管线，重新导出 `assets/story/` |
| **DEV-022** | 2026-08-30 | done | 九人角色像素重做：成块色块+清噪；`assets/cast/c1–c9`；选人/营地整数倍 nearest 缩放 |
| **DEV-023** | 2026-08-30 | done | **细节层**：四向行走表；帐篷开合；手冲三步仪式+地图蒸汽；`docs/动画与交互-SPEC.md`；Skill `linjian-camping-3ds`；playtest 扩展 PASS |
| **DEV-024** | 2026-08-30 | done | **发版脚本**：`scripts/deploy-to-sd.sh` 同步 SD 并自动打 `linjian.cia`（FBI）；`build-cia.sh` / `ensure-cia-tools.sh` |
| **DEV-025** | 2026-08-30 | done | **营地美化**：蜿蜒可趟小溪、8 种树/灌木/花/芦苇、浅滩、偶尔小鱼跃出；清像素贴图替换 |
| **DEV-026** | 2026-08-30 | done | **细节精修**：九人真四向走帧；手冲三步细像素特写；钓鱼/扇子 4 帧短动画仪式；playtest PASS |
| **DEV-027** | 2026-08-30 | done | **标题首图重做**：上屏林间营地细像素风景；下屏羊皮纸菜单底；旧版备份 `title_*_v1.png` |
| **DEV-028** | 2026-08-30 | done | **营地对标效果图**：统一草地亮度去棋盘；分层树冠+落影；河岸转角；水格同相位；帐篷/营火/树桩重切；`scripts/build-camp-tiles.py` |
| **DEV-029** | 2026-08-30 | done | **对标复盘再修**：泥地空场、溪靠右+踏脚石+码头、树影偏右下、静水波、背包藤框羊皮纸；补字体「包」 |
| **DEV-030** | 2026-08-30 | done | **分镜字幕**：台词与「按 A 继续」不再叠框，并入同一底栏 |
| **DEV-031** | 2026-08-30 | done | **装备图鉴落地**：六件装备上屏说明 + 下屏点选翻页；B 返回；playtest `09_codex` |
| **DEV-032** | 2026-08-30 | done | **关于页**：上屏作品说明 + 下屏周末要点；B 返回；playtest `10_about` |
| **DEV-033** | 2026-08-30 | done | **营地生趣**：鱼跃更勤；三种鸟栖枝/落地/飞回；部分树有巢；蝶、蜻蜓、夜里萤火虫 |
| **DEV-034** | 2026-08-30 | done | **手冲特写改像素**：三步改为 16-bit 大色块，×2 nearest，与营地/钓鱼扇子一致 |
| **DEV-035** | 2026-08-30 | done | **夜晚氛围**：色罩后画硬像素星星/十字亮星、偶发流星拖尾、萤火虫亮点；树冠随风轻晃；落叶粒子；入夜提示「抬头有星星」 |
| **DEV-036** | 2026-08-30 | done | **全局像素闸门**：扫描运行时素材；标题油画改 16-bit；草地/花/营火/手冲图标硬像素重绘；分镜限色；skill `linjian-pixel-style` + `scripts/audit-pixel-style.py` |
| **DEV-037** | 2026-08-30 | done | **真机加载修复**：标题图优先加载、分镜/立绘/走表/仪式按需加载；全屏图 pad 到 2 的幂；CIA RomFS 带 `game/`；New3DS 124MB；**禁止**把 `linjian.cia` 放进 `3ds/linjian/`（hbmenu data abort） |
| **DEV-038** | 2026-08-30 | done | **安装预检闸门**：`scripts/verify-3ds-install.py`；deploy 结束必跑；skill `linjian-3ds-install`；PASS 才许拔卡 |
| **DEV-039** | 2026-08-30 | done | **主画面图标/Banner**：文生图营地标（帐篷+营火）；`scripts/build-cia-icon.py` 锁成 48×48 / 256×128；旧占位备份 `cia/*_v1.png` |
| **DEV-040** | 2026-08-30 | done | **对外去拼音**：HB 目录/`3dsx`/CIA 文件改为 `CampingTrip`；作者与简介不再写 linjian；仓库目录仍叫 linjian |
| **DEV-041** | 2026-08-30 | done | **真机 setPitch**：LovePotion Source 无 `setPitch`，菜单音效 `playSfx` 改为 pcall，避免红屏 |
| **DEV-042** | 2026-08-30 | done | **CIA 可装**：收紧 RSF（去掉 NAND 权限、关闭 compress）；安装包同时放到 `cias/` 与 `CIA(tool)/` |
| **DEV-043** | 2026-08-30 | done | **真机无图 + 后半程 abort**：LovePotion 日志在 `save/camping-trip/errors/`；启动写 `load_report.txt`；探测 `game/assets` 前缀；真机音效不 clone/setPitch；deploy 禁止 macOS `._*` |
| **DEV-044** | 2026-08-30 | done | **开机黑屏**：插卡黑屏先修 FAT/安全弹出，不是游戏砖了；`love.load` 第一句写 `boot`；禁止启动 `getDirectoryItems`；营地贴图/音频推迟到标题之后 |
| **DEV-045** | 2026-08-30 | done | **SELECT 仍无 Luma**：卡上 `boot.firm` 与官方 13.4 哈希一致，不是文件坏了。关 `enable_external_firm_and_modules`；`3ds/as-ccd.3ds`（128MB）移出 HB 目录。下一步用「拔卡开机」对照是不是机子没读卡 |
| **DEV-046** | 2026-08-30 | done | **HOME 菜单黑屏恢复**：SELECT 可进 Luma、Start 后黑屏，且 SD 确认安装 `00040000004C4A00`；判定自打 LovePotion CIA/banner 高风险。须从 GodMode9 Title manager 卸载；deploy 默认永久改为仅 3dsx，`--no-cia` 不再误拷旧 CIA |
| **DEV-047** | 2026-08-30 | done | **卸载 CIA 后仍黑屏**：备份并移走日本区 HOME Menu extdata `00000082`，让系统重建图标/banner 缓存；不删游戏存档，但主菜单图标排列/文件夹可能重置 |
| **DEV-048** | 2026-08-30 | done | **真机 PNG 全部 missing**：日志证实 source 是 `sdmc:/3ds/CampingTrip/game`，但虚拟路径 `assets/*` 不可见；改用 `mountFullPath("sdmc:/", "sdmc", "read", true)` 后从真实 SD 路径加载。失败图片负缓存，避免图鉴每帧重复 IO 卡顿 |
| **DEV-049** | 2026-08-30 | done | **3DS 原生纹理管线**：日志明确 `newImage("*.png")` 真机会找同名 `.t3x`。本地构建 tex3ds 2.3.0；`build-3ds-textures.py` 转换 133 张运行时 PNG；deploy 自动转换；预检强制要求 T3X |
| **DEV-050** | 2026-08-31 | done | **真机营地性能第二轮**：日志确认单 BGM / 无环境音 / 静态动效仍约 5 FPS；新增 `camp_static_base.png/.t3x` 离线预合成地面/水岸/小装饰，运行时只画少量前景并恢复轻量树/灌木风感；手冲完成后自动选中杯子，杯子/手冲均可继续喝咖啡；playtest 记录 `coffeeCups` |
| **DEV-051** | 2026-08-31 | done | **出发页营地预热**：用户反馈 `到了。先安顿下来吧。` 按 A 后等待过长；将 `ensureCamp()` 拆成 20 步 `camp_preload`，在 `goDepart()` 后按帧预加载营地资源和离线底图，按 A 时若未完成则提示「营地还在整理」并完成后自动进 play |
| **DEV-052** | 2026-08-31 | done | **真机玩法节奏修正**：咖啡一壶最多三口；夜里靠近篝火按 A 点火；时间自动推进，R 快进到下一天；右上角显示 `D? 时段`；3DS 静态底图模式恢复轻量鱼跃、小鸟、蝴蝶/蜻蜓/萤火虫 |
| **DEV-053** | 2026-08-31 | done | **收获+日记存档**：挂果树有限摘果；钓鱼仪式 120×76 硬像素并计入鱼种；下屏收获条；回家后书桌日记分镜=`save.json`；角色仅首次选择，标题可切换；累计露营次数/果/鱼/咖啡 |
| **DEV-054** | 2026-08-31 | done | **营地生活感**：角色男女外形强化+选人标注；溪水波光动画（静态底图上也叠画）；靠近溪水/小鸟调节环境音；三种杯子可选；树种扩到 12；涉水脚边溅水；帐篷可在平地自选落点 |
| **DEV-055** | 2026-08-31 | done | **真机营地第三轮减 draw**：树/灌木/石/巢烤进 `camp_static_base`；静态路径不再每帧重绘 75 格水面与前景树；波光改廉价 sparkle；底图限色 48 过像素审计；静态预加载跳过树/水帧纹理 |
| **DEV-056** | 2026-08-31 | done | **出发/回家分镜跟角色**：擦掉 d1/d2/h1 写死男孩；运行时按 `player.castId` 叠 20×20 立绘；playtest 改选女孩并断言 castId |
| **DEV-057** | 2026-08-31 | done | **恢复角色美术**：从 `docs/characters/walk_v5` 还原九人立绘+走表（覆盖 DEV-054 程序色块）；`build-camp-life-assets` 不再重画角色；脚本 `restore-cast-walk-v5.py` |
| **DEV-058** | 2026-08-31 | done | **日记有字 + 钓鱼仪式加细**：上屏日记页按本趟收获写短句；钓鱼 120×76 重绘（夜空/码头/溅水/弯竿/鱼形）；`build-harvest-assets.py` |
| **DEV-059** | 2026-08-31 | done | **下屏背包 UI 文生图重做**：新 `ui_pack_bg` 藤蔓边框；六件 `gear_*` 图标更清晰；脚本 `build-pack-ui-from-gen.py`；参考 `docs/promo/*_gen_ref.png` |
| **DEV-060** | 2026-08-31 | done | **日记背景跟选角**：擦掉 diary 写死头像；按 castId 叠立绘，scissor 只露头肩；出发/回家槽位支持 scale |
| **DEV-061** | 2026-08-31 | done | **河岸溪流美术**：重绘水/浅滩/岸线 16×16（泥沙唇、碎石、波光动画帧）；加宽断续外浅滩；重建 `camp_static_base`；脚本 `build-creek-tiles.py` |
| **DEV-062** | 2026-08-31 | done | **草地/泥地砖美术**：硬像素重绘 8 草地 + 4 泥地（斑块/草叶/小花/边缘融合）；告别照片缩小糊图；重建 `camp_static_base`；脚本 `build-ground-tiles.py` |
| **DEV-063** | 2026-08-31 | done | **草地/泥地 v2**：安静斑块+竖草簇（去十字重复）；泥地降噪；`dirt_fringe_NESW` 软化泥地直角；静态底图同步烘焙；时钟 HUD 已为 `D? HH:MM` |
| **DEV-064** | 2026-08-31 | done | **手冲加深可反复冲**：选豆(5)/研磨(3)/滤杯(5)/滤纸/水温92·100/冲次2~4 → 三步冲煮；参数算口感；一壶三口喝空可再冲；文生图像素滤杯与豆袋；扩 `zh-ui` 字形；脚本 `build-drip-brew-assets.py` |
| **DEV-065** | 2026-08-31 | done | **手冲工程化**：`docs/手冲模块-SPEC.md`；逻辑/绘制迁入 `game/drip_brew.lua`；`PHASES` 数据驱动；`main` bind 宿主回调 |
| **DEV-066** | 2026-08-31 | done | **泡茶仪式**：`docs/泡茶模块-SPEC.md` + `tea_brew.lua`；选茶/投量/茶器/温杯/水温/出汤/三步；与咖啡壶状态并存；文生图 leaf/ware/tea_1..3；背包「泡茶」替换小锅格 |
| **DEV-067** | 2026-08-31 | done | **仪式资源分目录 + 钓鱼加深**：`ritual/drip/`、`ritual/tea/`、`ritual/fish/`；`fish_rod.lua` 六相位 |
| **DEV-068** | 2026-08-31 | done | **9 种日式杯子 + 场景资源分目录**：`assets/cups/`；`scenes/forest/`（story/camp/world）、`home/story`、`shared/`、`gear/`、`ui/`；`asset_paths.lua` |
| **DEV-068** | 2026-08-31 | wip | **代码模块化**：见 [代码架构-SPEC.md](./代码架构-SPEC.md)；P0–P3 完成，main locals 198→**151** |
| **DEV-069** | 2026-08-31 | wip | **真机音频扩展**：`console_prox_amb_bgm_switch`、title/night BGM、近水溪水、近鸟 sfx；见 [真机音频扩展-SPEC.md](./真机音频扩展-SPEC.md) |
| **DEV-012** | — | planned | **P1** 加深：更多时段事件（搭帐篷动画、手冲小游戏） |
| **DEV-014** | — | planned | **P3** 精修回家：次日收拾动画、周末计数 |
| **DEV-015** | 2026-08-30 | done | 基础 SFX 清单齐：UI + 脚步/帐篷/手冲/杯子/扇子/点灯 |
| **DEV-016** | — | planned | **P4** 继续加深美术：更多地砖转角、角色四向帧、道具动画（脚本出图，不强制付费软件） |

### 12.1.1 真机性能接续记录（DEV-050）

**证据来源：SD 真机日志 + 桌面 playtest。** 这段是给后续 Agent 接手性能问题时看的，不要只看桌面 FPS 做判断。

最近三轮真机日志结论：

1. `static_play_fx/console_single_stream_no_stop` 已经排除了主要风效、鱼鸟虫、环境音、多 BGM stream、`Source:stop()` 切换等变量，但营地仍长期约 `22–25 frames / 5s`，即约 `4–5 FPS`。
2. `ensureCamp` 首次加载从约 `41700ms` 降到约 `30416ms`，说明减少静态模式资源加载有收益，但没有解决持续低帧。
3. 标题、图鉴、关于页能跑到远高于营地的帧数，说明瓶颈集中在营地场景，不是整机或 LovePotion 全局都慢。
4. 因为关掉动效后仍卡，树叶/水面/鸟虫不是主因；更可能是营地每帧大量小纹理 draw、纹理切换和 Lua 热路径开销。
5. 真机 Canvas 实验曾导致黑屏判断不清，当前不把运行时 `newCanvas` 当默认优化路线；优先采用离线预合成图。

当前代码策略：

- build 标记：`2026-08-31-precomposed-camp-coffee-cup`。
- 真机静态模式仍为默认：`static_play_fx/console_single_stream_no_stop`。
- 音频保持单 BGM stream、无环境音、SFX 不 clone/setPitch/stop；不要和营地渲染优化混在一轮改。
- `scripts/build-camp-static-base.py` 生成 `game/assets/camp_static_base.png`，deploy 再转出 `camp_static_base.t3x`。
- 静态模式优先加载 `assets/camp_static_base.png`；若成功，地面、水岸、小花、芦苇、木头、踏脚石等不再逐帧绘制。
- 运行时只保留树、灌木、帐篷、营火、玩家等少量前景逐帧绘制，并恢复轻量树/灌木风感。
- `indexCampRenderData()` 缓存 decal/prop 行索引、树 variant 和鸟巢位置，避免每帧创建排序表或扫描全量 decal。

下一轮真机测试必须看：

```text
boot build=2026-08-31-precomposed-camp-coffee-cup
ensureCamp done fails=0 durationMs=... mode=static_play_fx staticBase=true
perf scene=play frames=... slow=... maxDtMs=... mode=static_play_fx/console_single_stream_no_stop
```

判断口径：

- 若 `staticBase=true` 且帧率明显提升：继续逐项恢复轻量效果，优先树/灌木风感，其次水面，最后鱼鸟虫/粒子。
- 若 `staticBase=true` 但仍约 `4–5 FPS`：继续减少前景 draw，把树/灌木/帐篷/营火也按“静态底图 + 玩家单独层”处理，或降低树数量/纹理种类。
- 若 `staticBase=false`：先查 `camp_static_base.t3x` 是否存在、是否过期、`loadImage("assets/camp_static_base.png")` 是否失败，别先改玩法。
- 若没有 `boot build=...`：问题在 Homebrew/LovePotion/SD 启动链，不是营地 Lua 热路径。

咖啡交互修正：

- 旧体验问题：手冲完成后玩家仍可能停留在“手冲”选择，看起来像无法喝咖啡。
- 当前行为：完成三步手冲后自动选中“杯子”；杯子可继续喝；如果已经冲好，再按“手冲”也会转为喝咖啡。
- 下屏会提示「咖啡已冲好 · 选杯子按 A 喝」或「A 喝咖啡 · 已喝 N 口」。
- playtest 已增加 `coffeeCups` 断言信号，当前日志为 `dripped=true coffeeCups=2`。

### 12.1.2 进入营地等待优化（DEV-051）

**证据来源：用户真机体感 + 桌面 `load_report.txt`。** 用户在第二张出发分镜
`到了。先安顿下来吧。` 按 A 后，需要等待很久才进入营地。此前 `goPlay()` 会同步执行
`ensureCamp()`，包括营地贴图、阴影、装备 icon、玩家、静态底图和 canvas 构建；在 3DS 上
这些 SD/T3X 读取和纹理创建会集中阻塞在按 A 的那一刻。

当前修正：

- build 标记：`2026-08-31-depart-camp-preload`。
- `ensureCamp()` 保留为强制完成入口，但内部改用 `campPreload` 步进器。
- `goDepart()` 会立即 `beginCampPreload("depart")`，用户阅读出发分镜时后台每帧加载一小步。
- `love.update()` 在 `scene == "depart"` 时继续执行 `runCampPreloadSlice()`；桌面每帧 3 步，真机每帧 1 步，避免单帧尖峰太大。
- 若用户很快在最后一句按 A，而 `campReady` 尚未完成，会显示「营地还在整理 · 马上就好」；加载完成后自动 `goPlay()`，不再黑屏式同步等待。
- 本地 `load_report.txt` 应看到 `camp_preload_begin reason=depart ...` 早于 `scene=play`，并看到 `ensureCamp done ... steps=20`。

下一轮真机测试重点：

```text
boot build=2026-08-31-depart-camp-preload
camp_preload_begin reason=depart mode=static_play_fx
ensureCamp done fails=0 durationMs=... mode=static_play_fx staticBase=true steps=20
perf scene=play frames=... slow=... maxDtMs=... mode=static_play_fx/console_single_stream_no_stop
```

判断口径：

- 如果按 A 体感等待明显缩短，说明卡点主要是首次营地资源加载尖峰，下一步继续压缩总加载量或提前到更早分镜。
- 如果按 A 后仍长时间停顿，说明单步里的某个 T3X/MP3/字体 IO 仍太重，下一步把 `camp_preload` 加每步耗时日志，定位具体 step。
- 如果进入后仍低帧，继续沿 DEV-050 的持续渲染优化路线处理，不要把进入等待和营地帧率混为一个问题。

### 12.1.3 真机玩法节奏修正（DEV-052）

**证据来源：用户真机反馈 + 桌面 playtest。** 用户确认 DEV-051 后整体不卡顿，但出现三类体验问题：咖啡可无限喝、夜里不知道如何点篝火、时间不应依赖 X 手动推进，同时希望 3DS 真机恢复鱼鸟虫。

当前修正：

- build 标记：`2026-08-31-auto-time-critters`。
- 咖啡改为一壶最多三口：手冲完成自动喝第一口，杯子/手冲入口最多再喝到第三口；超过后提示「这壶刚好喝完了」。
- 夜里靠近篝火按 A 会优先点火，不再要求先选中某个装备；左上角状态从「灯」改为「火」。
- 时间在 play 场景、非仪式状态下每 42 秒自动推进一档；X 不再作为时间推进键。
- R / right shoulder 快进到下一天上午，并重置咖啡、篝火、虫鸟状态。
- 右上角新增 `D1 上午` 这类时间牌，和左上角营地状态分开。
- `critterFx` 独立于静态底图：真机即使 `static_play_fx` 也加载并更新低数量鱼跃、小鸟、蝴蝶/蜻蜓/萤火虫；桌面可用 `LINJIAN_PLAY_FX=static LINJIAN_CRITTER_FX=1 love game --playtest` 模拟。

验收日志：

```text
dripped=true coffeeCups=3 cap=true
lantern=true
fastDay day=2 time=D2 上午
```

下一轮真机判断：如果恢复鱼鸟虫后仍不卡顿，就可以继续保留；如果音乐或帧率再次抖动，先关 `critterFx` 或减少 spawn 数量，不要回退自动时间和咖啡规则。

### 12.1.4 真机营地减 draw（DEV-055）

**证据来源：DEV-050 真机约 4–5 FPS + 桌面 static playtest。** 静态底图有了之后，每帧仍在做两件重活：重绘约 75 格水面动画、再逐棵画 ~28 棵树（含阴影/风摆）。

本轮改动：

- build 标记：`2026-08-31-static-props-bake`。
- `scripts/build-camp-static-base.py` 把树/灌木/石/巢也烤进 `camp_static_base.png`，并 median-cut **48 色**（审计 unique=48，此前 432 FAIL）。
- 静态路径：`drawCampGroundLayer` 只画一张底图；`propRows` 只留帐篷；水果用 `drawFruitOverlays` 小色块；溪水用 `drawCreekLite` 波光点，不再换水帧贴图。
- 静态预加载跳过树/灌木/石/花/水帧/岸线纹理，缩短进营地 IO。
- 桌面默认仍是 `full_play_fx`（完整动效）；真机或 `LINJIAN_PLAY_FX=static` 走上述路径。

桌面验收：

```text
boot build=2026-08-31-static-props-bake
ensureCamp done fails=0 ... mode=static_play_fx staticBase=true
playtest PASS（full + LINJIAN_PLAY_FX=static）
audit-pixel-style.py：0 fail
```

下一轮真机必须看：

```text
boot build=2026-08-31-static-props-bake
ensureCamp done ... staticBase=true
perf scene=play frames=... slow=... maxDtMs=... mode=static_play_fx/console_single_stream_no_stop
```

判断口径：

- 若帧率明显升到两位数：可逐步加回少量动态（例如 4～8 格真水帧，或 2～3 棵近景摆动树），不要一次全开。
- 若仍约 4–5 FPS：瓶颈更可能在鱼鸟虫/`drawFitted` 大纹理/Lua 热路径，下一步再减 `critterFx` 或拆 `drawPlayTop`。

### 12.2 Agent 验收约定

每次改玩法/美术/UI 后必须执行：

```bash
cd /Users/ruska/projects/3ds/linjian && love game --playtest
```

日志出现 `PASS`，且 `~/Library/Application Support/LOVE/linjian/playtest/` 有截图，才算本轮完成。
