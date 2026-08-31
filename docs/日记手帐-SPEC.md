# 日记手帐页 SPEC（TN 窄高本）

> 从属：[游戏设计-SPEC.md](./游戏设计-SPEC.md) §3.0.5  
> 状态：2026-08-31 · DEV-071  
> 目标：回家 `diary` 场景做成 **Traveler's Notebook 式窄高手帐**，可写字、有桌面氛围，文生图进包。

---

## 1. 体验一句话

周末结束摊开一本窄高的手帐：奶油纸页、松紧带痕迹、木桌夜灯；本趟短句写在本子上，而不是糊在半透明黑条里。

---

## 2. 构图（上屏 400×240）

| 层 | 内容 | 说明 |
|----|------|------|
| 底 | 书桌氛围 | 木纹桌面、暖灯/窗侧光，16-bit；**不要**抢正文 |
| 中 | **TN 打开本** | **窄高**（约宽:高 ≈ 1:1.8～2.0）；居中略偏左；可见书脊/松紧带/牛皮护封边 |
| 上 | 文字 | 标题 + 本趟日记行，落在**左页**（或跨中缝短行），深褐墨水色 |
| 侧 | 角色小照 | 右页或桌角贴一张选角头肩（scissor），像夹进手帐的照片 |

**禁止**：全屏铺开的横向大本、把正文画进厚涂油画底、半透明黑底盖满半屏。

推荐本子逻辑尺寸（绘制用）：约 **120×210**～**130×220**（相对 400×240 仍显窄高）；×1 或 ×2 nearest 贴图。

---

## 3. 资源

| 文件 | 尺寸意图 | 用途 |
|------|----------|------|
| `docs/promo/diary_desk_gen_ref.png` | 宽屏桌面 | 文生参考 |
| `docs/promo/diary_tn_open_gen_ref.png` | 竖向打开本 | 文生参考 |
| `game/assets/scenes/home/story/diary_desk.png` | 512×256 POT 或 400×240 | 运行时桌底 |
| `game/assets/scenes/home/story/diary_tn.png` | 透明底窄高本 | 打开手帐 |
| `game/assets/scenes/home/story/diary.png` | 可保留旧底作 fallback | 旧全屏日记 |

脚本：`scripts/build-diary-tn-assets.py`（只切图/限色，禁止 ImageDraw 画本子）。  
**抠图约定**：打开本必须用 **纯绿幕 `#00FF00`** 文生图，脚本只抠 chroma green；禁止 cream/木纹通杀（会把纸页扣穿）。

---

## 4. 绘制（`draw/story.lua`）

`StoryDraw.diaryTop()`：

1. 画 `diary_desk` 铺满上屏（无则回退 `diary`）。  
2. 居中偏左画 `diary_tn`（保持窄高，勿拉扁）。  
3. 在本子左页矩形内打印「周末手帐」+ `GearPlay.diaryTripLines()`（深墨色，无大黑底条）。  
4. 右页或桌角叠角色头肩小照。  
5. 右下角淡提示「A 合上保存」即可，勿再用粗黑底条挡内容。

`StoryDraw.diaryBottom()`：木色底 + 本趟/累计摘要 + 「按 A 保存并回标题」（可加细线框模仿便签）。

---

## 5. 文生图约束

套用 `linjian-rich-gear` prompt-lock：

- 16-bit pixel art / hard pixels / thick outlines / limited palette  
- NO blur / photorealism / soft gradients  
- TN：elastic band, kraft or soft leather cover edge, cream lined or blank insert pages, open flat on wood desk  
- 竖本主体占画面高度大半、宽度明显小于高度  

---

## 6. 验收

- [x] 上屏一眼是「窄高手帐摊在桌上」，不是横向大本  
- [x] 日记字写在纸页上可读  
- [x] 文生图 → promo ref → 硬像素 → audit 0 fail  
- [x] `love game --playtest` 含 diary 截图 PASS  
- [x] DEV-071 写入游戏设计 SPEC  

---

## 非目标

不改存档字段；不做翻页动画（可后续 DEV）；不引入真实 TN 商标素材。
