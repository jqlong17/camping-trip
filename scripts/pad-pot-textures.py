#!/usr/bin/env python3
"""Resave runtime PNGs as simple 8-bit RGBA; pad selected large images to POT."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "game" / "assets"

PAD_NAMES = {
    "title_top.png",
    "title_bot.png",
    "ui_pack_bg.png",
}


def pot(n: int) -> int:
    p = 1
    while p < n:
        p *= 2
    return p


def should_pad(path: Path) -> bool:
    if path.name in PAD_NAMES:
        return True
    rel = path.relative_to(ROOT).as_posix()
    if rel.startswith("story/") and path.suffix == ".png":
        return True
    if rel.startswith("ritual/drip_"):
        return True
    if rel.startswith("cast/") and path.name.endswith("_walk.png"):
        return True
    return False


def skip(path: Path) -> bool:
    name = path.name
    return name.startswith("._") or "_v1" in name or "paint" in name


def process(path: Path) -> None:
    im = Image.open(path).convert("RGBA")
    clean = Image.frombytes("RGBA", im.size, im.tobytes())
    w, h = clean.size
    note = "resave"
    if should_pad(path):
        tw, th = pot(w), pot(h)
        if (tw, th) != (w, h):
            out = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
            out.paste(clean, (0, 0))
            clean = out
            note = f"pad {w}x{h} → {tw}x{th}"
    clean.save(path, "PNG", compress_level=3, optimize=False)
    print(f"  {path.relative_to(ROOT)} {clean.size[0]}x{clean.size[1]} {note}")


def main() -> None:
    files = sorted(p for p in ROOT.rglob("*.png") if p.is_file() and not skip(p))
    for p in files:
        process(p)


if __name__ == "__main__":
    main()
