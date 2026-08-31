#!/usr/bin/env python3
"""Restore better cast sprites from docs/characters/walk_v5 (pre DEV-054 procedural overwrite).

Keeps names.txt / genders.txt. Does NOT regenerate crude draw_* cast art.
"""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "docs" / "characters" / "walk_v5"
DST = ROOT / "game" / "assets" / "cast"
BACKUP = ROOT / "docs" / "characters" / "cast_proc_v1_backup"


def main() -> int:
    if not SRC.is_dir():
        raise SystemExit(f"missing {SRC}")
    DST.mkdir(parents=True, exist_ok=True)
    BACKUP.mkdir(parents=True, exist_ok=True)

    for i in range(1, 10):
        walk_src = SRC / f"c{i}_walk.png"
        if not walk_src.exists():
            print(f"skip missing {walk_src.name}")
            continue
        walk_dst = DST / f"c{i}_walk.png"
        port_dst = DST / f"c{i}.png"

        # backup current procedural set once
        if walk_dst.exists() and not (BACKUP / f"c{i}_walk.png").exists():
            shutil.copy2(walk_dst, BACKUP / f"c{i}_walk.png")
        if port_dst.exists() and not (BACKUP / f"c{i}.png").exists():
            shutil.copy2(port_dst, BACKUP / f"c{i}.png")

        sheet = Image.open(walk_src).convert("RGBA")
        if sheet.size != (120, 160):
            raise SystemExit(f"{walk_src.name} expected 120x160 got {sheet.size}")
        sheet.save(walk_dst)

        # 立绘 = 朝下站立帧（row0 col0）
        front = sheet.crop((0, 0, 40, 40))
        front.save(port_dst)
        print(f"restored c{i}.png + c{i}_walk.png from walk_v5")

    print(f"backup of procedural set: {BACKUP}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
