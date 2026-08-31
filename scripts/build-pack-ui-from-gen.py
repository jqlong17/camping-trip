#!/usr/bin/env python3
"""Lock text-to-image pack UI + gear icons into hard-pixel runtime assets."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
from asset_layout import ASSETS, GEAR, UI
DOCS = ROOT / "docs" / "promo"
GEN_BG = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets/pack_bg_gen.png")
GEN_SHEET = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets/gear_sheet_gen.png")

GEAR_IDS = ["tent", "drip", "pot", "rod", "cup", "fan"]
ICON_W, ICON_H = 48, 40


def quantize_rgba(im: Image.Image, colors: int) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.split()[-1]
    rgb = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def hard_pixel(im: Image.Image, tw: int, th: int, colors: int) -> Image.Image:
    """Downsample then nearest upscale for chunky 16-bit look, then quantize."""
    src = im.convert("RGBA")
    # work at half then ×2 nearest when large enough
    if tw >= 64 and th >= 64:
        mid = src.resize((max(1, tw // 2), max(1, th // 2)), Image.Resampling.BILINEAR)
        out = mid.resize((tw, th), Image.Resampling.NEAREST)
    else:
        out = src.resize((tw, th), Image.Resampling.NEAREST)
    return quantize_rgba(out, colors)


def to_transparent(im: Image.Image, thr: int = 28) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    dark = (arr[:, :, 0] < thr) & (arr[:, :, 1] < thr) & (arr[:, :, 2] < thr)
    arr[dark, 3] = 0
    return Image.fromarray(arr)


def fit_icon(im: Image.Image, tw: int = ICON_W, th: int = ICON_H) -> Image.Image:
    im = to_transparent(im)
    arr = np.array(im)
    ys, xs = np.where(arr[:, :, 3] > 16)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    crop = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    # leave 1px margin
    scale = min((tw - 2) / crop.width, (th - 2) / crop.height)
    nw = max(1, int(round(crop.width * scale)))
    nh = max(1, int(round(crop.height * scale)))
    # prefer nearest for hard pixels after slight downsample
    small = crop.resize((max(1, nw // 2 * 2 or 1), max(1, nh // 2 * 2 or 1)), Image.Resampling.BILINEAR)
    # actually: resize to target with nearest after bilinear to mid
    mid_w = max(8, nw // 2)
    mid_h = max(8, nh // 2)
    mid = crop.resize((mid_w, mid_h), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    scaled = quantize_rgba(scaled, 24)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def build_pack_bg() -> None:
    from PIL import ImageDraw

    src = Image.open(GEN_BG).convert("RGBA")
    DOCS.mkdir(parents=True, exist_ok=True)
    src.save(DOCS / "pack_bg_gen_ref.png")
    sw, sh = src.size
    scale = max(320 / sw, 240 / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    resized = src.resize((nw, nh), Image.Resampling.BICUBIC)
    covered = Image.new("RGBA", (320, 240), (236, 222, 190, 255))
    covered.paste(resized, ((320 - nw) // 2, (240 - nh) // 2), resized)
    mid = covered.resize((200, 150), Image.Resampling.BILINEAR)
    pixel = mid.resize((320, 240), Image.Resampling.NEAREST)
    d = ImageDraw.Draw(pixel)
    leaf, leaf_l, flower = (52, 92, 40, 255), (90, 130, 55, 255), (220, 180, 60, 255)

    def corner(cx: int, cy: int, sx: int, sy: int) -> None:
        for ox, oy in [(2, 2), (8, 1), (14, 3), (4, 7), (10, 8), (16, 7), (6, 12), (12, 13), (3, 16), (18, 12), (20, 4)]:
            x, y = cx + ox * sx, cy + oy * sy
            d.rectangle((x, y, x + 3, y + 2), fill=leaf)
            d.point((x + 1, y), fill=leaf_l)
        d.point((cx + 10 * sx, cy + 6 * sy), fill=flower)
        d.point((cx + 6 * sx, cy + 10 * sy), fill=flower)

    corner(4, 4, 1, 1)
    corner(300, 4, -1, 1)
    corner(4, 220, 1, -1)
    corner(300, 220, -1, -1)
    for x in range(40, 280, 28):
        d.rectangle((x, 2, x + 12, 5), fill=leaf)
        d.point((x + 4, 3), fill=leaf_l)
        d.rectangle((x, 234, x + 12, 237), fill=leaf)
        d.point((x + 6, 235), fill=flower)
    pixel = quantize_rgba(pixel, 48)
    pot = Image.new("RGBA", (512, 256), (38, 46, 36, 255))
    pot.paste(pixel, (0, 0))
    old = UI / "ui_pack_bg.png"
    bak = UI / "ui_pack_bg_v1.png"
    if old.exists() and not bak.exists():
        Image.open(old).save(bak)
    UI.mkdir(parents=True, exist_ok=True)
    pot.save(old)
    print(f"ui_pack_bg.png {pot.size}")


def build_gear_icons() -> None:
    sheet = Image.open(GEN_SHEET).convert("RGBA")
    sheet.save(DOCS / "gear_sheet_gen_ref.png")
    arr = np.array(sheet)
    mask = ~((arr[:, :, 0] < 25) & (arr[:, :, 1] < 25) & (arr[:, :, 2] < 25))
    col = mask.any(axis=0)
    runs = []
    in_run = False
    start = 0
    for i, v in enumerate(col):
        if v and not in_run:
            in_run = True
            start = i
        elif not v and in_run:
            in_run = False
            runs.append((start, i - 1))
    if in_run:
        runs.append((start, len(col) - 1))
    row = mask.any(axis=1)
    ys = np.where(row)[0]
    y0, y1 = int(ys.min()), int(ys.max())
    assert len(runs) >= 6, f"expected 6 icons, got {len(runs)}"

    for i, gid in enumerate(GEAR_IDS):
        x0, x1 = runs[i]
        cell = sheet.crop((x0, y0, x1 + 1, y1 + 1))
        icon = fit_icon(cell)
        out = GEAR / f"{gid}.png"
        bak = GEAR / f"{gid}_v1.png"
        if out.exists() and not bak.exists():
            Image.open(out).save(bak)
        GEAR.mkdir(parents=True, exist_ok=True)
        icon.save(out)
        print(f"gear/{gid}.png {icon.size}")

    print("cup variants: run scripts/build-cups.py")


def main() -> int:
    if not GEN_BG.is_file() or not GEN_SHEET.is_file():
        raise SystemExit("missing generated images")
    print("lock pack UI from text-to-image")
    build_pack_bg()
    build_gear_icons()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
