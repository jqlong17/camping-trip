#!/usr/bin/env python3
"""Lock 文生图 sources into 3DS SMDH icon (48×48) + banner (256×128)."""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CIA = ROOT / "cia"
PROMO = ROOT / "docs" / "promo"
ASSETS = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")
ICON_SRC = ASSETS / "linjian-icon-source.png"
BANNER_SRC = ASSETS / "linjian-banner-source.png"
FONT = ROOT / "game" / "fonts" / "zh-ui.ttf"


def quantize(im: Image.Image, colors: int) -> Image.Image:
    rgb = im.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    return rgb.convert("RGB")


def pixel_lock_square(src: Path, size: int, colors: int) -> Image.Image:
    im = Image.open(src).convert("RGB")
    # two-step BOX so 48×48 stays chunky, not smeared
    mid = max(size * 2, 64)
    im = im.resize((mid, mid), Image.Resampling.BOX)
    im = quantize(im, min(48, colors * 2))
    im = im.resize((size, size), Image.Resampling.NEAREST)
    return quantize(im, colors)


def cover(im: Image.Image, w: int, h: int) -> Image.Image:
    sw, sh = im.size
    scale = max(w / sw, h / sh)
    nw, nh = max(1, int(sw * scale)), max(1, int(sh * scale))
    im = im.resize((nw, nh), Image.Resampling.BOX)
    # keep tent/fire: slightly below vertical center
    left = (nw - w) // 2
    top = max(0, int((nh - h) * 0.42))
    return im.crop((left, top, left + w, top + h))


def add_title(banner: Image.Image) -> Image.Image:
    im = banner.convert("RGB")
    draw = ImageDraw.Draw(im)
    title_font = ImageFont.truetype(str(FONT), 18)
    sub_font = ImageFont.truetype(str(FONT), 11)
    title, sub = "露营之旅", "Camping Trip"
    tw = title_font.getlength(title)
    sw = sub_font.getlength(sub)
    box_w = int(max(tw, sw) + 16)
    box_h = 38
    x, y = 256 - box_w - 8, 8
    draw.rectangle((x, y, x + box_w, y + box_h), fill=(28, 22, 16))
    draw.rectangle((x + 1, y + 1, x + box_w - 1, y + box_h - 1), outline=(214, 184, 120))
    draw.text((x + 8, y + 3), title, font=title_font, fill=(255, 244, 220))
    draw.text((x + 8, y + 22), sub, font=sub_font, fill=(214, 184, 120))
    return im


def main() -> None:
    PROMO.mkdir(parents=True, exist_ok=True)
    for name in ("icon.png", "banner.png"):
        src = CIA / name
        bak = CIA / name.replace(".png", "_v1.png")
        if src.is_file() and not bak.is_file():
            shutil.copy2(src, bak)

    icon = pixel_lock_square(ICON_SRC, 48, 24)
    icon.save(CIA / "icon.png")
    logo256 = pixel_lock_square(ICON_SRC, 256, 32)
    logo256.save(PROMO / "logo_256.png")
    shutil.copy2(ICON_SRC, PROMO / "logo_source.png")

    raw = Image.open(BANNER_SRC).convert("RGB")
    raw = cover(raw, 512, 256)
    raw = quantize(raw, 40)
    banner = raw.resize((256, 128), Image.Resampling.NEAREST)
    banner = add_title(banner)
    banner = quantize(banner, 40)
    banner.save(CIA / "banner.png")
    shutil.copy2(BANNER_SRC, PROMO / "banner_source.png")

    print(f"icon   {icon.size} colors={len(icon.getcolors() or [])}")
    print(f"banner {banner.size} colors={len(banner.getcolors() or [])}")
    print("✓ cia/icon.png + cia/banner.png")


if __name__ == "__main__":
    main()
