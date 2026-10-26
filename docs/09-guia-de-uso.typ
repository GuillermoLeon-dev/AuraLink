#import "template/corporativa.typ": *

#show: doc.with(
  title: "Guía de uso",
  subtitle: "Tutorial paso a paso: planificar un viaje, leer los resultados y usar la consola técnica",
  code: "AURA-DOC-09",
  version: "1.0",
)

// Paso numerado del tutorial
#let paso(n, titulo, body) = block(width: 100%, above: 14pt, below: 8pt, breakable: true)[
  #grid(columns: (26pt, 1fr), column-gutter: 10pt,
    box(width: 26pt, height: 26pt, radius: 13pt, fill: tf.blue, align(center + horizon, text(fill: white, weight: 800, str(n)))),
    [#text(size: 12pt, weight: 700, fill: tf.navy, titulo) \ #body],
  )
]
#let captura(path, caption, width: 100%) = fig(image(path, width: width), caption)

= Control de versiones
#version-table(
  ("1.0", "27/10/2026", "Equipo Aura Link", "Primera versión del tutorial con capturas reales de la aplicación."),
)

= Antes de empezar
#grid(columns: (1fr, 1fr, 1fr), gutter: 8pt,
  kpi("Navegador", "Chrome, Edge, Firefox o Safari actualizados"),
  kpi("Sin registro", "no hay cuentas ni contraseñas", color: tf.green),
  kpi("Madrid", "Metro, Metro Ligero, bus EMT y BiciMAD", color: tf.blue70),
)
#v(6pt)
Abra la aplicación en su navegador:
#align(center, text(size: 12pt, weight: 700, fill: tf.blue70)[https://guillermoleon-dev.github.io/AuraLink/])

#callout(kind: "ok", title: "Su viaje no sale de su dispositivo")[
  Aura Link calcula las rutas dentro de su navegador. El origen, el destino y su ubicación no se
  envían a ningún servidor ni se guardan. Detalle en AURA-DOC-06.
]

= Tutorial 1 · Planificar un viaje
En este ejemplo iremos de *Sol* a *Ciudad Universitaria* a las 08:30.

#paso(1, "Abra la aplicación")[
  Verá el panel de búsqueda a la izquierda y el mapa de Madrid a la derecha. Arriba están las
  pestañas *Planificar*, *Consola técnica*, *Documentación* y *Privacidad*.
]
#captura("img/guia/01-inicio.jpg", [Pantalla inicial.])

#paso(2, "Indique origen y destino")[
  Tiene tres formas de hacerlo, combinables:
  - *Escribir* en «Origen» y «Destino» el nombre de una parada o estación (por ejemplo «Sol») y
    elegirla de la lista que aparece. La búsqueda funciona sin conexión a terceros.
  - *Pulsar en el mapa*: el primer clic fija el origen (marcador verde *A*) y el segundo, el
    destino (marcador rojo *B*). Un tercer clic empieza de nuevo.
  - *Usar mi ubicación*: el navegador le pedirá permiso; la ubicación solo se usa en su dispositivo.
]
#paso(3, "Elija la hora y el tipo de billete")[
  - *Salida*: hora a la que quiere salir. Los horarios corresponden a un día laborable tipo.
  - *Billete*: «Billete sencillo», «Metrobús 10 viajes» o «Abono transporte». Cambia el coste
    calculado (con abono, el transporte público cuesta 0 € adicionales).
]
#captura("img/guia/02-origen-destino.jpg", [Origen, destino, hora y billete rellenados.], width: 55%)

#paso(4, "Pulse «Buscar rutas»")[
  En una fracción de segundo aparecen las alternativas. Encima de ellas verá cuántas hay y cuánto
  ha tardado el cálculo. La ruta seleccionada se dibuja en el mapa con el color de cada línea; los
  tramos a pie aparecen punteados.
]
#captura("img/guia/03-resultados.jpg", [Alternativas calculadas y la primera dibujada en el mapa.])

= Tutorial 2 · Entender los resultados
Aura Link no muestra una única «mejor ruta»: muestra las alternativas que *no son peores en todo*
que otra (frente de Pareto). Cada una gana en algo: tiempo, precio o emisiones.

#paso(5, "Lea una tarjeta")[
  Pulse una tarjeta para verla en el mapa y desplegar su detalle.
]
#grid(columns: (1fr, 1.15fr), gutter: 12pt, align: horizon,
  captura("img/guia/04-tarjeta.jpg", [Tarjeta desplegada.]),
  brand-table(
    columns: (0.9fr, 2fr),
    header: ("Elemento", "Significado"),
    [Horas y minutos], [Salida, llegada y duración del viaje.],
    [Etiquetas de colores], [Modos y líneas usados, en orden (p. ej. Metro 1 → Metro 4 → Metro 6).],
    [Coste], [Precio según el billete elegido.],
    [Emisiones], [Gramos de CO₂ equivalente del viaje.],
    [Fiabilidad], [Probabilidad de hacer el viaje como está planificado. Verde ≥ 80 %, ámbar ≥ 50 %, rojo < 50 %.],
    [Esperado], [Duración realista: suma los posibles contratiempos (no encontrar bici, tráfico).],
    [Insignias], [«Más rápida», «Más barata», «Menos CO₂», «Más fiable», ahorro frente al coche y avisos como «Bici poco fiable».],
    [Tramos], [Cada paso con su hora, línea, paradas y duración.],
  ),
)

#paso(6, "Lea el apartado «Por qué (fusión de datos)»")[
  Aparece cuando algo afecta a la ruta: disponibilidad de BiciMAD, lluvia, temperatura, viento,
  calidad del aire o tráfico. Cada línea indica la fuente y la *confianza* del dato (baja si el dato
  es antiguo). Así sabe por qué una opción está más abajo en la lista.
]

#paso(7, "Cambie la prioridad")[
  Los botones *Equilibrada*, *Más rápida*, *Más barata* y *Más verde* reordenan las alternativas al
  instante, sin volver a buscar. En la captura, con «Más verde» la bici pública pasa al primer puesto
  (0 g de CO₂), pero aparece marcada como «Bici poco fiable» porque la probabilidad de encontrar
  bici en la estación de salida es baja.
]
#captura("img/guia/05-mas-verde.jpg", [Prioridad «Más verde»: la alternativa en BiciMAD sube al primer puesto.])

#paso(8, "Consulte las estaciones de BiciMAD")[
  Active la casilla *Estaciones BiciMAD* (arriba a la izquierda del mapa) para ver la probabilidad
  de encontrar bici en cada estación dentro de 30 minutos.
]
#captura("img/guia/06-estaciones.jpg", [Mapa de estaciones con su probabilidad de bici.])
#brand-table(
  columns: (0.6fr, 2fr),
  header: ("Color", "Probabilidad de encontrar bici en 30 min"),
  text(fill: tf.green, weight: 700)[● Verde], [60 % o más],
  text(fill: rgb("#A7863E"), weight: 700)[● Ámbar], [entre 30 % y 60 %],
  text(fill: tf.coral60, weight: 700)[● Rojo], [menos de 30 %],
  text(fill: tf.grey5, weight: 700)[● Gris], [sin datos],
)

= Tutorial 3 · Consola técnica (personal de operación)
#callout(kind: "warn", title: "La consola no cambia nada")[
  Es de solo lectura. El sistema *propone*; el técnico *decide* en GitHub. Cualquier cambio de
  umbral o exclusión de estaciones se hace con una Pull Request revisada (AURA-DOC-04).
]

#paso(9, "Revise el estado de las fuentes y las alertas")[
  Abra la pestaña *Consola técnica*. Verá:
  - *Fuentes de datos*: si BiciMAD, meteorología, calidad del aire y tráfico están al día, y la
    confianza que la fusión les asigna.
  - *Alertas*: indicadores que superan su umbral, con la evidencia y una *acción sugerida* que no se
    aplica sola. Si el repositorio está configurado, el botón *Decidir en la Issue* lleva a GitHub.
  - *Umbrales vigentes*: valor de cada umbral y si genera un aviso al usuario o una alerta al técnico.
  - *Previsión de demanda* de BiciMAD para los próximos días, con su intervalo, y la *deriva de datos* (PSI).
]
#captura("img/guia/07-consola.jpg", [Consola técnica: fuentes, alertas y umbrales.])

#paso(10, "Pruebe un umbral con el simulador")[
  En «Simulador “qué pasaría si”», mueva el control para ver cuántas estaciones quedarían por
  debajo del umbral y si se generaría una alerta. No modifica nada: sirve para decidir antes de
  proponer el cambio.
]
#captura("img/guia/08-simulador.jpg", [Simulador de umbrales.], width: 60%)

#paso(11, "Cómo decide el técnico")[
  + En GitHub, abra la Issue de la alerta.
  + Si la alerta no procede, márquela con la etiqueta `decision:rechazar` (y `valoracion:falso-positivo`).
  + Si procede, márquela con `decision:aprobar` y abra una Pull Request que modifique
    `config/overrides.yaml` (p. ej. excluir una estación) o `config/thresholds.yaml` (cambiar un umbral).
  + Cuando la Pull Request se aprueba y se fusiona, la web se actualiza en el siguiente despliegue.
]

= Documentación y privacidad
#paso(12, "Consulte la documentación")[
  La pestaña *Documentación* enlaza todos los documentos del proyecto (AURA-DOC-00 a 09). Cada uno
  se abre en una pestaña nueva con el visor de PDF del navegador.
]
#captura("img/guia/09-documentacion.jpg", [Pestaña Documentación.])

#paso(13, "Infórmese sobre sus datos")[
  La franja inferior resume qué no se trata. La pestaña *Privacidad* contiene la información
  completa (responsable, terceros técnicos, derechos y cómo reclamar ante la AEPD).
]

= Preguntas frecuentes
#brand-table(
  columns: (1.2fr, 2.4fr),
  header: ("Pregunta", "Respuesta"),
  [No aparece ninguna alternativa], [Pruebe otra hora (de madrugada hay poco servicio) o puntos más cercanos a una parada. El cálculo considera tramos a pie de hasta 1 km para llegar a la red.],
  [¿Por qué la bici sale «poco fiable»?], [El modelo prevé que la estación de recogida o la de devolución puede estar vacía o llena al llegar. Mire el apartado «Por qué».],
  [¿Los horarios son en tiempo real?], [No. Son los horarios programados de un día laborable tipo. La disponibilidad de BiciMAD, el tiempo, el aire y el tráfico sí se actualizan (cada 15 minutos).],
  [¿Por qué el coste cambia?], [Depende del billete elegido. Con billete sencillo, el Metro cuesta más según las estaciones recorridas; con abono, 0 €.],
  [¿Se guarda mi búsqueda?], [No. Al cerrar o recargar la página desaparece. No hay cookies ni analítica.],
  [El mapa no carga], [Compruebe su conexión: las teselas del mapa se descargan de OpenFreeMap. El cálculo de rutas funciona aunque el mapa tarde.],
)
