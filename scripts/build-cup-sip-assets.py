#!/usr/bin/env python3
"""Build cup-sip focus icons + brew frames from per-item gen (no sheet guess)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from gen_slice_common import load_gen, quantize_rgba

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "ritual" / "cup"
PROMO = ROOT / "docs" / "promo"

FOCUS_IDS = ("nose", "mouth", "after")
SIP_STEPS = (
    (1, "cup_sip_1_mug_raise_gen.png"),
    (2, "cup_sip_2_mug_drink_gen.png"),
    (3, "cup_sip_3_mug_rest_gen.png"),
)

ASSET_PROVENANCE = [
    {
        "outputs": "game/assets/ritual/cup/focus_{id}.png",
        "sources": "docs/promo/cup_focus_{id}_gen_ref.png",
        "variants": {"id": ["nose", "mouth", "after"]},
        "operation": "background_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/cup/sip_1.png",
        "sources": "docs/promo/cup_sip_1_mug_raise_gen_ref.png",
        "operation": "cover_crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/cup/sip_2.png",
        "sources": "docs/promo/cup_sip_2_mug_drink_gen_ref.png",
        "operation": "cover_crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/cup/sip_3.png",
        "sources": "docs/promo/cup_sip_3_mug_rest_gen_ref.png",
        "operation": "cover_crop + resize + quantize",
    },
]


def kill_cream(im: Image.Image, thr: int = 228) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    cream = (a[:, :, 0] > thr) & (a[:, :, 1] > thr - 10) & (a[:, :, 2] > thr - 24)
    a[cream, 3] = 0
    return Image.fromarray(a)


def icon_fit(im: Image.Image, tw: int = 48, th: int = 48, colors: int = 28) -> Image.Image:
    """Contain-fit after cream-only knock; keep thin steam/outline (no kill_bg)."""
    rgba = kill_cream(im, thr=236)
    arr = np.array(rgba)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    crop = rgba.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    # pad so thin steam survives downscale
    pad = max(2, min(crop.width, crop.height) // 16)
    padded = Image.new("RGBA", (crop.width + pad * 2, crop.height + pad * 2), (0, 0, 0, 0))
    padded.alpha_composite(crop, (pad, pad))
    scale = min((tw - 2) / padded.width, (th - 2) / padded.height)
    nw = max(1, int(round(padded.width * scale)))
    nh = max(1, int(round(padded.height * scale)))
    # gentler mid step than ½ — preserve silhouette
    mid = padded.resize((max(nw, nw * 2), max(nh, nh * 2)), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    scaled = quantize_rgba(scaled, colors)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.alpha_composite(scaled, ((tw - nw) // 2, (th - nh) // 2))
    return canvas


def brew_fit(im: Image.Image, tw: int = 160, th: int = 120, colors: int = 40) -> Image.Image:
    """Cover-crop into filled 4:3 — no letterbox / top-half packing."""
    rgba = im.convert("RGBA")
    scale = max(tw / rgba.width, th / rgba.height)
    nw = max(tw, int(round(rgba.width * scale)))
    nh = max(th, int(round(rgba.height * scale)))
    mid = rgba.resize((max(4, nw // 2), max(4, nh // 2)), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    x0 = max(0, (nw - tw) // 2)
    y0 = max(0, (nh - th) // 2)
    return quantize_rgba(scaled.crop((x0, y0, x0 + tw, y0 + th)), colors)


def save(name: str, im: Image.Image) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def build_focuses() -> None:
    PROMO.mkdir(parents=True, exist_ok=True)
    for fid in FOCUS_IDS:
        stem = f"cup_focus_{fid}_gen.png"
        raw = load_gen(stem, f"cup_focus_{fid}_gen_ref.png")
        icon = icon_fit(raw)
        save(f"focus_{fid}.png", icon)


def build_sip_frames() -> None:
    PROMO.mkdir(parents=True, exist_ok=True)
    for i, name in SIP_STEPS:
        raw = load_gen(name, name.replace(".png", "_ref.png"))
        save(f"sip_{i}.png", brew_fit(raw))


def main() -> int:
    print("cup focus icons")
    build_focuses()
    print("cup sip frames")
    build_sip_frames()
    # orphaned after DEV-075 — do not regenerate sip_size_*
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
