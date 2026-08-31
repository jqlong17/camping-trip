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
  shared/            # 跨场景复用：树、石、灌木、花、阴影、player
  scenes/
    forest/          # 当前「林间溪流」营区
      story/         # p1–p3 序章、 d1–d2 出发
      camp/          # 地砖、岸线、帐篷、营火、静态底图
      world/         # 鸟虫鱼、手冲台蒸汽、收获图标
    home/            # 城里 / 回家
      story/         # h1 回家、 diary 日记
```

未来 `scenes/coast/`、`scenes/mountain/` 等按同样三层（story / camp / world）扩展。

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
