"""Sincroniza ``alerts.json`` con Issues de GitHub (human-in-the-loop).

- Una Issue por alerta y día (huella en la etiqueta ``alert:<id>``): si existe, se comenta
  con la nueva evidencia en vez de duplicarla.
- El técnico decide con etiquetas ``decision:aprobar`` / ``decision:rechazar`` y valora la
  alerta con ``valoracion:util`` / ``valoracion:falso-positivo``. Las decisiones con efecto
  se aplican por Pull Request sobre ``config/``.

Se ejecuta en GitHub Actions con ``GITHUB_TOKEN`` (permiso ``issues: write``). Con ``--dry-run``
solo imprime lo que haría.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from auralink_ml.settings import PUBLIC_DATA_DIR

BASE_LABELS = ["auralink-alerta", "needs-triage"]
MIN_UPDATE_INTERVAL = timedelta(hours=1)  # evita ruido: como mucho un comentario por hora


def render_body(alert: dict[str, Any]) -> str:
    evidence = json.dumps(alert.get("evidence", {}), ensure_ascii=False, indent=2)
    return (
        f"**{alert['title']}** (severidad: {alert['severity']})\n\n"
        f"{alert['detail']}\n\n"
        f"| Indicador | Valor | Umbral |\n|---|---|---|\n| `{alert['key']}` | {alert['value']} | {alert['threshold']} |\n\n"
        f"**Acción sugerida (no aplicada):** {alert['suggested_action']}\n\n"
        "<details><summary>Evidencia</summary>\n\n```json\n" + evidence + "\n```\n</details>\n\n"
        "---\nDecida con las etiquetas `decision:aprobar` o `decision:rechazar` y valore la alerta con "
        "`valoracion:util` o `valoracion:falso-positivo`. Cualquier cambio de configuración se hace "
        "mediante Pull Request revisada (CODEOWNERS)."
    )


def _gh(*args: str) -> str:
    exe = shutil.which("gh")
    if exe is None:
        raise RuntimeError("gh CLI no disponible")
    return subprocess.run([exe, *args], check=True, capture_output=True, text=True).stdout  # noqa: S603


def sync(alerts_path: Path, dry_run: bool = False) -> list[str]:
    alerts = json.loads(alerts_path.read_text(encoding="utf-8"))["alerts"]
    actions: list[str] = []
    for alert in alerts:
        label = f"alert:{alert['id']}"
        body = render_body(alert)
        if dry_run:
            actions.append(f"crear/actualizar issue [{label}] {alert['title']}")
            continue
        existing = json.loads(
            _gh("issue", "list", "--label", label, "--state", "all", "--json", "number,updatedAt", "--limit", "1")
        )
        if existing:
            number = existing[0]["number"]
            updated = datetime.fromisoformat(existing[0]["updatedAt"].replace("Z", "+00:00"))
            if datetime.now(UTC) - updated < MIN_UPDATE_INTERVAL:
                actions.append(f"sin cambios #{number} (actualizada hace < 1 h)")
                continue
            _gh("issue", "comment", str(number), "--body", "Actualización automática:\n\n" + body)
            actions.append(f"comentada #{number}")
        else:
            _gh("label", "create", label, "--force", "--color", "D22A1E")
            labels = ",".join([*BASE_LABELS, label, f"umbral:{alert['key']}"])
            for name in labels.split(","):
                _gh("label", "create", name, "--force")
            url = _gh("issue", "create", "--title", f"[Aura Link] {alert['title']}", "--body", body, "--label", labels)
            actions.append(f"creada {url.strip()}")
    return actions


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alerts", type=Path, default=PUBLIC_DATA_DIR / "alerts.json")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    for line in sync(args.alerts, args.dry_run):
        print(line)


if __name__ == "__main__":
    main()
