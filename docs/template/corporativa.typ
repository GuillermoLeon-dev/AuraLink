// Plantilla corporativa de Aura Link. Proyecto independiente, NO afiliado a Telefónica.
// Colores: estética inspirada en los tokens públicos del sistema de diseño Mística (licencia MIT),
//   https://www.npmjs.com/package/@telefonica/mistica  (skins/telefonica)
// Tipografía: Telefónica Sans es propietaria (derivada de TT Hoves, TypeType);
//   se usa Hanken Grotesk (SIL OFL) como alternativa libre más cercana.
// El rótulo es el nombre del proyecto; no se usa ninguna marca ni logotipo de terceros.

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// ---------- Tokens de marca ----------
#let tf = (
  blue: rgb("#0066FF"),
  blue10: rgb("#E5F0FF"),
  blue20: rgb("#B2D1FF"),
  blue30: rgb("#80B3FF"),
  blue70: rgb("#0356C9"),
  blue80: rgb("#002E73"),
  navy: rgb("#031A34"),
  grey1: rgb("#F7F7FF"),
  grey2: rgb("#D1D5E4"),
  grey3: rgb("#B0B6CA"),
  grey5: rgb("#6E7894"),
  grey6: rgb("#58617A"),
  grey8: rgb("#2B3447"),
  coral: rgb("#D6786B"),
  coral10: rgb("#F9EEED"),
  coral60: rgb("#D22A1E"),
  ambar: rgb("#EAC344"),
  ambar10: rgb("#FDF9EC"),
  turquoise: rgb("#75C0C7"),
  turquoise10: rgb("#EBFFFF"),
  turquoise70: rgb("#528889"),
  orchid: rgb("#B86BE8"),
  orchid10: rgb("#F8F0FD"),
  green: rgb("#00796B"),
  white: rgb("#FFFFFF"),
)

#let brand-font = ("Hanken Grotesk", "Arial")

// ---------- Componentes ----------

/// Rótulo tipográfico del proyecto.
#let wordmark(fill: tf.white, size: 16pt) = text(
  font: brand-font, weight: 800, size: size, fill: fill, tracking: -0.2pt,
)[Aura Link]

/// Tabla de versiones: el documento es iterativo y cada iteración queda registrada.
#let version-table(..rows) = {
  set par(justify: false)
  set text(size: 8.5pt)
  table(
    columns: (auto, auto, auto, 1fr),
    stroke: (x, y) => if y == 0 { none } else { (bottom: 0.4pt + tf.grey2) },
    fill: (x, y) => if y == 0 { tf.blue } else { none },
    inset: 6pt,
    table.header(..("Versión", "Fecha", "Autor", "Cambios").map(h => text(fill: white, weight: 700, h))),
    ..rows.pos().flatten(),
  )
}

/// Caja de aviso. kind: "info" | "warn" | "risk" | "ok" | "idea"
#let callout(kind: "info", title: none, body) = {
  let (bg, fg, label) = (
    info: (tf.blue10, tf.blue70, "Nota"),
    warn: (tf.ambar10, rgb("#69581F"), "Atención"),
    risk: (tf.coral10, tf.coral60, "Riesgo"),
    ok: (tf.turquoise10, tf.turquoise70, "Conclusión"),
    idea: (tf.orchid10, rgb("#7F258E"), "Innovación"),
  ).at(kind)
  block(
    width: 100%, fill: bg, inset: 10pt, radius: 4pt,
    stroke: (left: 3pt + fg), breakable: true,
  )[
    #text(weight: 700, fill: fg, if title == none { label } else { title })
    #v(-4pt)
    #body
  ]
}

/// Decisión de diseño con su fundamento normativo/técnico y la fuente consultada.
#let decision(id, title, body, basis: none, source: none) = block(
  width: 100%, inset: 10pt, radius: 4pt, breakable: true,
  stroke: 0.6pt + tf.blue30, fill: tf.grey1,
)[
  #text(weight: 700, fill: tf.blue)[#id · #title] \
  #body
  #if basis != none [
    #v(2pt)
    #text(size: 8.5pt, fill: tf.grey8)[*Fundamento:* #basis]
  ]
  #if source != none [
    \ #text(size: 8.5pt, fill: tf.grey6)[*Fuente:* #source]
  ]
]

/// Tarjeta de indicador.
#let kpi(value, label, color: tf.blue) = box(
  width: 100%, inset: 10pt, radius: 4pt, fill: tf.grey1, stroke: (top: 3pt + color),
)[
  #text(size: 18pt, weight: 800, fill: color, value) \
  #text(size: 8.5pt, fill: tf.grey6, label)
]

/// Tabla con el estilo de marca. `header` es un array de celdas de cabecera.
#let brand-table(columns: auto, header: (), size: 8.5pt, ..cells) = {
  set par(justify: false)
  set text(size: size)
  table(
    columns: columns,
    inset: 5.5pt,
    stroke: (x, y) => (bottom: 0.4pt + tf.grey2),
    fill: (x, y) => if y == 0 { tf.navy } else if calc.even(y) { tf.grey1 } else { none },
    table.header(..header.map(h => text(fill: white, weight: 700, h))),
    ..cells.pos(),
  )
}

// ---------- Estilos de diagrama (fletcher) ----------
#let n-sys(pos, body, name: none) = node(pos, body, name: name, fill: tf.blue, stroke: none,
  corner-radius: 4pt, inset: 8pt, shape: rect, extrude: (0,))
#let n-box(pos, body, name: none, fill: tf.blue10, stroke: 0.6pt + tf.blue) = node(
  pos, body, name: name, fill: fill, stroke: stroke, corner-radius: 4pt, inset: 7pt)
#let n-ext(pos, body, name: none) = node(pos, body, name: name, fill: tf.grey1,
  stroke: (paint: tf.grey5, dash: "dashed", thickness: 0.6pt), corner-radius: 4pt, inset: 7pt)
#let n-person(pos, body, name: none) = node(pos, body, name: name, fill: tf.navy,
  stroke: none, shape: fletcher.shapes.pill, inset: 8pt)
#let n-store(pos, body, name: none) = node(pos, body, name: name, fill: tf.turquoise10,
  stroke: 0.6pt + tf.turquoise70, shape: fletcher.shapes.cylinder, inset: 7pt)
#let n-alert(pos, body, name: none) = node(pos, body, name: name, fill: tf.coral10,
  stroke: 0.6pt + tf.coral60, shape: fletcher.shapes.hexagon, inset: 7pt)
#let wt(body) = text(fill: white, weight: 700, body)

/// Marco para diagramas con pie de figura.
#let fit(body) = layout(size => {
  let s = measure(body)
  if s.width > size.width {
    scale(size.width / s.width * 100%, reflow: true, body)
  } else { body }
})
#let fig(body, caption) = figure(
  block(width: 100%, inset: 10pt, radius: 4pt, stroke: 0.5pt + tf.grey2, align(center, fit(body))),
  caption: caption, kind: image,
)

// ---------- Documento ----------
#let doc(
  title: "",
  subtitle: "",
  code: "",
  version: "0.1",
  date: datetime.today(),
  status: "Borrador para revisión",
  classification: "Uso interno",
  body,
) = {
  set document(title: title, author: "Equipo Aura Link")
  set text(font: brand-font, size: 10pt, lang: "es", region: "es", fill: tf.navy)
  set par(justify: true, leading: 0.62em, spacing: 1em)
  set heading(numbering: "1.1")
  show heading: set text(fill: tf.blue, weight: 700)
  show heading.where(level: 1): it => {
    v(14pt, weak: true)
    block(text(size: 20pt, it))
    v(-6pt)
    line(length: 18%, stroke: 3pt + tf.blue)
    v(6pt)
  }
  show heading.where(level: 2): set text(size: 13pt)
  show heading.where(level: 3): set text(size: 11pt, fill: tf.blue70)
  show link: set text(fill: tf.blue70)
  show raw: set text(font: ("Cascadia Mono", "Consolas", "DejaVu Sans Mono"), size: 8.5pt)
  show raw.where(block: true): block.with(fill: tf.grey1, inset: 8pt, radius: 4pt, width: 100%)
  show figure.caption: set text(size: 8.5pt, fill: tf.grey6)
  set figure(supplement: "Figura")
  set list(marker: text(fill: tf.blue)[●])
  set enum(numbering: n => text(fill: tf.blue, weight: 700, str(n) + "."))

  // Portada
  page(margin: 0pt, fill: tf.blue, header: none, footer: none)[
    #place(top + right, dx: -0pt, dy: 0pt, circle(radius: 160pt, fill: tf.blue70))
    #place(bottom + left, dx: -80pt, dy: 80pt, circle(radius: 140pt, fill: tf.blue80))
    #pad(x: 56pt, y: 56pt)[
      #wordmark(size: 22pt)
      #v(1fr)
      #text(fill: tf.blue20, size: 11pt, weight: 500, upper(code))
      #v(4pt)
      #text(fill: white, size: 32pt, weight: 800, title)
      #v(6pt)
      #text(fill: white, size: 14pt, weight: 400, subtitle)
      #v(30pt)
      #line(length: 60pt, stroke: 2pt + white)
      #v(6pt)
      #text(fill: white, size: 10pt)[
        Proyecto *Aura Link* · Recomendador de rutas multimodales sostenibles \
        Versión #version · #date.display("[day]/[month]/[year]") · #status \
        Clasificación: #classification
      ]
      #v(1fr)
      #text(fill: tf.blue20, size: 7.5pt)[
        Proyecto independiente, no afiliado a Telefónica. Paleta inspirada en el sistema de diseño
        público Mística (licencia MIT) y tipografía Hanken Grotesk (OFL).
      ]
    ]
  ]

  set page(
    paper: "a4",
    margin: (x: 2.2cm, top: 2.4cm, bottom: 2.2cm),
    header: context {
      set text(size: 8pt, fill: tf.grey5)
      grid(columns: (1fr, auto), align: (left, right),
        wordmark(fill: tf.blue, size: 10pt), [#code · #title])
      v(-4pt)
      line(length: 100%, stroke: 0.5pt + tf.grey2)
    },
    footer: context {
      set text(size: 8pt, fill: tf.grey5)
      line(length: 100%, stroke: 0.5pt + tf.grey2)
      v(-4pt)
      grid(columns: (1fr, auto), align: (left, right),
        [#classification · v#version],
        text(fill: tf.blue, weight: 700, counter(page).display("1")))
    },
  )
  counter(page).update(1)

  outline(title: text(fill: tf.blue)[Índice], depth: 2, indent: auto)
  pagebreak()
  body
}

/// Gráfico de barras horizontales nativo (sin dependencias). items: array de (etiqueta, valor).
#let hbars(items, unit: "", max: none, color: tf.blue, width: 9cm, label-width: 5.2cm, fmt: v => str(calc.round(v, digits: 1))) = {
  let m = if max == none { calc.max(..items.map(i => i.at(1))) } else { max }
  set text(size: 8.5pt)
  grid(
    columns: (label-width, width, auto),
    column-gutter: 6pt, row-gutter: 4pt, align: (right + horizon, left + horizon, left + horizon),
    ..items.map(((l, v)) => (
      l,
      box(width: if m > 0 { v / m * width } else { 0pt }, height: 9pt, fill: color, radius: 2pt),
      text(fill: tf.grey6)[#fmt(v)#unit],
    )).flatten()
  )
}

/// Barras agrupadas verticales para comparar series (p. ej. MAE por fold).
#let grouped-bars(categories, series, height: 4.2cm, unit: "") = {
  // series: array de (nombre, color, valores)
  let m = calc.max(..series.map(s => calc.max(..s.at(2))))
  set text(size: 7.5pt)
  let bars-for(i) = series.map(((_, c, vals)) => box(width: 7pt, height: vals.at(i) / m * height, fill: c))
  block[
    #grid(
      columns: categories.len(), column-gutter: 10pt, align: bottom + center,
      ..categories.enumerate().map(((i, cat)) => stack(spacing: 3pt,
        box(height: height, align(bottom, stack(dir: ltr, spacing: 1pt, ..bars-for(i)))),
        cat)),
    )
    #v(4pt)
    #series.map(((n, c, _)) => box[#box(width: 8pt, height: 8pt, fill: c) #n]).join(h(12pt))
  ]
}
