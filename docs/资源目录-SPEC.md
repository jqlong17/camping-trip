# 资源目录 SPEC

> 2026-08-31 · DEV-068

## 顶层结构

```
game/assets/
  cups/              # 9 种日式杯子（选杯 UI + 背包槽用 gear/cup.png）
  gear/              # 背包道具图标 tent/drip/tea/rod/fan/cup
  ui/                # 标题、下屏背包底
  cast/              # 角色立绘 / 行走表
  ritual/            # 手冲 drip/ · 泡茶 tea/ · 钓鱼 fish/
  previews/          # TOP 专用 320×180；不得由 48×48 目录图标放大
    ritual/          # drip/fish/cup/cook（泡茶由独立任务维护）
    codex/           # 图鉴主视觉；目录 icon 仍在 gear/
    cast/            # 选角主视觉；移动精灵仍在 cast/
  shared/            # 跨场景复用：树、石、灌木、花、阴影、player
  scenes/
    forest/          # 当前「林间溪流」营区
      story/         # p1–p3 序章、 d1–d2 出发
      camp/          # 地砖、岸线、帐篷、营火、静态底图
      world/         # 鸟虫鱼、手冲台蒸汽、收获图标
    coast/           # 第二目的地：海边
      story/         # depart / arrive 海边分镜
      camp/          # 沙、海、海岸植被、礁石、漂木、静态底图
      world/         # 海鸟 / 螃蟹
    home/            # 城里 / 回家
      story/         # h1 回家、 diary 日记
```

`scenes/forest/` 与 `scenes/coast/` 均按 story / camp / world 三层组织；未来
`scenes/mountain/` 继续同构扩展。目的地选择预览单列在
`previews/destinations/{forest,coast}.png`，禁止用地块或小 icon 放大。

海边生成入口：`python3 scripts/build-coast-assets.py`。制作源为
`docs/promo/coast_*_gen_ref.png` 与 `destination_select_preview_gen_ref.png`；
环境 sheet 使用洋红幕 CKE，血缘由脚本 `ASSET_PROVENANCE` 声明。

上屏分辨率、POT/T3X 和单纹理内存预算见
[上屏资源分辨率-SPEC.md](./上屏资源分辨率-SPEC.md)。构建入口：
`python3 scripts/build-top-previews.py`。

## 仪式目录图与上屏预览

- `40/48×48` catalog icon 只用于下屏选项槽、背包或图谱缩略图。
- 上屏 `drawTop/topView` 禁止直接把 catalog icon 放大；每个会占据上屏主体的选择项必须加载独立 `preview_*`。
- icon 与 preview 应从同一份高分辨率 `docs/promo/*_gen_ref.png` 分别构建，禁止“高分制作源 → 48px → 再放大”。
- 选择预览优先 256×192（POT 256×256）；全幅过程帧可用 320×180（POT 512×256），按模块总纹理预算取舍。
- 已有 120×76、160×120 或更高的独立仪式特写可按实际清晰度保留，不为统一命名重复生成。

## 代码入口

- `game/asset_paths.lua` — 运行时路径与 `CUP_STYLES` 表
- `scripts/asset_layout.py` — 构建脚本共用目录常量
- `scripts/migrate-asset-folders.py` — 一次性扁平 → 分目录迁移

## 杯子（9 种）

| 文件 | 名称 | 类型 |
|------|------|------|
| cup_01_hakuji | 白瓷杯 | 咖啡 |
| cup_02_aogama | 青磁湯吞 | 茶 |
| cup_03_kozara | 茶杯碟 | 茶 |
| cup_04_sumi | 墨釉马克 | 咖啡 |
| cup_05_beni | 朱泥茶盏 | 茶 |
| cup_06_matcha | 抹茶碗 | 茶 |
| cup_07_enamel | 搪瓷马克 | 咖啡 |
| cup_08_take | 竹节杯 | 茶 |
| cup_09_glass | 硝子咖啡 | 咖啡 |

生成：`python3 scripts/build-cups.py`（源图 `docs/promo/cups_sheet_gen_ref.png`，文生图 sheet 切硬像素）
