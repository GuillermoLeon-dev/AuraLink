"""Recolector de instantáneas GBFS de BiciMAD (fase *Data Understanding* de CRISP-ML).

Guarda, por estación, bicis y anclajes disponibles en ``data/gbfs_snapshots/AAAAMMDD.csv``.
No contiene datos personales: el feed GBFS solo publica estado agregado de estaciones.
En producción lo ejecuta un workflow programado de GitHub Actions.
"""

from __future__ import annotations

import argparse
import csv
import json
import time
import urllib.request
from datetime import UTC, datetime
from pathlib import Path

STATION_STATUS_URL = "https://madrid.publicbikesystem.net/customer/gbfs/v2/en/station_status"
FIELDS = ["ts", "station_id", "bikes", "docks", "is_renting", "is_returning"]


def fetch_status(url: str = STATION_STATUS_URL, timeout: float = 20.0) -> dict:
    with urllib.request.urlopen(url, timeout=timeout) as response:  # noqa: S310 - URL fija
        payload: dict = json.load(response)
    return payload


def to_rows(payload: dict) -> list[dict[str, object]]:
    ts = datetime.fromtimestamp(payload["last_updated"], tz=UTC).isoformat()
    return [
        {
            "ts": ts,
            "station_id": s["station_id"],
            "bikes": s.get("num_bikes_available", 0),
            "docks": s.get("num_docks_available", 0),
            "is_renting": int(bool(s.get("is_renting", False))),
            "is_returning": int(bool(s.get("is_returning", False))),
        }
        for s in payload["data"]["stations"]
    ]


def append_snapshot(out_dir: Path) -> int:
    rows = to_rows(fetch_status())
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / f"{datetime.now(UTC):%Y%m%d}.csv"
    is_new = not path.exists()
    with path.open("a", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        if is_new:
            writer.writeheader()
        writer.writerows(rows)
    return len(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path("data/gbfs_snapshots"))
    parser.add_argument("--every", type=int, default=0, help="segundos entre capturas (0 = una vez)")
    parser.add_argument("--count", type=int, default=1)
    args = parser.parse_args()
    for i in range(args.count):
        try:
            n = append_snapshot(args.out)
            print(f"[gbfs] snapshot {i + 1}/{args.count}: {n} estaciones")
        except OSError as exc:  # red caída: se registra y se sigue
            print(f"[gbfs] error: {exc}")
        if args.every and i + 1 < args.count:
            time.sleep(args.every)


if __name__ == "__main__":
    main()
