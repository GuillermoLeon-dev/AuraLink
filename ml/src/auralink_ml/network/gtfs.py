"""Lectura de feeds GTFS (zip) y selección del servicio de un día tipo."""

from __future__ import annotations

import io
import zipfile
from dataclasses import dataclass
from pathlib import Path

import pandas as pd

WEEKDAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")

# route_type GTFS -> modo de Aura Link
MODE_BY_ROUTE_TYPE = {0: "light_rail", 1: "metro", 2: "rail", 3: "bus"}


def parse_gtfs_time(values: pd.Series) -> pd.Series:
    """'7:05:00' o '25:10:00' -> segundos desde medianoche del día de servicio."""
    parts = values.astype(str).str.strip().str.split(":", expand=True).astype(int)
    return parts[0] * 3600 + parts[1] * 60 + parts[2]


@dataclass(frozen=True)
class GtfsFeed:
    name: str
    stops: pd.DataFrame
    routes: pd.DataFrame
    trips: pd.DataFrame
    stop_times: pd.DataFrame
    frequencies: pd.DataFrame
    calendar: pd.DataFrame

    @classmethod
    def from_zip(cls, path: Path, name: str) -> GtfsFeed:
        with zipfile.ZipFile(path) as zf:

            def read(member: str, usecols: list[str] | None = None) -> pd.DataFrame:
                if member not in zf.namelist():
                    return pd.DataFrame(columns=usecols or [])
                raw = zf.read(member).decode("utf-8-sig")
                return pd.read_csv(io.StringIO(raw), dtype=str, usecols=usecols, keep_default_na=False)

            return cls(
                name=name,
                stops=read("stops.txt"),
                routes=read("routes.txt", ["route_id", "route_short_name", "route_long_name", "route_type", "route_color"]),
                trips=read("trips.txt", ["route_id", "service_id", "trip_id"]),
                stop_times=read("stop_times.txt", ["trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence"]),
                frequencies=read("frequencies.txt", ["trip_id", "start_time", "end_time", "headway_secs"]),
                calendar=read("calendar.txt"),
            )

    def services_for_weekday(self, weekday: str = "tuesday") -> set[str]:
        """Servicios del día tipo. Se ignora el rango de fechas a propósito: algunos feeds
        publicados (p. ej. Metro) tienen ``end_date`` vencido pero horarios aún representativos."""
        if weekday not in WEEKDAYS:
            raise ValueError(weekday)
        cal = self.calendar
        return set(cal.loc[cal[weekday] == "1", "service_id"])
