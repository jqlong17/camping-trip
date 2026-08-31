# 做饭模块 SPEC（A 档 · 替换扇子 · DEV-072）

> 从属：[游戏设计-SPEC.md](./游戏设计-SPEC.md)  
> 对标：手冲 / 泡茶 / 钓鱼 A 档  
> 装备格：原 `fan` → **`cook`（做饭）**

---

## 1. 体验一句话

在营地开火做一餐：选菜系、火候、调味，再看三步特写；吃完有口味短句，本趟计入「做饭」。

---

## 2. 相位（7）

| 序 | id | kind | catalog |
|----|-----|------|---------|
| 1 | cuisine | choice | 烧烤 / 寿司 / 火锅 / 烤串 / 炖锅（5） |
| 2 | heat | choice | 文火 / 中火 / 猛火（3） |
| 3 | season | choice | 盐胡椒 / 酱油 / 柑橘（3） |
| 4 | prep | confirm | 备菜摆盘确认 |
| 5–7 | cook | brew×3 | 开火 → 翻面成形 → 盛盘 |

可反复做；每次 `haul.meals += 1`；`CookMeal.taste` 口感句。

---

## 3. 口感公式

基调取菜系 `note`；火候修正（猛火偏焦香、文火偏嫩）；调味缀句。  
例：`烧烤 · 中火 · 酱油 · 外焦里嫩带酱香`

---

## 4. 文件

| 路径 | 职责 |
|------|------|
| `game/cook_meal.lua` | catalog / PHASES / 公式 / 绘制 |
| `game/assets/gear/cook.png` | 背包图标 |
| `game/assets/ritual/cook/*` | **按件** `cuisine_*`/`heat_*`/`season_*`（绿幕）；`cook_1..3` **160×120** 独立特写 |
| `scripts/build-cook-assets.py` | 一件一文生图；禁止 sheet 横切 |
| 删除扇子入口 | `fan` gear / ritual / playtest `05d_fan` |

---

## 5. 验收

- [x] 无扇子装备格与仪式  
- [x] 7 相位 + 口感 + haul.meals  
- [x] 文生图 + audit  
- [x] playtest 覆盖做饭主路径  
