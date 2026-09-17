# 3DS 真机开发踩坑与发布准则

> 项目：露营之旅（Camping Trip）
> 引擎：LovePotion 3.0.2
> 记录日期：2026-08-30
> 用途：后续 Agent 接手真机加载、部署、崩溃和 HOME Menu 恢复工作前必读。

## 1. 先说结论

今天最昂贵的两次试错，其实都有公开资料可以提前避免：

1. **LovePotion 的 3DS 后端不能直接把运行时 PNG 当纹理使用。**
   Lua 仍写 `love.graphics.newImage("assets/foo.png")`，但真机会查找同路径的
   `assets/foo.t3x`。每张运行时 PNG 都必须在部署前用 `tex3ds` 转换。
2. **LovePotion 官方不支持 CIA/NSP 安装版。**
   本项目自制 CIA `00040000004C4A00` 曾让 HOME Menu 在 Luma 启动后黑屏。
   日常开发和最终发布都应优先使用 game folder 或 fused 3DSX，不再把 CIA
   当作发布目标。

固定路线：

```text
开发：sdmc:/3ds/CampingTrip/CampingTrip.3dsx + game/
发布：优先 fused 3DSX
CIA：停用
```

## 2. 证据等级

后续 Agent 写诊断结论时必须区分：

- **官方事实**：LovePotion 文档/源码、devkitPro、Luma、GodMode9、
  3DS Hacks Guide 明确说明，可直接作为实现依据。
- **平台机制**：3dbrew、格式规范、维护者 issue，可作为高可信解释。
- **社区经验**：GitHub issue、GBAtemp、Reddit 个案，只用于提出假设。
- **本项目实测**：只证明这台机器和这个构建出现过，不能擅自写成平台通病。

修复后现象消失，只能说明修复与恢复相关，不能自动证明此前猜测的单一根因。

## 3. 今天遇到的问题与公开经验

### 3.1 PNG 在卡上，但标题、分镜、图鉴仍是色块

**证据：官方明确。**

LovePotion 3DS 的 ImageModule 只注册 T3X 处理器。调用：

```lua
love.graphics.newImage("assets/title_top.png")
```

真机实际会读取：

```text
assets/title_top.t3x
```

本项目日志中的 `Could not open file ...title_top.t3x` 已直接证明这一点。

固定做法：

- `python3 scripts/build-3ds-textures.py` 将全部运行时 PNG 转为同名 T3X。
- PNG 和 T3X 可以并存：桌面 LÖVE 读 PNG，3DS 读 T3X。
- 任一关键 T3X 缺失、过期或小于合理文件大小，部署必须失败。
- 转换失败必须中止，不允许“先拷卡上试试”。
- 不要把 Lua 路径改为 `.t3x`；代码仍引用 `.png`。

主要来源：

- [LÖVEBrew Rendering](https://lovebrew.github.io/compatibility/rendering)
- [devkitPro tex3ds](https://github.com/devkitPro/tex3ds)
- [LovePotion 3DS ImageModule 源码](https://github.com/lovebrew/lovepotion/blob/906511d4e05b47015da5bf85ad554fe6542b1c81/platform/ctr/source/modules/imagemodule_ext.cpp)

### 3.2 `Source:setPitch` 红屏或 nil

**证据：源码明确。**

LovePotion 3DS 的 Source Lua 方法表没有注册 `setPitch` / `getPitch`。
这不是偶发兼容性问题，不能仅用 `pcall` 后继续依赖它。

固定做法：

- 真机完全不调用 `setPitch`。
- BGM 使用 `stream`，短 SFX 使用 `static`。
- 真机复用少量 Source，当前项目采用 `stop()` 后 `play()`。
- `clone()` 在官方源码中有实现；本项目曾在 clone 后出现 data abort，
  只能记为本机风险，不能写成“LovePotion 普遍不支持 clone”。
- 需确认 `sdmc:/3ds/dspfirm.cdc` 存在。

主要来源：

- [LovePotion Source Lua 注册表](https://github.com/lovebrew/lovepotion/blob/906511d4e05b47015da5bf85ad554fe6542b1c81/source/objects/source/wrap_source.cpp)
- [LovePotion 3DS Source 后端](https://github.com/lovebrew/lovepotion/blob/906511d4e05b47015da5bf85ad554fe6542b1c81/platform/ctr/source/objects/source_ext.cpp)
- [LovePotion 3.0.2 发布说明](https://github.com/lovebrew/lovepotion/releases/tag/3.0.2)

### 3.3 game folder 中资源路径不可见

**证据：API 官方，本项目路径行为为真机实测。**

LovePotion 3.0 提供：

```lua
love.filesystem.mountFullPath(fullPath, mountPoint, permissions, append)
```

本机中 `getSource()` 显示 `sdmc:/3ds/CampingTrip/game`，但默认虚拟路径下
`getInfo("assets/...")` 返回 nil。当前项目通过：

```lua
love.filesystem.mountFullPath("sdmc:/", "sdmc", "read", true)
```

再从：

```text
sdmc/3ds/CampingTrip/game/assets/...
```

读取。

注意：

- API 和签名是官方事实。
- “所有 game folder 都必须挂载 SD 根目录”不是官方结论，只是本机实测。
- 启动日志必须记录 `getSource()`、挂载结果和首个关键资源加载结果。

来源：

- [LovePotion 3.0-pre1](https://github.com/lovebrew/lovepotion/releases/tag/3.0-pre1)
- [Filesystem Lua 绑定源码](https://github.com/lovebrew/lovepotion/blob/906511d4e05b47015da5bf85ad554fe6542b1c81/source/modules/filesystem/wrap_filesystem.cpp)

### 3.4 装备图鉴进入极慢

**证据：工程问题，符合社区 I/O 经验。**

失败图片若在每次 `draw` / `update` 中重新执行 `getInfo` 或 `newImage`，
会反复访问 SD，造成明显卡顿。

固定做法：

- 图片加载失败后写入负缓存，同一路径本场景不再重试。
- 禁止在 `draw` / `update` 中递归扫描目录。
- 启动只检查少数已知文件，不做无界 `getDirectoryItems`。
- 场景进入时加载，离开场景后释放引用。

“`getDirectoryItems` 在所有机器上必定崩溃”没有官方依据，不应这样记录；
准确说法是启动期大量目录扫描风险高、性能差，本项目应避免。

社区来源：

- [VNDS-LOVE 3DS I/O 性能讨论](https://github.com/ajusa/VNDS-LOVE/issues/16)

### 3.5 大图、POT 与内存压力

**证据：平台实现明确。**

3DS 纹理尺寸为 8–1024 范围内的 2 次幂。LovePotion/citro3d 会把尺寸向上
取整。例如 400×240 RGBA8888 全屏图实际按 512×256 分配，约 512 KiB。

注意：

- `tex3ds -z auto` 减少的是 T3X 文件/读取体积，不等于同等减少运行时纹理内存。
- 不透明背景可评估 RGB565；需要 alpha 再使用 RGBA8888、RGBA4 或 ETC1A4。
- 统计每个场景“同时常驻”的纹理，不要只看 SD 上文件大小。
- 标题、分镜、九人走表、仪式图不能全部在启动时常驻。

来源：

- [citro3d texture.c](https://raw.githubusercontent.com/devkitPro/citro3d/master/source/texture.c)
- [LovePotion 3DS Texture 实现](https://github.com/lovebrew/lovepotion/blob/906511d4e05b47015da5bf85ad554fe6542b1c81/platform/ctr/source/objects/texture_ext.cpp)
- [3dbrew Memory layout](https://3dbrew.org/wiki/Memory_layout)

### 3.6 画面卡顿与音乐断续

**证据：本项目真机现象，根因按两个方向分别验证。**

当前营地画面约为 25x15 个地块，每帧会执行大量独立的纹理绘制；旧版本真机还会播放
48 kHz 双声道 BGM，并叠加溪水、鸟鸣或虫鸣。Old 3DS 上这两类负载可能同时造成掉帧
和音频缓冲区欠载，因此“音乐卡”不一定是音频文件损坏，也可能是主线程绘制拖慢了音频
供给。

固定做法：

- 桌面保留高质量 BGM；真机使用 `game/audio/3ds/` 下的 `22.05 kHz / mono / 64 kbps`
  版本，避免设备实时解码高采样率立体声 MP3。
- Old 3DS 真机先采用 `console_single_stream_no_stop`：只播放一条 BGM stream，关闭环境音，避免 BGM、溪水、鸟鸣、虫鸣四个流同时解码。
- 短音效使用 `static`，真机复用 Source，禁止在高频输入中 `clone()`，也禁止无条件 `stop()` 后 `play()`。
- `load_report.txt` 每 5 秒记录一次 `scene`、帧数、慢帧数和 `maxDtMs`。`maxDtMs` 明显
  升高时先处理渲染；画面稳定但音乐仍断续时再处理音频格式或 DSP 配置。
- 不要把 T3X 或 MP3 的压缩后文件大小当成运行时 GPU、线性内存或解码 CPU 成本。

这部分是本机当前构建的性能策略，不应写成 LovePotion 在所有设备上的统一限制。

### 3.6.1 网络案例对本项目的影响

**证据等级：LovePotion 官方仓库 issue + LÖVEBrew 官方文档。**

这次网络检索发现，当前现象并不是孤立的泛化猜测：

- [LovePotion #266](https://github.com/lovebrew/lovepotion/issues/266) 在 3.0.2、Nintendo 3DS、Homebrew Menu 环境报告了 stream 音乐导致黑屏无声的案例。它没有证明本项目必然是同一 bug，但说明 3.0.2 的真机 stream 音频路径确实存在应单独验证的风险。
- [LovePotion #109](https://github.com/lovebrew/lovepotion/issues/109) 记录了特定音频文件的杂音，并提到维护者判断为 buffer filling 问题。音乐断续不能只归咎于文件编码。
- [LovePotion #226](https://github.com/lovebrew/lovepotion/issues/226) 报告对尚未播放的 Source 调用 `stop()` 会锁住整个 3DS。
- [LovePotion #237](https://github.com/lovebrew/lovepotion/issues/237)、[#240](https://github.com/lovebrew/lovepotion/issues/240) 和 [#249](https://github.com/lovebrew/lovepotion/issues/249) 分别报告 `Source:stop()` 或 `Music:stop/pause()` 在 3DS 上冻结或崩溃。
- [LÖVEBrew FAQ](https://lovebrew.org/faq) 明确建议用实体硬件做准确测试；桌面 LÖVE 或模拟器不能替代 3DS 性能验收。
- [LÖVE Optimising](https://love2d.org/wiki/Optimising) 的通用建议是先 profile，再处理隐藏循环、不可见对象和 overdraw；这与本项目先看 `perf`、再隔离营地绘制的方案一致。

因此本项目新增以下规则：

1. 真机音频 API 调用和营地绘制必须作为两个独立变量测试。不要在同一轮同时更换音频格式和地图渲染。
2. 真机 `playSfx` 不得无条件执行 `Source:stop()` 后再 `play()`；尤其不能对确认尚未播放的 Source 调用 `stop()`。当前实现已改为 Source 正在播放时跳过，未播放时直接 `play()`。
3. `playBgm` 的切歌、`stopBgm` 和环境音停止都属于高风险路径；当前真机实现已改为单 BGM stream、跳过切歌/停止、关闭环境音。之后如需恢复多音乐或环境音，必须单变量测试。
4. 电脑端 benchmark 只能验证流程与相对负载；即使桌面端 100 FPS，也不能推翻实体 3DS 的低帧日志。
5. 性能报告必须同时记录 `camp_load` 时长和 `perf scene=play`，区分首次资源加载卡顿与进入营地后的持续低帧。
6. 如果 `static_play_fx/console_single_stream_no_stop` 下仍约 4 FPS，主因不再优先怀疑风效或音频切换，而应先压缩营地每帧绘制：避免每帧创建排序表、避免逐行反复扫描全部 decal、减少不显示资源的首次加载。当前真机静态模式已改用 `assets/camp_static_base.png/.t3x` 离线预合成地面/水岸/小装饰，只保留树、灌木、帐篷、营火、玩家等少量前景逐帧绘制。
7. “按 A 后等很久才进营地”要和“进入营地后持续低帧”分开判断。前者通常是 `ensureCamp()` 首次 T3X/SD 读取和纹理创建集中在按键回调里；当前代码用 `camp_preload` 在 `depart` 分镜期间分帧预热 essential，日志应出现 `camp_preload_begin`、`camp_preload_essential`，再进 `scene=play`；`ensureCamp done` 可晚于进营（later 补鱼鸟虫）。

### 3.7 自制 CIA 导致 HOME Menu 黑屏

**证据：官方不支持安装版；坏 banner/SMDH 造成菜单异常有公开机制。**

LovePotion FAQ 和维护者明确表示 CIA/NSP 不属于支持范围。即使 CIA 可被
GodMode9 校验并被 FBI 安装，也只说明容器/哈希结构可接受，不保证真实
HOME Menu 能安全解析 banner、icon 或 SMDH。

固定做法：

- `deploy-to-sd.sh` 默认且永久不构建、不复制 CIA。
- 不把 CIA 放入 `sdmc:/3ds/CampingTrip/`。
- 不再以“FBI 安装成功”作为游戏可发布的证明。
- 开发使用 game folder；需要单文件分发时测试官方 fused 3DSX。
- 自制 Title ID 必须检查冲突，但不再为本项目分配 CIA Title ID。

来源：

- [LÖVEBrew FAQ](https://lovebrew.github.io/faq)
- [LovePotion issue #92](https://github.com/lovebrew/lovepotion/issues/92)
- [官方 Game Folder / Fused Binary](https://lovebrew.github.io/getting-started/get-lovepotion)
- [3dbrew SMDH](https://3dbrew.org/wiki/SMDH)
- [3dbrew HOME Menu](https://www.3dbrew.org/wiki/Home_Menu)

### 3.8 卸载 CIA 后仍黑屏，重建 HOME Menu extdata

**证据：公开恢复指南明确。**

HOME Menu 使用 `Cache.dat` / `CacheD.dat` 保存 Title ID、版本和 SMDH 图标
信息。日版 HOME Menu extdata 为：

```text
Nintendo 3DS/<ID0>/<ID1>/extdata/00000000/00000082
```

安全恢复顺序：

1. 按住 `SELECT` 开机确认 Luma 能运行。
2. 按住 `START` 开机进入 GodMode9。
3. 完整备份 SD，记录可疑 CIA 的完整 16 位 Title ID。
4. GodMode9 → HOME → Title manager → `[A:] SD CARD`。
5. 只卸载确定的用户 CIA；禁止猜 ID，禁止删除不确定的 NAND 标题。
6. 正常重启测试；恢复后立即停止，不多做清理。
7. 仍黑屏且确认与 SD 用户数据有关时，先备份，再移动日版 `00000082`
   让系统重建。

“卸载后仍黑屏必然是旧 banner 缓存”证据不足。准确说法是：
HOME Menu extdata、图标缓存或菜单数据损坏均可能继续阻止菜单启动，
重建 extdata 是标准分层恢复步骤。

来源：

- [3DS Hacks Guide：安装后排错](https://3ds.hacks.guide/troubleshooting-post-install.html)
- [3dbrew Extdata](https://www.3dbrew.org/wiki/Extdata)
- [GodMode9](https://github.com/d0k3/GodMode9)

### 3.9 所有游戏重新变成礼物

**证据：已知的 extdata 重建结果。**

重建 HOME Menu extdata 后，图标排列、文件夹和“是否已拆封”状态可能重置。
这通常不代表游戏或存档被删除。

可选恢复：

- [Cthulhu](https://github.com/Ryuzaki-MrL/Cthulhu)：
  `Unwrap all HOME Menu software`。
- [TYSS](https://github.com/R-YaTian/TYSS)：
  中文功能“打开所有软件礼包”。

这些工具只修改菜单状态，不会恢复丢失的 title、ticket 或存档。必须在
HOME Menu 已稳定启动、SD 已备份后使用。

### 3.10 开机黑屏如何分层，不要先怪游戏

**证据：Luma/boot9strap 官方行为。**

- `SELECT` 能进 Luma：boot9strap 已成功加载至少一份 Luma。
- `START` 能进 GodMode9/chainloader：Luma 与 payload 路径基本正常。
- 两者能进而普通启动黑屏：问题发生在 Luma 之后，优先调查 HOME Menu
  数据、SD 用户目录、系统模块或硬件初始化。
- 无 SD 不能启动不等于变砖：boot9strap 会先找 SD 根目录 `boot.firm`，
  再找 CTRNAND；内部没有有效副本时，本来就无法无 SD 启动。

不要在这一阶段直接重装 boot9strap、卸载 CFW、CTRTransfer 或恢复 NAND。

来源：

- [Luma3DS](https://github.com/LumaTeam/Luma3DS)
- [Luma 配置说明](https://wiki.hacks.guide/wiki/3DS:Luma3DS/Configuration)
- [boot9strap](https://github.com/SciresM/boot9strap)
- [GodMode9 Usage](https://3ds.hacks.guide/godmode9-usage)

## 4. 今天曾过度归因的项目

后续 Agent 不得把以下内容写成已证实根因：

### 4.1 `._*` AppleDouble

macOS 往 FAT SD 写入的 `._*` 和 `.DS_Store` 应继续清除，属于必要卫生措施。
但现代 hbmenu 已有忽略点文件的改动，没有证据证明 AppleDouble 是本次
HOME Menu 黑屏或 LovePotion data abort 的单一根因。

保留措施：

```bash
export COPYFILE_DISABLE=1
rsync --exclude '._*' --exclude '.DS_Store' ...
```

来源：[3ds-hbmenu PR #56](https://github.com/devkitPro/3ds-hbmenu/pull/56)

### 4.2 FAT dirty bit / FSInfo

不安全弹出确实可能造成 FAT 写入未完成；修复卷和安全弹出是正确维护步骤。
但 FSInfo 只是空闲簇数量和搜索位置缓存，没有高质量证据证明它单独造成
持续 HOME Menu 黑屏。

准确表达：

- 文件系统检查发现错误 → 先备份并修复。
- 修复后恢复 → 说明文件系统状态可能相关，但不证明唯一因果。
- 持续黑屏 → 继续按 SELECT / START / HOME Menu extdata 分层排查。

SD 健康检测应覆盖全容量；macOS 可按 3DS Hacks Guide 使用
[F3XSwift](https://3ds.hacks.guide/f3xswift-%28mac%29)。

### 4.3 `Source:clone`

LovePotion 源码中 `clone` 已注册并实现。本项目真机曾在相关路径发生
data abort，因此当前保守禁用 clone 是合理的；但不能宣称它是官方已知
的普遍坏指针 bug。

## 5. 固定构建和部署闸门

### 5.1 固定工具链

- 锁定已验证的 LovePotion 3.0.2 二进制及哈希。
- 锁定 `tex3ds` 版本；本项目当前为 2.3.0。
- 不混用旧 2.x bundler、不同 commit 的 ELF/3DSX 和过期教程参数。
- 不再使用旧教程中的 `--border` 纹理参数。

### 5.2 桌面测试

```bash
cd /Users/ruska/projects/3ds/linjian
love game --playtest
```

必须出现 `PASS`。桌面测试只证明游戏逻辑和 PNG 资源正常，不证明 T3X、
3DS 文件系统、音频后端或真机内存正常。

### 5.3 纹理构建

```bash
python3 scripts/build-3ds-textures.py
```

必须检查：

- 所有运行时 PNG 有同名 T3X。
- T3X 修改时间不早于 PNG。
- 宽高不超过 1024。
- 场景同时常驻纹理量处于保守预算。
- 关键纹理至少包括标题、首个分镜、营地和图鉴图标。

### 5.4 音频与性能构建

真机音频资源必须单独检查：

```bash
find game/audio/3ds -type f -name '*.mp3' -print
ffprobe game/audio/3ds/bgm_01_title.mp3
```

三首真机 BGM 应为 `22050 Hz`、单声道、约 `64 kbps`。桌面音频和真机音频可以并存，
但 `game/main.lua` 必须在 Horizon 上明确走 `audio/3ds/`，不能只生成文件而不切换加载路径。

部署后还要确认 SD 上存在：

```text
sdmc:/3ds/CampingTrip/game/audio/3ds/bgm_01_title.mp3
sdmc:/3ds/CampingTrip/game/audio/3ds/bgm_02_morning.mp3
sdmc:/3ds/CampingTrip/game/audio/3ds/bgm_03_night.mp3
```

### 5.5 SD 部署

```bash
./scripts/deploy-to-sd.sh
python3 scripts/verify-3ds-install.py --require-sd
```

只有 `RESULT PASS` 才能让用户拔卡。预检必须确认：

- `CampingTrip.3dsx` 存在。
- `game/main.lua`、`conf.lua` 存在。
- 关键 PNG/T3X 同时存在。
- 不存在旧 `CampingTrip.cia`。
- 不存在 `._*`、`.DS_Store`。
- `dspfirm.cdc` 存在。
- 启动日志路径可写。

部署后必须由 macOS 正常推出：

```bash
diskutil eject "/Volumes/NO NAME"
```

### 5.6 真机单变量测试

每个构建只改变一类变量：代码、纹理、音频、引擎或目录布局。

固定顺序：

1. 冷启动到 Homebrew Launcher。
2. 启动 CampingTrip，确认 `load_report.txt` 第一行是 `boot`。
3. 标题背景。
4. 首个分镜。
5. 选角。
6. 营地进入与场景切换。
7. 装备图鉴连续翻页。
8. 高频菜单音效。
9. 营地自由走动，观察 `load_report.txt` 中的 `perf` 记录。
10. 完整周末流程。
11. 返回标题并正常退出。

每个部署写入可见构建编号；Lua 错误、LovePotion 日志和 Luma dump 分开保存。

## 6. 真机日志

```text
LovePotion Lua 错误：
sdmc:/3ds/CampingTrip/save/camping-trip/errors/love_error_*.txt

项目启动探测：
sdmc:/3ds/CampingTrip/save/camping-trip/load_report.txt

Luma ARM11 转储：
sdmc:/luma/dumps/arm11/crash_dump_*.dmp
```

判断原则：

- 没有 `load_report.txt` 或第一行没有 `boot`：没有进入 `love.load`，
  优先排查 HB、3DSX、启动链或 HOME Menu，不要先改游戏 Lua。
- 有 `boot` 且有 T3X 打开错误：排查转换、同步和挂载路径。
- 只有画面缺图、没有错误：检查实际加载分支、资源缓存和 draw 路径。
- data abort：保存完整 dump，记录最后成功场景和唯一变量，不凭红屏截图猜根因。

## 7. 当前文档中的已知矛盾

项目旧文档对机型和内存存在冲突：

- `项目背景.md` 写“Old 3DS”。
- DEV-037 / 旧 CIA RSF 曾按 New 3DS 124MB、804MHz、L2/Core2 配置。

CIA 已停用，所以旧 RSF 不再是发布依据。后续 Agent在用户明确确认机型前，
不得继续从机身颜色或旧记录推断型号；游戏内存设计应采用保守预算。

另有旧记录 DEV-042“CIA 可装”。它只表示当时 FBI 接受安装，不表示 CIA
安全可运行；后续 DEV-046 的 HOME Menu 黑屏已证明该发布路线必须停用。

## 8. 高风险操作边界

可以自行执行：

- 读取日志和 crash dump。
- 校验 3DSX、T3X、哈希及 SD 文件。
- `SELECT` / `START` 启动诊断。
- 完整备份后隔离用户 extdata。

必须谨慎并向用户说明影响：

- 格式化 SD。
- Cthulhu/TYSS 修改 HOME Menu extdata。
- GodMode9 卸载用户 Title。
- 把 `boot.firm` 写入 CTRNAND。

没有逐机诊断和可靠备份时禁止：

- 猜测并删除 Title ID。
- 删除整个 `title` 目录、`title.db`、`import.db` 或 tickets。
- 卸载不确定的 NAND/TWL 系统标题。
- SysNAND lvl2/lvl3 写入、NAND restore、CTRTransfer、区域变更。
- 重装/卸载 boot9strap 或 CFW。
- 任何写入过程中拔卡或断电。

## 9. 后续 Agent 接手检查表

开始工作前：

1. 读本文。
2. 读 `项目背景.md`。
3. 读 `docs/游戏设计-SPEC.md` §12 最新 DEV 编号。
4. 检查 LovePotion/tex3ds 固定版本。
5. 确认任务走 3DSX，不启用 CIA。

结束工作前：

1. 桌面 playtest PASS。
2. PNG 改动已重建 T3X。
3. 真机预检 PASS。
4. 单变量测试范围已记录。
5. SD 已安全弹出。
6. 新发现明确标注“官方事实 / 社区经验 / 本机实测”，并附来源。

这套流程的目标不是保证 3DS 不出问题，而是让每次失败都能快速定位到：
启动链、HOME Menu、3DSX/game folder、文件系统、T3X、音频或场景内存中的
某一层，避免同时修改多个变量后继续盲猜。
