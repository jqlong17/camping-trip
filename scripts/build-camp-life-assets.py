#!/usr/bin/env python3
"""Camp life assets: clearer boy/girl cast, extra trees, cup styles, bird chirp."""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
from asset_layout import ASSETS, CUPS, GEAR, SHARED

CAST = ASSETS / "cast"
AUDIO = ROOT / "game" / "audio"

INK = (28, 22, 16, 255)
SKIN = (236, 192, 150, 255)
SKIN_D = (210, 160, 120, 255)


def quant(im: Image.Image, colors: int = 32) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.split()[-1]
    rgb = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def save(path: Path, im: Image.Image, colors: int = 32) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    quant(im, colors).save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def blank(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


# gender: boy/girl — silhouette must differ at a glance
CAST_DEF = [
    ("boy", "眼镜上班族", dict(hair=(48, 40, 36), shirt=(120, 160, 200), pants=(150, 120, 80), acc="glasses", item="bag")),
    ("girl", "草帽姑娘", dict(hair=(110, 70, 40), shirt=(40, 48, 70), pants=(40, 48, 70), acc="straw", item="basket", dress=True)),
    ("boy", "背心男生", dict(hair=(36, 52, 40), shirt=(240, 240, 235), pants=(40, 70, 90), acc="spike", item=None)),
    ("girl", "绿帽女孩", dict(hair=(90, 60, 40), shirt=(120, 170, 90), pants=(50, 70, 110), acc="cap_g", item="pack", long=True)),
    ("girl", "丸子头", dict(hair=(70, 48, 36), shirt=(220, 120, 130), pants=(90, 70, 110), acc="buns", item=None, dress=True)),
    ("boy", "银发polo", dict(hair=(190, 195, 200), shirt=(80, 130, 160), pants=(70, 70, 80), acc="side", item=None)),
    ("girl", "钓鱼姑娘", dict(hair=(120, 70, 45), shirt=(200, 70, 70), pants=(240, 240, 245), acc="curl", item="rod", long=True)),
    ("boy", "条纹少年", dict(hair=(40, 36, 34), shirt=(70, 90, 120), pants=(50, 55, 70), acc="stripe", item=None)),
    ("girl", "格子衫", dict(hair=(95, 60, 40), shirt=(190, 70, 70), pants=(170, 140, 90), acc="pony", item="lantern", long=True)),
]


def draw_front(cfg: dict, gender: str) -> Image.Image:
    im = blank(40, 40)
    d = ImageDraw.Draw(im)
    hair = (*cfg["hair"], 255)
    shirt = (*cfg["shirt"], 255)
    pants = (*cfg["pants"], 255)
    # head
    d.ellipse((12, 4, 28, 20), fill=SKIN)
    # hair
    acc = cfg.get("acc")
    if gender == "girl" or cfg.get("long"):
        d.rectangle((11, 6, 29, 16), fill=hair)
        d.rectangle((9, 14, 14, 28), fill=hair)
        d.rectangle((26, 14, 31, 28), fill=hair)
    else:
        d.rectangle((12, 4, 28, 12), fill=hair)
    if acc == "glasses":
        d.rectangle((14, 11, 19, 15), outline=INK)
        d.rectangle((21, 11, 26, 15), outline=INK)
        d.line((19, 13, 21, 13), fill=INK)
    elif acc == "straw":
        d.ellipse((8, 2, 32, 12), fill=(210, 180, 90, 255))
        d.rectangle((14, 1, 26, 6), fill=(190, 150, 60, 255))
    elif acc == "cap_g":
        d.rectangle((12, 2, 28, 8), fill=(90, 160, 70, 255))
        d.rectangle((26, 5, 32, 9), fill=(90, 160, 70, 255))
    elif acc == "buns":
        d.ellipse((8, 4, 14, 10), fill=hair)
        d.ellipse((26, 4, 32, 10), fill=hair)
    elif acc == "spike":
        for x in (14, 18, 22, 25):
            d.rectangle((x, 2, x + 2, 8), fill=hair)
    elif acc == "curl":
        d.ellipse((10, 8, 16, 18), fill=hair)
        d.ellipse((24, 8, 30, 18), fill=hair)
    elif acc == "pony":
        d.rectangle((26, 12, 31, 30), fill=hair)
    elif acc == "side":
        d.rectangle((12, 4, 22, 12), fill=hair)
    # eyes
    d.point((16, 12), fill=INK)
    d.point((23, 12), fill=INK)
    # body
    if cfg.get("dress"):
        d.polygon([(14, 18), (26, 18), (30, 34), (10, 34)], fill=shirt)
        if acc == "straw":
            for y in range(22, 34, 3):
                for x in range(12, 28, 4):
                    d.point((x, y), fill=(230, 230, 240, 255))
    else:
        d.rectangle((14, 18, 26, 28), fill=shirt)
        if acc == "stripe":
            for y in (20, 23, 26):
                d.line((14, y, 26, y), fill=(240, 240, 245, 255))
        d.rectangle((14, 28, 26, 36), fill=pants)
    # legs/shoes
    d.rectangle((15, 34, 19, 39), fill=pants)
    d.rectangle((21, 34, 25, 39), fill=pants)
    d.rectangle((14, 38, 19, 40), fill=INK)
    d.rectangle((21, 38, 26, 40), fill=INK)
    # item
    item = cfg.get("item")
    if item == "bag":
        d.rectangle((26, 22, 34, 32), fill=(210, 190, 140, 255))
    elif item == "basket":
        d.rectangle((6, 24, 14, 32), fill=(150, 100, 50, 255))
    elif item == "pack":
        d.rectangle((12, 18, 15, 28), fill=(90, 60, 40, 255))
        d.rectangle((25, 18, 28, 28), fill=(90, 60, 40, 255))
    elif item == "rod":
        d.line((8, 18, 8, 36), fill=(160, 120, 60, 255))
        d.line((8, 18, 12, 10), fill=(230, 230, 230, 255))
    elif item == "lantern":
        d.rectangle((28, 24, 34, 34), fill=(240, 210, 100, 255))
        d.rectangle((29, 22, 33, 24), fill=INK)
    return im


def mirror(im: Image.Image) -> Image.Image:
    return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)


def back_from_front(front: Image.Image, gender: str, hair) -> Image.Image:
    im = blank(40, 40)
    f = front.load()
    p = im.load()
    for y in range(40):
        for x in range(40):
            c = f[x, y]
            if c[3] < 16:
                continue
            # hide face details roughly by darkening upper-mid
            if 10 <= y <= 16 and 14 <= x <= 26:
                p[x, y] = (*hair, 255)
            else:
                p[x, y] = c
    # hair mass on back
    d = ImageDraw.Draw(im)
    if gender == "girl":
        d.rectangle((11, 4, 29, 18), fill=(*hair, 255))
        d.rectangle((10, 14, 30, 26), fill=(*hair, 255))
    else:
        d.rectangle((12, 4, 28, 12), fill=(*hair, 255))
    return im


def walk_sheet(front: Image.Image, gender: str, hair) -> Image.Image:
    # exact SPEC: 120x160 = 3 cols x 4 rows of 40x40
    sheet = blank(120, 160)
    left = mirror(front)
    right = front
    back = back_from_front(front, gender, hair)
    rows = [front, left, right, back]
    for r, base in enumerate(rows):
        for c in range(3):
            frame = base.copy()
            if c == 1:
                # step left foot
                px = frame.load()
                for y in range(34, 40):
                    for x in range(14, 20):
                        if px[x, y][3] > 16:
                            if x - 1 >= 0:
                                px[x - 1, y] = px[x, y]
                for y in range(34, 40):
                    for x in range(21, 27):
                        if px[x, y][3] > 16 and x + 1 < 40:
                            px[x + 1, min(39, y)] = px[x, y]
            elif c == 2:
                px = frame.load()
                for y in range(34, 40):
                    for x in range(21, 27):
                        if px[x, y][3] > 16 and x - 1 >= 0:
                            px[x - 1, y] = px[x, y]
            sheet.paste(frame, (c * 40, r * 40), frame)
    return sheet


def build_cast() -> None:
    names = []
    for i, (gender, name, cfg) in enumerate(CAST_DEF, start=1):
        front = draw_front(cfg, gender)
        save(CAST / f"c{i}.png", front, 24)
        sheet = walk_sheet(front, gender, cfg["hair"])
        save(CAST / f"c{i}_walk.png", sheet, 28)
        names.append(f"{name}|{gender}")
    (CAST / "names.txt").write_text("\n".join(n.split("|")[0] for n in names) + "\n", encoding="utf-8")
    (CAST / "genders.txt").write_text("\n".join(n.split("|")[1] for n in names) + "\n", encoding="utf-8")


def tree_pine_tall() -> Image.Image:
    im = blank(28, 40)
    d = ImageDraw.Draw(im)
    d.rectangle((12, 30, 16, 39), fill=(90, 60, 30, 255))
    for i, (top, bot, col) in enumerate(
        [((14, 2), (6, 14), (70, 130, 50)), ((14, 8), (4, 20), (50, 110, 40)), ((14, 14), (2, 28), (40, 90, 35))]
    ):
        d.polygon([top, (bot[0], bot[1]), (28 - bot[0], bot[1])], fill=(*col, 255))
        d.line([top, (bot[0] + 2, bot[1] - 2)], fill=(150, 190, 80, 255))
    return im


def tree_birch() -> Image.Image:
    im = blank(26, 38)
    d = ImageDraw.Draw(im)
    d.rectangle((11, 18, 15, 37), fill=(230, 230, 220, 255))
    for y in (22, 28, 33):
        d.line((11, y, 15, y), fill=(60, 60, 55, 255))
    d.ellipse((2, 2, 24, 22), fill=(70, 140, 55, 255))
    d.ellipse((4, 0, 18, 14), fill=(120, 180, 70, 255))
    return im


def tree_autumn() -> Image.Image:
    im = blank(30, 36)
    d = ImageDraw.Draw(im)
    d.rectangle((13, 22, 17, 35), fill=(100, 70, 35, 255))
    for box, col in [
        ((2, 4, 16, 18), (210, 120, 40)),
        ((10, 2, 28, 16), (220, 80, 50)),
        ((4, 10, 24, 24), (180, 60, 40)),
    ]:
        d.ellipse(box, fill=(*col, 255))
    return im


def tree_blossom() -> Image.Image:
    im = blank(28, 36)
    d = ImageDraw.Draw(im)
    d.rectangle((12, 20, 16, 35), fill=(110, 80, 50, 255))
    d.ellipse((2, 2, 26, 22), fill=(90, 150, 70, 255))
    for x, y in [(6, 6), (12, 4), (18, 8), (10, 12), (20, 12), (8, 16), (16, 16)]:
        d.ellipse((x, y, x + 3, y + 3), fill=(240, 170, 190, 255))
    return im


def build_trees() -> None:
    save(SHARED / "tile_tree8.png", tree_pine_tall(), 20)
    save(SHARED / "tile_tree9.png", tree_birch(), 20)
    save(SHARED / "tile_tree10.png", tree_autumn(), 20)
    save(SHARED / "tile_tree11.png", tree_blossom(), 20)


def build_cups() -> None:
    print("  (cups: run scripts/build-cups.py)")


def build_bird_chirp() -> None:
    # tiny mono wav chirp (no ffmpeg dependency)
    path = AUDIO / "sfx_bird.wav"
    rate = 22050
    dur = 0.22
    n = int(rate * dur)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        frames = bytearray()
        for i in range(n):
            t = i / rate
            env = max(0.0, 1.0 - t / dur)
            freq = 1800 + 900 * math.sin(t * 40)
            val = int(12000 * env * math.sin(2 * math.pi * freq * t))
            frames += struct.pack("<h", max(-32767, min(32767, val)))
        w.writeframes(frames)
    print(f"  audio/sfx_bird.wav {n} samples")


def main() -> int:
    print("build camp life assets")
    # 角色立绘/走表已恢复为 walk_v5，禁止再跑程序色块 build_cast 覆盖。
    # 需要重建杯子/树/鸟叫时再跑本脚本；角色请用 scripts/restore-cast-walk-v5.py
    build_trees()
    build_cups()
    build_bird_chirp()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
