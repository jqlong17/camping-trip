#!/usr/bin/env python3
"""Tiny readable wildlife sprites for 露营之旅."""
from pathlib import Path
from PIL import Image

from asset_layout import FOREST_WORLD

OUT = FOREST_WORLD
OUT.mkdir(parents=True, exist_ok=True)


def blank(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(im, pts):
    px = im.load()
    for x, y, c in pts:
        if 0 <= x < im.width and 0 <= y < im.height:
            px[x, y] = c


def save(name, im):
    path = OUT / name
    im.save(path)
    print(name, im.size)


# palettes: body, wing, belly, beak, eye
BIRDS = [
    ((118, 78, 48), (86, 54, 32), (196, 168, 120), (220, 140, 50), (20, 16, 12)),  # sparrow
    ((62, 110, 168), (40, 72, 128), (180, 210, 230), (230, 170, 60), (20, 16, 12)),  # blue
    ((214, 176, 52), (168, 120, 28), (244, 228, 150), (80, 56, 28), (20, 16, 12)),  # yellow
]


def bird_perch(pal):
    b, w, belly, beak, eye = pal
    im = blank(12, 10)
    put(im, [
        (3, 4, w), (4, 3, b), (5, 3, b), (6, 3, b), (7, 4, b),
        (3, 5, b), (4, 4, b), (5, 4, belly), (6, 4, b), (7, 5, b), (8, 5, b),
        (4, 5, belly), (5, 5, belly), (6, 5, b), (7, 6, w),
        (4, 6, b), (5, 6, b), (6, 6, b),
        (8, 4, beak), (2, 6, w), (1, 6, w),
        (5, 3, eye), (5, 8, (70, 48, 28, 255)), (6, 8, (70, 48, 28, 255)),
    ])
    return im


def bird_fly(pal, up=True):
    b, w, belly, beak, eye = pal
    im = blank(14, 10)
    wing = [(4, 1, w), (5, 2, w), (3, 2, w)] if up else [(4, 7, w), (5, 6, w), (3, 6, w)]
    put(im, [
        (6, 3, b), (7, 3, b), (8, 3, b), (9, 4, b),
        (5, 4, b), (6, 4, belly), (7, 4, b), (8, 4, b),
        (6, 5, b), (7, 5, b), (8, 5, w),
        (10, 4, beak), (7, 3, eye),
        (4, 4, w), (3, 4, w),
    ] + wing)
    return im


def nest():
    im = blank(10, 7)
    twig = (118, 82, 42, 255)
    dark = (72, 48, 24, 255)
    egg = (236, 224, 196, 255)
    put(im, [
        (1, 4, twig), (2, 3, twig), (3, 3, twig), (4, 2, twig), (5, 2, twig),
        (6, 3, twig), (7, 3, twig), (8, 4, twig),
        (2, 4, dark), (3, 4, dark), (4, 4, dark), (5, 4, dark), (6, 4, dark), (7, 4, dark),
        (3, 5, twig), (4, 5, twig), (5, 5, twig), (6, 5, twig),
        (4, 3, egg), (6, 3, egg),
    ])
    return im


def butterfly(frame):
    im = blank(9, 8)
    body = (48, 36, 24, 255)
    w1 = (220, 120, 170, 255) if frame == 0 else (236, 180, 80, 255)
    w2 = (160, 70, 130, 255) if frame == 0 else (196, 130, 40, 255)
    open_w = frame == 0
    put(im, [
        (4, 2, body), (4, 3, body), (4, 4, body), (4, 5, body),
        (3, 2, (20, 16, 12, 255)), (5, 2, (20, 16, 12, 255)),
    ])
    if open_w:
        put(im, [
            (1, 2, w1), (2, 2, w1), (2, 3, w2), (1, 3, w2),
            (6, 2, w1), (7, 2, w1), (6, 3, w2), (7, 3, w2),
            (2, 4, w1), (6, 4, w1),
        ])
    else:
        put(im, [(3, 3, w1), (5, 3, w1), (3, 4, w2), (5, 4, w2)])
    return im


def dragonfly():
    im = blank(12, 6)
    body = (40, 120, 88, 255)
    wing = (200, 230, 230, 180)
    put(im, [
        (1, 2, body), (2, 2, body), (3, 2, body), (4, 2, (30, 80, 60, 255)),
        (5, 2, body), (6, 2, body), (7, 2, body), (8, 2, (220, 80, 70, 255)),
        (3, 1, wing), (4, 1, wing), (3, 3, wing), (4, 3, wing),
        (6, 1, wing), (7, 1, wing), (6, 3, wing), (7, 3, wing),
    ])
    return im


def firefly(on):
    im = blank(6, 6)
    body = (40, 48, 28, 255)
    glow = (220, 240, 90, 220) if on else (120, 140, 50, 160)
    put(im, [(2, 2, body), (3, 2, body), (2, 3, glow), (3, 3, glow)])
    if on:
        put(im, [(1, 3, (220, 240, 90, 80)), (4, 3, (220, 240, 90, 80))])
    return im


def main():
    for i, pal in enumerate(BIRDS):
        save(f"bird_{i}_perch.png", bird_perch(pal))
        save(f"bird_{i}_fly0.png", bird_fly(pal, True))
        save(f"bird_{i}_fly1.png", bird_fly(pal, False))
    save("nest.png", nest())
    save("butterfly_0.png", butterfly(0))
    save("butterfly_1.png", butterfly(1))
    save("dragonfly.png", dragonfly())
    save("firefly_0.png", firefly(False))
    save("firefly_1.png", firefly(True))
    print("done")


if __name__ == "__main__":
    main()
