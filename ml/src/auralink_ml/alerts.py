"""Evaluación de umbrales → alertas para el técnico (human-in-the-loop).

Principio: el sistema *propone*, el técnico *decide*. Ninguna alerta cambia la configuración;
las decisiones se aplican vía Pull Request sobre ``config/overrides.yaml`` o ``thresholds.yaml``.
"""

from __future__ import annotations

import hashlib
from dataclasses import asdict, dataclass, field
from typing import Any

from auralink_ml.settings import Threshold


@dataclass(frozen=True)
class Alert:
    key: str
    severity: str  # "alta" | "media" | "baja"
    title: str
    detail: str
    value: float
    threshold: float
    suggested_action: str
    evidence: dict[str, Any] = field(default_factory=dict)

    def fingerprint(self, day: str) -> str:
        """Una alerta por umbral y día: la Issue existente se actualiza en vez de duplicarse."""
        return hashlib.sha1(f"{self.key}:{day}".encode()).hexdigest()[:12]  # noqa: S324 - no criptográfico

    def to_dict(self, day: str) -> dict[str, Any]:
        return {**asdict(self), "id": self.fingerprint(day), "day": day}


@dataclass
class Observations:
    """Indicadores calculados en cada ejecución del pipeline."""

    low_stations: list[dict[str, Any]] = field(default_factory=list)
    empty_share: float = 0.0
    no2_mean: float | None = None
    demand_rel_width: float | None = None
    drift_psi: dict[str, float] = field(default_factory=dict)
    mae_ratio: float | None = None
    source_age_min: dict[str, float | None] = field(default_factory=dict)


def evaluate(th: dict[str, Threshold], obs: Observations) -> list[Alert]:
    alerts: list[Alert] = []

    t = th["station_empty_alert"]
    min_stations = int(t.extra.get("min_stations", 1))
    if len(obs.low_stations) >= min_stations:
        alerts.append(
            Alert(
                t.key,
                "media",
                f"{len(obs.low_stations)} estaciones con baja probabilidad de bici a 30 min",
                "El nowcast prevé que estas estaciones estarán vacías. Se propone excluirlas de las "
                "recomendaciones o solicitar reequilibrio.",
                float(len(obs.low_stations)),
                t.value,
                "Revisar la lista; si procede, añadir a `excluded_bike_stations` en config/overrides.yaml (PR).",
                {"stations": obs.low_stations[:25]},
            )
        )

    t = th["system_empty_share_alert"]
    if obs.empty_share > t.value:
        alerts.append(
            Alert(
                t.key,
                "alta",
                "Alta proporción de estaciones sin bicis",
                f"{obs.empty_share:.0%} de las estaciones operativas están vacías.",
                obs.empty_share,
                t.value,
                "Valorar aviso general de baja disponibilidad de BiciMAD.",
            )
        )

    t = th["no2_alert"]
    if obs.no2_mean is not None and obs.no2_mean > t.value:
        alerts.append(
            Alert(
                t.key,
                "alta",
                "NO₂ elevado en la ciudad",
                f"Media urbana {obs.no2_mean:.0f} µg/m³.",
                obs.no2_mean,
                t.value,
                "Si procede, activar `exposure_notice_active: true` en config/overrides.yaml (PR).",
            )
        )

    t = th["demand_forecast_uncertainty_alert"]
    if obs.demand_rel_width is not None and obs.demand_rel_width > t.value:
        alerts.append(
            Alert(
                t.key,
                "baja",
                "Previsión de demanda con alta incertidumbre",
                f"Anchura relativa P10–P90 = {obs.demand_rel_width:.2f}.",
                obs.demand_rel_width,
                t.value,
                "Tratar la presión de demanda como poco fiable; revisar datos de entrada.",
            )
        )

    t = th["drift_psi_alert"]
    drifted = {f: v for f, v in obs.drift_psi.items() if v > t.value}
    if drifted:
        worst = max(drifted.values())
        alerts.append(
            Alert(
                t.key,
                "media",
                "Deriva en variables de entrada del modelo de demanda",
                "PSI por encima del umbral en: " + ", ".join(f"{k}={v:.2f}" for k, v in drifted.items()),
                worst,
                t.value,
                "Valorar reentrenamiento (workflow manual `retrain`) y revisar model card.",
                {"psi": obs.drift_psi},
            )
        )

    t = th["model_degradation_alert"]
    if obs.mae_ratio is not None and obs.mae_ratio > t.value:
        alerts.append(
            Alert(
                t.key,
                "alta",
                "El modelo no mejora a la línea base",
                f"MAE modelo / MAE climatología = {obs.mae_ratio:.2f}.",
                obs.mae_ratio,
                t.value,
                "No promocionar el modelo; mantener la versión anterior.",
            )
        )

    t = th["data_staleness_alert"]
    limits: dict[str, float] = t.extra.get("per_source", {})
    stale = {k: v for k, v in obs.source_age_min.items() if v is None or v > limits.get(k, t.value)}
    if stale:
        alerts.append(
            Alert(
                t.key,
                "media",
                "Fuentes de datos desactualizadas o caídas",
                ", ".join(f"{k}: {'sin datos' if v is None else f'{v:.0f} min'}" for k, v in stale.items()),
                float(len(stale)),
                t.value,
                "Comprobar disponibilidad de la fuente; la fusión reduce su peso automáticamente.",
                {"sources": stale},
            )
        )
    return alerts
