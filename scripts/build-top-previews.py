#!/usr/bin/env python3
"""Build 320×180 TOP-screen previews directly from high-resolution sources.

Catalog icons remain 48×48/48×40 for bottom-screen lists.  This builder never
uses those icons as input, so runtime previews are not enlarged thumbnails.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from gen_slice_common import (
    PROMO,
    chroma_key_fit,
    slice_equal,
    slice_grid,
    slice_runs,
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "previews"
PREVIEW_W, PREVIEW_H = 320, 180

ASSET_PROVENANCE = [
    {
        "outputs": "game/assets/previews/ritual/drip/bean_{id}.png",
        "sources": "docs/promo/coffee_beans_sheet_gen_ref.png",
        "variants": {"id": ["ethiopia", "peru", "colombia", "kenya", "brazil"]},
        "operation": "source_direct slice_runs + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/drip/dripper_{id}.png",
        "sources": "docs/promo/dripper_{id}_chroma_gen_ref.png",
        "variants": {"id": ["v60", "kalita", "single", "origami", "metal"]},
        "operation": "source_direct CKE + contain_downscale_320x180 + 3px_safety_margin + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/drip/grind_{id}.png",
        "sources": "docs/promo/drip_grind_{id}_gen_ref.png",
        "variants": {"id": ["fine", "medium", "coarse"]},
        "operation": "source_direct CKE + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/drip/temp_{id}.png",
        "sources": "docs/promo/drip_temp_{id}_gen_ref.png",
        "variants": {"id": ["92", "100"]},
        "operation": "source_direct background_key + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/drip/paper.png",
        "sources": "docs/promo/drip_paper_chroma_gen_ref.png",
        "operation": "source_direct CKE + contain_downscale_320x180 + 3px_safety_margin + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/drip/pours_{id}.png",
        "sources": "docs/promo/drip_pours_{id}_chroma_gen_ref.png",
        "variants": {"id": [2, 3, 4]},
        "operation": "source_direct CKE + contain_downscale_320x180 + 3px_safety_margin + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/drip/drip_{id}.png",
        "sources": "docs/promo/drip_pixel_{id}.png",
        "variants": {"id": [1, 2, 3]},
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/fish/spot_*.png",
        "sources": "docs/promo/fish_spots_v2_sheet_gen_ref.png",
        "operation": "source_direct slice_runs + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/fish/bait_*.png",
        "sources": "docs/promo/fish_baits_sheet_gen_ref.png",
        "operation": "source_direct slice_runs + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": [
            "game/assets/previews/ritual/fish/sinker_*.png",
            "game/assets/previews/ritual/fish/style_*.png",
        ],
        "sources": "docs/promo/fish_sinkers_styles_sheet_gen_ref.png",
        "operation": "source_direct slice_runs + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/fish/fish_1.png",
        "sources": "docs/promo/fish_step_1_cast_gen_ref.png",
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/fish/fish_2.png",
        "sources": "docs/promo/fish_step_2_wait_gen_ref.png",
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/fish/fish_3.png",
        "sources": "docs/promo/fish_step_3_bite_gen_ref.png",
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/fish/fish_4.png",
        "sources": "docs/promo/fish_step_4_catch_gen_ref.png",
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/fish/fish_4_miss.png",
        "sources": "docs/promo/fish_step_4_miss_gen_ref.png",
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/cup/focus_{id}.png",
        "sources": "docs/promo/cup_focus_{id}_chroma_gen_ref.png",
        "variants": {"id": ["nose", "mouth", "after"]},
        "operation": "source_direct CKE + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/cup/sip_1.png",
        "sources": "docs/promo/cup_sip_1_mug_raise_gen_ref.png",
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/cup/sip_2.png",
        "sources": "docs/promo/cup_sip_2_mug_drink_gen_ref.png",
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/cup/sip_3.png",
        "sources": "docs/promo/cup_sip_3_mug_rest_gen_ref.png",
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/cook/cuisine_*.png",
        "sources": [
            "docs/promo/cook_cuisine_bbq_gen_ref.png",
            "docs/promo/cook_cuisine_sushi_gen_ref.png",
            "docs/promo/cook_cuisine_hotpot_gen_ref.png",
            "docs/promo/cook_cuisine_skewer_gen_ref.png",
            "docs/promo/cook_cuisine_stew_gen_ref.png",
        ],
        "operation": "source_direct CKE/background_key + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/cook/heat_*.png",
        "sources": [
            "docs/promo/cook_heat_soft_gen_ref.png",
            "docs/promo/cook_heat_mid_gen_ref.png",
            "docs/promo/cook_heat_hot_gen_ref.png",
        ],
        "operation": "source_direct CKE/background_key + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/ritual/cook/season_*.png",
        "sources": [
            "docs/promo/cook_season_salt_gen_ref.png",
            "docs/promo/cook_season_soy_gen_ref.png",
            "docs/promo/cook_season_citrus_gen_ref.png",
        ],
        "operation": "source_direct CKE/background_key + contain_downscale_320x180 + quantize",
    },
    {
        "outputs": [
            "game/assets/previews/ritual/cook/cook_1.png",
            "game/assets/previews/ritual/cook/cook_2.png",
            "game/assets/previews/ritual/cook/cook_3.png",
        ],
        "sources": [
            "docs/promo/cook_step_1_fire_gen_ref.png",
            "docs/promo/cook_step_2_flip_gen_ref.png",
            "docs/promo/cook_step_3_plate_gen_ref.png",
        ],
        "operation": "source_direct cover_downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/codex/tent.png",
        "sources": "docs/promo/tents_pitch_shut_sheet_gen_ref.png",
        "operation": "source_direct representative_crop + downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/codex/drip.png",
        "sources": "docs/promo/dripper_v60_chroma_gen_ref.png",
        "operation": "source_direct CKE + representative_downscale_320x180 + 3px_safety_margin + quantize",
    },
    {
        "outputs": "game/assets/previews/codex/rod.png",
        "sources": "docs/promo/fish_step_1_cast_gen_ref.png",
        "operation": "source_direct representative_crop + downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/codex/cup.png",
        "sources": "docs/promo/cup_sip_1_mug_raise_gen_ref.png",
        "operation": "source_direct representative_crop + downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/codex/cook.png",
        "sources": "docs/promo/cook_step_1_fire_gen_ref.png",
        "operation": "source_direct representative_crop + downscale_320x180 + quantize",
    },
    {
        "outputs": "game/assets/previews/cast/c{id}.png",
        "sources": "docs/characters/cast-roster-chunky-v4-src.png",
        "variants": {"id": [1, 2, 3, 4, 5, 6, 7, 8, 9]},
        "operation": "source_direct slice_grid_3x3 + contain_downscale_320x180 + quantize",
    },
]


def quantize(im: Image.Image, colors: int = 48) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def alpha_crop(im: Image.Image) -> Image.Image:
    arr = np.asarray(im.convert("RGBA"))
    ys, xs = np.where(arr[:, :, 3] > 20)
    if not len(xs):
        raise ValueError("preview source has no opaque subject")
    return Image.fromarray(arr).crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def cream_key(im: Image.Image) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r, g, b = (arr[:, :, i].astype(int) for i in range(3))
    cream = (r > 228) & (g > 216) & (b > 190) & ((r - b) < 70)
    arr[cream, 3] = 0
    return Image.fromarray(arr)


def magenta_key(im: Image.Image) -> Image.Image:
    arr = np.array(im.convert("RGBA"))
    r, g, b = (arr[:, :, i].astype(int) for i in range(3))
    magenta = (r > 180) & (b > 150) & (g < 90) & ((r + b) > g * 4)
    arr[magenta, 3] = 0
    return Image.fromarray(arr)


def contain(im: Image.Image, colors: int = 40, margin: int = 10) -> Image.Image:
    crop = alpha_crop(im)
    scale = min((PREVIEW_W - margin * 2) / crop.width, (PREVIEW_H - margin * 2) / crop.height, 1.0)
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    scaled = crop.resize(size, Image.Resampling.BOX) if size != crop.size else crop
    canvas = Image.new("RGBA", (PREVIEW_W, PREVIEW_H), (0, 0, 0, 0))
    canvas.alpha_composite(quantize(scaled, colors), ((PREVIEW_W - size[0]) // 2, (PREVIEW_H - size[1]) // 2))
    return canvas


def cover(im: Image.Image, colors: int = 48) -> Image.Image:
    rgba = im.convert("RGBA")
    scale = max(PREVIEW_W / rgba.width, PREVIEW_H / rgba.height)
    # All authored sources are larger than the target; never enlarge a thumbnail.
    if scale > 1:
        raise ValueError(f"source {rgba.size} is below preview target")
    size = (max(PREVIEW_W, round(rgba.width * scale)), max(PREVIEW_H, round(rgba.height * scale)))
    scaled = rgba.resize(size, Image.Resampling.BOX)
    x = (size[0] - PREVIEW_W) // 2
    y = (size[1] - PREVIEW_H) // 2
    return quantize(scaled.crop((x, y, x + PREVIEW_W, y + PREVIEW_H)), colors)


def save(rel: str, im: Image.Image) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def cke_source(name: str) -> Image.Image:
    return chroma_key_fit(Image.open(PROMO / name), 1024, 1024, 64, margin=1)


def cke_preview(name: str, colors: int = 40) -> Image.Image:
    """Build a TOP preview straight from its high-resolution green-screen source."""
    return chroma_key_fit(
        Image.open(PROMO / name),
        PREVIEW_W,
        PREVIEW_H,
        colors,
        margin=3,
        pixel_scale=1,
    )


def parts(im: Image.Image, count: int) -> list[Image.Image]:
    found = slice_runs(im)
    return found if len(found) == count else slice_equal(im, count, pad=0.04)


def build_drip() -> None:
    bean_ids = ["ethiopia", "peru", "colombia", "kenya", "brazil"]
    for item, cell in zip(bean_ids, parts(Image.open(PROMO / "coffee_beans_sheet_gen_ref.png"), 5)):
        save(f"ritual/drip/bean_{item}.png", contain(cream_key(cell)))

    dripper_ids = ["v60", "kalita", "single", "origami", "metal"]
    for item in dripper_ids:
        save(
            f"ritual/drip/dripper_{item}.png",
            cke_preview(f"dripper_{item}_chroma_gen_ref.png"),
        )

    for item in ["fine", "medium", "coarse"]:
        save(f"ritual/drip/grind_{item}.png", contain(cke_source(f"drip_grind_{item}_gen_ref.png")))
    for item in ["92", "100"]:
        save(f"ritual/drip/temp_{item}.png", contain(cream_key(Image.open(PROMO / f"drip_temp_{item}_gen_ref.png"))))

    save("ritual/drip/paper.png", cke_preview("drip_paper_chroma_gen_ref.png"))
    for pours in [2, 3, 4]:
        save(
            f"ritual/drip/pours_{pours}.png",
            cke_preview(f"drip_pours_{pours}_chroma_gen_ref.png"),
        )

    for i in [1, 2, 3]:
        save(f"ritual/drip/drip_{i}.png", cover(Image.open(PROMO / f"drip_pixel_{i}.png")))


def build_fish() -> None:
    groups = [
        ("spot", ["shoal", "pool", "pier", "weed", "rapids"], "fish_spots_v2_sheet_gen_ref.png"),
        ("bait", ["worm", "dough", "lure", "bug", "corn"], "fish_baits_sheet_gen_ref.png"),
    ]
    for prefix, ids, source in groups:
        for item, cell in zip(ids, parts(Image.open(PROMO / source), len(ids))):
            save(f"ritual/fish/{prefix}_{item}.png", contain(cream_key(cell)))
    ids = [("sinker", x) for x in ["light", "mid", "heavy"]] + [("style", x) for x in ["wait", "twitch", "dance"]]
    for (prefix, item), cell in zip(ids, parts(Image.open(PROMO / "fish_sinkers_styles_sheet_gen_ref.png"), 6)):
        save(f"ritual/fish/{prefix}_{item}.png", contain(cream_key(cell)))
    names = {1: "cast", 2: "wait", 3: "bite", 4: "catch"}
    for i, name in names.items():
        save(f"ritual/fish/fish_{i}.png", cover(Image.open(PROMO / f"fish_step_{i}_{name}_gen_ref.png")))
    save("ritual/fish/fish_4_miss.png", cover(Image.open(PROMO / "fish_step_4_miss_gen_ref.png")))


def build_cup() -> None:
    for item in ["nose", "mouth", "after"]:
        save(f"ritual/cup/focus_{item}.png", contain(cke_source(f"cup_focus_{item}_chroma_gen_ref.png")))
    names = {1: "mug_raise", 2: "mug_drink", 3: "mug_rest"}
    for i, name in names.items():
        save(f"ritual/cup/sip_{i}.png", cover(Image.open(PROMO / f"cup_sip_{i}_{name}_gen_ref.png")))


def build_cook() -> None:
    groups = {
        "cuisine": ["bbq", "sushi", "hotpot", "skewer", "stew"],
        "heat": ["soft", "mid", "hot"],
        "season": ["salt", "soy", "citrus"],
    }
    for prefix, ids in groups.items():
        for item in ids:
            raw = Image.open(PROMO / f"cook_{prefix}_{item}_gen_ref.png")
            keyed = chroma_key_fit(raw, raw.width, raw.height, 64, margin=1)
            save(f"ritual/cook/{prefix}_{item}.png", contain(cream_key(keyed)))
    names = {1: "fire", 2: "flip", 3: "plate"}
    for i, name in names.items():
        save(f"ritual/cook/cook_{i}.png", cover(Image.open(PROMO / f"cook_step_{i}_{name}_gen_ref.png")))


def build_drip_codex() -> None:
    save("codex/drip.png", cke_preview("dripper_v60_chroma_gen_ref.png"))


def build_codex() -> None:
    tent = slice_grid(Image.open(PROMO / "tents_pitch_shut_sheet_gen_ref.png"), 3, 3, pad=0.08)[6]
    save("codex/tent.png", contain(cream_key(tent)))
    save("codex/rod.png", cover(Image.open(PROMO / "fish_step_1_cast_gen_ref.png")))
    save("codex/cup.png", cover(Image.open(PROMO / "cup_sip_1_mug_raise_gen_ref.png")))
    save("codex/cook.png", cover(Image.open(PROMO / "cook_step_1_fire_gen_ref.png")))


def build_cast() -> None:
    source = Image.open(ROOT / "docs" / "characters" / "cast-roster-chunky-v4-src.png")
    for i, cell in enumerate(slice_grid(source, 3, 3, pad=0.06), 1):
        save(f"cast/c{i}.png", contain(magenta_key(cell), colors=32, margin=8))


def main() -> int:
    parser = argparse.ArgumentParser(description="Build source-direct TOP previews")
    parser.add_argument(
        "--section",
        choices=["all", "drip"],
        default="all",
        help="limit rebuilding when other asset work is in progress",
    )
    args = parser.parse_args()
    build_drip()
    build_drip_codex()
    if args.section == "all":
        build_fish()
        build_cup()
        build_cook()
        build_codex()
        build_cast()
    print("TOP previews: source-direct 320x180; tea intentionally excluded")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
