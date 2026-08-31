"""Shared text-to-image → hard-pixel slice helpers for linjian build scripts."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROMO = ROOT / "docs" / "promo"
GEN_ASSETS = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")


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
    cream = (r > 230) & (g > 220) & (b > 200)
    dark = (r < 28) & (g < 28) & (b < 28)
    return wood | light | cream | dark


def kill_bg(im: Image.Image) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    a[bg_mask(a), 3] = 0
    return Image.fromarray(a)


def subject_crop(im: Image.Image, pad: int = 1) -> Image.Image:
    a = np.array(kill_bg(im))
    ys, xs = np.where(a[:, :, 3] > 20)
    if len(xs) == 0:
        return im
    x0 = max(0, int(xs.min()) - pad)
    x1 = min(im.width, int(xs.max()) + 1 + pad)
    y0 = max(0, int(ys.min()) - pad)
    y1 = min(im.height, int(ys.max()) + 1 + pad)
    return Image.fromarray(a).crop((x0, y0, x1, y1))


def hard_fit(im: Image.Image, tw: int, th: int, colors: int = 24) -> Image.Image:
    crop = subject_crop(im)
    arr = np.array(crop)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    scale = min((tw - 2) / crop.width, (th - 2) / crop.height)
    nw = max(1, int(round(crop.width * scale)))
    nh = max(1, int(round(crop.height * scale)))
    mid_w, mid_h = max(4, nw // 2), max(4, nh // 2)
    mid = crop.resize((mid_w, mid_h), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    scaled = quantize_rgba(scaled, colors)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def hard_tile(im: Image.Image, size: int = 16, colors: int = 20) -> Image.Image:
    """Resize cell to exact tile with nearest + quantize (opaque)."""
    mid = im.convert("RGBA").resize((size * 2, size * 2), Image.Resampling.BILINEAR)
    out = mid.resize((size, size), Image.Resampling.NEAREST)
    return quantize_rgba(out, colors)


def slice_grid(im: Image.Image, cols: int, rows: int, pad: float = 0.04) -> list[Image.Image]:
    a = np.array(im.convert("RGBA"))
    subj = (a[:, :, 3] > 16) & ~bg_mask(a)
    if not subj.any():
        return [Image.new("RGBA", (16, 16), (0, 0, 0, 0)) for _ in range(cols * rows)]
    ys, xs = np.where(subj)
    band = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    cw, ch = band.width / cols, band.height / rows
    out = []
    for r in range(rows):
        for c in range(cols):
            left = int(c * cw + cw * pad)
            right = int((c + 1) * cw - cw * pad)
            top = int(r * ch + ch * pad)
            bot = int((r + 1) * ch - ch * pad)
            out.append(band.crop((left, top, max(left + 1, right), max(top + 1, bot))))
    return out


def slice_equal(im: Image.Image, n: int, pad: float = 0.04) -> list[Image.Image]:
    return slice_grid(im, n, 1, pad=pad)


def slice_runs(im: Image.Image) -> list[Image.Image]:
    a = np.array(im.convert("RGBA"))
    subj = (a[:, :, 3] > 16) & ~bg_mask(a)
    ys, xs = np.where(subj)
    if len(xs) == 0:
        return []
    band = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
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


def load_gen(name: str, promo_name: str | None = None) -> Image.Image:
    src = GEN_ASSETS / name
    if not src.is_file():
        raise FileNotFoundError(f"missing gen sheet: {src}")
    im = Image.open(src).convert("RGBA")
    PROMO.mkdir(parents=True, exist_ok=True)
    im.save(PROMO / (promo_name or name.replace(".png", "_gen_ref.png")))
    return im
