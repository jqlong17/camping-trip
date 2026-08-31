---
name: linjian-rich-gear
description: >-
  Keeps 露营之旅 (linjian) equipment/rituals richly multi-step (not toast-thin),
  with SPEC-first modules and locked 16-bit text-to-image style. Use when adding
  or deepening gear—手冲、泡茶、帐篷选色/款式、露营灯、登山徒步背景与装备、背包新道具—
  or when the user mentions 丰富度、精细、文生图统一、别太简单、仪式、选配.
disable-model-invocation: false
---

# 露营之旅 · 丰富装备 / 仪式制作

仓库根：`/Users/ruska/projects/3ds/linjian`  
金标准：**手冲**（DEV-064/065）与 **泡茶**（DEV-066）的深度。新内容不得明显更薄。

必联读：

1. `linjian-camping-3ds` — 流程 / playtest / DEV  
2. `linjian-pixel-style` — 运行时 PNG 闸门  
3. 金标准 SPEC：`docs/手冲模块-SPEC.md`、`docs/泡茶模块-SPEC.md`  
4. 本 skill 补充：`prompt-lock.md`（文生图固定措辞）、`depth-checklist.md`（丰富度验收）

---

## 核心原则（不可破）

1. **先 SPEC，后代码图**：用户要新装备/仪式时，先写 `docs/<主题>模块-SPEC.md`，对齐手冲章节结构，再实现。  
2. **禁止「一句 toast 完事」**：可玩选择 ≥ **3 个独立维度**（如色/款/材质），或仪式相位 ≥ **5 步**（含确认/过程帧）。  
3. **参数要有结果**：选择须影响文案、口感/氛围短句、地图可见态，或日记计数——不能纯装饰。  
4. **可反复 / 可并存**：能重做的就重做（再冲/再泡）；多壶多灯状态不要互相踩死。  
5. **模块化**：逻辑进 `game/<topic>_*.lua` + `PHASES`/catalog 表；`main.lua` 只 bind / 入口 / 输入路由。  
6. **文生图必须过像素锁**：统一 prompt 锁（见下）→ `docs/promo/*_gen_ref.png` → 切硬像素进 `game/assets` → `audit-pixel-style.py`。
7. **禁止 PIL 程序画展示图**：凡玩家会看见的 PNG（装备、杯子、仪式选参、特写帧、角色、分镜、世界生物、背包 UI 图标）**不得**用 `ImageDraw` / 逐像素 `put()` 从零绘制。项目有 **GenerateImage / 文生图** 能力时，必须先 gen → 存 `docs/promo/` → `build-*-assets.py` **只做切图、nearest 缩放、限色、透明裁边**。不得以「赶进度、占位、脚本快」为由跳过文生图。

若用户说「随便加点」而主题属于装备/仪式：仍按本 skill 拉满一档丰富度，并在回复里说明对标手冲。

---

## 丰富度水位（对标手冲）

| 档 | 何时用 | 最低交付 |
|----|--------|----------|
| **A 仪式** | 手冲/泡茶/做饭/篝火仪式 | 5–7 相位；3+ catalog；口感/氛围公式；三步特写帧；可反复 |
| **B 选配** | 帐篷色/款、露营灯、杯子以外的外观件 | ≥3 维选择（如色×款×尺寸）；地图可见变化；下屏左右选 |
| **C 场景包** | 登山徒步背景、主题周末 | 上屏氛围图套件（≥2 时段）+ ≥3 相关装备图标 + 简短互动或图鉴条目 |
| **D 轻反馈** | 仅 SFX/粒子 | **不得**单独作为「新装备」交付；只能附在 A/B/C 上 |

**不及格示例**：只加一个背包图标 + toast「搭好了」；帐篷不能选色；灯只有开/关无款式。

**及格示例（未来）**：

- 帐篷：色（沙/绿/蓝灰）× 款（穹顶/隧道/小尖顶）× 门帘开合；地图换贴图。  
- 露营灯：煤油/LED/纸灯笼 × 暖白/冷白；夜里光晕色变。  
- 登山：山脊/林道背景（晨昏）+ 登山杖/水壶/地图册装备格。

---

## 标准工作流

```
1. 读游戏设计-SPEC §12 最新 DEV 编号
2. 写 docs/<主题>模块-SPEC.md（体验表 + 相位/维度 + 资源命名 + 并存规则）
3. 文生图（套用 prompt-lock.md）→ docs/promo/*_gen_ref.png
4. scripts/build-<topic>-assets.py **仅从 gen_ref 切** 48×48 / 120×76 硬像素（脚本内禁止 ImageDraw 画主体）
5. game/<module>.lua：catalog + PHASES + bind + draw
6. main：require、装备格、输入 nudge、playtest 断言
7. 扩 zh-ui 缺字；audit-pixel-style.py；love game --playtest → PASS
8. 写 DEV-XXX；更新 动画与交互-SPEC / 怎么玩.md
```

部署真机时再走 `linjian-3ds-install`。

---

## 文生图风格锁（摘要）

每条 GenerateImage / 文生描述 **必须包含**（完整模板见 [prompt-lock.md](prompt-lock.md)）：

- `16-bit pixel art` / `hard pixels` / `thick outlines` / `limited palette`  
- `NO blur, NO photorealism, NO anti-aliasing, NO soft gradients`  
- `Nintendo 3DS camping game` / `retro game asset`  
- 多物件用 **横向 sprite sheet**，单件尺寸意图写清（约 48px / 64px 可读）  
- 背景：`cream or simple wood plank`，勿复杂风景抢主体（全屏分镜除外）

**禁止**在 gen prompt 里写：realistic, 8k, cinematic lighting, depth of field, photograph。

切图后：`audit-pixel-style.py` 0 fail 才算进包。

---

## 工程模板（与手冲对齐）

```
docs/<主题>模块-SPEC.md
game/<topic>_brew.lua | <topic>_gear.lua   # 自包含
scripts/build-<topic>-assets.py
game/assets/ritual/<prefix>_*.png 或 gear_*.png
docs/promo/<topic>_*_gen_ref.png
```

`PHASES` / 选配表字段习惯：`id, head, kind(choice|confirm|brew|preview), catalog, store, defaultPick, assetBag`。  
口感/氛围用 **修正小表按 id**，少写散落 `if`。

Lua chunk **200 locals**：新表放模块全局/表字段，勿继续堆 `main` local。

---

## 装备格与并存

- 下屏默认约 **6 格**；新仪式优先替换低优先级格或 SPEC 写明布局，勿 silently 挤爆 UI。  
- 多「壶/灯/帐」状态字段分离（如 `drippedOnce` vs `teaReady`）。  
- 杯子等多用途入口：多产物并存时要有 **显式选择相**（左右选咖啡/茶）。

---

## 验收（每次交付）

- [ ] SPEC 已写且声明对标手冲/泡茶哪一档（A/B/C）  
- [ ] 选择维度或相位数量达标  
- [ ] 参数影响可见（文案 / 地图 / 计数至少一项）  
- [ ] 文生图用了 prompt 锁；`docs/promo/*_gen_ref.png` 可追溯；runtime 图过 audit  
- [ ] **无新增** ImageDraw 程序绘制的展示 PNG（见下表「待迁移」须逐步换成 gen）  
- [ ] `love game --playtest` PASS（含新流程断言）  
- [ ] DEV-XXX + 怎么玩 有入口说明  

不达标 → 先补丰富度，再谈收工。

---

## 资源管线：文生图 vs 程序绘制

| 类别 | 正确做法 | 禁止 |
|------|----------|------|
| 装备 / 杯子 / 仪式 catalog | gen sheet → `build-*-assets.py` slice | `build-cups.py` 式 ImageDraw 画杯 |
| 仪式三步特写 | gen 横条或分三次 gen → 120×76 | `build-harvest-assets.py` 画人+线 |
| 选参 UI 图标（钓点/饵/研磨度等） | gen sprite sheet → slice | `build-fish-rod-assets.py` 全程序 |
| 背包 / pack UI | `build-pack-ui-from-gen.py` | `enforce-pixel-style.py` 兜底画 gear |
| 角色 walk / 立绘 | `docs/characters/` + 文生图迭代 | `build-camp-life-assets` 的 `build_cast` |
| 分镜 / 标题 | gen → cover → ×2 nearest → 限色 | 程序画场景 |

**build 脚本允许的程序操作**（不算违规）：从已有 PNG 切片、resize NEAREST、median-cut 量化、alpha 裁边、拼已有 tile 成 static base（`build-camp-static-base.py`）、T3X/音频等非视觉产物。

### 仓库内仍含程序绘制、待文生图替换（维护清单）

| 脚本 | 产出路径 | 说明 |
|------|----------|------|
| `scripts/build-cups.py` | `assets/cups/cup_*.png`, `gear/cup.png` | **文生图** sheet 切图 |
| `scripts/build-fish-rod-assets.py` | `ritual/fish/spot_*.png` 等 | **全程序**选参图标 |
| `scripts/build-harvest-assets.py` | `ritual/fish/fish_1..4.png` 等 | 钓鱼仪式帧 |
| `scripts/build-critters.py` | `scenes/forest/world/` 鸟虫 | 世界小精灵 |
| `scripts/build-camp-life-assets.py` | `shared/tile_tree8-11.png` | 额外树 tile（角色已禁覆盖） |
| `scripts/build-ground-tiles.py` | `scenes/forest/camp/tile_*.png` | 草地/泥地 16×16 |
| `scripts/build-creek-tiles.py` | 溪水/岸 tile | 同上 |
| `scripts/build-drip-brew-assets.py` | `grind_*`, `temp_*`, `pours_*`, `paper` | **部分**程序；滤杯/豆已 gen |
| `scripts/build-tea-brew-assets.py` | `amount_*`, `temp_*`, `steeps_*`, `rinse` | **部分**程序；茶叶/ ware 已 gen |
| `scripts/enforce-pixel-style.py` | 缺图时 gear 占位 | 应急兜底，新资源勿依赖 |

**已走文生图（金标准）**：`build-drip-brew-assets`（滤杯/豆/手冲帧）、`build-tea-brew-assets`（茶叶/茶具/泡茶帧）、`build-pack-ui-from-gen.py`、分镜/标题 promo 管线、`build-cia-icon.py`（从 gen 源像素锁）。

新增或重做上述任一类资源时：**先 gen ref，再改 build 脚本为纯切图**；不要扩写 ImageDraw 分支。

---

## 详细材料

- [prompt-lock.md](prompt-lock.md) — 文生图固定前缀/后缀与 sheet 构图  
- [depth-checklist.md](depth-checklist.md) — 按主题（帐/灯/登山）的展开清单
