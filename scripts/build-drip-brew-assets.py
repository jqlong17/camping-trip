#!/usr/bin/env python3
"""Build drip-brew pixel icons from gen sheets + procedural grind/temp markers."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
RITUAL = ASSETS / "ritual"
PROMO = ROOT / "docs" / "promo"
GEN_DRIP = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets/dripper_sheet_gen.png")
GEN_BEAN = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets/coffee_beans_sheet_gen.png")

DRIPPER_IDS = ["v60", "kalita", "single", "origami", "metal"]
BEAN_IDS = ["ethiopia", "peru", "colombia", "kenya", "brazil"]


def quantize_rgba(im: Image.Image, colors: int = 28) -> Image.Image:
    rgba = im.convert("RGBA")
    a = rgba.split()[-1]
    q = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = q.convert("RGBA")
    out.putalpha(a)
    return out


def hard_fit(im: Image.Image, tw: int, th: int, colors: int = 28) -> Image.Image:
    rgba = im.convert("RGBA")
    arr = np.array(rgba)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    crop = rgba.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    # mid bilinear then nearest for hard pixels
    mid = crop.resize((tw * 2, th * 2), Image.Resampling.BILINEAR)
    mid = mid.resize((tw, th), Image.Resampling.NEAREST)
    return quantize_rgba(mid, colors)


def kill_cream_bg(im: Image.Image, thr: int = 228) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    cream = (a[:, :, 0] > thr) & (a[:, :, 1] > thr - 8) & (a[:, :, 2] > thr - 20)
    a[cream, 3] = 0
    return Image.fromarray(a)


def save(rel: str, im: Image.Image) -> None:
    if str(rel).startswith("ritual/"):
        parts = Path(rel).parts
        path = RITUAL.joinpath(*parts[1:]) if len(parts) >= 3 else RITUAL / "drip" / Path(rel).name
    else:
        path = ASSETS / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def slice_equal(im: Image.Image, n: int, pad: float = 0.02) -> list[Image.Image]:
    w, h = im.size
    # trim top/bottom empty-ish
    a = np.array(im.convert("RGBA"))
    ink = a[:, :, 3] > 16
    rows = ink.any(axis=1)
    cols = ink.any(axis=0)
    if not rows.any():
        return [Image.new("RGBA", (64, 64), (0, 0, 0, 0)) for _ in range(n)]
    y0, y1 = int(np.argmax(rows)), int(h - np.argmax(rows[::-1]))
    x0, x1 = int(np.argmax(cols)), int(w - np.argmax(cols[::-1]))
    # drop bottom wood shelf if present: keep upper 78%
    y1 = y0 + int((y1 - y0) * 0.82)
    band = im.crop((x0, y0, x1, y1))
    bw = band.width
    out = []
    for i in range(n):
        left = int(bw * i / n + bw * pad)
        right = int(bw * (i + 1) / n - bw * pad)
        out.append(kill_cream_bg(band.crop((left, 0, right, band.height))))
    return out


def slice_runs(im: Image.Image) -> list[Image.Image]:
    a = np.array(im.convert("RGBA"))
    bg = ((a[:, :, 0] > 230) & (a[:, :, 1] > 220) & (a[:, :, 2] > 200)) | (a[:, :, 3] < 16)
    ink = ~bg
    cols = ink.any(axis=0)
    runs = []
    inr = False
    s = 0
    for i, v in enumerate(cols):
        if v and not inr:
            s = i
            inr = True
        elif not v and inr:
            runs.append((s, i))
            inr = False
    if inr:
        runs.append((s, len(cols)))
    out = []
    for x0, x1 in runs:
        out.append(kill_cream_bg(im.crop((x0, 0, x1, im.height))))
    return out


def build_drippers() -> None:
    src = Image.open(GEN_DRIP).convert("RGBA")
    PROMO.mkdir(parents=True, exist_ok=True)
    src.save(PROMO / "dripper_sheet_gen_ref.png")
    parts = slice_equal(src, 5)
    for i, pid in enumerate(DRIPPER_IDS):
        icon = hard_fit(parts[i], 48, 48, 26)
        save(f"ritual/dripper_{pid}.png", icon)


def build_beans() -> None:
    src = Image.open(GEN_BEAN).convert("RGBA")
    PROMO.mkdir(parents=True, exist_ok=True)
    src.save(PROMO / "coffee_beans_sheet_gen_ref.png")
    parts = slice_runs(src)
    if len(parts) < 5:
        parts = slice_equal(src, 5)
    for i, bid in enumerate(BEAN_IDS):
        icon = hard_fit(parts[i], 48, 48, 28)
        save(f"ritual/bean_{bid}.png", icon)


def draw_grind_icons() -> None:
    # fine / medium / coarse — coffee particle density
    for name, dens, size in (("fine", 18, 1), ("medium", 10, 2), ("coarse", 6, 3)):
        im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        px = im.load()
        # mill body
        for y in range(8, 40):
            for x in range(14, 34):
                px[x, y] = (90, 70, 48, 255) if (x in (14, 33) or y in (8, 39)) else (150, 118, 78, 255)
        # crank
        for x in range(34, 42):
            px[x, 18] = (70, 70, 70, 255)
        px[41, 16] = (70, 70, 70, 255)
        px[41, 17] = (70, 70, 70, 255)
        # grounds
        step = max(2, 8 - dens // 3)
        for y in range(28, 44, size + 1):
            for x in range(8, 40, step):
                if (x + y) % 3 != dens % 3:
                    continue
                for dy in range(size):
                    for dx in range(size):
                        if 0 <= x + dx < 48 and 0 <= y + dy < 48:
                            px[x + dx, y + dy] = (72, 48, 28, 255)
        save(f"ritual/grind_{name}.png", im)


def draw_temp_icons() -> None:
    for name, fill, steam in (("92", (120, 170, 210), True), ("100", (220, 90, 70), True)):
        im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        px = im.load()
        # kettle
        for y in range(16, 40):
            for x in range(10, 36):
                if (x - 23) ** 2 / 140 + (y - 28) ** 2 / 90 <= 1:
                    px[x, y] = (200, 200, 205, 255) if y < 22 else (*fill, 255)
        for x in range(30, 42):
            px[x, 22] = (160, 160, 165, 255)
        if steam:
            for y, x in ((8, 20), (6, 24), (9, 28)):
                px[x, y] = (220, 230, 240, 255)
                px[x, y + 1] = (200, 210, 220, 180)
        save(f"ritual/temp_{name}.png", im)


def draw_pours_icons() -> None:
    for n in (2, 3, 4):
        im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        px = im.load()
        # cup
        for y in range(22, 40):
            for x in range(14, 34):
                px[x, y] = (240, 235, 220, 255)
        for y in range(26, 36):
            for x in range(16, 32):
                px[x, y] = (92, 58, 32, 255)
        # pour arcs
        for i in range(n):
            x0 = 10 + i * 8
            for t in range(10):
                x = x0 + t // 2
                y = 6 + t
                if 0 <= x < 48 and 0 <= y < 48:
                    px[x, y] = (140, 190, 220, 255)
        save(f"ritual/pours_{n}.png", im)


def draw_paper_icon() -> None:
    im = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
    px = im.load()
    # cone paper
    for y in range(8, 40):
        w = 4 + (y - 8)
        cx = 24
        for x in range(cx - w, cx + w + 1):
            if 0 <= x < 48:
                edge = abs(x - cx) >= w - 1
                px[x, y] = (210, 200, 180, 255) if not edge else (120, 100, 70, 255)
    # crease
    for y in range(10, 38):
        px[24, y] = (170, 155, 130, 255)
    save("ritual/drip_paper.png", im)


def main() -> int:
    RITUAL.mkdir(parents=True, exist_ok=True)
    print("drippers")
    build_drippers()
    print("beans")
    build_beans()
    print("grind/temp/pours/paper")
    draw_grind_icons()
    draw_temp_icons()
    draw_pours_icons()
    draw_paper_icon()
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
