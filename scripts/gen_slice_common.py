"""Shared text-to-image → hard-pixel slice helpers for linjian build scripts."""
from __future__ import annotations

from collections import deque
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


def chroma_key_fit(
    im: Image.Image,
    tw: int,
    th: int,
    colors: int = 24,
    margin: int = 2,
    pixel_scale: int = 2,
) -> Image.Image:
    """CKE：移除高饱和绿幕后等比缩放；pixel_scale=1 保留高密度细节。"""
    arr = np.array(im.convert("RGBA"))
    rgb = arr[:, :, :3].astype(int)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    green_excess = g - np.maximum(r, b)
    chroma = (g >= 150) & (green_excess >= 55)
    arr[chroma, 3] = 0

    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    x0 = max(0, int(xs.min()) - 1)
    x1 = min(im.width, int(xs.max()) + 2)
    y0 = max(0, int(ys.min()) - 1)
    y1 = min(im.height, int(ys.max()) + 2)
    crop = Image.fromarray(arr.astype(np.uint8)).crop((x0, y0, x1, y1))

    inner_w = max(1, tw - margin * 2)
    inner_h = max(1, th - margin * 2)
    scale = min(inner_w / crop.width, inner_h / crop.height)
    nw = max(1, int(round(crop.width * scale)))
    nh = max(1, int(round(crop.height * scale)))
    if pixel_scale <= 1:
        scaled = quantize_rgba(crop.resize((nw, nh), Image.Resampling.BILINEAR), colors)
    else:
        mid = crop.resize(
            (max(4, nw // pixel_scale), max(4, nh // pixel_scale)),
            Image.Resampling.BILINEAR,
        )
        scaled = quantize_rgba(mid.resize((nw, nh), Image.Resampling.NEAREST), colors)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def ecsp_remove_edge_background(im: Image.Image) -> Image.Image:
    """ECSP：只清除与画布边缘连通的浅色背景，保留主体内部同色图案。"""
    arr = np.array(im.convert("RGBA"))
    rgb = arr[:, :, :3].astype(int)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    candidate = (arr[:, :, 3] < 16) | (
        (r > 230) & (g > 220) & (b > 200) & ((r - b) < 70)
    )
    height, width = candidate.shape
    background = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    def seed(y: int, x: int) -> None:
        if candidate[y, x] and not background[y, x]:
            background[y, x] = True
            queue.append((y, x))

    for x in range(width):
        seed(0, x)
        seed(height - 1, x)
    for y in range(height):
        seed(y, 0)
        seed(y, width - 1)

    while queue:
        y, x = queue.popleft()
        for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if (
                0 <= next_y < height
                and 0 <= next_x < width
                and candidate[next_y, next_x]
                and not background[next_y, next_x]
            ):
                background[next_y, next_x] = True
                queue.append((next_y, next_x))

    arr[background, 3] = 0
    return Image.fromarray(arr.astype(np.uint8))


def ecsp_split_horizontal(im: Image.Image, count: int) -> list[Image.Image]:
    """ECSP：按实际主体间的空白分组，不用等宽分格，避免把手跨格被截断。"""
    keyed = ecsp_remove_edge_background(im)
    arr = np.array(keyed)
    foreground = arr[:, :, 3] > 20
    height, width = foreground.shape

    row_counts = foreground.sum(axis=1)
    wide_rows = np.where(row_counts > width * 0.55)[0]
    if not len(wide_rows):
        raise ValueError("ECSP could not locate the shared shelf")
    wide_runs: list[list[int]] = []
    for y in wide_rows:
        current = int(y)
        if not wide_runs or current > wide_runs[-1][-1] + 1:
            wide_runs.append([current])
        else:
            wide_runs[-1].append(current)
    # 同一高度排列的多个器具也会形成宽前景带；木架取覆盖像素最多的那一带。
    shelf_rows = max(wide_runs, key=lambda run: int(row_counts[run].max()))
    shelf_top = shelf_rows[0]
    shelf_bottom = shelf_rows[-1] + 1

    columns = foreground[:shelf_top].any(axis=0)
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for x, occupied in enumerate(columns):
        if occupied and start is None:
            start = x
        elif not occupied and start is not None:
            runs.append((start, x))
            start = None
    if start is not None:
        runs.append((start, width))
    runs = [(x0, x1) for x0, x1 in runs if x1 - x0 >= max(4, width // 200)]
    if len(runs) != count:
        raise ValueError(f"ECSP expected {count} subjects, found {len(runs)}: {runs}")

    parts: list[Image.Image] = []
    for x0, x1 in runs:
        x_pad = max(6, int((x1 - x0) * 0.08))
        left = max(0, x0 - x_pad)
        right = min(width, x1 + x_pad)
        local = foreground[:shelf_top, left:right]
        ys, _ = np.where(local)
        top = max(0, int(ys.min()) - x_pad) if len(ys) else 0
        bottom = min(height, shelf_bottom + x_pad)
        parts.append(keyed.crop((left, top, right, bottom)))
    return parts


def ecsp_fit(im: Image.Image, tw: int, th: int, colors: int = 24, margin: int = 3) -> Image.Image:
    """ECSP：透明裁边后 contain 等比缩放，四周保留明确安全边距。"""
    arr = np.array(im.convert("RGBA"))
    ys, xs = np.where(arr[:, :, 3] > 20)
    if not len(xs):
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    crop = Image.fromarray(arr).crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    scale = min((tw - margin * 2) / crop.width, (th - margin * 2) / crop.height)
    nw = max(1, int(round(crop.width * scale)))
    nh = max(1, int(round(crop.height * scale)))
    mid = crop.resize((max(4, nw * 2), max(4, nh * 2)), Image.Resampling.BILINEAR)
    scaled = quantize_rgba(mid.resize((nw, nh), Image.Resampling.NEAREST), colors)
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
    PROMO.mkdir(parents=True, exist_ok=True)
    src = GEN_ASSETS / name
    out_name = promo_name or f"{src.stem}_ref.png"
    repo_source = PROMO / out_name
    if repo_source.is_file():
        return Image.open(repo_source).convert("RGBA")
    if not src.is_file():
        raise FileNotFoundError(f"missing gen source: {repo_source} or {src}")
    im = Image.open(src).convert("RGBA")
    im.save(repo_source)
    return im
