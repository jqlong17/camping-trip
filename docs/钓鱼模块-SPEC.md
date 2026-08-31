# 钓鱼模块 SPEC（工程）

> 从属：[游戏设计-SPEC.md](./游戏设计-SPEC.md) · [动画与交互-SPEC.md](./动画与交互-SPEC.md)  
> 状态：2026-08-31 · DEV-067  
> 对标：手冲 / 泡茶（A 仪式档）

---

## 1. 问题与目标

**现状问题**

- 钓竿仅 4 帧自动短片，无选择；鱼种纯随机。
- 与手冲/泡茶丰富度落差大。

**目标**

1. 溪边可反复钓；≥4 个独立选择维 + 抛竿确认 + 起鱼过程帧。  
2. 选点 / 饵 / 坠 / 手法影响**中鱼率**与**鱼种权重**，并产出氛围短句。  
3. 逻辑进 `game/fish_rod.lua`；资源进 `game/assets/ritual/fish/`。

非目标：不做真实物理抛投、不新开鱼种图鉴页（沿用香鱼/溪鳟/鲤鱼）。

---

## 2. 文件与职责

| 路径 | 职责 |
|------|------|
| `game/fish_rod.lua` | 目录、相位、概率、推进、上下屏绘制、选图加载 |
| `game/main.lua` | require、bind、溪边入口、输入 nudge、playtest |
| `game/assets/ritual/fish/` | 饵/点/坠/手法图标 + `fish_1..4` / miss |
| `scripts/build-fish-rod-assets.py` | 文生图切硬像素 |
| `docs/promo/fish_*_gen_ref.png` | 文生参考 |

---

## 3. 相位表

| id | head | kind | 说明 |
|----|------|------|------|
| `spot` | 选钓点 | choice | 浅滩 / 深潭 / 桥墩 / 水草边 / 急流旁 |
| `bait` | 选鱼饵 | choice | 蚯蚓 / 面团 / 假饵 / 昆虫 / 玉米 |
| `sinker` | 选铅坠 | choice | 轻 / 中 / 重 |
| `cast` | 抛竿 | confirm | A 抛出 |
| `style` | 竿法 | choice | 死等 / 轻抽 / 逗引 |
| `brew` | 起鱼 | brew | 4 步：抛线→等漂→咬钩→起竿（A 推进；可跳过） |

---

## 4. 结果公式（概要）

- **中鱼率** = clamp(0.35 + 饵/点/手法修正, 0.25, 0.92)  
- **鱼种权重**：香鱼偏浅滩+昆虫+轻抽；溪鳟偏深潭/急流+假饵+逗引；鲤鱼偏桥墩/水草+面团/玉米+死等  
- **氛围句** `FishRod.mood`：如「浅滩 · 昆虫 · 轻抽 → 水花清亮」

---

## 5. 资源命名

```
ritual/fish/bait_<id>.png          # 48×48
ritual/fish/spot_<id>.png
ritual/fish/sinker_<id>.png        # light|mid|heavy
ritual/fish/style_<id>.png         # wait|twitch|dance
ritual/fish/fish_1..4.png          # 120×76
ritual/fish/fish_4_miss.png
```

手冲 / 泡茶已分目录：`ritual/drip/`、`ritual/tea/`。

---

## 6. 宿主绑定

| 回调 | 用途 |
|------|------|
| `say` / `playSfx` | 提示与音效 |
| `getRitual` / `setRitual` / `clearRitual` | 仪式态 |
| `ensureRitual` | 懒加载图 |
| `onFishSplash` | 咬钩/起鱼时触发溪边鱼跃 FX |
| `addFish(kind)` | 写入 `tripHaul.fish` |
| `fishName(kind)` | 中文名 |
