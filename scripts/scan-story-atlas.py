#!/usr/bin/env python3
"""Build the local Story Atlas index without changing game runtime files."""
from __future__ import annotations

import argparse
import ast
import fnmatch
import json
import re
import runpy
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
ATLAS = ROOT / "tools" / "story-atlas"
MANIFEST = ATLAS / "data" / "story-manifest.json"
REGISTRY = ATLAS / "data" / "resource-registry.json"
REVIEWS = ATLAS / "data" / "review-status.json"
LUA_RUNTIME_GRAPH = ATLAS / "data" / "lua-runtime-graph.json"
DESTINATION_PACKS = ATLAS / "data" / "destination-packs.json"
OUTPUT = ATLAS / "public" / "graph-index.json"

MEDIA_ROOTS = (
    ROOT / "game" / "assets",
    ROOT / "game" / "audio",
    ROOT / "game" / "fonts",
    ROOT / "cia",
    ROOT / "docs" / "audio",
    ROOT / "docs" / "promo",
    ROOT / "docs" / "storyboards",
)
MEDIA_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".mp3", ".ogg", ".wav", ".ttf", ".txt", ".t3x"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp"}
PREVIEW_EXTS = IMAGE_EXTS | {".mp3", ".ogg", ".wav", ".txt"}

LEGACY_PATTERNS = (
    "game/assets/gear/tent/",
    "game/assets/scenes/forest/camp/tent/",
    "game/assets/ritual/tent/",
    "game/assets/scenes/forest/camp/tile_tent.",
    "game/assets/scenes/forest/camp/tile_tent_open.",
    "game/assets/scenes/forest/world/fan_anim_",
    "game/assets/scenes/forest/world/fish_anim_",
    "game/assets/gear_tea.",
    "game/assets/cups/cup_02_aoguma.",
)


def read_json(path: Path, fallback: Any) -> Any:
    if not path.is_file():
        return fallback
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def repo_path(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def is_backup(path: str) -> bool:
    parts = Path(path).parts
    return any(part.startswith("_") or "bak" in part.lower() for part in parts)


def category_of(path: str) -> str:
    parts = Path(path).parts
    if path.startswith("game/assets/") and len(parts) >= 4:
        if parts[2] == "scenes" and len(parts) >= 6:
            return "/".join(parts[2:5])
        if parts[2] == "ritual" and len(parts) >= 4:
            return "/".join(parts[2:4])
        return parts[2]
    if path.startswith("game/audio/"):
        return "audio"
    if path.startswith("game/fonts/"):
        return "fonts"
    if path.startswith("docs/promo/"):
        return "source/promo"
    if path.startswith("docs/storyboards/"):
        return "source/storyboards"
    if path.startswith("cia/"):
        return "release/cia"
    return "other"


def dimensions(path: Path) -> list[int] | None:
    if path.suffix.lower() not in IMAGE_EXTS:
        return None
    try:
        from PIL import Image

        with Image.open(path) as image:
            return [image.width, image.height]
    except Exception:
        return None


def resource_created_at(path: Path) -> str:
    stat = path.stat()
    timestamp = getattr(stat, "st_birthtime", stat.st_mtime)
    return datetime.fromtimestamp(timestamp, timezone.utc).isoformat()


def collect_media() -> list[Path]:
    found: list[Path] = []
    for base in MEDIA_ROOTS:
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file() or path.name == ".DS_Store" or path.name.startswith("._"):
                continue
            if path.suffix.lower() in MEDIA_EXTS:
                # PNG 与同名 T3X 是同一视觉资源；只为孤立 T3X 单独编号。
                if path.suffix.lower() == ".t3x" and path.with_suffix(".png").is_file():
                    continue
                found.append(path)
    return sorted(found, key=lambda path: repo_path(path).lower())


def update_registry(paths: list[str]) -> dict[str, Any]:
    registry = read_json(REGISTRY, {"version": 1, "next": 1, "entries": {}, "tombstones": {}})
    entries: dict[str, str] = registry.setdefault("entries", {})
    tombstones: dict[str, str] = registry.setdefault("tombstones", {})
    current = set(paths)

    for stale in sorted(set(entries) - current):
        tombstones[stale] = entries.pop(stale)

    for path in paths:
        if path in entries:
            continue
        if path in tombstones:
            entries[path] = tombstones.pop(path)
            continue
        number = int(registry.get("next", 1))
        entries[path] = f"RES-{number:04d}"
        registry["next"] = number + 1

    registry["entries"] = dict(sorted(entries.items()))
    registry["tombstones"] = dict(sorted(tombstones.items()))
    write_json(REGISTRY, registry)
    return registry


def source_texts() -> dict[str, str]:
    texts: dict[str, str] = {}
    for base, pattern in ((ROOT / "game", "*.lua"), (ROOT / "scripts", "*.py")):
        for path in base.rglob(pattern):
            try:
                texts[repo_path(path)] = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                pass
    return texts


def code_refs(path: str, texts: dict[str, str]) -> list[str]:
    file_name = Path(path).name
    game_relative = path.removeprefix("game/")
    needles = {path, game_relative}
    if len(file_name) >= 6:
        needles.add(file_name)
    return sorted(
        source
        for source, text in texts.items()
        if any(needle in text for needle in needles)
    )


def declared_provenance(paths: list[str]) -> dict[str, list[dict[str, Any]]]:
    """从构建脚本的静态声明读取血缘；不导入脚本，也不按文件名猜测。"""
    by_output: dict[str, list[dict[str, Any]]] = {}
    for script in sorted((ROOT / "scripts").glob("*.py")):
        try:
            tree = ast.parse(script.read_text(encoding="utf-8"), filename=str(script))
        except (OSError, SyntaxError, UnicodeDecodeError):
            continue
        declaration: Any = None
        for statement in tree.body:
            target = None
            value = None
            if isinstance(statement, ast.Assign) and len(statement.targets) == 1:
                target, value = statement.targets[0], statement.value
            elif isinstance(statement, ast.AnnAssign):
                target, value = statement.target, statement.value
            if isinstance(target, ast.Name) and target.id == "ASSET_PROVENANCE" and value is not None:
                try:
                    declaration = ast.literal_eval(value)
                except (ValueError, TypeError):
                    declaration = None
                break
        if not isinstance(declaration, list):
            continue
        script_path = repo_path(script)
        for item in declaration:
            if not isinstance(item, dict):
                continue
            variants = item.get("variants", {})
            contexts: list[dict[str, Any]] = [{}]
            if isinstance(variants, dict):
                for key, values in variants.items():
                    contexts = [
                        {**context, key: value}
                        for context in contexts
                        for value in values
                    ]
            for context in contexts:
                output_patterns = item.get("outputs", [])
                sources = item.get("sources", [])
                if isinstance(output_patterns, str):
                    output_patterns = [output_patterns]
                if isinstance(sources, str):
                    sources = [sources]
                output_patterns = [pattern.format(**context) for pattern in output_patterns]
                sources = [source.format(**context) for source in sources]
                for pattern in output_patterns:
                    for output in paths:
                        if not fnmatch.fnmatchcase(output, pattern):
                            continue
                        link = {
                            "sources": [source for source in sources if source in paths],
                            "scriptPath": script_path,
                            "operation": str(item.get("operation", "transform")),
                        }
                        if link not in by_output.setdefault(output, []):
                            by_output[output].append(link)
    return by_output


def media_kind(path: str) -> str:
    ext = Path(path).suffix.lower()
    if ext in IMAGE_EXTS:
        return "image"
    if ext in {".mp3", ".ogg", ".wav"}:
        return "audio"
    if ext == ".ttf":
        return "font"
    if ext == ".t3x":
        return "texture"
    return "text"


def lua_strings_in_block(path: str, block: str, first_line: int) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for offset, line in enumerate(block.splitlines()):
        for token_match in re.finditer(r'"(?:\\.|[^"\\])*"', line):
            token = token_match.group(0)
            try:
                value = json.loads(token)
            except json.JSONDecodeError:
                continue
            if value and re.search(r"[\u3400-\u9fff]", value):
                entries.append({"path": path, "line": first_line + offset, "text": value})
    return entries


def lua_strings_in_function(path: str, function_name: str, text: str) -> list[dict[str, Any]]:
    match = re.search(rf"(?m)^function\s+{re.escape(function_name)}\s*\(", text)
    if not match:
        return []
    next_function = re.search(r"(?m)^function\s+", text[match.end():])
    end = match.end() + next_function.start() if next_function else len(text)
    block = text[match.start():end]
    first_line = text[:match.start()].count("\n") + 1
    return lua_strings_in_block(path, block, first_line)


def lua_strings_in_range(path: str, start_marker: str, end_marker: str, text: str) -> list[dict[str, Any]]:
    start = text.find(start_marker)
    if start < 0:
        return []
    end = text.find(end_marker, start + len(start_marker)) if end_marker else len(text)
    if end < 0:
        end = len(text)
    first_line = text[:start].count("\n") + 1
    return lua_strings_in_block(path, text[start:end], first_line)


def exact_copy_entries(node: dict[str, Any], texts: dict[str, str]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    candidates = [node.get("label", ""), node.get("description", ""), *node.get("options", [])]
    for path in node.get("sourcePaths", []):
        if not path.startswith("game/") or not path.endswith(".lua") or path not in texts:
            continue
        source = texts[path]
        for candidate in candidates:
            if not candidate:
                continue
            token = json.dumps(candidate, ensure_ascii=False)
            for line_number, line in enumerate(source.splitlines(), 1):
                if token in line:
                    entries.append({"path": path, "line": line_number, "text": candidate})

    for scope in node.get("copyScopes", []):
        path = scope.get("path", "")
        source = texts.get(path)
        if not source:
            continue
        for function_name in scope.get("functions", []):
            entries.extend(lua_strings_in_function(path, function_name, source))
        if scope.get("start"):
            entries.extend(
                lua_strings_in_range(
                    path,
                    scope["start"],
                    scope.get("end", ""),
                    source,
                )
            )

    deduped: list[dict[str, Any]] = []
    seen: set[tuple[str, int, str]] = set()
    for entry in entries:
        key = (entry["path"], entry["line"], entry["text"])
        if key in seen:
            continue
        seen.add(key)
        deduped.append(entry)
    for index, entry in enumerate(deduped, 1):
        entry["id"] = f"COPY-{node['id']}-{index:02d}"
    return deduped


def classify_status(path: str, refs: list[str], node_ids: list[str]) -> str:
    if is_backup(path):
        return "backup"
    if any(pattern in path for pattern in LEGACY_PATTERNS):
        return "legacy"
    if path.startswith("docs/"):
        return "source"
    if refs or node_ids:
        return "active"
    return "unlinked"


def expand_node_assets(node: dict[str, Any], paths: list[str]) -> tuple[dict[str, Any], list[str]]:
    """把节点声明的资源组通配符展开为实际资源，新增同组图片时无需逐张登记。"""
    expanded = list(node.get("assetPaths", []))
    missing_patterns: list[str] = []
    for pattern in node.get("assetGlobs", []):
        matches = sorted(path for path in paths if fnmatch.fnmatchcase(path, pattern))
        if not matches:
            missing_patterns.append(pattern)
        for path in matches:
            if path not in expanded:
                expanded.append(path)
    return {**node, "assetPaths": expanded}, missing_patterns


STORY_ONTOLOGY_TYPES = {
    "scene": "ONT-101",
    "beat": "ONT-102",
    "choice": "ONT-103",
    "action": "ONT-104",
    "phase": "ONT-105",
    "page": "ONT-106",
    "entry": "ONT-107",
}

RESOURCE_ONTOLOGY_TYPES = {
    "image": "ONT-301",
    "audio": "ONT-302",
    "font": "ONT-303",
    "texture": "ONT-304",
    "text": "ONT-305",
}

DESTINATION_TYPE = "ONT-108"
SCENE_GROUP_TYPE = "ONT-109"
PLACEMENT_TYPE = "ONT-110"
SCENE_HAS_DESTINATION = "ONT-608"
DESTINATION_HAS_GROUP = "ONT-609"
GROUP_HAS_RESOURCE = "ONT-610"
GROUP_HAS_PLACEMENT = "ONT-611"
PLACEMENT_USES_RESOURCE = "ONT-612"


def materialize_destination_packs(
    paths: list[str],
    resource_id_by_path: dict[str, str],
) -> list[dict[str, Any]]:
    """Materialize destination composition and placements from declared pack data."""
    document = read_json(DESTINATION_PACKS, {"destinations": []})
    available = set(paths)
    destinations: list[dict[str, Any]] = []
    for declared in document.get("destinations", []):
        groups: list[dict[str, Any]] = []
        group_by_key: dict[str, dict[str, Any]] = {}
        for group in declared.get("groups", []):
            resource_paths = [path for path in group.get("resourcePaths", []) if path in available]
            item = {
                **group,
                "resourcePaths": resource_paths,
                "resourceIds": [resource_id_by_path[path] for path in resource_paths],
                "placements": [],
            }
            groups.append(item)
            group_by_key[item["key"]] = item

        provider = declared.get("layoutProvider")
        if provider:
            provider_path = (ROOT / provider["path"]).resolve()
            if ROOT not in provider_path.parents or not provider_path.is_file():
                raise ValueError(f"invalid destination layout provider: {provider_path}")
            namespace = runpy.run_path(str(provider_path))
            camp_map, decals = namespace[provider["function"]]()
            destination_key = declared["key"].upper()

            def add_placement(
                group_key: str,
                kind: str,
                x: int,
                y: int,
                resource_path: str,
                variant: int | str | None,
                layer: str,
                suffix: str = "",
            ) -> None:
                if resource_path not in resource_id_by_path:
                    return
                variant_key = str(variant) if variant is not None else "base"
                placement_id = f"PLACE-{destination_key}-{kind.upper()}-{x:02d}-{y:02d}-{variant_key}{suffix}"
                kind_label = declared.get("placementKindLabels", {}).get(kind, kind)
                group_by_key[group_key]["placements"].append({
                    "id": placement_id,
                    "kind": kind,
                    "label": f"{kind_label} · 坐标 {x},{y} · 变体{variant_key}",
                    "kindLabel": kind_label,
                    "x": x,
                    "y": y,
                    "variant": variant,
                    "layer": layer,
                    "resourcePath": resource_path,
                    "resourceId": resource_id_by_path[resource_path],
                    "contextImagePath": declared.get("contextImagePath"),
                    "source": provider["path"],
                    "evidence": [{"path": provider["path"], "functionName": provider["function"]}],
                })

            def tile_at(x: int, y: int) -> int | None:
                return camp_map.get(y, {}).get(x)

            def water(value: int | None) -> bool:
                return value in (2, 8)

            is_coast = declared["key"] == "coast"
            for y, row in sorted(camp_map.items()):
                for x, tile in sorted(row.items()):
                    if is_coast and tile in (2, 8):
                        variant = (x * 5 + y * 3) % 4
                        kind = "deep-water" if tile == 2 else "shallow-water"
                        add_placement("water", kind, x, y, f"game/assets/scenes/coast/camp/tile_ocean{variant}.png", variant, "ground")
                    elif is_coast and tile == 9:
                        add_placement("ground", "wet-sand", x, y, "game/assets/scenes/coast/camp/tile_wet_sand.png", 0, "ground")
                    elif is_coast:
                        variant = (x * 17 + y * 31) % 4
                        add_placement("ground", "sand", x, y, f"game/assets/scenes/coast/camp/tile_sand{variant}.png", variant, "ground")
                    elif tile == 2:
                        variant = (x * 5 + y * 3) % 4
                        add_placement("water", "deep-water", x, y, f"game/assets/scenes/forest/camp/tile_water{variant}.png", variant, "ground")
                    elif tile == 8:
                        variant = (x * 5 + y * 3) % 4
                        add_placement("water", "shallow-water", x, y, f"game/assets/scenes/forest/camp/tile_shallow{variant}.png", variant, "ground")
                    elif tile in (5, 7):
                        variant = (x * 3 + y * 5) % 4
                        add_placement("ground", "dirt", x, y, f"game/assets/scenes/forest/camp/tile_dirt{variant}.png", variant, "ground")
                    elif tile == 10:
                        if x == 0 and y == 0:
                            add_placement(
                                "vegetation", "distant-forest", 0, 0,
                                "game/assets/scenes/forest/camp/forest_distant_canopy.png",
                                0, "backdrop",
                            )
                        continue
                    else:
                        variant = (x * 17 + y * 31) % 8
                        add_placement("ground", "grass", x, y, f"game/assets/scenes/forest/camp/tile_grass{variant}.png", variant, "ground")

                    if not is_coast and not water(tile):
                        adjacent = {
                            "E": water(tile_at(x + 1, y)),
                            "W": water(tile_at(x - 1, y)),
                            "N": water(tile_at(x, y - 1)),
                            "S": water(tile_at(x, y + 1)),
                        }
                        covered: set[str] = set()
                        for corner, present in (
                            ("NE", adjacent["N"] and adjacent["E"]),
                            ("NW", adjacent["N"] and adjacent["W"]),
                            ("SE", adjacent["S"] and adjacent["E"]),
                            ("SW", adjacent["S"] and adjacent["W"]),
                        ):
                            if present:
                                add_placement("water", "shore", x, y, f"game/assets/scenes/forest/camp/shore_{corner}.png", corner, "overlay", f"-{corner}")
                                covered.update(corner)
                        for direction, present in adjacent.items():
                            if present and direction not in covered:
                                add_placement("water", "shore", x, y, f"game/assets/scenes/forest/camp/shore_{direction}.png", direction, "overlay", f"-{direction}")
                    if not is_coast and tile in (5, 7):
                        for direction, dx, dy in (("N", 0, -1), ("S", 0, 1), ("E", 1, 0), ("W", -1, 0)):
                            if tile_at(x + dx, y + dy) in (0, 1):
                                add_placement("ground", "dirt-fringe", x, y, f"game/assets/scenes/forest/camp/dirt_fringe_{direction}.png", direction, "overlay", f"-{direction}")

            decal_resources = {
                "tree": ("vegetation", lambda v: f"game/assets/shared/tile_tree{v % 12}.png"),
                "bush": ("vegetation", lambda v: f"game/assets/shared/tile_bush{v % 3}.png"),
                "flower": ("vegetation", lambda v: f"game/assets/shared/prop_flower{v % 4}.png"),
                "reed": ("vegetation", lambda _v: "game/assets/scenes/forest/camp/prop_reed.png"),
                "stone": ("nature", lambda v: f"game/assets/shared/tile_stone{v % 3}.png"),
                "log": ("nature", lambda _v: "game/assets/shared/prop_log.png"),
                "stump": ("nature", lambda _v: "game/assets/shared/prop_stump.png"),
                "nest": ("nature", lambda _v: "game/assets/scenes/forest/world/nest.png"),
                "step": ("water", lambda v: f"game/assets/shared/tile_stone{v % 3}.png"),
                "pier": ("water", lambda _v: "game/assets/scenes/forest/camp/prop_pier.png"),
            }
            if is_coast:
                decal_resources = {
                    "coast-pine": ("vegetation", lambda _v: "game/assets/scenes/coast/camp/coast_pine.png"),
                    "salt-shrub": ("vegetation", lambda _v: "game/assets/scenes/coast/camp/salt_shrub.png"),
                    "beach-grass": ("vegetation", lambda _v: "game/assets/scenes/coast/camp/beach_grass.png"),
                    "reef-rock": ("nature", lambda _v: "game/assets/scenes/coast/camp/reef_rock.png"),
                    "driftwood": ("nature", lambda _v: "game/assets/scenes/coast/camp/driftwood.png"),
                }
            duplicate_counter: Counter[str] = Counter()
            for decal in decals:
                kind = str(decal["kind"])
                if kind not in decal_resources:
                    continue
                x, y, variant = int(decal["x"]), int(decal["y"]), int(decal["v"])
                group_key, resolver = decal_resources[kind]
                duplicate_key = f"{kind}:{x}:{y}:{variant}"
                duplicate_counter[duplicate_key] += 1
                suffix = f"-{duplicate_counter[duplicate_key]}" if duplicate_counter[duplicate_key] > 1 else ""
                add_placement(group_key, kind, x, y, resolver(variant), variant, "prop", suffix)

        destinations.append({
            **declared,
            "groups": groups,
            "source": repo_path(DESTINATION_PACKS),
        })
    return destinations


def materialize_instance_graph(
    nodes: list[dict[str, Any]],
    story_edges: list[dict[str, Any]],
    resources: list[dict[str, Any]],
    runtime_graph: dict[str, Any],
    destinations: list[dict[str, Any]],
) -> dict[str, Any]:
    """把嵌套扫描结果物化成可按本体类型查询的统一实例图。"""
    entities: list[dict[str, Any]] = []
    relations: list[dict[str, Any]] = []
    resource_id_by_path = {resource["path"]: resource["id"] for resource in resources}
    destination_ids = {destination["id"] for destination in destinations}

    for node in nodes:
        if node["id"] not in destination_ids:
            entities.append({
                "id": node["id"],
                "ontologyTypeId": STORY_ONTOLOGY_TYPES[node["kind"]],
                "entityKind": "story",
                "label": node["label"],
                "source": "story-manifest",
                "attributes": {
                    "kind": node["kind"],
                    "subtitle": node["subtitle"],
                    "chapter": node["chapter"],
                    "visibility": node["visibility"],
                    "description": node["description"],
                    "runtimeScene": node.get("runtimeScene"),
                    "runtimeOverlay": node.get("runtimeOverlay"),
                    "resourceCount": len(node["resourceIds"]),
                    "copyCount": len(node["copyEntries"]),
                },
            })
        for copy in node["copyEntries"]:
            entities.append({
                "id": copy["id"],
                "ontologyTypeId": "ONT-401",
                "entityKind": "copy",
                "label": copy["text"],
                "source": "lua-string",
                "attributes": {
                    "nodeId": node["id"],
                    "path": copy["path"],
                    "line": copy["line"],
                    "text": copy["text"],
                },
            })
            relations.append({
                "id": f"COPYREL:{node['id']}:{copy['id']}",
                "ontologyTypeId": "ONT-607",
                "source": node["id"],
                "target": copy["id"],
                "label": "包含文案",
                "attributes": {"path": copy["path"], "line": copy["line"]},
                "evidence": [{"path": copy["path"], "line": copy["line"]}],
            })

    for resource in resources:
        entities.append({
            "id": resource["id"],
            "ontologyTypeId": RESOURCE_ONTOLOGY_TYPES[resource["kind"]],
            "roleTypeIds": ["ONT-306"] if resource["status"] == "source" else [],
            "entityKind": "resource",
            "label": resource["name"],
            "source": "filesystem-scan",
            "attributes": {
                "path": resource["path"],
                "kind": resource["kind"],
                "category": resource["category"],
                "status": resource["status"],
                "bytes": resource["bytes"],
                "createdAt": resource["createdAt"],
                "width": resource["size"][0] if resource["size"] else None,
                "height": resource["size"][1] if resource["size"] else None,
                "previewable": resource["previewable"],
                "pairedT3x": resource["pairedT3x"],
                "nodeCount": len(resource["nodeIds"]),
                "hasProvenance": bool(resource["provenance"]),
            },
        })

    for destination in destinations:
        destination_id = destination["id"]
        scene_node_id = destination["sceneNodeId"]
        entities.append({
            "id": destination_id,
            "ontologyTypeId": DESTINATION_TYPE,
            "entityKind": "destination",
            "label": destination["label"],
            "source": destination["source"],
            "attributes": {
                "key": destination["key"],
                "status": destination["status"],
                "sceneNodeId": scene_node_id,
                "groupCount": len(destination["groups"]),
                "futurePacks": destination.get("futurePacks", []),
            },
        })
        relations.append({
            "id": f"DESTINATION:{scene_node_id}:{destination_id}",
            "ontologyTypeId": SCENE_HAS_DESTINATION,
            "source": scene_node_id,
            "target": destination_id,
            "label": "采用目的地",
            "attributes": {},
            "evidence": [{"path": destination["source"]}],
        })
        for group in destination["groups"]:
            entities.append({
                "id": group["id"],
                "ontologyTypeId": SCENE_GROUP_TYPE,
                "entityKind": "sceneGroup",
                "label": group["label"],
                "source": destination["source"],
                "attributes": {
                    "key": group["key"],
                    "destinationId": destination_id,
                    "sceneNodeId": scene_node_id,
                    "resourceCount": len(group["resourceIds"]),
                    "placementCount": len(group["placements"]),
                },
            })
            relations.append({
                "id": f"GROUP:{destination_id}:{group['id']}",
                "ontologyTypeId": DESTINATION_HAS_GROUP,
                "source": destination_id,
                "target": group["id"],
                "label": "包含场景构成组",
                "attributes": {"key": group["key"]},
                "evidence": [{"path": destination["source"]}],
            })
            for resource_id in group["resourceIds"]:
                relations.append({
                    "id": f"GROUPRES:{group['id']}:{resource_id}",
                    "ontologyTypeId": GROUP_HAS_RESOURCE,
                    "source": group["id"],
                    "target": resource_id,
                    "label": "包含资源定义",
                    "attributes": {},
                    "evidence": [{"path": destination["source"]}],
                })
            for placement in group["placements"]:
                entities.append({
                    "id": placement["id"],
                    "ontologyTypeId": PLACEMENT_TYPE,
                    "entityKind": "placement",
                    "label": placement["label"],
                    "source": placement["source"],
                    "attributes": {
                        "destinationId": destination_id,
                        "sceneNodeId": scene_node_id,
                        "groupId": group["id"],
                        "kind": placement["kind"],
                        "kindLabel": placement["kindLabel"],
                        "groupLabel": group["label"],
                        "x": placement["x"],
                        "y": placement["y"],
                        "coordinate": f"{placement['x']}:{placement['y']}",
                        "variant": placement["variant"],
                        "layer": placement["layer"],
                        "resourceId": placement["resourceId"],
                        "resourcePath": placement["resourcePath"],
                        "contextImagePath": placement["contextImagePath"],
                    },
                })
                relations.append({
                    "id": f"GROUPPLACE:{group['id']}:{placement['id']}",
                    "ontologyTypeId": GROUP_HAS_PLACEMENT,
                    "source": group["id"],
                    "target": placement["id"],
                    "label": "包含摆放实例",
                    "attributes": {},
                    "evidence": placement["evidence"],
                })
                relations.append({
                    "id": f"PLACERES:{placement['id']}:{placement['resourceId']}",
                    "ontologyTypeId": PLACEMENT_USES_RESOURCE,
                    "source": placement["id"],
                    "target": placement["resourceId"],
                    "label": "使用资源定义",
                    "attributes": {},
                    "evidence": placement["evidence"],
                })

    for scene in runtime_graph.get("scenes", []):
        entities.append({
            "id": f"RSCENE:{scene['id']}",
            "ontologyTypeId": "ONT-201",
            "entityKind": "runtimeScene",
            "label": scene["id"],
            "source": "lua-ast",
            "attributes": {
                "scene": scene["id"],
                "readCount": len(scene.get("reads", [])),
                "writeCount": len(scene.get("writes", [])),
            },
        })
    for state in runtime_graph.get("stateVariables", []):
        entities.append({
            "id": f"RSTATE:{state['path']}",
            "ontologyTypeId": "ONT-202",
            "entityKind": "runtimeState",
            "label": state["path"],
            "source": "lua-ast",
            "attributes": {
                "path": state["path"],
                "initialValues": state.get("initialValues", []),
                "writeCount": len(state.get("writes", [])),
            },
        })

    overlays = sorted({
        node["runtimeOverlay"]
        for node in nodes
        if node.get("runtimeOverlay")
    })
    for overlay in overlays:
        entities.append({
            "id": f"ROVERLAY:{overlay}",
            "ontologyTypeId": "ONT-203",
            "entityKind": "runtimeOverlay",
            "label": overlay,
            "source": "story-manifest",
            "attributes": {"overlay": overlay},
        })

    pipeline_operations: dict[str, set[str]] = {}
    for resource in resources:
        for provenance in resource["provenance"]:
            pipeline_operations.setdefault(provenance["scriptPath"], set()).add(provenance["operation"])
    for script_path, operations in sorted(pipeline_operations.items()):
        entities.append({
            "id": f"PIPE:{script_path}",
            "ontologyTypeId": "ONT-501",
            "entityKind": "pipeline",
            "label": script_path.rsplit("/", 1)[-1],
            "source": "asset-provenance",
            "attributes": {
                "scriptPath": script_path,
                "operations": sorted(operations),
            },
        })

    for edge in story_edges:
        relations.append({
            **edge,
            "ontologyTypeId": "ONT-601",
            "attributes": {"kind": edge["kind"]},
            "evidence": [{"path": "tools/story-atlas/data/story-manifest.json"}],
        })
    for transition in runtime_graph.get("transitions", []):
        relations.append({
            "id": f"RTREL:{transition['id']}",
            "ontologyTypeId": "ONT-602",
            "source": f"RSCENE:{transition['from']}",
            "target": f"RSCENE:{transition['to']}",
            "label": " / ".join(transition.get("events", [])) or "运行时跳转",
            "attributes": {
                "events": transition.get("events", []),
                "guards": transition.get("guards", []),
                "callChain": transition.get("callChain", []),
            },
            "evidence": transition.get("evidence", []),
        })
    for node in nodes:
        for resource_id in node["resourceIds"]:
            relations.append({
                "id": f"USES:{node['id']}:{resource_id}",
                "ontologyTypeId": "ONT-603",
                "source": node["id"],
                "target": resource_id,
                "label": "使用资源",
                "attributes": {},
                "evidence": [{"path": "tools/story-atlas/data/story-manifest.json"}],
            })
        if node.get("runtimeScene"):
            target = f"RSCENE:{node['runtimeScene']}"
            relation_label = "映射运行时场景"
        elif node.get("runtimeOverlay"):
            target = f"ROVERLAY:{node['runtimeOverlay']}"
            relation_label = "映射运行时覆盖层"
        else:
            target = None
            relation_label = ""
        if target:
            relations.append({
                "id": f"RMAP:{node['id']}:{target}",
                "ontologyTypeId": "ONT-604",
                "source": node["id"],
                "target": target,
                "label": relation_label,
                "attributes": {},
                "evidence": [{"path": "tools/story-atlas/data/story-manifest.json"}],
            })

    for resource in resources:
        for provenance in resource["provenance"]:
            pipeline_id = f"PIPE:{provenance['scriptPath']}"
            relations.append({
                "id": f"GENERATES:{pipeline_id}:{resource['id']}",
                "ontologyTypeId": "ONT-606",
                "source": pipeline_id,
                "target": resource["id"],
                "label": provenance["operation"],
                "attributes": {"operation": provenance["operation"]},
                "evidence": [{"path": provenance["scriptPath"]}],
            })
            for source_path in provenance["sources"]:
                source_id = resource_id_by_path.get(source_path)
                if source_id:
                    relations.append({
                        "id": f"DERIVED:{resource['id']}:{source_id}",
                        "ontologyTypeId": "ONT-605",
                        "source": resource["id"],
                        "target": source_id,
                        "label": provenance["operation"],
                        "attributes": {"operation": provenance["operation"]},
                        "evidence": [{"path": provenance["scriptPath"]}],
                    })

    entity_ids = {entity["id"] for entity in entities}
    valid_relations = [
        relation
        for relation in relations
        if relation["source"] in entity_ids and relation["target"] in entity_ids
    ]
    return {
        "entities": entities,
        "relations": valid_relations,
        "meta": {
            "entityCount": len(entities),
            "relationCount": len(valid_relations),
            "droppedRelationCount": len(relations) - len(valid_relations),
        },
    }


def build_index() -> dict[str, Any]:
    manifest = read_json(MANIFEST, None)
    if not manifest:
        raise SystemExit(f"missing manifest: {MANIFEST}")
    runtime_graph = read_json(LUA_RUNTIME_GRAPH, {
        "meta": {"schemaVersion": 1, "extractorVersion": 0, "fileCount": 0},
        "scenes": [],
        "stateVariables": [],
        "functions": [],
        "transitions": [],
        "unresolved": [{"kind": "missing-runtime-graph", "path": repo_path(LUA_RUNTIME_GRAPH)}],
    })
    runtime_bindings: dict[str, list[str]] = manifest.get("runtimeSceneBindings", {})
    runtime_overlay_bindings: dict[str, list[str]] = manifest.get("runtimeOverlayBindings", {})
    runtime_scene_by_node: dict[str, str] = {}
    runtime_overlay_by_node: dict[str, str] = {}
    duplicate_runtime_bindings: list[dict[str, str]] = []
    for scene, node_ids in runtime_bindings.items():
        for node_id in node_ids:
            previous = runtime_scene_by_node.get(node_id)
            if previous and previous != scene:
                duplicate_runtime_bindings.append({
                    "nodeId": node_id,
                    "firstScene": previous,
                    "secondScene": scene,
                })
            runtime_scene_by_node[node_id] = scene
    for overlay, node_ids in runtime_overlay_bindings.items():
        for node_id in node_ids:
            runtime_overlay_by_node[node_id] = overlay

    media = collect_media()
    paths = [repo_path(path) for path in media]
    registry = update_registry(paths)
    id_by_path: dict[str, str] = registry["entries"]
    destinations = materialize_destination_packs(paths, id_by_path)
    by_path = {repo_path(path): path for path in media}
    manifest_nodes: list[dict[str, Any]] = []
    unmatched_asset_globs: list[dict[str, str]] = []
    for node in manifest["nodes"]:
        expanded_node, missing_patterns = expand_node_assets(node, paths)
        manifest_nodes.append(expanded_node)
        unmatched_asset_globs.extend(
            {"nodeId": node["id"], "path": f"glob:{pattern}"}
            for pattern in missing_patterns
        )
    node_ids_by_asset: dict[str, list[str]] = {}
    for node in manifest_nodes:
        for path in node.get("assetPaths", []):
            node_ids_by_asset.setdefault(path, []).append(node["id"])
    for destination in destinations:
        scene_node_id = destination["sceneNodeId"]
        for group in destination["groups"]:
            for path in group["resourcePaths"]:
                bucket = node_ids_by_asset.setdefault(path, [])
                if scene_node_id not in bucket:
                    bucket.append(scene_node_id)

    texts = source_texts()
    reviews: dict[str, dict[str, str]] = read_json(REVIEWS, {})
    provenance_by_output = declared_provenance(paths)
    resources: list[dict[str, Any]] = []
    for path in paths:
        disk_path = by_path[path]
        refs = code_refs(path, texts)
        node_ids = sorted(node_ids_by_asset.get(path, []))
        ext = disk_path.suffix.lower()
        paired_t3x = None
        if path.startswith("game/assets/") and ext in IMAGE_EXTS:
            paired_t3x = disk_path.with_suffix(".t3x").is_file()
        review = reviews.get(path, {})
        inferred_status = classify_status(path, refs, node_ids)
        provenance = provenance_by_output.get(path, [])
        source_candidates = sorted({
            source
            for link in provenance
            for source in link["sources"]
        })
        resources.append(
            {
                "id": id_by_path[path],
                "path": path,
                "name": disk_path.name,
                "kind": media_kind(path),
                "category": category_of(path),
                "displayRole": (
                    "top-preview" if "/previews/" in path
                    else "directory-icon" if path.startswith("game/assets/gear/")
                    else "catalog-icon" if path.startswith("game/assets/ritual/")
                    and dimensions(disk_path) in ([48, 48], [48, 40])
                    else "top-frame" if "/story/" in path
                    else "runtime-media"
                ),
                "status": review.get("status", inferred_status),
                "inferredStatus": inferred_status,
                "reviewNote": review.get("note", ""),
                "size": dimensions(disk_path),
                "bytes": disk_path.stat().st_size,
                "createdAt": resource_created_at(disk_path),
                "previewable": ext in PREVIEW_EXTS,
                "pairedT3x": paired_t3x,
                "nodeIds": node_ids,
                "codeRefs": refs,
                "sourceCandidates": source_candidates,
                "provenance": provenance,
            }
        )

    resource_by_path = {resource["path"]: resource for resource in resources}
    missing_assets: list[dict[str, str]] = list(unmatched_asset_globs)
    nodes: list[dict[str, Any]] = []
    for node in manifest_nodes:
        resource_ids: list[str] = []
        for path in node.get("assetPaths", []):
            resource = resource_by_path.get(path)
            if resource:
                resource_ids.append(resource["id"])
            else:
                missing_assets.append({"nodeId": node["id"], "path": path})
        nodes.append({
            **node,
            "resourceIds": resource_ids,
            "copyEntries": exact_copy_entries(node, texts),
            "runtimeScene": runtime_scene_by_node.get(node["id"]),
            "runtimeOverlay": runtime_overlay_by_node.get(node["id"]),
        })

    ids = [node["id"] for node in nodes]
    id_counts = Counter(ids)
    duplicate_node_ids = sorted(key for key, count in id_counts.items() if count > 1)
    id_set = set(ids)
    broken_edges = [
        edge
        for edge in manifest["edges"]
        if edge["source"] not in id_set or edge["target"] not in id_set
    ]
    missing_t3x = [
        resource["path"]
        for resource in resources
        if resource["pairedT3x"] is False
    ]
    status_counts = Counter(resource["status"] for resource in resources)
    code_scenes = {scene["id"] for scene in runtime_graph.get("scenes", [])}
    bound_scenes = set(runtime_bindings)
    unbound_runtime_scenes = sorted(code_scenes - bound_scenes)
    missing_runtime_scenes = sorted(bound_scenes - code_scenes)

    manifest_runtime_edges: dict[tuple[str, str], list[str]] = {}
    for edge in manifest["edges"]:
        source_scene = runtime_scene_by_node.get(edge["source"])
        target_scene = runtime_scene_by_node.get(edge["target"])
        if not source_scene or not target_scene or source_scene == target_scene:
            continue
        manifest_runtime_edges.setdefault((source_scene, target_scene), []).append(edge["id"])
    edges_from_overlay: dict[str, list[dict[str, Any]]] = {}
    for edge in manifest["edges"]:
        overlay = runtime_overlay_by_node.get(edge["source"])
        if overlay:
            edges_from_overlay.setdefault(edge["source"], []).append(edge)
    for incoming in manifest["edges"]:
        source_scene = runtime_scene_by_node.get(incoming["source"])
        overlay = runtime_overlay_by_node.get(incoming["target"])
        if not source_scene or not overlay:
            continue
        for outgoing in edges_from_overlay.get(incoming["target"], []):
            target_scene = runtime_scene_by_node.get(outgoing["target"])
            if not target_scene or target_scene == source_scene:
                continue
            manifest_runtime_edges.setdefault((source_scene, target_scene), []).extend(
                [incoming["id"], outgoing["id"]]
            )

    runtime_transition_by_pair = {
        (transition["from"], transition["to"]): transition
        for transition in runtime_graph.get("transitions", [])
        if transition.get("from") and transition.get("to")
    }
    runtime_transitions_missing_in_manifest = [
        transition
        for pair, transition in sorted(runtime_transition_by_pair.items())
        if pair not in manifest_runtime_edges
    ]
    manifest_transitions_missing_in_runtime = [
        {"from": pair[0], "to": pair[1], "edgeIds": edge_ids}
        for pair, edge_ids in sorted(manifest_runtime_edges.items())
        if pair not in runtime_transition_by_pair
    ]
    instance_graph = materialize_instance_graph(
        nodes,
        manifest["edges"],
        resources,
        runtime_graph,
        destinations,
    )

    return {
        "meta": {
            "version": 1,
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "resourceCount": len(resources),
            "nodeCount": len(nodes),
            "edgeCount": len(manifest["edges"]),
            "runtimeSceneCount": len(code_scenes),
            "runtimeTransitionCount": len(runtime_transition_by_pair),
            "statusCounts": dict(sorted(status_counts.items())),
        },
        "nodes": nodes,
        "edges": manifest["edges"],
        "resources": resources,
        "sceneCompositions": destinations,
        "instanceGraph": instance_graph,
        "runtimeGraph": runtime_graph,
        "audits": {
            "duplicateNodeIds": duplicate_node_ids,
            "brokenEdges": broken_edges,
            "missingAssets": missing_assets,
            "missingT3x": missing_t3x,
            "unlinkedResourceIds": [
                resource["id"] for resource in resources if resource["status"] == "unlinked"
            ],
            "legacyResourceIds": [
                resource["id"] for resource in resources if resource["status"] == "legacy"
            ],
            "backupResourceIds": [
                resource["id"] for resource in resources if resource["status"] == "backup"
            ],
            "duplicateRuntimeBindings": duplicate_runtime_bindings,
            "unboundRuntimeScenes": unbound_runtime_scenes,
            "missingRuntimeScenes": missing_runtime_scenes,
            "runtimeTransitionsMissingInManifest": runtime_transitions_missing_in_manifest,
            "manifestTransitionsMissingInRuntime": manifest_transitions_missing_in_runtime,
            "unresolvedLuaFacts": runtime_graph.get("unresolved", []),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the Story Atlas graph index")
    parser.add_argument("--check", action="store_true", help="fail on structural graph errors")
    args = parser.parse_args()

    index = build_index()
    write_json(OUTPUT, index)
    meta = index["meta"]
    audits = index["audits"]
    print(
        f"Story Atlas: {meta['nodeCount']} nodes / {meta['edgeCount']} edges / "
        f"{meta['resourceCount']} resources"
    )
    print("status:", json.dumps(meta["statusCounts"], ensure_ascii=False, sort_keys=True))
    print(
        f"audit: missing={len(audits['missingAssets'])} "
        f"broken={len(audits['brokenEdges'])} duplicate={len(audits['duplicateNodeIds'])} "
        f"missing_t3x={len(audits['missingT3x'])} "
        f"runtime_unbound={len(audits['unboundRuntimeScenes'])} "
        f"runtime_drift={len(audits['runtimeTransitionsMissingInManifest'])}"
    )
    has_errors = bool(
        audits["missingAssets"]
        or audits["brokenEdges"]
        or audits["duplicateNodeIds"]
        or audits["duplicateRuntimeBindings"]
        or audits["unboundRuntimeScenes"]
        or audits["missingRuntimeScenes"]
    )
    return 1 if args.check and has_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
