# 帐篷模块 SPEC（单款直开 · DEV-091）

> 从属：[游戏设计-SPEC.md](./游戏设计-SPEC.md) · [动画与交互-SPEC.md](./动画与交互-SPEC.md)  
> 取代：DEV-070/072 的三维选配与搭建仪式  
> 取舍：帐篷是营地基础设施，不再与手冲/泡茶争夺操作节奏。

---

## 1. 体验一句话

选中唯一的米白尖顶帐篷，按 A 直接展开；再次按 A 收起。

---

## 2. 操作

- 未搭：平地上选中帐篷，A → 直接展开。
- 已搭：再次使用帐篷，A → 直接收起。
- 不创建 `ritual`，无颜色、款式、门帘和搭建分步。

---

## 3. 地图表现

- 背包只使用 `assets/gear/tent.png` 目录 icon；营地展开态独立使用 `assets/scenes/forest/camp/tent_open_hd.png`。
- PNG 透明叠在原土地上，不带草地垫。
- 展开资源由纯 `#00FF00` 绿幕文生图经 CKE 直出 **96×72**，有效 bbox 为 **92×68**；运行时以 0.5× 显示为 **46×34px（2.9×2.1 格）**，没有放大目录小图。
- 实体底边按 CKE bbox 的 `y=70` 校准落地。
- 底边三格作为碰撞 footprint，人物可从帐篷前后绕行，但不能横穿布面。
- 以脚点所在行为 Y-sort 锚点：人物在帐篷后方时先画、被布面遮住；走到前一行时后画、显示在帐篷前。
- 日记写入固定氛围句。

---

## 4. 资源

| 路径 | 说明 |
|------|------|
| `docs/promo/tent_camp_open_chroma_gen_ref.png` | 纯绿幕高清制作源；帐篷主体禁用绿色 |
| `game/assets/scenes/forest/camp/tent_open_hd.png` | 营地展开态 96×72 CKE 运行时资源 |
| `game/assets/gear/tent.png` | 仅背包目录 icon，不再用于营地绘制 |
| `game/assets/previews/codex/tent.png` | 图鉴上屏 320×180 预览；由高分辨率帐篷制作源构建 |
| 旧 `gear/tent/`、`camp/tent/pitch_*` | 不再运行时加载，保留历史资源 |

---

## 5. 验收

- [x] 一次 A 直接展开，不进入 ritual  
- [x] 再次 A 收起  
- [x] 目录 icon 与营地高清资源分层
- [x] 透明叠地，展开轮廓约 2.9×2.1 格
- [x] 三格底边不可穿越，前后可绕行
- [x] 人物后方被遮挡、前方显示在前
- [x] mood 短句进入日记  
- [x] audit 0 fail  
