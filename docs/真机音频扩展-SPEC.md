# 真机音频扩展 SPEC（3DS · 渐进恢复）

> 状态：**wip（代码+资产已落地，待真机手测）** · 2026-08-31  
> 关联：**DEV-069**（本 SPEC）· **DEV-068c**（架构重构中的 `audio.lua` 落地）  
> 读者：正在做模块化的 Agent；**先读本文再改 `game/audio.lua`**，勿与营地渲染同一轮混改。

---

## 1. 目标（用户拍板）

在 **Old 3DS + LovePotion 3.0.2** 上，在现有保守策略基础上 **增量恢复** 三类听感：

| 优先级 | 内容 | 行为 |
|--------|------|------|
| P0 | **溪水环境音** | 仅 `play` 场景、**靠近水**（tile 2/8）时播放；离开水 **停止** |
| P0 | **标题 BGM + 夜里 BGM** | 标题/图鉴/关于/回家/日记结束 → 标题曲；营地入夜～深夜 → 夜里曲 |
| P1 | **鸟鸣** | **靠近鸟** 才偶发短叫；**不要** 全图常开 `amb_birds` 循环流 |

**明确不做（本轮）**

- 虫鸣 `amb_crickets` 循环（夜里仍只靠 BGM + 可选 SFX）
- 桌面与真机行为完全统一（真机可更省）
- 与 DEV-055 营地 draw 优化同 PR 提交

---

## 2. 现状快照（代码已探索 · 2026-08-31）

### 2.1 模块与 Host

| 位置 | 职责 |
|------|------|
| `game/audio.lua` | 真机/桌面分支、BGM/环境/SFX 加载与同步 |
| `game/main.lua` | `Audio.bindHost({ getScene, playerNearWater, playerNearBird, isNight })`；`love.update` 里 `birdChirpT` + `Audio.syncAmbient()` |
| `game/time.lua` | 时段推进后调 `host.syncPlayBgm()` |

重构进行中：**逻辑应留在 `audio.lua`**；`main` / 未来的 `scene_flow.lua` / `camp_world.lua` 只通过 Host 回调，不直接 `love.audio.newSource`。

### 2.2 真机模式名

```text
console_single_stream_no_stop   ← 当前 bindHost 时设定
```

行为摘要：

- `loadBgm()` 真机早退：只加载 `bgm_02_morning` + 尝试 `amb_creek`（**`audio/3ds/` 下尚无 amb 文件**）
- **不加载** `bgm_01_title`、`bgm_03_night`
- `playBgm()`：若 `current ~= src` → **直接 skip_switch**，不切歌
- `stopBgm()` / `stopAmb()`：真机 **no-op**（但 `syncAmbient` 里溪水 **仍会** `creek:stop()`，与 `stopAmb` 不一致）
- `love.load`：真机 **不** 调 `loadBgm`/`loadSfx`，靠 `ensureConsoleLoaded()` 延迟加载
- `love.load`：真机 **不** `playBgm(title)`（标题无声）

### 2.3 桌面已有、真机应对齐的逻辑

**靠近水**（`main.lua` → 将来 `camp_map`）：

```lua
-- playerNearWater(radius): 玩家周围 Manhattan 距离内存在 tile 2（水）或 8（浅滩）
```

**靠近鸟**（`main.lua` → 将来 `camp_world`）：

```lua
-- playerNearBird(radius): critters.birds 里任一只与玩家格距 <= radius
```

**桌面 `syncAmbient()`（`audio.lua` 159–183 行）**

- 溪水：**远离水也轻垫 0.08**（用户 **不要** 真机这样；真机要 **离水即停**）
- 鸟：用 **`amb_birds` stream**，远离鸟仍 0.12 轻垫（用户 **不要**；改用 **`sfx_bird` 点叫**）

**桌面 `love.update` 鸟叫**（`main.lua` ~1650）：

```lua
if birdChirpT <= 0 and playerNearBird(2) and not Time.isNight() then
  birdChirpT = 2.8 + love.math.random() * 1.5
  Audio.playSfx("bird")
end
```

真机 `playSfx` 已走「正在播则跳过、否则 play」——**鸟鸣 P1 只需保证 `loadSfx` 执行 + 保留上述 tick**，**不要** 加载 `amb_birds` stream。

### 2.4 磁盘资产

| 路径 | 状态 |
|------|------|
| `game/audio/3ds/bgm_01_title.mp3` | ✅ 已有（22k mono ~64k） |
| `game/audio/3ds/bgm_02_morning.mp3` | ✅ |
| `game/audio/3ds/bgm_03_night.mp3` | ✅ |
| `game/audio/3ds/amb_creek.mp3` | ❌ **缺失**（需从桌面 `amb_creek.mp3` 复制或重编码） |
| `game/audio/sfx_bird.wav` | ✅ static，真机与桌面共用路径 |

---

## 3. 目标架构

### 3.1 新模式名

```text
console_prox_amb_bgm_switch
```

替换 `console_single_stream_no_stop`（或作为其子模式，日志里写全名）。

**并发上限（真机）**

| 类型 | 最多同时 | 说明 |
|------|----------|------|
| BGM stream | **1 路** | title / morning / night **互斥** |
| 环境 stream | **1 路** | 仅 `amb_creek`，且仅近水 |
| SFX static | 多路 | 短 WAV；不 `clone` / 不 `setPitch` / 不无条件 `stop()` |

峰值 **2 条 stream**（BGM + 溪水），低于旧桌面 4 路（BGM+鸟+虫+溪）。

### 3.2 BGM 路由表

| 场景 | BGM |
|------|-----|
| `title` | `bgm_01_title` |
| `codex` / `about` | `bgm_01_title` |
| `prologue` / `depart` / `cast` | `bgm_02_morning` |
| `play` 且非夜 | `bgm_02_morning` |
| `play` 且 `Time.isNight()` | `bgm_03_night` |
| `homecoming` / `diary`（至回标题） | `bgm_01_title` |

触发点（须全部接上，重构后归 `scene_flow` / `time`）：

- `goTitle` / `finishDiary` → title
- `goPrologue` → morning（已有）
- `goPlay` → `syncPlayBgm()`（已有）
- `Time.advance` / 自动走时入夜 → `syncPlayBgm()`（经 `time.lua` 已有）
- `goHomecoming` → title

### 3.3 环境音：溪水

**仅真机 + 仅 play：**

```text
playerNearWater(2) == true  → ensureAmb(creek)  volume ≈ 0.22
else                      → creek:stop()       （pcall 包裹）
```

- **禁止** 远离水 0.08 轻垫（与桌面不同， intentional）
- `syncAmbient()` 调用频率：保持 `love.update` 每 ~0.5s 一次（`titlePulse` 偶帧），**不要每帧**

### 3.4 鸟鸣：仅 proximity SFX

| 平台 | 策略 |
|------|------|
| 真机 | **仅** `sfx_bird.wav` 点叫；**不** `load amb_birds` |
| 桌面（可选同步） | 本轮可保留 `amb_birds` 或改为与真机一致；用户偏好 **靠近才有** → 建议桌面也逐步去掉远距 0.12 轻垫 |

触发条件（与现 `main` 一致）：

- `scene == "play"`
- `not Time.isNight()`
- `playerNearBird(2)`（半径可配置常量 `BIRD_CHIRP_RADIUS = 2`）
- 冷却 `2.8～4.3s` 随机

实现建议：新增 `Audio.tick(dt)`，把 `birdChirpT` 收进 `audio.lua`，`main` 只调 `Audio.tick(dt)`。

---

## 4. 真机 BGM 切换策略（LovePotion 坑）

参考 [3DS真机开发踩坑与发布准则.md §3.6](./3DS真机开发踩坑与发布准则.md)：

- `Source:stop()` 在未播放 / 切换时可能 freeze（#226/#240）
- 当前 `skip_switch` 是为规避此问题

**推荐实现：`safeSwitchBgm(nextSrc)`**

1. 若 `nextSrc == nil` 或 `nextSrc == bgm.current` 且已在播 → return  
2. 若 `bgm.current` 存在且 **正在播** → `pcall(function() bgm.current:stop() end)` **仅一次**  
3. `bgm.current = nextSrc`  
4. 若 `nextSrc` 未播 → `pcall(function() nextSrc:play() end)`  
5. `appendLoadLog("audio switch_bgm -> " .. (nextSrc._label or "?"))`  

**允许切换的时机（禁止在 play 每帧调）**

- 场景切换函数（`goTitle` / `goPrologue` / `goHomecoming` / `goPlay`）
- `Time.advance` 导致 **入夜/黎明** 一次（已有 `syncPlayBgm`）

**禁止**

- 在 `syncAmbient` 里切 BGM  
- 对 **从未 play 过** 的 Source 调 `stop()`

若真机实测切换仍 freeze → 回退为「营地只 morning、标题 silent」，并在 DEV 日志记 **证据级** 失败，不要 silent skip。

---

## 5. `audio.lua` 改动清单（给 DEV-068c / DEV-069）

### 5.1 `loadBgm()` 真机分支

```lua
-- 伪代码
if isConsole() then
  prefix = "audio/3ds/"
  bgm.title   = tryLoad("bgm_01_title.mp3")
  bgm.morning = tryLoad("bgm_02_morning.mp3")
  bgm.night   = tryLoad("bgm_03_night.mp3")
  amb.creek   = tryLoad("amb_creek.mp3", 0.22)
  -- 不加载 amb.birds / amb.crickets
  appendLog("audio mode=console_prox_amb_bgm_switch bgm=3 amb=creek_prox")
  return
end
```

### 5.2 新增/调整 API

| 函数 | 说明 |
|------|------|
| `Audio.syncSceneBgm()` | 按 **当前 scene** 选 BGM（非 play 专用）；供 title/codex/about/homecoming |
| `Audio.syncPlayBgm()` | 保持；play 内 day/night + 调 `syncAmbient` |
| `Audio.safeSwitchBgm(src)` | 真机切歌唯一入口 |
| `Audio.tick(dt)` | 鸟叫冷却 + 节流 `syncAmbient` |
| `Audio.stopAmb()` | 真机：仅 stop `amb.creek`（若 isPlaying）；**不要** 全局 no-op |

### 5.3 `bindHost` 真机

```lua
consoleAudioMode = "console_prox_amb_bgm_switch"
```

### 5.4 `main.lua` / 重构后调用点

| 时机 | 调用 |
|------|------|
| `love.load` 末尾 | 真机：`ensureConsoleLoaded()` 后 **`Audio.syncSceneBgm()`**（标题进游戏即 title BGM） |
| `goTitle` / `goHomecoming` / `finishDiary` | `Audio.stopAmb()` + `Audio.syncSceneBgm()` |
| `goPlay` | 保持 `Audio.syncPlayBgm()` |
| `love.update` play 分支 | `Audio.tick(dt)` 替代内联 `birdChirpT` + `syncAmbient` |

---

## 6. 资产与部署

### 6.1 生成 `game/audio/3ds/amb_creek.mp3`

与三首 BGM 同规格：**22050 Hz · mono · ~64 kbps · 24s 循环**（可直接转码桌面 `game/audio/amb_creek.mp3`）。

```bash
ffmpeg -y -i game/audio/amb_creek.mp3 \
  -ac 1 -ar 22050 -b:a 64k game/audio/3ds/amb_creek.mp3
```

### 6.2 部署检查（扩展现有 §5.4）

`verify-3ds-install.py` / 文档应增加：

```text
game/audio/3ds/amb_creek.mp3
```

### 6.3 CREDITS

在 `game/audio/CREDITS-sfx.txt` 注明 `amb_creek` 真机副本来源（已有 robertcrosley 行即可）。

---

## 7. 日志与验收

### 7.1 `load_report.txt` 期望行

```text
boot build=...
audio mode=console_prox_amb_bgm_switch bgm=3 amb=creek_prox
audio switch_bgm -> title
audio switch_bgm -> morning
audio switch_bgm -> night
audio switch_bgm -> title
```

### 7.2 真机手测清单

1. **标题**：进 HB 启动后 **≤3s** 内听到 title BGM（音量与 morning 相当）  
2. **营地白天**：近溪边听到溪水；走到草地 **2 格外** 溪水停  
3. **入夜**：时段到「入夜/深夜」切 night BGM **一次**，不 freeze  
4. **黎明**：回 morning BGM  
5. **鸟**：白天站到鸟旁 **偶发** 短叫；远离鸟 **30s** 无叫；夜里无叫  
6. **回家**：切回 title BGM，溪水停  
7. **perf**：`perf scene=play` 与 DEV-050 基线对比，**帧数不明显更差**；若 `maxDtMs` 飙升先怀疑渲染而非先加音频  

### 7.3 桌面回归

```bash
cd /Users/ruska/projects/3ds/linjian && love game --playtest
# 必须 PASS；桌面仍走 desktop_full_audio，三 BGM + 全 amb 不受影响
```

---

## 8. 与重构的边界（DEV-068）

| 模块 | 本 SPEC 要求 |
|------|----------------|
| `audio.lua` | **主改文件** |
| `state.lua` | 不必新增字段；鸟叫冷却可放 `audio.lua` local |
| `time.lua` | 保持 `syncPlayBgm` 回调，不内联音频 |
| `scene_flow.lua`（未建） | 场景切换时调 `Audio.syncSceneBgm()` / `stopAmb` |
| `camp_world.lua`（未建） | 提供 `playerNearBird` 或继续 Host 注入 |
| `main.lua` | 只保留 `bindHost` + `Audio.tick(dt)` 一行 |

**禁止**：在 `draw/*` 里播音频；在 `drip_brew` / `tea_brew` 改 BGM 路由。

---

## 9. 开发日志占位

| 编号 | 状态 | 摘要 |
|------|------|------|
| **DEV-069** | planned | 真机音频扩展：title/night BGM + 近水溪水 + 近鸟 sfx（本文 SPEC） |
| **DEV-069a** | done | 资产：`audio/3ds/amb_creek.mp3` + deploy 校验 |
| **DEV-069b** | done | `audio.lua`：`console_prox_amb_bgm_switch` + `safeSwitchBgm` + `tick` |
| **DEV-069c** | planned | 真机手测 + perf 对比 + 更新踩坑文档 §3.6 |

---

## 10. 风险与回退

| 风险 | 回退 |
|------|------|
| BGM 切换 freeze | 仅保留 morning；title/night 静音，模式回 `console_single_stream_no_stop` |
| 溪水 + BGM 双 stream 断续 | 关溪水，只留 BGM |
| 鸟鸣叠加 SFX 爆音 | 降 `sfx_bird` volume 或拉长冷却 |

**单变量原则**：先 **只开 title BGM** → 再 **night 切换** → 再 **溪水** → 最后确认 **鸟鸣**；不要一次全开难以定责。
