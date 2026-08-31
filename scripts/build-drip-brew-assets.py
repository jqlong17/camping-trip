#!/usr/bin/env python3
"""Build drip-brew pixel icons from gen sheets + procedural pours/paper markers."""
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


def kill_chroma_green(im: Image.Image) -> Image.Image:
    """Remove pure chroma-key green only — do not touch brown coffee grounds."""
    a = np.array(im.convert("RGBA"))
    r = a[:, :, 0].astype(int)
    g = a[:, :, 1].astype(int)
    b = a[:, :, 2].astype(int)
    chroma = (g > 140) & (g > r + 40) & (g > b + 40) & (r < 120) & (b < 120)
    pure = (g > 180) & (r < 80) & (b < 80)
    a[chroma | pure, 3] = 0
    return Image.fromarray(a)


def icon_fit_alpha(im: Image.Image, tw: int = 48, th: int = 48, colors: int = 32) -> Image.Image:
    """Contain-fit after alpha crop — no cream/kill_bg that eats ground highlights."""
    arr = np.array(im.convert("RGBA"))
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    crop = Image.fromarray(arr).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    pad = max(2, min(crop.width, crop.height) // 16)
    padded = Image.new("RGBA", (crop.width + pad * 2, crop.height + pad * 2), (0, 0, 0, 0))
    padded.alpha_composite(crop, (pad, pad))
    scale = min((tw - 2) / padded.width, (th - 2) / padded.height)
    nw = max(1, int(round(padded.width * scale)))
    nh = max(1, int(round(padded.height * scale)))
    mid = padded.resize((max(nw * 2, 4), max(nh * 2, 4)), Image.Resampling.BILINEAR)
    scaled = quantize_rgba(mid.resize((nw, nh), Image.Resampling.NEAREST), colors)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def draw_grind_icons() -> None:
    """Fine / medium / coarse — per-item gen on chroma green (no sheet cream kill)."""
    assets_dir = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")
    PROMO.mkdir(parents=True, exist_ok=True)
    for name in ("fine", "medium", "coarse"):
        gen = assets_dir / f"drip_grind_{name}_gen.png"
        if not gen.is_file():
            raise FileNotFoundError(f"missing grind gen: {gen}")
        raw = Image.open(gen).convert("RGBA")
        raw.save(PROMO / f"drip_grind_{name}_gen_ref.png")
        keyed = kill_chroma_green(raw)
        # drop leftover cream card if gen put subject on a paper square
        a = np.array(keyed)
        cream = (a[:, :, 0] > 230) & (a[:, :, 1] > 220) & (a[:, :, 2] > 200) & (
            a[:, :, 0].astype(int) - a[:, :, 2].astype(int) < 45
        )
        a[cream, 3] = 0
        icon = icon_fit_alpha(Image.fromarray(a), 48, 48, 32)
        opaque = (np.array(icon)[:, :, 3] > 20).sum()
        if opaque < 200:
            raise SystemExit(f"grind_{name} too sparse opaque={opaque} after chroma")
        save(f"ritual/grind_{name}.png", icon)


def brew_fit(
    im: Image.Image, tw: int = 160, th: int = 120, colors: int = 40, y_bias: float = -0.12
) -> Image.Image:
    """Cover-crop into 4:3. Negative y_bias keeps more sky so action sits lower."""
    rgba = kill_cream_bg(im.convert("RGBA"), thr=232)
    scale = max(tw / rgba.width, th / rgba.height)
    nw = max(tw, int(round(rgba.width * scale)))
    nh = max(th, int(round(rgba.height * scale)))
    mid = rgba.resize((max(4, nw // 2), max(4, nh // 2)), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    x0 = max(0, (nw - tw) // 2)
    y0 = max(0, min(nh - th, (nh - th) // 2 + int(th * y_bias)))
    return quantize_rgba(scaled.crop((x0, y0, x0 + tw, y0 + th)), colors)


def build_brew_steps() -> None:
    """Rebuild drip_1..3 as filled 160×120 (old 128² kept art in the top 76px)."""
    PROMO.mkdir(parents=True, exist_ok=True)
    for i in (1, 2, 3):
        src = PROMO / f"drip_pixel_{i}.png"
        if not src.is_file():
            raise FileNotFoundError(f"missing brew frame promo: {src}")
        save(f"ritual/drip_{i}.png", brew_fit(Image.open(src)))


def draw_temp_icons() -> None:
    """92 / 100 kettle icons from text-to-image (no ImageDraw bodies).

    Old PIL blue kettle vanished on the selected yellow choice slot; gen
    icons keep high-contrast metal + cool/hot cue on cream then kill_cream.
    """
    assets_dir = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")
    PROMO.mkdir(parents=True, exist_ok=True)
    for name in ("92", "100"):
        gen = assets_dir / f"drip_temp_{name}_gen.png"
        if not gen.is_file():
            raise FileNotFoundError(f"missing temp gen: {gen}")
        raw = Image.open(gen).convert("RGBA")
        raw.save(PROMO / f"drip_temp_{name}_gen_ref.png")
        icon = hard_fit(kill_cream_bg(raw), 48, 48, 26)
        # reinforce alpha if cream bleed survived hard_fit upsample
        icon = kill_cream_bg(icon, thr=232)
        save(f"ritual/temp_{name}.png", icon)


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
    print("brew steps")
    build_brew_steps()
    print("grind/temp/pours/paper")
    draw_grind_icons()
    draw_temp_icons()
    draw_pours_icons()
    draw_paper_icon()
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
