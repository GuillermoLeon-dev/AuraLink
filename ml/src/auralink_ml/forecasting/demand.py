"""Previsión de la demanda diaria de BiciMAD (viajes/día).

Modelo híbrido (CRISP-ML(Q), fase *Modeling*):
1. **Nivel**: tendencia log-lineal ajustada por mínimos cuadrados. Captura el crecimiento
   estructural del sistema (la demanda casi se duplica entre 2024 y 2025), que los árboles
   no pueden extrapolar.
2. **Patrón**: LightGBM cuantílico (q10/q50/q90) sobre el residuo logarítmico con variables
   de calendario y meteorología. *Sin retardos de la propia serie*: el dato abierto se publica
   con meses de retraso, así que en operación no habría lags recientes.
3. **Calibración**: predicción conforme sobre cuantiles (CQR, Romano et al. 2019) para que el
   intervalo P10–P90 tenga cobertura empírica cercana al 80 %.

Evaluación con origen móvil (folds mensuales) frente a dos líneas base: climatología (media
por día de la semana y mes) y naïve estacional (lag 7; cota optimista no disponible en producción).
"""

from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass, field
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

import holidays
import lightgbm as lgb
import numpy as np
import pandas as pd

from auralink_ml import settings

MODEL_NAME = "demand-lgbm-v1"
QUANTILES = (0.1, 0.5, 0.9)
COVERAGE_TARGET = 0.8
FEATURES = [
    "dow",
    "month",
    "doy_sin",
    "doy_cos",
    "is_weekend",
    "is_holiday",
    "is_bridge",
    "temp_max",
    "temp_min",
    "precip",
    "rainy",
    "wind_max",
]
WEATHER_FEATURES = ["temp_max", "temp_min", "precip", "wind_max"]
LGB_PARAMS: dict[str, Any] = {
    "learning_rate": 0.03,
    "num_leaves": 15,
    "min_data_in_leaf": 10,
    "feature_fraction": 0.9,
    "bagging_fraction": 0.9,
    "bagging_freq": 1,
    "lambda_l2": 1.0,
    "verbose": -1,
    "seed": 42,
}
NUM_ROUNDS = 400
TREND_ORIGIN = date(2024, 1, 1)


# ---------------------------------------------------------------- datos
def load_trips(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, sep=";", encoding="utf-8-sig")
    df.columns = [c.strip().lower() for c in df.columns]
    df = df.rename(columns={"fecha": "date", "viajes": "trips"})
    df["date"] = pd.to_datetime(df["date"])
    return df[["date", "trips"]].dropna().sort_values("date").reset_index(drop=True)


def load_weather_daily(path: Path) -> pd.DataFrame:
    daily = json.loads(path.read_text(encoding="utf-8"))["daily"]
    return weather_frame(daily)


def weather_frame(daily: dict[str, list[Any]]) -> pd.DataFrame:
    return pd.DataFrame(
        {
            "date": pd.to_datetime(daily["time"]),
            "temp_max": daily["temperature_2m_max"],
            "temp_min": daily["temperature_2m_min"],
            "precip": daily["precipitation_sum"],
            "wind_max": daily["wind_speed_10m_max"],
        }
    ).dropna()


def calendar_features(dates: pd.Series) -> pd.DataFrame:
    years = sorted(set(dates.dt.year))
    hol = holidays.country_holidays("ES", subdiv="MD", years=years)
    for y in years:  # festivos locales de la ciudad de Madrid (no incluidos en la subdivisión MD)
        hol[date(y, 5, 15)] = "San Isidro"
        hol[date(y, 11, 9)] = "Nuestra Señora de la Almudena"
    d = pd.DataFrame({"date": dates})
    d["dow"] = d["date"].dt.day_of_week
    d["month"] = d["date"].dt.month
    doy = d["date"].dt.day_of_year
    d["doy_sin"] = np.sin(2 * np.pi * doy / 365.25)
    d["doy_cos"] = np.cos(2 * np.pi * doy / 365.25)
    d["is_weekend"] = (d["dow"] >= 5).astype(int)
    d["is_holiday"] = d["date"].dt.date.map(lambda x: int(x in hol))
    prev_h = (d["date"] - pd.Timedelta(days=1)).dt.date.map(lambda x: x in hol)
    next_h = (d["date"] + pd.Timedelta(days=1)).dt.date.map(lambda x: x in hol)
    d["is_bridge"] = (((d["dow"] == 0) & next_h) | ((d["dow"] == 4) & prev_h)).astype(int)
    d["t_days"] = (d["date"] - pd.Timestamp(TREND_ORIGIN)).dt.days
    return d


def build_features(trips: pd.DataFrame | None, weather: pd.DataFrame) -> pd.DataFrame:
    base = weather if trips is None else trips.merge(weather, on="date", how="inner")
    feats = base.merge(calendar_features(base["date"]), on="date")
    feats["rainy"] = (feats["precip"] >= 1.0).astype(int)
    return feats


# ---------------------------------------------------------------- modelo
@dataclass
class DemandModel:
    trend: tuple[float, float] = (0.0, 0.0)  # log(trips) ≈ a + b·t_days
    conformal_margin: float = 0.0  # en espacio logarítmico
    boosters: dict[float, lgb.Booster] = field(default_factory=dict)

    def _level(self, t_days: pd.Series) -> np.ndarray:
        a, b = self.trend
        return np.asarray(a + b * t_days.to_numpy(dtype=float))

    def fit(self, df: pd.DataFrame) -> DemandModel:
        y_log = np.log(df["trips"].to_numpy(dtype=float))
        b, a = np.polyfit(df["t_days"].to_numpy(dtype=float), y_log, 1)
        self.trend = (float(a), float(b))
        resid = y_log - self._level(df["t_days"])
        for q in QUANTILES:
            params = {**LGB_PARAMS, "objective": "quantile", "alpha": q}
            self.boosters[q] = lgb.train(params, lgb.Dataset(df[FEATURES], label=resid), NUM_ROUNDS)
        return self

    def predict_log(self, df: pd.DataFrame, calibrated: bool = True) -> dict[float, np.ndarray]:
        level = self._level(df["t_days"])
        out = {q: level + self.boosters[q].predict(df[FEATURES]) for q in QUANTILES}
        lo, hi = np.minimum(out[0.1], out[0.5]), np.maximum(out[0.9], out[0.5])
        margin = self.conformal_margin if calibrated else 0.0
        return {0.1: lo - margin, 0.5: out[0.5], 0.9: hi + margin}

    def predict(self, df: pd.DataFrame) -> dict[float, np.ndarray]:
        return {q: np.exp(v) for q, v in self.predict_log(df).items()}


def conformity_scores(y_log: np.ndarray, pred_log: dict[float, np.ndarray]) -> np.ndarray:
    """Puntuación CQR: cuánto queda fuera el valor real del intervalo [q10, q90]."""
    return np.asarray(np.maximum(pred_log[0.1] - y_log, y_log - pred_log[0.9]), dtype=float)


def conformal_quantile(scores: np.ndarray, coverage: float = COVERAGE_TARGET) -> float:
    n = len(scores)
    if n == 0:
        return 0.0
    level = min(1.0, np.ceil((n + 1) * coverage) / n)
    return float(np.quantile(scores, level))


# ---------------------------------------------------------------- evaluación
@dataclass
class FoldResult:
    month: str
    mae_model: float
    mae_climatology: float
    mae_seasonal_naive: float
    coverage_80_raw: float
    coverage_80_conformal: float
    mean_rel_width: float


def backtest(df: pd.DataFrame, n_folds: int = 6) -> tuple[list[FoldResult], np.ndarray]:
    """Origen móvil mensual. La calibración conforme de cada fold usa solo puntuaciones de
    folds anteriores (CQR en línea), así la cobertura reportada es honesta."""
    df = df.sort_values("date").reset_index(drop=True)
    df["naive7"] = df["trips"].shift(7)
    months = df["date"].dt.to_period("M").unique()[-n_folds:]
    results: list[FoldResult] = []
    scores: list[np.ndarray] = []
    for month in months:
        train = df[df["date"].dt.to_period("M") < month]
        test = df[df["date"].dt.to_period("M") == month]
        model = DemandModel().fit(train)
        # calibración: últimas 8 semanas del entrenamiento con un modelo que no las ha visto
        # + puntuaciones de folds previos
        calib_cut = train["date"].max() - pd.Timedelta(days=56)
        inner = DemandModel().fit(train[train["date"] <= calib_cut])
        calib = train[train["date"] > calib_cut]
        calib_scores = conformity_scores(np.log(calib["trips"].to_numpy(dtype=float)), inner.predict_log(calib, calibrated=False))
        model.conformal_margin = conformal_quantile(np.concatenate([calib_scores, *scores]))

        y = test["trips"].to_numpy(dtype=float)
        raw = {q: np.exp(v) for q, v in model.predict_log(test, calibrated=False).items()}
        cal = model.predict(test)
        clim = train.groupby(["dow", "month"])["trips"].mean()
        clim_dow = train.groupby("dow")["trips"].mean()
        clim_pred = np.asarray([clim.get((d, m), clim_dow[d]) for d, m in zip(test["dow"], test["month"], strict=True)])
        results.append(
            FoldResult(
                month=str(month),
                mae_model=float(np.mean(np.abs(y - cal[0.5]))),
                mae_climatology=float(np.mean(np.abs(y - clim_pred))),
                mae_seasonal_naive=float(np.mean(np.abs(y - test["naive7"].to_numpy(dtype=float)))),
                coverage_80_raw=float(np.mean((y >= raw[0.1]) & (y <= raw[0.9]))),
                coverage_80_conformal=float(np.mean((y >= cal[0.1]) & (y <= cal[0.9]))),
                mean_rel_width=float(np.mean((cal[0.9] - cal[0.1]) / np.maximum(cal[0.5], 1))),
            )
        )
        scores.append(conformity_scores(np.log(y), model.predict_log(test, calibrated=False)))
    return results, np.concatenate(scores)


def reference_profile(df: pd.DataFrame) -> dict[str, list[float]]:
    """Deciles de entrenamiento de las variables meteorológicas (referencia para PSI)."""
    return {f: [float(v) for v in np.quantile(df[f], np.linspace(0, 1, 11))] for f in WEATHER_FEATURES}


# ---------------------------------------------------------------- persistencia
def save_model(model: DemandModel, model_dir: Path) -> None:
    model_dir.mkdir(parents=True, exist_ok=True)
    for q, booster in model.boosters.items():
        # vía texto: la librería nativa de LightGBM no admite rutas no ASCII en Windows
        (model_dir / f"q{int(q * 100):02d}.txt").write_text(booster.model_to_string(), encoding="utf-8")
    meta = {"trend": model.trend, "conformal_margin": model.conformal_margin}
    (model_dir / "meta.json").write_text(json.dumps(meta), encoding="utf-8")


def load_model(model_dir: Path) -> DemandModel:
    meta = json.loads((model_dir / "meta.json").read_text(encoding="utf-8"))
    boosters = {q: lgb.Booster(model_str=(model_dir / f"q{int(q * 100):02d}.txt").read_text(encoding="utf-8")) for q in QUANTILES}
    return DemandModel(tuple(meta["trend"]), float(meta["conformal_margin"]), boosters)


def forecast(model: DemandModel, weather_daily: pd.DataFrame) -> pd.DataFrame:
    feats = build_features(None, weather_daily)
    pred = model.predict(feats)
    return pd.DataFrame({"date": feats["date"], "p10": pred[0.1], "p50": pred[0.5], "p90": pred[0.9]})


# ---------------------------------------------------------------- orquestación
def run_training(artifact_dir: Path = settings.ARTIFACT_DIR, public_dir: Path = settings.PUBLIC_DATA_DIR) -> dict[str, Any]:
    trips = load_trips(settings.RAW_DIR / "bicimad_viajes_diarios.csv")
    weather = load_weather_daily(settings.RAW_DIR / "openmeteo_madrid_daily.json")
    df = build_features(trips, weather)
    folds, fold_scores = backtest(df)
    mean = lambda key: float(np.mean([getattr(f, key) for f in folds]))  # noqa: E731
    summary = {
        "mae_model": mean("mae_model"),
        "mae_climatology": mean("mae_climatology"),
        "mae_seasonal_naive": mean("mae_seasonal_naive"),
        "coverage_80_raw": mean("coverage_80_raw"),
        "coverage_80_conformal": mean("coverage_80_conformal"),
        "mean_rel_width": mean("mean_rel_width"),
    }
    summary["mae_ratio_vs_climatology"] = summary["mae_model"] / summary["mae_climatology"]
    summary["mape_model"] = summary["mae_model"] / float(df["trips"].tail(180).mean())

    model = DemandModel().fit(df)
    model.conformal_margin = conformal_quantile(fold_scores)
    model_dir = artifact_dir / "models" / MODEL_NAME
    save_model(model, model_dir)
    # referencia para la monitorización de deriva (PSI) por estacionalidad
    df[["date", *WEATHER_FEATURES]].to_csv(model_dir / "train_weather.csv", index=False)
    importance = dict(zip(FEATURES, model.boosters[0.5].feature_importance("gain").round(1).tolist(), strict=True))

    card = {
        "name": MODEL_NAME,
        "task": "Previsión de viajes diarios del sistema BiciMAD (P10/P50/P90 calibrados)",
        "method": "Tendencia log-lineal + LightGBM cuantílico sobre residuo + calibración conforme (CQR)",
        "trained_at": datetime.now(UTC).isoformat(timespec="seconds"),
        "training_range": [str(df["date"].min().date()), str(df["date"].max().date())],
        "n_days": len(df),
        "features": FEATURES,
        "trend_growth_per_year": float(np.exp(model.trend[1] * 365) - 1),
        "conformal_margin_log": model.conformal_margin,
        "data_sources": ["datos.madrid.es 900043 (viajes diarios BiciMAD)", "Open-Meteo archive", "holidays (ES-MD)"],
        "personal_data": "Ninguno: series agregadas del sistema",
        "validation": "Backtesting con origen móvil, 6 folds mensuales; CQR en línea",
        "folds": [asdict(f) for f in folds],
        "metrics": summary,
        "feature_importance_gain": importance,
        "reference_profile": reference_profile(df),
        "limitations": [
            "Sin retardos de la serie: el dato abierto se publica con retraso.",
            "La tendencia se extrapola desde el último dato publicado; cambios de tarifa o de flota no se anticipan.",
            "Demanda agregada del sistema, no por estación.",
            "Meteorología diaria de un único punto (centro de Madrid).",
        ],
        "promotion": "Manual por técnico vía Pull Request (config/overrides.yaml: promoted_demand_model)",
    }
    (model_dir / "model_card.json").write_text(json.dumps(card, indent=2, ensure_ascii=False), encoding="utf-8")
    public_dir.mkdir(parents=True, exist_ok=True)
    (public_dir / "model_card.json").write_text(json.dumps(card, ensure_ascii=False), encoding="utf-8")
    _log_mlflow(artifact_dir, summary, folds, model_dir)
    return {"model": MODEL_NAME, **summary}


def _log_mlflow(artifact_dir: Path, summary: dict[str, float], folds: list[FoldResult], model_dir: Path) -> None:
    """Registro de experimentos local (proporcionado: sin servidor de tracking)."""
    try:
        import mlflow
    except ImportError:
        return
    os.environ.setdefault("MLFLOW_ALLOW_FILE_STORE", "true")
    tracking_dir = Path(os.environ.get("AURALINK_MLRUNS", artifact_dir / "mlruns"))
    try:
        mlflow.set_tracking_uri(tracking_dir.resolve().as_uri())
        mlflow.set_experiment("auralink-demand")
        with mlflow.start_run(run_name=MODEL_NAME):
            mlflow.log_params({**LGB_PARAMS, "num_rounds": NUM_ROUNDS, "features": ",".join(FEATURES)})
            mlflow.log_metrics(summary)
            for i, f in enumerate(folds):
                mlflow.log_metric("fold_mae_model", f.mae_model, step=i)
                mlflow.log_metric("fold_coverage_conformal", f.coverage_80_conformal, step=i)
            mlflow.log_artifacts(str(model_dir), artifact_path="model")
    except Exception as exc:
        print(f"[mlflow] registro omitido: {exc.__class__.__name__}: {str(exc)[:120]}")
