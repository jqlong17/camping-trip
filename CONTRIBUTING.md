# 一起来把「露营之旅」做下去

这是一款爱好向的 Nintendo 3DS 自制游戏。仓库刚开源，缺人手，也欢迎只来玩、提体验的人。

你不需要先成为 3DS 专家。像素图、文案、新仪式、新目的地、真机反馈，都算共建。

## 你可以从这里开始

- 开 [Issue](https://github.com/jqlong17/camping-trip/issues) 说卡顿、缺字、想加的装备，或某台真机上的现象
- 提 Pull Request：修 bug、加内容、补文档都可以
- 如果是第一次来，先看 [README](./README.md) 的安装说明，以及 [docs/怎么玩.md](./docs/怎么玩.md)
- 要摸清故事节点和资源血缘，打开本地工作台：`cd tools/story-atlas && npm install && npm run dev`，浏览器访问 `http://127.0.0.1:5173/`

特别欢迎：

- 新的周末目的地（不只林间 / 海边）
- 和手冲、泡茶同级的新仪式，而不是一句提示就结束
- 16-bit 硬像素新图（角色、道具、分镜）
- 更多真机型号上的测试记录
- 翻译、操作说明、新手向导

## 本地跑起来

```bash
brew install --cask love   # macOS 未安装时
love game
```

改完玩法或美术后：

```bash
python3 scripts/audit-pixel-style.py   # 动过 game/assets 时
love game --playtest
LINJIAN_PLAYTEST_DESTINATION=forest love game --playtest
```

日志里要看到 `PASS`。

## 写代码时请守住的几条

1. 玩家看见的名字是 **露营之旅 / Camping Trip**，不要用拼音 `linjian` 当标题。
2. 运行时 PNG 必须是 **16-bit 硬像素**，不要把写实厚涂直接放进 `game/assets`。
3. 新装备/仪式请先写 `docs/<主题>模块-SPEC.md`，深度对齐手冲和泡茶，不要只弹一句 toast。
4. 真机不要在 `goPlay()` 或绘制函数里一次性读完全部营地贴图。
5. 真机环境音用短 PCM WAV 静态循环，不要对溪水/海浪走 MP3 stream。
6. 不要把 `.cia` 放进 `sd:/3ds/CampingTrip/`，否则 Homebrew 二次进入可能崩溃。
7. 改动写进 [docs/游戏设计-SPEC.md](./docs/游戏设计-SPEC.md) 的 DEV 日志。真机新坑写进 [docs/3DS真机开发踩坑与发布准则.md](./docs/3DS真机开发踩坑与发布准则.md)。

更完整的约束在 `.cursor/skills/linjian-camping-3ds/SKILL.md`。

## 提 PR

- 说清楚改了玩家能看见的哪一步
- 如果动了图，附上 playtest 截图或说明
- 小步、可回看；一次 PR 只做一件事会更容易合并

开源的目的不是把仓库丢到网上，而是让喜欢露营、像素和 3DS 的人能一起把这周末营地补完整。欢迎来玩，也欢迎留下一顶帐篷。
