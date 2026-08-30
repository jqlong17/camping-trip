# CIA / 发版说明

LovePotion **官方不提供** CIA。本仓库用社区常见做法（ELF + RomFS + makerom）自打爱好向安装包。

## 命令

```bash
./scripts/deploy-to-sd.sh          # 同步 SD + 打 CIA（默认）
./scripts/deploy-to-sd.sh --no-cia # 只热更 game/（日常开发）
./scripts/build-cia.sh             # 只生成 dist/3ds/linjian/linjian.cia
./scripts/ensure-cia-tools.sh      # 首次拉取/编译 makerom、bannertool
```

## FBI

1. 卡里应有 `cias/linjian.cia`（deploy 会放）  
2. FBI → 该文件 → Install CIA  
3. 主画面图标短名 **Camping Trip**（banner 图上是中文「露营之旅」）

## 注意

- CIA 把当时的 `game/` **打进 RomFS**，之后只改电脑上的 `game/` **不会**自动进已安装标题；要嘛重打重装，要嘛用 HB 旁路 `3ds/linjian`。  
- UniqueId：`0x4C4A`（可在 `scripts/build-cia.sh` 改）。  
- 素材：`cia/banner.png`、`icon.png`、`audio.wav`、`info.rsf`。
