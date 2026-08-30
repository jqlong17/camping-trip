#!/usr/bin/env bash
# 同步到 SD：默认只部署安全的 3dsx + game/。
#
# 用法:
#   ./scripts/deploy-to-sd.sh           # 只同步 3dsx/game（推荐）
#   ./scripts/deploy-to-sd.sh --with-cia # 明确要求时才打 CIA（高风险）
#   ./scripts/deploy-to-sd.sh --cia-only
#   SD=/Volumes/MYSD ./scripts/deploy-to-sd.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HB_NAME="CampingTrip"
DIST="$ROOT/dist/3ds/$HB_NAME"
ELF_SRC="$ROOT/vendor/lovepotion-3ds/lovepotion.3dsx"
GAME_SRC="$ROOT/game"

DO_CIA=0
DO_SYNC=1
for a in "$@"; do
  case "$a" in
    --no-cia) DO_CIA=0 ;;
    --with-cia) DO_CIA=1 ;;
    --cia-only) DO_SYNC=0; DO_CIA=1 ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
  esac
done

echo "== 露营之旅 deploy =="

# macOS 往 FAT 卡 rsync 默认会写出 ._ AppleDouble，hbmenu/LovePotion 扫目录会出事
export COPYFILE_DISABLE=1

# 1) LovePotion 3DS 会把 newImage("*.png") 映射到同名 *.t3x
python3 "$ROOT/scripts/build-camp-static-base.py"
python3 "$ROOT/scripts/build-3ds-textures.py"

# 2) 刷新 dist 镜像
mkdir -p "$DIST/game"
cp -f "$ELF_SRC" "$DIST/$HB_NAME.3dsx"
rsync -a --delete --exclude '.DS_Store' --exclude '._*' "$GAME_SRC/" "$DIST/game/"
echo "✓ dist: $DIST"

# 3) 打 CIA（默认关闭）
CIA_PATH="$DIST/CampingTrip.cia"
if [[ "$DO_CIA" -eq 1 ]]; then
  if bash "$ROOT/scripts/build-cia.sh"; then
    echo "✓ CIA 已生成"
  else
    echo "⚠ CIA 构建失败（可先 ./scripts/ensure-cia-tools.sh）。仍会同步 3dsx+game。"
    DO_CIA=0
  fi
fi

# 4) 找 SD
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
  echo "  - $DIST/$HB_NAME.3dsx + game/"
  [[ -f "$CIA_PATH" ]] && echo "  - $CIA_PATH"
  echo "插入 SD 后重跑，或: SD=\"/Volumes/你的卡\" $0"
  python3 "$ROOT/scripts/verify-3ds-install.py"
  exit 0
fi

echo "SD → $SD_ROOT"

if [[ "$DO_SYNC" -eq 1 ]]; then
  mkdir -p "$SD_ROOT/3ds/$HB_NAME"
  rsync -a --delete --exclude '.DS_Store' --exclude '._*' "$DIST/game/" "$SD_ROOT/3ds/$HB_NAME/game/"
  cp -f "$DIST/$HB_NAME.3dsx" "$SD_ROOT/3ds/$HB_NAME/$HB_NAME.3dsx"
  find "$SD_ROOT/3ds/$HB_NAME" \( -name '._*' -o -name '.DS_Store' \) -delete
  rm -f "$SD_ROOT/cias/._CampingTrip.cia" "$SD_ROOT/CIA(tool)/._CampingTrip.cia" 2>/dev/null || true
  # 旧拼音目录会在 HB 列表里多占一项，同步成功后删掉
  if [[ -d "$SD_ROOT/3ds/linjian" ]]; then
    rm -rf "$SD_ROOT/3ds/linjian"
    echo "✓ 已移除旧目录 3ds/linjian"
  fi
  echo "✓ 已同步 3ds/$HB_NAME/（Homebrew 列表显示 CampingTrip）"
fi

if [[ "$DO_CIA" -eq 1 && -f "$CIA_PATH" ]]; then
  mkdir -p "$SD_ROOT/cias"
  cp -f "$CIA_PATH" "$SD_ROOT/cias/CampingTrip.cia"
  rm -f "$SD_ROOT/cias/linjian.cia" "$SD_ROOT/3ds/$HB_NAME/"*.cia "$SD_ROOT/3ds/$HB_NAME/._"*.cia
  echo "✓ FBI 安装包: $SD_ROOT/cias/CampingTrip.cia"
  # 这台机习惯在 CIA(tool) 里装包
  if [[ -d "$SD_ROOT/CIA(tool)" ]]; then
    cp -f "$CIA_PATH" "$SD_ROOT/CIA(tool)/CampingTrip.cia"
    echo "✓ 也放了一份: CIA(tool)/CampingTrip.cia"
  fi
  echo
  echo "真机步骤："
  echo "  1. 安全退出 / 关机后拔卡"
  echo "  2. Homebrew 里选 CampingTrip 热更（含 setPitch 修复）"
  echo "  3. FBI → SD → CIA(tool) 或 cias → CampingTrip.cia → Install CIA"
  echo "     若提示已存在：Titles 里删掉旧的 Camping Trip / linjian 再装"
fi

echo "完成。"

VERIFY=("$ROOT/scripts/verify-3ds-install.py")
if [[ -d "$SD_ROOT" ]]; then
  VERIFY+=(--require-sd)
fi
echo
if ! python3 "${VERIFY[@]}"; then
  echo "安装预检失败：不要拔卡，先修上面的 FAIL。"
  exit 1
fi
