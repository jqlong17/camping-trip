---
name: linjian-camping-3ds
description: >-
  Builds and iterates the Nintendo 3DS homebrew camping game「露营之旅」(repo linjian)
  on LovePotion/LÖVE. Use when working under projects/3ds/linjian, editing game/main.lua,
  storyboards, cast sprites, camp rituals, playtest, SPEC/DEV logs, or when the user
  mentions 露营之旅、林间、3DS、LovePotion、手冲、帐篷、分镜.
disable-model-invocation: false
---

# 露营之旅 · 3DS Homebrew

## 必读

开始任何改动前读：

1. [docs/游戏设计-SPEC.md](docs/游戏设计-SPEC.md) — 体验权威；**§12 DEV-XXX** 最新编号  
2. [docs/动画与交互-SPEC.md](docs/动画与交互-SPEC.md) — 四向精灵 / 道具仪式  
3. [项目背景.md](项目背景.md) — 真机踩坑  
4. [docs/怎么玩.md](docs/怎么玩.md) — 操作与自测  
5. [linjian-pixel-style](../linjian-pixel-style/SKILL.md) — 运行时 PNG 必须是 16-bit 硬像素  

仓库根：`/Users/ruska/projects/3ds/linjian`

## 硬约束

| 项 | 约定 |
|----|------|
| 正式名 | **露营之旅**（工程目录/identity 仍为 `linjian`） |
| 引擎 | LovePotion 3.0.2；桌面预览 `love game`（LÖVE 11.x） |
| 分辨率 | 上屏 400×240；下屏 320×240；桌面纵向叠屏 |
| 部署 | `./scripts/deploy-to-sd.sh` → SD 同步 `3dsx+game/` **并自动打 `linjian.cia`**（FBI 安装）；日常热更可用 `--no-cia` |
| 语言 | 对用户回复 **中文** |
| 像素 | nearest；**16-bit 硬像素**；禁止写实/厚涂进 `game/assets`；改图后跑 `scripts/audit-pixel-style.py` |
| 自测 | 每次玩法/美术改完必须 `love game --playtest` → 日志 `PASS` |

## 整局流程（不可跳过场景）

```
title → prologue → cast → depart → play → homecoming → title
```

`startJourney()` 必须进 `prologue`，禁止直跳营地。

## 资源位置

| 用途 | 路径 |
|------|------|
| 可运行内容 | `game/` |
| 分镜进游戏 | `game/assets/story/*.png`（由 docs 清晰 400×240 导出） |
| 角色立绘/行走 | `game/assets/cast/c{N}.png`、`c{N}_walk.png` |
| 仪式/世界动效 | `game/assets/ritual/`、`game/assets/world/` |
| 角色源与参考 | `docs/characters/` |
| 分镜源 | `docs/storyboards/` |

### 行走表格式

`c{N}_walk.png`：单帧 40×40；3 列（站/走1/走2）× 4 行（下/左/右/上）= 120×160。详见动画 SPEC。

### 分镜管线

文生图 → cover 400×240 → 可 200×120 再 ×2 nearest → 限色 32–48 → `audit-pixel-style.py` → `game/assets/story/`。  
**禁止**写实厚涂原样进游戏；**禁止**高斯模糊旧屏化。

## 营地细节水位（持续加）

优先顺序：

1. 四向走动帧切换  
2. 帐篷开合在地图可见  
3. 手冲 **三步仪式画面** + 地图冲煮台/蒸汽  
4. 小锅/钓鱼轻反馈  
5. 夜里点灯（已有则保留）  
6. 夜晚：星星 / 流星 / 萤火虫 / 树叶随风（色罩之后画）

仪式用 `ritual` 叠加态，不要只 toast。

## Agent 工作流

```
1. 读 SPEC §12 最新 DEV + 相关章节
2. 改 game/ 与资产
3. 若动了 PNG：python3 scripts/audit-pixel-style.py
4. love game --playtest
5. 确认 PASS 与截图
6. 写 DEV-XXX；必要时更新 怎么玩.md / 动画 SPEC
```

## 真机注意（摘要）

- 白机 Old 3DS；SD 常为 `/Volumes/NO NAME`  
- 拔卡前关机；Luma 需较新；需 `dspfirm.cdc`  
- 桌面中文用 `game/fonts/zh-ui.ttf`（改文案后要扩子集）

## 更多

- 阶段与 BGM 提示词：游戏设计 SPEC §8 / §11  
- 操作表：`docs/怎么玩.md`
