#!/usr/bin/env python3
"""Build cook ritual icons + brew frames from per-item gen (no sheet slice)."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from gen_slice_common import load_gen, quantize_rgba

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "ritual" / "cook"
PROMO = ROOT / "docs" / "promo"

CUISINES = ("bbq", "sushi", "hotpot", "skewer", "stew")
HEATS = ("soft", "mid", "hot")
SEASONS = ("salt", "soy", "citrus")
COOK_STEPS = (
    (1, "cook_step_1_fire_gen.png"),
    (2, "cook_step_2_flip_gen.png"),
    (3, "cook_step_3_plate_gen.png"),
)

ASSET_PROVENANCE = [
    {
        "outputs": "game/assets/ritual/cook/cuisine_{id}.png",
        "sources": "docs/promo/cook_cuisine_{id}_gen_ref.png",
        "variants": {"id": ["bbq", "sushi", "hotpot", "skewer", "stew"]},
        "operation": "chroma_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/cook/heat_{id}.png",
        "sources": "docs/promo/cook_heat_{id}_gen_ref.png",
        "variants": {"id": ["soft", "mid", "hot"]},
        "operation": "background_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/cook/season_{id}.png",
        "sources": "docs/promo/cook_season_{id}_gen_ref.png",
        "variants": {"id": ["salt", "soy", "citrus"]},
        "operation": "background_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/cook/cook_1.png",
        "sources": "docs/promo/cook_step_1_fire_gen_ref.png",
        "operation": "cover_crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/cook/cook_2.png",
        "sources": "docs/promo/cook_step_2_flip_gen_ref.png",
        "operation": "cover_crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/cook/cook_3.png",
        "sources": "docs/promo/cook_step_3_plate_gen_ref.png",
        "operation": "cover_crop + resize + quantize",
    },
]


def kill_chroma_green(im: Image.Image) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    chroma = (g > 140) & (g > r + 40) & (g > b + 40) & (r < 120) & (b < 120)
    pure = (g > 180) & (r < 80) & (b < 80)
    a[chroma | pure, 3] = 0
    return Image.fromarray(a)


def kill_cream(im: Image.Image, thr: int = 236) -> Image.Image:
    a = np.array(im.convert("RGBA"))
    cream = (a[:, :, 0] > thr) & (a[:, :, 1] > thr - 10) & (a[:, :, 2] > thr - 24)
    a[cream, 3] = 0
    return Image.fromarray(a)


def icon_fit(im: Image.Image, tw: int = 48, th: int = 48, colors: int = 28) -> Image.Image:
    """Contain-fit after chroma/cream knock — keep subject fully in frame."""
    rgba = kill_cream(kill_chroma_green(im), thr=236)
    arr = np.array(rgba)
    ys, xs = np.where(arr[:, :, 3] > 20)
    if len(xs) == 0:
        return Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    crop = rgba.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    pad = max(2, min(crop.width, crop.height) // 14)
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


def brew_fit(im: Image.Image, tw: int = 160, th: int = 120, colors: int = 40) -> Image.Image:
    """Cover-crop into filled 4:3 — no 120×76 letterbox from sheet panels."""
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


def build_named(prefix: str, ids: tuple[str, ...], gen_prefix: str) -> None:
    PROMO.mkdir(parents=True, exist_ok=True)
    for iid in ids:
        stem = f"{gen_prefix}_{iid}_gen.png"
        raw = load_gen(stem, f"{gen_prefix}_{iid}_gen_ref.png")
        icon = icon_fit(raw)
        opaque = (np.array(icon)[:, :, 3] > 20).sum()
        if opaque < 180:
            raise SystemExit(f"{prefix}_{iid} too sparse opaque={opaque}")
        save(f"{prefix}_{iid}.png", icon)


def build_cook_steps() -> None:
    PROMO.mkdir(parents=True, exist_ok=True)
    for i, name in COOK_STEPS:
        raw = load_gen(name, name.replace(".png", "_ref.png"))
        save(f"cook_{i}.png", brew_fit(raw))


def main() -> int:
    print("cuisines (per-item chroma)")
    build_named("cuisine", CUISINES, "cook_cuisine")
    print("heats (per-item)")
    build_named("heat", HEATS, "cook_heat")
    print("seasons (per-item)")
    build_named("season", SEASONS, "cook_season")
    print("cook steps (per-item 160x120)")
    build_cook_steps()
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
