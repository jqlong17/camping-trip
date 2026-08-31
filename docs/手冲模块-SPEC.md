# 手冲模块 SPEC（工程）

> 从属：[游戏设计-SPEC.md](./游戏设计-SPEC.md) · [动画与交互-SPEC.md](./动画与交互-SPEC.md)  
> 状态：2026-08-31 · DEV-065  
> 目标：把手冲从 `main.lua` 长 `if` 链，收成**可扩展、可单测路径清晰**的独立模块。

---

## 1. 问题与目标

**现状问题**

- 配方表、相位推进、口感公式、上下屏绘制散落在 `main.lua`（约 3900 行）。
- 加豆子/滤杯要改多处 `if phase ==`。
- 曾触发 Lua chunk **200 locals** 上限，被迫用全局表补丁。

**目标**

1. 玩法行为与 DEV-064 **一致**（可反复冲、多参数 → 口感）。  
2. 新增选项 =「改一张配方表 + 丢一张 PNG」，尽量不改推进逻辑。  
3. `main.lua` 只负责：装备入口、全局 `ritual` 指针、杯子喝法、输入路由。

非目标：不改冲煮手感数值平衡大翻修；不拆钓鱼/帐篷。

---

## 2. 文件与职责

| 路径 | 职责 |
|------|------|
| `game/drip_brew.lua` | 配方目录、相位表、推进/口感、选图加载、手冲上下屏绘制 |
| `game/main.lua` | `require`、bind 宿主回调、`tryUseGear` / 输入 / `drinkCoffee` / playtest |
| `game/assets/ritual/` | 运行时 PNG（及真机 `.t3x`） |
| `scripts/build-drip-brew-assets.py` | 文生图切硬像素图标 |
| `docs/promo/*_gen_ref.png` | 文生参考，不进运行时 |

LovePotion / 桌面 LÖVE：`require("drip_brew")`（与 `main.lua` 同目录）。

---

## 3. 宿主绑定（`DripBrew.bind`）

模块**不**直接闭包 `main` 的 `local`；启动后由 `main` 注入：

| 回调 | 用途 |
|------|------|
| `say(msg, sec)` | toast |
| `playSfx(id)` | UI / pour / cup |
| `getRitual` / `setRitual` / `clearRitual` | 仪式态 |
| `getPot` → `drippedOnce, coffeeCups` | 壶状态 |
| `setPot(drippedOnce, coffeeCups)` | 写回壶状态 |
| `ensureRitual` | 懒加载含手冲图的 `assets.ritual` |
| `drinkCoffee` | 壶未空时选手冲 → 改喝 |
| `selectCup` | 冲完自动选中杯子装备 |
| `onBrewMap(x, y, timer)` | 地图冲煮台 / 蒸汽计时 |
| `addTripCoffee(n)` | 本趟计数 |

运行时结果：`DripBrew.taste`、`DripBrew.last`（配方快照）仍挂在模块上，日记/提示可读。

---

## 4. 相位表（数据驱动）

有序表 `DripBrew.PHASES`。每项字段：

| 字段 | 说明 |
|------|------|
| `id` | `bean` / `grind` / `dripper` / `paper` / `temp` / `pours` / `brew` |
| `head` | 下屏标题短名（如「选豆子」） |
| `kind` | `choice` \| `confirm` \| `brew` |
| `catalog` | 指向 `DripBrew.beans` 等表名；`pours` 为数字列表 |
| `store` | 写入 `ritual` 的字段名（`beanI` / `tempC` / …） |
| `valueKey` | 可选；选项是表时取 `item[valueKey]`（水温取 `c`） |
| `defaultPick` | 进入该相时的默认 `ritual.pick` |
| `assetBag` | `assets.ritual` 下子表名 |
| `enterSfx` / `enterToast` | 进入下一相时的反馈（由上一相 confirm 触发） |

**推进规则**

- `choice`：A → 把当前 `pick` 写入 `store`，进入下一相并设 `defaultPick`。  
- `confirm`：A → 仅前进（滤纸）。  
- `brew`：A → `brewStep++`；超过 `brewSteps` → `finish()`。  
- 左右：仅 `kind==choice` 时 `nudge`。

扩展新相：在 `PHASES` 插入一项 +（若需）新 catalog + PNG；**禁止**再复制一整段 `elseif phase==`。

---

## 5. 配方目录与资源命名

| catalog | 资源 | 命名 |
|---------|------|------|
| `beans` | `ritual/bean_{id}.png` | id 与表一致 |
| `grinds` | `ritual/grind_{id}.png` | |
| `drippers` | `ritual/dripper_{id}.png` | |
| `temps` | `ritual/temp_{c}.png` | 用摄氏度数字 |
| `pours` | `ritual/pours_{n}.png` | |
| （滤纸） | `ritual/drip_paper.png` | |
| （冲煮帧） | `ritual/drip_1..3.png` | brewStep |

豆子项需带口感基底：`acid, sweet, body, bitter`。  
滤杯/研磨/水温/冲次的修正写在 `DripBrew.computeTaste` 的**小表**（按 id），不要散落 if。

---

## 6. 玩法契约（与产品一致）

1. 壶内还有口（`0 < cups < CUPS_PER_POT`）且已冲过 → 选手冲 = 去喝。  
2. 未冲或已喝空 → 开新仪式；喝空时清 `taste` 并重置杯数。  
3. `finish`：算口感、`cups=1`、+trip 咖啡、选中杯子、清 ritual。  
4. 一壶 `CUPS_PER_POT = 3`；喝空提示可再冲。

---

## 7. 绘制 API

- `DripBrew.drawTop(ritual, assets, ctx)`：`ctx` 含 `TOP_W/TOP_H`、`uiFont`、`drawFitted`。  
- `DripBrew.drawBottom(ritual, assets, ctx)`：`ctx` 含 `BOT_W`、`uiFont`。  
- `DripBrew.potHint(drippedOnce, coffeeCups, selectedIsCupOrDrip)` → 下屏黄条文案或 nil。

`main` 的 `drawRitualOverlay` / `drawPlayBottom` 在 `kind=="drip"` 时直接转调。

---

## 8. 验收

```bash
cd /Users/ruska/projects/3ds/linjian
love game --playtest   # 须 PASS；含 rebrew=true
```

手工：加一个假豆子 id 只改正文表 + 复制一张 bean PNG，不改 `advance` 源码即可出现在选项里。

---

## 9. DEV

| 编号 | 内容 |
|------|------|
| **DEV-065** | 手冲工程 SPEC + `game/drip_brew.lua` 模块化与相位表 |
