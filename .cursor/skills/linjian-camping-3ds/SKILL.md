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
5. `linjian-pixel-style` — 运行时 PNG 必须是 16-bit 硬像素

仓库根：`/Users/ruska/projects/3ds/linjian`

## 硬约束

| 项 | 约定 |
|----|------|
| 正式名 | **露营之旅** / **Camping Trip**（电脑仓库仍叫 `linjian`） |
| 引擎 | LovePotion 3.0.2；桌面预览 `love game`（LÖVE 11.x） |
| 分辨率 | 上屏 400×240；下屏 320×240；桌面纵向叠屏 |
| 部署 | `sd:/3ds/CampingTrip/CampingTrip.3dsx` + `game/`；CIA 为 `cias/CampingTrip.cia` |
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
7. **真机报错或兼容性修正（红屏 / data abort / 缺 API）必须立刻写入本 skill「真机注意」和 `3ds-homebrew-game`**，不要只改代码
8. 若动过 SD / CIA / 真机加载：python3 scripts/verify-3ds-install.py
   （插着卡时加 --require-sd）。必须 RESULT PASS，才能让用户拔卡。
```

安装预检细节见项目 skill `linjian-3ds-install`。
新开另一部 3DS 游戏（不是改露营之旅）用个人 skill `3ds-homebrew-game`。

## 真机注意（摘要）

- 白机多为 New 3DS（有 C-stick）；SD 常为 `/Volumes/NO NAME`
- 拔卡前关机；电脑写完必须 `diskutil eject`。插卡整机黑屏多半是 FAT 脏标记，不是游戏把机子弄砖了：先 `diskutil repairVolume`，再安全弹出。按住 SELECT 开机应出 Luma 菜单
- **按住 SELECT 仍全黑、但 `boot.firm` 哈希与官方 Luma 13.4 一致**：不是启动文件坏了，是机子没读到这张卡，或 Luma 菜单之后主菜单挂了。对照：**拔卡开机**有没有 Nintendo 标志。`luma/config.ini` 里 `enable_external_firm_and_modules` 必须为 0。禁止换回 `sd:/_backup_boot_2019/boot.firm`
- Luma 需较新；需 `dspfirm.cdc`
- 桌面中文用 `game/fonts/zh-ui.ttf`（改文案后要扩子集）
- **禁止**把 CIA 放进 `sd:/3ds/CampingTrip/`（hbmenu 二次进入会 data abort）；CIA 只放 `cias/CampingTrip.cia`
- 玩家可见名称不要再用拼音 `linjian`
- 大图/分镜/走表按需加载；全屏 PNG 先 pad 到 2 的幂（`scripts/pad-pot-textures.py`）
- LovePotion 3DS **没有** `Source:setPitch`（桌面 LÖVE 有）。真机 `playSfx` **不要 clone/setPitch/stop**。另外 `Source:stop()` 在 LovePotion 3DS 是高风险调用：公开 issue 记录了对未播放 Source 调用 `stop()` 会锁机，以及停止 stream 音乐会冻结游戏；真机短音效采用“正在播放则跳过、未播放则直接 `play`”策略。详见 [LovePotion #226](https://github.com/lovebrew/lovepotion/issues/226)、[#237](https://github.com/lovebrew/lovepotion/issues/237)、[#240](https://github.com/lovebrew/lovepotion/issues/240)、[#249](https://github.com/lovebrew/lovepotion/issues/249)。菜单一动红屏是旧坑；后半程 `3dsx_app` data abort 也可能是 clone 写坏指针
- **CampingTrip CIA 已停用**：本机确认 Title `00040000004C4A00` 可让 HOME 菜单在 Luma 后黑屏。恢复：GodMode9 2.2.3（START 开机）→ HOME → Title manager → `[A:] SYSNAND SD` → 该 ID → Manage title → Uninstall title。日常只跑 `3ds/CampingTrip/CampingTrip.3dsx`；deploy 默认不得打包或复制旧 CIA。
- **Titles 删了但桌面还是旧图标**：Homemenu 缓存，不是没删掉。须 **完全关机再开机**；装新 CIA 后再关一次机。系统设置 → 数据管理 → 3DS 软件 看一眼也会刷新。不要指望删完立刻变。
- **真机日志在 SD 上**（插回电脑就能读，不必只靠红屏）：
  - LovePotion：`sd:/3ds/CampingTrip/save/camping-trip/errors/love_error_*.txt`（Lua 报错）
  - 启动探测：`sd:/3ds/CampingTrip/save/camping-trip/load_report.txt`（第一行必须是 `boot`；没有这份文件 = 没进到 `love.load`，多半是整机/HB/CIA 黑屏）
  - **禁止**在启动时 `getDirectoryItems`（真机列目录会卡死）
  - Luma：`sd:/luma/dumps/arm11/crash_dump_*.dmp`（按 A 才存）；`sd:/luma/errdisp.txt` 多半是旧系统错误
- **macOS 往 FAT 卡 rsync 会生成 `._*` AppleDouble**（每个 PNG 旁边一份）。hbmenu 扫目录、LovePotion 列目录都危险。deploy 必须 `COPYFILE_DISABLE=1` 并 `--exclude '._*'`，同步后 `find … -name '._*' -delete`。预检看到 `._*` 算 FAIL
- 分镜/营地走色块 = `newImage` 失败。先读 `load_report.txt`，不要先猜「文件没拷上」。卡上有 PNG 仍可能解码失败或根目录其实是 `game/assets/`
- `getSource()` 显示 `sdmc:/3ds/CampingTrip/game` 但 `getInfo("assets/...")` 全 nil：LovePotion 的默认虚拟挂载没暴露旁路资源。用 `mountFullPath("sdmc:/", "sdmc", "read", true)`，再读 `sdmc/3ds/CampingTrip/game/assets/...`。失败路径必须负缓存，否则 `ensureStory` 每帧重复 IO，图鉴会非常慢
- **LovePotion 3DS 不直接加载 PNG**：`newImage("foo.png")` 在真机实际查找 `foo.t3x`；日志会明确报 `Could not open file foo.t3x`。每次 PNG 改动后必须跑 `python3 scripts/build-3ds-textures.py`（tex3ds 2.3.0，RGBA8888/LZ），deploy 自动执行；预检缺任一关键 T3X 必须 FAIL

## 性能与音频调查规则

- 桌面 LÖVE 只能验证流程和代码级负载，不能代表 3DS 性能。LÖVEBrew FAQ 明确不建议用模拟器或桌面环境判断真实性能；必须以实体 3DS 为准。
- 3DS 低帧和音乐断续应先看 `load_report.txt` 的 `perf`：营地每 5 秒帧数、`slow` 和 `maxDtMs`。主线程出现数百毫秒长帧时，stream 音频断续应先按渲染阻塞处理。
- 做性能隔离时一次只改变一类变量：完整动态、静态地图、单个动态效果、无环境音、无 BGM。每次测试都记录 `perfMode` 和真机日志。
- 真机 `Source:stop()`、`Source:pause()`、未播放 Source 的 stop、频繁切换 stream 都是高风险路径；当前代码使用 `console_single_stream_no_stop`：单 BGM stream、关闭环境音、跳过 BGM stop/switch、SFX 不 stop。
- 若 `static_play_fx/console_single_stream_no_stop` 仍约 4 FPS，优先查营地渲染，而不是继续改音频。当前真机静态模式使用 `assets/camp_static_base.png/.t3x` 离线预合成地面/水岸/小装饰；运行时只画少量前景并保留轻量树/灌木风感。部署前必须运行 `scripts/build-camp-static-base.py`，deploy 已自动接入。
- 官方 issue 曾报告 3.0.1/3.0.2 时代的音频缓冲填充、stream 播放无声、stop/pause 冻结和 3DS 黑屏无声案例。它们是高相关证据，不等于每个版本都必然复现，但足以把音频 API 调用列为独立变量。
- 官方 LÖVE 优化经验要求避免不可见对象、过度绘制和隐藏循环；营地地图应优先统计每帧独立 `draw` 数量，再决定是否使用批处理或预合成。

参考：[LÖVEBrew FAQ](https://lovebrew.org/faq)、[LÖVEBrew Rendering](https://lovebrew.org/compatibility/rendering)、[LÖVE Optimising](https://love2d.org/wiki/Optimising)、[LovePotion #109](https://github.com/lovebrew/lovepotion/issues/109)、[#226](https://github.com/lovebrew/lovepotion/issues/226)、[#237](https://github.com/lovebrew/lovepotion/issues/237)、[#240](https://github.com/lovebrew/lovepotion/issues/240)、[#249](https://github.com/lovebrew/lovepotion/issues/249)、[#266](https://github.com/lovebrew/lovepotion/issues/266)

## 更多

- 阶段与 BGM 提示词：游戏设计 SPEC §8 / §11
- 操作表：`docs/怎么玩.md`
