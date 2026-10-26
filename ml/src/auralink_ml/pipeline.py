"""Pipeline ``refresh-context``: ingesta → nowcast → previsión → fusión → umbrales → artefactos.

Salidas (estáticas, publicadas en GitHub Pages):
- ``context.json``: estado y dinámica de estaciones, meteorología, NO₂, tráfico, demanda,
  avisos activos y umbrales vigentes. Lo consume el navegador para fusionar por trayecto.
- ``alerts.json``: alertas para el técnico (también se convierten en Issues en CI).
- ``data/artifacts/alerts_log.jsonl``: registro de auditoría de alertas emitidas.
"""

from __future__ import annotations

import csv
import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from auralink_ml import settings
from auralink_ml.alerts import Observations, evaluate
from auralink_ml.collect_gbfs import FIELDS as SNAPSHOT_FIELDS
from auralink_ml.context.sources import SourceReading, read_all
from auralink_ml.forecasting import demand, nowcast
from auralink_ml.monitoring import weather_drift

HORIZON_MIN = 30


def _append_snapshot(gbfs: SourceReading, snapshot_dir: Path) -> None:
    if not gbfs.ok or not gbfs.updated:
        return
    snapshot_dir.mkdir(parents=True, exist_ok=True)
    path = snapshot_dir / f"{datetime.fromisoformat(gbfs.updated):%Y%m%d}.csv"
    is_new = not path.exists()
    d = gbfs.data
    with path.open("a", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        if is_new:
            writer.writerow(SNAPSHOT_FIELDS)
        for row in zip(d["id"], d["bikes"], d["docks"], d["renting"], d["returning"], strict=True):
            writer.writerow([gbfs.updated, *row])


def _demand_block(weather: SourceReading, model_name: str, today: pd.Timestamp) -> tuple[dict[str, Any], float, pd.DataFrame]:
    """Previsión de demanda para hoy y 6 días; presión = P50 hoy / mediana semanal."""
    if not weather.ok:
        return {"ok": False}, 1.0, pd.DataFrame()
    daily = demand.weather_frame(weather.data["daily"])
    model_dir = settings.ARTIFACT_DIR / "models" / model_name
    if not (model_dir / "meta.json").exists():
        return {"ok": False, "error": "modelo no entrenado"}, 1.0, daily
    fc = demand.forecast(demand.load_model(model_dir), daily[daily["date"] >= today.normalize()])
    if fc.empty:
        return {"ok": False}, 1.0, daily
    first = fc.iloc[0]
    pressure = float(first["p50"] / max(fc["p50"].median(), 1.0))
    block = {
        "ok": True,
        "model": model_name,
        "date": str(pd.Timestamp(first["date"]).date()),
        "p10": round(float(first["p10"])),
        "p50": round(float(first["p50"])),
        "p90": round(float(first["p90"])),
        "rel_width": float((first["p90"] - first["p10"]) / max(first["p50"], 1.0)),
        "pressure": round(pressure, 3),
        "days": [
            {"date": str(pd.Timestamp(r["date"]).date()), "p10": round(r["p10"]), "p50": round(r["p50"]), "p90": round(r["p90"])}
            for r in fc.to_dict("records")
        ],
    }
    return block, pressure, daily


def _weather_block(weather: SourceReading, now: datetime) -> dict[str, Any]:
    if not weather.ok:
        return {"ok": False}
    h = weather.data["hourly"]
    times = pd.to_datetime(h["time"]).tz_localize(
        "Europe/Madrid", ambiguous="NaT", nonexistent="NaT"
    )  # cambio de hora: se descarta la hora ambigua
    keep = times.notna() & (times >= pd.Timestamp(now).floor("h")) & (times < pd.Timestamp(now) + pd.Timedelta(hours=48))
    idx = np.flatnonzero(keep)
    return {
        "ok": True,
        "time": [times[i].isoformat() for i in idx],
        "precip": [h["precipitation"][i] for i in idx],
        "temp": [h["temperature_2m"][i] for i in idx],
        "wind": [h["wind_speed_10m"][i] for i in idx],
    }


def refresh_context(offline: bool = False, out_dir: Path = settings.PUBLIC_DATA_DIR) -> dict[str, Any]:
    now = datetime.now(UTC).replace(microsecond=0)
    today = pd.Timestamp(now).tz_convert("Europe/Madrid").tz_localize(None)
    thresholds = settings.load_thresholds()
    overrides = settings.load_yaml("overrides.yaml")
    readings = read_all(offline=offline)

    # --- BiciMAD: instantánea + dinámica por estación
    gbfs = readings["gbfs"]
    if not offline:
        _append_snapshot(gbfs, settings.SNAPSHOT_DIR)
    dynamics = nowcast.estimate_dynamics(nowcast.load_snapshots(settings.SNAPSHOT_DIR))

    # --- Demanda prevista y presión sobre el sistema
    demand_block, pressure, daily_weather = _demand_block(
        readings["weather"], overrides.get("promoted_demand_model", demand.MODEL_NAME), today
    )

    stations: dict[str, list[Any]] = {
        k: [] for k in ("id", "bikes", "docks", "renting", "returning", "mu", "sigma2", "p_bike_30", "p_dock_30")
    }
    low: list[dict[str, Any]] = []
    excluded = {str(e["station_id"]) for e in overrides.get("excluded_bike_stations") or []}
    if gbfs.ok:
        d = gbfs.data
        for sid, b, k, r, ret in zip(d["id"], d["bikes"], d["docks"], d["renting"], d["returning"], strict=True):
            dyn = dynamics.get(sid)
            pb = nowcast.prob_bike(b, dyn, HORIZON_MIN, pressure) if r else 0.0
            pd_ = nowcast.prob_dock(k, dyn, HORIZON_MIN, pressure) if ret else 0.0
            for key, val in (
                ("id", sid),
                ("bikes", b),
                ("docks", k),
                ("renting", r),
                ("returning", ret),
                ("mu", round(dyn.mu if dyn else 0.0, 4)),
                ("sigma2", round(dyn.sigma2 if dyn else 0.1, 4)),
                ("p_bike_30", round(pb, 3)),
                ("p_dock_30", round(pd_, 3)),
            ):
                stations[key].append(val)
            if r and sid not in excluded and pb < thresholds["station_empty_alert"].value:
                low.append({"station_id": sid, "bikes": b, "p_bike_30": round(pb, 3)})

    # --- Monitorización del modelo
    card_path = out_dir / "model_card.json"
    card = json.loads(card_path.read_text(encoding="utf-8")) if card_path.exists() else {}
    drift: dict[str, float] = {}
    train_weather = settings.ARTIFACT_DIR / "models" / str(overrides.get("promoted_demand_model")) / "train_weather.csv"
    if train_weather.exists() and not daily_weather.empty:
        recent = daily_weather[daily_weather["date"] < today.normalize()].tail(30)
        drift = weather_drift(pd.read_csv(train_weather, parse_dates=["date"]), recent, demand.WEATHER_FEATURES)

    obs = Observations(
        low_stations=sorted(low, key=lambda s: s["p_bike_30"]),
        empty_share=nowcast.empty_share(
            np.asarray([b for b, r in zip(stations["bikes"], stations["renting"], strict=True) if r])
        ),
        no2_mean=readings["air"].data.get("no2_mean"),
        demand_rel_width=demand_block.get("rel_width"),
        drift_psi=drift,
        mae_ratio=card.get("metrics", {}).get("mae_ratio_vs_climatology"),
        source_age_min={
            k: (None if v.age_minutes(now) is None else round(v.age_minutes(now) or 0, 1)) for k, v in readings.items()
        },
    )
    day = str(today.date())
    alerts = [a.to_dict(day) for a in evaluate(thresholds, obs)]

    weather_block = _weather_block(readings["weather"], now)
    notices = _notices(thresholds, weather_block, readings["traffic"], overrides)
    context = {
        "version": 1,
        "generated": now.isoformat(),
        "sources": {
            k: {"ok": v.ok, "updated": v.updated, "age_min": obs.source_age_min[k], "error": v.error} for k, v in readings.items()
        },
        "stations": stations,
        "pressure": round(pressure, 3),
        "weather": weather_block,
        "air": {"ok": readings["air"].ok, **readings["air"].data},
        "traffic": {"ok": readings["traffic"].ok, **readings["traffic"].data},
        "demand": demand_block,
        "drift_psi": drift,
        "notices": notices,
        "thresholds": {k: {"kind": t.kind, "value": t.value, "description": t.description} for k, t in thresholds.items()},
        "overrides": overrides,
        "config": {"fares": settings.load_yaml("fares.yaml"), "emissions": settings.load_yaml("emissions.yaml")},
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "context.json").write_text(json.dumps(context, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (out_dir / "alerts.json").write_text(
        json.dumps({"generated": now.isoformat(), "alerts": alerts}, ensure_ascii=False, indent=1), encoding="utf-8"
    )
    settings.ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    with (settings.ARTIFACT_DIR / "alerts_log.jsonl").open("a", encoding="utf-8") as log:
        for a in alerts:
            log.write(json.dumps({"ts": now.isoformat(), **a}, ensure_ascii=False) + "\n")

    return {
        "sources": {k: v.ok for k, v in readings.items()},
        "stations": len(stations["id"]),
        "stations_with_dynamics": len(dynamics),
        "pressure": round(pressure, 3),
        "demand_today_p50": demand_block.get("p50"),
        "no2_mean": obs.no2_mean,
        "traffic_index": readings["traffic"].data.get("congestion_index"),
        "drift_psi": drift,
        "alerts": [a["key"] for a in alerts],
        "notices": [n["key"] for n in notices],
    }


def _notices(
    th: dict[str, settings.Threshold], weather: dict[str, Any], traffic: SourceReading, overrides: dict[str, Any]
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if weather.get("ok"):
        rain = max(weather["precip"][:3], default=0.0)
        if rain >= th["rain_notice"].value:
            out.append(
                {"key": "rain_notice", "message": f"Lluvia prevista ({rain:.1f} mm/h) en las próximas horas", "value": rain}
            )
    ci = traffic.data.get("congestion_index")
    if ci is not None and ci >= th["traffic_congestion_notice"].value:
        out.append(
            {
                "key": "traffic_congestion_notice",
                "message": f"Tráfico denso (índice {ci:.0f}/100): los buses pueden retrasarse",
                "value": ci,
            }
        )
    if overrides.get("exposure_notice_active"):
        out.append(
            {
                "key": "exposure_notice",
                "message": "Aviso de calidad del aire activado por el técnico: considere modos no activos",
                "value": 1,
            }
        )
    return out
