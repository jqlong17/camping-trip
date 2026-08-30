#!/usr/bin/env bash
# Ensure makerom + bannertool under vendor/tools (macOS arm64/x86_64).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/vendor/tools"
mkdir -p "$TOOLS"

arch="$(uname -m)"
case "$arch" in
  arm64) MAKEROM_ZIP="makerom-v0.19.0-macos_arm64.zip" ;;
  x86_64) MAKEROM_ZIP="makerom-v0.19.0-macos_x86_64.zip" ;;
  *) echo "不支持的架构: $arch"; exit 1 ;;
esac

MAKEROM_URL="https://github.com/3DSGuy/Project_CTR/releases/download/makerom-v0.19.0/${MAKEROM_ZIP}"

MIRRORS=(
  "https://ghfast.top/"
  "https://mirror.ghproxy.com/"
  ""
)

download() {
  local url="$1" out="$2"
  local full
  for m in "${MIRRORS[@]}"; do
    full="${m}${url}"
    echo "↓ $full"
    if curl -fL --connect-timeout 15 --max-time 120 --retry 1 -o "$out" "$full"; then
      return 0
    fi
  done
  return 1
}

if [[ ! -x "$TOOLS/makerom" ]]; then
  tmp="$(mktemp -d)"
  download "$MAKEROM_URL" "$tmp/makerom.zip"
  unzip -qo "$tmp/makerom.zip" -d "$tmp"
  bin="$(find "$tmp" -type f -name makerom | head -1)"
  [[ -n "$bin" ]] || { echo "makerom 解压失败"; exit 1; }
  cp "$bin" "$TOOLS/makerom"
  chmod +x "$TOOLS/makerom"
  rm -rf "$tmp"
  echo "✓ makerom → $TOOLS/makerom"
fi

if [[ ! -x "$TOOLS/bannertool" ]]; then
  echo "编译 bannertool（官方 zip 无 macOS 二进制）…"
  src="$(mktemp -d)"
  cloned=0
  for m in "${MIRRORS[@]}"; do
    if [[ -n "$m" ]]; then
      url="${m}https://github.com/carstene1ns/3ds-bannertool.git"
    else
      url="https://github.com/carstene1ns/3ds-bannertool.git"
    fi
    echo "git clone $url"
    if git clone --depth 1 "$url" "$src/bt" 2>/dev/null; then
      cloned=1
      break
    fi
  done
  [[ "$cloned" -eq 1 ]] || { echo "无法克隆 bannertool 源码"; exit 1; }

  python3 - "$src/bt/source/3ds/lz11.cpp" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1])
t = p.read_text()
t = t.replace("u8 pad[padLength] = {0};", "u8 pad[4] = {0};")
p.write_text(t)
PY

  (
    cd "$src/bt"
    clang++ -std=c++17 -O2 -Isource -Isource/pc -Isource/3ds \
      -DVERSION=\"1.2.3\" \
      -DSTBI_ONLY_PNG -DSTBI_NO_LINEAR -DSTBI_NO_STDIO \
      -DSTB_VORBIS_NO_PUSHDATA_API -DSTB_VORBIS_NO_STDIO \
      -DDR_WAV_NO_STDIO \
      source/main.cpp source/log.cpp source/types.cpp source/utils.cpp \
      source/3ds/cwav.cpp source/3ds/lz11.cpp source/3ds/cbmd.cpp \
      source/pc/stb_image.cpp source/pc/stb_vorbis.cpp source/pc/dr_wav.cpp \
      -o "$TOOLS/bannertool"
  )
  chmod +x "$TOOLS/bannertool"
  rm -rf "$src"
  echo "✓ bannertool → $TOOLS/bannertool"
fi

echo "工具就绪: $TOOLS"
"$TOOLS/makerom" 2>&1 | head -2 || true
"$TOOLS/bannertool" 2>&1 | head -3 || true
