#!/usr/bin/env python3
"""Build fishing ritual frames from per-item gen (no sheet slice, no characters)."""
from __future__ import annotations

from pathlib import Path

from gen_slice_common import load_gen, quantize_rgba
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
FISH_DIR = ASSETS / "ritual" / "fish"
WORLD = ASSETS / "scenes" / "forest" / "world"
PROMO = ROOT / "docs" / "promo"

# cast → wait → bite → catch / miss
FRAMES = (
    ("fish_1.png", "fish_step_1_cast_gen.png"),
    ("fish_2.png", "fish_step_2_wait_gen.png"),
    ("fish_3.png", "fish_step_3_bite_gen.png"),
    ("fish_4.png", "fish_step_4_catch_gen.png"),
    ("fish_4_miss.png", "fish_step_4_miss_gen.png"),
)

ASSET_PROVENANCE = [
    {"outputs": "game/assets/ritual/fish/fish_1.png", "sources": "docs/promo/fish_step_1_cast_gen_ref.png", "operation": "cover_crop + resize + quantize"},
    {"outputs": "game/assets/ritual/fish/fish_2.png", "sources": "docs/promo/fish_step_2_wait_gen_ref.png", "operation": "cover_crop + resize + quantize"},
    {"outputs": "game/assets/ritual/fish/fish_3.png", "sources": "docs/promo/fish_step_3_bite_gen_ref.png", "operation": "cover_crop + resize + quantize"},
    {"outputs": "game/assets/ritual/fish/fish_4.png", "sources": "docs/promo/fish_step_4_catch_gen_ref.png", "operation": "cover_crop + resize + quantize"},
    {"outputs": "game/assets/ritual/fish/fish_4_miss.png", "sources": "docs/promo/fish_step_4_miss_gen_ref.png", "operation": "cover_crop + resize + quantize"},
]


def brew_fit(im: Image.Image, tw: int = 160, th: int = 120, colors: int = 40) -> Image.Image:
    """Cover-crop into filled 4:3 — no 120×76 sheet panels."""
    rgba = im.convert("RGBA")
    scale = max(tw / rgba.width, th / rgba.height)
    nw = max(tw, int(round(rgba.width * scale)))
    nh = max(th, int(round(rgba.height * scale)))
    mid = rgba.resize((max(4, nw // 2), max(4, nh // 2)), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    x0 = max(0, (nw - tw) // 2)
    y0 = max(0, (nh - th) // 2)
    return quantize_rgba(scaled.crop((x0, y0, x0 + tw, y0 + th)), colors)


def save(rel: Path, im: Image.Image) -> None:
    rel.parent.mkdir(parents=True, exist_ok=True)
    im.save(rel)
    print(f"  {rel.relative_to(ROOT)} {im.size}")


def main() -> int:
    print("fish ritual frames (per-item, no character)")
    PROMO.mkdir(parents=True, exist_ok=True)
    FISH_DIR.mkdir(parents=True, exist_ok=True)
    for out_name, gen_name in FRAMES:
        raw = load_gen(gen_name, gen_name.replace(".png", "_ref.png"))
        save(FISH_DIR / out_name, brew_fit(raw))

    for name in ("fruit_icon.png", "fish_icon_ayu.png", "fish_icon_trout.png", "fish_icon_carp.png"):
        path = WORLD / name
        if path.is_file():
            print(f"  keep {path.relative_to(ROOT)}")
        else:
            print(f"  WARN missing {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
