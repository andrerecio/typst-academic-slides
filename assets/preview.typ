// README preview: six pages of the showcase deck on one sheet.
//
//   typst compile --root . examples/seminar.typ
//   typst compile --root . assets/preview.typ assets/preview.png --ppi 144
//
// The page numbers are PDF pages (subslides count), not slide numbers.

#let deck = "../examples/seminar.pdf"
#let pages = (1, 2, 12, 15, 16, 21)

#set page(width: 1200pt, height: auto, margin: 16pt, fill: rgb("#eaeef2"))

#grid(
  columns: 3,
  gutter: 16pt,
  ..pages.map(p => box(stroke: 0.5pt + rgb("#d1d9e0"), image(deck, page: p, width: 100%))),
)
