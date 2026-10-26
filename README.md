# Aura Link — rutas multimodales sostenibles (piloto Madrid)

Aplicación web que recomienda la mejor combinación de **transporte público + BiciMAD + a pie**
según **tiempo, coste y emisiones**, fusionando disponibilidad prevista de bicis, meteorología,
calidad del aire, tráfico y demanda. El cálculo se hace **en el navegador**: el origen y el destino
no salen del dispositivo. Las situaciones anómalas generan **alertas por umbral** que decide un técnico.

| Pieza | Dónde | Tecnología |
|---|---|---|
| Web + motor McRAPTOR (Web Worker) | `web/` | React 18, TypeScript, Vite, MapLibre |
| Datos, ML, fusión, alertas | `ml/` | Python 3.12, uv, LightGBM, MLflow |
| Configuración decidida por técnicos | `config/` | YAML versionado + CODEOWNERS |
| CI/CD, refresco de datos, Pages | `.github/workflows/` | GitHub Actions + Pages |
| Documentación (Typst, plantilla corporativa) | `docs/` | Typst + fletcher |
| Cronómetro del experimento | `tools/timelog.py`, `timelog.csv` | — |

## Arranque rápido (local)

```bash
cd ml && uv sync && uv run auralink-ml fetch-data && uv run auralink-ml compile-network && uv run auralink-ml train-demand && uv run auralink-ml refresh-context
```

```bash
cd web && npm ci && npm run dev
```

Abra http://localhost:5173, pulse en el mapa el origen y el destino y busque.

## Calidad

```bash
cd ml && uv run ruff check src tests && uv run mypy src && uv run pytest -q
```

```bash
cd web && npm run lint && npm run typecheck && npm test
```

## Documentación

```bash
for f in docs/[0-9]*.typ; do typst compile --root . --font-path docs/template/fonts "$f" "docs/pdf/$(basename "${f%.typ}").pdf"; done
```

| Código | Documento |
|---|---|
| AURA-DOC-00 | Estudio de mercado y estado del arte |
| AURA-DOC-01 | Propuesta de valor y producto |
| AURA-DOC-02 | Arquitectura, tecnologías y despliegue |
| AURA-DOC-03 | ML/series temporales con CRISP-ML(Q) y MLOps |
| AURA-DOC-04 | Innovación, data fusion y umbrales |
| AURA-DOC-05 | Seguridad |
| AURA-DOC-06 | Protección de datos (RGPD, LOPDGDD, AEPD, EDPB), RAT, riesgos y EIPD |
| AURA-DOC-07 | Viabilidad económica |
| AURA-DOC-08 | Informe de tiempos del experimento |

## Despliegue en GitHub Pages

1. Settings → Pages → *Source: GitHub Actions*.
2. El workflow `pages.yml` construye y publica en cada push a `main` y cada 15 minutos refresca
   el contexto (y abre/actualiza Issues de alerta).
3. Ajuste los equipos de `.github/CODEOWNERS` y proteja `main` (revisión obligatoria).

Atribución de datos: *Powered by CRTM* · EMT Madrid · BiciMAD (Ayuntamiento de Madrid, CC BY 4.0) ·
Open-Meteo (CC BY 4.0) · © OpenStreetMap / OpenFreeMap.
