#import "template/corporativa.typ": *

#show: doc.with(
  title: "Informe de tiempos del experimento",
  subtitle: "Cuánto se tardó en cada etapa: análisis, diseño, implementación, documentación y verificación",
  code: "AURA-DOC-08",
  version: "1.1",
)

// Fuente: timelog.csv, escrito por tools/timelog.py al empezar y terminar cada etapa.
#let raw = csv("../timelog.csv").slice(1).filter(r => r.at(3) != "")
#let rows = raw.map(r => (etapa: r.at(0), inicio: r.at(1), fin: r.at(2), min: float(r.at(3))))
#let total = rows.map(r => r.min).sum()
#let hhmm(iso) = iso.slice(11, 16)

= Control de versiones
#version-table(
  ("1.0", "26/10/2026", "Equipo Aura Link", "Informe generado a partir de timelog.csv al cerrar el experimento."),
  ("1.1", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

= Metodología de medida
- Cada etapa se abre y se cierra con `python tools/timelog.py start "<etapa>"`, que registra la
  marca temporal del sistema (zona Europe/Madrid) en `timelog.csv`. Abrir una etapa cierra la
  anterior, de modo que no hay huecos ni solapes en el registro.
- Se mide *tiempo de reloj* del agente (Claude Code, modelo Claude Opus 5.5), incluidas esperas
  de instalación, descargas y compilaciones.
- Hubo trabajo en paralelo dentro de etapas (p. ej. el recolector de BiciMAD corría en segundo
  plano mientras se diseñaba); se imputa a la etapa activa en ese momento.
- La etapa 0 (planificación) incluye la conversación previa de aclaración con el usuario.

= Resultados
#grid(columns: (1fr, 1fr, 1fr), gutter: 8pt,
  kpi(str(calc.round(total, digits: 0)) + " min", "tiempo total registrado"),
  kpi(str(rows.len()), "etapas", color: tf.blue70),
  kpi(hhmm(rows.first().inicio) + " → " + hhmm(rows.last().fin), "inicio → fin (26/10/2026)", color: tf.turquoise70),
)

#brand-table(
  columns: (3fr, 0.8fr, 0.8fr, 0.9fr, 0.8fr),
  header: ("Etapa", "Inicio", "Fin", "Minutos", "% total"),
  ..rows.map(r => (r.etapa, hhmm(r.inicio), hhmm(r.fin), str(calc.round(r.min, digits: 1)), str(calc.round(r.min / total * 100, digits: 1)) + " %")).flatten(),
  [*Total*], [], [], [*#calc.round(total, digits: 1)*], [100 %],
)

#fig(
  hbars(rows.map(r => (r.etapa, r.min)), unit: " min", label-width: 7cm, width: 7cm),
  [Duración por etapa.],
)

= Observaciones
#let pct(pred) = {
  let s = rows.filter(pred).map(r => r.min).sum(default: 0)
  calc.round(s / total * 100)
}
- *Análisis y diseño* (etapas 0–3): #pct(r => r.etapa.starts-with("0") or r.etapa.starts-with("1") or r.etapa.starts-with("2") or r.etapa.starts-with("3")) % del tiempo, incluyendo la
  investigación de mercado, la localización de fuentes de datos abiertas y la plantilla corporativa.
- *Implementación* (etapas 4–7): #pct(r => r.etapa.starts-with("4") or r.etapa.starts-with("5") or r.etapa.starts-with("6") or r.etapa.starts-with("7")) % —motor de rutas, pipeline de datos/ML, frontend y CI/CD.
- *Documentación y verificación* (etapas 8–9): #pct(r => r.etapa.starts-with("8") or r.etapa.starts-with("9")) %.
- Incidencias que consumieron tiempo y quedaron documentadas: duplicación de salidas en el GTFS de
  EMT (plantillas por bloque), rutas con caracteres no ASCII en LightGBM/MLflow (Windows), cadena
  de certificados de Let's Encrypt no reconocida por el Python embebido, cambio de hora (DST) en la
  serie horaria, y *training-serving skew* de la variable viento detectado por el PSI.

#callout(kind: "info", title: "Interpretación")[
  Los tiempos reflejan un flujo de ingeniería asistida por IA con un único agente y revisión
  puntual del usuario. Un equipo humano equivalente necesitaría semanas (AURA-DOC-07 estima 4
  meses para un MVP convencional); la validación por expertos (DPD, seguridad, negocio) y las
  pruebas con usuarios reales *no* están incluidas en este cronómetro y deben planificarse aparte.
]
