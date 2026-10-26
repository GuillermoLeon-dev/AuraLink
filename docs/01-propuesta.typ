#import "template/corporativa.typ": *

#show: doc.with(
  title: "Propuesta de valor y producto",
  subtitle: "Aura Link: la mejor ruta según tiempo, coste y emisiones, con decisión humana",
  code: "AURA-DOC-01",
  version: "1.1",
)

= Control de versiones
#version-table(
  ("0.1", "26/10/2026", "Equipo Aura Link", "Visión inicial a partir del estudio de mercado (AURA-DOC-00)."),
  ("1.0", "26/10/2026", "Equipo Aura Link", "Restricción de despliegue en GitHub Pages incorporada; alcance del MVP cerrado."),
  ("1.1", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

= Resumen ejecutivo
#grid(columns: (1fr, 1fr, 1fr, 1fr), gutter: 8pt,
  kpi("3", "criterios optimizados a la vez: tiempo, coste y CO₂"),
  kpi("0", "orígenes/destinos enviados a servidores", color: tf.green),
  kpi("4+", "fuentes fusionadas: BiciMAD, clima, aire, tráfico, demanda", color: tf.blue70),
  kpi("≈0 €", "coste de hosting del piloto (GitHub Pages)", color: tf.turquoise70),
)

*Aura Link* es una aplicación web que, dado un origen y un destino en Madrid, calcula el conjunto de
alternativas *óptimas en el sentido de Pareto* combinando Metro, Metro Ligero, bus EMT, BiciMAD y
tramos a pie, y las ordena según la preferencia del usuario (más rápida, más barata, más verde o
equilibrada). Cada alternativa incluye su *fiabilidad* y *confort*, obtenidos fusionando la
predicción de disponibilidad de bicis, la meteorología, la calidad del aire, el tráfico y la
demanda prevista del sistema.

Para el operador (consorcio, ayuntamiento o un integrador tecnológico), Aura Link incluye una
*consola técnica*: el sistema detecta situaciones anómalas mediante *umbrales configurables* y
genera alertas; ninguna acción operativa se aplica sin que un técnico la apruebe.

= Usuarios y necesidades
#brand-table(
  columns: (1fr, 2fr, 2fr),
  header: ("Perfil", "Necesidad", "Respuesta de Aura Link"),
  [Ciudadano / visitante], [Elegir rápido la mejor opción entendiendo el compromiso], [Frente de Pareto visual, ranking por preferencia, desglose por tramo],
  [Usuario sensible al precio], [Saber cuánto cuesta realmente], [Perfiles tarifarios (sencillo, 10 viajes, abono) y BiciMAD],
  [Usuario con conciencia ambiental], [Reducir su huella], [gCO₂e por alternativa y ahorro frente al coche],
  [Técnico de operación], [Detectar problemas y decidir con datos], [Alertas por umbral, simulador "qué pasaría si", decisión trazable],
  [Responsable de movilidad], [Medir impacto y cumplir RGPD], [Métricas agregadas sin datos personales, EIPD, model card],
)

= Propuesta de valor
+ *Transparencia multicriterio.* El usuario ve el compromiso entre tiempo, coste y emisiones en
  vez de una única "mejor ruta" opaca.
+ *Recomendación consciente del contexto.* Si va a llover o la estación de BiciMAD previsiblemente
  estará vacía, la alternativa en bici pierde fiabilidad y se explica por qué.
+ *Privacidad radical por diseño.* El cálculo ocurre en el navegador; el origen y el destino no
  salen del dispositivo (art. 25 RGPD; ver AURA-DOC-06).
+ *Operación con humano en el bucle.* Umbrales configurables por el técnico, decisiones auditadas
  en Git.
+ *Sostenibilidad económica.* Arquitectura estática, coste marginal por consulta ≈ 0, escalable
  vía CDN (ver AURA-DOC-07).

= Alcance del MVP
#grid(columns: (1fr, 1fr), gutter: 10pt,
  callout(kind: "ok", title: "Incluido")[
    - Red Metro, Metro Ligero y EMT (GTFS), BiciMAD (GBFS)
    - Enrutamiento McRAPTOR (≤ 4 transbordos) en Web Worker
    - Accesos/egresos a pie y en bici pública
    - Tarifas y factores de emisión configurables con fuente
    - Modelo de demanda diaria BiciMAD (LightGBM cuantílico)
    - Nowcast de disponibilidad por estación
    - Data fusion: clima, NO₂, tráfico, demanda
    - Consola técnica, alertas por umbral, Issues/PR
    - Documentación Typst, CI/CD a GitHub Pages
  ],
  callout(kind: "warn", title: "Fuera del MVP (evolución)")[
    - Callejero OSM real (hoy: distancia × factor de rodeo)
    - Tiempo real de llegadas EMT (requiere credenciales)
    - Cercanías e interurbanos
    - Pago / validación de títulos (MaaS completo)
    - Modelos espacio-temporales profundos (GNN/TFT)
    - Modo servidor para B2G con SSO corporativo
  ],
)

= Historias de usuario principales
#brand-table(
  columns: (0.4fr, 2.6fr, 2fr),
  header: ("ID", "Historia", "Criterio de aceptación"),
  [HU-1], [Como usuario quiero marcar origen y destino en el mapa o elegir una estación para obtener alternativas.], [≥ 1 alternativa en < 2 s en un portátil medio.],
  [HU-2], [Como usuario quiero ordenar por rapidez, precio o emisiones.], [El orden cambia sin recalcular la búsqueda.],
  [HU-3], [Como usuario quiero saber si es fiable ir en bici.], [Cada tramo en bici muestra probabilidad de bici y anclaje.],
  [HU-4], [Como técnico quiero ver alertas cuando se superen umbrales.], [Alertas con valor, umbral, evidencia y enlace a la decisión.],
  [HU-5], [Como técnico quiero ajustar un umbral y ver su efecto antes de aplicarlo.], [Simulador en consola; cambio efectivo solo vía PR aprobado.],
  [HU-6], [Como DPD quiero verificar que no se almacenan trayectos.], [Sin peticiones de red con coordenadas del usuario (test e2e).],
)
