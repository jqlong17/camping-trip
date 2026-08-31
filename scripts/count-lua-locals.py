#!/usr/bin/env python3
"""Count chunk-level local names in a Lua file (Lua 5.1 MAXVARS = 200)."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

WARN_AT = 180
FAIL_AT = 200


def strip_comment(line: str) -> str:
    return re.sub(r"--.*$", "", line)


def local_names(line: str) -> list[str]:
    code = strip_comment(line)
    if not code.startswith("local "):
        return []
    rest = code[len("local ") :]
    if rest.startswith("function "):
        m = re.match(r"function\s+(\w+)", rest)
        return [m.group(1)] if m else []
    lhs = rest.split("=", 1)[0]
    names: list[str] = []
    for part in lhs.split(","):
        part = part.strip()
        if not part:
            continue
        if part.startswith("function "):
            names.append(part.split()[1].split("(")[0])
        else:
            m = re.match(r"(\w+)", part)
            if m:
                names.append(m.group(1))
    return names


def count_chunk_locals(text: str) -> list[tuple[int, str]]:
    """This project uses zero-indent for chunk-level locals."""
    out: list[tuple[int, str]] = []
    for i, line in enumerate(text.splitlines(), 1):
        if not line.startswith("local "):
            continue
        for name in local_names(line):
            out.append((i, name))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Count Lua chunk-level local variables")
    ap.add_argument("files", nargs="+", type=Path, help="Lua source files")
    ap.add_argument("--warn", type=int, default=WARN_AT)
    ap.add_argument("--fail", type=int, default=FAIL_AT)
    ap.add_argument("--verbose", "-v", action="store_true")
    args = ap.parse_args()

    worst = 0
    for path in args.files:
        if not path.is_file():
            print(f"MISSING {path}", file=sys.stderr)
            worst = max(worst, 2)
            continue
        entries = count_chunk_locals(path.read_text(encoding="utf-8"))
        n = len(entries)
        if n >= args.fail:
            status = "FAIL"
            code = 2
        elif n >= args.warn:
            status = "WARN"
            code = 1
        else:
            status = "OK"
            code = 0
        worst = max(worst, code)
        print(f"{status} {path}: {n} chunk locals (limit {args.fail})")
        if args.verbose and entries:
            for ln, name in entries[-10:]:
                print(f"  L{ln}: {name}")
            if len(entries) > 10:
                print(f"  ... {len(entries) - 10} more")
    return worst


if __name__ == "__main__":
    sys.exit(main())
