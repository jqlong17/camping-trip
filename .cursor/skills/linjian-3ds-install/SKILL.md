---
name: linjian-3ds-install
description: >-
  Verifies Nintendo 3DS install/deploy for 露营之旅 (linjian) before telling the
  user to insert the SD card. Use when deploying to SD, building CIA, FBI
  install, 真机安装, 主画面图标, Homebrew 二次崩溃, or the user asks how to
  ensure the next install works.
---

# 露营之旅 · 真机安装闸门

仓库：`/Users/ruska/projects/3ds/linjian`

电脑**不能**代替真机点主画面图标。LovePotion **官方不保证 CIA**。
能做的是：把上次已证实会翻车的问题做成硬失败，过不了就不许说「可以装了」。

## 每次 deploy / 打 CIA 之后必须跑

```bash
cd /Users/ruska/projects/3ds/linjian
python3 scripts/verify-3ds-install.py --require-sd
```

日志必须出现 `RESULT PASS`。`FAIL` 则继续修，**禁止**让用户拔卡。

卡没插时去掉 `--require-sd`（SD 项变 WARN）。`deploy-to-sd.sh` 结束时会自动跑预检。

## 闸门挡住什么

| 上次现象 | 预检查什么 |
|---|---|
| 标题背景纯色 | `title_*` 最先加载；PNG 为 2 的幂；卡上有 `title_top.png` |
| 再进 HB 就 data abort | `3ds/CampingTrip/` **没有** `.cia` 或 >8MB 文件 |
| 主画面点图标进不去 | RomFS 同时有 `/main.lua` 与 `/game/main.lua`；RSF 124MB |
| FBI 装的是旧包 | `cias/CampingTrip.cia` 体积接近本地 dist |
| 菜单一动红屏 `setPitch` | 真机 `playSfx` 只 `stop`+`play`，不要 clone/setPitch |
| FBI 装不上 CIA | RSF 无 NAND 权限；`EnableCompress: false`；卡上 `cias/` 与 `CIA(tool)/` 都有 `CampingTrip.cia` |
| 删了 Titles 桌面仍旧图标 | Homemenu 缓存：关机重启，不要只按 Home |
| 分镜/营地只有色块 | 看 `load_report.txt`；若报找不到 `.t3x`，必须用 tex3ds 转换所有运行时 PNG，并让预检检查关键 T3X |
| SD 上每个 PNG 旁有 `._*` | deploy 必须 `COPYFILE_DISABLE` + 排除/删除 AppleDouble；预检 FAIL |
| 插卡整机黑屏 | FAT 脏标记 / 没安全弹出。修卷后 `diskutil eject`。按住 SELECT 开机应出 Luma。`load_report.txt` 没有 `boot` = 游戏没启动 |
| SELECT 可进 Luma、Start 后黑屏 | HOME 菜单启动失败。先查 `Nintendo 3DS/**/title/00040000/004c4a00/`；存在则用 GodMode9 2.2.3：START 开机 → HOME → Title manager → `[A:] SYSNAND SD` → `00040000004C4A00` → Manage title → Uninstall title |
| 卸载坏 CIA 后仍黑屏 | 备份并移走当前 ID0/ID1 下日本区 HOME Menu extdata `00000082`，让系统重建。可能重置图标排列/文件夹，不删游戏存档；无效可恢复备份 |

## 对用户怎么说

- **Homebrew `3ds/CampingTrip`**：预检 PASS 后，标题图和二次进入是这次要保证的路径。
- **主画面 CIA 已停用**：本机确认自打 LovePotion CIA 可导致 HOME 菜单黑屏。默认和热更只部署 Homebrew `3ds/CampingTrip`。

## 禁止

- 把 CIA 拷进 `sd:/3ds/CampingTrip/`
- 默认生成、复制或建议安装 `CampingTrip.cia`
- 预检 FAIL 还说可以拔卡
- 用 2019 的 `_backup_boot_2019/boot.firm` 换现用 Luma
- 修了真机坑却不更新 `linjian-camping-3ds` / `3ds-homebrew-game`
