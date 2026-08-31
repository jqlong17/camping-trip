#!/usr/bin/env python3
"""Build hard-pixel fishing ritual frames, fruit icon, and diary story art."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
DOCS = ROOT / "docs" / "storyboards"
DIARY_REF = Path(
    "/Users/ruska/.cursor/projects/Users-ruska-projects-3ds/assets/diary_desk_ref.png"
)

INK = (28, 22, 16, 255)
WOOD = (156, 108, 52, 255)
WOOD_D = (96, 64, 28, 255)
DOCK = (168, 132, 72, 255)
WATER = (72, 140, 176, 255)
WATER_D = (48, 100, 136, 255)
WATER_L = (120, 180, 200, 255)
GRASS = (78, 148, 42, 255)
TREE = (42, 96, 40, 255)
TREE_D = (28, 64, 28, 255)
SKIN = (232, 188, 148, 255)
HAT = (176, 120, 56, 255)
CLOTH = (72, 112, 72, 255)
LINE = (220, 220, 220, 255)
BOBBER = (236, 84, 64, 255)
FISH_AYU = (220, 210, 150, 255)
FISH_TROUT = (196, 120, 84, 255)
FISH_CARP = (168, 120, 72, 255)
FRUIT = (220, 64, 64, 255)
FRUIT_H = (246, 180, 90, 255)
PAPER = (236, 222, 190, 255)
DESK = (140, 96, 52, 255)
LAMP = (246, 210, 110, 255)
WALL = (92, 78, 58, 255)


def quantize(im: Image.Image, colors: int = 36) -> Image.Image:
    rgba = im.convert("RGBA")
    alpha = rgba.split()[-1]
    rgb = rgba.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def save(rel: str, im: Image.Image, colors: int = 36) -> None:
    path = ASSETS / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    out = quantize(im, colors)
    out.save(path)
    print(f"  {rel} {out.size}")


def blank(w: int = 120, h: int = 76) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def fill_rect(draw: ImageDraw.ImageDraw, box, color) -> None:
    draw.rectangle(box, fill=color)


def draw_scene_base(im: Image.Image, night: bool = True) -> ImageDraw.ImageDraw:
    d = ImageDraw.Draw(im)
    # sky
    sky = (14, 22, 40, 255) if night else (168, 206, 230, 255)
    fill_rect(d, (0, 0, 119, 75), sky)
    if night:
        for x, y in ((8, 6), (22, 10), (40, 4), (58, 8), (76, 5), (94, 9), (110, 7), (30, 16), (88, 14)):
            d.point((x, y), fill=(240, 236, 200, 255))
        # soft moon
        d.ellipse((100, 4, 112, 16), fill=(230, 226, 190, 255))
        d.ellipse((103, 5, 113, 15), fill=sky)
    # far bank trees silhouette
    for x, h in ((2, 18), (14, 22), (26, 16), (96, 20), (108, 17)):
        d.polygon([(x + 6, 38 - h), (x, 38), (x + 12, 38)], fill=(28, 48, 32, 255))
    # grass bank
    fill_rect(d, (0, 34, 78, 52), (64, 118, 48, 255))
    for x in range(2, 76, 5):
        d.point((x, 36), fill=(110, 168, 70, 255))
        d.point((x + 2, 39), fill=(42, 90, 36, 255))
    # water body
    fill_rect(d, (0, 48, 119, 75), WATER)
    for y in (52, 58, 64, 70):
        for x in range(2, 118, 7):
            d.point((x + (y % 5), y), fill=WATER_L if (x // 7) % 2 == 0 else WATER_D)
    # shore foam
    for x in range(0, 80, 4):
        d.point((x, 48), fill=(180, 210, 220, 255))
    # wooden pier / dock
    fill_rect(d, (10, 40, 62, 54), DOCK)
    for x in range(12, 60, 5):
        d.line((x, 40, x, 53), fill=WOOD_D)
    d.line((10, 40, 62, 40), fill=(190, 150, 90, 255))
    # pier posts in water
    for x in (16, 34, 52):
        d.rectangle((x, 52, x + 3, 66), fill=WOOD_D)
        d.rectangle((x, 52, x + 3, 54), fill=WOOD)
    # pine with trunk + highlight
    d.rectangle((17, 30, 21, 42), fill=WOOD_D)
    d.polygon([(19, 8), (6, 28), (32, 28)], fill=TREE_D)
    d.polygon([(19, 14), (9, 32), (29, 32)], fill=TREE)
    d.polygon([(19, 20), (12, 36), (26, 36)], fill=(58, 120, 48, 255))
    d.line((19, 10, 14, 24), fill=(120, 170, 70, 255))
    # camp lantern on dock
    d.rectangle((54, 34, 60, 40), fill=(40, 36, 28, 255))
    d.rectangle((55, 30, 59, 35), fill=(246, 200, 90, 255))
    d.point((57, 31), fill=(255, 240, 180, 255))
    return d


def draw_person(d: ImageDraw.ImageDraw, arm_up: bool = False, lean: int = 0):
    """Back-facing camper with bag — denser than old block stack."""
    ox = 28 + lean
    # shoes + legs
    d.rectangle((ox + 3, 49, ox + 8, 53), fill=(32, 28, 24, 255))
    d.rectangle((ox + 11, 49, ox + 16, 53), fill=(32, 28, 24, 255))
    d.rectangle((ox + 3, 44, ox + 9, 50), fill=(52, 60, 88, 255))
    d.rectangle((ox + 10, 44, ox + 16, 50), fill=(44, 52, 78, 255))
    # torso + straps
    d.rectangle((ox + 2, 33, ox + 17, 46), fill=CLOTH)
    d.rectangle((ox + 3, 35, ox + 9, 44), fill=(96, 138, 92, 255))
    d.line((ox + 5, 33, ox + 5, 45), fill=(50, 80, 48, 255))
    d.line((ox + 13, 33, ox + 13, 45), fill=(50, 80, 48, 255))
    # backpack with buckle
    d.rectangle((ox - 3, 33, ox + 4, 47), fill=(118, 82, 46, 255))
    d.rectangle((ox - 2, 35, ox + 3, 40), fill=(150, 112, 66, 255))
    d.point((ox + 1, 42), fill=(200, 170, 90, 255))
    # head from behind
    d.ellipse((ox + 4, 22, ox + 16, 35), fill=SKIN)
    d.rectangle((ox + 4, 22, ox + 16, 29), fill=HAT)
    d.rectangle((ox + 2, 27, ox + 18, 30), fill=(138, 90, 38, 255))
    d.rectangle((ox + 6, 30, ox + 14, 33), fill=(90, 60, 36, 255))  # hair nape
    # shoulders
    d.rectangle((ox, 33, ox + 19, 37), fill=CLOTH)
    # arm + rod
    if arm_up:
        d.line((ox + 16, 35, ox + 26, 24), fill=SKIN, width=2)
        d.line((ox + 26, 24, ox + 27, 24), fill=SKIN)
        d.line((ox + 27, 23, ox + 48, 12), fill=WOOD, width=2)
        d.line((ox + 27, 24, ox + 48, 13), fill=WOOD_D)
        return (48 + lean, 12)
    d.line((ox + 16, 37, ox + 28, 36), fill=SKIN, width=2)
    d.line((ox + 28, 35, ox + 54, 28), fill=WOOD, width=2)
    d.line((ox + 28, 36, ox + 54, 29), fill=WOOD_D)
    return (54 + lean, 28)


def draw_line_to(d: ImageDraw.ImageDraw, tip, bobber, taut: bool = False, bent: bool = False) -> None:
    color = (255, 255, 255, 255) if taut else LINE
    if bent:
        mid = ((tip[0] + bobber[0]) // 2, tip[1] + 8)
        d.line((tip[0], tip[1], mid[0], mid[1]), fill=color)
        d.line((mid[0], mid[1], bobber[0], bobber[1]), fill=color)
    else:
        d.line((tip[0], tip[1], bobber[0], bobber[1]), fill=color)
    # bobber with white tip
    d.ellipse((bobber[0] - 2, bobber[1] - 2, bobber[0] + 3, bobber[1] + 3), fill=BOBBER)
    d.point((bobber[0], bobber[1] - 1), fill=(250, 240, 230, 255))


def draw_fish(d: ImageDraw.ImageDraw, x: int, y: int, color, facing: int = 1, big: bool = False) -> None:
    s = 1.4 if big else 1.0
    w = int(14 * s)
    h = int(4 * s)
    body = [
        (x, y),
        (x + int(8 * s) * facing, y - h),
        (x + w * facing, y),
        (x + int(8 * s) * facing, y + h),
    ]
    d.polygon(body, fill=color)
    d.polygon(
        [
            (x + w * facing, y),
            (x + int((w + 5) * s) * facing, y - h - 1),
            (x + int((w + 5) * s) * facing, y + h + 1),
        ],
        fill=color,
    )
    # belly highlight + eye
    d.point((x + int(4 * s) * facing, y + 1), fill=(250, 230, 180, 255))
    d.point((x + int(3 * s) * facing, y - 1), fill=INK)
    d.point((x + int(7 * s) * facing, y), fill=(40, 30, 20, 255))  # fin hint


def draw_splash(d: ImageDraw.ImageDraw, cx: int, cy: int, r: int = 6) -> None:
    d.ellipse((cx - r, cy - r // 2, cx + r, cy + r // 2), outline=WATER_L)
    d.ellipse((cx - r + 2, cy - r // 2 + 1, cx + r - 2, cy + r // 2 - 1), outline=(200, 230, 240, 255))
    for ox, oy in ((-r - 1, 0), (r + 1, 0), (0, -r // 2 - 1), (-3, -2), (3, -2)):
        d.point((cx + ox, cy + oy), fill=(230, 245, 250, 255))


def build_fish_frames() -> None:
    # 1 cast — arm up, line flying out
    im = blank()
    d = draw_scene_base(im)
    tip = draw_person(d, arm_up=True)
    draw_line_to(d, tip, (86, 56))
    draw_splash(d, 86, 58, 5)
    d.arc((78, 54, 94, 64), 200, 340, fill=WATER_L)
    save("ritual/fish/fish_1.png", im, colors=48)

    # 2 wait — calm bobber, soft ripples
    im = blank()
    d = draw_scene_base(im)
    tip = draw_person(d, arm_up=False)
    draw_line_to(d, tip, (92, 62))
    for ox in (84, 92, 100):
        d.arc((ox, 58, ox + 10, 68), 200, 340, fill=WATER_L)
    d.point((90, 61), fill=(250, 250, 240, 255))
    save("ritual/fish/fish_2.png", im, colors=48)

    # 3 bite — bent rod, splash, fish under surface
    im = blank()
    d = draw_scene_base(im)
    tip = draw_person(d, arm_up=True, lean=1)
    draw_line_to(d, tip, (88, 64), taut=True, bent=True)
    draw_splash(d, 88, 64, 8)
    draw_fish(d, 78, 68, FISH_TROUT, facing=1)
    # tension spark on rod tip
    d.point((tip[0], tip[1]), fill=(255, 255, 220, 255))
    save("ritual/fish/fish_3.png", im, colors=48)

    # 4 catch — lift fish into air
    im = blank()
    d = draw_scene_base(im)
    tip = draw_person(d, arm_up=True, lean=-1)
    d.line((tip[0], tip[1], tip[0] + 10, tip[1] + 16), fill=LINE)
    draw_fish(d, tip[0] + 6, tip[1] + 20, FISH_AYU, facing=1, big=True)
    draw_splash(d, 90, 62, 6)
    # small sparkles
    for p in ((tip[0] + 18, tip[1] + 14), (tip[0] + 22, tip[1] + 22), (tip[0] + 12, tip[1] + 26)):
        d.point(p, fill=(255, 250, 200, 255))
    save("ritual/fish/fish_4.png", im, colors=48)

    # miss — empty splash, no fish
    im = blank()
    d = draw_scene_base(im)
    tip = draw_person(d, arm_up=True)
    draw_line_to(d, tip, (96, 48))
    draw_splash(d, 96, 50, 7)
    d.arc((88, 46, 106, 58), 180, 360, fill=WATER_L)
    save("ritual/fish/fish_4_miss.png", im, colors=48)


def build_fruit_icon() -> None:
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((2, 3, 13, 14), fill=FRUIT)
    d.ellipse((5, 5, 8, 8), fill=FRUIT_H)
    d.rectangle((7, 1, 9, 4), fill=WOOD_D)
    d.point((10, 2), fill=TREE)
    save("world/fruit_icon.png", im, colors=12)

    for name, color in (
        ("fish_icon_ayu.png", FISH_AYU),
        ("fish_icon_trout.png", FISH_TROUT),
        ("fish_icon_carp.png", FISH_CARP),
    ):
        fim = Image.new("RGBA", (20, 12), (0, 0, 0, 0))
        fd = ImageDraw.Draw(fim)
        draw_fish(fd, 2, 6, color, facing=1)
        save(f"world/{name}", fim, colors=12)


def build_diary() -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    if DIARY_REF.is_file():
        src = Image.open(DIARY_REF).convert("RGBA")
        src.save(DOCS / "diary_ref.png")
    else:
        src = Image.new("RGBA", (400, 240), WALL)

    # Cover to 400x240 then pixelize via 200x120 nearest upscale
    covered = Image.new("RGBA", (400, 240), WALL)
    sw, sh = src.size
    scale = max(400 / sw, 240 / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    resized = src.resize((nw, nh), Image.Resampling.BICUBIC)
    ox, oy = (400 - nw) // 2, (240 - nh) // 2
    covered.paste(resized, (ox, oy), resized)
    small = covered.resize((200, 120), Image.Resampling.BILINEAR)
    pixel = small.resize((400, 240), Image.Resampling.NEAREST)

    # Reinforce hard diary subject so it stays readable after quantize
    d = ImageDraw.Draw(pixel)
    fill_rect(d, (70, 70, 330, 210), DESK)
    fill_rect(d, (110, 90, 290, 190), PAPER)
    d.line((200, 90, 200, 190), fill=WOOD_D, width=3)
    for y in range(105, 180, 12):
        d.line((120, y, 190, y), fill=(210, 190, 160, 255))
        d.line((210, y, 280, y), fill=(210, 190, 160, 255))
    d.ellipse((300, 48, 330, 78), fill=LAMP)
    d.rectangle((312, 78, 318, 110), fill=WOOD)
    d.rectangle((40, 40, 70, 200), fill=WOOD_D)  # chair hint
    save("story/diary.png", pixel, colors=40)


def main() -> int:
    print("build harvest assets")
    build_fish_frames()
    build_fruit_icon()
    # diary art kept; page ink is drawn at runtime from tripHaul
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
