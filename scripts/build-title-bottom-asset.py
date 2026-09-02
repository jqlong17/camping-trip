#!/usr/bin/env python3
"""Build RES-0446 from a full-frame generated source at native 320×240."""
from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

from gen_slice_common import load_gen, quantize_rgba

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "assets" / "ui" / "title_bot.png"

GEN_NAME = "title_bot_no_banner_gen.png"
PROMO_NAME = "title_bot_no_banner_gen_ref.png"

ASSET_PROVENANCE = [
    {
        "outputs": "game/assets/ui/title_bot.png",
        "sources": "docs/promo/title_bot_no_banner_gen_ref.png",
        "operation": "full_frame_cover_crop + native_resize + quantize + pot_pad",
    },
]


def cover_native(im: Image.Image, width: int = 320, height: int = 240) -> Image.Image:
    """Crop at source resolution, then reduce directly to the native screen size."""
    rgba = im.convert("RGBA")
    target_ratio = width / height
    source_ratio = rgba.width / rgba.height
    if source_ratio > target_ratio:
        crop_width = int(round(rgba.height * target_ratio))
        left = (rgba.width - crop_width) // 2
        rgba = rgba.crop((left, 0, left + crop_width, rgba.height))
    elif source_ratio < target_ratio:
        crop_height = int(round(rgba.width / target_ratio))
        top = (rgba.height - crop_height) // 2
        rgba = rgba.crop((0, top, rgba.width, top + crop_height))

    # Generated source is larger than 320×240. Never upscale a low-resolution source.
    if rgba.width < width or rgba.height < height:
        raise ValueError(f"source too small for native output: {rgba.size}")
    native = rgba.resize((width, height), Image.Resampling.BOX)
    native = quantize_rgba(native, 48)

    # The former title strip occupied this central top band. It must now be paper/scene.
    band = np.asarray(native.convert("RGB"))[18:46, 36:284]
    luminance = band.mean(axis=2)
    dark_ratio = float((luminance < 90).mean())
    if dark_ratio > 0.08:
        raise ValueError(f"top safe band still reads as a dark title strip: {dark_ratio:.3f}")
    return native


def pot_pad(content: Image.Image) -> Image.Image:
    padded = Image.new("RGBA", (512, 256), (0, 0, 0, 255))
    padded.paste(content, (0, 0))
    return padded


def main() -> int:
    source = load_gen(GEN_NAME, PROMO_NAME)
    output = pot_pad(cover_native(source))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUT, optimize=True)
    print(f"built {OUT.relative_to(ROOT)} from {PROMO_NAME} ({output.size[0]}x{output.size[1]})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
