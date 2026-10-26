from __future__ import annotations

import io
import zipfile
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from auralink_ml.alerts import Observations, evaluate
from auralink_ml.context.sources import parse_air, parse_traffic
from auralink_ml.forecasting import nowcast
from auralink_ml.forecasting.demand import calendar_features, conformal_quantile
from auralink_ml.monitoring import psi
from auralink_ml.network.compile import FeedSpec, compile_network
from auralink_ml.network.gtfs import parse_gtfs_time
from auralink_ml.settings import load_thresholds


def test_gtfs_time_supports_after_midnight() -> None:
    assert parse_gtfs_time(pd.Series(["7:05:00", "25:10:30"])).tolist() == [25500, 90630]


def test_psi_zero_for_same_distribution_and_high_for_shift() -> None:
    rng = np.random.default_rng(0)
    ref = rng.normal(0, 1, 2000)
    assert psi(ref, rng.normal(0, 1, 2000)) < 0.05
    assert psi(ref, rng.normal(2, 1, 2000)) > 0.2


def test_conformal_quantile_finite_sample_level() -> None:
    scores = np.arange(10, dtype=float)
    # ceil((n+1)*0.8)/n = 0.9 -> cuantil 0.9 de 0..9
    assert conformal_quantile(scores, 0.8) == pytest.approx(np.quantile(scores, 0.9))
    assert conformal_quantile(np.array([]), 0.8) == 0.0


def test_calendar_marks_madrid_holidays() -> None:
    feats = calendar_features(pd.Series(pd.to_datetime(["2025-05-02", "2025-05-15", "2025-05-06"])))
    assert feats["is_holiday"].tolist() == [1, 1, 0]  # Día de la Comunidad y San Isidro


def test_nowcast_probability_is_monotonic() -> None:
    dyn = nowcast.StationDynamics("1", mu=-0.1, sigma2=0.3, n=50)
    assert nowcast.prob_bike(10, dyn, 5) > nowcast.prob_bike(10, dyn, 60)
    assert nowcast.prob_bike(0, dyn, 30) < 0.3
    assert nowcast.prob_dock(10, dyn, 60) > nowcast.prob_bike(10, dyn, 60)


def test_estimate_dynamics_shrinks_towards_system_mean() -> None:
    ts = pd.date_range("2026-10-26 08:00", periods=4, freq="2min", tz="UTC")
    snaps = pd.DataFrame(
        {
            "ts": list(ts) * 2,
            "station_id": ["a"] * 4 + ["b"] * 4,
            "bikes": [10, 8, 6, 4, 5, 5, 5, 5],
            "docks": [0] * 8,
        }
    ).sort_values(["station_id", "ts"])
    dyn = nowcast.estimate_dynamics(snaps)
    assert dyn["a"].mu < 0 < dyn["a"].mu + 1  # drena bicis
    assert dyn["a"].mu > -1.0  # contraída hacia la media global (-0.5)


def test_alerts_only_fire_above_threshold() -> None:
    th = load_thresholds()
    quiet = evaluate(th, Observations(source_age_min={"gbfs": 1.0}))
    assert quiet == []
    noisy = evaluate(
        th,
        Observations(
            low_stations=[{"station_id": str(i), "p_bike_30": 0.01} for i in range(10)],
            no2_mean=250,
            drift_psi={"wind_max": 0.9},
            source_age_min={"gbfs": None},
        ),
    )
    keys = {a.key for a in noisy}
    assert {"station_empty_alert", "no2_alert", "drift_psi_alert", "data_staleness_alert"} <= keys
    assert all(a.suggested_action for a in noisy)


def test_parse_air_uses_last_validated_hour() -> None:
    header = "PROVINCIA;MUNICIPIO;ESTACION;MAGNITUD;PUNTO_MUESTREO;ANO;MES;DIA;" + ";".join(
        f"H{h:02d};V{h:02d}" for h in range(1, 25)
    )
    vals = ";".join(f"{h * 2};{'V' if h <= 3 else 'N'}" for h in range(1, 25))
    body = f"{header}\n28;079;4;8;x;2026;10;26;{vals}\n28;079;8;8;y;2026;10;26;{vals}\n".encode()
    reading = parse_air(body)
    assert reading.ok and reading.data["hour"] == 3 and reading.data["no2_mean"] == 6.0


def test_parse_traffic_ignores_points_with_error() -> None:
    xml = (
        b"<pms><fecha_hora>26/10/2026 23:00:02</fecha_hora>"
        b"<pm><carga>10</carga><error>N</error></pm><pm><carga>90</carga><error>S</error></pm>"
        b"<pm><carga>30</carga><error>N</error></pm></pms>"
    )
    reading = parse_traffic(xml)
    assert reading.data == {"congestion_index": 20.0, "points": 2}


def _zip(files: dict[str, str]) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for name, content in files.items():
            zf.writestr(name, content)
    return buf.getvalue()


def test_compile_network_expands_and_deduplicates_frequencies(tmp_path: Path) -> None:
    feed = _zip(
        {
            "stops.txt": "stop_id,stop_name,stop_lat,stop_lon\n1,A,40.42,-3.70\n2,B,40.421,-3.70\n3,C,40.43,-3.70\n",
            "routes.txt": "route_id,route_short_name,route_long_name,route_type,route_color\nR,1,Línea,3,0178BC\n",
            "trips.txt": "route_id,service_id,trip_id\nR,LA,t1\nR,LA,t2\nR,SA,t3\n",
            "stop_times.txt": "trip_id,arrival_time,departure_time,stop_id,stop_sequence\n"
            "t1,08:00:00,08:00:00,1,1\nt1,08:05:00,08:05:00,2,2\nt1,08:10:00,08:10:00,3,3\n"
            "t2,08:00:00,08:00:00,1,1\nt2,08:06:00,08:06:00,2,2\nt2,08:12:00,08:12:00,3,3\n"
            "t3,08:00:00,08:00:00,1,1\nt3,08:05:00,08:05:00,2,2\nt3,08:10:00,08:10:00,3,3\n",
            "frequencies.txt": "trip_id,start_time,end_time,headway_secs\nt1,08:00:00,08:59:59,600\nt2,08:00:00,08:59:59,600\n",
            "calendar.txt": "service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date\n"
            "LA,1,1,1,1,1,0,0,20260101,20261231\nSA,0,0,0,0,0,1,0,20260101,20261231\n",
        }
    )
    (tmp_path / "f.zip").write_bytes(feed)
    (tmp_path / "si.json").write_text(
        '{"data":{"stations":[{"station_id":"9","name":"S","lat":40.42,"lon":-3.7,"capacity":10}]}}'
    )
    summary = compile_network([FeedSpec("emt", tmp_path / "f.zip")], tmp_path / "si.json", tmp_path / "net.json")
    # 6 salidas (08:00..08:50) y no 12: las dos plantillas de bloque comparten frecuencia de línea
    assert summary["patterns"] == 1 and summary["trips"] == 6
    assert summary["bike_stations"] == 1
    assert summary["transfers"] == 2  # A<->B a ~111 m
