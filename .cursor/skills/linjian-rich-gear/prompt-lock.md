# 文生图 Prompt 锁（露营之旅）

所有为 `linjian` 生成的装备 / 仪式 / 图标 sheet，在调用文生图时把下面块 **原样拼进 description**（可在中间插入具体物件列表）。

## 固定前缀

```
16-bit pixel art sprite sheet for a Nintendo 3DS camping game 「露营之旅」.
Hard pixels, thick black outlines, limited color palette, flat shading,
NO blur, NO anti-aliasing, NO photorealism, NO soft gradients, NO cinematic lighting.
Retro game inventory / ritual asset style, crisp readable silhouettes.
```

## 固定后缀

```
Consistent scale and lighting across items. Cream or plain wood-plank background.
Each subject must stay recognizable at ~48×48 game-icon size after downscale.
```

## 构图约定

| 用途 | 构图 | 产出后 |
|------|------|--------|
| 多选一目录（豆/茶/帐/灯/杯） | 横向 4–9 件等分 | `slice` → `cups/`、`ritual/` 或 `gear_` 48×48 |
| 仪式三步特写 | 三等分横条或分三次 gen | `*_1..3.png` **120×76** |
| 单背包图标 | 1:1 居中主体 | `gear_<id>.png` 48×48 |
| 登山/氛围全屏 | 400×240 意图；可先 200×120 | ×2 nearest + 限色 32–48 → `story/` 或营地底 |

## 主题加料（写在物件列表里）

- **露营**：wood table, canvas, warm afternoon or camp night, quiet weekend mood  
- **茶**：porcelain / zisha / enamel camping ware, steam optional as hard pixels  
- **帐篷**：top-down or 3/4 camping tent, solid color blocks per variant  
- **灯**：lantern silhouette, warm vs cool as flat color not glow bloom  
- **登山**：trail, pack, poles — still pixel icons, not photo landscapes in icon sheets  

## 禁止词

`photorealistic`, `8k`, `ultra detailed skin`, `depth of field`, `bokeh`, `ray tracing`, `oil painting`, `watercolor`, `blurry background`

## 进包前

1. 原图存 `docs/promo/<name>_gen_ref.png`  
2. `scripts/build-*-assets.py` 硬像素  
3. `python3 scripts/audit-pixel-style.py` → 0 fail  
