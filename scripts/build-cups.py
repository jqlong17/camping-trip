#!/usr/bin/env python3
"""Build 9 Japanese cup icons from text-to-image sheet → hard-pixel runtime PNGs."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from asset_layout import CUPS, GEAR

ROOT = Path(__file__).resolve().parents[1]
PROMO = ROOT / "docs" / "promo"
GEN = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets/cups_sheet_gen.png")

ICON_W, ICON_H = 40, 36
GEAR_W, GEAR_H = 48, 40

CUP_DEFS = [
    ("cup_01_hakuji", "白瓷杯", "coffee"),
    ("cup_02_aoguma", "青磁湯吞", "tea"),
    ("cup_03_kozara", "茶杯碟", "tea"),
    ("cup_04_sumi", "墨釉马克", "coffee"),
    ("cup_05_beni", "朱泥茶盏", "tea"),
    ("cup_06_matcha", "抹茶碗", "tea"),
    ("cup_07_enamel", "搪瓷马克", "coffee"),
    ("cup_08_take", "竹节杯", "tea"),
    ("cup_09_glass", "硝子咖啡", "coffee"),
]

ASSET_PROVENANCE = [
    {
        "outputs": "game/assets/cups/{id}.png",
        "sources": "docs/promo/cups_sheet_gen_ref.png",
        "variants": {"id": [
            "cup_01_hakuji", "cup_02_aoguma", "cup_03_kozara",
            "cup_04_sumi", "cup_05_beni", "cup_06_matcha",
            "cup_07_enamel", "cup_08_take", "cup_09_glass",
        ]},
        "operation": "slice_runs + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/gear/cup.png",
        "sources": "docs/promo/cups_sheet_gen_ref.png",
        "operation": "slice_first + crop + resize + quantize",
    },
]


def quantize_rgba(im: Image.Image, colors: int = 24) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.split()[-1]
    rgb = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def bg_mask(arr: np.ndarray) -> np.ndarray:
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    wood = (r > 175) & (g > 140) & (b > 95) & (r - b < 110)
    light = (r > 205) & (g > 195) & (b > 155)
    return wood | light


def kill_bg(im: Image.Image) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    a[bg_mask(a), 3] = 0
    return Image.fromarray(a)


def subject_bbox(im: Image.Image, pad: int = 2) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    subj = (a[:, :, 3] > 16) & ~bg_mask(a)
    ys, xs = np.where(subj)
    if len(xs) == 0:
        return im
    x0, x1 = max(0, int(xs.min()) - pad), min(im.width, int(xs.max()) + 1 + pad)
    y0, y1 = max(0, int(ys.min()) - pad), min(im.height, int(ys.max()) + 1 + pad)
    return kill_bg(im.crop((x0, y0, x1, y1)))


def hard_fit(im: Image.Image, tw: int, th: int, colors: int = 24) -> Image.Image:
    crop = subject_bbox(im)
    arr = np.array(crop)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    rgba = crop
    scale = min((tw - 2) / rgba.width, (th - 2) / rgba.height)
    nw = max(1, int(round(rgba.width * scale)))
    nh = max(1, int(round(rgba.height * scale)))
    mid_w, mid_h = max(8, nw // 2), max(8, nh // 2)
    mid = rgba.resize((mid_w, mid_h), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    scaled = quantize_rgba(scaled, colors)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def slice_runs(im: Image.Image) -> list[Image.Image]:
    a = np.array(im.convert("RGBA"))
    subj = (a[:, :, 3] > 16) & ~bg_mask(a)
    rows, cols = subj.any(axis=1), subj.any(axis=0)
    if not rows.any():
        return []
    y0, y1 = int(np.argmax(rows)), int(im.height - np.argmax(rows[::-1]))
    x0, x1 = int(np.argmax(cols)), int(im.width - np.argmax(cols[::-1]))
    band = im.crop((x0, y0, x1 + 1, y1 + 1))
    ba = np.array(band)
    col = (~bg_mask(ba)).any(axis=0)
    runs, in_run, start = [], False, 0
    for i, v in enumerate(col):
        if v and not in_run:
            start, in_run = i, True
        elif not v and in_run:
            runs.append((start, i))
            in_run = False
    if in_run:
        runs.append((start, len(col)))
    return [band.crop((rx0, 0, rx1, band.height)) for rx0, rx1 in runs]


def save(path: Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def main() -> int:
    PROMO.mkdir(parents=True, exist_ok=True)
    repo_source = PROMO / "cups_sheet_gen_ref.png"
    if repo_source.is_file():
        src = Image.open(repo_source).convert("RGBA")
    elif GEN.is_file():
        src = Image.open(GEN).convert("RGBA")
        src.save(repo_source)
    else:
        raise SystemExit(f"missing source: {repo_source} or {GEN}")
    print(f"promo ref → {PROMO / 'cups_sheet_gen_ref.png'}")

    parts = slice_runs(src)
    if len(parts) != len(CUP_DEFS):
        raise SystemExit(f"slice_runs got {len(parts)} cups, need {len(CUP_DEFS)} — check gen sheet layout")

    print("cups → assets/cups/")
    CUPS.mkdir(parents=True, exist_ok=True)
    for i, (cup_id, _name, _kind) in enumerate(CUP_DEFS):
        save(CUPS / f"{cup_id}.png", hard_fit(parts[i], ICON_W, ICON_H, 24))

    GEAR.mkdir(parents=True, exist_ok=True)
    save(GEAR / "cup.png", hard_fit(parts[0], GEAR_W, GEAR_H, 24))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
