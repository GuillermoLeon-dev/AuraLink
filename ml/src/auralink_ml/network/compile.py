"""Compila GTFS (+ estaciones GBFS) a ``network.json`` para el McRAPTOR del navegador.

Modelo compacto:
- *Patrón*: secuencia exacta de paradas de una línea con tiempos acumulados (``t``) y
  distancia acumulada (``d``) del viaje representativo.
- *Viajes*: ``[salida_en_origen_s, factor_x1000]``; la hora en la parada *i* es
  ``salida + t[i] * factor``. Así se conserva la variación horaria de la velocidad del bus
  (las plantillas EMT cambian de duración por franja) sin almacenar cada horario completo.
- *Transbordos a pie*: CSR (``start``, ``to``, ``sec``) entre paradas a ≤ ``radius`` metros.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, cast

import numpy as np
import pandas as pd

from auralink_ml.geo import haversine_m, pairs_within
from auralink_ml.network.gtfs import MODE_BY_ROUTE_TYPE, GtfsFeed, parse_gtfs_time

WALK_SPEED_MPS = 4.8 / 3.6
DETOUR_FACTOR = 1.3
TRANSFER_RADIUS_M = 400.0
MIN_TRANSFER_S = 60


@dataclass
class Pattern:
    route: int
    stops: list[int]
    offsets: list[int]
    dist: list[int]
    trips: list[tuple[int, int]] = field(default_factory=list)


@dataclass(frozen=True)
class FeedSpec:
    name: str
    path: Path


def _title(name: str) -> str:
    return name.title() if name.isupper() else name


def _expand_departures(trip_ids: pd.Series, first_dep: pd.Series, freqs: pd.DataFrame) -> pd.DataFrame:
    """Devuelve (trip_id, dep) expandiendo ``frequencies.txt``; sin frecuencias, una salida."""
    base = pd.DataFrame({"trip_id": trip_ids.values, "t0": first_dep.values})
    if freqs.empty:
        return base.rename(columns={"t0": "dep"})
    f = freqs[freqs["trip_id"].isin(base["trip_id"])].copy()
    f["start"] = parse_gtfs_time(f["start_time"])
    f["end"] = parse_gtfs_time(f["end_time"])
    f["headway"] = f["headway_secs"].astype(int)
    rows = [
        (tid, dep)
        for tid, start, end, hw in f[["trip_id", "start", "end", "headway"]].itertuples(index=False)
        for dep in range(int(start), int(end), max(int(hw), 60))
    ]
    expanded = pd.DataFrame(rows, columns=["trip_id", "dep"])
    single = base[~base["trip_id"].isin(f["trip_id"])].rename(columns={"t0": "dep"})
    return pd.concat([expanded, single], ignore_index=True)


def compile_feed(
    feed: GtfsFeed, weekday: str, stop_lookup: dict[str, int], stops_out: dict[str, list[Any]], routes_out: list[dict[str, Any]]
) -> list[Pattern]:
    services = feed.services_for_weekday(weekday)
    trips = feed.trips[feed.trips["service_id"].isin(services)]
    st = feed.stop_times[feed.stop_times["trip_id"].isin(trips["trip_id"])].copy()
    st["seq"] = st["stop_sequence"].astype(int)
    st["t"] = parse_gtfs_time(st["departure_time"].where(st["departure_time"] != "", st["arrival_time"]))
    st = st.sort_values(["trip_id", "seq"])

    stops = feed.stops.set_index("stop_id")
    for sid in st["stop_id"].unique():
        key = f"{feed.name}:{sid}"
        if key in stop_lookup:
            continue
        row = stops.loc[sid]
        stop_lookup[key] = len(stops_out["id"])
        stops_out["id"].append(key)
        stops_out["name"].append(_title(str(row["stop_name"])))
        stops_out["lat"].append(round(float(row["stop_lat"]), 6))
        stops_out["lon"].append(round(float(row["stop_lon"]), 6))

    route_index: dict[str, int] = {}
    for r in feed.routes.to_dict("records"):
        route_index[str(r["route_id"])] = len(routes_out)
        routes_out.append(
            {
                "id": f"{feed.name}:{r['route_id']}",
                "short": r["route_short_name"],
                "long": r["route_long_name"],
                "mode": MODE_BY_ROUTE_TYPE.get(int(r["route_type"]), "bus"),
                "color": f"#{r['route_color'] or '0066FF'}",
                "feed": feed.name,
            }
        )

    grouped = st.groupby("trip_id", sort=False).agg(stops=("stop_id", tuple), times=("t", list))
    grouped = grouped.join(trips.set_index("trip_id")["route_id"])
    grouped["t0"] = grouped["times"].map(lambda ts: ts[0])
    grouped["duration"] = grouped["times"].map(lambda ts: max(ts[-1] - ts[0], 1))
    departures = _expand_departures(grouped.index.to_series(), grouped["t0"], feed.frequencies)

    patterns: list[Pattern] = []
    for group_key, group in grouped.groupby(["route_id", "stops"], sort=False):
        route_id, stop_seq = cast(tuple[str, tuple[str, ...]], group_key)
        if len(stop_seq) < 2:
            continue
        rep = group.iloc[int(np.argsort(group["duration"].to_numpy())[len(group) // 2])]
        offsets = [t - rep["t0"] for t in rep["times"]]
        idx = [stop_lookup[f"{feed.name}:{s}"] for s in stop_seq]
        lat = np.asarray([stops_out["lat"][i] for i in idx])
        lon = np.asarray([stops_out["lon"][i] for i in idx])
        cum = np.concatenate([[0.0], np.cumsum(haversine_m(lat[:-1], lon[:-1], lat[1:], lon[1:]))])
        pattern = Pattern(route_index[route_id], idx, [int(o) for o in offsets], [int(d) for d in cum])
        factors = (group["duration"] / max(rep["duration"], 1)).clip(0.5, 2.0)
        deps = departures[departures["trip_id"].isin(group.index)]
        factor_by_trip = (factors * 1000).round().astype(int).to_dict()
        # EMT repite la frecuencia de la *línea* en la plantilla de cada bloque (autobús):
        # se deduplica por hora de salida para no multiplicar la oferta.
        by_dep: dict[int, int] = {}
        for tid, d in deps.itertuples(index=False):
            by_dep.setdefault(int(d), factor_by_trip[tid])
        pattern.trips = sorted(by_dep.items())
        patterns.append(pattern)
    return patterns


def build_transfers(lat: np.ndarray, lon: np.ndarray, radius_m: float = TRANSFER_RADIUS_M) -> dict[str, list[int]]:
    src, dst, dist = pairs_within(lat, lon, radius_m)
    secs = np.ceil(dist * DETOUR_FACTOR / WALK_SPEED_MPS).astype(int) + MIN_TRANSFER_S
    order = np.lexsort((secs, src))
    src, dst, secs = src[order], dst[order], secs[order]
    start = np.searchsorted(src, np.arange(len(lat) + 1)).tolist()
    return {"start": start, "to": dst.tolist(), "sec": secs.tolist()}


def load_bike_stations(station_information: Path) -> dict[str, list[Any]]:
    data = json.loads(station_information.read_text(encoding="utf-8"))["data"]["stations"]
    out: dict[str, list[Any]] = {"id": [], "name": [], "lat": [], "lon": [], "capacity": []}
    for s in data:
        if s.get("is_virtual_station"):
            continue
        out["id"].append(str(s["station_id"]))
        out["name"].append(s["name"])
        out["lat"].append(round(float(s["lat"]), 6))
        out["lon"].append(round(float(s["lon"]), 6))
        out["capacity"].append(int(s.get("capacity", 0)))
    return out


def compile_network(feeds: list[FeedSpec], station_information: Path, out_path: Path, weekday: str = "tuesday") -> dict[str, Any]:
    stop_lookup: dict[str, int] = {}
    stops_out: dict[str, list[Any]] = {"id": [], "name": [], "lat": [], "lon": []}
    routes_out: list[dict[str, Any]] = []
    patterns: list[Pattern] = []
    for spec in feeds:
        patterns += compile_feed(GtfsFeed.from_zip(spec.path, spec.name), weekday, stop_lookup, stops_out, routes_out)

    lat = np.asarray(stops_out["lat"])
    lon = np.asarray(stops_out["lon"])
    network = {
        "version": 1,
        "generated": datetime.now(UTC).isoformat(timespec="seconds"),
        "weekday": weekday,
        "sources": [f.name for f in feeds] + ["bicimad_gbfs"],
        "attribution": "Powered by CRTM · EMT Madrid · BiciMAD (Ayuntamiento de Madrid)",
        "stops": stops_out,
        "routes": routes_out,
        "patterns": [
            {"r": p.route, "s": p.stops, "t": p.offsets, "d": p.dist, "trips": [list(t) for t in p.trips]}
            for p in patterns
            if p.trips
        ],
        "transfers": build_transfers(lat, lon),
        "bike": load_bike_stations(station_information),
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(network, separators=(",", ":"), ensure_ascii=False), encoding="utf-8")
    return summarize(network)


def summarize(network: dict[str, Any]) -> dict[str, Any]:
    pats = network["patterns"]
    return {
        "stops": len(network["stops"]["id"]),
        "routes": len(network["routes"]),
        "patterns": len(pats),
        "trips": sum(len(p["trips"]) for p in pats),
        "transfers": len(network["transfers"]["to"]),
        "bike_stations": len(network["bike"]["id"]),
        "max_pattern_len": max((len(p["s"]) for p in pats), default=0),
        "nan_free": all(not math.isnan(x) for x in network["stops"]["lat"]),
    }
