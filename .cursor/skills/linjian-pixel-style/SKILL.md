---
name: linjian-pixel-style
description: >-
  Enforces 16-bit pixel-art consistency for 露营之旅 (linjian) runtime PNGs.
  Use when adding, replacing, generating, or reviewing game/assets, title,
  story frames, tiles, gear icons, ritual close-ups, or when the user mentions
  像素风格、画风一致、写实、糊图、素材扫描、pixel style.
---

# 露营之旅 · 像素风格闸门

运行时只允许 **16-bit 硬像素**：大色块、限色、nearest。禁止写实照片、厚涂插画、高斯光晕、平滑渐变。

权威体验仍看 [docs/游戏设计-SPEC.md](../../../docs/游戏设计-SPEC.md)。本 skill 管 **进 `game/assets/` 的图**。

## 何时必跑

改任何 PNG / 文生图进游戏 / 切图脚本之后，先审计再 playtest：

```bash
cd /Users/ruska/projects/3ds/linjian
python3 scripts/audit-pixel-style.py
love game --playtest
```

`audit` 必须 exit 0。FAIL 的图不得进运行时。

## 能进游戏 vs 只能当参考

| 路径 | 角色 |
|------|------|
| `game/assets/**`（除备份目录） | **必须**像素风，玩家会看见 |
| `docs/mockups/`、`docs/storyboards/style_ref_*`、`docs/promo/` | 情绪参考，**禁止原样拷进 game/** |
| `*_v1.png`、`_tiles_v1/`、`ritual/_drip_v1/`、`title_top_paint.png` | 旧版备份，勿再加载 |

## 硬规则

1. **nearest only**：`love.graphics.setDefaultFilter("nearest","nearest")`。禁止线性放大。
2. **限色**：全屏（标题/分镜/背包底）目标 **≤64** 不透明色；小精灵 **≤32**。
3. **硬边**：轮廓是整像素台阶。禁止抗锯齿半透明边、照片噪点、纸纹扫描感。
4. **禁止**：写实天空/体积光、手冲照片、模糊萤火虫光斑、先糊再放大。
5. **可读优先**：宁可少细节，不要 8×8 糊成一团。花/营火/图标要一眼能认。
6. **整数倍缩放**：仪式特写、鸟/虫用 ×2。不要 1.7× 这种非整数。

## 新图管线

**玩法贴图 / 图标 / 特写**（营地、装备、仪式）：

- 用脚本逐像素画，或从已通过审计的像素稿切。
- 参考色：草地 `(78,148,42)`、泥地 `(166,124,62)`、溪水 `(32,108,176)`、帐篷浅褐 `(214,184,120)`。
- 现成脚本：`scripts/build-camp-tiles.py`、`scripts/build-critters.py`、`scripts/enforce-pixel-style.py`。

**标题 / 分镜全屏**：

1. 构图可先文生图，但 **必须过像素锁**：
   - cover 到目标尺寸（上屏 400×240，下屏 320×240）
   - 可先收到 **200×120** 再 **×2 nearest**（这是 16-bit，不是糊化）
   - median-cut 量化到 32–48 色
2. 禁止 LANCZOS 直接当成品；禁止「极轻 posterize」后仍留几千色。
3. 过完 `audit-pixel-style.py` 才替换 `game/assets/title_*.png` / `story/*.png`。

## 审计阈值（脚本已编码）

- 全屏 unique RGB **>180** → FAIL（还是厚涂/照片）
- 全屏又 **太平滑**（邻域色差很低）→ FAIL
- 小精灵 unique **>56** → WARN（抗锯齿脏边）

修法：跑 `python3 scripts/enforce-pixel-style.py`，或手绘替换，再审计。

## 不要做

- 把 `docs/mockups/` 午后油画当标题底图
- 为了「旧屏感」加高斯模糊
- 萤火虫/灯光用径向模糊贴图（改硬像素点或代码画矩形）
- 同一场景混照片、厚涂、像素三种分辨率
