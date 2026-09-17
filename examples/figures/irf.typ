// Source of irf.svg, a stand-in for a plot exported from R, Stata or Julia.
//   typst compile examples/figures/irf.typ examples/figures/irf.svg

#set page(width: 460pt, height: 208pt, margin: 0pt, fill: none)
#set text(font: "Inter", size: 11pt, fill: rgb("#59636e"))

#let (x0, y0, w, h) = (44pt, 166pt, 406pt, 160pt)
#let quarters = 40
#let response(scale, decay, t) = scale * t * calc.exp(-t / decay)
#let peak = response(30, 9, 9)
#let point(scale, decay, t) = (
  x0 + w * t / quarters,
  y0 - h * 0.9 * response(scale, decay, t) / peak,
)
#let series(scale, decay, paint) = place(curve(
  stroke: (paint: paint, thickness: 2pt, cap: "round", join: "round"),
  curve.move(point(scale, decay, 0)),
  ..range(1, 4 * quarters + 1).map(i => curve.line(point(scale, decay, i / 4))),
))

// Axes and ticks.
#place(line(start: (x0, y0), end: (x0 + w, y0), stroke: 0.6pt + rgb("#818b98")))
#place(line(start: (x0, y0), end: (x0, y0 - h), stroke: 0.6pt + rgb("#818b98")))
#for q in (0, 10, 20, 30, 40) {
  let x = x0 + w * q / quarters
  place(line(start: (x, y0), end: (x, y0 + 4pt), stroke: 0.6pt + rgb("#818b98")))
  place(dx: x - 10pt, dy: y0 + 8pt, box(width: 20pt, align(center, str(q))))
}
#for (i, label) in ("0", "0.1", "0.2", "0.3").enumerate() {
  let y = y0 - h * 0.9 * i / 3
  place(line(start: (x0 - 4pt, y), end: (x0, y), stroke: 0.6pt + rgb("#818b98")))
  place(dx: x0 - 34pt, dy: y - 5pt, box(width: 26pt, align(right, label)))
}
#place(dx: x0 + w - 200pt, dy: y0 + 23pt, box(width: 200pt, align(right)[Quarters after the shock]))

#series(38, 7, rgb("#818b98"))
#series(30, 9, rgb("#1a5fb4"))

// Direct labels instead of a legend.
#place(dx: x0 + w * 0.47, dy: y0 - h * 0.70, text(fill: rgb("#1a5fb4"), weight: 600)[HANK])
#place(dx: x0 + w * 0.17, dy: y0 - h * 0.24, text(fill: rgb("#59636e"), weight: 600)[Representative agent])
