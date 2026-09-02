#!/usr/bin/env python3
"""Encode the edited shoreline loop for desktop LÖVE and LovePotion."""
from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "audio" / "amb_ocean_waves_loop_source.wav"
DESKTOP = ROOT / "game" / "audio" / "amb_ocean_waves.ogg"
CONSOLE = ROOT / "game" / "audio" / "3ds" / "amb_ocean_waves.wav"

ASSET_PROVENANCE = [
    {
        "sources": ["docs/audio/amb_ocean_waves_loop_source.wav"],
        "outputs": [
            "game/audio/amb_ocean_waves.ogg",
                    "game/audio/3ds/amb_ocean_waves.wav",
        ],
                "operation": "audio_encode + mono + 3ds_pcm_static_loop",
    },
]


def run(command: list[str]) -> None:
    subprocess.run(command, check=True)


def main() -> int:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise SystemExit("找不到 ffmpeg，无法构建海浪环境音。")
    if not SOURCE.is_file():
        raise SystemExit(f"缺少海浪循环母带：{SOURCE}")

    DESKTOP.parent.mkdir(parents=True, exist_ok=True)
    CONSOLE.parent.mkdir(parents=True, exist_ok=True)
    run([
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-i", str(SOURCE),
        "-ar", "48000", "-ac", "2",
        "-c:a", "vorbis", "-strict", "experimental", "-q:a", "4",
        str(DESKTOP),
    ])
    run([
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
    ])
    print(
        f"ocean ambience: desktop={DESKTOP.stat().st_size} bytes "
        f"3ds={CONSOLE.stat().st_size} bytes"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
