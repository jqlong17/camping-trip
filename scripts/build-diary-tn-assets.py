#!/usr/bin/env python3
"""Build TN-style diary desk + open notebook from text-to-image → home/story.

手帐本子必须用 **纯绿幕** 文生图：只抠 chroma green，切勿用 cream 掩码
（否则奶油纸页会被当成背景扣光，只剩书脊线框）。
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from gen_slice_common import load_gen, quantize_rgba

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "scenes" / "home" / "story"
GEN = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")
PROMO = ROOT / "docs" / "promo"


def hard_cover(im: Image.Image, tw: int, th: int, colors: int = 44) -> Image.Image:
    src = im.convert("RGBA")
    scale = max(tw / src.width, th / src.height)
    nw, nh = int(src.width * scale), int(src.height * scale)
    mid = src.resize((max(8, nw // 2), max(8, nh // 2)), Image.Resampling.BILINEAR)
    big = mid.resize((nw, nh), Image.Resampling.NEAREST)
    covered = Image.new("RGBA", (tw, th), (40, 32, 24, 255))
    covered.alpha_composite(big, ((tw - nw) // 2, (th - nh) // 2))
    small = covered.resize((tw // 2, th // 2), Image.Resampling.BILINEAR)
    return quantize_rgba(small.resize((tw, th), Image.Resampling.NEAREST), colors)


def kill_chroma_green(im: Image.Image) -> Image.Image:
    """Only remove chroma-key green (#00FF00 family). Keep cream page paper."""
    a = np.array(im.convert("RGBA"))
    r = a[:, :, 0].astype(int)
    g = a[:, :, 1].astype(int)
    b = a[:, :, 2].astype(int)
    # strong green key: G high, R/B low relative to G
    chroma = (g > 140) & (g > r + 40) & (g > b + 40) & (r < 120) & (b < 120)
    # also near-pure #00FF00 / #00CC00
    pure = (g > 180) & (r < 80) & (b < 80)
    a[chroma | pure, 3] = 0
    return Image.fromarray(a)


def subject_crop_alpha(im: Image.Image, pad: int = 2) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    ys, xs = np.where(a[:, :, 3] > 20)
    if len(xs) == 0:
        return im
    x0 = max(0, int(xs.min()) - pad)
    x1 = min(im.width, int(xs.max()) + 1 + pad)
    y0 = max(0, int(ys.min()) - pad)
    y1 = min(im.height, int(ys.max()) + 1 + pad)
    return Image.fromarray(a).crop((x0, y0, x1, y1))


def hard_fit_alpha(im: Image.Image, tw: int, th: int, colors: int = 32) -> Image.Image:
    crop = subject_crop_alpha(im)
    scale = min((tw - 2) / max(1, crop.width), (th - 2) / max(1, crop.height))
    nw = max(1, int(round(crop.width * scale)))
    nh = max(1, int(round(crop.height * scale)))
    mid = crop.resize((max(4, nw // 2), max(4, nh // 2)), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    scaled = quantize_rgba(scaled, colors)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def to_pot(content_400x240: Image.Image, colors: int = 48) -> Image.Image:
    pot = Image.new("RGBA", (512, 256), (38, 46, 36, 255))
    pot.paste(content_400x240.convert("RGBA"), (0, 0))
    return quantize_rgba(pot, colors)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    PROMO.mkdir(parents=True, exist_ok=True)

    desk = load_gen("diary_desk_gen.png", "diary_desk_gen_ref.png")
    desk_px = hard_cover(desk, 400, 240, 44)
    desk_pot = to_pot(desk_px, 48)
    desk_pot.save(OUT / "diary_desk.png")
    print(f"  diary_desk.png {desk_pot.size}")

    gen_tn = GEN / "diary_tn_open_gen.png"
    if not gen_tn.is_file():
        raise SystemExit(f"missing {gen_tn}")
    raw = Image.open(gen_tn).convert("RGBA")
    raw.save(PROMO / "diary_tn_open_gen_ref.png")
    tn_src = kill_chroma_green(raw)
    opaque = int((np.array(tn_src)[:, :, 3] > 20).sum())
    if opaque < 8000:
        raise SystemExit(f"diary_tn too sparse after chroma kill opaque={opaque} — check green key")
    tn_px = hard_fit_alpha(tn_src, 120, 210, 32)
    tn_px.save(OUT / "diary_tn.png")
    print(f"  diary_tn.png {tn_px.size} opaque_src={opaque}")

    page = desk_px.copy()
    ox = (400 - tn_px.width) // 2 - 24
    oy = max(4, (240 - tn_px.height) // 2)
    page.alpha_composite(tn_px, (ox, oy))
    to_pot(page, 48).save(OUT / "diary.png")
    print("  diary.png composite fallback 512x256")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
