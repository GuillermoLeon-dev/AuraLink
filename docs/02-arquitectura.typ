#import "template/corporativa.typ": *

#show: doc.with(
  title: "Arquitectura, tecnologías y despliegue",
  subtitle: "Diseño static-first sobre GitHub Pages con MLOps en GitHub Actions",
  code: "AURA-DOC-02",
  version: "1.2",
)

= Control de versiones
#version-table(
  ("0.1", "26/10/2026", "Equipo Aura Link", "Arquitectura cliente-servidor inicial (FastAPI + PostGIS)."),
  ("1.0", "26/10/2026", "Equipo Aura Link", "Rediseño static-first por despliegue en GitHub Pages; FastAPI pasa a evolución."),
  ("1.1", "26/10/2026", "Equipo Aura Link", "Diagramas de componentes, flujo de datos y despliegue tras implementación."),
  ("1.2", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

= Decisiones de arquitectura (ADR)

#decision("AD-01", "Static-first: el cálculo ocurre en el navegador",
  [La web se sirve como ficheros estáticos; el motor de rutas se ejecuta en un Web Worker sobre
  una red precompilada. No existe backend que reciba consultas de usuario.],
  basis: [restricción de despliegue en GitHub Pages; minimización y protección de datos desde el
  diseño (arts. 5.1.c y 25 RGPD); coste marginal ≈ 0 y escalado por CDN.],
  source: [docs.github.com/pages; AURA-DOC-06; AURA-DOC-07.])

#decision("AD-02", "Arquitectura limpia / hexagonal en el cliente",
  [`domain/` (TypeScript puro: McRAPTOR, tarifas, emisiones, Pareto, ranking, fusión) no depende
  de React, del mapa ni de la red. `infrastructure/` adapta ficheros JSON y el Worker; `ui/`
  solo presenta. Así el dominio se prueba con tests unitarios deterministas.],
  basis: [Clean Architecture (R. C. Martin): regla de dependencias hacia dentro; SOLID.],
  source: [Martin, R. C. _Clean Architecture_, 2017.])

#decision("AD-03", "MLOps sobre GitHub Actions, proporcionado al piloto",
  [Ingesta, predicción, fusión y evaluación de umbrales son *jobs* programados que publican
  artefactos JSON versionados. Reentrenar es un `workflow_dispatch` manual y promocionar un
  modelo exige Pull Request revisada.],
  basis: [CRISP-ML(Q) fases de despliegue y monitorización; "MLOps nivel 1" sin infraestructura
  dedicada; trazabilidad completa en Git.],
  source: [Studer et al. 2021; Google Cloud, _MLOps: Continuous delivery and automation pipelines in ML_.])

#decision("AD-04", "Human-in-the-loop mediante Issues y Pull Requests",
  [Cuando un indicador supera un umbral se abre (o actualiza) una *Issue* etiquetada. El técnico
  decide con etiquetas (`decision:aprobar`, `decision:rechazar`) y aplica cambios en
  `config/*.yaml` vía PR con revisión obligatoria (CODEOWNERS).],
  basis: [requisito de no automatizar decisiones operativas; art. 22 RGPD por analogía; registro
  de auditoría sin construir un backend.],
  source: [GitHub Docs: protected branches, CODEOWNERS.])

#decision("AD-05", "Sin geocodificador externo",
  [El origen/destino se fija pulsando en el mapa, con la geolocalización del navegador o eligiendo
  una parada/estación del índice local. No se envía texto de búsqueda a terceros.],
  basis: [minimización (art. 5.1.c RGPD); evitar transferencias a terceros (arts. 28 y 44 RGPD).],
  source: [AEPD, _Guía de Privacidad desde el Diseño_, 2019.])

= Vista de contexto (C4 nivel 1)
#fig(
  diagram(
    spacing: (18mm, 12mm),
    edge-stroke: 0.7pt + tf.grey6,
    n-person((0, 0), wt[Ciudadano], name: <user>),
    n-person((0, 2), wt[Técnico de operación], name: <tech>),
    n-sys((2, 1), wt[*Aura Link*\ Web estática + Worker], name: <app>),
    n-ext((4, 0), [Open data Madrid\ GTFS · GBFS · aire · tráfico], name: <od>),
    n-ext((4, 1), [Open-Meteo], name: <om>),
    n-ext((4, 2), [GitHub\ Actions · Issues · PR · Pages], name: <gh>),
    n-ext((2, 2.6), [Teselas de mapa\ (OpenFreeMap)], name: <tiles>),
    edge(<user>, <app>, "-|>", [planifica viaje], label-side: left),
    edge(<tech>, <app>, "-|>", [consulta alertas]),
    edge(<tech>, <gh>, "-|>", [decide (Issue/PR)], bend: -30deg, label-side: right),
    edge(<od>, <gh>, "-|>", [ingesta programada], bend: 40deg),
    edge(<om>, <gh>, "-|>"),
    edge(<gh>, <app>, "-|>", [publica datos y web]),
    edge(<app>, <tiles>, "-|>", [teselas (sin O/D)]),
  ),
  [Contexto del sistema. Las líneas indican dependencias; ningún flujo transporta el origen o destino del usuario.],
)

= Vista de contenedores (C4 nivel 2)
#fig(
  diagram(
    spacing: (14mm, 10mm),
    edge-stroke: 0.7pt + tf.grey6,
    node((0, 0), [*Navegador del usuario*], stroke: none),
    n-box((0, 1), [SPA React + MapLibre\ `web/src/ui`], name: <spa>),
    n-box((0, 2), [Router Worker\ McRAPTOR · `domain/`], name: <worker>),
    n-store((0, 3), [Caché HTTP\ red + contexto], name: <cache>),
    node((2, 0), [*GitHub Pages (CDN)*], stroke: none),
    n-store((2, 1), [`data/network.json`\ paradas · patrones · transbordos], name: <net>),
    n-store((2, 2), [`data/context.json`\ estaciones · clima · aire · tráfico · demanda], name: <ctx>),
    n-store((2, 3), [`data/alerts.json`\ `model_card.json`], name: <al>),
    node((4, 0), [*GitHub Actions*], stroke: none),
    n-box((4, 1), [compile-network\ (semanal)], name: <cn>, fill: tf.turquoise10, stroke: 0.6pt + tf.turquoise70),
    n-box((4, 2), [refresh-context\ (cada 15 min)], name: <rc>, fill: tf.turquoise10, stroke: 0.6pt + tf.turquoise70),
    n-box((4, 3), [train-demand\ (manual)], name: <tr>, fill: tf.turquoise10, stroke: 0.6pt + tf.turquoise70),
    n-alert((4, 4), [Issues de alerta], name: <iss>),
    edge(<spa>, <worker>, "<|-|>", [postMessage]),
    edge(<worker>, <cache>, "-|>"),
    edge(<spa>, <ctx>, "-|>", [GET], label-side: left),
    edge(<worker>, <net>, "-|>", [GET], label-side: right),
    edge(<spa>, <al>, "-|>", [GET], label-side: right),
    edge(<cn>, <net>, "-|>"),
    edge(<rc>, <ctx>, "-|>"),
    edge(<rc>, <al>, "-|>"),
    edge(<tr>, <rc>, "-|>", [modelo], label-side: left),
    edge(<rc>, <iss>, "-|>", [umbral superado], label-side: left),
  ),
  [Contenedores. Todo lo que consume el navegador son ficheros estáticos cacheables.],
)

= Vista de componentes del cliente (C4 nivel 3)
#fig(
  diagram(
    spacing: (10mm, 9mm),
    edge-stroke: 0.6pt + tf.grey6,
    n-box((0, 0), [`ui/`\ App · MapView · SearchPanel\ JourneyList · OpsConsole · PrivacyNotice], name: <ui>),
    n-box((0, 1.3), [`application/`\ useJourneys · useContext · ranking], name: <app>),
    n-sys((-1.3, 2.6), wt[`domain/raptor`\ McRAPTOR], name: <rap>),
    n-sys((0, 2.6), wt[`domain/fares`\ `domain/emissions`], name: <fe>),
    n-sys((1.3, 2.6), wt[`domain/fusion`\ fiabilidad · confort], name: <fu>),
    n-sys((0, 3.7), wt[`domain/pareto` · `geo` · `ranking`], name: <core>),
    n-box((2.4, 1.3), [`infrastructure/`\ dataClient · router.worker], name: <inf>, fill: tf.grey1, stroke: 0.6pt + tf.grey5),
    edge(<ui>, <app>, "-|>"),
    edge(<app>, <rap>, "-|>"),
    edge(<app>, <fe>, "-|>"),
    edge(<app>, <fu>, "-|>"),
    edge(<rap>, <core>, "-|>"),
    edge(<fe>, <core>, "-|>"),
    edge(<fu>, <core>, "-|>"),
    edge(<inf>, <app>, "-|>", [implementa puertos], label-side: left),
  ),
  [Componentes. Las flechas siguen la regla de dependencias: el dominio no conoce la UI ni la infraestructura.],
)

= Flujo de datos y ML
#fig(
  diagram(
    spacing: (12mm, 10mm),
    edge-stroke: 0.6pt + tf.grey6,
    n-ext((0, 0), [GTFS Metro · ML · EMT], name: <gtfs>),
    n-ext((0, 1), [GBFS BiciMAD], name: <gbfs>),
    n-ext((0, 2), [Open-Meteo · NO₂ · tráfico], name: <ext>),
    n-ext((0, 3), [Viajes diarios BiciMAD], name: <hist>),
    n-box((1.6, 0), [Compilador de red\ patrones · transbordos], name: <comp>),
    n-box((1.6, 1), [Nowcast estación\ deriva + difusión], name: <now>),
    n-box((1.6, 2), [Normalización\ de contexto], name: <norm>),
    n-box((1.6, 3), [LightGBM cuantílico\ demanda diaria], name: <lgb>),
    n-sys((3.2, 1.5), wt[Data fusion\ + umbrales], name: <fus>),
    n-store((4.6, 0.5), [network.json], name: <o1>),
    n-store((4.6, 1.5), [context.json], name: <o2>),
    n-alert((4.6, 2.5), [Alertas → técnico], name: <o3>),
    edge(<gtfs>, <comp>, "-|>"), edge(<gbfs>, <now>, "-|>"), edge(<ext>, <norm>, "-|>"), edge(<hist>, <lgb>, "-|>"),
    edge(<comp>, <o1>, "-|>"),
    edge(<now>, <fus>, "-|>"), edge(<norm>, <fus>, "-|>"), edge(<lgb>, <fus>, "-|>"),
    edge(<fus>, <o2>, "-|>"), edge(<fus>, <o3>, "-|>"),
  ),
  [Pipeline de datos. Las fuentes solo contienen datos agregados o de infraestructura; ninguna contiene datos personales.],
)

= Tecnologías

#brand-table(
  columns: (1fr, 1.4fr, 2.2fr),
  header: ("Capa", "Tecnología", "Motivo"),
  [Lenguaje cliente], [TypeScript 5 (strict)], [Tipado estático del dominio; mismo código en UI y Worker.],
  [UI], [React 18 + Vite], [Ecosistema maduro, build estático rápido, `base` configurable para Pages.],
  [Mapa], [MapLibre GL JS + OpenFreeMap], [Vectorial, open source (BSD), sin claves ni cookies de seguimiento.],
  [Concurrencia], [Web Worker], [El enrutamiento no bloquea la interfaz.],
  [Tests cliente], [Vitest + ESLint], [Rápidos, nativos de Vite.],
  [Datos/ML], [Python 3.12, uv, pandas, LightGBM, scikit-learn], [Estándar de facto; `uv` reproducible con `uv.lock`.],
  [Calidad Python], [Ruff, mypy, pytest], [Lint + tipos + tests en CI.],
  [Registro de experimentos], [MLflow (local) + `model_card.json` versionado], [Proporcionado: sin servidor de tracking.],
  [Orquestación], [GitHub Actions (cron, dispatch)], [Sin infraestructura propia; auditable.],
  [Hosting], [GitHub Pages], [Estático, HTTPS, CDN global, coste 0 en el piloto.],
  [Documentación], [Typst + fletcher], [Docs-as-code: versionado, revisable en PR, PDF reproducible.],
)

#fig(
  {
    set text(size: 8pt)
    let layer(title, color, ..items) = block(width: 100%, inset: 6pt, radius: 4pt, fill: color.lighten(85%), stroke: 0.6pt + color)[
      #text(weight: 700, fill: color, title) \
      #items.pos().map(i => box(inset: (x: 5pt, y: 3pt), radius: 3pt, fill: white, stroke: 0.4pt + color, i)).join(h(4pt))
    ]
    stack(spacing: 5pt,
      layer("Presentación", tf.blue, "React 18", "MapLibre GL", "CSS tokens Mística", "i18n es"),
      layer("Aplicación", tf.blue70, "Hooks", "Ranking por perfil", "Web Worker"),
      layer("Dominio", tf.navy, "McRAPTOR", "Tarifas", "Emisiones", "Fusión", "Pareto"),
      layer("Datos y ML", tf.turquoise70, "Python 3.12", "pandas", "LightGBM", "MLflow", "uv"),
      layer("Plataforma", tf.grey6, "GitHub Actions", "GitHub Pages", "Issues/PR", "Dependabot", "CodeQL"),
    )
  },
  [Mapa de tecnologías por capas.],
)

= Motor de rutas McRAPTOR
- *Red*: cada línea GTFS se descompone en *patrones* (secuencia exacta de paradas). Para cada
  patrón se guardan los tiempos acumulados de recorrido y la distancia acumulada, y las salidas
  del día tipo laborable (expandiendo `frequencies.txt`).
- *Transbordos a pie*: pares de paradas a ≤ 400 m, distancia haversine × 1,3 (rodeo) a 4,8 km/h.
- *Bici pública*: acceso y egreso _a pie → estación BiciMAD → bici (15 km/h) → estación → a pie_,
  con 1 min de desanclaje/anclaje; además, ruta directa en bici puerta a puerta.
- *Criterios*: llegada (s), coste (céntimos), emisiones (gCO₂e). Bolsas de Pareto por parada y
  ronda con dominancia ε (5 céntimos, 10 g) y tamaño acotado.
- *Ranking*: normalización min–max dentro del frente y pesos por perfil; penalización por
  fiabilidad esperada (si P(bici) = p, se suma (1 − p) × 8 min de contingencia esperada).

= Despliegue
#fig(
  diagram(
    spacing: (14mm, 10mm),
    edge-stroke: 0.6pt + tf.grey6,
    n-person((0, 0), wt[Desarrollador], name: <dev>),
    n-box((1.5, 0), [Pull Request], name: <pr>),
    n-box((3, 0), [CI: lint · types · tests\ CodeQL · audit · Typst], name: <ci>),
    n-box((4.5, 0), [Revisión\ CODEOWNERS], name: <rev>),
    n-box((4.5, 1.2), [merge a `main`], name: <main>),
    n-box((3, 1.2), [build Vite\ + datos + PDFs], name: <build>),
    n-sys((1.5, 1.2), wt[GitHub Pages\ (HTTPS, CDN)], name: <pages>),
    n-box((3, 2.4), [cron 15 min:\ refresh-context], name: <cron>, fill: tf.turquoise10, stroke: 0.6pt + tf.turquoise70),
    n-person((0, 1.2), wt[Usuarios], name: <users>),
    edge(<dev>, <pr>, "-|>"), edge(<pr>, <ci>, "-|>"), edge(<ci>, <rev>, "-|>"),
    edge(<rev>, <main>, "-|>"), edge(<main>, <build>, "-|>"), edge(<build>, <pages>, "-|>", [deploy-pages]),
    edge(<cron>, <build>, "-|>"),
    edge(<users>, <pages>, "<|-", [HTTPS]),
  ),
  [Despliegue continuo. Los datos de contexto se refrescan sin intervención; el código y la configuración, solo vía PR.],
)

== Entornos
#brand-table(
  columns: (1fr, 2fr, 2fr),
  header: ("Entorno", "Cómo", "Para qué"),
  [Local], [`npm run dev` (web) · `uv run auralink-ml …` (datos)], [Desarrollo y pruebas],
  [Preview], [Artefacto de build de cada PR], [Revisión funcional],
  [Producción piloto], [GitHub Pages desde `main`], [Usuarios del piloto],
  [Evolución B2G], [Contenedores (FastAPI + PostGIS + OIDC) en nube soberana], [Escala regional, SSO corporativo, SLA],
)

= Escalabilidad y sostenibilidad
- *Lectura*: todo es estático y cacheable → escala horizontalmente vía CDN sin coste por consulta.
- *Cómputo*: el coste de cada búsqueda lo asume el dispositivo (≈ 100–600 ms); no hay servidor
  que saturar. Para redes regionales completas se migraría a ULTRA/servidor (AURA-DOC-00).
- *Tamaño de red*: patrones + salidas comprimidos (gzip por HTTP); se carga una vez y se cachea.
- *Sostenibilidad ambiental del software*: sin servidores encendidos 24/7; los jobs programados
  duran segundos; ficheros comprimidos reducen transferencia (Green Software Foundation, principios
  de eficiencia energética y de hardware).
- *Mantenibilidad*: dominio puro con tests, lint y tipado estricto, configuración separada del
  código, ADRs en este documento.
