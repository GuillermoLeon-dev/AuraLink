"""CLI de pipelines: ``auralink-ml <comando>``. Cada comando es un paso de CRISP-ML(Q)."""

from __future__ import annotations

import argparse
import json
from collections.abc import Callable

from auralink_ml import settings


def cmd_compile_network(args: argparse.Namespace) -> None:
    from auralink_ml.network.compile import FeedSpec, compile_network

    feeds = [
        FeedSpec("metro", settings.RAW_DIR / "metro_gtfs.zip"),
        FeedSpec("ml", settings.RAW_DIR / "ml_gtfs.zip"),
        FeedSpec("emt", settings.RAW_DIR / "emt_gtfs.zip"),
    ]
    summary = compile_network(
        feeds,
        settings.RAW_DIR / "bicimad_station_information.json",
        settings.PUBLIC_DATA_DIR / "network.json",
        weekday=args.weekday,
    )
    print(json.dumps(summary, indent=2))


def cmd_train_demand(args: argparse.Namespace) -> None:
    from auralink_ml.forecasting.demand import run_training

    print(json.dumps(run_training(), indent=2, ensure_ascii=False))


def cmd_refresh_context(args: argparse.Namespace) -> None:
    from auralink_ml.pipeline import refresh_context

    print(json.dumps(refresh_context(offline=args.offline), indent=2, ensure_ascii=False))


def cmd_fetch_data(args: argparse.Namespace) -> None:
    from auralink_ml.fetch import fetch_all

    print(json.dumps(fetch_all(include_training=not args.no_training), indent=2))


COMMANDS: dict[str, Callable[[argparse.Namespace], None]] = {
    "fetch-data": cmd_fetch_data,
    "compile-network": cmd_compile_network,
    "train-demand": cmd_train_demand,
    "refresh-context": cmd_refresh_context,
}


def main() -> None:
    parser = argparse.ArgumentParser(prog="auralink-ml", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("fetch-data", help="Descarga GTFS, GBFS, serie BiciMAD y meteorología histórica")
    p.add_argument("--no-training", action="store_true", help="omitir datos solo necesarios para entrenar")
    p = sub.add_parser("compile-network", help="GTFS + GBFS -> web/public/data/network.json")
    p.add_argument("--weekday", default="tuesday")
    sub.add_parser("train-demand", help="Entrena y evalúa el modelo de demanda diaria BiciMAD")
    p = sub.add_parser("refresh-context", help="Ingesta, nowcast, fusión y alertas -> context.json")
    p.add_argument("--offline", action="store_true", help="usar solo datos locales (tests/CI)")
    args = parser.parse_args()
    COMMANDS[args.command](args)


if __name__ == "__main__":
    main()
