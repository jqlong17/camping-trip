#!/usr/bin/env python3
"""Slice tent pitch/pack sheets → gear/tent + camp tent tiles.

IMPORTANT: tent fabric (尤其沙褐) 不能走 gen_slice_common.kill_bg——
木纹/浅木掩码会把沙色帐布当成背景抠没，地图上只剩绿草垫+细杆。
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from gen_slice_common import load_gen, quantize_rgba, slice_equal, slice_grid, slice_runs

ROOT = Path(__file__).resolve().parents[1]
TENT_GEAR = ROOT / "game" / "assets" / "gear" / "tent"
TENT_CAMP = ROOT / "game" / "assets" / "scenes" / "forest" / "camp" / "tent"

STYLES = ["dome", "tunnel", "peak"]
COLORS = ["sand", "pine", "mist"]


def kill_sheet_pad(im: Image.Image) -> Image.Image:
    """去掉奶油底 + 帐底草垫（含偏黄的软绿），保留帐布（含松绿）。"""
    a = np.array(im.convert("RGBA"))
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    cream = (r > 225) & (g > 215) & (b > 195)
    # 旧荧光绿
    lime = (g > 160) & (g > r + 45) & (g > b + 35) & (r < 160) & (b < 120)
    # 软草绿垫：只清下半，避免误伤松绿帐布上沿
    h = a.shape[0]
    lower = np.zeros(a.shape[:2], dtype=bool)
    lower[int(h * 0.52) :, :] = True
    soft_pad = (
        (g > 95)
        & (g < 190)
        & (g > r + 18)
        & (g > b + 12)
        & (r < 170)
        & (b < 140)
        & lower
    )
    a[cream | lime | soft_pad, 3] = 0
    return Image.fromarray(a)


def tent_hard_fit(im: Image.Image, tw: int = 48, th: int = 40, colors: int = 36) -> Image.Image:
    rgba = kill_sheet_pad(im)
    arr = np.array(rgba)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    crop = rgba.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    scale = min((tw - 2) / crop.width, (th - 2) / crop.height)
    nw = max(1, int(round(crop.width * scale)))
    nh = max(1, int(round(crop.height * scale)))
    mid_w, mid_h = max(4, nw // 2), max(4, nh // 2)
    mid = crop.resize((mid_w, mid_h), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    scaled = quantize_rgba(scaled, colors)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def save(path: Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def main() -> int:
    shut = load_gen("tents_pitch_shut_sheet_gen.png")
    ajar = load_gen("tents_pitch_ajar_sheet_gen.png")
    packs = load_gen("tents_pack_sheet_gen.png")

    shut_cells = slice_grid(shut, 3, 3, pad=0.05)
    ajar_cells = slice_grid(ajar, 3, 3, pad=0.05)
    if len(shut_cells) < 9 or len(ajar_cells) < 9:
        raise SystemExit(f"tent grid short: shut={len(shut_cells)} ajar={len(ajar_cells)}")

    for r, style in enumerate(STYLES):
        for c, color in enumerate(COLORS):
            i = r * 3 + c
            save(TENT_CAMP / f"pitch_{style}_{color}_shut.png", tent_hard_fit(shut_cells[i]))
            save(TENT_CAMP / f"pitch_{style}_{color}_ajar.png", tent_hard_fit(ajar_cells[i]))

    for r, style in enumerate(STYLES):
        save(TENT_GEAR / f"style_{style}.png", tent_hard_fit(shut_cells[r * 3], 48, 40, 24))
    for c, color in enumerate(COLORS):
        save(TENT_GEAR / f"color_{color}.png", tent_hard_fit(shut_cells[c], 48, 40, 24))
    save(TENT_GEAR / "door_shut.png", tent_hard_fit(shut_cells[0], 48, 40, 24))
    save(TENT_GEAR / "door_ajar.png", tent_hard_fit(ajar_cells[0], 48, 40, 24))

    pack_parts = slice_runs(packs)
    if len(pack_parts) != 3:
        pack_parts = slice_equal(packs, 3, pad=0.05)
    for color, cell in zip(COLORS, pack_parts):
        # packs: cream-only kill via tent_hard_fit is fine
        save(TENT_CAMP / f"pack_{color}.png", tent_hard_fit(cell, 22, 16, 20))
        save(TENT_GEAR / f"pack_{color}.png", tent_hard_fit(cell, 48, 40, 20))

    camp = ROOT / "game" / "assets" / "scenes" / "forest" / "camp"
    save(camp / "tile_tent_open.png", tent_hard_fit(shut_cells[0]))
    save(camp / "tile_tent.png", tent_hard_fit(shut_cells[0]))
    save(camp / "tile_tent_packed.png", tent_hard_fit(pack_parts[0], 28, 20, 24))

    # sanity: sand shut must keep fabric (not just poles)
    sand = Image.open(TENT_CAMP / "pitch_dome_sand_shut.png").convert("RGBA")
    opaque = sum(1 for px in sand.getdata() if px[3] > 20)
    if opaque < 400:
        raise SystemExit(f"sand tent still too sparse opaque={opaque} — check kill mask")
    print(f"ok sand dome shut opaque={opaque}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
