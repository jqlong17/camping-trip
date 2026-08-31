#!/usr/bin/env python3
"""Slice tent pitch ritual + cook + cup deepen assets from text-to-image."""
from __future__ import annotations

from pathlib import Path

from gen_slice_common import hard_fit, load_gen, quantize_rgba, slice_equal, slice_grid
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GEN = Path("/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets")


def hard_panel(im: Image.Image, tw: int = 120, th: int = 76, colors: int = 40) -> Image.Image:
    src = im.convert("RGBA")
    pad = max(2, min(src.width, src.height) // 50)
    src = src.crop((pad, pad, src.width - pad, src.height - pad))
    scale = max(tw / src.width, th / src.height)
    nw, nh = max(tw, int(src.width * scale)), max(th, int(src.height * scale))
    mid = src.resize((max(4, nw // 2), max(4, nh // 2)), Image.Resampling.BILINEAR)
    resized = mid.resize((nw, nh), Image.Resampling.NEAREST)
    ox, oy = (resized.width - tw) // 2, (resized.height - th) // 2
    cropped = resized.crop((ox, oy, ox + tw, oy + th))
    small = cropped.resize((tw // 2, th // 2), Image.Resampling.BILINEAR)
    return quantize_rgba(small.resize((tw, th), Image.Resampling.NEAREST), colors)


def save_panels(src_name: str, out_dir: Path, prefix: str, n: int) -> None:
    im = load_gen(src_name, src_name.replace(".png", "_ref.png"))
    parts = slice_equal(im, n, pad=0.03)
    if len(parts) < n:
        parts = slice_grid(im, n, 1, pad=0.03)
    out_dir.mkdir(parents=True, exist_ok=True)
    for i in range(n):
        cell = parts[i] if i < len(parts) else Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        path = out_dir / f"{prefix}_{i + 1}.png"
        hard_panel(cell).save(path)
        print(f"  {path.relative_to(ROOT)}")


def save_icons(src_name: str, out_dir: Path, names: list[str], cols: int | None = None) -> None:
    im = load_gen(src_name, src_name.replace(".png", "_ref.png"))
    n = len(names)
    parts = slice_equal(im, n, pad=0.04) if cols is None else slice_grid(im, cols, max(1, (n + cols - 1) // cols), pad=0.04)
    out_dir.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(names):
        cell = parts[i] if i < len(parts) else Image.new("RGBA", (48, 48), (0, 0, 0, 0))
        path = out_dir / f"{name}.png"
        hard_fit(cell, 48, 48, 28).save(path)
        print(f"  {path.relative_to(ROOT)}")


def main() -> int:
    tent_out = ROOT / "game" / "assets" / "ritual" / "tent"
    save_panels("tent_pitch_ritual_gen.png", tent_out, "pitch", 3)

    cook_out = ROOT / "game" / "assets" / "ritual" / "cook"
    # cook icons + cook_1..3: use scripts/build-cook-assets.py (per-item gen)
    print("  (skip sheet cook — run build-cook-assets.py)")
    _ = cook_out  # keep path for gear below

    gear = load_gen("gear_cook_v2_gen.png", "gear_cook_v2_gen_ref.png")
    # Fill 48×40 like drip/cup — avoid tiny subject in empty canvas
    from gen_slice_common import kill_bg, subject_crop
    g = subject_crop(gear, pad=2)
    tw, th = 48, 40
    scale = min(tw / max(1, g.width), th / max(1, g.height)) * 0.98
    nw, nh = max(1, int(round(g.width * scale))), max(1, int(round(g.height * scale)))
    mid = g.resize((max(4, nw // 2), max(4, nh // 2)), Image.Resampling.BILINEAR)
    scaled = mid.resize((nw, nh), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    ox, oy = (tw - nw) // 2, (th - nh) // 2
    if nw > tw or nh > th:
        left, top = max(0, -ox), max(0, -oy)
        scaled = scaled.crop((left, top, left + tw, top + th))
        ox, oy = max(0, ox), max(0, oy)
    canvas.alpha_composite(scaled, (ox, oy))
    quantize_rgba(canvas, 36).save(ROOT / "game" / "assets" / "gear" / "cook.png")
    print("  gear/cook.png (48x40 filled)")

    # cup sip / focus: use scripts/build-cup-sip-assets.py (per-item gen)
    print("  (skip sheet cup_sip — run build-cup-sip-assets.py)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
