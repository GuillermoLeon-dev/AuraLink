"""Monitorización de deriva de datos (CRISP-ML(Q), fase *Monitoring & Maintenance*)."""

from __future__ import annotations

import numpy as np
import pandas as pd

EPS = 1e-4


def psi(reference: np.ndarray, current: np.ndarray, bins: int = 10) -> float:
    """Population Stability Index con cortes en los cuantiles de la referencia.
    Convención habitual: < 0,1 estable · 0,1–0,2 moderada · > 0,2 deriva relevante."""
    reference = reference[~np.isnan(reference)]
    current = current[~np.isnan(current)]
    if len(reference) < bins or len(current) == 0:
        return 0.0
    edges = np.unique(np.quantile(reference, np.linspace(0, 1, bins + 1)))
    if len(edges) < 3:
        return 0.0
    edges[0], edges[-1] = -np.inf, np.inf
    ref_frac = np.histogram(reference, edges)[0] / len(reference)
    cur_frac = np.histogram(current, edges)[0] / len(current)
    ref_frac, cur_frac = np.clip(ref_frac, EPS, None), np.clip(cur_frac, EPS, None)
    return float(np.sum((cur_frac - ref_frac) * np.log(cur_frac / ref_frac)))


def seasonal_reference(train: pd.DataFrame, today: pd.Timestamp, window_days: int = 25) -> pd.DataFrame:
    """Filas de entrenamiento en la misma época del año (±window), para no confundir
    estacionalidad con deriva."""
    doy = train["date"].dt.day_of_year
    delta = np.abs(doy - today.day_of_year)
    return pd.DataFrame(train.loc[np.minimum(delta, 365 - delta) <= window_days])


def weather_drift(train: pd.DataFrame, recent: pd.DataFrame, features: list[str]) -> dict[str, float]:
    """PSI de cada variable del periodo reciente frente a la misma época de años anteriores
    (referencia centrada en la fecha mediana del periodo reciente)."""
    if recent.empty:
        return {}
    ref = seasonal_reference(train, pd.Timestamp(recent["date"].median()))
    return {f: round(psi(ref[f].to_numpy(dtype=float), recent[f].to_numpy(dtype=float)), 4) for f in features}
