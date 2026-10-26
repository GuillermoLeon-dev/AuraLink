#import "template/corporativa.typ": *

#show: doc.with(
  title: "Viabilidad económica",
  subtitle: "Costes, escalado, modelo de negocio y punto de equilibrio",
  code: "AURA-DOC-07",
  version: "1.1",
)

// ---------------- Supuestos (editar aquí: todas las tablas se recalculan) ----------------
#let A = (
  fte_month_cost: 5500,       // € coste empresa mensual medio de un perfil técnico
  mvp_months: 4,
  mvp_fte: 3.7,               // 2 desarrollo + 1 datos/ML + 0,5 PM + 0,2 legal/DPD
  support_fte: 0.5,           // operación y evolución anual
  legal_year: 3000,           // revisión DPD, EIPD, contratos
  infra_year_pilot: 600,      // GitHub Team + minutos Actions extra + almacenamiento de teselas
  license_city_year: 40000,   // licencia B2G por ciudad (soporte, SLA, adaptación)
  onboarding_city: 15000,     // alta de una nueva ciudad (feeds, calibración, formación)
  cities: (1, 2, 4),          // ciudades por año (escenario base)
)
#let eur(v) = {
  let neg = v < 0
  let s = str(int(calc.abs(calc.round(v))))
  let out = ""
  let n = s.len()
  for (i, ch) in s.clusters().enumerate() {
    if i > 0 and calc.rem(n - i, 3) == 0 { out += "." }
    out += ch
  }
  (if neg { "−" } else { "" }) + out + " €"
}
#let mvp_cost = A.fte_month_cost * A.mvp_months * A.mvp_fte
#let opex_year = A.support_fte * 12 * A.fte_month_cost + A.legal_year + A.infra_year_pilot

#let _proj = range(3).map(y => {
  let c = A.cities.at(y)
  let prev = if y == 0 { 0 } else { A.cities.at(y - 1) }
  let revenue = c * A.license_city_year + (c - prev) * A.onboarding_city
  let cost = (if y == 0 { mvp_cost } else { 0 }) + opex_year + (c - 1) * 0.25 * 12 * A.fte_month_cost
  revenue - cost
})
#let payback = {
  let acc = 0
  let year = none
  for (i, r) in _proj.enumerate() { acc += r; if year == none and acc >= 0 { year = i + 1 } }
  year
}

= Control de versiones
#version-table(
  ("0.1", "26/10/2026", "Equipo Aura Link", "Estimación con arquitectura de servidor (OpenTripPlanner)."),
  ("1.0", "26/10/2026", "Equipo Aura Link", "Arquitectura static-first: coste de operación casi nulo; escenarios y sensibilidad."),
  ("1.1", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

#callout(kind: "info", title: "Cómo usar este documento")[
  Todas las cifras derivan de los supuestos del bloque inicial del fichero fuente (`A`). Son
  *estimaciones de orden de magnitud* para decidir, no un presupuesto: deben contrastarse con
  tarifas internas y con el cliente. Cambiar un supuesto y recompilar recalcula todas las tablas.
]

= Resumen
#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 8pt,
  kpi(eur(mvp_cost), "inversión MVP (desarrollo convencional)"),
  kpi(eur(opex_year), "operación anual piloto", color: tf.blue70),
  kpi("≈ 0 €", "coste marginal por consulta", color: tf.green),
  kpi(if payback == none { "> 3 años" } else { "Año " + str(payback) }, "recuperación de la inversión (escenario base)", color: tf.turquoise70),
)

= Costes
== Desarrollo del MVP
#brand-table(
  columns: (2fr, 1fr, 1fr),
  header: ("Concepto", "Supuesto", "Importe"),
  [Equipo (2 desarrollo, 1 datos/ML, 0,5 PM, 0,2 legal/DPD)], [#A.mvp_fte FTE × #A.mvp_months meses], eur(mvp_cost),
  [Licencias de software], [100 % open source], [0 €],
  [Datos], [Abiertos (CRTM, EMT, Ayto. Madrid, Open-Meteo)], [0 €],
)

#callout(kind: "idea", title: "Dato del experimento")[
  Este MVP (análisis, diseño, implementación, documentación) se ha construido con ingeniería
  asistida por IA en el tiempo registrado en AURA-DOC-08. No elimina la necesidad de revisión
  experta (DPD, seguridad, negocio, pruebas con usuarios), pero reduce de forma drástica el coste
  de llegar a un prototipo verificable y desplaza la inversión hacia validación y operación.
]

== Operación
#brand-table(
  columns: (2fr, 1.4fr, 1fr),
  header: ("Concepto", "Supuesto", "€/año"),
  [Operación y evolución], [#A.support_fte FTE], eur(A.support_fte * 12 * A.fte_month_cost),
  [Cumplimiento (DPD, EIPD, contratos)], [revisión anual], eur(A.legal_year),
  [Infraestructura piloto], [GitHub Team, minutos de Actions, almacenamiento de teselas], eur(A.infra_year_pilot),
  [*Total*], [], [*#eur(opex_year)*],
)

== Infraestructura por escala: static-first frente a servidor
Supuestos: 0,9 MB por visita nueva (red ≈ 0,54 MB gzip + aplicación ≈ 0,3 MB; las siguientes visitas
usan caché), 4 consultas por usuario y mes. GitHub Pages admite ≈ 100 GB/mes de tráfico (límite
blando); por encima se sirve el mismo build desde una CDN estática.

#brand-table(
  columns: (1fr, 1.3fr, 1.3fr, 1.6fr),
  header: ("Usuarios/mes", "Static-first (Aura Link)", "Servidor de rutas", "Comentario"),
  [10 000], [≈ 0 €/mes (Pages)], [≈ 300 €/mes], [OTP mínimo: 1 VM 16 GB + BD + balanceador],
  [100 000], [≈ 0–20 €/mes], [≈ 800 €/mes], [Pages al límite; CDN estática opcional],
  [1 000 000], [≈ 100–200 €/mes (CDN)], [≈ 3 000–5 000 €/mes], [Servidor: varias réplicas y autoescalado],
)
#text(size: 8pt, fill: tf.grey6)[Las cifras de servidor son órdenes de magnitud de nube pública para un motor JVM de rutas (memoria intensiva) con alta disponibilidad; a validar con el proveedor elegido.]

#fig(
  hbars((
    ("Static-first · 10k", 0), ("Servidor · 10k", 300),
    ("Static-first · 100k", 20), ("Servidor · 100k", 800),
    ("Static-first · 1M", 200), ("Servidor · 1M", 4000),
  ), unit: " €/mes", fmt: v => str(calc.round(v)), color: tf.blue70),
  [Coste mensual de infraestructura por escala (límite superior de cada rango).],
)

= Modelo de negocio
#brand-table(
  columns: (1.2fr, 2.4fr, 1.2fr),
  header: ("Línea", "Propuesta", "Cliente"),
  [B2G licencia], [Despliegue por ciudad/consorcio con soporte, SLA, consola técnica, adaptación de feeds y cumplimiento (EIPD) incluidos.], [Ayuntamientos, consorcios, empresas municipales de transporte],
  [B2B white-label], [Motor y fusión integrables en apps MaaS u operadores (SDK web).], [Operadores, MaaS, aseguradoras de movilidad],
  [Servicios], [Analítica agregada de movilidad sostenible (sin datos personales), calibración de umbrales.], [Áreas de movilidad y sostenibilidad],
  [Ecosistema de integradores], [Integración con plataformas Smart City / IoT de integradores tecnológicos como componente de movilidad.], [Clientes de integradores Smart City],
)

= Proyección a 3 años (escenario base)
#let years = range(3)
#let rows = years.map(y => {
  let c = A.cities.at(y)
  let prev = if y == 0 { 0 } else { A.cities.at(y - 1) }
  let revenue = c * A.license_city_year + (c - prev) * A.onboarding_city
  let cost = (if y == 0 { mvp_cost } else { 0 }) + opex_year + (c - 1) * 0.25 * 12 * A.fte_month_cost
  (y + 1, c, revenue, cost, revenue - cost)
})
#let cum = {
  let acc = 0
  let out = ()
  for r in rows { acc += r.at(4); out.push(acc) }
  out
}

#brand-table(
  columns: (0.6fr, 0.8fr, 1.2fr, 1.2fr, 1.2fr, 1.2fr),
  header: ("Año", "Ciudades", "Ingresos", "Costes", "Resultado", "Acumulado"),
  ..rows.enumerate().map(((i, r)) => (str(r.at(0)), str(r.at(1)), eur(r.at(2)), eur(r.at(3)), eur(r.at(4)), eur(cum.at(i)))).flatten()
)
#text(size: 8pt, fill: tf.grey6)[Costes: MVP en el año 1, operación anual y +0,25 FTE por cada ciudad adicional. Ingresos: licencia anual por ciudad + alta de cada ciudad nueva.]

== Sensibilidad
#let breakeven_cities = calc.ceil((opex_year) / (A.license_city_year - 0.25 * 12 * A.fte_month_cost))
#brand-table(
  columns: (2fr, 1.2fr, 2fr),
  header: ("Variable", "Variación", "Efecto"),
  [Precio de licencia], [−25 % (30 000 €)], [El equilibrio se retrasa ≈ 1 año; sigue siendo viable con ≥ 3 ciudades.],
  [Ciudades captadas], [1 → 1 → 2], [Acumulado negativo a 3 años; viable solo con financiación pública inicial.],
  [Esfuerzo por ciudad], [0,5 FTE en lugar de 0,25], [Margen por ciudad ≈ #eur(A.license_city_year - 0.5 * 12 * A.fte_month_cost)/año; sigue positivo.],
  [Infraestructura], [×10 (tráfico)], [Irrelevante: < 1 % de los costes (static-first).],
)
#callout(kind: "ok", title: "Conclusión de viabilidad")[
  El coste se concentra en personas, no en infraestructura: el diseño static-first convierte el
  coste por usuario en prácticamente cero. Con la operación anual estimada (#eur(opex_year)) y un
  margen por ciudad de #eur(A.license_city_year - 0.25 * 12 * A.fte_month_cost), bastan
  #breakeven_cities ciudades para cubrir la operación recurrente; el escenario base recupera la
  inversión del MVP en el año #payback. El principal riesgo es comercial (captación), no técnico.
]

= Valor social (no monetizado)
Indicador de impacto, no ingreso: si un 1 % de 10 000 usuarios diarios sustituye un trayecto en
coche de 5 km por una alternativa con ≈ 50 gCO₂e/km, el ahorro es
$100 dot 5 dot (166 - 50) approx 58$ kg CO₂e/día ≈ *21 t CO₂e/año*. Aura Link muestra al usuario el
ahorro frente al coche en cada alternativa para reforzar el cambio modal.
