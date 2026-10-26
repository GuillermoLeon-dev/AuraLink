"""Rutas y carga de configuración versionada (``config/*.yaml``)."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[3]
CONFIG_DIR = REPO_ROOT / "config"
RAW_DIR = REPO_ROOT / "data" / "raw"
SNAPSHOT_DIR = REPO_ROOT / "data" / "gbfs_snapshots"
ARTIFACT_DIR = REPO_ROOT / "data" / "artifacts"
PUBLIC_DATA_DIR = REPO_ROOT / "web" / "public" / "data"

MADRID_CENTER = (40.4168, -3.7038)


def load_yaml(name: str, config_dir: Path = CONFIG_DIR) -> dict[str, Any]:
    with (config_dir / name).open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise ValueError(f"{name}: se esperaba un mapa YAML")
    return data


@dataclass(frozen=True)
class Threshold:
    key: str
    kind: str  # "alert" | "notice"
    value: float
    description: str
    extra: dict[str, Any]


def load_thresholds(config_dir: Path = CONFIG_DIR) -> dict[str, Threshold]:
    raw = load_yaml("thresholds.yaml", config_dir)["thresholds"]
    result: dict[str, Threshold] = {}
    for key, spec in raw.items():
        extra = {k: v for k, v in spec.items() if k not in {"kind", "value", "description"}}
        if spec["kind"] not in {"alert", "notice"}:
            raise ValueError(f"umbral {key}: kind inválido {spec['kind']!r}")
        result[key] = Threshold(key, spec["kind"], float(spec["value"]), spec["description"], extra)
    return result
