"""Descarga de datos abiertos de entrada (fase *Data Understanding*). Fuentes y licencias en
AURA-DOC-00. Las URL son fijas: no se descarga nada indicado por contenido de terceros."""

from __future__ import annotations

import urllib.request
from datetime import date, timedelta
from pathlib import Path

import truststore

from auralink_ml.settings import MADRID_CENTER, RAW_DIR

truststore.inject_into_ssl()

SOURCES: dict[str, str] = {
    "metro_gtfs.zip": "https://crtm.maps.arcgis.com/sharing/rest/content/items/5c7f2951962540d69ffe8f640d94c246/data",
    "ml_gtfs.zip": "https://www.arcgis.com/sharing/rest/content/items/aaed26cc0ff64b0c947ac0bc3e033196/data",
    "emt_gtfs.zip": "https://servicios.emtmadrid.es:8443/gtfs/transitemt.zip",
    "bicimad_station_information.json": "https://madrid.publicbikesystem.net/customer/gbfs/v2/en/station_information",
    "bicimad_viajes_diarios.csv": (
        "https://datos.madrid.es/dataset/900043-0-viajes-diario-bicimad/resource/"
        "900043-0-viajes-diario-bicimad-csv/download/900043-0-viajes-diario-bicimad-csv.csv"
    ),
}


def weather_archive_url(start: date, end: date) -> str:
    return (
        "https://archive-api.open-meteo.com/v1/archive?"
        f"latitude={MADRID_CENTER[0]}&longitude={MADRID_CENTER[1]}&start_date={start}&end_date={end}"
        "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max&timezone=Europe%2FMadrid"
    )


def download(url: str, dest: Path, timeout: float = 180.0) -> int:
    dest.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "auralink-ml/1.0 (+datos abiertos)"})  # noqa: S310
    with urllib.request.urlopen(request, timeout=timeout) as resp:  # noqa: S310 - URLs fijas
        body: bytes = resp.read()
    tmp = dest.with_suffix(dest.suffix + ".part")
    tmp.write_bytes(body)
    tmp.replace(dest)
    return len(body)


def fetch_all(raw_dir: Path = RAW_DIR, include_training: bool = True) -> dict[str, int]:
    sizes = {name: download(url, raw_dir / name) for name, url in SOURCES.items()}
    if include_training:
        end = date.today() - timedelta(days=2)
        sizes["openmeteo_madrid_daily.json"] = download(
            weather_archive_url(date(2024, 1, 1), end), raw_dir / "openmeteo_madrid_daily.json"
        )
    return sizes
