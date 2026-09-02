# 杯子品尝模块 SPEC（A 档加深 · DEV-072 / DEV-075）

> 从属：[游戏设计-SPEC.md](./游戏设计-SPEC.md) · `asset_paths.CUP_STYLES`  
> 对标：手冲品尝深度

---

## 1. 体验一句话

有壶时先选杯（保留 3×9），确认后进入品尝仪式：关注点 → 三帧抬杯特写；文案含杯型修正 + 关注维度。

---

## 2. 流程

1. 装备「杯子」→ 既有 `cupPick`（杯型 × 咖啡/茶）。  
2. 确认喝下 → `CupSip` 仪式：  
   - `focus`：闻香 / 入口 / 回味（3）  
   - `brew`×3：抬杯 → 入口 → 放下  
3. `composeSipLine` 拼：杯名 · 基味 · 杯型 mod · 关注点 · 第 N 口  

**已删**：一口大小（浅尝/正常/大口）——体感怪，不再作为选项。

---

## 3. 资源

| 文件 | 说明 |
|------|------|
| `ritual/cup/focus_*.png` | 关注点图标（按件文生图 48×48） |
| `ritual/cup/sip_1..3.png` | 抬杯→入口→放下；**160×120**；**无人物**（只拍杯子，避免性别不一致） |
| 既有 `cups/cup_01..09` | 杯型 |

上屏使用独立 `assets/previews/ritual/cup/focus_*.png` 与 `sip_*.png`
（320×180）；48×48 focus 仅用于下屏 catalog，160×120 sip 仅作兼容资源，二者
均不得放大充当 TOP 成品。preview 直接由对应 `docs/promo/*_gen_ref.png` 构建。

---

## 4. 验收

- [x] 品尝相位 ≥ focus + brew×3  
- [x] 不同杯 + 不同 focus 文案可区分  
- [x] playtest 含 cup_sip  
- [x] 无「一口大小」相位  
