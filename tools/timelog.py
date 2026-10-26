"""Cronómetro de etapas del experimento.

Uso:
    python tools/timelog.py start "<etapa>"   # cierra la etapa abierta (si la hay) y abre otra
    python tools/timelog.py stop              # cierra la etapa abierta
    python tools/timelog.py report            # imprime el resumen

Registro en ``timelog.csv`` (raíz del repo): etapa, inicio, fin, duracion_min.
"""

from __future__ import annotations

import csv
import sys
from datetime import datetime
from pathlib import Path

LOG_PATH = Path(__file__).resolve().parent.parent / "timelog.csv"
HEADER = ["etapa", "inicio", "fin", "duracion_min"]


def _now() -> datetime:
    return datetime.now().astimezone().replace(microsecond=0)


def _read() -> list[dict[str, str]]:
    if not LOG_PATH.exists():
        return []
    with LOG_PATH.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def _write(rows: list[dict[str, str]]) -> None:
    with LOG_PATH.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=HEADER)
        writer.writeheader()
        writer.writerows(rows)


def _close_open(rows: list[dict[str, str]], at: datetime) -> None:
    for row in rows:
        if not row["fin"]:
            start = datetime.fromisoformat(row["inicio"])
            row["fin"] = at.isoformat()
            row["duracion_min"] = f"{(at - start).total_seconds() / 60:.1f}"


def start(stage: str) -> None:
    rows = _read()
    at = _now()
    _close_open(rows, at)
    rows.append({"etapa": stage, "inicio": at.isoformat(), "fin": "", "duracion_min": ""})
    _write(rows)
    print(f"[timelog] start '{stage}' @ {at.isoformat()}")


def stop() -> None:
    rows = _read()
    _close_open(rows, _now())
    _write(rows)
    print("[timelog] stop")


def report() -> None:
    total = 0.0
    for row in _read():
        minutes = float(row["duracion_min"] or 0)
        total += minutes
        print(f"{row['etapa']:<45} {minutes:>7.1f} min")
    print(f"{'TOTAL':<45} {total:>7.1f} min")


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "start":
        start(" ".join(argv[1:]))
    elif argv[:1] == ["stop"]:
        stop()
    elif argv[:1] == ["report"]:
        report()
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
