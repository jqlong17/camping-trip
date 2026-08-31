---
name: linjian-gear-parity
description: >-
  Scores and levels 露营之旅 (linjian) gear/rituals against drip/tea/rod gold
  standard before shipping. Use when adding equipment, deepening tent/cup/cook,
  replacing gear slots, 横向对比, 丰富度评价, 装备验收, or after implementing a
  new backpack item—self-evaluate then fix gaps to A-tier parity.
disable-model-invocation: false
---

# 露营之旅 · 装备横向评价（自检 skill）

仓库：`/Users/ruska/projects/3ds/linjian`  
金标准模块：**手冲** `drip_brew`、**泡茶** `tea_brew`、**钓鱼** `fish_rod`（A 档）。  
联读：`linjian-rich-gear`、`linjian-pixel-style`、`linjian-camping-3ds`。

**何时用**：每新加/替换一个装备格，或用户说「横向对比 / 拉齐 / 评价装备」——先评分，不达标则补齐再标 DEV done。

---

## 评分表（每项 0–2，满分 20）

| # | 维度 | 0 | 1 | 2 |
|---|------|---|---|---|
| 1 | SPEC | 无 | 有短说明 | 独立 `docs/<主题>模块-SPEC.md` 且声明 A/B/C |
| 2 | 相位/维 | toast 一步 | 3–4 相或 2 维 | ≥5 相 **或** ≥3 独立维且含过程 |
| 3 | Catalog | ≤1 选项 | 2–3 | 主维 ≥3（仪式常用 3–5） |
| 4 | 结果影响 | 无 | 仅 toast | 口感/氛围公式 + 日记或 haul 计数 |
| 5 | 过程特写 | 无 | 1–2 帧 | ≥3 帧 120×76 硬像素 |
| 6 | 文生图 | 程序画主体 | 混用 | gen → `docs/promo/*_gen_ref.png` → 纯切图 |
| 7 | 像素 audit | fail | warn 未处理 | `audit-pixel-style.py` 0 fail |
| 8 | 模块化 | 堆在 main | 半拆 | 独立 `game/<mod>.lua` + bind |
| 9 | 可反复 | 一次性脏状态 | 可重做但怪 | 可反复；状态字段不互踩 |
| 10 | playtest | 无 | 有截图 | 断言 taste/mood/haul + PASS |

**档位**：≥16 → **A**（可与手冲并列）；12–15 → **B**（选配可交付，仪式勿停）；&lt;12 → **不及格**，禁止标 done。

---

## 当前基准线（维护时更新）

| 装备 | 目标档 | 备注 |
|------|--------|------|
| 手冲 drip | A | 金标准 |
| 泡茶 tea | A | 金标准 |
| 钓竿 rod | A | 金标准 |
| 帐篷 tent | A | DEV-072：选配 + pitch×3 + mood |
| 杯子 cup | A | DEV-072：sip/focus + sip×3 |
| 做饭 cook | A | DEV-072：替换扇子 |
| ~~扇子 fan~~ | — | 已移除 |

---

## 强制工作流

```
1. 写/更新 SPEC，声明目标档 A/B/C
2. 按评分表自打分（写进 PR/回复或 docs 短表）
3. <16 分：先补相位/公式/文生图/playtest，再写代码收尾
4. 文生图必须套 linjian-rich-gear prompt-lock
5. love game --playtest PASS；audit 0 fail
6. DEV-XXX；更新本 skill「基准线」与 怎么玩.md
```

---

## 回复用户时的评价格式

```markdown
### 装备横向评价 · <名称>
| 维度 | 分 | 证据 |
...
**合计 x/20 → A|B|不及格**
**缺口**：…
**已补 / 下一步**：…
```

新增装备交付末尾 **必须**附上此表；不得只写「做完了」。

---

## 反例（直接不及格）

- 背包图标 + toast「好了」  
- 只有开/关无选配  
- ImageDraw 画展示 PNG  
- 占着第六格却比扇子时代还薄  

## 正例锚点

手冲：7 相、多 catalog、三帧、`computeTaste`、可再冲、独立模块、playtest rebrew。
