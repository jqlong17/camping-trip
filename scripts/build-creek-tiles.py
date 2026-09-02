#!/usr/bin/env python3
"""Rebuild seamless natural creek water / shallow / shore tiles from gen sources."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from asset_layout import FOREST_CAMP
from gen_slice_common import hard_fit, hard_tile, load_gen, quantize_rgba

OUT = FOREST_CAMP
BAK = OUT / "_creek_v1"

SHORE_KEYS = ["E", "W", "N", "S", "NE", "NW", "SE", "SW"]
WATER_SOURCE = "creek_water_natural_v2.png"
SHORE_SOURCE = "creek_shore_natural_v2.png"

ASSET_PROVENANCE = [
    {
        "outputs": [
            "game/assets/scenes/forest/camp/tile_water*.png",
            "game/assets/scenes/forest/camp/tile_shallow*.png",
        ],
        "sources": ["docs/promo/creek_water_natural_v2_ref.png"],
        "operation": "4x2 generated source slice + hard-pixel quantize + shared seamless borders",
    },
    {
        "outputs": ["game/assets/scenes/forest/camp/shore_*.png"],
        "sources": ["docs/promo/creek_shore_natural_v2_ref.png"],
        "operation": "magenta CKE + narrow natural bank extraction + 8-way edge composition",
    },
]


def save(name: str, im: Image.Image) -> None:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    bak = BAK / name
    if path.exists() and not bak.exists():
        BAK.mkdir(parents=True, exist_ok=True)
        Image.open(path).save(bak)
    im.save(path)
    print(f"  {name} {im.size}")


def exact_grid(im: Image.Image, cols: int = 4, rows: int = 2) -> list[Image.Image]:
    """Slice the generated sheet by its explicit panel grid, not foreground color."""
    cells: list[Image.Image] = []
    for row in range(rows):
        for col in range(cols):
            left = round(im.width * col / cols)
            right = round(im.width * (col + 1) / cols)
            top = round(im.height * row / rows)
            bottom = round(im.height * (row + 1) / rows)
            inset = max(2, min(right - left, bottom - top) // 100)
            cells.append(im.crop((left + inset, top + inset, right - inset, bottom - inset)))
    return cells


def cell_tile(cell: Image.Image, colors: int = 18) -> Image.Image:
    inset = max(2, min(cell.size) // 48)
    cropped = cell.crop((inset, inset, cell.width - inset, cell.height - inset))
    return hard_tile(cropped, 16, colors)


def shared_seamless_borders(tiles: list[Image.Image]) -> list[Image.Image]:
    """All variants share wrap-safe outer pixels, so any neighboring pair joins."""
    arrays = [np.array(tile.convert("RGBA")) for tile in tiles]
    anchor = arrays[0]
    horizontal = anchor[0, :, :].copy()
    vertical = anchor[:, 0, :].copy()
    corner = anchor[0, 0, :].copy()
    for arr in arrays:
        arr[0, :, :] = horizontal
        arr[-1, :, :] = horizontal
        arr[:, 0, :] = vertical
        arr[:, -1, :] = vertical
        arr[0, 0, :] = arr[0, -1, :] = arr[-1, 0, :] = arr[-1, -1, :] = corner
    return [Image.fromarray(arr) for arr in arrays]


def magenta_key(cell: Image.Image) -> Image.Image:
    """CKE on a contrast color that cannot delete green grass or brown soil."""
    a = np.array(cell.convert("RGBA"))
    rgb = a[:, :, :3].astype(int)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    magenta = (r > 190) & (b > 170) & (g < 110) & ((r + b) > g * 3)
    a[magenta, 3] = 0
    return Image.fromarray(a.astype(np.uint8))


def panel_to_tile(cell: Image.Image) -> Image.Image:
    keyed = magenta_key(cell)
    a = np.array(keyed)
    ys, xs = np.where(a[:, :, 3] > 20)
    if not len(xs):
        return Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pad = max(2, min(cell.size) // 100)
    crop = keyed.crop((
        max(0, int(xs.min()) - pad),
        max(0, int(ys.min()) - pad),
        min(cell.width, int(xs.max()) + 1 + pad),
        min(cell.height, int(ys.max()) + 1 + pad),
    ))
    mid = crop.resize((32, 32), Image.Resampling.BILINEAR)
    pixel = mid.resize((16, 16), Image.Resampling.NEAREST)
    pa = np.array(pixel)
    pa[pa[:, :, 3] < 96, 3] = 0
    return quantize_rgba(Image.fromarray(pa), 14)


def narrow_edge(panel: Image.Image, direction: str) -> Image.Image:
    """Retain a continuous 2–3 px grass/soil lip on the land-side tile."""
    a = np.array(panel.convert("RGBA"))
    yy, xx = np.mgrid[0:16, 0:16]
    wobble = np.array([0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1])
    if direction == "E":
        keep = xx >= (13 - wobble[yy])
    elif direction == "W":
        keep = xx <= (2 + wobble[yy])
    elif direction == "N":
        keep = yy <= (2 + wobble[xx])
    else:
        keep = yy >= (13 - wobble[xx])

    # CKE may leave pinholes along an antialiased source contour. Fill each
    # canonical strip from the nearest real source pixel before color locking.
    valid_y, valid_x = np.where(a[:, :, 3] > 96)
    for y, x in zip(*np.where(keep)):
        if a[y, x, 3] <= 96 and len(valid_x):
            nearest = np.argmin((valid_x - x) ** 2 + (valid_y - y) ** 2)
            a[y, x, :3] = a[valid_y[nearest], valid_x[nearest], :3]
        a[y, x, 3] = 255
    a[~keep, 3] = 0

    # Pull the generated ochre/green material into the camp's existing grass
    # and damp-earth palette. This keeps the bank readable without a bright ring.
    grass = np.array(Image.open(OUT / "tile_grass0.png").convert("RGB"), dtype=int)
    dirt = np.array(Image.open(OUT / "tile_dirt0.png").convert("RGB"), dtype=int)
    grass_base = np.median(grass.reshape(-1, 3), axis=0)
    dirt_base = np.median(dirt.reshape(-1, 3), axis=0)
    for y, x in zip(*np.where(keep)):
        source = a[y, x, :3].astype(int)
        is_green = source[1] > source[0] * 0.92 and source[1] > source[2] * 1.05
        damp_base = dirt_base * 0.52 + grass_base * 0.48
        base = grass_base if is_green else damp_base
        a[y, x, :3] = np.clip(base * 0.84 + source * 0.16, 0, 255)
    return Image.fromarray(a)


def build_water() -> None:
    src = load_gen(WATER_SOURCE)
    cells = exact_grid(src)
    if len(cells) < 8:
        raise SystemExit(f"creek water expected 8 cells, got {len(cells)}")
    deep = shared_seamless_borders([cell_tile(cell, 16) for cell in cells[:4]])
    shallow = shared_seamless_borders([cell_tile(cell, 14) for cell in cells[4:8]])
    for i, tile in enumerate(deep):
        save(f"tile_water{i}.png", tile)
    for i, tile in enumerate(shallow):
        save(f"tile_shallow{i}.png", tile)


def build_shores() -> None:
    src = load_gen(SHORE_SOURCE)
    cells = exact_grid(src)
    if len(cells) < 8:
        raise SystemExit(f"shore sheet expected 8 cells, got {len(cells)}")
    # Generated N/S panels landed visually swapped; map by observed water side.
    panels = {
        "E": panel_to_tile(cells[0]),
        "W": panel_to_tile(cells[1]),
        "N": panel_to_tile(cells[3]),
        "S": panel_to_tile(cells[2]),
    }
    edges = {key: narrow_edge(panel, key) for key, panel in panels.items()}
    for key in ("E", "W", "N", "S"):
        save(f"shore_{key}.png", edges[key])
    # Corner overlays are exact compositions of the straight canonical strips.
    # This makes all 8 directions available without a second high-contrast ring.
    for corner, pair in {
        "NE": ("N", "E"), "NW": ("N", "W"),
        "SE": ("S", "E"), "SW": ("S", "W"),
    }.items():
        tile = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        tile.alpha_composite(edges[pair[0]])
        tile.alpha_composite(edges[pair[1]])
        save(f"shore_{corner}.png", quantize_rgba(tile, 14))


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


def validate_tiles() -> None:
    """Fail the build on visible seams, broken edge coverage, or blue bank pixels."""
    for prefix in ("tile_water", "tile_shallow"):
        arrays = [np.array(Image.open(OUT / f"{prefix}{i}.png").convert("RGBA")) for i in range(4)]
        for i, arr in enumerate(arrays):
            if not np.array_equal(arr[0, :, :], arr[-1, :, :]):
                raise ValueError(f"{prefix}{i}: north/south seam mismatch")
            if not np.array_equal(arr[:, 0, :], arr[:, -1, :]):
                raise ValueError(f"{prefix}{i}: east/west seam mismatch")
        for arr in arrays[1:]:
            if not np.array_equal(arr[0, :, :], arrays[0][0, :, :]):
                raise ValueError(f"{prefix}: variant north/south borders differ")
            if not np.array_equal(arr[:, 0, :], arrays[0][:, 0, :]):
                raise ValueError(f"{prefix}: variant east/west borders differ")

    for direction in ("E", "W", "N", "S"):
        arr = np.array(Image.open(OUT / f"shore_{direction}.png").convert("RGBA"))
        border = {
            "E": arr[:, -1, 3], "W": arr[:, 0, 3],
            "N": arr[0, :, 3], "S": arr[-1, :, 3],
        }[direction]
        if not np.all(border > 0):
            raise ValueError(f"shore_{direction}: broken outer edge")
        rgb = arr[:, :, :3].astype(int)
        cyan = (rgb[:, :, 2] > rgb[:, :, 0] + 24) & (rgb[:, :, 1] > rgb[:, :, 0] + 12) & (arr[:, :, 3] > 0)
        if cyan.any():
            raise ValueError(f"shore_{direction}: cyan/blue bank residue")
    print("  seam audit PASS water+shallow+shore_8way")


def main() -> int:
    print("build natural seamless creek tiles from gen")
    build_water()
    build_shores()
    improve_reed()
    validate_tiles()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
