#!/usr/bin/env python3
"""Slice mockup-style sheets into 3DS camp tiles. Readable pixels, unified grass."""
from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

SRC = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")
OUT = Path("/Users/ruska/projects/3ds/linjian/game/assets")
BAK = OUT / "_tiles_v1"
PROMO = Path("/Users/ruska/projects/3ds/linjian/docs/promo")

GRASS_TARGET = np.array([72, 138, 38], dtype=np.float32)
WATER_DEEP = (32, 108, 176)
WATER_MID = (48, 148, 208)
WATER_LIGHT = (118, 198, 228)
WATER_SPARK = (230, 246, 255)
SHORE_DIRT = (168, 126, 62)
SHORE_DARK = (112, 78, 36)
SHORE_LIP = (86, 148, 46)


def save(name: str, im: Image.Image) -> None:
    path = OUT / name
    im.save(path)
    print(f"  {name} {im.size}")


def posterize(im: Image.Image, colors: int = 28) -> Image.Image:
    rgba = im.convert("RGBA")
    rgb = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(rgba.split()[-1])
    return out


def pixel_fit(im: Image.Image, max_w: int, max_h: int) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    scale = min(max_w / w, max_h / h, 1.0) if w * h > max_w * max_h else min(max_w / w, max_h / h)
    tw, th = max(8, int(round(w * scale))), max(8, int(round(h * scale)))
    mid = im.resize((tw * 2, th * 2), Image.Resampling.BOX)
    mid = posterize(mid, 32)
    return mid.resize((tw, th), Image.Resampling.NEAREST)


def mask_light_bg(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, :, 0].astype(np.int16), rgb[:, :, 1].astype(np.int16), rgb[:, :, 2].astype(np.int16)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    near_white = (mn > 228) | ((mx > 238) & (mx - mn < 18))
    gray_checker = (np.abs(r - g) < 10) & (np.abs(g - b) < 10) & (r > 218)
    return ~(near_white | gray_checker)


def mask_dark_bg(rgb: np.ndarray) -> np.ndarray:
    return rgb.max(axis=2) > 18


def components(mask: np.ndarray, min_area: int = 400) -> list[tuple[int, int, int, int]]:
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    boxes = []
    ys, xs = np.where(mask)
    # flood via simple scan of unlabeled seeds
    from collections import deque

    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        minx = maxx = x0
        miny = maxy = y0
        area = 0
        while q:
            y, x = q.popleft()
            area += 1
            if x < minx:
                minx = x
            if x > maxx:
                maxx = x
            if y < miny:
                miny = y
            if y > maxy:
                maxy = y
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if area >= min_area:
            boxes.append((minx, miny, maxx + 1, maxy + 1, area))
    boxes.sort(key=lambda b: b[0])
    return boxes


def cut_rgba(im: Image.Image, box, mask: np.ndarray, pad: int = 2) -> Image.Image:
    x0, y0, x1, y1 = box[:4]
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    crop = im.crop((x0, y0, x1, y1)).convert("RGBA")
    a = np.array(crop)
    m = mask[y0:y1, x0:x1]
    a[~m, 3] = 0
    return Image.fromarray(a)


def unify_grass(tile: Image.Image) -> Image.Image:
    a = np.array(tile.convert("RGB"), dtype=np.float32)
    mean = a.reshape(-1, 3).mean(axis=0)
    shift = GRASS_TARGET - mean
    # keep tufts/flowers; only pull the average so tiles do not checker
    out = np.clip(a + shift * 0.55, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGB").convert("RGBA")


def stamp_grass_detail(tile: Image.Image, variant: int) -> Image.Image:
    px = tile.load()
    tuft = (48, 102, 28, 255)
    blade = (96, 168, 52, 255)
    flower_w = (244, 240, 220, 255)
    flower_y = (236, 200, 64, 255)
    pebble = (132, 108, 64, 255)
    pebble_h = (176, 150, 96, 255)
    spots = [
        ((3, 5), (9, 11), (12, 4)),
        ((6, 8), (2, 3), (13, 12)),
        ((4, 12), (11, 6), (7, 2)),
        ((10, 9), (1, 7), (14, 3)),
        ((5, 4), (12, 10), (8, 13)),
        ((2, 10), (9, 3), (13, 8)),
        ((7, 7), (3, 13), (14, 5)),
        ((11, 2), (4, 9), (8, 14)),
    ][variant % 8]
    ax, ay = spots[0]
    px[ax, ay] = tuft
    px[ax, ay - 1] = blade
    if variant % 2 == 0:
        fx, fy = spots[1]
        px[fx, fy] = flower_w
        if fy + 1 < 16:
            px[fx, fy + 1] = flower_y
    if variant in (2, 5, 7):
        sx, sy = spots[2]
        px[sx, sy] = pebble
        if sx > 0:
            px[sx - 1, sy] = pebble_h
    return tile


def build_grass() -> None:
    meadow = Image.open(SRC / "camp_grass_meadow.png").convert("RGB")
    w, h = meadow.size
    # eight 96x96 patches — enough source pixels that flowers/tufts survive 16px
    origins = [
        (0.08, 0.28), (0.20, 0.40), (0.34, 0.22), (0.48, 0.36),
        (0.60, 0.24), (0.72, 0.42), (0.18, 0.55), (0.52, 0.58),
    ]
    for i, (fx, fy) in enumerate(origins):
        x, y = int(w * fx), int(h * fy)
        cell = meadow.crop((x, y, x + 96, y + 96))
        tile = cell.resize((16, 16), Image.Resampling.BOX)
        tile = posterize(tile.convert("RGBA"), 22).convert("RGB")
        tile = unify_grass(tile)
        tile = stamp_grass_detail(tile, i)
        save(f"tile_grass{i}.png", tile)


def build_water() -> None:
    # quiet river: same base, only a horizontal ripple + 1 sparkle moves
    ripple_y = (6, 7, 10, 11)
    for i in range(4):
        im = Image.new("RGB", (16, 16), WATER_DEEP)
        px = im.load()
        for y in range(16):
            for x in range(16):
                if y in (3, 12):
                    px[x, y] = WATER_MID
        ry = ripple_y[i]
        for x in range(2, 14):
            if (x + i) % 3 != 0:
                px[x, ry] = WATER_LIGHT
        px[3 + i * 3, 4] = WATER_SPARK
        save(f"tile_water{i}.png", im.convert("RGBA"))

        sh = Image.new("RGB", (16, 16), (78, 168, 172))
        px = sh.load()
        for y in range(16):
            for x in range(16):
                if y > 11:
                    px[x, y] = (148, 128, 74)
                elif (x + y) % 11 == 0:
                    px[x, y] = (110, 186, 186)
        px[4 + i, 12] = (128, 112, 78)
        px[9, 13] = (160, 144, 96)
        save(f"tile_shallow{i}.png", sh.convert("RGBA"))


def build_dirt() -> None:
    base = (166, 124, 62)
    dark = (128, 92, 44)
    light = (196, 158, 92)
    blade = (78, 132, 42)
    for i in range(4):
        im = Image.new("RGB", (16, 16), base)
        px = im.load()
        specks = [(2 + i, 3), (11, 5 + i % 3), (7, 12), (14, 9), (4, 14), (9, 1)]
        for x, y in specks:
            px[x % 16, y % 16] = dark if (x + y + i) % 2 == 0 else light
        # grass blades only on edges so the pad blends into meadow
        if i % 2 == 0:
            px[1, 1] = blade
            px[14, 2] = blade
        else:
            px[2, 14] = blade
            px[13, 13] = blade
        save(f"tile_dirt{i}.png", im.convert("RGBA"))


def build_pier() -> None:
    im = Image.new("RGBA", (28, 12), (0, 0, 0, 0))
    px = im.load()
    plank = (156, 108, 52)
    gap = (96, 64, 28)
    nail = (70, 48, 24)
    for y in range(2, 11):
        for x in range(1, 27):
            px[x, y] = gap if y in (5, 8) else plank
    for x in (4, 13, 22):
        px[x, 3] = nail
        px[x, 9] = nail
    save("prop_pier.png", im)


def paint_water_fallback() -> None:
    rng = np.random.RandomState(11)
    for i in range(4):
        im = Image.new("RGB", (16, 16), WATER_DEEP)
        px = im.load()
        for y in range(16):
            for x in range(16):
                wave = ((x + i * 2 + y // 2) % 7) == 0
                px[x, y] = WATER_LIGHT if wave else (WATER_MID if (x + y + i) % 5 == 0 else WATER_DEEP)
        for _ in range(3):
            px[int(rng.randint(0, 16)), int(rng.randint(0, 16))] = WATER_SPARK
        save(f"tile_water{i}.png", im.convert("RGBA"))
        sh = Image.new("RGB", (16, 16), (70, 168, 176))
        px = sh.load()
        for y in range(16):
            for x in range(16):
                if (x + y + i) % 6 == 0:
                    px[x, y] = (150, 190, 150)
                if (x + i * 3) % 8 == 2 and y > 9:
                    px[x, y] = (150, 120, 80)
        save(f"tile_shallow{i}.png", sh.convert("RGBA"))


def paint_shores() -> None:
    def shore(kind: str) -> Image.Image:
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        px = im.load()

        def dirt(x, y, lip=False):
            if 0 <= x < 16 and 0 <= y < 16:
                px[x, y] = (*SHORE_LIP, 230) if lip else (*SHORE_DIRT, 220)

        jag = [1, 2, 1, 3, 2, 1, 2, 1, 3, 1, 2, 1, 2, 3, 1, 2]
        if kind == "E":
            for y in range(16):
                w = 3 + jag[y] % 2
                for k in range(w):
                    dirt(15 - k, y, k == w - 1)
                    if k == 0:
                        px[15, y] = (*SHORE_DARK, 210)
        elif kind == "W":
            for y in range(16):
                w = 3 + jag[15 - y] % 2
                for k in range(w):
                    dirt(k, y, k == w - 1)
                    if k == 0:
                        px[0, y] = (*SHORE_DARK, 210)
        elif kind == "N":
            for x in range(16):
                w = 3 + jag[x] % 2
                for k in range(w):
                    dirt(x, k, k == w - 1)
        elif kind == "S":
            for x in range(16):
                w = 3 + (jag[x] + 1) % 2
                for k in range(w):
                    dirt(x, 15 - k, k == w - 1)
        elif kind == "NE":
            for i in range(8):
                dirt(15 - i // 2, i, True)
                dirt(15, i)
        elif kind == "NW":
            for i in range(8):
                dirt(i // 2, i, True)
                dirt(0, i)
        elif kind == "SE":
            for i in range(8):
                dirt(15 - i // 2, 15 - i, True)
                dirt(15, 15 - i)
        elif kind == "SW":
            for i in range(8):
                dirt(i // 2, 15 - i, True)
                dirt(0, 15 - i)
        return im

    for k in ("E", "W", "N", "S", "NE", "NW", "SE", "SW"):
        save(f"shore_{k}.png", shore(k))


def extract_row(path: Path, light_bg: bool, min_area: int) -> list[Image.Image]:
    im = Image.open(path).convert("RGB")
    rgb = np.array(im)
    mask = mask_light_bg(rgb) if light_bg else mask_dark_bg(rgb)
    boxes = components(mask, min_area=min_area)
    sprites = [cut_rgba(im, b, mask) for b in boxes]
    print(f"  extracted {len(sprites)} from {path.name}")
    return sprites


def trim(im: Image.Image) -> Image.Image:
    a = np.array(im)
    vis = a[:, :, 3] > 20
    if not vis.any():
        return im
    ys, xs = np.where(vis)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def build_trees() -> None:
    sprites = extract_row(SRC / "camp_trees_sheet.png", True, 1800)
    sprites = [trim(s) for s in sprites if s.size[0] * s.size[1] > 80 * 80][:8]
    sizes = [(26, 36), (24, 34), (22, 38), (28, 34), (24, 36), (20, 38), (18, 36), (22, 34)]
    for i, spr in enumerate(sprites[:8]):
        tw, th = sizes[i % 8]
        save(f"tile_tree{i}.png", pixel_fit(spr, tw, th))


def build_props() -> None:
    # x-sorted sprites on camp_props_sheet (see index dump in DEV notes)
    sprites = [trim(s) for s in extract_row(SRC / "camp_props_sheet.png", True, 350)]
    idx = {
        "tent": 0, "tent_open": 3, "roll": 8, "fire": 13, "stump": 16,
        "stone0": 4, "stone1": 7, "stone2": 11,
        "bush0": 1, "bush1": 2, "bush2": 5,
        "flower0": 6, "flower1": 9, "flower2": 10, "flower3": 12,
        "log": 14, "reed": 17,
    }
    save("tile_tent.png", pixel_fit(sprites[idx["tent"]], 38, 30))
    save("tile_tent_open.png", pixel_fit(sprites[idx["tent_open"]], 38, 30))
    save("tile_tent_packed.png", pixel_fit(sprites[idx["roll"]], 22, 16))
    save("prop_firepit.png", pixel_fit(sprites[idx["fire"]], 24, 20))
    save("prop_stump.png", pixel_fit(sprites[idx["stump"]], 18, 16))
    for i, key in enumerate(("bush0", "bush1", "bush2")):
        save(f"tile_bush{i}.png", pixel_fit(sprites[idx[key]], 20, 16))
    for i, key in enumerate(("stone0", "stone1", "stone2")):
        save(f"tile_stone{i}.png", pixel_fit(sprites[idx[key]], 16, 12))
    for i, key in enumerate(("flower0", "flower1", "flower2", "flower3")):
        save(f"prop_flower{i}.png", pixel_fit(sprites[idx[key]], 12, 12))
    save("prop_log.png", pixel_fit(sprites[idx["log"]], 20, 10))
    save("prop_reed.png", pixel_fit(sprites[idx["reed"]], 14, 16))


def build_shadows() -> None:
    def oval(w, h, a0=150):
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = im.load()
        cx, cy = (w - 1) / 2, (h - 1) / 2
        for y in range(h):
            for x in range(w):
                u = (x - cx) / max(0.5, cx)
                v = (y - cy) / max(0.5, cy)
                d = u * u + v * v
                if d <= 1.05:
                    alpha = int(a0 * max(0, 1 - d * 0.85))
                    px[x, y] = (18, 24, 10, alpha)
        return im

    save("prop_shadow.png", oval(26, 9, 170))
    save("prop_shadow_sm.png", oval(16, 6, 140))
    save("prop_shadow_tree.png", oval(32, 11, 185))


def build_pack_ui() -> None:
    src = SRC / "pack_ui_frame.png"
    if not src.exists():
        return
    im = Image.open(src).convert("RGB")
    # cover 320x240 then light posterize so it stays pixel-readable
    tw, th = 320, 240
    sw, sh = im.size
    scale = max(tw / sw, th / sh)
    mid = im.resize((int(sw * scale), int(sh * scale)), Image.Resampling.BOX)
    x0 = max(0, (mid.width - tw) // 2)
    y0 = max(0, (mid.height - th) // 2)
    crop = mid.crop((x0, y0, x0 + tw, y0 + th))
    crop = posterize(crop.convert("RGBA"), 40).convert("RGB")
    save("ui_pack_bg.png", crop.convert("RGBA"))


def main() -> None:
    BAK.mkdir(exist_ok=True)
    PROMO.mkdir(parents=True, exist_ok=True)
    for name in (
        "tile_grass0.png",
        "tile_tree0.png",
        "tile_tent.png",
        "prop_firepit.png",
    ):
        src = OUT / name
        if src.exists() and not (BAK / name).exists():
            shutil.copy2(src, BAK / name)
    for src_name in (
        "camp_trees_sheet.png",
        "camp_grass_water_sheet.png",
        "camp_props_sheet.png",
        "camp_grass_meadow.png",
    ):
        shutil.copy2(SRC / src_name, PROMO / src_name)

    print("grass")
    build_grass()
    print("water")
    build_water()
    print("dirt")
    build_dirt()
    print("pier")
    build_pier()
    print("shores")
    paint_shores()
    print("trees")
    build_trees()
    print("props")
    build_props()
    print("shadows")
    build_shadows()
    print("pack ui")
    build_pack_ui()
    print("done")


if __name__ == "__main__":
    main()
