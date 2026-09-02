#!/usr/bin/env python3
"""Convert runtime PNGs to the T3X files required by LÖVE Potion on 3DS."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
VENDORED = ROOT / "vendor" / "tools" / "tex3ds"
FONT_SUBSET_BUILDER = ROOT / "scripts" / "build-font-subset.py"


def find_tex3ds() -> str:
    if VENDORED.is_file():
        return str(VENDORED)
    found = shutil.which("tex3ds")
    if found:
        return found
    raise SystemExit(
        "找不到 tex3ds。先安装 devkitPro tex3ds，或放到 vendor/tools/tex3ds。"
    )


def is_runtime(path: Path) -> bool:
    name = path.name
    return not (
        name.startswith("._")
        or "_v1" in name
        or "paint" in name
    )


def main() -> int:
    # Rebuild first so every deploy/build contains all current player-facing
    # copy. The font builder exits non-zero when either the source or output
    # cannot cover a required glyph, turning silent tofu into a build failure.
    subprocess.run([sys.executable, str(FONT_SUBSET_BUILDER)], check=True)
    tool = find_tex3ds()
    pngs = sorted(p for p in ASSETS.rglob("*.png") if is_runtime(p))
    built = skipped = 0

    for png in pngs:
        out = png.with_suffix(".t3x")
        if out.is_file() and out.stat().st_mtime_ns >= png.stat().st_mtime_ns:
            skipped += 1
            continue
        subprocess.run(
            [tool, str(png), "-f", "rgba8888", "-z", "auto", "-o", str(out)],
            check=True,
        )
        built += 1

    print(f"T3X: {built} built / {skipped} current / {len(pngs)} total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
