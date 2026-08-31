#!/usr/bin/env python3
"""Rebuild grass + dirt pad tiles from text-to-image sheets (16×16)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from asset_layout import FOREST_CAMP
from gen_slice_common import hard_tile, load_gen, quantize_rgba, slice_grid

OUT = FOREST_CAMP
BAK = OUT / "_ground_v2_bak"

G1 = (48, 100, 28, 255)
G3 = (90, 154, 50, 255)
G4 = (40, 84, 24, 255)
D3 = (148, 108, 54, 220)


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
    """Inset past grid lines then hard-pixel to 16×16."""
    w, h = cell.size
    inset = max(2, min(w, h) // 16)
    cropped = cell.crop((inset, inset, w - inset, h - inset))
    return hard_tile(cropped, 16, colors)


def build_grass() -> None:
    src = load_gen("grass_tiles_sheet_gen.png")
    # sheet is 4 cols × 2 rows
    cells = slice_grid(src, 4, 2, pad=0.02)
    if len(cells) < 8:
        raise SystemExit(f"grass sheet expected 8 cells, got {len(cells)}")
    for i, cell in enumerate(cells[:8]):
        save(f"tile_grass{i}.png", cell_tile(cell, 16))


def build_dirt() -> None:
    src = load_gen("dirt_tiles_sheet_gen.png")
    cells = slice_grid(src, 2, 2, pad=0.03)
    if len(cells) < 4:
        raise SystemExit(f"dirt sheet expected 4 cells, got {len(cells)}")
    for i, cell in enumerate(cells[:4]):
        save(f"tile_dirt{i}.png", cell_tile(cell, 16))


def build_dirt_fringe() -> None:
    """Transparent grass lip overlays derived from grass tile greens (edge only)."""
    grass0 = Image.open(OUT / "tile_grass0.png").convert("RGBA")
    a = np.array(grass0)
    # pick green tip pixels from grass as fringe palette source
    specs = {
        "N": ("y", 0, 1),
        "S": ("y", 15, 14),
        "W": ("x", 0, 1),
        "E": ("x", 15, 14),
    }
    for name, (axis, a0, a1) in specs.items():
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        px = im.load()
        for i in range(16):
            if axis == "y":
                if i % 3 != 2:
                    px[i, a0] = G1
                if i % 4 == 1:
                    px[i, a1] = G3
                if i % 5 == 3:
                    px[i, a0] = G4
                if i % 7 == 2:
                    px[i, a1] = D3
            else:
                if i % 3 != 2:
                    px[a0, i] = G1
                if i % 4 == 1:
                    px[a1, i] = G3
                if i % 5 == 3:
                    px[a0, i] = G4
                if i % 7 == 2:
                    px[a1, i] = D3
        # sample a couple of grass tip colors from gen grass for variety
        tips = a[a[:, :, 1] > a[:, :, 0] + 10]
        if len(tips):
            c = tuple(int(x) for x in tips[len(tips) // 3][:3]) + (255,)
            if axis == "y":
                px[4, a0] = c
                px[11, a1] = c
            else:
                px[a0, 4] = c
                px[a1, 11] = c
        save(f"dirt_fringe_{name}.png", quantize_rgba(im, 12))


def main() -> None:
    print("grass from gen")
    build_grass()
    print("dirt from gen")
    build_dirt()
    print("dirt fringe (edge overlay from grass palette)")
    build_dirt_fringe()
    print("done")


if __name__ == "__main__":
    main()
