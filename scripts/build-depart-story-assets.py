#!/usr/bin/env python3
"""Build crisp 400×240 story frames (depart d1/d2) → POT 512×256, nearest only."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from gen_slice_common import load_gen, quantize_rgba

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "scenes" / "forest" / "story"
PROMO = ROOT / "docs" / "promo"
GEN = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")

FRAMES = (
    ("story_d1_path_distinct_gen.png", "story_d1_path_distinct_gen_ref.png", "d1.png"),
    ("story_d2_arrive_distinct_gen.png", "story_d2_arrive_distinct_gen_ref.png", "d2.png"),
)

ASSET_PROVENANCE = [
    {
        "outputs": "game/assets/scenes/forest/story/d1.png",
        "sources": "docs/promo/story_d1_path_distinct_gen_ref.png",
        "operation": "cover_crop + resize + quantize",
    },
    {
        "outputs": "game/assets/scenes/forest/story/d2.png",
        "sources": "docs/promo/story_d2_arrive_distinct_gen_ref.png",
        "operation": "cover_crop + resize + quantize",
    },
]


def hard_screen(im: Image.Image, tw: int = 400, th: int = 240, colors: int = 48) -> Image.Image:
    """Cover-crop to screen size with nearest — no bilinear blur into final pixels."""
    rgba = im.convert("RGBA")
    scale = max(tw / rgba.width, th / rgba.height)
    nw = max(tw, int(round(rgba.width * scale)))
    nh = max(th, int(round(rgba.height * scale)))
    # two-step: mild mid then nearest to final (hard pixels)
    mid = rgba.resize((max(8, nw // 2), max(8, nh // 2)), Image.Resampling.BILINEAR)
    big = mid.resize((nw, nh), Image.Resampling.NEAREST)
    x0 = max(0, (nw - tw) // 2)
    y0 = max(0, (nh - th) // 2)
    crop = big.crop((x0, y0, x0 + tw, y0 + th))
    return quantize_rgba(crop, colors)


def to_pot(content: Image.Image) -> Image.Image:
    pot = Image.new("RGBA", (512, 256), (0, 0, 0, 255))
    pot.paste(content.convert("RGBA"), (0, 0))
    return pot


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    PROMO.mkdir(parents=True, exist_ok=True)
    for gen_name, promo_name, out_name in FRAMES:
        src = GEN / gen_name
        if not src.is_file():
            raise SystemExit(f"missing {src}")
        raw = load_gen(gen_name, promo_name)
        frame = hard_screen(raw, 400, 240, 48)
        pot = to_pot(frame)
        path = OUT / out_name
        pot.save(path)
        print(f"  {path.relative_to(ROOT)} {pot.size} content=400x240")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
