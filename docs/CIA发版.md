# CIA / 发版说明

LovePotion **官方不提供** CIA。本仓库用社区常见做法（ELF + RomFS + makerom）自打爱好向安装包。

## 命令

```bash
./scripts/deploy-to-sd.sh          # 同步 SD + 打 CIA（默认）
./scripts/deploy-to-sd.sh --no-cia # 只热更 game/（日常开发）
./scripts/build-cia.sh             # 只生成 dist/3ds/CampingTrip/CampingTrip.cia
./scripts/ensure-cia-tools.sh      # 首次拉取/编译 makerom、bannertool
```

## FBI

1. 卡里应有 `cias/CampingTrip.cia`，以及习惯目录 `CIA(tool)/CampingTrip.cia`
2. FBI → SD → **CIA(tool)** 或 **cias** → `CampingTrip.cia` → Install CIA
3. 若失败：FBI → Titles 删掉旧的 Camping Trip，再装一次
4. 主画面短名 **Camping Trip**（banner 上是「露营之旅」）
5. 删旧标题后桌面图标可能暂时还在：这是 Homemenu 缓存。**完全关机再开机**，再装新 CIA，再关一次机。

## 安装前预检（必跑）

```bash
./scripts/deploy-to-sd.sh                 # 结束时自动跑
python3 scripts/verify-3ds-install.py --require-sd
```

必须出现 `RESULT PASS`。这能挡住：标题图没打进卡、CIA 误放进 Homebrew 目录、RomFS 没有 `game/main.lua`。
**不能**代替真机点主画面图标（LovePotion 官方不保证 CIA）。

## 注意

- CIA 把当时的 `game/` **打进 RomFS**（根目录 + `romfs/game/` 各一份），之后只改电脑上的 `game/` **不会**自动进已安装标题；要嘛重打重装，要嘛用 HB 旁路 `3ds/CampingTrip`。
- UniqueId：`0x4C4A`（可在 `scripts/build-cia.sh` 改；换 UniqueId 主画面会多一个图标）。
- New 3DS：`info.rsf` 使用 `SystemModeExt: 124MB` + 804MHz。
- **不要**把 CIA 拷进 `sd:/3ds/CampingTrip/`：Homebrew 菜单扫目录会 OOM。安装包只放 `sd:/cias/CampingTrip.cia`。
- 素材：`cia/banner.png`（256×128）、`icon.png`（48×48）、`audio.wav`、`info.rsf`。
- 重做图标：换文生图源后跑 `python3 scripts/build-cia-icon.py`，再 `./scripts/build-cia.sh`。高清稿在 `docs/promo/logo_256.png`。
