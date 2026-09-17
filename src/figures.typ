// Figure sizing. An unsized image is laid out at full width and overflows the
// slide, so a figure whose image has no explicit size instead takes the height
// left over by the rest of the slide, and the image scales to fit.

#import "@preview/touying:0.7.4": cols as _touying-cols
#import "tokens.typ": *

// Take the remaining height of the container, but report at least `min` to
// `measure`.
//
// Touying detects overfull slides by measuring the body at unbounded height,
// where a fraction counts as zero. A bare `1fr` block would make a figure-only
// slide look empty, and would let a figure be squeezed to nothing by too much
// text without any warning. So a strut of height `min` is measured, and at
// layout time the real content is moved up over it and made `min` taller, so
// the strut costs no space.
//
// The weight is 100fr so that a `#source` line (`v(1fr)`) on the same slide
// does not take half of the free space.
#let _fill(min, body) = {
  block(width: 100%, height: min, below: 0pt)
  block(width: 100%, height: 100fr, above: 0pt, move(
    dy: -min,
    block(width: 100%, height: 100% + min, body),
  ))
}

#let _is-auto-image(body) = (
  body.func() == image and not body.has("width") and not body.has("height")
)

// A grid of panels under one caption: `figure(grid(columns: 2, image(..), image(..)))`.
#let _is-auto-panel-grid(body) = body.func() == grid and not body.has("rows")

#let _is-auto-figure(it) = _is-auto-image(it.body) or _is-auto-panel-grid(it.body)

/// Show rule for `figure.where(kind: image)`.
#let fit-figure(it) = {
  if not _is-auto-figure(it) { return it }
  _fill(space.figure-min, grid(
    columns: 100%,
    rows: if it.caption == none { (1fr,) } else { (1fr, auto) },
    row-gutter: it.gap,
    align: center + horizon,
    {
      set image(height: 100%, fit: "contain")
      set grid(rows: 1fr)
      it.body
    },
    ..if it.caption != none { (it.caption,) },
  ))
}

// Whether content holds a figure that `fit-figure` will stretch. Looks through
// sequences and styled content only, which is what `#cols[..][..]` bodies are.
#let _holds-auto-figure(body) = {
  if body.func() == figure {
    _is-auto-figure(body)
  } else if body.has("children") {
    body.children.any(_holds-auto-figure)
  } else if body.has("child") {
    _holds-auto-figure(body.child)
  } else {
    false
  }
}

/// Columns. Touying's `cols`, except that when a column holds an auto-sized
/// figure the columns take the remaining slide height. Without that, the
/// figure's fractional height would claim the whole page inside an auto-height
/// row and push whatever follows the columns off the slide, unnoticed by the
/// overflow check. Extra named arguments go to `grid` (`align: horizon`, ..).
///
/// The fill has to happen at flow level (`_fill`), not with `rows: 1fr` alone:
/// a grid with a fractional row still claims the whole region for itself.
///
/// Limitation: such columns are measured as `figure-min` tall, so a text column
/// that is too long next to a figure is not caught by the overflow warning.
#let cols(..args) = {
  let named = args.named()
  if "rows" in named or not args.pos().any(_holds-auto-figure) {
    return _touying-cols(..named, ..args.pos())
  }
  _fill(space.figure-min, _touying-cols(rows: 1fr, ..named, ..args.pos()))
}
