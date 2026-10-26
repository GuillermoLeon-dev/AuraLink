#import "template/corporativa.typ": *

#show: doc.with(
  title: "Seguridad",
  subtitle: "Modelo de amenazas, controles y cadena de suministro",
  code: "AURA-DOC-05",
  version: "1.1",
)

= Control de versiones
#version-table(
  ("0.1", "26/10/2026", "Equipo Aura Link", "Superficie de ataque de la arquitectura cliente-servidor."),
  ("1.0", "26/10/2026", "Equipo Aura Link", "Arquitectura static-first: STRIDE, controles implementados, pruebas y plan."),
  ("1.1", "27/10/2026", "Equipo Aura Link", "Cambio de nombre a Aura Link; retirada de la marca Telefónica (proyecto no afiliado)."),
)

= Superficie y fronteras de confianza
La arquitectura static-first elimina la mayor parte de la superficie habitual: no hay API,
base de datos ni sesiones de usuario. Lo que queda: el navegador (código y datos descargados),
la cadena de suministro (dependencias, Actions), las fuentes de datos externas y GitHub
(permisos de quien decide).

#fig(
  diagram(
    spacing: (16mm, 9mm),
    edge-stroke: 0.6pt + tf.grey6,
    node((0, 0), text(size: 8pt, fill: tf.blue, weight: 700)[ZONA 1 · DISPOSITIVO], stroke: none),
    node((1.5, 0), text(size: 8pt, fill: tf.turquoise70, weight: 700)[ZONA 2 · GITHUB], stroke: none),
    node((3, 0), text(size: 8pt, fill: tf.grey6, weight: 700)[ZONA 3 · TERCEROS], stroke: none),
    n-box((0, 1), [SPA + Worker\ (O/D en memoria)], name: <spa>),
    n-box((0, 2), [Geolocalización\ (permiso del navegador)], name: <geo>, fill: tf.grey1, stroke: 0.6pt + tf.grey5),
    n-store((1.5, 1), [Pages\ (estáticos)], name: <pages>),
    n-box((1.5, 2), [Actions\ GITHUB_TOKEN mínimo], name: <act>),
    n-person((1.5, 3), wt[Técnico (2FA)], name: <tec>),
    n-ext((3, 1), [Teselas\ OpenFreeMap], name: <tiles>),
    n-ext((3, 2), [Datos abiertos\ GBFS · NO₂ · GTFS], name: <od>),
    n-alert((0, 3), [Cadena de\ suministro], name: <sc>),
    edge(<geo>, <spa>, "-|>"),
    edge(<pages>, <spa>, "-|>", [HTTPS + CSP], label-side: right),
    edge(<spa>, <tiles>, "-|>", bend: 30deg, [teselas (sin O/D)]),
    edge(<act>, <od>, "-|>", [TLS verificado], label-side: right),
    edge(<act>, <pages>, "-|>", [publica]),
    edge(<tec>, <act>, "-|>", [PR revisada], label-side: right),
    edge(<sc>, <act>, "--|>", stroke: 0.8pt + tf.coral60),
    edge(<sc>, <spa>, "--|>", stroke: 0.8pt + tf.coral60),
  ),
  [Fronteras de confianza. Las flechas discontinuas rojas son los vectores de ataque principales.],
)

= Modelo de amenazas (STRIDE)
#brand-table(
  columns: (0.35fr, 1.6fr, 2fr, 2.2fr),
  header: ("", "Amenaza", "Escenario", "Control"),
  [S], [Suplantación], [Un atacante publica un sitio clonado], [Dominio único de Pages documentado; HTTPS obligatorio; sin credenciales que robar.],
  [S], [Suplantación de técnico], [Robo de cuenta GitHub para aprobar cambios], [2FA obligatoria en la organización; CODEOWNERS; ramas protegidas con revisión.],
  [T], [Manipulación de datos de entrada], [Feed GBFS o tráfico alterado → rutas absurdas], [Parsers estrictos; descarte de puntos con error; umbrales de frescura; confianza decreciente; decisión humana ante anomalías.],
  [T], [Manipulación del artefacto publicado], [Commit malicioso en `main`], [Ramas protegidas, revisión obligatoria, CI verde requerido, historial firmado (recomendado).],
  [R], [Repudio de decisiones], ["Yo no aprobé esa exclusión"], [Issues, etiquetas, PR, revisiones y commits: registro inmutable de quién decidió qué.],
  [I], [Fuga de O/D], [Script de terceros exfiltra ubicación], [O/D nunca salen por diseño; CSP `connect-src 'self' tiles`; `script-src 'self'`; sin analítica.],
  [I], [Fuga de información operativa], [Issues públicas revelan estaciones problemáticas o identidades], [Repositorio de operación privado (AURA-DOC-06, R5).],
  [D], [Denegación de servicio], [Saturar el sitio], [CDN de GitHub Pages; sin backend que tumbar; la app funciona con datos cacheados.],
  [D], [Fuente de datos caída], [Sin GBFS], [Degradación elegante: confianza → 0, probabilidad → 0,5; alerta de frescura.],
  [E], [Elevación vía workflows], [`pull_request_target` o tokens amplios], [Permisos por workflow mínimos (`contents: read` salvo lo imprescindible); sin `pull_request_target`; acciones fijadas por versión mayor y Dependabot.],
)
#text(size: 8pt, fill: tf.grey6)[Fuente: Shostack, A. _Threat Modeling: Designing for Security_ (2014), STRIDE; OWASP Threat Modeling Cheat Sheet.]

= Controles implementados
#brand-table(
  columns: (1.2fr, 2.6fr, 1.2fr),
  header: ("Área", "Control", "Dónde"),
  [Navegador], [Content-Security-Policy restrictiva en producción (`default-src 'self'`, `script-src 'self'`, `connect-src 'self'` + teselas, `object-src 'none'`, `base-uri 'self'`)], [`web/vite.config.ts`],
  [Navegador], [`referrer: no-referrer`; sin cookies ni almacenamiento; peticiones con `credentials: 'omit'`], [`index.html`, `dataClient.ts`],
  [Navegador], [Sin `innerHTML` con datos externos; React escapa por defecto], [`web/src/ui`],
  [Transporte], [HTTPS (Pages); en el pipeline, verificación TLS con el almacén del sistema (`truststore`), nunca desactivada], [`context/sources.py`],
  [Entrada], [URLs de fuentes fijas en código (sin SSRF); parsers con tipos; XML de fuente oficial fija], [`fetch.py`, `sources.py`],
  [CI/CD], [Permisos mínimos por workflow; CodeQL (Python y TS); `pip-audit`; `npm audit`; SBOM CycloneDX; Dependabot (npm, uv, Actions)], [`.github/`],
  [Gobierno], [CODEOWNERS sobre `config/` y modelos; reentrenamiento solo por PR], [`.github/CODEOWNERS`],
  [Divulgación], [`SECURITY.md` con canal privado (Security Advisories)], [raíz],
  [Calidad], [TypeScript estricto, ESLint, mypy estricto, Ruff (incluye reglas de seguridad `S` de Bandit)], [CI],
)

= Verificación OWASP
#brand-table(
  columns: (1.6fr, 0.6fr, 2.4fr),
  header: ("OWASP Top 10 (2021)", "Aplica", "Situación"),
  [A01 Control de acceso roto], [Bajo], [No hay recursos protegidos en la web; el control de acceso está en GitHub (ramas protegidas, CODEOWNERS).],
  [A02 Fallos criptográficos], [Bajo], [Solo HTTPS gestionado; sin secretos en el cliente.],
  [A03 Inyección], [Bajo], [Sin backend ni consultas; React escapa salidas.],
  [A04 Diseño inseguro], [Medio], [Mitigado por diseño static-first y modelo de amenazas.],
  [A05 Configuración insegura], [Medio], [CSP, permisos mínimos; revisar configuración de Pages y organización.],
  [A06 Componentes vulnerables], [*Alto*], [Principal riesgo: Dependabot, auditorías, SBOM, CodeQL.],
  [A07 Identificación y autenticación], [Medio], [Delegada en GitHub con 2FA.],
  [A08 Integridad de software y datos], [*Alto*], [Lockfiles (`uv.lock`, `package-lock.json`), revisión de PR, acciones oficiales.],
  [A09 Registro y monitorización], [Medio], [Registro de alertas y decisiones en GitHub; `alerts_log.jsonl`.],
  [A10 SSRF], [Bajo], [Sin URLs controladas por usuarios.],
)
Para el modo B2G con servidor se aplicará OWASP ASVS 4.0.3 nivel 2 y, en sector público, las
medidas del ENS (Real Decreto 311/2022) de categoría media.

= Pruebas de seguridad y privacidad
#brand-table(
  columns: (0.5fr, 2.4fr, 1.2fr),
  header: ("ID", "Prueba", "Resultado"),
  [P-01], [Inspección de tráfico con un viaje real (Sol → Ciudad Universitaria): ninguna petición contiene coordenadas, texto de búsqueda ni hora], [Superada (26/10/2026)],
  [P-02], [Build de producción incluye CSP en `index.html`], [Superada],
  [P-03], [Pipeline con fuente caída: la fusión reduce confianza y genera alerta de frescura], [Superada (Open-Meteo con TLS fallido)],
  [P-04], [Tests unitarios de exclusión de estaciones por decisión del técnico], [Superada],
  [P-05], [Automatizar P-01 en CI con Playwright], [Pendiente (plan)],
)
