#import "template/corporativa.typ": *

#show: doc.with(
  title: "Aprendizaje automático y series temporales",
  subtitle: "CRISP-ML(Q), modelos, resultados y MLOps proporcionado",
  code: "AURA-DOC-03",
  version: "1.2",
)

#let card = json("../web/public/data/model_card.json")
#let m = card.metrics
#let fmtk(v) = str(calc.round(v / 1000, digits: 1)) + "k"

= Control de versiones
#version-table(
  ("0.1", "26/10/2026", "Equipo Aura Link", "Definición del problema y criterios de éxito (fase 1)."),
  ("1.0", "26/10/2026", "Equipo Aura Link", "Iteración 1: LightGBM cuantílico sin tendencia. Cobertura P10–P90 ≈ 44 %, fallo en septiembre 2025 (cambio de nivel)."),
  ("1.1", "26/10/2026", "Equipo Aura Link", "Iteración 2: modelo híbrido tendencia + LightGBM + calibración conforme (CQR). Nowcast por estación. Monitorización PSI."),
  ("1.2", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

#callout(kind: "info", title: "Datos de este documento")[
  Las cifras de resultados se leen directamente de `web/public/data/model_card.json`, generado por
  `auralink-ml train-demand`. Al reentrenar y recompilar el documento, las tablas se actualizan solas
  (documentación reproducible).
]

= Enfoque: CRISP-ML(Q)
Se sigue el modelo de proceso CRISP-ML(Q) de Studer et al. (2021), que añade a CRISP-DM
aseguramiento de calidad en cada fase y una fase explícita de monitorización y mantenimiento.

#fig(
  diagram(
    spacing: (9mm, 8mm),
    edge-stroke: 0.7pt + tf.grey6,
    n-sys((0, 0), wt[1. Negocio y\ datos], name: <a>),
    n-sys((1, 0), wt[2. Preparación\ de datos], name: <b>),
    n-sys((2, 0), wt[3. Modelado], name: <c>),
    n-sys((3, 0), wt[4. Evaluación], name: <d>),
    n-sys((4, 0), wt[5. Despliegue], name: <e>),
    n-sys((5, 0), wt[6. Monitorización\ y mantenimiento], name: <f>),
    edge(<a>, <b>, "-|>"), edge(<b>, <c>, "-|>"), edge(<c>, <d>, "-|>"), edge(<d>, <e>, "-|>"), edge(<e>, <f>, "-|>"),
    edge(<d>, <c>, "-|>", bend: 40deg, [iteración]),
    edge(<f>, <a>, "-|>", bend: 22deg, [deriva → reentreno (decisión humana)]),
  ),
  [Fases de CRISP-ML(Q) aplicadas en Aura Link, con los dos bucles de iteración usados.],
)

#brand-table(
  columns: (1.1fr, 2.4fr, 2fr),
  header: ("Fase", "Qué se hizo en Aura Link", "Aseguramiento de calidad"),
  [1. Business & Data Understanding], [Objetivo: fiabilidad de la bici en la ruta y presión de demanda. Fuentes abiertas identificadas (AURA-DOC-00).], [Criterio de éxito cuantitativo: MAE < climatología; cobertura P10–P90 ≈ 80 %.],
  [2. Data Preparation], [Serie diaria oficial, meteorología, calendario con festivos ES-MD y locales; instantáneas GBFS.], [Fechas sin solape; tests de parsers (aire, tráfico, GTFS).],
  [3. Modeling], [Modelo híbrido de demanda y nowcast de difusión por estación.], [Semillas fijas, configuración versionada.],
  [4. Evaluation], [Backtesting con origen móvil (6 folds mensuales) frente a dos líneas base.], [Comparación con baseline; cobertura del intervalo.],
  [5. Deployment], [Inferencia en GitHub Actions; artefactos JSON en Pages.], [Promoción manual por PR (CODEOWNERS).],
  [6. Monitoring & Maintenance], [PSI de entradas, frescura de fuentes, ratio MAE.], [Umbrales → alertas → decisión del técnico.],
)

= Problemas de ML abordados
== Demanda diaria del sistema BiciMAD (serie temporal)
*Para qué*: estimar la "presión" sobre las estaciones (más demanda prevista → más rotación e
incertidumbre en la disponibilidad), que la fusión usa para ajustar la fiabilidad de los tramos
en bici. *Datos*: #card.n_days días (#card.training_range.at(0) → #card.training_range.at(1)).

=== Observación clave de la fase 1
La demanda casi se duplica entre 2024 y 2025 (crecimiento estimado
#str(calc.round(card.trend_growth_per_year * 100)) % anual). Los árboles de decisión no extrapolan
fuera del rango de entrenamiento: en la iteración 1 el modelo erró por ~18 000 viajes/día en
septiembre de 2025 y su intervalo P10–P90 cubría solo un 44 % de los días.

=== Modelo (iteración 2)
+ *Nivel*: tendencia log-lineal por mínimos cuadrados.
+ *Patrón*: LightGBM con pérdida cuantílica (q = 0,1/0,5/0,9) sobre el residuo logarítmico, con
  calendario (día de la semana, estacionalidad anual seno/coseno, festivos, puentes) y meteorología
  (temperaturas, precipitación, viento).
+ *Calibración*: predicción conforme sobre cuantiles (CQR, Romano et al. 2019). La puntuación es la
  distancia del valor real al intervalo; el margen es el cuantil
  $ceil((n+1) dot 0.8) \/ n$ de las puntuaciones. En backtesting se aplica *en línea* (cada fold solo
  usa puntuaciones anteriores), por lo que la cobertura reportada es honesta.

#callout(kind: "warn", title: "Decisión de diseño: sin retardos de la serie")[
  El dato abierto de viajes diarios se publica mensualmente con retraso. Un modelo con retardos
  (lag-1, lag-7) sería mejor en backtesting pero *no podría servirse* en producción. Se reporta la
  línea base naïve estacional (lag-7) solo como cota optimista.
]

=== Resultados (backtesting con origen móvil, 6 meses)
#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 8pt,
  kpi(fmtk(m.mae_model), "MAE modelo (viajes/día)"),
  kpi(fmtk(m.mae_climatology), "MAE climatología", color: tf.grey6),
  kpi(str(calc.round(m.mae_ratio_vs_climatology, digits: 2)), "ratio MAE vs climatología", color: tf.green),
  kpi(str(calc.round(m.coverage_80_conformal * 100)) + " %", "cobertura P10–P90 (objetivo 80 %)", color: tf.blue70),
)
#v(6pt)
#fig(
  grouped-bars(
    card.folds.map(f => f.month),
    (
      ("Modelo", tf.blue, card.folds.map(f => f.mae_model)),
      ("Climatología", tf.grey3, card.folds.map(f => f.mae_climatology)),
      ("Naïve lag-7 (no servible)", tf.ambar, card.folds.map(f => f.mae_seasonal_naive)),
    ),
  ),
  [MAE por fold mensual. El modelo bate a la climatología en los 6 meses y al naïve lag-7 (que usa datos no disponibles en producción) en 3 de 6.],
)

#brand-table(
  columns: (1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
  header: ("Mes", "MAE modelo", "MAE climat.", "MAE naïve-7", "Cobertura bruta", "Cobertura CQR"),
  ..card.folds.map(f => (
    f.month, fmtk(f.mae_model), fmtk(f.mae_climatology), fmtk(f.mae_seasonal_naive),
    str(calc.round(f.coverage_80_raw * 100)) + " %", str(calc.round(f.coverage_80_conformal * 100)) + " %",
  )).flatten()
)

#callout(kind: "risk", title: "Limitación detectada (iteración 3 propuesta)")[
  En noviembre y diciembre de 2025 el error crece y la cobertura cae al 43–45 %: el crecimiento se
  frena y la tendencia lineal sobreestima. Propuesta para la siguiente iteración: tendencia
  amortiguada (damped trend) o ponderada hacia los últimos meses, y recalibración conforme
  adaptativa (ACI, Gibbs & Candès 2021). Se deja documentado como deuda técnica, no se oculta.
]

#fig(
  hbars(card.feature_importance_gain.pairs().sorted(key: p => -p.at(1)).slice(0, 8), fmt: v => str(calc.round(v))),
  [Importancia (ganancia) de variables en el cuantil 50: la meteorología y la estacionalidad dominan.],
)

== Disponibilidad por estación (nowcast de alta frecuencia)
Para cada estación se modela la variación de bicis como un proceso de difusión con deriva:
$ Delta B ~ cal(N)(mu Delta t, sigma^2 Delta t) $
con $mu$ y $sigma^2$ estimados de las instantáneas GBFS (cada 2–15 min) y *contraídos* hacia la
media del sistema según el número de observaciones $n$ (peso $n \/ (n + 10)$): bayes empírico que
resuelve el arranque en frío. La probabilidad de encontrar al menos una bici al llegar, a $h$
minutos, es
$ P(B_h >= 1) = 1 - Phi((0.5 - (B_0 + mu h)) / sqrt(sigma^2 h + 0.25)) $
y análogamente para anclajes con $-mu$. La misma fórmula se ejecuta en Python (alertas) y en el
navegador (por trayecto, con la hora real de llegada); un test cruzado verifica que coinciden.

= Aprendizaje profundo: ¿por qué no (todavía)?
#brand-table(
  columns: (1.2fr, 2fr, 2fr),
  header: ("Alternativa", "Ventaja", "Por qué no en el piloto"),
  [LSTM / GRU], [Capturan dinámicas no lineales], [700 días de serie diaria: alto riesgo de sobreajuste; no supera a GBDT en series cortas.],
  [Temporal Fusion Transformer], [Multihorizonte, interpretabilidad por atención], [Coste de entrenamiento y operación desproporcionado; requiere GPU para iterar.],
  [GNN espacio-temporales (ST-GCN)], [Aprovechan la red de estaciones], [Necesitan meses de histórico por estación a alta frecuencia; hoy hay horas (arranque en frío).],
)
#callout(kind: "idea", title: "Criterio cuantitativo para pasar a DL")[
  Se evaluará una GNN espacio-temporal cuando haya ≥ 90 días de instantáneas por estación y el
  nowcast actual muestre un Brier score > 0,15 a 30 min. El experimento se registrará en MLflow
  y su promoción seguirá el mismo proceso de PR con revisión humana.
]

= MLOps proporcionado al tamaño del proyecto
#brand-table(
  columns: (1fr, 2.2fr, 1.6fr),
  header: ("Práctica", "Implementación", "Por qué así"),
  [Versionado de código y config], [Git; `config/*.yaml` con CODEOWNERS], [Trazabilidad sin herramientas extra],
  [Versionado de modelos], [`data/artifacts/models/<nombre>/` + `model_card.json`], [Modelos de pocos cientos de KB],
  [Seguimiento de experimentos], [MLflow local (parámetros, métricas por fold, artefactos)], [Sin servidor de tracking],
  [Orquestación], [GitHub Actions: cron 15 min (inferencia), manual (reentreno)], [Coste ≈ 0; auditable],
  [Validación de datos], [Parsers tipados y testeados; descarte de puntos con error], [Fuentes oficiales estables],
  [Despliegue de modelos], [PR automática; promoción tras revisión], [Decisión humana obligatoria],
  [Monitorización], [PSI estacional, frescura de fuentes, ratio MAE → alertas], [Umbrales configurables],
)

== Monitorización en producción: un hallazgo real
En la primera ejecución del pipeline el PSI del viento máximo diario fue
2,94 (26/10/2026, umbral 0,2) y se generó una alerta. El análisis mostró un *training-serving skew*: el modelo se
entrenó con reanálisis ERA5 (archivo de Open-Meteo; viento medio en octubre ≈ 16 km/h) y en servicio
recibe la previsión operativa (≈ 10 km/h). La acción propuesta al técnico: reentrenar con la API
de previsiones históricas de Open-Meteo para que entrenamiento y servicio usen la misma fuente.

= Model card (resumen)
#brand-table(
  columns: (1fr, 3fr),
  header: ("Campo", "Valor"),
  [Nombre], card.name,
  [Tarea], card.task,
  [Método], card.method,
  [Datos personales], card.personal_data,
  [Validación], card.validation,
  [Promoción], card.promotion,
  [Limitaciones], card.limitations.map(l => [• #l]).join(linebreak()),
)
