#import "template/corporativa.typ": *

#show: doc.with(
  title: "Innovación, data fusion y umbrales",
  subtitle: "Qué hace distinto a Aura Link y cómo decide un humano",
  code: "AURA-DOC-04",
  version: "1.1",
)

= Control de versiones
#version-table(
  ("0.1", "26/10/2026", "Equipo Aura Link", "Hipótesis de innovación tras el estudio de mercado."),
  ("1.0", "26/10/2026", "Equipo Aura Link", "Fusión implementada (BiciMAD, meteorología, NO₂, tráfico, demanda); umbrales y flujo de decisión vía GitHub."),
  ("1.1", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

= Aspectos de innovación
#brand-table(
  columns: (1.3fr, 2.4fr, 1.3fr),
  header: ("Innovación", "Descripción", "Estado del arte"),
  [Enrutamiento tricriterio en el dispositivo], [McRAPTOR (tiempo, coste, CO₂) en un Web Worker sobre una red GTFS compacta (≈ 0,5 MB gzip). 50–90 ms por consulta en Madrid (Metro, Metro Ligero, EMT, BiciMAD).], [Los planificadores comerciales calculan en servidor.],
  [Privacidad radical por arquitectura], [El origen/destino nunca sale del navegador. No hay base de datos de trayectos que proteger, filtrar o vender.], [Las apps de consumo registran trayectos y ubicación.],
  [Fusión de contexto con confianza explícita], [Cada fuente aporta evidencia y una confianza que decae con la antigüedad; las contribuciones se explican al usuario.], [Avisos genéricos sin cuantificar incertidumbre.],
  [Predicción con incertidumbre calibrada], [Demanda con intervalos conformes; disponibilidad por estación con modelo de difusión bayesiano.], [Predicción puntual sin intervalos.],
  [Humano en el bucle auditable], [Umbrales → Issues → decisión con etiquetas → cambio por PR revisada.], [Paneles de operación sin trazabilidad de decisiones.],
  [Infraestructura casi nula], [GitHub Pages + Actions: sin servidores que operar.], [Clústeres JVM (OpenTripPlanner) o SaaS.],
)

= Data fusion: por qué es una ventaja competitiva
Ninguna fuente por sí sola responde a la pregunta del usuario: *"¿me conviene ir en bici ahora?"*.
La respuesta depende de si habrá bici y anclaje (BiciMAD), de si llueve (meteorología), de la
calidad del aire en tramos activos (NO₂), del tráfico (retrasos del bus) y de cuánta demanda se
espera (rotación en estaciones). La fusión convierte cinco datos heterogéneos en dos indicadores
comprensibles —*fiabilidad* y *confort*— y una *duración esperada*.

#fig(
  diagram(
    spacing: (12mm, 7mm),
    edge-stroke: 0.6pt + tf.grey6,
    n-ext((0, 0), [GBFS BiciMAD\ (cada 15 min)], name: <g>),
    n-ext((0, 1), [Open-Meteo\ (horaria)], name: <w>),
    n-ext((0, 2), [NO₂ Ayto. Madrid\ (horaria)], name: <a>),
    n-ext((0, 3), [Tráfico informo\ (5 min)], name: <t>),
    n-ext((0, 4), [Modelo de demanda\ (diaria)], name: <d>),
    n-box((1.7, 0), [Nowcast P(bici), P(anclaje)], name: <g2>),
    n-box((1.7, 1), [Lluvia, temperatura, viento], name: <w2>),
    n-box((1.7, 2), [Exposición en tramos activos], name: <a2>),
    n-box((1.7, 3), [Retraso esperado del bus], name: <t2>),
    n-box((1.7, 4), [Presión sobre estaciones], name: <d2>),
    n-sys((3.4, 2), wt[Fusión ponderada\ por confianza\ $c = e^(-"edad"\/tau)$], name: <f>),
    n-box((5, 1), [Fiabilidad], name: <r>, fill: tf.turquoise10, stroke: 0.6pt + tf.turquoise70),
    n-box((5, 2), [Confort], name: <c>, fill: tf.turquoise10, stroke: 0.6pt + tf.turquoise70),
    n-box((5, 3), [Duración esperada\ + explicación], name: <e>, fill: tf.turquoise10, stroke: 0.6pt + tf.turquoise70),
    edge(<g>, <g2>, "-|>"), edge(<w>, <w2>, "-|>"), edge(<a>, <a2>, "-|>"), edge(<t>, <t2>, "-|>"), edge(<d>, <d2>, "-|>"),
    edge(<g2>, <f>, "-|>"), edge(<w2>, <f>, "-|>"), edge(<a2>, <f>, "-|>"), edge(<t2>, <f>, "-|>"), edge(<d2>, <g2>, "-|>", bend: -50deg, [$sigma^2 times "presión"$]),
    edge(<f>, <r>, "-|>"), edge(<f>, <c>, "-|>"), edge(<f>, <e>, "-|>"),
  ),
  [Fusión a nivel de decisión. La demanda modula la varianza del nowcast; las demás fuentes aportan evidencia ponderada por su frescura.],
)

== Reglas de fusión
#brand-table(
  columns: (1fr, 2.6fr, 1fr),
  header: ("Fuente", "Regla", "τ (confianza)"),
  [BiciMAD], [$p' = c dot p + (1 - c) dot 0.5$: sin dato fresco la probabilidad se contrae a la ignorancia (0,5), nunca se inventa certeza. Fiabilidad $times= p'_"bici" dot p'_"anclaje"$; contingencia esperada $(1-p') dot 8$ min.], [30 min],
  [Demanda], [La presión (P50 hoy / mediana semanal) multiplica la varianza del nowcast: más demanda, más incertidumbre.], [diaria],
  [Tráfico], [Retraso esperado en bus $= t_"bus" dot 0.5 dot "carga"\/100 dot c$; fiabilidad $times= 1 - 0.3 dot "carga"\/100 dot c$.], [45 min],
  [Meteorología], [Lluvia ≥ umbral: confort $-= 0.5 dot s dot c$ ($s$ = fracción del viaje en modo activo); temperatura extrema y viento > 35 km/h en bici también penalizan.], [6 h],
  [Calidad del aire], [NO₂ urbano > umbral (o aviso activado por el técnico): confort $-= 0.3 dot s dot c$.], [3 h],
)

#callout(kind: "ok", title: "Explicabilidad")[
  Cada penalización genera un "factor" visible en la tarjeta de la ruta con su fuente y su
  confianza (p. ej. "BiciMAD: P(bici en Sol) = 42 % · confianza 97 %"). El usuario entiende por
  qué una opción baja en el ranking; el técnico puede auditar la lógica.
]

== Ranking
Sobre el frente de Pareto, cada perfil (equilibrada, más rápida, más barata, más verde) pondera
los criterios normalizados min–max, usando la *duración esperada* de la fusión y penalizando
$0.8 dot (1 - "fiabilidad") + 0.3 dot (1 - "confort")$. Cambiar de perfil reordena al instante sin
recalcular rutas.

= Umbrales y decisión humana
#callout(kind: "warn", title: "Principio")[
  El sistema *informa* al usuario (avisos) y *propone* al técnico (alertas). *No modifica nunca*
  su propia configuración: excluir una estación, activar un aviso de calidad del aire, cambiar un
  umbral o promocionar un modelo exige una decisión humana registrada.
]

#brand-table(
  columns: (2.2fr, 0.6fr, 0.7fr, 2.2fr),
  header: ("Umbral", "Tipo", "Valor", "Qué ocurre al superarlo"),
  [`bike_availability_notice`], [aviso], [0,6], [Tramo marcado "bici poco fiable" en la ruta.],
  [`dock_availability_notice`], [aviso], [0,6], [Ídem para la devolución.],
  [`station_empty_alert`], [alerta], [0,15 (≥ 5 est.)], [Issue: proponer excluir estaciones o pedir reequilibrio.],
  [`system_empty_share_alert`], [alerta], [25 %], [Issue: aviso general de baja disponibilidad.],
  [`rain_notice`], [aviso], [0,5 mm/h], [Aviso al usuario y penalización de confort.],
  [`no2_alert`], [alerta], [100 µg/m³], [Issue: proponer activar aviso de exposición.],
  [`traffic_congestion_notice`], [aviso], [40/100], [Aviso y retraso esperado en bus.],
  [`demand_forecast_uncertainty_alert`], [alerta], [0,6], [Issue: presión de demanda poco fiable.],
  [`drift_psi_alert`], [alerta], [0,2], [Issue: valorar reentrenamiento.],
  [`model_degradation_alert`], [alerta], [1,0], [Issue: no promocionar el modelo.],
  [`data_staleness_alert`], [alerta], [por fuente], [Issue: fuente caída o desactualizada.],
)

#fig(
  diagram(
    spacing: (11mm, 9mm),
    edge-stroke: 0.6pt + tf.grey6,
    n-box((0, 0), [Pipeline\ cada 15 min], name: <p>),
    node((1.3, 0), [¿Supera\ umbral?], name: <q>, shape: fletcher.shapes.diamond, fill: tf.ambar10, stroke: 0.6pt + rgb("#A7863E"), inset: 6pt),
    n-alert((2.8, 0), [Issue de alerta\ (evidencia + acción sugerida)], name: <i>),
    n-person((4.4, 0), wt[Técnico], name: <t>),
    n-box((4.4, 1.3), [Etiqueta\ `decision:rechazar`\ `valoracion:falso-positivo`], name: <rej>, fill: tf.grey1, stroke: 0.6pt + tf.grey5),
    n-box((2.8, 1.3), [Pull Request sobre\ `config/overrides.yaml`\ o `thresholds.yaml`], name: <pr>),
    n-box((1.3, 1.3), [Revisión\ CODEOWNERS], name: <rv>),
    n-sys((0, 1.3), wt[Merge → nuevo\ comportamiento], name: <m>),
    edge(<p>, <q>, "-|>"), edge(<q>, <i>, "-|>", [sí]), edge(<i>, <t>, "-|>"),
    edge(<t>, <rej>, "-|>", [descarta]), edge(<t>, <pr>, "-|>", [aprueba], label-side: left),
    edge(<pr>, <rv>, "-|>"), edge(<rv>, <m>, "-|>"),
    edge(<q>, <p>, "-|>", bend: -50deg, [no]),
  ),
  [Flujo de decisión. Toda acción queda registrada (Issue, etiquetas, PR, revisión, commit).],
)

La valoración de alertas (`valoracion:util` / `valoracion:falso-positivo`) permite medir la
precisión de cada umbral y recalibrarlo con datos: es el bucle de mejora del propio sistema de
alertas. Implica tratar datos personales del técnico (usuario de GitHub, acciones): ver
AURA-DOC-06, tratamiento T2.

== Simulador "qué pasaría si"
La consola técnica permite mover un umbral y ver, con los datos actuales, cuántas estaciones lo
superarían y si se generaría una alerta, *antes* de proponer el cambio por PR. Reduce cambios a
ciegas y ayuda a calibrar.
