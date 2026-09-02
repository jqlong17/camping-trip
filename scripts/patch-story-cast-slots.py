#!/usr/bin/env python3
"""Remove baked-in default boy from travel storyboards; runtime overlays selected cast."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
STORY = ROOT / "game" / "assets" / "story"

# Fixed erase boxes + runtime overlay feet anchors (logic 400×240 space).
# Overlay draws cast sprite at 20×20 (scale 0.5 from 40×40) with top-left = slot.
STORY_CAST_SLOTS = {
    # erase (x0,y0,x1,y1 inclusive), overlay top-left
    "d1": {"erase": (165, 105, 186, 136), "slot": (164, 112)},
    "d2": {"erase": (165, 107, 185, 138), "slot": (164, 114)},
    "h1": {"erase": (180, 155, 216, 202), "slot": (188, 166)},
}


def erase_box(im: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    out = arr.copy()
    x0, y0, x1, y1 = box
    h, w = arr.shape[:2]
    mask = np.zeros((h, w), dtype=bool)
    mask[y0 : y1 + 1, x0 : x1 + 1] = True
    ys, xs = np.where(mask)
    for y, x in zip(ys, xs):
        best = None
        bestd = 10**9
        for radius in range(1, 18):
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    if max(abs(dx), abs(dy)) != radius:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not mask[ny, nx]:
                        d = dx * dx + dy * dy
                        if d < bestd:
                            bestd = d
                            best = (nx, ny)
            if best:
                break
        if best:
            out[y, x] = arr[best[1], best[0]]
    return Image.fromarray(out)


def main() -> int:
    for key, meta in STORY_CAST_SLOTS.items():
        path = STORY / f"{key}.png"
        if not path.exists():
            print(f"missing {path}")
            continue
        src = Image.open(path).convert("RGBA")
        # backup once
        bak = STORY / f"{key}_with_boy_v1.png"
        if not bak.exists():
            src.save(bak)
            print(f"backup {bak.name}")
        cleaned = erase_box(src, tuple(meta["erase"]))
        # preserve pot padding if any
        if cleaned.size != src.size:
            canvas = Image.new("RGBA", src.size, (0, 0, 0, 255))
            canvas.paste(cleaned, (0, 0))
            cleaned = canvas
        cleaned.save(path)
        print(f"patched {key}.png erase={meta['erase']} slot={meta['slot']}")
    print("slots for main.lua:", {k: v["slot"] for k, v in STORY_CAST_SLOTS.items()})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
