#!/usr/bin/env python3
"""Rebuild creek water / shallow / shore tiles from text-to-image sheets."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from asset_layout import FOREST_CAMP
from gen_slice_common import hard_fit, hard_tile, load_gen, quantize_rgba, slice_grid

OUT = FOREST_CAMP
BAK = OUT / "_creek_v1"

SHORE_KEYS = ["E", "W", "N", "S", "NE", "NW", "SE", "SW"]


def save(name: str, im: Image.Image) -> None:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    bak = BAK / name
    if path.exists() and not bak.exists():
        BAK.mkdir(parents=True, exist_ok=True)
        Image.open(path).save(bak)
    im.save(path)
    print(f"  {name} {im.size}")


def cell_tile(cell: Image.Image, colors: int = 18) -> Image.Image:
    w, h = cell.size
    inset = max(2, min(w, h) // 16)
    cropped = cell.crop((inset, inset, w - inset, h - inset))
    return hard_tile(cropped, 16, colors)


def to_shore_overlay(cell: Image.Image) -> Image.Image:
    """Keep sand/wet lip + nearby grass tufts; kill water + sheet checker bg."""
    w, h = cell.size
    inset = max(2, min(w, h) // 18)
    cell = cell.crop((inset, inset, w - inset, h - inset))
    a = np.array(cell.convert("RGBA"))
    r = a[:, :, 0].astype(int)
    g = a[:, :, 1].astype(int)
    b = a[:, :, 2].astype(int)
    # checkerboard gray bg
    checker = (np.abs(r.astype(int) - g) < 18) & (np.abs(g.astype(int) - b) < 18) & (r > 140) & (r < 220)
    water = (b > r + 15) & (b > g - 5) & (b > 90)
    # sand / wet bank
    sand = (r > 110) & (g > 70) & (b < 130) & (r > b + 15) & (r - g < 90)
    wet = (r > 70) & (r < 170) & (g > 55) & (g < 150) & (b < 110) & (r >= g - 10)
    grass = (g > r + 12) & (g > b) & (g > 70)
    keep = sand | wet
    # grass only near sand/wet band
    ys, xs = np.where(keep)
    if len(xs):
        yy0, yy1 = int(ys.min()), int(ys.max())
        xx0, xx1 = int(xs.min()), int(xs.max())
        band = np.zeros_like(keep)
        band[max(0, yy0 - 2) : min(a.shape[0], yy1 + 3), max(0, xx0 - 2) : min(a.shape[1], xx1 + 3)] = True
        keep = keep | (grass & band)

    out = a.copy()
    out[~(keep) | checker | water, 3] = 0
    im = Image.fromarray(out)
    # hard fit to 16 keeping transparency
    mid = im.resize((32, 32), Image.Resampling.BILINEAR)
    pixel = mid.resize((16, 16), Image.Resampling.NEAREST)
    # re-kill near-transparent junk
    pa = np.array(pixel)
    pa[pa[:, :, 3] < 40, 3] = 0
    return quantize_rgba(Image.fromarray(pa), 16)


def build_water() -> None:
    src = load_gen("creek_water_sheet_gen.png")
    cells = slice_grid(src, 4, 2, pad=0.02)
    if len(cells) < 8:
        raise SystemExit(f"creek water expected 8 cells, got {len(cells)}")
    for i, cell in enumerate(cells[:4]):
        save(f"tile_water{i}.png", cell_tile(cell, 16))
    for i, cell in enumerate(cells[4:8]):
        save(f"tile_shallow{i}.png", cell_tile(cell, 16))


def build_shores() -> None:
    src = load_gen("creek_shore_sheet_gen.png")
    cells = slice_grid(src, 4, 2, pad=0.02)
    if len(cells) < 8:
        raise SystemExit(f"shore sheet expected 8 cells, got {len(cells)}")
    # Prompt order: E W N S / NE NW SE SW
    # Gen may swap N/S — remap by detecting water mass location after kill.
    mapped = list(cells[:8])
    for k, cell in zip(SHORE_KEYS, mapped):
        save(f"shore_{k}.png", to_shore_overlay(cell))


def improve_reed() -> None:
    """Reed clump: prefer extracting from fish weed spot gen if available."""
    weed = OUT.parent.parent.parent / "ritual" / "fish" / "spot_weed.png"
    # path: assets/ritual/fish/spot_weed.png
    weed = Path(__file__).resolve().parents[1] / "game" / "assets" / "ritual" / "fish" / "spot_weed.png"
    if weed.is_file():
        src = Image.open(weed).convert("RGBA")
        # crop green reed-ish upper region
        a = np.array(src)
        g = a[:, :, 1].astype(int)
        r = a[:, :, 0].astype(int)
        b = a[:, :, 2].astype(int)
        green = (g > r + 10) & (g > b) & (g > 60) & (a[:, :, 3] > 20)
        a[~green, 3] = 0
        reed = Image.fromarray(a)
        save("prop_reed.png", hard_fit(reed, 12, 20, 12))
    else:
        print("  skip prop_reed (no spot_weed yet)")


def main() -> int:
    print("build creek tiles from gen")
    build_water()
    build_shores()
    improve_reed()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
