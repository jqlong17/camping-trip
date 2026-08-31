# 泡茶模块 SPEC

> 从属：[游戏设计-SPEC.md](./游戏设计-SPEC.md) · [动画与交互-SPEC.md](./动画与交互-SPEC.md) · [手冲模块-SPEC.md](./手冲模块-SPEC.md)  
> 状态：2026-08-31 · DEV-066  
> 目标：露营里除了手冲，再做一套**丰富度对齐手冲**的泡茶仪式；独立模块、可扩展、可反复泡。

---

## 1. 体验目标

周末林间：咖啡与茶都是慢仪式。泡茶要让人感到「选茶、温器、水温、出汤」有讲究，而不是一句 toast。

| 对齐手冲 | 泡茶侧 |
|----------|--------|
| 选豆子 | 选茶叶（产区/工艺） |
| 研磨度 | 投茶量 |
| 滤杯 | 茶器 |
| 放滤纸 | 温杯烫壶 |
| 水温 92/100 | 水温多档（绿茶更低） |
| 冲几次 | 出汤次数（功夫茶） |
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
| 6 | `steeps` | choice | 出汤 1 / 2 / 3 / 4 次 |
| 7 | `brew` | brew×3 | 注水 → 闷泡 → 出汤 |

扩展：改 catalog + PNG，禁止再堆 `main` 的 `elseif phase`。

---

## 5. 口感模型

茶叶基底字段：`aroma, sweet, bitter, body`（香 / 甘 / 苦 / 厚）。

修正表（按 id）：

- 投茶量：少许偏香清；满杯偏厚苦。
- 茶器：盖碗扬香；紫砂更厚；玻璃偏清；搪瓷更粗放。
- 水温：偏低护香甜；偏高增苦厚（绿茶选高温会提示「稍烫了」体现在口感偏苦）。
- 出汤次数：少则浓；多则透、回甘。

`computeTaste` → `"龙井 · 清香回甘，带点鲜爽"` 这类短句。

---

## 6. 资源命名

| catalog | 文件 |
|---------|------|
| leaves | `ritual/leaf_{id}.png` |
| amounts | `ritual/tea_amount_{id}.png` |
| wares | `ritual/ware_{id}.png` |
| temps | `ritual/tea_temp_{c}.png` |
| steeps | `ritual/tea_steeps_{n}.png` |
| rinse | `ritual/tea_rinse.png` |
| brew 帧 | `ritual/tea_1.png` … `tea_3.png` |
| 背包图标 | `assets/gear_tea.png` |

文生图须经硬像素限色后进 `game/assets`；参考图放 `docs/promo/`。

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
