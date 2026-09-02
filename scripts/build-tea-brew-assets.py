#!/usr/bin/env python3
"""Build tea-brew pixel icons from per-item gen refs (no multi-icon sheet slice)."""
from __future__ import annotations

from pathlib import Path

from gen_slice_common import chroma_key_fit, hard_fit, load_gen

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
RITUAL = ASSETS / "ritual" / "tea"
GEN = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")

BACKGROUND_KEY_LEAF_IDS = ["longjing", "tieguanyin", "dianhong", "genmaicha"]
CHROMA_KEY_LEAF_IDS = ["yinzhen"]
WARE_IDS = ["gaiwan", "glass", "zisha", "piaoyi", "enamel"]
TEMP_IDS = [80, 85, 90, 95, 100]
PREVIEW_W, PREVIEW_H = 256, 192
BREW_W, BREW_H = 320, 180

ASSET_PROVENANCE = [
    {
        "outputs": "game/assets/ritual/tea/leaf_{id}.png",
        "sources": "docs/promo/tea_leaf_{id}_gen_ref.png",
        "variants": {"id": ["longjing", "tieguanyin", "dianhong", "genmaicha"]},
        "operation": "background_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/leaf_yinzhen.png",
        "sources": "docs/promo/tea_leaf_yinzhen_chroma_gen_ref.png",
        "operation": "chroma_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/ware_{id}.png",
        "sources": "docs/promo/tea_ware_{id}_gen_ref.png",
        "variants": {"id": ["gaiwan", "glass", "zisha", "piaoyi", "enamel"]},
        "operation": "background_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/tea_rinse.png",
        "sources": "docs/promo/tea_rinse_action_chroma_gen_ref.png",
        "operation": "chroma_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/preview_rinse.png",
        "sources": "docs/promo/tea_rinse_action_chroma_gen_ref.png",
        "operation": "source_direct chroma_key + contain 256x192 + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/tea_temp_{c}.png",
        "sources": "docs/promo/tea_temp_{c}_chroma_gen_ref.png",
        "variants": {"c": [80, 85, 90, 95, 100]},
        "operation": "chroma_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/preview_leaf_{id}.png",
        "sources": "docs/promo/tea_leaf_{id}_gen_ref.png",
        "variants": {"id": ["longjing", "tieguanyin", "dianhong", "genmaicha"]},
        "operation": "source_direct background_key + contain 256x192 + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/preview_leaf_yinzhen.png",
        "sources": "docs/promo/tea_leaf_yinzhen_chroma_gen_ref.png",
        "operation": "source_direct chroma_key + contain 256x192 + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/preview_ware_{id}.png",
        "sources": "docs/promo/tea_ware_{id}_gen_ref.png",
        "variants": {"id": ["gaiwan", "glass", "zisha", "piaoyi", "enamel"]},
        "operation": "source_direct background_key + contain 256x192 + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/preview_temp_{c}.png",
        "sources": "docs/promo/tea_temp_{c}_chroma_gen_ref.png",
        "variants": {"c": [80, 85, 90, 95, 100]},
        "operation": "source_direct chroma_key + contain 256x192 + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/tea_amount_{id}.png",
        "sources": "docs/promo/tea_amount_{id}_chroma_gen_ref.png",
        "variants": {"id": ["light", "medium", "full"]},
        "operation": "chroma_key + crop + resize + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/preview_amount_{id}.png",
        "sources": "docs/promo/tea_amount_{id}_chroma_gen_ref.png",
        "variants": {"id": ["light", "medium", "full"]},
        "operation": "source_direct chroma_key + contain 256x192 + quantize",
    },
    {
        "outputs": "game/assets/ritual/tea/tea_{id}.png",
        "sources": "docs/promo/tea_brew_step_{id}_gen_ref.png",
        "variants": {"id": [1, 2, 3]},
        "operation": "source_direct cover_crop 320x180 + quantize",
    },
]


def save(name: str, im) -> None:
    RITUAL.mkdir(parents=True, exist_ok=True)
    path = RITUAL / name
    im.save(path)
    print(f"  {path.relative_to(ROOT)} {im.size}")


def build_leaves() -> None:
    for lid in BACKGROUND_KEY_LEAF_IDS:
        name = f"tea_leaf_{lid}_gen.png"
        if not (GEN / name).exists():
            raise SystemExit(f"missing per-item gen: {GEN / name}")
        source = load_gen(name, f"tea_leaf_{lid}_gen_ref.png")
        save(f"leaf_{lid}.png", hard_fit(source, 48, 48, 28))
        save(f"preview_leaf_{lid}.png", hard_fit(source, PREVIEW_W, PREVIEW_H, 36))
    for lid in CHROMA_KEY_LEAF_IDS:
        name = f"tea_leaf_{lid}_chroma_gen.png"
        if not (GEN / name).exists():
            raise SystemExit(f"missing per-item chroma gen: {GEN / name}")
        source = load_gen(name, f"tea_leaf_{lid}_chroma_gen_ref.png")
        save(
            f"leaf_{lid}.png",
            chroma_key_fit(source, 48, 48, 28, margin=3),
        )
        save(
            f"preview_leaf_{lid}.png",
            chroma_key_fit(source, PREVIEW_W, PREVIEW_H, 36, margin=5),
        )


def build_wares() -> None:
    for wid in WARE_IDS:
        name = f"tea_ware_{wid}_gen.png"
        if not (GEN / name).exists():
            raise SystemExit(f"missing per-item gen: {GEN / name}")
        source = load_gen(name, f"tea_ware_{wid}_gen_ref.png")
        save(f"ware_{wid}.png", hard_fit(source, 48, 48, 26))
        save(f"preview_ware_{wid}.png", hard_fit(source, PREVIEW_W, PREVIEW_H, 36))


def build_rinse() -> None:
    name = "tea_rinse_action_chroma_gen.png"
    promo_name = "tea_rinse_action_chroma_gen_ref.png"
    if not (GEN / name).exists() and not (ROOT / "docs" / "promo" / promo_name).exists():
        raise SystemExit(f"missing per-item chroma gen: {GEN / name}")
    source = load_gen(name, promo_name)
    save(
        "tea_rinse.png",
        chroma_key_fit(source, 48, 48, 30, margin=3),
    )
    save(
        "preview_rinse.png",
        chroma_key_fit(source, PREVIEW_W, PREVIEW_H, 40, margin=5),
    )


def build_temps() -> None:
    """Five no-text kettle states: cool blue through rolling orange-red boil."""
    for temp in TEMP_IDS:
        name = f"tea_temp_{temp}_chroma_gen.png"
        if not (GEN / name).exists() and not (ROOT / "docs" / "promo" / f"tea_temp_{temp}_chroma_gen_ref.png").exists():
            raise SystemExit(f"missing per-item chroma gen: {GEN / name}")
        source = load_gen(name, f"tea_temp_{temp}_chroma_gen_ref.png")
        save(
            f"tea_temp_{temp}.png",
            chroma_key_fit(source, 48, 48, 24, margin=2),
        )
        save(
            f"preview_temp_{temp}.png",
            chroma_key_fit(source, PREVIEW_W, PREVIEW_H, 36, margin=5),
        )


def build_brew_steps() -> None:
    """Per-frame 4:3 close-ups — never squash strip panels into 120×76."""
    import numpy as np
    from gen_slice_common import quantize_rgba

    def brew_fit(im, tw: int = BREW_W, th: int = BREW_H, colors: int = 48):
        rgba = im.convert("RGBA")
        a = np.array(rgba)
        r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
        cream = (r > 232) & (g > 222) & (b > 200)
        a[cream, 3] = 0
        rgba = Image.fromarray(a)
        # cover-crop into 4:3 — keeps proportions, no letterbox bars
        scale = max(tw / rgba.width, th / rgba.height)
        nw = max(tw, int(round(rgba.width * scale)))
        nh = max(th, int(round(rgba.height * scale)))
        mid = rgba.resize((max(4, nw // 2), max(4, nh // 2)), Image.Resampling.BILINEAR)
        scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
        x0 = max(0, (nw - tw) // 2)
        y0 = max(0, (nh - th) // 2)
        cropped = scaled.crop((x0, y0, x0 + tw, y0 + th))
        return quantize_rgba(cropped, colors)

    from PIL import Image

    built = False
    for i in (1, 2, 3):
        name = f"tea_brew_step_{i}_gen.png"
        if (GEN / name).exists():
            save(f"tea_{i}.png", brew_fit(load_gen(name, f"tea_brew_step_{i}_gen_ref.png")))
            built = True
    if built:
        return
    strip = "tea_brew_steps_gen.png"
    if (GEN / strip).exists():
        from gen_slice_common import slice_equal

        parts = slice_equal(load_gen(strip, "tea_brew_steps_gen_ref.png"), 3, pad=0.01)
        for i, part in enumerate(parts, start=1):
            save(f"tea_{i}.png", brew_fit(part))



def build_gear() -> None:
    name = "gear_tea_gen.png"
    if not (GEN / name).exists():
        print("  skip gear_tea (no gen)")
        return
    out = ASSETS / "gear_tea.png"
    hard_fit(load_gen(name, "gear_tea_gen_ref.png"), 48, 48, 24).save(out)
    print(f"  {out.relative_to(ROOT)}")


def build_amount_from_gen() -> bool:
    for aid in ("light", "medium", "full"):
        name = f"tea_amount_{aid}_chroma_gen.png"
        promo_name = f"tea_amount_{aid}_chroma_gen_ref.png"
        if not (GEN / name).exists() and not (ROOT / "docs" / "promo" / promo_name).exists():
            return False
        source = load_gen(name, promo_name)
        save(f"tea_amount_{aid}.png", chroma_key_fit(source, 48, 48, 28, margin=3))
        save(f"preview_amount_{aid}.png", chroma_key_fit(source, PREVIEW_W, PREVIEW_H, 40, margin=5))
    return True


def main() -> int:
    print("leaves (per-item)")
    build_leaves()
    print("wares (per-item)")
    build_wares()
    print("rinse (chroma key)")
    build_rinse()
    print("temps (per-item chroma key)")
    build_temps()
    print("brew steps")
    build_brew_steps()
    print("gear")
    build_gear()
    if not build_amount_from_gen():
        print("  amounts: keep existing (no per-item gen this run)")
    print("done — catalog icons are one gen → one PNG; Lua owns all labels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
