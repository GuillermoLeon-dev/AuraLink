#import "template/corporativa.typ": *

#show: doc.with(
  title: "Protección de datos",
  subtitle: "Privacidad desde el diseño y por defecto, RAT, análisis de riesgos y EIPD",
  code: "AURA-DOC-06",
  version: "1.1",
  classification: "Uso interno · Revisión DPD",
)

#let src(body) = text(size: 8pt, fill: tf.grey6, body)

= Control de versiones
#version-table(
  ("0.1", "26/10/2026", "Equipo Aura Link", "Inventario inicial de datos con arquitectura cliente-servidor."),
  ("1.0", "26/10/2026", "Equipo Aura Link", "Rediseño static-first: O/D solo en el dispositivo. Bases jurídicas, decisiones PbD/PbDf, RAT, análisis de riesgos y EIPD (metodología AEPD 2021)."),
  ("1.1", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

#callout(kind: "warn", title: "Alcance y limitaciones")[
  Documento técnico elaborado por el equipo de proyecto para su revisión por el Delegado de
  Protección de Datos (DPD) y asesoría jurídica de la entidad que despliegue el piloto. No sustituye
  su criterio. Cada decisión cita el artículo o la guía que la respalda y la fuente consultada
  (lista completa en la sección final). Los datos identificativos del responsable se completarán
  en el despliegue.
]

= Marco normativo y guías aplicadas
#brand-table(
  columns: (1.6fr, 2.6fr),
  header: ("Norma / guía", "Uso en este documento"),
  [Reglamento (UE) 2016/679 (RGPD)], [Principios (art. 5), licitud (6), transparencia (12–14), decisiones automatizadas (22), responsabilidad proactiva (24), PbD/PbDf (25), encargados (28), RAT (30), seguridad (32), brechas (33–34), EIPD (35–36), transferencias (44–46).],
  [LO 3/2018 (LOPDGDD)], [Transparencia por capas (art. 11), enfoque de riesgo (28), RAT (31), DPD (34), derechos digitales laborales (87–91).],
  [Ley 34/2002 (LSSI), art. 22.2], [Acceso a información del terminal (geolocalización del navegador, almacenamiento local).],
  [EDPB, Directrices 4/2019 sobre el art. 25 (v2.0, 2020)], [Elementos de PbD/PbDf y su eficacia.],
  [EDPB, Directrices 01/2020 vehículos conectados y aplicaciones de movilidad (v2.0, 2021)], [Sensibilidad de los datos de localización; preferencia por el tratamiento local.],
  [EDPB, Directrices 2/2023 sobre el art. 5.3 ePrivacy (v2.0, 2024)], [Alcance técnico del acceso al terminal.],
  [EDPB, Directrices 01/2025 sobre seudonimización], [Medidas de separación para la evolución con cuentas.],
  [GT29 WP248 rev.01 (EIPD) y WP251 rev.01 (decisiones automatizadas), refrendadas por el EDPB], [Criterios de alto riesgo; intervención humana significativa.],
  [AEPD, Guía de Privacidad desde el Diseño (2019)], [Estrategias de diseño (minimizar, ocultar, separar, abstraer, informar, controlar, cumplir, demostrar).],
  [AEPD, Guía de Protección de Datos por Defecto (2020)], [Cantidad, extensión, conservación y accesibilidad por defecto.],
  [AEPD, Gestión del riesgo y EIPD en tratamientos de datos personales (2021)], [Metodología de análisis de riesgos y EIPD.],
  [AEPD, Lista de tratamientos que requieren EIPD (art. 35.4)], [Análisis de necesidad de EIPD.],
  [AEPD, La protección de datos en las relaciones laborales (2021)], [Tratamiento de datos de técnicos.],
  [Reglamento (UE) 2024/1689 (Reglamento de IA)], [Clasificación de riesgo del componente de ML.],
)

= Inventario de datos personales
#callout(kind: "ok", title: "Resultado del diseño")[
  La arquitectura *static-first* (AURA-DOC-02, AD-01) hace que el responsable *no recoja* el
  origen, el destino, la hora del viaje ni la ubicación del usuario: se procesan solo en la memoria
  del navegador. Los datos personales que sí existen son la *dirección IP* que recibe cualquier
  servidor web y los *datos de los técnicos* que deciden sobre las alertas.
]

#brand-table(
  columns: (1.3fr, 1.1fr, 1.6fr, 1.1fr, 1.2fr),
  header: ("Dato", "¿Personal?", "Dónde / quién lo trata", "¿Se conserva?", "Tratamiento"),
  [Origen y destino del viaje], [Sí (localización, art. 4.1 RGPD)], [Solo en el navegador del usuario; nunca se transmite], [No (memoria de la pestaña)], [— (no hay tratamiento por el responsable)],
  [Ubicación del dispositivo (opcional)], [Sí], [API de geolocalización del navegador, baja precisión, solo local], [No], [— (ídem)],
  [Hora de salida, perfil tarifario, preferencia], [Sí, asociados al viaje], [Solo local], [No], [—],
  [Dirección IP y user-agent de visitantes], [Sí (STJUE C-582/14, Breyer)], [GitHub Pages (alojamiento); proveedor de teselas del mapa], [Según política del proveedor], [T1],
  [Zona visible del mapa (teselas pedidas)], [Indirectamente: puede revelar la zona del viaje], [Proveedor de teselas (OpenFreeMap)], [Según proveedor], [T1 (riesgo R2)],
  [Usuario de GitHub, nombre de perfil, acciones del técnico (etiquetas, comentarios, revisiones, *valoraciones de alertas*)], [Sí], [GitHub (repositorio de operación)], [Mientras exista el repositorio; política de conservación en T2], [T2],
  [Registro de actividad del pipeline (`alerts_log.jsonl`)], [No: solo indicadores agregados], [Artefactos del proyecto], [Sí], [—],
  [Instantáneas GBFS, NO₂, tráfico, meteorología, viajes diarios], [No: agregados de infraestructura (Cdo. 26 RGPD)], [Pipeline], [7 días (GBFS); resto según fuente], [—],
  [Informes de vulnerabilidades (SECURITY.md)], [Sí (identidad y contacto del informante)], [GitHub Security Advisories], [Hasta cierre + 1 año], [T3],
)

#src[Fuentes: RGPD art. 4.1 y Considerando 26; STJUE de 19/10/2016, asunto C-582/14 (Breyer); EDPB Directrices 01/2020, apdo. sobre datos de localización.]

= Tratamientos: finalidad y base jurídica
#brand-table(
  columns: (0.4fr, 1.4fr, 1.6fr, 2fr),
  header: ("ID", "Tratamiento", "Finalidad", "Base jurídica"),
  [T1], [Servicio web y teselas (IP, user-agent, zona visible)], [Entregar la aplicación y el mapa; seguridad del servicio], [Art. 6.1.e RGPD (misión de interés público del operador/ayuntamiento, con base en norma de rango legal: art. 8.2 LOPDGDD y competencias de movilidad) *o* art. 6.1.f (interés legítimo en la seguridad de la red, Cdo. 49) si el responsable es privado.],
  [T2], [Gestión de alertas por técnicos (identidad GitHub, decisiones, valoraciones)], [Trazabilidad de decisiones operativas y mejora de los umbrales], [Art. 6.1.b RGPD (ejecución del contrato laboral: registrar el propio trabajo) o 6.1.e en sector público; nunca para evaluar el rendimiento individual sin cumplir arts. 87–91 LOPDGDD y 20.3 / 20 bis ET.],
  [T3], [Gestión de notificaciones de seguridad], [Corregir vulnerabilidades], [Art. 6.1.f RGPD (interés legítimo en la seguridad, Cdo. 49).],
  [—], [Planificación de viajes], [Calcular rutas], [No aplica: el responsable no trata O/D. Si en el futuro se almacenaran (cuentas, favoritos en servidor), base: art. 6.1.b (servicio solicitado) y consentimiento para usos adicionales (art. 6.1.a).],
)
#src[Fuentes: RGPD arts. 6.1, 6.3 y Cdo. 49; LOPDGDD arts. 8 y 87–91; Real Decreto Legislativo 2/2015 (Estatuto de los Trabajadores) arts. 20.3 y 20 bis; AEPD, La protección de datos en las relaciones laborales (2021).]

= Decisiones de privacidad desde el diseño y por defecto
Cada decisión se vincula a la estrategia de diseño de la AEPD (Guía de Privacidad desde el
Diseño, 2019) y a su fundamento normativo.

#decision("PD-01", "El cálculo de rutas se ejecuta en el dispositivo",
  [El motor McRAPTOR corre en un Web Worker con la red descargada como fichero estático. El origen,
  el destino y la hora no se envían a ningún servidor. Verificado con inspección de tráfico de red
  (AURA-DOC-05, prueba P-01).],
  basis: [Art. 25.1 RGPD (medidas técnicas que apliquen de forma efectiva la minimización); art. 5.1.c
  (minimización). Estrategias AEPD *minimizar* y *ocultar*. EDPB 01/2020 recomienda tratar la localización
  localmente siempre que sea posible.],
  source: [EDPB, Directrices 4/2019 (v2.0), apdos. sobre minimización; EDPB, Directrices 01/2020 (v2.0), «tratamiento local»; AEPD, Guía de Privacidad desde el Diseño (2019).])

#decision("PD-02", "Sin geocodificador ni búsqueda en servidores de terceros",
  [La búsqueda de lugares usa un índice local de paradas y estaciones; el usuario puede pulsar en el
  mapa o usar su ubicación. No se envía texto de búsqueda a terceros.],
  basis: [Art. 5.1.c y 25.2 RGPD; se evitan comunicaciones y transferencias innecesarias (arts. 28 y 44).
  Estrategia AEPD *minimizar*.],
  source: [AEPD, Guía de Protección de Datos por Defecto (2020), «cantidad de datos» y «accesibilidad».])

#decision("PD-03", "Sin cookies, sin almacenamiento local, sin analítica",
  [La aplicación no escribe cookies, `localStorage` ni IndexedDB y no integra analítica. No se requiere
  banner de consentimiento porque no hay acceso no exento al terminal.],
  basis: [Art. 22.2 LSSI; art. 25.2 RGPD (por defecto solo los datos necesarios).],
  source: [EDPB, Directrices 2/2023 sobre el alcance técnico del art. 5.3 ePrivacy (v2.0); AEPD, Guía sobre el uso de las cookies (2023).])

#decision("PD-04", "Geolocalización opcional, a petición, de baja precisión y efímera",
  [Solo se solicita al pulsar «Usar mi ubicación»; `enableHighAccuracy: false`; el valor se usa como
  origen y no se guarda. El acceso al terminal está exento de consentimiento LSSI por ser estrictamente
  necesario para el servicio expresamente solicitado; el navegador pide permiso igualmente.],
  basis: [Art. 25.2 RGPD (extensión del tratamiento y conservación por defecto); art. 22.2 LSSI (excepción de servicio solicitado).],
  source: [AEPD, Guía de Protección de Datos por Defecto (2020); EDPB 01/2020 (datos de localización).])

#decision("PD-05", "Recursos autoalojados (tipografías)",
  [Las tipografías se sirven desde el propio sitio, no desde CDNs de terceros, para no comunicar la
  IP del visitante a terceros sin necesidad.],
  basis: [Arts. 5.1.c, 25.2 y 44 RGPD.],
  source: [AEPD, Guía de Protección de Datos por Defecto (2020), «accesibilidad».])

#decision("PD-06", "Información por capas",
  [Primera capa visible en todas las pantallas (qué no se trata y con quién se comparte técnicamente);
  segunda capa completa en la pestaña «Privacidad».],
  basis: [Art. 11 LOPDGDD; arts. 12–13 RGPD. Estrategia AEPD *informar*.],
  source: [AEPD, Guía para el cumplimiento del deber de informar.])

#decision("PD-07", "Datos de técnicos: mínimos y con finalidad cerrada",
  [Solo se usan la identidad de GitHub y las acciones sobre alertas. Las valoraciones de alertas miden
  la *calidad de los umbrales*, no al técnico: queda prohibido su uso para evaluar el desempeño sin un
  proceso específico conforme a la LOPDGDD y al ET. Repositorio de operación privado (ver R5).],
  basis: [Art. 5.1.b (limitación de la finalidad) y 5.1.c RGPD; art. 88 RGPD; arts. 87–91 LOPDGDD.],
  source: [AEPD, La protección de datos en las relaciones laborales (2021).])

#decision("PD-08", "Intervención humana significativa",
  [El sistema no adopta decisiones con efectos jurídicos sobre personas: recomienda rutas (el usuario
  elige) y propone acciones operativas (el técnico decide). Los umbrales y la lógica son transparentes.],
  basis: [Art. 22 RGPD (no aplicable al no haber decisión basada únicamente en tratamiento automatizado con efectos significativos); art. 5.1.a (transparencia).],
  source: [GT29, WP251 rev.01 (refrendadas por el EDPB).])

#decision("PD-09", "Datos de entrada verificados como no personales",
  [GBFS, NO₂, tráfico y meteorología son agregados de infraestructura. No se usan los datos de
  viajes individuales de BiciMAD (2017–2023) aunque estén publicados anonimizados, por riesgo residual
  de reidentificación de trayectos.],
  basis: [Considerando 26 RGPD; art. 5.1.c.],
  source: [AEPD y SEPD, 10 malentendidos relacionados con la anonimización (2021).])

#decision("PD-10", "Conservación mínima",
  [Instantáneas GBFS: 7 días (rotación automática en CI). Registros de alertas: sin datos personales.
  Issues de alerta: cierre a los 90 días de resolverse; revisión anual del repositorio de operación.],
  basis: [Art. 5.1.e RGPD (limitación del plazo de conservación); art. 25.2.],
  source: [AEPD, Guía de Protección de Datos por Defecto (2020), «periodo de conservación».])

#decision("PD-11", "Seguridad del tratamiento",
  [CSP `connect-src 'self'` (impide exfiltrar datos a dominios no autorizados aunque se comprometa una
  dependencia), HTTPS, `referrer: no-referrer`, tokens de CI con permisos mínimos, CodeQL, Dependabot,
  auditoría de dependencias y SBOM. Detalle en AURA-DOC-05.],
  basis: [Art. 32 RGPD; art. 25.1 (estado de la técnica).],
  source: [EDPB, Directrices 4/2019; Real Decreto 311/2022 (ENS) si el responsable es del sector público.])

#decision("PD-12", "Evolución con cuentas: seudonimización y separación",
  [Si se añaden cuentas o favoritos en servidor (modo B2G), los identificadores se seudonimizarán con
  clave separada, los trayectos se guardarán solo con consentimiento y con generalización espacial
  (celdas ≥ 250 m), y se repetirá la EIPD antes de la puesta en producción.],
  basis: [Arts. 4.5, 25 y 32.1.a RGPD; art. 35.1 (EIPD previa).],
  source: [EDPB, Directrices 01/2025 sobre seudonimización.])

= Registro de actividades de tratamiento (art. 30 RGPD; art. 31 LOPDGDD)
#brand-table(
  columns: (1fr, 1.6fr, 1.6fr, 1.4fr),
  header: ("Campo", "T1 · Servicio web", "T2 · Gestión de alertas", "T3 · Notificaciones de seguridad"),
  [Responsable / DPD], [Entidad que despliega el piloto / DPD de la entidad], [Ídem], [Ídem],
  [Finalidad], [Servir la web y el mapa; seguridad], [Trazabilidad de decisiones; calidad de umbrales], [Corregir vulnerabilidades],
  [Interesados], [Visitantes], [Técnicos de operación, revisores], [Informantes],
  [Categorías de datos], [IP, user-agent, teselas solicitadas], [Usuario y nombre GitHub, acciones, comentarios, valoraciones, marcas temporales], [Identidad y contacto, contenido del informe],
  [Destinatarios / encargados], [GitHub Inc. (alojamiento), proveedor de teselas], [GitHub Inc.], [GitHub Inc.],
  [Transferencias internacionales], [EE. UU.: Marco de Privacidad de Datos UE-EE. UU. (Decisión de adecuación C(2023) 4745) y/o cláusulas contractuales tipo], [Ídem], [Ídem],
  [Plazo de supresión], [Según proveedor (documentar en el contrato)], [90 días tras cierre de la Issue; revisión anual], [Cierre + 1 año],
  [Medidas de seguridad], [HTTPS, CSP, sin cookies], [Repositorio privado, 2FA obligatoria, CODEOWNERS, ramas protegidas], [Avisos privados (Security Advisories)],
)
#src[Fuentes: RGPD arts. 28, 30 y 45–46; LOPDGDD art. 31; Decisión de Ejecución (UE) 2023/1795 de la Comisión, de 10 de julio de 2023 (C(2023) 4745).]

= Análisis de la necesidad de EIPD
La AEPD indica que, en la mayoría de los casos, procede una EIPD cuando el tratamiento cumple *dos o
más* criterios de su lista del art. 35.4.

#brand-table(
  columns: (2.4fr, 1fr, 1fr, 1.2fr),
  header: ("Criterio AEPD (art. 35.4)", "MVP (static-first)", "T2 técnicos", "Evolución B2G con cuentas"),
  [1. Perfilado o valoración de sujetos], [No], [No (finalidad cerrada, PD-07)], [Posible (preferencias)],
  [2. Decisiones automatizadas], [No (PD-08)], [No], [No],
  [3. Observación o geolocalización sistemática; identificadores únicos], [No (O/D no salen del dispositivo)], [No], [*Sí* (historial de trayectos)],
  [4–6. Categorías especiales, biometría, genética], [No], [No], [No],
  [7. Gran escala (WP243)], [Potencialmente (visitantes), pero solo IP en alojamiento], [No], [*Sí* (área metropolitana)],
  [8. Combinación de conjuntos de datos], [No (fusión de datos *no personales*)], [No], [Posible],
  [9. Sujetos vulnerables (p. ej. menores de 14)], [No se recogen datos], [No], [Posible],
  [10. Nuevas tecnologías / uso innovador], [Sí (ML, fusión), sin datos personales], [No], [*Sí*],
  [11. Impide ejercer derechos], [No], [No], [No],
  [*Total*], [*≤ 1*], [*0*], [*≥ 3*],
)

#callout(kind: "ok", title: "Conclusión")[
  El MVP *no está obligado* a realizar EIPD (≤ 1 criterio). Sin embargo: (a) el análisis de riesgos
  es obligatorio en todo caso (arts. 24 y 32 RGPD; art. 28 LOPDGDD); y (b) la evolución prevista
  (modo B2G con cuentas) cumpliría tres o más criterios. Por responsabilidad proactiva se elabora
  *ahora* una EIPD que cubre el sistema y su evolución, para que el diseño futuro herede las medidas.
]
#src[Fuentes: AEPD, Listas de tipos de tratamientos de datos que requieren EIPD (art. 35.4); GT29 WP248 rev.01; GT29 WP243 rev.01 (gran escala); RGPD arts. 24, 32 y 35.]

= Evaluación de impacto (metodología AEPD 2021)
== Descripción sistemática del tratamiento
#fig(
  diagram(
    spacing: (12mm, 9mm),
    edge-stroke: 0.6pt + tf.grey6,
    n-person((0, 0), wt[Usuario], name: <u>),
    n-box((1.5, 0), [Navegador: O/D, hora,\ ubicación (memoria)], name: <b>),
    n-box((3, 0), [Worker: McRAPTOR\ + fusión], name: <w>),
    n-box((4.5, 0), [Resultado en pantalla\ (se descarta al cerrar)], name: <r>),
    n-ext((1.5, 1.3), [GitHub Pages\ (IP, user-agent)], name: <gh>),
    n-ext((3, 1.3), [Teselas de mapa\ (IP, zona visible)], name: <t>),
    n-person((0, 2.4), wt[Técnico], name: <tec>),
    n-store((1.5, 2.4), [Repositorio de operación\ (privado): Issues, PR], name: <ops>),
    edge(<u>, <b>, "-|>"), edge(<b>, <w>, "-|>", [postMessage]), edge(<w>, <r>, "-|>"),
    edge(<b>, <gh>, "-|>", [descarga web/datos]), edge(<b>, <t>, "-|>", [teselas]),
    edge(<tec>, <ops>, "-|>", [decide / valora]),
  ),
  [Ciclo de vida de los datos. Las flechas hacia proveedores no transportan O/D.],
)

== Necesidad y proporcionalidad
#brand-table(
  columns: (1fr, 3fr),
  header: ("Juicio", "Valoración"),
  [Idoneidad], [Calcular rutas exige conocer O/D; hacerlo en el dispositivo cumple la finalidad sin que el responsable acceda a ellos.],
  [Necesidad], [No existe alternativa menos intrusiva: el responsable no trata O/D. La IP es inherente a servir una web.],
  [Proporcionalidad estricta], [Beneficio (movilidad sostenible, información de fiabilidad) frente a una injerencia mínima (IP en alojamiento y teselas).],
)

== Escalas
Probabilidad: *1* improbable · *2* posible · *3* probable · *4* casi seguro. Impacto: *1* limitado ·
*2* significativo · *3* grave · *4* muy grave. Riesgo = P × I: *1–3* bajo · *4–6* medio · *8–9* alto · *12–16* muy alto.

#let lvl(v) = {
  let (c, t) = if v <= 3 { (tf.green, "Bajo") } else if v <= 6 { (rgb("#A7863E"), "Medio") } else if v <= 9 { (tf.coral60, "Alto") } else { (rgb("#843C34"), "Muy alto") }
  text(fill: c, weight: 700)[#v · #t]
}

== Riesgos identificados, medidas y riesgo residual
#brand-table(
  columns: (0.35fr, 1.7fr, 0.3fr, 0.3fr, 0.7fr, 2fr, 0.3fr, 0.3fr, 0.7fr),
  size: 7.5pt,
  header: ("ID", "Riesgo", "P", "I", "Inherente", "Medidas", "P", "I", "Residual"),
  [R1], [Reidentificación y perfilado por almacenamiento de O/D y ubicación], [3], [4], lvl(12), [PD-01, PD-02, PD-04: O/D nunca salen del dispositivo; test e2e de red], [1], [4], lvl(4),
  [R2], [El proveedor de teselas infiere la zona del viaje (el mapa se ajusta a la ruta)], [3], [2], lvl(6), [Plan: autoalojar teselas vectoriales de Madrid (PMTiles) en el mismo origen; hasta entonces, informado en la segunda capa], [1], [2], lvl(2),
  [R3], [Registro de IP por el alojamiento y transferencia a EE. UU.], [4], [1], lvl(4), [Contrato de encargo/DPA; DPF o CCT; sin cookies ni analítica; PD-05], [3], [1], lvl(3),
  [R4], [Uso de la actividad de técnicos para evaluar su desempeño (desviación de finalidad)], [2], [3], lvl(6), [PD-07; política interna; información a técnicos y representación legal (art. 87.3 LOPDGDD)], [1], [3], lvl(3),
  [R5], [Exposición pública de identidades de técnicos y detalles operativos en Issues], [3], [2], lvl(6), [Issues en repositorio de operación privado; 2FA; mínimos privilegios], [1], [2], lvl(2),
  [R6], [Dependencia comprometida que exfiltre O/D (cadena de suministro)], [2], [4], lvl(8), [CSP `connect-src 'self'`; lockfiles; Dependabot; CodeQL; `npm audit`/`pip-audit`; SBOM], [1], [4], lvl(4),
  [R7], [Datos de fuente manipulados → recomendaciones erróneas (integridad)], [2], [2], lvl(4), [Validación de parsers; umbrales de frescura; confianza decreciente; decisión humana], [1], [2], lvl(2),
  [R8], [Menores u otros colectivos vulnerables usan la app], [3], [1], lvl(3), [No se recogen datos; información clara], [3], [1], lvl(3),
  [R9], [Falta de transparencia sobre la lógica de recomendación], [2], [2], lvl(4), [Explicación por factores con fuente y confianza; documentación pública], [1], [2], lvl(2),
  [R10], [Evolución B2G: historial de trayectos y cuentas], [3], [4], lvl(12), [PD-12: seudonimización, consentimiento, generalización espacial, nueva EIPD previa], [2], [3], lvl(6),
)

#callout(kind: "ok", title: "Resultado de la EIPD")[
  Para el MVP, todos los riesgos residuales son *bajos o medios* y no se requiere consulta previa a
  la AEPD (art. 36 RGPD). El riesgo R10 (evolución B2G) queda en *medio* con las medidas previstas y
  obliga a revisar esta EIPD antes de habilitar cuentas. Medida prioritaria pendiente: *autoalojar
  las teselas* (R2).
]

== Plan de acción
#brand-table(
  columns: (0.4fr, 2.5fr, 1fr, 1fr),
  header: ("#", "Acción", "Responsable", "Plazo"),
  [1], [Autoalojar teselas vectoriales (PMTiles) del área de Madrid en Pages], [Plataforma], [Antes del piloto abierto],
  [2], [Firmar DPA con el proveedor de alojamiento y documentar transferencias], [Responsable / DPD], [Antes del piloto],
  [3], [Crear repositorio de operación privado para Issues; 2FA obligatoria], [Plataforma], [Antes del piloto],
  [4], [Informar a técnicos y representación legal de PD-07 (art. 87.3 LOPDGDD)], [RR. HH. / DPD], [Antes del piloto],
  [5], [Prueba automatizada de "cero O/D en red" en CI (Playwright)], [Desarrollo], [Iteración siguiente],
  [6], [Revisión de esta EIPD ante cualquier cambio de arquitectura o anualmente], [DPD], [Continuo],
)

= Reglamento de IA
El componente de ML (previsión de demanda y disponibilidad) no está en los usos de alto riesgo
del anexo III del Reglamento (UE) 2024/1689 (no es infraestructura crítica de seguridad, ni afecta
al acceso a servicios esenciales ni evalúa personas). Se aplican de forma voluntaria buenas prácticas
de transparencia (model card, AURA-DOC-03) y la obligación de alfabetización en IA del personal (art. 4).

= Fuentes consultadas
#set text(size: 8.5pt)
- Reglamento (UE) 2016/679 (RGPD). DOUE L 119, 4/5/2016. eur-lex.europa.eu/eli/reg/2016/679/oj
- Ley Orgánica 3/2018, de Protección de Datos Personales y garantía de los derechos digitales. BOE-A-2018-16673.
- Ley 34/2002 (LSSI), art. 22.2. BOE-A-2002-13758.
- Real Decreto Legislativo 2/2015, Estatuto de los Trabajadores, arts. 20.3 y 20 bis. BOE-A-2015-11430.
- Real Decreto 311/2022, Esquema Nacional de Seguridad. BOE-A-2022-7191.
- Reglamento (UE) 2024/1689 (Reglamento de Inteligencia Artificial). eur-lex.europa.eu/eli/reg/2024/1689/oj
- STJUE de 19 de octubre de 2016, C-582/14, Breyer.
- Decisión de Ejecución (UE) 2023/1795 (Marco de Privacidad de Datos UE-EE. UU.).
- EDPB, Guidelines 4/2019 on Article 25 Data Protection by Design and by Default, v2.0 (20/10/2020). edpb.europa.eu
- EDPB, Guidelines 01/2020 on processing personal data in the context of connected vehicles and mobility related applications, v2.0 (09/03/2021).
- EDPB, Guidelines 2/2023 on Technical Scope of Art. 5(3) of ePrivacy Directive, v2.0 (2024).
- EDPB, Guidelines 01/2025 on Pseudonymisation (16/01/2025).
- Grupo de Trabajo del Artículo 29, WP248 rev.01 (EIPD), WP251 rev.01 (decisiones automatizadas) y WP243 rev.01 (DPD).
- AEPD, Listas de tipos de tratamientos de datos que requieren evaluación de impacto (art. 35.4). aepd.es/documento/listas-dpia-es-35-4.pdf
- AEPD, Guía de Privacidad desde el Diseño (2019). aepd.es
- AEPD, Guía de Protección de Datos por Defecto (2020). aepd.es
- AEPD, Gestión del riesgo y evaluación de impacto en tratamientos de datos personales (2021). aepd.es
- AEPD, Guía para el cumplimiento del deber de informar. aepd.es
- AEPD, La protección de datos en las relaciones laborales (2021). aepd.es
- AEPD, Guía sobre el uso de las cookies (2023). aepd.es
- AEPD y SEPD, 10 malentendidos relacionados con la anonimización (2021). aepd.es
