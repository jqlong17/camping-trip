#!/usr/bin/env python3
"""Build tea-brew pixel icons from gen sheets + procedural markers."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
RITUAL = ASSETS / "ritual"
PROMO = ROOT / "docs" / "promo"
GEN = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")

LEAF_IDS = ["longjing", "tieguanyin", "dianhong", "yinzhen", "genmaicha"]
WARE_IDS = ["gaiwan", "glass", "zisha", "piaoyi", "enamel"]


def quantize_rgba(im: Image.Image, colors: int = 28) -> Image.Image:
    rgba = im.convert("RGBA")
    a = rgba.split()[-1]
    q = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = q.convert("RGBA")
    out.putalpha(a)
    return out


def kill_cream_bg(im: Image.Image, thr: int = 228) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    cream = (a[:, :, 0] > thr) & (a[:, :, 1] > thr - 8) & (a[:, :, 2] > thr - 20)
    a[cream, 3] = 0
    return Image.fromarray(a)


def hard_fit(im: Image.Image, tw: int, th: int, colors: int = 28) -> Image.Image:
    rgba = kill_cream_bg(im.convert("RGBA"))
    arr = np.array(rgba)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    crop = rgba.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    mid = crop.resize((tw * 2, th * 2), Image.Resampling.BILINEAR)
    mid = mid.resize((tw, th), Image.Resampling.NEAREST)
    return quantize_rgba(mid, colors)


def save(rel: str, im: Image.Image) -> None:
    # rel like "ritual/tea/leaf_x.png" or legacy "ritual/leaf_x.png" → tea/
    if str(rel).startswith("ritual/"):
        parts = Path(rel).parts  # ritual, ...
        if len(parts) >= 3:
            path = RITUAL.joinpath(*parts[1:])
        else:
            path = RITUAL / "tea" / Path(rel).name
    else:
        path = ASSETS / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def slice_equal(im: Image.Image, n: int, pad: float = 0.02, top_frac: float = 1.0) -> list[Image.Image]:
    a = np.array(im.convert("RGBA"))
    ink = a[:, :, 3] > 16
    # also treat near-cream as bg
    cream = (a[:, :, 0] > 230) & (a[:, :, 1] > 220) & (a[:, :, 2] > 200)
    ink = ink & ~cream
    rows, cols = ink.any(axis=1), ink.any(axis=0)
    if not rows.any():
        return [Image.new("RGBA", (48, 48), (0, 0, 0, 0)) for _ in range(n)]
    y0, y1 = int(np.argmax(rows)), int(im.height - np.argmax(rows[::-1]))
    x0, x1 = int(np.argmax(cols)), int(im.width - np.argmax(cols[::-1]))
    y1 = y0 + int((y1 - y0) * top_frac)
    band = im.crop((x0, y0, x1, y1))
    bw = band.width
    out = []
    for i in range(n):
        left = int(bw * i / n + bw * pad)
        right = int(bw * (i + 1) / n - bw * pad)
        out.append(kill_cream_bg(band.crop((left, 0, max(left + 1, right), band.height))))
    return out


def slice_runs(im: Image.Image) -> list[Image.Image]:
    a = np.array(im.convert("RGBA"))
    bg = ((a[:, :, 0] > 230) & (a[:, :, 1] > 220) & (a[:, :, 2] > 200)) | (a[:, :, 3] < 16)
    cols = (~bg).any(axis=0)
    runs, inr, s = [], False, 0
    for i, v in enumerate(cols):
        if v and not inr:
            s, inr = i, True
        elif not v and inr:
            runs.append((s, i))
            inr = False
    if inr:
        runs.append((s, len(cols)))
    return [kill_cream_bg(im.crop((x0, 0, x1, im.height))) for x0, x1 in runs]


def build_leaves() -> None:
    src = Image.open(GEN / "tea_leaves_sheet_gen.png").convert("RGBA")
    PROMO.mkdir(parents=True, exist_ok=True)
    src.save(PROMO / "tea_leaves_sheet_gen_ref.png")
    parts = slice_runs(src)
    if len(parts) < 5:
        parts = slice_equal(src, 5)
    for i, lid in enumerate(LEAF_IDS):
        save(f"ritual/leaf_{lid}.png", hard_fit(parts[i], 48, 48, 28))


def build_wares() -> None:
    src = Image.open(GEN / "tea_ware_sheet_gen.png").convert("RGBA")
    src.save(PROMO / "tea_ware_sheet_gen_ref.png")
    parts = slice_equal(src, 5, top_frac=0.88)
    for i, wid in enumerate(WARE_IDS):
        save(f"ritual/ware_{wid}.png", hard_fit(parts[i], 48, 48, 26))


def build_brew_steps() -> None:
    src = Image.open(GEN / "tea_brew_steps_gen.png").convert("RGBA")
    src.save(PROMO / "tea_brew_steps_gen_ref.png")
    parts = slice_equal(src, 3, pad=0.01, top_frac=1.0)
    for i, part in enumerate(parts, start=1):
        save(f"ritual/tea_{i}.png", hard_fit(part, 120, 76, 36))


def build_gear() -> None:
    src = Image.open(GEN / "gear_tea_gen.png").convert("RGBA")
    src.save(PROMO / "gear_tea_gen_ref.png")
    save("gear_tea.png", hard_fit(src, 48, 48, 24))


def draw_amounts() -> None:
    for name, n in (("light", 3), ("medium", 6), ("full", 10)):
        im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        px = im.load()
        # bowl
        for y in range(20, 40):
            for x in range(12, 36):
                if abs(x - 24) < 12 - (y - 20) // 3:
                    px[x, y] = (220, 210, 190, 255)
        for i in range(n):
            x, y = 16 + (i % 4) * 4, 24 + (i // 4) * 4
            px[x, y] = (40, 110, 50, 255)
            px[x + 1, y] = (60, 140, 60, 255)
        save(f"ritual/tea_amount_{name}.png", im)


def draw_temps() -> None:
    for c, col in ((80, (120, 180, 210)), (85, (140, 170, 200)), (90, (180, 150, 120)),
                   (95, (210, 120, 90)), (100, (220, 80, 70))):
        im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        px = im.load()
        for y in range(14, 40):
            for x in range(16, 32):
                px[x, y] = (200, 200, 205, 255) if y < 20 else (*col, 255)
        for y in (6, 8, 10):
            px[22, y] = (230, 235, 240, 255)
            px[26, y + 1] = (210, 220, 230, 200)
        save(f"ritual/tea_temp_{c}.png", im)


def draw_steeps() -> None:
    for n in (1, 2, 3, 4):
        im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        px = im.load()
        for i in range(n):
            x0 = 8 + i * 9
            for y in range(18, 36):
                for x in range(x0, x0 + 7):
                    px[x, y] = (240, 230, 210, 255)
            for y in range(22, 32):
                for x in range(x0 + 1, x0 + 6):
                    px[x, y] = (160, 90, 40, 255)
        save(f"ritual/tea_steeps_{n}.png", im)


def draw_rinse() -> None:
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    px = im.load()
    for y in range(16, 38):
        for x in range(14, 34):
            if (x - 24) ** 2 / 90 + (y - 28) ** 2 / 70 <= 1:
                px[x, y] = (230, 225, 215, 255)
    for x in range(18, 30):
        px[x, 14] = (200, 195, 185, 255)
    for y in (8, 10, 12):
        px[20, y] = (180, 210, 230, 255)
        px[28, y + 1] = (180, 210, 230, 200)
    save("ritual/tea_rinse.png", im)


def main() -> int:
    RITUAL.mkdir(parents=True, exist_ok=True)
    print("leaves")
    build_leaves()
    print("wares")
    build_wares()
    print("brew steps")
    build_brew_steps()
    print("gear")
    build_gear()
    print("proc icons")
    draw_amounts()
    draw_temps()
    draw_steeps()
    draw_rinse()
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
