#!/usr/bin/env python3
"""Build fishing ritual choice icons (48×48) into ritual/fish/."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
FISH_DIR = ROOT / "game" / "assets" / "ritual" / "fish"

WATER = (72, 140, 176, 255)
WATER_L = (120, 180, 200, 255)
WATER_D = (48, 100, 136, 255)
GRASS = (78, 148, 42, 255)
WOOD = (156, 108, 52, 255)
WOOD_D = (96, 64, 28, 255)
INK = (28, 22, 16, 255)
BOBBER = (236, 84, 64, 255)
METAL = (140, 150, 160, 255)
WORM = (196, 88, 72, 255)
DOUGH = (240, 220, 180, 255)
LURE = (220, 180, 60, 255)
BUG = (120, 180, 60, 255)
CORN = (250, 210, 80, 255)
WEED = (56, 120, 48, 255)
FOAM = (230, 245, 250, 255)


def quantize(im: Image.Image, colors: int = 32) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.split()[-1]
    rgb = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def save(name: str, im: Image.Image) -> None:
    FISH_DIR.mkdir(parents=True, exist_ok=True)
    path = FISH_DIR / name
    out = quantize(im, 32)
    out.save(path)
    print(f"  {path.relative_to(ROOT)} {out.size}")


def blank() -> Image.Image:
    return Image.new("RGBA", (48, 48), (0, 0, 0, 0))


def water_band(d: ImageDraw.ImageDraw, y0: int = 18, y1: int = 44) -> None:
    d.rectangle((0, y0, 47, y1), fill=WATER)
    for x in range(0, 48, 6):
        d.arc((x, y0 + 2, x + 8, y0 + 10), 200, 340, fill=WATER_L)


def spot_shoal() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 28, 47, 47), fill=GRASS)
    water_band(d, 22, 44)
    d.ellipse((10, 30, 22, 36), fill=FOAM)
    d.point((16, 32), fill=INK)
    return im


def spot_pool() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 47, 47), fill=WATER_D)
    d.ellipse((8, 14, 40, 40), fill=WATER)
    d.ellipse((14, 22, 34, 34), fill=(36, 72, 100, 255))
    return im


def spot_pier() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    water_band(d, 24, 47)
    for x in (6, 22, 38):
        d.rectangle((x, 8, x + 4, 34), fill=WOOD_D)
    d.rectangle((4, 20, 44, 28), fill=WOOD)
    d.line((4, 24, 44, 24), fill=WOOD_D)
    return im


def spot_weed() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    water_band(d, 20, 47)
    for x in (8, 18, 28, 36):
        d.polygon([(x, 38), (x + 3, 18), (x + 6, 38)], fill=WEED)
    return im


def spot_rapids() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.rectangle((0, 16, 47, 47), fill=WATER)
    for x in range(0, 48, 8):
        d.polygon([(x, 44), (x + 4, 20), (x + 8, 44)], fill=FOAM)
    return im


def bait_worm() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    pts = [(10, 28), (16, 22), (24, 26), (32, 20), (38, 28)]
    for i in range(len(pts) - 1):
        d.line((pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]), fill=WORM, width=3)
    d.ellipse((8, 26, 14, 32), fill=WORM)
    return im


def bait_dough() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.ellipse((12, 18, 36, 34), fill=DOUGH)
    d.ellipse((14, 20, 34, 32), fill=(250, 235, 210, 255))
    return im


def bait_lure() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.polygon([(24, 10), (32, 24), (24, 38), (16, 24)], fill=LURE)
    d.line((24, 10, 24, 6), fill=INK)
    d.ellipse((22, 4, 26, 8), fill=METAL)
    return im


def bait_bug() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.ellipse((18, 20, 30, 32), fill=BUG)
    d.line((14, 24, 34, 24), fill=INK)
    d.line((14, 28, 34, 28), fill=INK)
    d.ellipse((16, 14, 22, 20), fill=BUG)
    d.ellipse((26, 14, 32, 20), fill=BUG)
    return im


def bait_corn() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.ellipse((16, 14, 32, 36), fill=CORN)
    for y in range(18, 34, 4):
        for x in range(18, 31, 4):
            d.point((x, y), fill=(220, 170, 40, 255))
    return im


def sinker_light() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.ellipse((20, 28, 28, 36), fill=METAL)
    d.line((24, 8, 24, 28), fill=INK)
    return im


def sinker_mid() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.ellipse((18, 26, 30, 38), fill=METAL)
    d.rectangle((22, 10, 26, 26), fill=INK)
    return im


def sinker_heavy() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    d.polygon([(24, 8), (34, 40), (14, 40)], fill=METAL)
    d.line((24, 8, 24, 4), fill=INK)
    return im


def style_wait() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    water_band(d, 26, 47)
    d.line((24, 6, 24, 30), fill=WOOD_D)
    d.ellipse((20, 30, 28, 36), fill=BOBBER)
    return im


def style_twitch() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    water_band(d, 26, 47)
    d.line((24, 6, 24, 30), fill=WOOD_D)
    d.ellipse((18, 28, 26, 34), fill=BOBBER)
    for ox in (28, 32, 36):
        d.line((ox, 30, ox + 3, 28), fill=WATER_L)
    return im


def style_dance() -> Image.Image:
    im = blank()
    d = ImageDraw.Draw(im)
    water_band(d, 26, 47)
    d.line((24, 6, 24, 30), fill=WOOD_D)
    d.ellipse((20, 28, 28, 34), fill=BOBBER)
    d.arc((10, 18, 38, 40), 200, 340, fill=FOAM)
    d.arc((12, 20, 36, 38), 20, 160, fill=FOAM)
    return im


SPOTS = {
    "shoal": spot_shoal,
    "pool": spot_pool,
    "pier": spot_pier,
    "weed": spot_weed,
    "rapids": spot_rapids,
}
BAITS = {
    "worm": bait_worm,
    "dough": bait_dough,
    "lure": bait_lure,
    "bug": bait_bug,
    "corn": bait_corn,
}
SINKERS = {
    "light": sinker_light,
    "mid": sinker_mid,
    "heavy": sinker_heavy,
}
STYLES = {
    "wait": style_wait,
    "twitch": style_twitch,
    "dance": style_dance,
}


def main() -> int:
    print("fish choice icons → ritual/fish/")
    for sid, fn in SPOTS.items():
        save(f"spot_{sid}.png", fn())
    for bid, fn in BAITS.items():
        save(f"bait_{bid}.png", fn())
    for sid, fn in SINKERS.items():
        save(f"sinker_{sid}.png", fn())
    for sid, fn in STYLES.items():
        save(f"style_{sid}.png", fn())
    print("done (run build-harvest-assets.py for fish_1..4 frames)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
