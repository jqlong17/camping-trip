# 露营之旅

Nintendo 3DS 上的**休闲露营小游戏**（爱好向，不上架）。  
一个夏天上班族周末逃进林间：搭帐篷、手冲咖啡、看河水从早到晚，夜里点起露营灯，第二天收拾行李回家——下一周再来，装备略有不同。

工程目录名仍为 `linjian`（曾用名「林间一夜」）；**对玩家展示名称以「露营之旅」为准**。

## 文档索引

| 文档 | 说明 |
|------|------|
| **[docs/游戏设计-SPEC.md](./docs/游戏设计-SPEC.md)** | 完整体验规格 + DEV 日志 |
| **[docs/动画与交互-SPEC.md](./docs/动画与交互-SPEC.md)** | 四向精灵 / 手冲仪式 / 帐篷开合 |
| **[docs/怎么玩.md](./docs/怎么玩.md)** | 操作说明 + Agent 自测 `love game --playtest` |
| **[项目背景.md](./项目背景.md)** | 硬件/CFW、部署踩坑、给后续 Agent 的接续说明 |
| `.cursor/skills/linjian-camping-3ds/` | 本项目 Agent Skill（约束与工作流） |
| `game/` | 运行中的源码与资源（`main.lua`、`assets/`、`fonts/`） |
| `dist/3ds/linjian/` | 可直接拷到 SD 的目录镜像 |
| **[docs/storyboards/](./docs/storyboards/)** | 序章/出发/回家分镜；进游戏用清晰 400×240 |
| `vendor/` | LovePotion 3DS 预编译包 |

> 清掉 Cursor 对话后：先读 **SPEC**，再读 **项目背景**。

## 体验摘要

- **标题画面**：进入后的第一屏——上屏风景标题，下屏「开始旅程」等菜单（见 SPEC §2）。  
- **一局** = 一个周末：抵达 → 白天活动 → 夜里点灯 → 次日回家。  
- **循环**：下一周末豆子/小目标可略变，偏治愈重复。  
- **打磨重点**：人物细节、咖啡器具、帐篷与光线，而非战斗数值。

## 技术

- [LÖVE Potion 3.0.2](https://github.com/lovebrew/lovepotion)（LÖVE 系自制框架）
- 上屏 400×240：俯视像素林子 / 标题背景  
- 下屏 320×240：菜单或背包装备（触摸）  
- 真机形态：`.3dsx` + 旁路 `game/`（**不是** FBI 安装的 `.cia`）

## 电脑预览

```bash
brew install --cask love   # 若未安装
cd /Users/ruska/projects/3ds/linjian
love game
```

上下屏叠成 400×480。WASD / 方向键走路，点下屏背包。若 macOS 无法验证 love：系统设置 → 隐私与安全性 → 仍要打开。

中文：桌面用 `game/fonts/zh-ui.ttf`；真机用系统 `chinese` 字体。新增中文文案时需扩展字体子集。

## 真机（SD 卡）

**一键发版（同步 + 自动打 CIA）：**

```bash
cd /Users/ruska/projects/3ds/linjian
./scripts/deploy-to-sd.sh
```

会刷新 `3dsx + game/`，打包 **`linjian.cia`**，并拷到 SD 的 `3ds/linjian/` 与 `cias/linjian.cia`。

- FBI：`cias/linjian.cia` → Install CIA → 主画面进入  
- 日常热更（不重装 CIA）：`./scripts/deploy-to-sd.sh --no-cia`，用 HB 菜单打开 `3ds/linjian`  
- 只打 CIA：`./scripts/build-cia.sh`

旁路目录仍可用：

```
sdmc:/3ds/linjian/
  lovepotion.3dsx
  game/
  linjian.cia
sdmc:/cias/linjian.cia
```

1. 拷贝完成后**关机**再拔卡。  
2. 详见 [项目背景.md](./项目背景.md)（Luma 需较新；需 `dspfirm.cdc`）。

## 风格

2.5D 俯视像素（借鉴三角力量透视感）；角色是夏天上班族露营装，不是林克。氛围参考 `docs/mockups/`。
