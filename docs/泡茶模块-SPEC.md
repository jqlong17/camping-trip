# 泡茶模块 SPEC

> 从属：[游戏设计-SPEC.md](./游戏设计-SPEC.md) · [动画与交互-SPEC.md](./动画与交互-SPEC.md) · [手冲模块-SPEC.md](./手冲模块-SPEC.md)  
> 状态：2026-09-01 · DEV-103  
> 目标：露营里除了手冲，再做一套**丰富度对齐手冲**的泡茶仪式；独立模块、可扩展、可反复泡。

---

## 1. 体验目标

周末林间：咖啡与茶都是慢仪式。泡茶要让人感到「选茶、温器、水温、三步冲泡」有讲究，而不是一句 toast。

| 对齐手冲 | 泡茶侧 |
|----------|--------|
| 选豆子 | 选茶叶（产区/工艺） |
| 研磨度 | 投茶量 |
| 滤杯 | 茶器 |
| 放滤纸 | 温杯烫壶 |
| 水温 92/100 | 水温多档（绿茶更低） |
| 三步冲煮 | 注水 → 闷泡 → 出汤 |
| 一壶三口可再冲 | 一壶三口可再泡 |
| 参数 → 口感短句 | 同样 |

非目标：不做成真实茶艺模拟器；不引入网络；不挤掉帐篷/钓鱼。

---

## 2. 装备与并存

- 下屏背包六格调整为：

```
帐篷 | 手冲 | 泡茶
钓竿 | 杯子 | 扇子
```

- 原「小锅」移出背包格：夜里营火旁 **A 点火**保留；小锅咕嘟改为点灯后靠近营火短反馈（或并入火旁文案），避免占格。
- **咖啡壶 / 茶壶状态分离**：可同时有冲好的咖啡与泡好的茶。
- **杯子**：
  - 仅咖啡有剩 → 喝咖啡；
  - 仅茶有剩 → 喝茶；
  - 两者都有 → 左右选「咖啡 / 茶」再 A 喝一口（或先弹选择相）。

本趟计数：`tripHaul.tea`（口数）；日记与收获条显示「茶×N」。

---

## 3. 文件与职责

| 路径 | 职责 |
|------|------|
| `docs/泡茶模块-SPEC.md` | 本文 |
| `game/tea_brew.lua` | 配方、相位表、口感、绘制、加载 |
| `game/main.lua` | require/bind、装备入口、杯子分流、playtest |
| `game/assets/ritual/tea_*` / `leaf_*` / `ware_*` … | 运行时图标与三步特写 |
| `scripts/build-tea-brew-assets.py` | 文生图 → 硬像素 |
| `docs/promo/tea_*_gen_ref.png` | 参考原图 |

API 形态对齐 `DripBrew`：`TeaBrew.bind` / `start` / `advance` / `nudge` / `drawTop` / `drawBottom` / `potHint` / `resetTrip`。

仪式：`ritual.kind == "tea"`。

---

## 4. 相位表（数据驱动）

`TeaBrew.PHASES`：

| 序 | id | kind | 选项 |
|----|-----|------|------|
| 1 | `leaf` | choice | 龙井 / 铁观音 / 滇红 / 白毫银针 / 玄米茶 |
| 2 | `amount` | choice | 少许 / 适中 / 满杯 |
| 3 | `ware` | choice | 盖碗 / 玻璃公道 / 紫砂壶 / 飘逸杯 / 搪瓷缸 |
| 4 | `rinse` | confirm | 温杯烫壶 |
| 5 | `temp` | choice | 80° / 85° / 90° / 95° / 100° |
| 6 | `brew` | brew×3 | 注水 → 闷泡 → 出汤 |

扩展：改 catalog + PNG，禁止再堆 `main` 的 `elseif phase`。
旧 `steeps` 相位已删除：它与紧接的 `brew` 实际“注水 → 闷泡 → 出汤”演出语义重复。

---

## 5. 口感模型

茶叶基底字段：`aroma, sweet, bitter, body`（香 / 甘 / 苦 / 厚）。

修正表（按 id）：

- 投茶量：少许偏香清；满杯偏厚苦。
- 茶器：盖碗扬香；紫砂更厚；玻璃偏清；搪瓷更粗放。
- 水温：偏低护香甜；偏高增苦厚（绿茶选高温会提示「稍烫了」体现在口感偏苦）。

`computeTaste` → `"龙井 · 清香回甘，带点鲜爽"` 这类短句。

---

## 6. 资源命名

| 类别 | 下屏目录图 | 上屏主视觉 |
|------|------------|------------|
| leaves | `leaf_{id}.png`（48×48） | `preview_leaf_{id}.png`（256×192） |
| amounts | `tea_amount_{id}.png`（48×48） | `preview_amount_{id}.png`（256×192） |
| wares | `ware_{id}.png`（48×48） | `preview_ware_{id}.png`（256×192） |
| temps | `tea_temp_{c}.png`（48×48） | `preview_temp_{c}.png`（256×192） |
| rinse | `tea_rinse.png`（48×48） | `preview_rinse.png`（256×192） |
| brew 帧 | — | `tea_1.png` … `tea_3.png`（320×180） |
| 背包图标 | `assets/gear_tea.png` |

文生图：一件一图 → `docs/promo/*_gen_ref.png` → `scripts/build-tea-brew-assets.py` 只做硬像素；**禁止**一张 sheet 切五袋再靠袋面字认种。  
下屏选参：槽内只显示 `name`（`printf` 居中限宽），`note` 在底栏单行；与帐篷/做饭选参一致。

### 6.1 双资源层硬约束

- **禁止把 40/48px 目录小图放大为上屏主视觉**；`drawTop/topView` 必须读取独立 preview bag。
- icon 与 preview 必须从同一份 1024 级制作源分别构建，不能先得到 48×48 再放大。
- 选择/确认预览用 256×192：T3X POT 为 256×256，RGBA8888 上限约 256 KiB/张；19 张约 4.75 MiB。
- 三步泡茶用 320×180：T3X POT 为 512×256，上限约 512 KiB/张；3 张约 1.5 MiB。
- 全套上屏泡茶资源未压缩显存上限约 6.25 MiB，实际 T3X 使用 LZ 压缩；避免 22 张全部使用 400×240 导致约 11 MiB 级 POT 预算。
- 温杯源固定为 `tea_rinse_action_chroma_gen_ref.png`：深色水壶、连续水流、蓝白盖碗、三股蒸汽；旧 `tea_rinse_chroma_gen_ref.png` 已废弃。

---

## 7. 玩法契约

1. 茶壶还有口 → 选「泡茶」改为喝茶（同手冲）。  
2. 喝空或未泡 → 开新仪式；可反复泡。  
3. `finish`：口感、`teaCups=1`、`tripHaul.tea++`、优先选中杯子。  
4. `CUPS_PER_POT = 3`。  
5. 地图：泡茶时脚边可复用冲煮台/蒸汽，或轻量茶壶 prop（有则画，无则蒸汽即可）。

---

## 8. 验收

```bash
love game --playtest   # PASS；日志含 tea 仪式与 rebrew tea
```

真机：deploy 后预检 PASS；泡茶选项与滤杯同级可读。

---

## 9. DEV

| 编号 | 内容 |
|------|------|
| **DEV-066** | 泡茶 SPEC + `tea_brew.lua` + 文生图资源 + 背包「泡茶」与咖啡并存 |
| **DEV-103** | 删除重复的 PHASE-013 并保留 PHASE-014 稳定 ID；PHASE-008~014 全部改为 icon/preview 双资源层，选参/温杯 256×192、泡茶三帧 320×180；温杯烫壶动作重新绿幕文生图 |
