#!/usr/bin/env python3
"""Rebuild creek water / shallow / shore tiles for softer riverbanks (16×16 hard pixel)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
from asset_layout import FOREST_CAMP

OUT = FOREST_CAMP
BAK = OUT / "_creek_v1"

# Palette — camping creek, not neon pool
DEEP = (28, 96, 158)
DEEP_D = (18, 72, 128)
MID = (42, 132, 188)
LIGHT = (96, 178, 216)
SPARK = (232, 246, 255)
FOAM = (186, 220, 232)
SHALLOW = (64, 158, 168)
SHALLOW_L = (110, 186, 186)
PEBBLE = (148, 128, 86)
PEBBLE_L = (176, 156, 110)
SAND = (186, 148, 84)
SAND_D = (148, 108, 56)
WET = (120, 108, 72)
GRASS_LIP = (78, 148, 42)
GRASS_D = (52, 110, 32)


def save(name: str, im: Image.Image) -> None:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    bak = BAK / name
    if path.exists() and not bak.exists():
        BAK.mkdir(parents=True, exist_ok=True)
        Image.open(path).save(bak)
    im.save(path)
    print(f"  {name} {im.size}")


def blank() -> Image.Image:
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))


def build_water() -> None:
    for i in range(4):
        im = Image.new("RGBA", (16, 16), (*DEEP, 255))
        px = im.load()
        # depth mottling
        for y in range(16):
            for x in range(16):
                n = (x * 3 + y * 5 + i * 2) % 7
                if n == 0:
                    px[x, y] = (*DEEP_D, 255)
                elif n == 3:
                    px[x, y] = (*MID, 255)
        # flowing horizontal bands (phase by frame)
        for band in (3, 8, 13):
            yy = (band + i) % 16
            for x in range(16):
                if (x + i * 2 + band) % 4 != 0:
                    px[x, yy] = (*LIGHT, 255)
                if (x + i) % 5 == 0:
                    px[x, (yy + 1) % 16] = (*MID, 255)
        # foam flecks
        for x, y in ((2 + i, 5), (9, 4 + (i % 2)), (13, 10), (5, 12), (11, 14)):
            px[x % 16, y % 16] = (*FOAM, 255)
        # sparkle
        px[(4 + i * 3) % 16, (6 + i) % 14] = (*SPARK, 255)
        px[(10 + i * 2) % 16, (11 + i) % 14] = (*SPARK, 255)
        save(f"tile_water{i}.png", im)


def build_shallow() -> None:
    for i in range(4):
        im = Image.new("RGBA", (16, 16), (*SHALLOW, 255))
        px = im.load()
        for y in range(16):
            for x in range(16):
                if (x + y * 2 + i) % 6 == 0:
                    px[x, y] = (*SHALLOW_L, 255)
                if y > 10 and (x + i) % 4 == 0:
                    px[x, y] = (*PEBBLE, 255)
                if y > 12 and (x + i * 2) % 5 == 2:
                    px[x, y] = (*PEBBLE_L, 255)
        # soft surface shimmer
        yy = 4 + i % 3
        for x in range(1, 15):
            if (x + i) % 3:
                px[x, yy] = (*FOAM, 255)
        px[3 + i, 7] = (*SPARK, 255)
        save(f"tile_shallow{i}.png", im)


def put(px, x: int, y: int, rgba) -> None:
    if 0 <= x < 16 and 0 <= y < 16:
        px[x, y] = rgba


def shore_edge(kind: str) -> Image.Image:
    """Organic jagged shore overlays (transparent elsewhere)."""
    im = blank()
    px = im.load()
    # irregular thickness profile
    jag = [2, 3, 2, 4, 3, 2, 3, 2, 4, 3, 2, 3, 2, 4, 3, 2]

    def paint_strip(axis: str, outward: int) -> None:
        # outward: +1 means growing toward high index
        for i in range(16):
            w = jag[i]
            for k in range(w):
                if axis == "x":  # vertical edge on E/W
                    x = 15 - k if outward > 0 else k
                    y = i
                else:
                    x = i
                    y = 15 - k if outward > 0 else k
                # outer wet sand / dark lip nearest water
                if k == 0:
                    put(px, x, y, (*SAND_D, 235))
                elif k == 1:
                    put(px, x, y, (*SAND, 230))
                elif k == w - 1:
                    put(px, x, y, (*GRASS_LIP, 220))
                else:
                    put(px, x, y, (*WET, 220))
            # occasional pebble / grass tuft on lip
            if i % 4 == 1:
                if axis == "x":
                    put(px, 15 - (w - 1) if outward > 0 else (w - 1), i, (*PEBBLE_L, 255))
                else:
                    put(px, i, 15 - (w - 1) if outward > 0 else (w - 1), (*GRASS_D, 255))
            if i % 5 == 3:
                if axis == "x":
                    put(px, 15 if outward > 0 else 0, i, (*FOAM, 180))
                else:
                    put(px, i, 15 if outward > 0 else 0, (*FOAM, 180))

    if kind == "E":
        paint_strip("x", +1)
    elif kind == "W":
        paint_strip("x", -1)
    elif kind == "N":
        paint_strip("y", -1)
    elif kind == "S":
        paint_strip("y", +1)
    elif kind == "NE":
        for i in range(10):
            put(px, 15 - i // 2, i, (*SAND, 230))
            put(px, 15, i, (*SAND_D, 230))
            if i < 6:
                put(px, 15 - i // 2 - 1, i, (*GRASS_LIP, 200))
        put(px, 14, 2, (*FOAM, 180))
    elif kind == "NW":
        for i in range(10):
            put(px, i // 2, i, (*SAND, 230))
            put(px, 0, i, (*SAND_D, 230))
            if i < 6:
                put(px, i // 2 + 1, i, (*GRASS_LIP, 200))
        put(px, 1, 2, (*FOAM, 180))
    elif kind == "SE":
        for i in range(10):
            put(px, 15 - i // 2, 15 - i, (*SAND, 230))
            put(px, 15, 15 - i, (*SAND_D, 230))
            if i < 6:
                put(px, 15 - i // 2 - 1, 15 - i, (*GRASS_LIP, 200))
        put(px, 14, 13, (*FOAM, 180))
    elif kind == "SW":
        for i in range(10):
            put(px, i // 2, 15 - i, (*SAND, 230))
            put(px, 0, 15 - i, (*SAND_D, 230))
            if i < 6:
                put(px, i // 2 + 1, 15 - i, (*GRASS_LIP, 200))
        put(px, 1, 13, (*FOAM, 180))
    return im


def build_shores() -> None:
    for k in ("E", "W", "N", "S", "NE", "NW", "SE", "SW"):
        save(f"shore_{k}.png", shore_edge(k))


def improve_reed() -> None:
    """Slightly richer reed clump for creek edge."""
    im = blank()
    # taller than 16? prop_reed may be taller - check
    im = Image.new("RGBA", (12, 20), (0, 0, 0, 0))
    px = im.load()
    stem = (48, 110, 36, 255)
    tip = (90, 160, 50, 255)
    for x, h in ((2, 16), (5, 19), (8, 15), (10, 17)):
        for y in range(20 - h, 20):
            px[x, y] = stem
            if y < 20 - h + 3:
                px[x, y] = tip
            if y == 20 - h:
                px[min(11, x + 1), y] = tip
    save("prop_reed.png", im)


def main() -> int:
    print("build creek tiles")
    build_water()
    build_shallow()
    build_shores()
    improve_reed()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
