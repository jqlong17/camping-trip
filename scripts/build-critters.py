#!/usr/bin/env python3
"""Build forest wildlife sprites from text-to-image sheets."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from asset_layout import FOREST_WORLD
from gen_slice_common import hard_fit, load_gen, slice_equal, slice_grid, slice_runs

OUT = FOREST_WORLD


def kill_corner_bg(im: Image.Image, thr: int = 42) -> Image.Image:
    """Remove near-uniform sheet background sampled from corners."""
    a = np.array(im.convert("RGBA"))
    h, w = a.shape[:2]
    samples = [
        a[2, 2, :3],
        a[2, w - 3, :3],
        a[h - 3, 2, :3],
        a[h - 3, w - 3, :3],
        a[h // 2, 2, :3],
        a[h // 2, w - 3, :3],
    ]
    bg = np.median(np.stack(samples), axis=0)
    dist = np.abs(a[:, :, :3].astype(int) - bg.astype(int)).sum(axis=2)
    a[dist < thr, 3] = 0
    # also kill classic cream / dark voids
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    cream = (r > 230) & (g > 220) & (b > 200)
    dark = (r < 22) & (g < 22) & (b < 22)
    a[cream | dark, 3] = 0
    return Image.fromarray(a)


def save(name: str, im: Image.Image) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    im.save(path)
    print(f"  {path.name} {im.size}")


def main() -> int:
    print("critters from gen → scenes/forest/world/")
    birds = load_gen("critters_birds_sheet_gen.png")
    cells = slice_grid(birds, 3, 3, pad=0.06)
    names = []
    for i in range(3):
        names += [
            f"bird_{i}_perch.png",
            f"bird_{i}_fly0.png",
            f"bird_{i}_fly1.png",
        ]
    sizes = [(12, 10), (14, 10), (14, 10)] * 3
    for name, cell, (w, h) in zip(names, cells, sizes):
        save(name, hard_fit(kill_corner_bg(cell), w, h, 20))

    bugs = load_gen("critters_bugs_sheet_gen.png")
    parts = slice_runs(bugs)
    if len(parts) != 6:
        parts = slice_equal(bugs, 6, pad=0.05)
    # nest still from sheet; flying insects are per-item below
    if parts:
        save("nest.png", hard_fit(kill_corner_bg(parts[0], thr=38), 14, 10, 18))

    from gen_slice_common import GEN_ASSETS

    # 蝴蝶 / 蜻蜓 / 萤火虫：按件文生图，分辨率提到营地可读
    insect_specs = [
        ("butterfly_0.png", "butterfly_wing_open_gen.png", 36, 30),
        ("butterfly_1.png", "butterfly_wing_closed_gen.png", 36, 30),
        ("dragonfly.png", "dragonfly_gen.png", 36, 18),
        ("firefly_0.png", "firefly_0_gen.png", 14, 14),
        ("firefly_1.png", "firefly_1_gen.png", 14, 14),
    ]
    for out_name, stem, w, h in insect_specs:
        src = GEN_ASSETS / stem
        if not src.is_file():
            raise SystemExit(f"missing insect gen: {src}")
        save(
            out_name,
            hard_fit(kill_corner_bg(load_gen(stem, stem.replace(".png", "_ref.png")), thr=48), w, h, 24),
        )
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
