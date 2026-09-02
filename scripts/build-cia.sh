#!/usr/bin/env bash
# Build an Old 3DS-compatible experimental CIA from LovePotion ELF + game RomFS.
# LovePotion 官方不提供 CIA；此为爱好向自用打包（参考社区 DDLC-LOVE 做法）。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/ensure-cia-tools.sh" >/dev/null

TOOLS="$ROOT/vendor/tools"
ELF="$ROOT/vendor/lovepotion-3ds/lovepotion.elf"
GAME="$ROOT/game"
CIA_DIR="$ROOT/cia"
OUT_DIR="$ROOT/dist/3ds/CampingTrip"
BUILD="$ROOT/build/cia"
OUT_CIA="$OUT_DIR/CampingTrip.cia"

APP_TITLE="Camping Trip"   # SMDH 英文短名（主画面）；中文名在 banner 图上
APP_DESC="Weekend camp in the woods"
APP_AUTHOR="Camping Trip"
PRODUCT_CODE="CTR-H-CAMP"
UNIQUE_ID="0xF4C4A"        # Homebrew 高位范围；避开旧实验 0x4C4A
CIA_WITH_BANNER="${CIA_WITH_BANNER:-0}" # 第一轮默认无 banner/audio，减少 HOME Menu 变量

[[ -f "$ELF" ]] || { echo "缺少 $ELF"; exit 1; }
[[ -f "$GAME/main.lua" ]] || { echo "缺少 game/main.lua"; exit 1; }
[[ -x "$TOOLS/makerom" && -x "$TOOLS/bannertool" ]] || {
  echo "正在准备工具…"
  bash "$ROOT/scripts/ensure-cia-tools.sh"
}

mkdir -p "$BUILD" "$OUT_DIR"

ROMFS="$BUILD/romfs"
rm -rf "$ROMFS"
mkdir -p "$ROMFS/game"
# LovePotion 3.x 找旁边的 game/；CIA 的 RomFS 根对应 3dsx 所在目录
rsync -a --delete --exclude '.DS_Store' "$GAME/" "$ROMFS/game/"
# 旧 fused 约定也会看 RomFS 根上的 main.lua，两套同内容避免点图标直接退回
rsync -a --exclude '.DS_Store' "$GAME/" "$ROMFS/"

echo "→ icon（Old 3DS minimal）"
"$TOOLS/bannertool" makesmdh \
  -s "$APP_TITLE" \
  -l "$APP_DESC" \
  -p "$APP_AUTHOR" \
  -i "$CIA_DIR/icon.png" \
  -f "nosavebackups,visible" \
  -o "$BUILD/icon.icn"

if [[ "$CIA_WITH_BANNER" == "1" ]]; then
  echo "→ optional banner / audio"
  "$TOOLS/bannertool" makebanner \
    -i "$CIA_DIR/banner.png" \
    -a "$CIA_DIR/audio.wav" \
    -o "$BUILD/banner.bnr"
fi

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
if [[ "$CIA_WITH_BANNER" == "1" ]]; then
  "$TOOLS/makerom" -f cia \
    -o "$OUT_CIA" -target t -exefslogo \
    -elf "$ELF" -rsf "$RSF_EXPANDED" \
    -banner "$BUILD/banner.bnr" -icon "$BUILD/icon.icn"
else
  "$TOOLS/makerom" -f cia \
    -o "$OUT_CIA" -target t -exefslogo \
    -elf "$ELF" -rsf "$RSF_EXPANDED" \
    -icon "$BUILD/icon.icn"
fi

ls -lh "$OUT_CIA"
echo "✓ CIA: $OUT_CIA"
echo "  Old 3DS minimal：Legacy / 268MHz / L2 off / Core2 off / banner off"
echo "  Title ID: 000400000F4C4A00（旧实验 00040000004C4A00 必须先卸载）"
echo "  FBI：SD/cias/CampingTrip.cia → Install CIA → 主画面「Camping Trip」（本轮无 banner）。"
echo "  热更新：deploy --no-cia 后用 HB 打开 3ds/CampingTrip。"
