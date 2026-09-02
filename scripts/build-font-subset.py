#!/usr/bin/env python3
"""Rebuild and verify the desktop Chinese UI font from player-visible copy."""
from __future__ import annotations

import argparse
import json
import os
import re
import string
import sys
import tempfile
import unicodedata
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTCollection, TTFont

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
OUTPUT = GAME / "fonts" / "zh-ui.ttf"
FONT_SOURCE_ENV = "LINJIAN_FONT_SOURCE"
SOURCE_CANDIDATES = (
    Path("/System/Library/Fonts/Hiragino Sans GB.ttc"),
    Path("/Library/Fonts/NotoSansCJK-Regular.ttc"),
    Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
)

# Characters rendered by code rather than stored in player-facing strings.
REQUIRED_TEXT = string.printable + "…·—℃°×→←↑↓（）【】《》“”‘’"


def extract_lua_strings(source: str) -> list[str]:
    """Extract quoted and long Lua strings while ignoring comments."""
    values: list[str] = []
    i, length = 0, len(source)
    while i < length:
        if source.startswith("--", i):
            long_comment = re.match(r"--\[(=*)\[", source[i:])
            if long_comment:
                equals = long_comment.group(1)
                end = source.find("]" + equals + "]", i + long_comment.end())
                i = length if end < 0 else end + len(equals) + 2
            else:
                end = source.find("\n", i + 2)
                i = length if end < 0 else end + 1
            continue

        char = source[i]
        if char in ("'", '"'):
            quote = char
            i += 1
            value: list[str] = []
            while i < length:
                if source[i] == "\\" and i + 1 < length:
                    # The following raw character still matters for font coverage.
                    i += 1
                    value.append(source[i])
                    i += 1
                elif source[i] == quote:
                    i += 1
                    break
                else:
                    value.append(source[i])
                    i += 1
            values.append("".join(value))
            continue

        long_string = re.match(r"\[(=*)\[", source[i:])
        if long_string:
            equals = long_string.group(1)
            start = i + long_string.end()
            end = source.find("]" + equals + "]", start)
            if end < 0:
                values.append(source[start:])
                break
            values.append(source[start:end])
            i = end + len(equals) + 2
            continue
        i += 1
    return values


def json_strings(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [text for item in value for text in json_strings(item)]
    if isinstance(value, dict):
        return [text for item in value.values() for text in json_strings(item)]
    return []


def collect_required_characters() -> tuple[set[str], list[Path]]:
    texts = [REQUIRED_TEXT]
    scanned: list[Path] = []
    for path in sorted(GAME.rglob("*.lua")):
        scanned.append(path)
        texts.extend(extract_lua_strings(path.read_text(encoding="utf-8")))
    for path in sorted(GAME.rglob("*.json")):
        scanned.append(path)
        try:
            texts.extend(json_strings(json.loads(path.read_text(encoding="utf-8"))))
        except json.JSONDecodeError as exc:
            raise SystemExit(f"字体扫描失败：JSON 无效 {path.relative_to(ROOT)}: {exc}") from exc

    chars = {
        char
        for text in texts
        for char in text
        if not unicodedata.category(char).startswith("C")
    }
    return chars, scanned


def cmap(path: Path, font_number: int | None = None) -> set[int]:
    font = TTFont(path, fontNumber=font_number)
    try:
        return set(font.getBestCmap() or {})
    finally:
        font.close()


def locate_source(required: set[str]) -> tuple[Path, int | None] | None:
    candidates: list[Path] = []
    configured = os.getenv(FONT_SOURCE_ENV)
    if configured:
        candidates.append(Path(configured).expanduser())
    candidates.extend(SOURCE_CANDIDATES)

    required_codes = {ord(char) for char in required}
    best: tuple[int, Path, int | None] | None = None
    for path in candidates:
        if not path.is_file():
            continue
        if path.suffix.lower() in (".ttc", ".otc"):
            collection = TTCollection(path, lazy=True)
            try:
                face_count = len(collection.fonts)
            finally:
                collection.close()
            faces: list[int | None] = list(range(face_count))
        else:
            faces = [None]
        for face in faces:
            covered = len(cmap(path, face) & required_codes)
            candidate = (covered, path, face)
            if best is None or candidate[0] > best[0]:
                best = candidate
    if best is None:
        return None
    return best[1], best[2]


def missing_characters(path: Path, required: set[str]) -> list[str]:
    covered = cmap(path)
    return sorted((char for char in required if ord(char) not in covered), key=ord)


def format_missing(chars: list[str]) -> str:
    return " ".join(f"{char}(U+{ord(char):04X})" for char in chars[:40])


def build_subset(source: Path, font_number: int | None, required: set[str]) -> bytes:
    options = subset.Options()
    options.font_number = font_number
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.name_languages = ["*"]
    options.notdef_glyph = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.recalc_average_width = True

    font = subset.load_font(str(source), options, lazy=False)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes={ord(char) for char in required})
    subsetter.subset(font)
    with tempfile.NamedTemporaryFile(suffix=".ttf", delete=False) as temporary:
        temp_path = Path(temporary.name)
    try:
        subset.save_font(font, str(temp_path), options)
        return temp_path.read_bytes()
    finally:
        temp_path.unlink(missing_ok=True)
        font.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="只验证现有子集，不自动重建",
    )
    args = parser.parse_args()

    required, scanned = collect_required_characters()
    existing_missing = missing_characters(OUTPUT, required) if OUTPUT.is_file() else list(required)
    if args.check:
        if existing_missing:
            print("字体子集缺字：" + format_missing(existing_missing), file=sys.stderr)
            return 1
        print(f"font coverage: PASS ({len(required)} chars / {len(scanned)} files)")
        return 0

    source_info = locate_source(required)
    if source_info is None:
        if not existing_missing:
            print(f"font subset: current ({len(required)} chars / no full source found)")
            return 0
        print(
            f"找不到完整字体源，且 zh-ui.ttf 缺字：{format_missing(existing_missing)}\n"
            f"请通过 {FONT_SOURCE_ENV} 指向支持中文的 TTF/TTC。",
            file=sys.stderr,
        )
        return 1

    source, font_number = source_info
    source_codes = cmap(source, font_number)
    source_missing = sorted(
        (char for char in required if ord(char) not in source_codes),
        key=ord,
    )
    if source_missing:
        print(
            f"完整字体源 {source} 自身缺字：{format_missing(source_missing)}",
            file=sys.stderr,
        )
        return 1

    built = build_subset(source, font_number, required)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    changed = not OUTPUT.is_file() or OUTPUT.read_bytes() != built
    if changed:
        temporary = OUTPUT.with_suffix(".ttf.tmp")
        temporary.write_bytes(built)
        os.replace(temporary, OUTPUT)

    output_missing = missing_characters(OUTPUT, required)
    if output_missing:
        print("字体子集构建后仍缺字：" + format_missing(output_missing), file=sys.stderr)
        return 1
    state = "updated" if changed else "current"
    face = f" face={font_number}" if font_number is not None else ""
    print(
        f"font subset: {state} ({len(required)} chars / {len(scanned)} files / "
        f"{OUTPUT.stat().st_size} bytes / source={source}{face})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
