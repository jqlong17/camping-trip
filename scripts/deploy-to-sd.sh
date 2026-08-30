#!/usr/bin/env bash
# 同步到 SD：3dsx + game/（可热更）+ 自动打 CIA 供 FBI 安装。
#
# 用法:
#   ./scripts/deploy-to-sd.sh           # 同步 + 打 CIA + 拷到已挂载 SD
#   ./scripts/deploy-to-sd.sh --no-cia  # 只同步 3dsx/game（最快迭代）
#   ./scripts/deploy-to-sd.sh --cia-only
#   SD=/Volumes/MYSD ./scripts/deploy-to-sd.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist/3ds/linjian"
ELF_SRC="$ROOT/vendor/lovepotion-3ds/lovepotion.3dsx"
GAME_SRC="$ROOT/game"

DO_CIA=1
DO_SYNC=1
for a in "$@"; do
  case "$a" in
    --no-cia) DO_CIA=0 ;;
    --cia-only) DO_SYNC=0; DO_CIA=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
  esac
done

echo "== 露营之旅 deploy =="

# 1) 刷新 dist 镜像
mkdir -p "$DIST/game"
cp -f "$ELF_SRC" "$DIST/lovepotion.3dsx"
rsync -a --delete --exclude '.DS_Store' "$GAME_SRC/" "$DIST/game/"
echo "✓ dist: $DIST"

# 2) 打 CIA
CIA_PATH="$DIST/linjian.cia"
if [[ "$DO_CIA" -eq 1 ]]; then
  if bash "$ROOT/scripts/build-cia.sh"; then
    echo "✓ CIA 已生成"
  else
    echo "⚠ CIA 构建失败（可先 ./scripts/ensure-cia-tools.sh）。仍会同步 3dsx+game。"
    DO_CIA=0
  fi
fi

# 3) 找 SD
find_sd() {
  if [[ -n "${SD:-}" && -d "$SD" ]]; then echo "$SD"; return; fi
  local c
  for c in "/Volumes/NO NAME" "/Volumes/Untitled" "/Volumes/3DS" "/Volumes/NINTENDO3DS"; do
    if [[ -d "$c" ]]; then echo "$c"; return; fi
  done
  # 任意含 Nintendo 3DS 文件夹的卷
  for c in /Volumes/*; do
    [[ -d "$c" ]] || continue
    if [[ -d "$c/Nintendo 3DS" || -d "$c/3ds" ]]; then echo "$c"; return; fi
  done
  return 1
}

if ! SD_ROOT="$(find_sd)"; then
  echo "未检测到 SD 卡。已准备好本地产物："
  echo "  - $DIST/lovepotion.3dsx + game/"
  [[ -f "$CIA_PATH" ]] && echo "  - $CIA_PATH"
  echo "插入 SD 后重跑，或: SD=\"/Volumes/你的卡\" $0"
  exit 0
fi

echo "SD → $SD_ROOT"

if [[ "$DO_SYNC" -eq 1 ]]; then
  mkdir -p "$SD_ROOT/3ds/linjian"
  rsync -a --delete "$DIST/game/" "$SD_ROOT/3ds/linjian/game/"
  cp -f "$DIST/lovepotion.3dsx" "$SD_ROOT/3ds/linjian/lovepotion.3dsx"
  echo "✓ 已同步 3ds/linjian/（Homebrew 菜单仍可用）"
fi

if [[ -f "$CIA_PATH" ]]; then
  mkdir -p "$SD_ROOT/cias"
  cp -f "$CIA_PATH" "$SD_ROOT/cias/linjian.cia"
  # 也放一份在游戏目录方便找
  cp -f "$CIA_PATH" "$SD_ROOT/3ds/linjian/linjian.cia"
  echo "✓ FBI 安装包: $SD_ROOT/cias/linjian.cia"
  echo
  echo "真机步骤："
  echo "  1. 安全退出 / 关机后拔卡（或确认拷贝完成）"
  echo "  2. 开机 → FBI → SD → cias → linjian.cia → Install CIA"
  echo "  3. 主画面点「露营之旅」"
  echo "日常改代码若只想快测：可用 Homebrew 打开 3ds/linjian（改 game/ 即生效，不必每次重装 CIA）。"
fi

echo "完成。"
