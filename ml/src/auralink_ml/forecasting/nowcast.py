"""Nowcast de disponibilidad por estación BiciMAD (serie temporal de alta frecuencia).

Modelo de difusión con deriva por estación: ΔB ~ N(μ·Δt, σ²·Δt), con μ y σ² estimados de las
instantáneas GBFS y *contraídos* (shrinkage bayesiano empírico) hacia la media del sistema
cuando la estación tiene pocos datos (arranque en frío).

P(al menos una bici a h minutos) = 1 − Φ((0,5 − (B₀ + μh)) / √(σ²h + 0,25)).
El navegador aplica la misma fórmula (web/src/domain/fusion.ts) con la hora real de llegada.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

SHRINK_K = 10.0  # observaciones equivalentes del prior
MIN_SIGMA2 = 0.02  # bicis²/min, suelo para no sobreconfiar


@dataclass(frozen=True)
class StationDynamics:
    station_id: str
    mu: float  # bicis/min
    sigma2: float  # bicis²/min
    n: int


def load_snapshots(snapshot_dir: Path, max_files: int = 7) -> pd.DataFrame:
    files = sorted(snapshot_dir.glob("*.csv"))[-max_files:]
    if not files:
        return pd.DataFrame(columns=["ts", "station_id", "bikes", "docks"])
    df = pd.concat([pd.read_csv(f, dtype={"station_id": str}) for f in files], ignore_index=True)
    df["ts"] = pd.to_datetime(df["ts"], utc=True)
    return df.drop_duplicates(["ts", "station_id"]).sort_values(["station_id", "ts"])


def estimate_dynamics(snapshots: pd.DataFrame) -> dict[str, StationDynamics]:
    if snapshots.empty:
        return {}
    df = snapshots.copy()
    df["dt"] = df.groupby("station_id")["ts"].diff().dt.total_seconds() / 60
    df["db"] = df.groupby("station_id")["bikes"].diff()
    steps = df[(df["dt"] > 0) & (df["dt"] <= 30)]
    if steps.empty:
        return {}
    global_mu = float((steps["db"] / steps["dt"]).mean())
    global_s2 = max(float(((steps["db"] - global_mu * steps["dt"]) ** 2 / steps["dt"]).mean()), MIN_SIGMA2)
    out: dict[str, StationDynamics] = {}
    for sid, g in steps.groupby("station_id"):
        n = len(g)
        mu_s = float((g["db"] / g["dt"]).mean())
        s2_s = float(((g["db"] - mu_s * g["dt"]) ** 2 / g["dt"]).mean())
        w = n / (n + SHRINK_K)
        out[str(sid)] = StationDynamics(
            station_id=str(sid),
            mu=w * mu_s + (1 - w) * global_mu,
            sigma2=max(w * s2_s + (1 - w) * global_s2, MIN_SIGMA2),
            n=n,
        )
    return out


def _phi(x: float) -> float:
    return 0.5 * (1 + math.erf(x / math.sqrt(2)))


def prob_at_least_one(level: float, drift: float, sigma2: float, minutes: float) -> float:
    mean = level + drift * minutes
    sd = math.sqrt(max(sigma2 * minutes, 0.0) + 0.25)
    return 1.0 - _phi((0.5 - mean) / sd)


def prob_bike(bikes: int, dyn: StationDynamics | None, minutes: float, pressure: float = 1.0) -> float:
    mu, s2 = (dyn.mu, dyn.sigma2) if dyn else (0.0, MIN_SIGMA2 * 5)
    return prob_at_least_one(bikes, mu, s2 * pressure, minutes)


def prob_dock(docks: int, dyn: StationDynamics | None, minutes: float, pressure: float = 1.0) -> float:
    mu, s2 = (dyn.mu, dyn.sigma2) if dyn else (0.0, MIN_SIGMA2 * 5)
    return prob_at_least_one(docks, -mu, s2 * pressure, minutes)


def empty_share(bikes: np.ndarray) -> float:
    return float(np.mean(bikes <= 0)) if len(bikes) else 0.0
