#!/usr/bin/env python3
"""Build a short PCM static creek loop for LovePotion (same idea as ocean)."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "game" / "audio" / "amb_creek.mp3"
CONSOLE = ROOT / "game" / "audio" / "3ds" / "amb_creek.wav"


def main() -> int:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("找不到 ffmpeg，无法构建溪水环境音。")
    if not SOURCE.is_file():
        raise SystemExit(f"缺少溪水母带：{SOURCE}")
    CONSOLE.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(SOURCE),
        "-filter_complex",
        (
            "[0:a]atrim=0:1.5,asetpts=PTS-STARTPTS[head];"
            "[0:a]atrim=1.5:13.5,asetpts=PTS-STARTPTS[body];"
            "[body][head]acrossfade=d=1.5:c1=tri:c2=tri,"
            "aresample=22050,aformat=sample_fmts=s16:channel_layouts=mono[out]"
        ),
        "-map", "[out]",
        "-c:a", "pcm_s16le",
        str(CONSOLE),
    ], check=True)
    print(f"creek ambience: 3ds={CONSOLE.stat().st_size} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
