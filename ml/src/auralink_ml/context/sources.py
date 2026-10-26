"""Adaptadores de fuentes de contexto. Cada uno devuelve un ``SourceReading`` normalizado con
su marca temporal, de modo que la fusión pueda ponderar por frescura (confianza).

Fuentes (licencias abiertas, sin datos personales):
- GBFS BiciMAD (estado de estaciones).
- Open-Meteo (previsión horaria y diaria; CC BY 4.0).
- Calidad del aire en tiempo real, Ayuntamiento de Madrid (NO₂, magnitud 8; CC BY 4.0).
- Intensidad de tráfico en tiempo real (informo.madrid.es, ``pm.xml``; CC BY 4.0).
"""

from __future__ import annotations

import csv
import io
import json
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

import truststore

from auralink_ml.settings import MADRID_CENTER, RAW_DIR

# Verificación TLS con el almacén de confianza del sistema operativo (no se desactiva nunca).
truststore.inject_into_ssl()

MADRID_TZ = ZoneInfo("Europe/Madrid")
CACHE_DIR = RAW_DIR / "context"

URLS = {
    "gbfs_status": "https://madrid.publicbikesystem.net/customer/gbfs/v2/en/station_status",
    "weather": (
        f"https://api.open-meteo.com/v1/forecast?latitude={MADRID_CENTER[0]}&longitude={MADRID_CENTER[1]}"
        "&hourly=temperature_2m,precipitation,wind_speed_10m"
        "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max"
        "&past_days=30&forecast_days=7&timezone=Europe%2FMadrid"
    ),
    "air": "https://datos.madrid.es/egob/catalogo/212531-10515086-calidad-aire-tiempo-real.csv",
    "traffic": "https://informo.madrid.es/informo/tmadrid/pm.xml",
}


@dataclass
class SourceReading:
    name: str
    ok: bool
    updated: str | None
    data: dict[str, Any] = field(default_factory=dict)
    error: str | None = None

    def age_minutes(self, now: datetime) -> float | None:
        if not self.updated:
            return None
        return (now - datetime.fromisoformat(self.updated)).total_seconds() / 60


def _fetch_bytes(name: str, offline: bool, timeout: float = 30.0) -> bytes:
    cache = CACHE_DIR / f"{name}.raw"
    if offline:
        return cache.read_bytes()
    with urllib.request.urlopen(URLS[name], timeout=timeout) as resp:  # noqa: S310 - URLs fijas
        body: bytes = resp.read()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache.write_bytes(body)
    return body


def _safe(name: str, offline: bool, parse: Any) -> SourceReading:
    try:
        return parse(_fetch_bytes(name, offline))  # type: ignore[no-any-return]
    except Exception as exc:
        return SourceReading(name, ok=False, updated=None, error=f"{exc.__class__.__name__}: {exc}"[:200])


# ------------------------------------------------------------------ GBFS
def parse_gbfs(body: bytes) -> SourceReading:
    payload = json.loads(body)
    stations = payload["data"]["stations"]
    data = {
        "id": [str(s["station_id"]) for s in stations],
        "bikes": [int(s.get("num_bikes_available", 0)) for s in stations],
        "docks": [int(s.get("num_docks_available", 0)) for s in stations],
        "renting": [int(bool(s.get("is_renting"))) for s in stations],
        "returning": [int(bool(s.get("is_returning"))) for s in stations],
    }
    updated = datetime.fromtimestamp(payload["last_updated"], tz=UTC).isoformat()
    return SourceReading("gbfs", True, updated, data)


# ------------------------------------------------------------------ meteorología
def parse_weather(body: bytes) -> SourceReading:
    payload = json.loads(body)
    data = {"hourly": payload["hourly"], "daily": payload["daily"]}
    return SourceReading("weather", True, datetime.now(UTC).isoformat(timespec="seconds"), data)


# ------------------------------------------------------------------ calidad del aire
def parse_air(body: bytes, magnitude: str = "8") -> SourceReading:
    """Media urbana de NO₂ (µg/m³) en la última hora con datos validados (V)."""
    rows = list(csv.DictReader(io.StringIO(body.decode("utf-8-sig")), delimiter=";"))
    no2 = [r for r in rows if r["MAGNITUD"] == magnitude]
    if not no2:
        return SourceReading("air", False, None, error="sin NO2")
    last_hour = 0
    for h in range(1, 25):
        if any(r.get(f"V{h:02d}") == "V" for r in no2):
            last_hour = h
    values = [float(r[f"H{last_hour:02d}"]) for r in no2 if r.get(f"V{last_hour:02d}") == "V"]
    first = no2[0]
    day = datetime(int(first["ANO"]), int(first["MES"]), int(first["DIA"]), tzinfo=MADRID_TZ)
    updated = (day + timedelta(hours=last_hour)).astimezone(UTC).isoformat()
    data = {
        "no2_mean": round(sum(values) / len(values), 1) if values else None,
        "no2_max": max(values) if values else None,
        "stations": len(values),
        "hour": last_hour,
    }
    return SourceReading("air", bool(values), updated, data)


# ------------------------------------------------------------------ tráfico
def parse_traffic(body: bytes) -> SourceReading:
    """Índice de congestión urbano: media de ``carga`` (0–100) de los puntos sin error."""
    root = ET.fromstring(body)  # noqa: S314 - fuente oficial fija
    stamp = root.findtext("fecha_hora")
    loads = [
        float(pm.findtext("carga") or 0)
        for pm in root.iter("pm")
        if (pm.findtext("error") or "N") == "N" and pm.findtext("carga") is not None
    ]
    updated = None
    if stamp:
        updated = datetime.strptime(stamp, "%d/%m/%Y %H:%M:%S").replace(tzinfo=MADRID_TZ).astimezone(UTC).isoformat()
    data = {"congestion_index": round(sum(loads) / len(loads), 1) if loads else None, "points": len(loads)}
    return SourceReading("traffic", bool(loads), updated, data)


def read_all(offline: bool = False) -> dict[str, SourceReading]:
    return {
        "gbfs": _safe("gbfs_status", offline, parse_gbfs),
        "weather": _safe("weather", offline, parse_weather),
        "air": _safe("air", offline, parse_air),
        "traffic": _safe("traffic", offline, parse_traffic),
    }


def cache_path(name: str) -> Path:
    return CACHE_DIR / f"{name}.raw"
