#!/usr/bin/env python3
"""Camp life assets: extra trees from gen; bird chirp WAV; cups delegated."""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

import numpy as np
from PIL import Image

from asset_layout import SHARED
from gen_slice_common import hard_fit, load_gen, slice_equal, slice_runs

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "game" / "audio"

TREE_NAMES = ["tile_tree8.png", "tile_tree9.png", "tile_tree10.png", "tile_tree11.png"]
TREE_SIZES = [(28, 40), (26, 38), (30, 36), (28, 36)]


def kill_grass_bg(im: Image.Image) -> Image.Image:
    """Remove meadow grass backdrop under trees; keep canopy greens."""
    a = np.array(im.convert("RGBA"))
    h, w = a.shape[:2]
    # sample lower corners + mid-bottom for grass ground color
    samples = [a[h - 4, 4, :3], a[h - 4, w - 5, :3], a[h - 3, w // 2, :3], a[2, 2, :3], a[2, w - 3, :3]]
    bg = np.median(np.stack(samples), axis=0)
    dist = np.abs(a[:, :, :3].astype(int) - bg.astype(int)).sum(axis=2)
    # only clear bg-like pixels in lower third OR matching top corner field
    lower = np.zeros((h, w), dtype=bool)
    lower[int(h * 0.72) :, :] = True
    top_field = np.zeros((h, w), dtype=bool)
    top_field[: max(4, h // 10), :] = True
    a[(dist < 40) & (lower | top_field), 3] = 0
    # clear left/right gutters that are grass between trees
    gutter = np.zeros((h, w), dtype=bool)
    gutter[:, : max(2, w // 12)] = True
    gutter[:, w - max(2, w // 12) :] = True
    a[(dist < 36) & gutter, 3] = 0
    return Image.fromarray(a)


def save(path: Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def build_trees() -> None:
    src = load_gen("trees_extra_sheet_gen.png")
    parts = slice_runs(src)
    if len(parts) != 4:
        parts = slice_equal(src, 4, pad=0.05)
    for name, (w, h), cell in zip(TREE_NAMES, TREE_SIZES, parts):
        save(SHARED / name, hard_fit(kill_grass_bg(cell), w, h, 24))


def build_cups() -> None:
    print("  (cups: run scripts/build-cups.py)")


def build_bird_chirp() -> None:
    path = AUDIO / "sfx_bird.wav"
    rate = 22050
    dur = 0.22
    n = int(rate * dur)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(n):
            t = i / rate
            env = max(0.0, 1.0 - t / dur)
            freq = 1800 + 900 * math.sin(t * 40)
            val = int(12000 * env * math.sin(2 * math.pi * freq * t))
            frames += struct.pack("<h", max(-32767, min(32767, val)))
        w.writeframes(frames)
    print(f"  audio/sfx_bird.wav {n} samples")


def main() -> int:
    print("build camp life assets (trees from gen; cast not touched)")
    build_trees()
    build_cups()
    build_bird_chirp()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
