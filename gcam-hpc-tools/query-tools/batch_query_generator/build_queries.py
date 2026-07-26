#!/usr/bin/env python3
"""Purpose: Build a GCAM batch query XML from query-config.yaml.

Author: Jingyang Song, Peking University; Jul 2026;

Usage:
    python build_queries.py query-config.yaml

The script has no third-party dependencies. It supports the simple YAML format
used by query-config.yaml: top-level keys with string values or lists of strings.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Tuple


SCRIPT_DIR = Path(__file__).resolve().parent


def parse_simple_yaml(path: Path) -> Dict[str, object]:
    data: Dict[str, object] = {}
    current_key: str | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue

        if not raw_line.startswith((" ", "\t")) and ":" in line:
            key, value = line.split(":", 1)
            current_key = key.strip()
            data[current_key] = unquote(value.strip()) if value.strip() else ""
            continue

        stripped = line.strip()
        if stripped.startswith("-") and current_key:
            if data.get(current_key) == "":
                data[current_key] = []
            if not isinstance(data[current_key], list):
                raise ValueError(f"Key {current_key!r} mixes scalar and list values")
            data[current_key].append(unquote(stripped[1:].strip()))
            continue

        raise ValueError(f"Unsupported config line: {raw_line}")

    return data


def unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def as_list(config: Dict[str, object], key: str) -> List[str]:
    value = config.get(key, [])
    if value == "":
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    raise ValueError(f"Config key {key!r} must be a string or list")


def as_string(config: Dict[str, object], key: str, default: str = "") -> str:
    value = config.get(key, default)
    if value == "":
        return default
    if isinstance(value, list):
        if not value:
            return default
        if len(value) == 1:
            return str(value[0])
        raise ValueError(f"Config key {key!r} must be a string or a single-item list")
    return str(value)


def resolve_path(value: str, config_path: Path) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path

    config_relative = (config_path.parent / path).resolve()
    if config_relative.exists() or path.parent != Path("."):
        return config_relative

    return (SCRIPT_DIR / path).resolve()


def load_queries(query_files: List[str], config_path: Path) -> List[Tuple[str, ET.Element]]:
    queries: List[Tuple[str, ET.Element]] = []
    for value in query_files:
        path = resolve_path(value, config_path)
        if not path.exists():
            raise FileNotFoundError(f"Query file not found: {path}")

        root = ET.parse(path).getroot()
        for node in root.findall(".//supplyDemandQuery"):
            title = node.get("title")
            if title:
                queries.append((title, node))
    return queries


def select_queries(all_queries: List[Tuple[str, ET.Element]], selected_titles: List[str]) -> List[Tuple[str, ET.Element]]:
    if any(title.lower() == "all" for title in selected_titles):
        return all_queries

    by_title: Dict[str, List[ET.Element]] = {}
    for title, node in all_queries:
        by_title.setdefault(title, []).append(node)

    selected: List[Tuple[str, ET.Element]] = []
    missing: List[str] = []
    for title in selected_titles:
        nodes = by_title.get(title)
        if nodes:
            selected.extend((title, node) for node in nodes)
        else:
            missing.append(title)

    if missing:
        raise ValueError("Selected queries not found:\n" + "\n".join(f"  - {title}" for title in missing))
    return selected


def select_regions(selected_regions: List[str], available_regions: List[str]) -> List[str]:
    if any(region.lower() == "all" for region in selected_regions):
        return available_regions

    available = set(available_regions)
    missing = [region for region in selected_regions if region not in available]
    if missing:
        raise ValueError("Selected regions not found in available_regions:\n" + "\n".join(f"  - {region}" for region in missing))
    return selected_regions


def build_query_xml(queries: List[Tuple[str, ET.Element]], regions: List[str], output_file: Path) -> None:
    root = ET.Element("queries")
    for _, query_node in queries:
        aquery = ET.SubElement(root, "aQuery")
        for region in regions:
            region_node = ET.SubElement(aquery, "region", name=region)
            region_node.tail = "\n"

        query_copy = ET.fromstring(ET.tostring(query_node, encoding="unicode"))
        aquery.append(query_copy)
        query_copy.tail = "\n"
        aquery.tail = "\n"

    output_file.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(output_file, encoding="utf-8", xml_declaration=True)


def default_output_path() -> Path:
    timestamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    return (SCRIPT_DIR.parent / "user_batch_queries" / f"queries-{timestamp}.xml").resolve()


def main(argv: List[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build a GCAM batch query XML from query-config.yaml")
    parser.add_argument("config", nargs="?", default=str(SCRIPT_DIR / "query-config.yaml"), help="Path to query-config.yaml")
    args = parser.parse_args(argv)

    config_path = Path(args.config).resolve()
    config = parse_simple_yaml(config_path)

    query_files = as_list(config, "query_files")
    selected_query_titles = as_list(config, "selected_queries")
    selected_region_names = as_list(config, "selected_regions")
    available_regions = as_list(config, "available_regions")

    if not query_files:
        raise ValueError("query_files must contain at least one XML file")
    if not selected_query_titles:
        raise ValueError("selected_queries must contain at least one query title or All")
    if not selected_region_names:
        raise ValueError("selected_regions must contain at least one region or All")
    if not available_regions:
        raise ValueError("available_regions must contain at least one region")

    all_queries = load_queries(query_files, config_path)
    queries = select_queries(all_queries, selected_query_titles)
    regions = select_regions(selected_region_names, available_regions)

    output_value = as_string(config, "output_file", "").strip()
    output_file = resolve_path(output_value, config_path) if output_value else default_output_path()

    build_query_xml(queries, regions, output_file)
    print(f"Generated: {output_file}")
    print(f"Queries: {len(queries)}")
    print(f"Regions: {len(regions)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
