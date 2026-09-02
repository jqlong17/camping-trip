#!/usr/bin/env python3
"""Build a precomposed static camp ground+props layer for 3DS runtime.

Bakes grass/water/shore/decals AND trees/bushes/stones/nests so the console
only redraws tent, firepit, player, fruit dots, and cheap creek sparkles.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
from asset_layout import FOREST_CAMP, FOREST_WORLD, SHARED, ASSETS

OUT = FOREST_CAMP / "camp_static_base.png"
DISTANT_OUT = FOREST_CAMP / "forest_distant_canopy.png"
DISTANT_SOURCE = ROOT / "docs" / "promo" / "forest_distant_canopy_v2_gen_ref.png"
TOP_W, TOP_H, TILE = 400, 240, 16
PALETTE = 48

ASSET_PROVENANCE = [
    {
        "outputs": ["game/assets/scenes/forest/camp/camp_static_base.png"],
        "sources": [
            "game/assets/scenes/forest/camp/tile_water0.png",
            "game/assets/scenes/forest/camp/tile_water1.png",
            "game/assets/scenes/forest/camp/tile_water2.png",
            "game/assets/scenes/forest/camp/tile_water3.png",
            "game/assets/scenes/forest/camp/tile_shallow0.png",
            "game/assets/scenes/forest/camp/tile_shallow1.png",
            "game/assets/scenes/forest/camp/tile_shallow2.png",
            "game/assets/scenes/forest/camp/tile_shallow3.png",
            "game/assets/scenes/forest/camp/shore_E.png",
            "game/assets/scenes/forest/camp/shore_W.png",
            "game/assets/scenes/forest/camp/shore_N.png",
            "game/assets/scenes/forest/camp/shore_S.png",
            "game/assets/scenes/forest/camp/shore_NE.png",
            "game/assets/scenes/forest/camp/shore_NW.png",
            "game/assets/scenes/forest/camp/shore_SE.png",
            "game/assets/scenes/forest/camp/shore_SW.png",
        ],
        "operation": "SCN-003 static 25x15 scene composition + 48-color hard-pixel bake",
    },
    {
        "outputs": [
            "game/assets/scenes/forest/camp/forest_distant_canopy.png",
            "game/assets/scenes/forest/camp/camp_static_base.png",
        ],
        "sources": ["docs/promo/forest_distant_canopy_v2_gen_ref.png"],
        "operation": "distant_forest_crop + nearest_resize + scene_composite",
    },
]


def open_rgba(name: str) -> Image.Image:
    for base in (FOREST_CAMP, FOREST_WORLD, SHARED, ASSETS):
        path = base / name
        if path.is_file():
            return Image.open(path).convert("RGBA")
    raise FileNotFoundError(name)


def paste(dst: Image.Image, src: Image.Image | None, x: int, y: int) -> None:
    if src is None:
        return
    dst.alpha_composite(src, (int(x), int(y)))


def quantize_rgba(im: Image.Image, colors: int) -> Image.Image:
    rgba = im.convert("RGBA")
    # Only quantize the logical 400×240 playfield; keep pot padding solid.
    play = rgba.crop((0, 0, TOP_W, TOP_H))
    alpha = play.split()[-1]
    rgb = play.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    locked = rgb.convert("RGBA")
    locked.putalpha(alpha)
    out = Image.new("RGBA", rgba.size, (38, 46, 36, 255))
    out.paste(locked, (0, 0))
    return out


def creek_center_x(y: int) -> int:
    import math

    wiggle = math.floor(1.4 * math.sin(y * 0.35) + 0.9 * math.sin(y * 0.72 + 0.8))
    return 17 + wiggle


def is_water(t: int) -> bool:
    return t in (2, 8)


def is_deep_water(t: int) -> bool:
    return t == 2


def is_open_ground(t: int) -> bool:
    return t in (0, 1, 7)


def build_map() -> tuple[dict[int, dict[int, int]], list[dict[str, int | str]]]:
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
            elif abs(dx) == 3 and (x + y) % 3 != 0:
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

    # Keep this declarative placement list byte-for-byte equivalent to CampMap.build.
    # Story Atlas executes build_map() to materialize stable scene placement instances.
    trees = [
        (1, 1, 0), (2, 0, 8), (4, 1, 1), (6, 0, 9), (0, 3, 4), (3, 4, 10),
        (7, 2, 6), (9, 0, 11), (1, 6, 2), (2, 8, 0), (4, 7, 3), (0, 10, 8),
        (3, 11, 5), (5, 13, 9), (7, 13, 6), (10, 1, 1), (16, 0, 7),
        (18, 0, 10), (19, 2, 2), (21, 1, 3), (22, 3, 11), (23, 0, 4),
        (20, 5, 6), (22, 6, 0), (23, 8, 7), (23, 10, 8), (21, 12, 2),
        (23, 13, 5), (6, 5, 9), (8, 3, 2), (2, 12, 10), (0, 7, 1),
        (14, 2, 11), (15, 12, 8),
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

    camp_map[10][11] = 7
    camp_map[10][12] = 7

    for x, y, v in [(creek_center_x(6), 6, 0), (creek_center_x(7) + 1, 7, 1), (creek_center_x(8), 8, 2)]:
        if is_water(camp_map[y][x]):
            decals.append({"x": x, "y": y, "kind": "step", "v": v})
    y, x = 13, creek_center_x(13)
    decals.append({"x": x, "y": y, "kind": "pier", "v": 0})

    # The top five rows are a visual distance layer, not traversable ground.
    # Keep runtime and Story Atlas coordinates explicit instead of hiding live
    # collision tiles underneath the generated forest wall.
    for y in range(5):
        for x in range(cols):
            camp_map[y][x] = 10
    decals = [decal for decal in decals if int(decal["y"]) >= 5]
    return camp_map, decals


def main() -> int:
    camp_map, decals = build_map()
    distant_source = Image.open(DISTANT_SOURCE).convert("RGBA")
    # The generator intentionally left white framing around the authored
    # forest. Crop only the continuous sky/canopy/meadow band, then reduce it
    # as one image so tree heights and overlaps remain coherent.
    distant = distant_source.crop((0, 220, distant_source.width, 724))
    distant = distant.resize((TOP_W, 80), Image.Resampling.NEAREST)
    distant = quantize_rgba(distant, PALETTE).crop((0, 0, TOP_W, 80))
    DISTANT_OUT.parent.mkdir(parents=True, exist_ok=True)
    distant.save(DISTANT_OUT)

    grass = [open_rgba(f"tile_grass{i}.png") for i in range(8)]
    dirt = [open_rgba(f"tile_dirt{i}.png") for i in range(4)]
    water = [open_rgba(f"tile_water{i}.png") for i in range(4)]
    shallow = [open_rgba(f"tile_shallow{i}.png") for i in range(4)]
    shore = {k: open_rgba(f"shore_{k}.png") for k in ["E", "W", "N", "S", "SE", "NE", "NW", "SW"]}
    fringe = {k: open_rgba(f"dirt_fringe_{k}.png") for k in ["N", "S", "E", "W"]}
    flowers = [open_rgba(f"prop_flower{i}.png") for i in range(4)]
    stones = [open_rgba(f"tile_stone{i}.png") for i in range(3)]
    bushes = [open_rgba(f"tile_bush{i}.png") for i in range(3)]
    trees = [open_rgba(f"tile_tree{i}.png") for i in range(12)]
    reed = open_rgba("prop_reed.png")
    log = open_rgba("prop_log.png")
    stump = open_rgba("prop_stump.png")
    shadow_sm = open_rgba("prop_shadow_sm.png")
    shadow_tree = open_rgba("prop_shadow_tree.png")
    nest = open_rgba("nest.png")
    pier = open_rgba("prop_pier.png")
    out = Image.new("RGBA", (512, 256), (38, 46, 36, 255))

    def tile_at(tx: int, ty: int) -> int | None:
        return camp_map.get(ty, {}).get(tx)

    def paste_land_shore(px: int, py: int, adjacent: dict[str, bool]) -> None:
        """Choose canonical 8-way land overlays; never carpet the water tile."""
        covered: set[str] = set()
        for corner, first, second in (
            ("NE", "N", "E"), ("NW", "N", "W"),
            ("SE", "S", "E"), ("SW", "S", "W"),
        ):
            if adjacent[first] and adjacent[second]:
                paste(out, shore[corner], px, py)
                covered.update((first, second))
        for direction in ("N", "S", "E", "W"):
            if adjacent[direction] and direction not in covered:
                paste(out, shore[direction], px, py)

    nest_keys = {(int(d["x"]), int(d["y"])) for d in decals if d["kind"] == "nest"}

    for y in range(TOP_H // TILE):
        for x in range(TOP_W // TILE):
            t = camp_map[y][x]
            px, py = x * TILE, y * TILE
            if t in (2, 8):
                variant = (x * 5 + y * 3) % 4
                paste(out, shallow[variant] if t == 8 else water[variant], px, py)
            elif t == 7 or t == 5:
                # Tent starts as dirt pad in the baked layer; runtime draws the tent sprite.
                paste(out, dirt[(x * 3 + y * 5) % 4], px, py)
                n, s = tile_at(x, y - 1), tile_at(x, y + 1)
                e, w = tile_at(x + 1, y), tile_at(x - 1, y)
                if n in (0, 1):
                    paste(out, fringe["N"], px, py)
                if s in (0, 1):
                    paste(out, fringe["S"], px, py)
                if e in (0, 1):
                    paste(out, fringe["E"], px, py)
                if w in (0, 1):
                    paste(out, fringe["W"], px, py)
                paste_land_shore(px, py, {
                    "E": is_water(tile_at(x + 1, y)),
                    "W": is_water(tile_at(x - 1, y)),
                    "N": is_water(tile_at(x, y - 1)),
                    "S": is_water(tile_at(x, y + 1)),
                })
            else:
                paste(out, grass[(x * 17 + y * 31) % 8], px, py)
                paste_land_shore(px, py, {
                    "E": is_water(tile_at(x + 1, y)),
                    "W": is_water(tile_at(x - 1, y)),
                    "N": is_water(tile_at(x, y - 1)),
                    "S": is_water(tile_at(x, y + 1)),
                })

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
            elif kind == "tree":
                tree = trees[v % 12]
                paste(out, shadow_tree, px + TILE // 2 - shadow_tree.width // 2 + 5, py + TILE - shadow_tree.height + 3)
                paste(out, tree, px + (TILE - tree.width) // 2, py + TILE - tree.height)
                if (int(d["x"]), int(d["y"])) in nest_keys:
                    paste(out, nest, px + (TILE - nest.width) // 2 + 2, py - 4)
            elif kind == "bush":
                bush = bushes[v % 3]
                paste(out, shadow_sm, px + TILE // 2 - shadow_sm.width // 2 + 3, py + TILE - shadow_sm.height + 2)
                paste(out, bush, px + (TILE - bush.width) // 2, py + TILE - bush.height)
            elif kind == "stone":
                stone = stones[v % 3]
                paste(out, shadow_sm, px + TILE // 2 - shadow_sm.width // 2 + 3, py + TILE - shadow_sm.height + 2)
                paste(out, stone, px, py + TILE - stone.height)

    paste(out, distant, 0, 0)
    out = quantize_rgba(out, PALETTE)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT)
    play = out.crop((0, 0, TOP_W, TOP_H))
    unique = len({c[:3] for c in play.getdata() if c[3] > 16})
    print(f"camp static base: {OUT} {out.size} palette={PALETTE} unique={unique}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
