#!/usr/bin/env python3
"""Lock runtime art to 16-bit pixel style: limited palette, hard edges, no paint."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets"
GEN = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets/title_top_pixel.png")

G0 = (64, 128, 36)
G1 = (78, 148, 42)
G2 = (50, 108, 28)
G3 = (96, 168, 52)
DIRT = (166, 124, 62)
DIRT_D = (128, 92, 44)
WOOD = (156, 108, 52)
WOOD_D = (96, 64, 28)
TAN = (214, 184, 120)
TAN_D = (168, 132, 72)
STONE = (128, 128, 132)
STONE_D = (86, 86, 92)
FLAME = (236, 148, 48)
FLAME_H = (246, 220, 90)
INK = (28, 22, 16, 255)


def save(rel: str, im: Image.Image) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {rel} {im.size}")


def quantize_rgba(im: Image.Image, colors: int) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.split()[-1]
    rgb = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def lock_size(im: Image.Image, w: int, h: int, colors: int) -> Image.Image:
    src = im.convert("RGBA")
    if src.size != (w, h):
        src = src.resize((w, h), Image.Resampling.NEAREST)
    return quantize_rgba(src, colors)


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(im: Image.Image, pts) -> None:
    px = im.load()
    for x, y, c in pts:
        if 0 <= x < im.width and 0 <= y < im.height:
            if len(c) == 3:
                c = (*c, 255)
            px[x, y] = c


def rebuild_grass() -> None:
    flowers = [(244, 240, 220), (236, 200, 64), (232, 96, 120)]
    for i in range(8):
        im = Image.new("RGB", (16, 16), G1)
        px = im.load()
        for y in range(16):
            for x in range(16):
                if (x + y * 3 + i) % 7 == 0:
                    px[x, y] = G0
                elif (x * 2 + y + i) % 11 == 0:
                    px[x, y] = G3
                elif (x + i) % 5 == 2 and y % 4 == 1:
                    px[x, y] = G2
        ax, ay = 3 + (i % 4), 4 + (i % 3)
        px[ax % 16, ay % 16] = G2
        px[ax % 16, (ay - 1) % 16] = G3
        if i % 2 == 0:
            fx, fy = 9 + i % 3, 8
            px[fx % 16, fy] = flowers[i % 3]
        save(f"tile_grass{i}.png", im.convert("RGBA"))


def rebuild_flowers() -> None:
    pals = [
        ((236, 200, 64), (214, 160, 40)),
        ((232, 96, 120), (196, 56, 88)),
        ((244, 244, 236), (220, 210, 180)),
        ((120, 196, 220), (70, 140, 180)),
    ]
    stem, leaf = (48, 110, 36), (70, 148, 48)
    for i, (c0, c1) in enumerate(pals):
        im = blank(12, 12)
        put(im, [
            (5, 10, stem), (6, 10, stem), (6, 9, stem), (6, 8, stem),
            (4, 8, leaf), (3, 8, leaf), (8, 8, leaf), (9, 7, leaf),
            (5, 5, c1), (6, 5, c0), (7, 5, c1),
            (5, 4, c0), (6, 4, c0), (7, 4, c0),
            (6, 3, c1), (6, 6, c1),
        ])
        if i == 1:
            put(im, [(4, 4, c0), (8, 4, c0)])
        save(f"prop_flower{i}.png", im)


def rebuild_firepit() -> None:
    im = blank(24, 16)
    for x, y in (
        (6, 11), (8, 12), (11, 13), (14, 12), (17, 11),
        (5, 9), (18, 9), (7, 8), (16, 8),
    ):
        put(im, [(x, y, STONE_D), (x + 1, y, STONE), (x, y + 1, STONE), (x + 1, y + 1, STONE_D)])
    put(im, [
        (11, 8, FLAME), (12, 8, FLAME_H), (13, 8, FLAME),
        (11, 7, FLAME), (12, 6, FLAME_H), (13, 7, FLAME),
        (12, 5, FLAME_H), (10, 9, WOOD_D), (14, 9, WOOD),
    ])
    save("prop_firepit.png", im)


def rebuild_brew_kit() -> None:
    im = blank(24, 16)
    # carafe
    put(im, [
        (8, 10, (70, 78, 88)), (9, 10, (90, 100, 110)), (10, 10, (70, 78, 88)),
        (8, 11, (48, 36, 28)), (9, 11, (70, 48, 32)), (10, 11, (48, 36, 28)),
        (8, 12, (70, 78, 88)), (9, 12, (90, 100, 110)), (10, 12, (70, 78, 88)),
    ])
    # V60
    put(im, [
        (7, 7, (230, 228, 220)), (8, 7, (230, 228, 220)), (9, 7, (230, 228, 220)), (10, 7, (230, 228, 220)), (11, 7, (230, 228, 220)),
        (8, 6, (210, 200, 170)), (9, 6, (196, 160, 90)), (10, 6, (210, 200, 170)),
        (9, 5, (230, 228, 220)),
    ])
    # kettle
    put(im, [
        (15, 9, (40, 40, 48)), (16, 9, (56, 56, 64)), (17, 9, (40, 40, 48)),
        (15, 10, (32, 32, 38)), (16, 10, (48, 48, 56)), (17, 10, (32, 32, 38)),
        (18, 9, (90, 70, 40)), (14, 8, (40, 40, 48)),
    ])
    save("world/brew_kit.png", im)


def icon_canvas(draw_fn) -> Image.Image:
    im = blank(32, 32)
    draw_fn(im)
    canvas = blank(48, 40)
    canvas.paste(im, (8, 4), im)
    return canvas


def rebuild_gear() -> None:
    def tent(im):
        d = ImageDraw.Draw(im)
        d.polygon([(16, 4), (6, 26), (26, 26)], fill=TAN)
        d.polygon([(16, 4), (6, 26), (16, 26)], fill=TAN_D)
        d.polygon([(16, 14), (12, 26), (20, 26)], fill=(40, 28, 18))
        d.point((7, 27), fill=WOOD_D)
        d.point((25, 27), fill=WOOD_D)

    def drip(im):
        d = ImageDraw.Draw(im)
        d.rectangle((11, 20, 21, 28), fill=(70, 78, 88), outline=INK)
        d.rectangle((12, 22, 20, 27), fill=(48, 32, 22))
        d.polygon([(10, 14), (22, 14), (19, 20), (13, 20)], fill=(236, 234, 226), outline=INK)
        d.rectangle((13, 12, 19, 14), fill=(214, 180, 90))
        d.rectangle((22, 10, 28, 16), fill=(40, 40, 48), outline=INK)
        d.line((28, 12, 30, 8), fill=(90, 70, 40), width=1)

    def pot(im):
        d = ImageDraw.Draw(im)
        d.ellipse((8, 10, 24, 26), fill=(56, 56, 62), outline=INK)
        d.rectangle((6, 16, 8, 20), fill=STONE)
        d.rectangle((24, 16, 26, 20), fill=STONE)
        d.ellipse((13, 8, 19, 13), fill=(40, 40, 46), outline=INK)
        d.arc((10, 14, 22, 24), 20, 160, fill=(160, 160, 168))

    def rod(im):
        d = ImageDraw.Draw(im)
        d.rectangle((6, 22, 12, 28), fill=WOOD)
        d.ellipse((10, 20, 16, 26), fill=STONE_D)
        d.line((15, 21, 26, 6), fill=TAN, width=1)
        d.line((26, 6, 26, 20), fill=(230, 230, 230))
        d.point((26, 21), fill=(220, 48, 48))
        d.point((26, 22), fill=(220, 48, 48))

    def cup(im):
        d = ImageDraw.Draw(im)
        d.rectangle((10, 12, 22, 26), fill=(236, 234, 226), outline=INK)
        d.rectangle((10, 17, 22, 20), fill=WOOD)
        d.arc((21, 16, 26, 23), 270, 90, fill=INK)
        d.point((13, 8), fill=STONE)
        d.point((16, 7), fill=STONE)
        d.point((19, 8), fill=STONE)

    def fan(im):
        d = ImageDraw.Draw(im)
        d.pieslice((6, 6, 26, 26), 200, 340, fill=(196, 48, 56), outline=INK)
        for a in (220, 250, 280, 310):
            d.pieslice((6, 6, 26, 26), a, a + 4, fill=(236, 190, 190))
        d.rectangle((14, 22, 18, 28), fill=WOOD)

    mapping = {
        "gear_tent.png": tent,
        "gear_drip.png": drip,
        "gear_pot.png": pot,
        "gear_rod.png": rod,
        "gear_cup.png": cup,
        "gear_fan.png": fan,
    }
    for name, fn in mapping.items():
        save(name, icon_canvas(fn))


def lock_fullscreen() -> None:
    jobs = [
        ("title_bot.png", 320, 240, 36),
        ("ui_pack_bg.png", 320, 240, 22),
        ("story/p1.png", 400, 240, 48),
        ("story/p2.png", 400, 240, 48),
        ("story/p3.png", 400, 240, 48),
        ("story/d1.png", 400, 240, 48),
        ("story/d2.png", 400, 240, 48),
        ("story/h1.png", 400, 240, 48),
    ]
    for rel, w, h, colors in jobs:
        src = OUT / rel
        if not src.exists():
            continue
        save(rel, lock_size(Image.open(src), w, h, colors))


def rebuild_title() -> None:
    paint = OUT / "title_top.png"
    bak = OUT / "title_top_paint.png"
    if paint.exists() and not bak.exists():
        shutil.copy2(paint, bak)
    if GEN.exists():
        im = Image.open(GEN).convert("RGBA")
        # 200x120 then 2x nearest = true 16-bit pixels on 400x240
        mid = im.resize((200, 120), Image.Resampling.BOX)
        mid = quantize_rgba(mid, 32)
        out = mid.resize((400, 240), Image.Resampling.NEAREST)
        save("title_top.png", out)
    else:
        print("  skip title: generated source missing")


def main() -> None:
    print("title")
    rebuild_title()
    print("grass")
    rebuild_grass()
    print("flowers")
    rebuild_flowers()
    print("firepit / brew")
    rebuild_firepit()
    rebuild_brew_kit()
    print("gear")
    rebuild_gear()
    print("lock fullscreen palettes")
    lock_fullscreen()
    print("done")


if __name__ == "__main__":
    main()
