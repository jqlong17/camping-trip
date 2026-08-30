#!/usr/bin/env python3
"""Build a precomposed static camp ground layer for 3DS runtime."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
OUT = ASSETS / "camp_static_base.png"
TOP_W, TOP_H, TILE = 400, 240, 16


def open_rgba(name: str) -> Image.Image:
    return Image.open(ASSETS / name).convert("RGBA")


def paste(dst: Image.Image, src: Image.Image | None, x: int, y: int) -> None:
    if src is None:
        return
    dst.alpha_composite(src, (int(x), int(y)))


def creek_center_x(y: int) -> int:
    import math

    wiggle = math.floor(1.7 * math.sin(y * 0.40) + 0.7 * math.sin(y * 0.88 + 1.0))
    return 17 + wiggle


def is_water(t: int) -> bool:
    return t in (2, 8)


def is_deep_water(t: int) -> bool:
    return t == 2


def is_open_ground(t: int) -> bool:
    return t in (0, 1, 7)


def build_map() -> tuple[dict[int, dict[int, int]], list[dict[str, int | str]]]:
    import math

    cols, rows = TOP_W // TILE, TOP_H // TILE
    camp_map: dict[int, dict[int, int]] = {}
    decals: list[dict[str, int | str]] = []
    tree_tiles: list[dict[str, int]] = []
    for y in range(rows):
        camp_map[y] = {}
        cx = creek_center_x(y)
        for x in range(cols):
            t = 0 if (x * 3 + y * 5) % 2 == 0 else 1
            dx = x - cx
            if abs(dx) <= 1:
                t = 2
            elif abs(dx) == 2:
                t = 8
            camp_map[y][x] = t

    for y in range(8, 13):
        for x in range(8, 14):
            if not is_water(camp_map[y][x]):
                camp_map[y][x] = 7

    for y in range(5, 10):
        cx = creek_center_x(y)
        for x in range(cx - 2, cx + 3):
            if x in camp_map[y]:
                if abs(x - cx) <= 1 or is_deep_water(camp_map[y][x]):
                    camp_map[y][x] = 8

    trees = [
        (1, 1, 0), (2, 0, 2), (4, 1, 1), (6, 0, 3), (0, 3, 4), (3, 4, 5),
        (7, 2, 6), (9, 0, 7), (1, 6, 2), (2, 8, 0), (4, 7, 3), (0, 10, 1),
        (3, 11, 5), (5, 13, 4), (7, 13, 6), (10, 1, 1), (16, 0, 7),
        (18, 0, 0), (19, 2, 2), (21, 1, 3), (22, 3, 5), (23, 0, 4),
        (20, 5, 6), (22, 6, 0), (23, 8, 7), (23, 10, 1), (21, 12, 2),
        (23, 13, 5), (6, 5, 3), (8, 3, 2), (2, 12, 4), (0, 7, 1),
    ]
    for x, y, v in trees:
        if y in camp_map and x in camp_map[y] and not is_water(camp_map[y][x]):
            camp_map[y][x] = 3
            decals.append({"x": x, "y": y, "kind": "tree", "v": v})
            tree_tiles.append({"x": x, "y": y, "v": v})

    for i in range(1, min(4, len(tree_tiles)) + 1):
        t = tree_tiles[(i * 5 + 2) % len(tree_tiles)]
        decals.append({"x": t["x"], "y": t["y"], "kind": "nest", "v": i % 3})

    for x, y, v in [(5, 3, 0), (8, 6, 1), (13, 5, 2), (17, 6, 0), (11, 11, 1), (4, 9, 2), (19, 10, 0)]:
        if not is_water(camp_map[y][x]) and camp_map[y][x] != 3:
            camp_map[y][x] = 6
            decals.append({"x": x, "y": y, "kind": "bush", "v": v})

    for x, y, v in [(8, 7, 0), (14, 6, 1), (6, 12, 2), (12, 4, 0), (20, 5, 1)]:
        if not is_water(camp_map[y][x]) and camp_map[y][x] < 3:
            camp_map[y][x] = 4
            decals.append({"x": x, "y": y, "kind": "stone", "v": v})

    for x, y, kind, v in [
        (5, 5, "flower", 0), (7, 4, "flower", 1), (10, 7, "flower", 2),
        (13, 9, "flower", 3), (15, 6, "flower", 1), (3, 7, "flower", 0),
        (9, 11, "flower", 2), (18, 4, "flower", 3), (16, 7, "reed", 0),
        (19, 8, "reed", 0), (17, 11, "reed", 0), (21, 6, "reed", 0),
        (11, 8, "log", 0), (4, 11, "log", 0), (12, 9, "stump", 0),
        (6, 8, "flower", 0), (9, 7, "flower", 1), (14, 8, "flower", 2),
        (8, 11, "flower", 3), (10, 12, "flower", 1), (7, 10, "flower", 0),
    ]:
        if is_open_ground(camp_map[y][x]) or is_water(camp_map[y][x]):
            if not (kind == "reed" and not is_water(camp_map[y][x])):
                decals.append({"x": x, "y": y, "kind": kind, "v": v})
        if kind == "reed":
            decals.append({"x": creek_center_x(y) - 1, "y": y, "kind": "reed", "v": 0})

    camp_map[10][11] = 5
    camp_map[10][12] = 7

    for x, y, v in [(creek_center_x(6), 6, 0), (creek_center_x(7) + 1, 7, 1), (creek_center_x(8), 8, 2)]:
        if is_water(camp_map[y][x]):
            decals.append({"x": x, "y": y, "kind": "step", "v": v})
    y, x = 13, creek_center_x(13)
    decals.append({"x": x, "y": y, "kind": "pier", "v": 0})
    return camp_map, decals


def main() -> int:
    camp_map, decals = build_map()
    grass = [open_rgba(f"tile_grass{i}.png") for i in range(8)]
    dirt = [open_rgba(f"tile_dirt{i}.png") for i in range(4)]
    water = open_rgba("tile_water0.png")
    shallow = open_rgba("tile_shallow0.png")
    shore = {k: open_rgba(f"shore_{k}.png") for k in ["E", "W", "N", "S", "SE", "NE", "NW", "SW"]}
    flowers = [open_rgba(f"prop_flower{i}.png") for i in range(4)]
    stones = [open_rgba(f"tile_stone{i}.png") for i in range(3)]
    reed = open_rgba("prop_reed.png")
    log = open_rgba("prop_log.png")
    stump = open_rgba("prop_stump.png")
    shadow_sm = open_rgba("prop_shadow_sm.png")
    pier = open_rgba("prop_pier.png")
    out = Image.new("RGBA", (512, 256), (38, 46, 36, 255))

    def tile_at(tx: int, ty: int) -> int | None:
        return camp_map.get(ty, {}).get(tx)

    for y in range(TOP_H // TILE):
        for x in range(TOP_W // TILE):
            t = camp_map[y][x]
            px, py = x * TILE, y * TILE
            if t in (2, 8):
                paste(out, shallow if t == 8 else water, px, py)
                if not is_water(tile_at(x + 1, y)): paste(out, shore["E"], px, py)
                if not is_water(tile_at(x - 1, y)): paste(out, shore["W"], px, py)
                if not is_water(tile_at(x, y - 1)): paste(out, shore["N"], px, py)
                if not is_water(tile_at(x, y + 1)): paste(out, shore["S"], px, py)
            elif t == 7:
                paste(out, dirt[(x * 3 + y * 5) % 4], px, py)
            else:
                paste(out, grass[(x * 17 + y * 31) % 8], px, py)
                e, w, n, s = is_water(tile_at(x + 1, y)), is_water(tile_at(x - 1, y)), is_water(tile_at(x, y - 1)), is_water(tile_at(x, y + 1))
                if e: paste(out, shore["E"], px, py)
                if w: paste(out, shore["W"], px, py)
                if n: paste(out, shore["N"], px, py)
                if s: paste(out, shore["S"], px, py)
                if n and e: paste(out, shore["NE"], px, py)
                if n and w: paste(out, shore["NW"], px, py)
                if s and e: paste(out, shore["SE"], px, py)
                if s and w: paste(out, shore["SW"], px, py)

        for d in decals:
            if d["y"] != y:
                continue
            px, py = int(d["x"]) * TILE, int(d["y"]) * TILE
            kind, v = str(d["kind"]), int(d["v"])
            if kind == "flower":
                paste(out, flowers[v % 4], px + 3, py + 4)
            elif kind == "reed":
                paste(out, reed, px + 2, py + TILE - reed.height)
            elif kind == "log":
                paste(out, log, px - 2, py + 6)
            elif kind == "stump":
                paste(out, shadow_sm, px + TILE // 2 - shadow_sm.width // 2 + 3, py + TILE - shadow_sm.height + 2)
                paste(out, stump, px + (TILE - stump.width) // 2, py + TILE - stump.height)
            elif kind == "step":
                paste(out, stones[v % 3], px + 2, py + 6)
            elif kind == "pier":
                paste(out, pier, px + TILE - pier.width + 4, py + 4)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    print(f"camp static base: {OUT} {out.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
