#!/usr/bin/env python3
"""Rebuild grass + dirt pad tiles + dirt-grass fringe (16×16 hard pixel)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
from asset_layout import FOREST_CAMP

OUT = FOREST_CAMP
BAK = OUT / "_ground_v2_bak"

# Quiet meadow — keep neighbor averages close (no checkerboard)
G0 = (58, 118, 34)   # base
G1 = (48, 100, 28)   # shade
G2 = (72, 136, 40)   # lift
G3 = (90, 154, 50)   # tip
G4 = (40, 84, 24)    # deep shade

FLOWER = {
    "w": (240, 236, 214),
    "y": (228, 188, 52),
    "p": (212, 118, 140),
}
STEM = (52, 104, 30)
PEB = (122, 102, 68)
PEB_L = (158, 138, 96)

# Dirt pad — softer, less salt noise
D0 = (162, 122, 62)
D1 = (136, 100, 48)
D2 = (184, 146, 90)
D3 = (148, 108, 54)  # wear
D4 = (120, 88, 42)   # crack


def save(name: str, im: Image.Image) -> None:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    bak = BAK / name
    if path.exists() and not bak.exists():
        BAK.mkdir(parents=True, exist_ok=True)
        Image.open(path).save(bak)
    im.save(path)
    print(f"  {name}")


def put(px, x: int, y: int, rgb) -> None:
    if 0 <= x < 16 and 0 <= y < 16:
        px[x, y] = (*rgb, 255)


def put_a(px, x: int, y: int, rgba) -> None:
    if 0 <= x < 16 and 0 <= y < 16:
        px[x, y] = rgba


def h(x: int, y: int, s: int = 0) -> int:
    return (x * 41 + y * 73 + s * 91) & 0xFFFF


def blade_sprig(px, x: int, y: int, tall: bool = False) -> None:
    """Single vertical grass sprig (not an X)."""
    put(px, x, y, G1)
    put(px, x, y - 1, G3)
    if tall:
        put(px, x, y - 2, G2)


def blade_clump(px, x: int, y: int) -> None:
    """Small L-shaped clump (avoids +)."""
    put(px, x, y, G1)
    put(px, x, y - 1, G3)
    put(px, x + 1, y, G4)


def build_grass() -> None:
    # Per-variant hand layouts — sparse, different rhythms
    # sprigs, clumps, optional flower, optional pebble
    layouts = [
        {"sprigs": [(4, 6), (12, 11)], "clumps": [(9, 3)], "flower": (6, 13, "w"), "peb": None},
        {"sprigs": [(2, 10), (10, 5)], "clumps": [(14, 12)], "flower": None, "peb": (7, 2)},
        {"sprigs": [(7, 4), (3, 14)], "clumps": [(11, 9)], "flower": (13, 7, "y"), "peb": None},
        {"sprigs": [(5, 8), (14, 4)], "clumps": [(1, 5)], "flower": None, "peb": (9, 14)},
        {"sprigs": [(8, 12), (1, 3)], "clumps": [(12, 6)], "flower": (4, 9, "p"), "peb": None},
        {"sprigs": [(11, 2), (6, 10)], "clumps": [(3, 7)], "flower": None, "peb": (14, 13)},
        {"sprigs": [(9, 7), (2, 12)], "clumps": [(13, 14)], "flower": (10, 4, "w"), "peb": None},
        {"sprigs": [(15, 8), (5, 2)], "clumps": [(8, 14)], "flower": None, "peb": (3, 11)},
    ]
    for i, lay in enumerate(layouts):
        im = Image.new("RGBA", (16, 16), (*G0, 255))
        px = im.load()
        # Large quiet patches only (circular / irregular — not diamond +)
        for cx, cy, col, r in (
            (3 + (i % 3), 4 + (i % 2), G1, 2),
            (10 + (i % 4), 9, G1, 2),
            (7, 2 + (i % 3), G2, 1),
            (2, 11, G2, 1),
            (13, 5 + (i % 2), G2, 1),
        ):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx * dx + dy * dy <= r * r + (0 if r == 1 else 0):
                        # skip some corners for irregularity
                        if r > 1 and abs(dx) == r and abs(dy) == r:
                            continue
                        put(px, cx + dx, cy + dy, col)
        # Very sparse lift dots
        for y in range(16):
            for x in range(16):
                if h(x, y, i + 20) % 47 == 0:
                    put(px, x, y, G2)

        for sx, sy in lay["sprigs"]:
            blade_sprig(px, sx, sy, tall=(h(sx, sy, i) % 2 == 0))
        for cx, cy in lay["clumps"]:
            blade_clump(px, cx, cy)

        fl = lay["flower"]
        if fl:
            fx, fy, kind = fl
            put(px, fx, fy + 1, STEM)
            put(px, fx, fy, FLOWER[kind])

        if lay["peb"]:
            sx, sy = lay["peb"]
            put(px, sx, sy, PEB)
            put(px, sx - 1, sy, PEB_L)

        # Keep rim near base so tiling seams stay soft
        for x in range(16):
            if h(x, 0, i) % 5 != 0:
                put(px, x, 0, G0)
                put(px, x, 15, G0)
        for y in range(16):
            if h(0, y, i) % 5 != 0:
                put(px, 0, y, G0)
                put(px, 15, y, G0)

        save(f"tile_grass{i}.png", im)


def build_dirt() -> None:
    wear_blobs = [
        [(6, 6), (7, 6), (8, 6), (6, 7), (7, 7), (8, 7), (7, 8)],
        [(5, 7), (6, 7), (7, 7), (8, 8), (6, 8), (7, 9)],
        [(7, 5), (8, 5), (7, 6), (8, 6), (9, 6), (8, 7)],
        [(6, 8), (7, 8), (8, 8), (5, 9), (6, 9), (7, 9), (8, 9)],
    ]
    shade_patches = [
        [(2, 3, 2), (11, 4, 2), (4, 12, 1)],
        [(3, 5, 2), (12, 10, 2), (8, 2, 1)],
        [(1, 8, 2), (10, 3, 2), (13, 13, 1)],
        [(4, 2, 2), (9, 11, 2), (14, 6, 1)],
    ]
    for i in range(4):
        im = Image.new("RGBA", (16, 16), (*D0, 255))
        px = im.load()
        for cx, cy, r in shade_patches[i]:
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx * dx + dy * dy <= r * r:
                        put(px, cx + dx, cy + dy, D1 if (dx + dy) % 2 == 0 else D3)
        for x, y in wear_blobs[i]:
            put(px, x, y, D3)
        # Sparse highlights / cracks (not salt)
        for x, y in ((3, 10), (12, 7), (9, 13), (14, 3), (1, 14)):
            ox = (x + i * 2) % 16
            oy = (y + i) % 16
            put(px, ox, oy, D2 if (x + y) % 2 == 0 else D4)
        # Tiny edge grass only on corners (real fringe is overlay)
        for bx, by in ((0, 0), (15, 1), (1, 15), (14, 14)):
            if (bx + by + i) % 2 == 0:
                put(px, bx, by, G2)
        if i % 2:
            put(px, 4 + i, 10, PEB)
            put(px, 3 + i, 10, PEB_L)
        save(f"tile_dirt{i}.png", im)


def build_dirt_fringe() -> None:
    """Transparent grass lip for dirt tiles bordering meadow."""
    # Edge on the *outer* side of the dirt pad (toward grass neighbor)
    # N fringe: grass along top rows of dirt tile
    specs = {
        "N": ("y", 0, 1),   # paint near y=0,1
        "S": ("y", 15, 14),
        "W": ("x", 0, 1),
        "E": ("x", 15, 14),
    }
    for name, (axis, a0, a1) in specs.items():
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        px = im.load()
        for i in range(16):
            if axis == "y":
                # horizontal edge
                if i % 3 != 2:
                    put_a(px, i, a0, (*G1, 255))
                if i % 4 == 1:
                    put_a(px, i, a1, (*G3, 255))
                if i % 5 == 3:
                    put_a(px, i, a0, (*G4, 255))
                if i % 7 == 2:
                    put_a(px, i, a1, (*D3, 220))
            else:
                if i % 3 != 2:
                    put_a(px, a0, i, (*G1, 255))
                if i % 4 == 1:
                    put_a(px, a1, i, (*G3, 255))
                if i % 5 == 3:
                    put_a(px, a0, i, (*G4, 255))
                if i % 7 == 2:
                    put_a(px, a1, i, (*D3, 220))
        save(f"dirt_fringe_{name}.png", im)


def main() -> None:
    print("grass")
    build_grass()
    print("dirt")
    build_dirt()
    print("dirt fringe")
    build_dirt_fringe()
    print("done")


if __name__ == "__main__":
    main()
