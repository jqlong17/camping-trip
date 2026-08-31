#!/usr/bin/env python3
"""One-shot migrate flat game/assets into cups/ gear/ ui/ shared/ scenes/."""
from __future__ import annotations

import shutil
from pathlib import Path

from asset_layout import (
    ASSETS,
    CUPS,
    FOREST_CAMP,
    FOREST_STORY,
    FOREST_WORLD,
    GEAR,
    HOME_STORY,
    SHARED,
    UI,
)

FOREST_STORY_KEYS = ("p1", "p2", "p3", "d1", "d2")
HOME_STORY_KEYS = ("h1", "diary")

CAMP_FILES = [
    "camp_static_base.png",
    *[f"tile_grass{i}.png" for i in range(8)],
    *[f"tile_dirt{i}.png" for i in range(4)],
    *[f"tile_water{i}.png" for i in range(4)],
    *[f"tile_shallow{i}.png" for i in range(4)],
    "shore_E.png", "shore_W.png", "shore_N.png", "shore_S.png",
    "shore_SE.png", "shore_NE.png", "shore_NW.png", "shore_SW.png",
    "dirt_fringe_N.png", "dirt_fringe_S.png", "dirt_fringe_E.png", "dirt_fringe_W.png",
    "prop_reed.png", "prop_pier.png", "prop_firepit.png",
    "tile_tent.png", "tile_tent_open.png", "tile_tent_packed.png",
]

SHARED_FILES = [
    *[f"tile_tree{i}.png" for i in range(12)],
    *[f"tile_stone{i}.png" for i in range(3)],
    *[f"tile_bush{i}.png" for i in range(3)],
    *[f"prop_flower{i}.png" for i in range(4)],
    "prop_log.png", "prop_stump.png",
    "prop_shadow.png", "prop_shadow_sm.png", "prop_shadow_tree.png",
    "player.png",
]

UI_FILES = ("title_top.png", "title_bot.png", "ui_pack_bg.png")
GEAR_FILES = ("tent", "drip", "tea", "rod", "fan")


def move(src: Path, dst: Path) -> None:
    if not src.is_file():
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.is_file():
        return
    shutil.move(str(src), str(dst))
    print(f"  {src.name} → {dst.relative_to(ASSETS.parent.parent)}")


def main() -> int:
    print("migrate asset folders")
    for d in (CUPS, GEAR, UI, SHARED, FOREST_CAMP, FOREST_WORLD, FOREST_STORY, HOME_STORY):
        d.mkdir(parents=True, exist_ok=True)

    story_dir = ASSETS / "story"
    for key in FOREST_STORY_KEYS:
        move(story_dir / f"{key}.png", FOREST_STORY / f"{key}.png")
        t3x = story_dir / f"{key}.t3x"
        if t3x.is_file():
            move(t3x, FOREST_STORY / f"{key}.t3x")
    for key in HOME_STORY_KEYS:
        move(story_dir / f"{key}.png", HOME_STORY / f"{key}.png")
        t3x = story_dir / f"{key}.t3x"
        if t3x.is_file():
            move(t3x, HOME_STORY / f"{key}.t3x")

    for name in UI_FILES:
        move(ASSETS / name, UI / name)
        t3x = ASSETS / name.replace(".png", ".t3x")
        if t3x.is_file():
            move(t3x, UI / t3x.name)

    for gid in GEAR_FILES:
        move(ASSETS / f"gear_{gid}.png", GEAR / f"{gid}.png")
        t3x = ASSETS / f"gear_{gid}.t3x"
        if t3x.is_file():
            move(t3x, GEAR / f"{gid}.t3x")

    for i in range(3):
        move(ASSETS / f"gear_cup_{i}.png", CUPS / f"_legacy_gear_cup_{i}.png")

    for name in CAMP_FILES:
        move(ASSETS / name, FOREST_CAMP / name)
        t3x = ASSETS / name.replace(".png", ".t3x")
        if t3x.is_file():
            move(t3x, FOREST_CAMP / t3x.name)

    for name in SHARED_FILES:
        move(ASSETS / name, SHARED / name)
        t3x = ASSETS / name.replace(".png", ".t3x")
        if t3x.is_file():
            move(t3x, SHARED / t3x.name)

    world = ASSETS / "world"
    if world.is_dir():
        for f in world.iterdir():
            if f.is_file():
                move(f, FOREST_WORLD / f.name)

    if story_dir.is_dir() and not any(story_dir.iterdir()):
        story_dir.rmdir()
    if world.is_dir() and not any(world.iterdir()):
        world.rmdir()

    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
