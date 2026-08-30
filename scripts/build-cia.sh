#!/usr/bin/env bash
# Build linjian.cia from LovePotion ELF + game RomFS (for FBI install).
# LovePotion 官方不提供 CIA；此为爱好向自用打包（参考社区 DDLC-LOVE 做法）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/ensure-cia-tools.sh" >/dev/null

TOOLS="$ROOT/vendor/tools"
ELF="$ROOT/vendor/lovepotion-3ds/lovepotion.elf"
GAME="$ROOT/game"
CIA_DIR="$ROOT/cia"
OUT_DIR="$ROOT/dist/3ds/linjian"
BUILD="$ROOT/build/cia"
OUT_CIA="$OUT_DIR/linjian.cia"

APP_TITLE="Camping Trip"   # SMDH/CIA 英文短名（主画面）；中文名在 banner 图上
APP_DESC="Linjian weekend camp"
APP_AUTHOR="linjian"
PRODUCT_CODE="CTR-H-LJIN"
UNIQUE_ID="0x4C4A"         # 须在 makerom 允许范围内（约 16-bit）

[[ -f "$ELF" ]] || { echo "缺少 $ELF"; exit 1; }
[[ -f "$GAME/main.lua" ]] || { echo "缺少 game/main.lua"; exit 1; }
[[ -x "$TOOLS/makerom" && -x "$TOOLS/bannertool" ]] || {
  echo "正在准备工具…"
  bash "$ROOT/scripts/ensure-cia-tools.sh"
}

mkdir -p "$BUILD" "$OUT_DIR"

ROMFS="$BUILD/romfs"
rm -rf "$ROMFS"
mkdir -p "$ROMFS"
rsync -a --delete --exclude '.DS_Store' "$GAME/" "$ROMFS/"

echo "→ banner / icon"
"$TOOLS/bannertool" makebanner \
  -i "$CIA_DIR/banner.png" \
  -a "$CIA_DIR/audio.wav" \
  -o "$BUILD/banner.bnr"

"$TOOLS/bannertool" makesmdh \
  -s "$APP_TITLE" \
  -l "$APP_DESC" \
  -p "$APP_AUTHOR" \
  -i "$CIA_DIR/icon.png" \
  -f "nosavebackups,visible" \
  -o "$BUILD/icon.icn"

# makerom -D 对路径/中文不稳定，改为展开 RSF
RSF_EXPANDED="$BUILD/info.expanded.rsf"
python3 - "$CIA_DIR/info.rsf" "$RSF_EXPANDED" "$APP_TITLE" "$PRODUCT_CODE" "$UNIQUE_ID" "$ROMFS" <<'PY'
import sys
src, dst, title, product, uid, romfs = sys.argv[1:7]
text = open(src, encoding="utf-8").read()
repl = {
  "$(APP_TITLE)": title,
  "$(APP_PRODUCT_CODE)": product,
  "$(APP_UNIQUE_ID)": uid,
  "$(APP_ROMFS)": romfs,
  "$(APP_VERSION_MAJOR)": "0",
}
for k, v in repl.items():
  text = text.replace(k, v)
open(dst, "w", encoding="utf-8").write(text)
print("RSF UniqueId →", uid)
print("RomFS →", romfs)
PY

echo "→ makerom CIA"
"$TOOLS/makerom" -f cia \
  -o "$OUT_CIA" \
  -target t \
  -exefslogo \
  -elf "$ELF" \
  -rsf "$RSF_EXPANDED" \
  -banner "$BUILD/banner.bnr" \
  -icon "$BUILD/icon.icn"

ls -lh "$OUT_CIA"
echo "✓ CIA: $OUT_CIA"
echo "  FBI：SD/cias/linjian.cia → Install CIA → 主画面「Camping Trip」/ banner 中文「露营之旅」。"
echo "  热更新仍可用：改 game/ 后跑 deploy --no-cia，用 HB 菜单进 3ds/linjian。"
