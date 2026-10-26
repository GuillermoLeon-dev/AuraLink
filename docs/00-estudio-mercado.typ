#import "template/corporativa.typ": *

#show: doc.with(
  title: "Estudio de mercado y estado del arte",
  subtitle: "Planificación multimodal sostenible: competidores, algoritmos y oportunidad",
  code: "AURA-DOC-00",
  version: "1.1",
)

= Control de versiones
#version-table(
  ("0.1", "26/10/2026", "Equipo Aura Link", "Esqueleto, fuentes de datos de Madrid identificadas."),
  ("1.0", "26/10/2026", "Equipo Aura Link", "Matriz competitiva, estado del arte algorítmico y de ML, hueco de mercado."),
  ("1.1", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

#callout(kind: "info", title: "Cómo leer este documento")[
  Es la fase *Business & Data Understanding* de CRISP-ML(Q) @studer2021: se fija el problema, se
  revisa qué existe y se justifica dónde aporta valor Aura Link *antes* de diseñar o programar.
  Las afirmaciones sobre producto de terceros reflejan funcionalidad pública observada en la
  investigación; las marcadas como _a validar_ deben contrastarse antes de usarse comercialmente.
]

= Problema y contexto

Un desplazamiento urbano típico en Madrid admite varias combinaciones razonables: metro directo,
bus + a pie, bici pública + metro… Los planificadores generalistas optimizan casi siempre *un*
criterio (tiempo) y añaden el resto como información secundaria. Sin embargo, para el usuario y
para la administración importan simultáneamente:

- *Tiempo* de puerta a puerta y su *fiabilidad* (¿habrá bici en la estación?).
- *Coste* real según la tarifa aplicable (sencillo, abono, BiciMAD).
- *Emisiones* de gases de efecto invernadero (gCO₂e) de cada alternativa.

Además, las condiciones cambian: lluvia, episodios de contaminación o estaciones vacías alteran
qué opción es mejor. Esto exige *combinar varias fuentes* (data fusion) y *predecir* (series
temporales), sin delegar en la máquina decisiones operativas de impacto: un técnico debe
validarlas a partir de umbrales.

== Mercado
Las estimaciones de tamaño de mercado divergen mucho según el perímetro: un informe sitúa el
mercado MaaS en 5,7 mil M\$ (2023) con previsión de 40,1 mil M\$ en 2030 @globenewswire2024,
mientras otro valora la planificación multimodal en 7,2 mil M\$ en 2025 @marketintelo. Ambas
cifras proceden de informes comerciales y se usan solo como orden de magnitud. Lo relevante para
Aura Link es la tendencia: operadores públicos y ayuntamientos buscan herramientas que *empujen el
cambio modal* y que se puedan *auditar*, algo que las apps de consumo no ofrecen.

== Activos de datos abiertos en Madrid (piloto)
#brand-table(
  columns: (1.3fr, 2fr, 1fr),
  header: ("Fuente", "Contenido", "Licencia / acceso"),
  [GTFS Metro de Madrid (CRTM)], [13 líneas, horarios por frecuencias], [Abierta CRTM, atribución "Powered by CRTM" @crtmlic],
  [GTFS Metro Ligero (CRTM)], [4 líneas], [Abierta CRTM @mdb2802],
  [GTFS EMT Madrid], [≈236 líneas de bus urbano, actualización diaria], [Abierta EMT @mdb793],
  [GBFS BiciMAD], [Estaciones, capacidad, bicis y anclajes en tiempo real], [Ayto. Madrid / EMT @bicimadgbfs],
  [BiciMAD viajes diarios], [Serie diaria desde 02/2024], [datos.madrid.es @bicimadviajes],
  [Calidad del aire (tiempo real)], [NO₂, PM, O₃ por estación], [CC BY 4.0, datos.madrid.es],
  [Tráfico / aforos], [Intensidades por punto de medida], [CC BY 4.0, datos.madrid.es],
  [Open-Meteo], [Meteorología histórica y predicción], [CC BY 4.0, sin clave @openmeteo],
)
EMT MobilityLabs (tiempos de llegada en tiempo real) exige registro de credenciales y queda fuera
del MVP; se contempla como mejora (ver AURA-DOC-07).

= Análisis competitivo

#let y = text(fill: tf.green, weight: 700)[●]
#let p = text(fill: rgb("#A7863E"), weight: 700)[◐]
#let no = text(fill: tf.coral60, weight: 700)[○]

#brand-table(
  columns: (1.4fr, 0.8fr, 0.8fr, 0.8fr, 0.8fr, 0.8fr, 0.8fr, 0.8fr),
  header: ("Solución", "Bici + TP en un viaje", "Coste", "CO₂", "Pareto explícito", "Predicción disponibilidad", "Privacidad O/D", "Auditable / HITL"),
  [Google Maps], p, p, p, no, no, no, no,
  [Citymapper (Via)], y, y, p, no, no, no, no,
  [Moovit (Mobileye)], p, p, no, no, no, no, no,
  [Transit], y, p, no, no, p, no, no,
  [Madrid Mobility 360 / EMT], p, y, no, no, no, p, no,
  [OpenTripPlanner 2], y, p, no, p, no, y, p,
  [Navitia (Hove)], y, p, p, no, no, p, no,
  [*Aura Link (propuesta)*], y, y, y, y, y, y, y,
)
#text(size: 8pt, fill: tf.grey6)[● sí · ◐ parcial · ○ no / no observado. Valoración cualitativa
del equipo sobre funcionalidad pública (_a validar_); OpenTripPlanner y Navitia son motores, no
apps finales. Citymapper fue adquirida por Via en 2023 @cbinsights.]

== Lectura de la matriz
- *Las apps de consumo* (Google, Citymapper, Moovit) son excelentes en cobertura y tiempo real,
  pero su modelo de negocio descansa en datos de uso y ubicación; no exponen el compromiso
  tiempo–coste–emisiones ni permiten a un operador auditar por qué se recomienda algo.
- *Los motores abiertos* (OpenTripPlanner, Navitia, r5) resuelven el enrutamiento, pero requieren
  un servidor JVM dimensionado y no incorporan predicción ni fusión de contexto.
- *Las apps institucionales* integran pago y servicios municipales, pero recomiendan sin
  criterio ambiental explícito.

#callout(kind: "ok", title: "Hueco de mercado")[
  No se ha identificado una solución que combine (1) frente de Pareto explícito
  tiempo/coste/CO₂, (2) predicción de disponibilidad de bici con incertidumbre fusionada con
  clima y calidad del aire, (3) cálculo de rutas *en el dispositivo* sin que el origen/destino
  salga del navegador y (4) una consola de operación con umbrales y decisión humana. Este es el
  posicionamiento de Aura Link, orientado a B2G (consorcios, ayuntamientos) y B2B (white-label).
]

= Estado del arte

== Algoritmos de planificación en transporte público
#brand-table(
  columns: (1fr, 2.4fr, 1.2fr),
  header: ("Familia", "Idea", "Uso en Aura Link"),
  [Dijkstra / A\* sobre grafo tiempo-expandido], [Clásico; grafos enormes, lento para multicriterio.], [Descartado],
  [CSA (Connection Scan)], [Recorre conexiones ordenadas por hora; muy rápido para un criterio.], [Referencia],
  [RAPTOR @delling2015], [Basado en rondas (una por transbordo), sin cola de prioridad, cache-friendly.], [Base],
  [McRAPTOR @delling2015], [Mantiene *bolsas de Pareto* por parada para varios criterios.], [*Elegido*],
  [ULTRA @baum2023], [Precalcula atajos de transbordo para permitir transbordos ilimitados a pie/bici.], [Evolución],
  [McTB / HydRA @potthoff2022], [Tres criterios en tiempos interactivos; bici compartida y patinete.], [Evolución],
)

McRAPTOR es la elección del MVP: es exacto, sencillo de implementar y testear, y añadir criterios
(coste, CO₂) no cambia su estructura. La literatura señala que las bolsas de Pareto dinámicas lo
hacen lento a gran escala @potthoff2022; Aura Link lo mitiga acotando rondas (≤ 4 transbordos),
ventana horaria y discretizando el coste. ULTRA queda como evolución para la red completa.

== Bicicleta compartida en el enrutamiento
Tratar la bici pública como un modo más exige modelar recogida y devolución en estación. La
práctica habitual (OpenTripPlanner, ULTRA multimodal @potthoff2022) modela el tramo
_a pie → estación → bici → estación → a pie_ como transferencia. Aura Link añade la
*probabilidad de encontrar bici y anclaje* como atributo del tramo, procedente del modelo de ML.

== Predicción de disponibilidad y demanda
- *Modelos clásicos de series temporales* (ARIMA/SARIMA, Prophet): buenos en series agregadas,
  débiles con exógenas no lineales.
- *Gradient boosting con variables de calendario y retardos* (LightGBM, XGBoost): estado del arte
  práctico en competiciones de previsión (M5) y fácil de operar.
- *Deep learning espacio-temporal* (ST-GCN, GNN, Temporal Fusion Transformer): mejores
  resultados cuando hay muchas estaciones y meses de histórico a alta frecuencia @stgcn2021
  @graphreview2023, a cambio de coste de entrenamiento y menor explicabilidad.

#callout(kind: "idea", title: "Decisión proporcionada")[
  Para el piloto se usa LightGBM con regresión cuantílica (incertidumbre) frente a una línea base
  estacional, y para la disponibilidad por estación un *nowcast* bayesiano (Beta-Binomial) que
  arranca en frío con los datos GBFS recolectados. Las redes espacio-temporales se planifican
  cuando el histórico acumulado lo justifique (criterio cuantitativo en AURA-DOC-03).
]

== Factores de emisión
No se ha localizado una tabla oficial española de gCO₂e por pasajero-km por modo urbano; se
adoptan factores de referencia DESNZ 2025 (Reino Unido) @desnz2025 —bus local 103,9; metro 27,8;
tren 35,5 gCO₂e/pkm— como valores configurables, marcados _a validar por el técnico_ y
sustituibles por datos de memoria ambiental de EMT/Metro/CRTM. Bici y a pie: 0 en uso directo.

== Metodología y operación de ML
CRISP-ML(Q) @studer2021 extiende CRISP-DM con aseguramiento de calidad por fase y una fase
explícita de *monitorización y mantenimiento*, adecuada para modelos que se degradan con el
tiempo. Las prácticas MLOps se dimensionan al tamaño del piloto: versionado de datos y modelos en
el repositorio, ejecución programada en GitHub Actions y promoción manual por Pull Request.

= Conclusiones para el diseño
+ Arquitectura *static-first*: enrutamiento en el navegador (privacidad y coste casi nulo).
+ Motor McRAPTOR multicriterio (tiempo, coste, CO₂) con ranking configurable por el usuario.
+ ML proporcionado: LightGBM cuantílico + nowcast bayesiano; DL como evolución medible.
+ Data fusion de disponibilidad, meteorología, calidad del aire y calendario en una puntuación
  de fiabilidad/confort con incertidumbre.
+ Umbrales configurables y decisión humana del técnico, auditada en Git.

#bibliography("refs.yml", title: "Fuentes consultadas", style: "ieee")
