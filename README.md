# 露营之旅

Nintendo 3DS 上的**休闲露营小游戏**（爱好向，不上架）。  
一个夏天上班族周末逃进林间：搭帐篷、手冲咖啡、看河水从早到晚，夜里点起露营灯，第二天收拾行李回家——下一周再来，装备略有不同。

对玩家：**露营之旅** / **Camping Trip**。电脑仓库目录仍叫 `linjian`，真机 Homebrew 文件夹和 CIA 文件名用 `CampingTrip`，不再用拼音。

## 文档索引

| 文档 | 说明 |
|------|------|
| **[docs/游戏设计-SPEC.md](./docs/游戏设计-SPEC.md)** | 完整体验规格 + DEV 日志 |
| **[docs/动画与交互-SPEC.md](./docs/动画与交互-SPEC.md)** | 四向精灵 / 手冲仪式 / 帐篷开合 |
| **[docs/怎么玩.md](./docs/怎么玩.md)** | 操作说明 + Agent 自测 `love game --playtest` |
| **[项目背景.md](./项目背景.md)** | 硬件/CFW、部署踩坑、给后续 Agent 的接续说明 |
| `.cursor/skills/linjian-camping-3ds/` | 本项目 Agent Skill（约束与工作流） |
| `game/` | 运行中的源码与资源（`main.lua`、`assets/`、`fonts/`） |
| `dist/3ds/CampingTrip/` | 可直接拷到 SD 的目录镜像 |
| **[docs/storyboards/](./docs/storyboards/)** | 序章/出发/回家分镜；进游戏用清晰 400×240 |
| `vendor/` | LovePotion 3DS 预编译包 |

> 清掉 Cursor 对话后：先读 **SPEC**，再读 **项目背景**。

## Agent 记录准则

这个项目已经多次遇到“真机现象和桌面结果完全不一致”的问题：PNG/T3X、LovePotion 音频、HOME Menu/CIA、FAT32 脏状态、营地性能都靠日志和文档才避免重复试错。任何 Agent 接手后，不能只在代码里修完就结束，必须把本轮新增事实、假设、验证命令、真机日志结论和后续判断口径写回文档。

最低记录要求：

1. 改玩法、性能、部署、真机兼容性后，更新 [docs/游戏设计-SPEC.md](./docs/游戏设计-SPEC.md) 的 DEV 日志。
2. 真机加载、黑屏、音频、T3X、SD/FAT、CIA/Homebrew 相关经验，更新 [docs/3DS真机开发踩坑与发布准则.md](./docs/3DS真机开发踩坑与发布准则.md)。
3. 会改变后续 Agent 工作方式的规则，同步更新 `.cursor/skills/linjian-camping-3ds/SKILL.md`。
4. 每条结论要写清楚证据等级：桌面 playtest、SD 日志、真机现象、公开资料，还是推测。
5. 部署到 SD 前后写明验证结果；插着卡时必须跑 `python3 scripts/verify-3ds-install.py --require-sd`，通过后再 `diskutil eject`。

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

**一键部署（仅同步安全的 3DSX + game/）：**

```bash
cd /Users/ruska/projects/3ds/linjian
./scripts/deploy-to-sd.sh
```

会刷新 `3dsx + game/`，自动生成营地静态底图和 3DS 所需 T3X 纹理，并同步到 SD 的 `3ds/CampingTrip/`。默认不打包、不复制 CIA。

- 日常测试：Homebrew 里选 **CampingTrip**。
- 预检：`python3 scripts/verify-3ds-install.py --require-sd` 必须 `RESULT PASS`。
- CIA：本项目日常停用；不要通过 FBI 安装 `CampingTrip.cia`，除非明确重新做单变量实验。

旁路目录：

```
sdmc:/3ds/CampingTrip/
  CampingTrip.3dsx
  game/
```

1. 电脑同步完成后必须 `diskutil eject "/Volumes/NO NAME"`，再拔卡。
2. 详见 [项目背景.md](./项目背景.md)（Luma 需较新；需 `dspfirm.cdc`）。

## 风格

2.5D 俯视像素（借鉴三角力量透视感）；角色是夏天上班族露营装，不是林克。氛围参考 `docs/mockups/`。
