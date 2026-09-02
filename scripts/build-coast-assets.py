#!/usr/bin/env python3
"""Build the coast Destination Pack from generated pixel-art sources."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
PROMO = ROOT / "docs" / "promo"
ASSETS = ROOT / "game" / "assets"
COAST = ASSETS / "scenes" / "coast"

ASSET_PROVENANCE = [
    {
        "sources": ["docs/promo/coast_environment_sheet_gen_ref.png"],
        "outputs": [
            "game/assets/scenes/coast/camp/tile_sand*.png",
            "game/assets/scenes/coast/camp/tile_wet_sand.png",
            "game/assets/scenes/coast/camp/coast_pine.png",
            "game/assets/scenes/coast/camp/salt_shrub.png",
            "game/assets/scenes/coast/camp/beach_grass.png",
            "game/assets/scenes/coast/camp/reef_rock.png",
            "game/assets/scenes/coast/camp/driftwood.png",
        ],
        "operation": "chroma_key + crop + nearest_resize + quantize",
    },
    {
        "sources": ["docs/promo/coast_ocean_band_v2_gen_ref.png"],
        "outputs": [
            "game/assets/scenes/coast/camp/tile_ocean*.png",
            "game/assets/scenes/coast/camp/coast_ocean_band.png",
        ],
        "operation": "cover_crop + nearest_resize + quantize",
    },
    {
        "sources": [
            "docs/promo/coast_ocean_sunrise_v2_gen_ref.png",
            "docs/promo/coast_ocean_sunset_v2_gen_ref.png",
        ],
        "outputs": [
            "game/assets/scenes/coast/camp/coast_ocean_sunrise.png",
            "game/assets/scenes/coast/camp/coast_ocean_sunset.png",
        ],
        "operation": "top_horizon_crop + nearest_resize + quantize",
    },
    {
        "sources": ["docs/promo/coast_fauna_v2_gen_ref.png"],
        "outputs": ["game/assets/scenes/coast/world/*.png"],
        "operation": "chroma_key + crop + nearest_resize + quantize",
    },
    {
        "sources": ["docs/promo/coast_depart_gen_ref.png", "docs/promo/coast_arrive_gen_ref.png"],
        "outputs": ["game/assets/scenes/coast/story/*.png"],
        "operation": "cover_crop + nearest_resize + quantize",
    },
    {
        "sources": ["docs/promo/destination_select_preview_gen_ref.png"],
        "outputs": ["game/assets/previews/destinations/*.png"],
        "operation": "crop + nearest_resize + quantize",
    },
    {
        "sources": ["game/assets/scenes/coast/camp/*.png"],
        "outputs": ["game/assets/scenes/coast/camp/coast_static_base.png"],
        "operation": "tile_composite + quantize",
    },
]


def build_map() -> tuple[dict[int, dict[int, int]], list[dict[str, int | str]]]:
    """Return the deterministic 25x15 coast layout used by Lua and Story Atlas."""
    camp: dict[int, dict[int, int]] = {}
    for y in range(15):
        camp[y] = {}
        for x in range(25):
            if y <= 2:
                tile = 2  # deep sea, blocked
            elif y == 3:
                tile = 8  # shallows, blocked but fishable
            elif y == 4:
                tile = 9  # wet sand
            else:
                tile = 7 if 7 <= x <= 16 and 7 <= y <= 12 else 0
            camp[y][x] = tile

    decals: list[dict[str, int | str]] = []
    for x, y, variant in (
        (1, 6, 0), (22, 6, 0), (2, 12, 0), (21, 12, 0),
    ):
        camp[y][x] = 3
        decals.append({"x": x, "y": y, "kind": "coast-pine", "v": variant})
    for x, y in ((4, 7), (19, 7), (3, 10), (20, 11)):
        camp[y][x] = 6
        decals.append({"x": x, "y": y, "kind": "salt-shrub", "v": 0})
    for x, y in ((6, 5), (18, 5), (1, 9), (23, 9), (5, 13), (19, 13)):
        decals.append({"x": x, "y": y, "kind": "beach-grass", "v": 0})
    for x, y in ((3, 4), (7, 4), (18, 4), (22, 4), (2, 8), (21, 9)):
        camp[y][x] = 4
        decals.append({"x": x, "y": y, "kind": "reef-rock", "v": 0})
    for x, y in ((5, 6), (18, 10), (3, 13)):
        decals.append({"x": x, "y": y, "kind": "driftwood", "v": 0})
    return camp, decals


def quantize_rgba(image: Image.Image, colors: int = 48) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGB")
    return Image.merge("RGBA", (*rgb.split(), alpha))


def cover(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    sw, sh = source.size
    dw, dh = size
    scale = max(dw / sw, dh / sh)
    resized = source.resize((round(sw * scale), round(sh * scale)), Image.Resampling.NEAREST)
    left = max(0, (resized.width - dw) // 2)
    top = max(0, (resized.height - dh) // 2)
    return resized.crop((left, top, left + dw, top + dh))


def chroma_crop(source: Image.Image, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    image = source.crop(box).convert("RGBA")
    pixels = []
    for r, g, b, a in image.getdata():
        # Remove both the flat key and its dark nearest-neighbour edge pixels.
        # Brown trunks and orange crabs have little blue, so they remain intact.
        is_magenta = r > 70 and b > 70 and g < 150 and r > g * 1.35 and b > g * 1.35
        pixels.append((r, g, b, 0 if is_magenta else a))
    image.putdata(pixels)
    bbox = image.getbbox()
    image = image.crop(bbox) if bbox else image
    scale = min((size[0] - 2) / image.width, (size[1] - 2) / image.height)
    image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.NEAREST)
    out = Image.new("RGBA", size)
    out.alpha_composite(image, ((size[0] - image.width) // 2, size[1] - image.height - 1))
    return quantize_rgba(out, 32)


def save(image: Image.Image, path: Path, colors: int = 48) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    quantize_rgba(image.convert("RGBA"), colors).save(path)


def repair_tile_chroma(image: Image.Image) -> Image.Image:
    """Inpaint residual key-color gutters in a tiny opaque terrain tile."""
    image = image.convert("RGBA")
    source = image.copy()
    valid = []
    for y in range(source.height):
        for x in range(source.width):
            r, g, b, _ = source.getpixel((x, y))
            if not (r > 150 and b > 150 and g < 100):
                valid.append((x, y))
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, _ = source.getpixel((x, y))
            if r > 150 and b > 150 and g < 100:
                nx, ny = min(valid, key=lambda point: abs(point[0] - x) + abs(point[1] - y))
                image.putpixel((x, y), source.getpixel((nx, ny)))
    return image


def build() -> None:
    sheet = Image.open(PROMO / "coast_environment_sheet_gen_ref.png").convert("RGBA")
    # The authored crop guide used the 819 px preview shown by the generator;
    # apply it proportionally to the retained 1024 px source.
    def sheet_box(box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
        sx, sy = sheet.width / 819, sheet.height / 819
        return tuple(round(value * (sx if index % 2 == 0 else sy)) for index, value in enumerate(box))

    tile_boxes = [
        (52, 57, 202, 207), (240, 57, 391, 207), (428, 57, 579, 207), (616, 57, 767, 207),
        (52, 242, 202, 392), (240, 242, 391, 392), (428, 242, 579, 392), (616, 242, 767, 392),
    ]
    tile_boxes = [sheet_box(box) for box in tile_boxes]
    # Generated tiles include a black frame and magenta gutter. Crop safely
    # inside that frame before downsampling so adjacent 16 px tiles stay seamless.
    def tile_image(box: tuple[int, int, int, int]) -> Image.Image:
        left, top, right, bottom = box
        return sheet.crop((left + 14, top + 14, right - 8, bottom - 8))

    for i, box in enumerate(tile_boxes[:4]):
        tile = tile_image(box).resize((16, 16), Image.Resampling.NEAREST)
        save(repair_tile_chroma(tile), COAST / "camp" / f"tile_sand{i}.png", 24)

    # One authored ocean band replaces four unrelated square samples. The old
    # samples alternated depth and foam styles per tile, producing a checkerboard.
    ocean_source = Image.open(PROMO / "coast_ocean_band_v2_gen_ref.png").convert("RGBA")
    ocean_band = cover(ocean_source, (400, 64))
    save(ocean_band, COAST / "camp" / "coast_ocean_band.png", 40)
    ocean_strip = cover(ocean_source, (64, 16))
    for i in range(4):
        save(ocean_strip.crop((i * 16, 0, (i + 1) * 16, 16)), COAST / "camp" / f"tile_ocean{i}.png", 28)

    # Preserve the authored horizon and circular sun at its original aspect.
    # Only the upper source band is needed because the runtime sea occupies
    # four 16px rows; a full-frame squash would flatten the sun into a bar.
    for time_name in ("sunrise", "sunset"):
        time_source = Image.open(PROMO / f"coast_ocean_{time_name}_v2_gen_ref.png").convert("RGBA")
        crop_height = min(time_source.height, round(time_source.width * 64 / 400))
        time_band = time_source.crop((0, 0, time_source.width, crop_height))
        time_band = time_band.resize((400, 64), Image.Resampling.NEAREST)
        save(time_band, COAST / "camp" / f"coast_ocean_{time_name}.png", 40)
    # Wet sand is a cooler/darker transform of generated sand, not a painted placeholder.
    wet = tile_image(tile_boxes[0]).resize((16, 16), Image.Resampling.NEAREST).convert("RGB")
    wet = ImageEnhance.Color(wet).enhance(0.72)
    wet = ImageEnhance.Brightness(wet).enhance(0.82)
    save(wet, COAST / "camp" / "tile_wet_sand.png", 24)

    objects = {
        "camp/coast_pine.png": ((42, 411, 304, 641), (48, 48)),
        "camp/salt_shrub.png": ((300, 421, 474, 584), (32, 32)),
        "camp/beach_grass.png": ((470, 415, 619, 580), (24, 32)),
        "camp/reef_rock.png": ((625, 410, 782, 582), (32, 32)),
        "camp/driftwood.png": ((292, 565, 617, 676), (48, 24)),
    }
    for relative, (box, size) in objects.items():
        save(chroma_crop(sheet, sheet_box(box), size), COAST / relative, 32)

    fauna = Image.open(PROMO / "coast_fauna_v2_gen_ref.png").convert("RGBA")
    fauna_objects = {
        "seabird_0.png": ((205, 205, 450, 425), (20, 18)),
        "seabird_1.png": ((565, 205, 815, 425), (20, 18)),
        "crab_0.png": ((120, 550, 505, 840), (28, 18)),
        "crab_1.png": ((550, 550, 920, 840), (28, 18)),
    }
    for name, (box, size) in fauna_objects.items():
        save(chroma_crop(fauna, box, size), COAST / "world" / name, 32)

    for key in ("depart", "arrive"):
        src = Image.open(PROMO / f"coast_{key}_gen_ref.png").convert("RGBA")
        save(cover(src, (400, 240)), COAST / "story" / f"{key}.png", 48)

    selector = Image.open(PROMO / "destination_select_preview_gen_ref.png").convert("RGBA")
    halves = {"forest": (15, 15, 501, 668), "coast": (518, 15, 1009, 668)}
    for key, box in halves.items():
        save(cover(selector.crop(box), (320, 180)), ASSETS / "previews" / "destinations" / f"{key}.png", 48)

    camp_map, decals = build_map()
    tile_images = {
        "sand": [Image.open(COAST / "camp" / f"tile_sand{i}.png").convert("RGBA") for i in range(4)],
        "ocean": [Image.open(COAST / "camp" / f"tile_ocean{i}.png").convert("RGBA") for i in range(4)],
        "wet": Image.open(COAST / "camp" / "tile_wet_sand.png").convert("RGBA"),
    }
    base = Image.new("RGBA", (400, 240))
    for y, row in camp_map.items():
        for x, tile in row.items():
            if tile in (2, 8):
                image = tile_images["ocean"][(x * 5 + y * 3) % 4]
            elif tile == 9:
                image = tile_images["wet"]
            else:
                image = tile_images["sand"][(x * 17 + y * 31) % 4]
            base.alpha_composite(image, (x * 16, y * 16))
    # Keep the sea as one continuous authored surface instead of a 25×4 tile
    # matrix. The runtime still keeps tiny tiles as a low-memory fallback.
    base.alpha_composite(Image.open(COAST / "camp" / "coast_ocean_band.png").convert("RGBA"), (0, 0))
    object_paths = {
        "coast-pine": "coast_pine.png", "salt-shrub": "salt_shrub.png",
        "beach-grass": "beach_grass.png", "reef-rock": "reef_rock.png", "driftwood": "driftwood.png",
    }
    for decal in sorted(decals, key=lambda item: int(item["y"])):
        image = Image.open(COAST / "camp" / object_paths[str(decal["kind"])]).convert("RGBA")
        x, y = int(decal["x"]) * 16, int(decal["y"]) * 16
        base.alpha_composite(image, (x + (16 - image.width) // 2, y + 16 - image.height))
    save(base, COAST / "camp" / "coast_static_base.png", 48)


if __name__ == "__main__":
    build()
