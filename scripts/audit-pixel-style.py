#!/usr/bin/env python3
"""Audit runtime PNGs for 露营之旅 pixel-style consistency.

Exit 0 = pass, 1 = fail. Prints WARN / FAIL lines.
Skips backups: *_v1*, _tiles_v1/, ritual/_drip_v1/.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
SKIP_DIR = {"_tiles_v1", "_drip_v1"}


def skip(path: Path) -> bool:
    if any(p in SKIP_DIR for p in path.parts):
        return True
    name = path.name
    return "_v1" in name or name.endswith("_paint.png")


def neighbor_diff(im: Image.Image) -> float:
    w, h = im.size
    px = im.load()
    total = 0
    n = 0
    step_x = max(1, w // 48)
    step_y = max(1, h // 48)
    for y in range(0, h, step_y):
        for x in range(0, w - 1, step_x):
            a, b = px[x, y], px[x + 1, y]
            total += abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])
            n += 1
    return total / n if n else 0


def unique_opaque(im: Image.Image) -> int:
    return len({c[:3] for c in im.getdata() if c[3] > 16})


def main() -> int:
    fails: list[str] = []
    warns: list[str] = []
    files = sorted(p for p in ASSETS.rglob("*.png") if not skip(p))
    print(f"audit {len(files)} runtime pngs")
    for path in files:
        im = Image.open(path).convert("RGBA")
        w, h = im.size
        u = unique_opaque(im)
        nd = neighbor_diff(im)
        rel = path.relative_to(ASSETS)
        full = w * h >= 320 * 200
        if full and u > 180:
            fails.append(f"FAIL {rel} unique={u} (>180 on fullscreen — looks painted)")
        elif full and u > 80:
            warns.append(f"WARN {rel} unique={u} (prefer ≤64 indexed colors)")
        if full and nd < 10 and u > 80:
            fails.append(f"FAIL {rel} too-smooth nDiff={nd:.1f} (photo/gradient)")
        if not full and u > 56 and w * h <= 1600:
            warns.append(f"WARN {rel} unique={u} on small sprite (messy / anti-aliased)")
        if min(w, h) < 8 and "shadow" not in path.name and "firefly" not in path.name:
            warns.append(f"WARN {rel} {w}x{h} very small — may read as noise")
    for line in warns:
        print(line)
    for line in fails:
        print(line)
    print(f"result: {len(fails)} fail, {len(warns)} warn")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
