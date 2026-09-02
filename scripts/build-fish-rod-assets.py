#!/usr/bin/env python3
"""Build fishing choice icons (48×48) from text-to-image sheets → ritual/fish/."""
from __future__ import annotations

from pathlib import Path

from gen_slice_common import hard_fit, load_gen, slice_equal, slice_runs

ROOT = Path(__file__).resolve().parents[1]
FISH_DIR = ROOT / "game" / "assets" / "ritual" / "fish"

SPOTS = ["shoal", "pool", "pier", "weed", "rapids"]
BAITS = ["worm", "dough", "lure", "bug", "corn"]
SINKERS = ["light", "mid", "heavy"]
STYLES = ["wait", "twitch", "dance"]

ASSET_PROVENANCE = [
    {
        "outputs": "game/assets/ritual/fish/spot_*.png",
        "sources": "docs/promo/fish_spots_v2_sheet_gen_ref.png",
        "operation": "slice_runs + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/fish/bait_*.png",
        "sources": "docs/promo/fish_baits_sheet_gen_ref.png",
        "operation": "slice_runs + crop + resize + quantize",
    },
    {
        "outputs": ["game/assets/ritual/fish/sinker_*.png", "game/assets/ritual/fish/style_*.png"],
        "sources": "docs/promo/fish_sinkers_styles_sheet_gen_ref.png",
        "operation": "slice_runs + crop + resize + quantize",
    },
]


def save(name: str, im) -> None:
    FISH_DIR.mkdir(parents=True, exist_ok=True)
    path = FISH_DIR / name
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def parts_or_equal(im, n: int):
    runs = slice_runs(im)
    if len(runs) == n:
        return runs
    return slice_equal(im, n, pad=0.05)


def main() -> int:
    print("fish choice icons from gen → ritual/fish/")
    spots = parts_or_equal(load_gen("fish_spots_v2_sheet_gen.png"), 5)
    for sid, cell in zip(SPOTS, spots):
        save(f"spot_{sid}.png", hard_fit(cell, 48, 48, 28))

    baits = parts_or_equal(load_gen("fish_baits_sheet_gen.png"), 5)
    for bid, cell in zip(BAITS, baits):
        save(f"bait_{bid}.png", hard_fit(cell, 48, 48, 24))

    ss = parts_or_equal(load_gen("fish_sinkers_styles_sheet_gen.png"), 6)
    for sid, cell in zip(SINKERS, ss[:3]):
        save(f"sinker_{sid}.png", hard_fit(cell, 48, 48, 20))
    for sid, cell in zip(STYLES, ss[3:]):
        save(f"style_{sid}.png", hard_fit(cell, 48, 48, 24))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
