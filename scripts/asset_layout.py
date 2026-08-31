"""Shared runtime asset folder layout for linjian build scripts."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game" / "assets"
CUPS = ASSETS / "cups"
GEAR = ASSETS / "gear"
UI = ASSETS / "ui"
SHARED = ASSETS / "shared"
FOREST_CAMP = ASSETS / "scenes" / "forest" / "camp"
FOREST_WORLD = ASSETS / "scenes" / "forest" / "world"
FOREST_STORY = ASSETS / "scenes" / "forest" / "story"
HOME_STORY = ASSETS / "scenes" / "home" / "story"
RITUAL = ASSETS / "ritual"
CAST = ASSETS / "cast"
