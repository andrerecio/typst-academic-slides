# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`brownbag` (working name) is a Typst package: a minimal slide theme built on
[Touying](https://touying-typ.github.io) 0.7.4 for academic talks in economics
and econometrics. It is a theme, not a slide engine — slide mechanics, reveals,
counters, handouts and speaker notes all stay in Touying.

## Commands

```sh
# Build / watch the showcase deck (always from the repo root, with --root .)
typst compile --root . examples/seminar.typ
typst watch   --root . examples/seminar.typ

# Run regression checks (requires Python 3 and pypdf)
python3 -m unittest discover -s tests -v

# Render pages to PNG for visual review
typst compile --root . examples/seminar.typ "out/s-{0p}.png" --ppi 110
typst compile --root . --pages 9 examples/seminar.typ out/p9.png --ppi 400   # one page, zoomed

# README preview (embeds pages of examples/seminar.pdf, so compile the deck first;
# the page list in preview.typ is PDF pages and shifts when subslides are added)
typst compile --root . assets/preview.typ assets/preview.png --ppi 144
```

- `--root .` is required: examples import `../lib.typ`, which is outside their own directory.
- Inter, JetBrains Mono and STIX Two Math are required, never vendored or
  committed (`fonts/` is git-ignored; use `--font-path fonts` if they are not
  installed system-wide). Verify with
  `typst fonts | grep -E "^(Inter|JetBrains Mono|STIX Two Math)$"` — trust this
  over any installer's report. To preview the degraded look:
  `--ignore-system-fonts --font-path <dir containing only Arial>`.
- Run the regression suite, then compile `examples/seminar.typ` with zero
  warnings and look at the rendered pages. There is no linter yet.
  Low-ppi PNGs alias thin math strokes (braces look dashed); zoom before
  concluding a glyph is broken.
- To try theme options without touching the repo, keep a scratch `.typ`
  anywhere, import the absolute path of `lib.typ`, and compile with `--root /`.

## Architecture

`lib.typ` is the entire public surface. It imports named items from `src/` and
re-exports a curated list of Touying names so a deck needs one import line.
Typst re-exports whatever a module imports, so never `import "src/tokens.typ": *`
in `lib.typ` — token names such as `rule`, `ink`, `size`, `space` would leak
into user decks.

- `src/tokens.typ` — fonts, neutral colors, accent presets, type scale, spacing.
  Plain constants, sized for the 841.89 × 473.56 pt `presentation-16-9` page.
- `src/slides.typ` — slide functions. Each wraps `touying-slide-wrapper`, merges
  a `config-page(header:, footer:)` into `self`, and delegates to `touying-slide`.
  `title-slide` and `focus-slide` share `_bare` (no chrome, symmetric margins,
  frozen slide counter).
- `src/components.typ` — `muted`, `keypoint`, `source`, `goto`, and
  `accent-state`, the one piece of state in the package (see gotchas).
- Backup-slide navigation spans two files: `goto` (components) leaves a
  `metadata(str(target))<brownbag-goto>` marker next to its link; `_back-link`
  (slides, called from `_footer`) looks up the current `==` heading's label,
  queries the markers that name it, and links to the last subslide of the first
  slide that points here. There is no registry and no state.
- `src/statements.typ` — `assumption`, `proposition`, `proof`, … all built by
  the private `_statement(kind)` factory. Numbers are manual (`number:`); there
  are no counters, so nothing needs freezing across subslides.
- `src/theme.typ` — `brownbag-theme`: calls `touying-slides` with the `config-*`
  dictionaries; all global `set`/`show` rules live in `config-methods(init:)`.

How a deck becomes slides: the theme registers `slide-fn` and
`new-section-slide-fn` with `slide-level: 2`, so `= Section` produces a section
slide and `== Title` starts a content slide. The slide title is not body
content; `_header` renders it in the page's top margin via
`utils.display-current-heading(level: 2)`. Real page margins are used (not
`margin: 0` plus a padded frame) so the body is a true container and `v(1fr)`
and `align(horizon)` behave.

### Figure sizing (`src/figures.typ`)

`image(height:)` does not accept `fr`, and a bare `#figure(image(..))` is laid
out at full width and overflows. So `fit-figure` (a show rule on
`figure.where(kind: image)`) makes a figure whose image has no explicit size
take the slide's remaining height. Three constraints shaped it; do not simplify
them away:

- The fraction must be at **flow level**, i.e. the figure's own outer block. An
  `fr` block *inside* `figure`, or a `grid(rows: 1fr)`, claims the whole region
  and pushes following content off the slide with no warning. This is also why
  `cols` is wrapped: with an auto-figure inside, the columns go in `_fill`.
- Touying detects overflow with `measure` at unbounded height, where a fraction
  counts as **zero**. `_fill` therefore emits a strut of `space.figure-min` that
  is measured, and at layout time moves the real content up over it (`move` +
  `height: 100% + min`), so the strut costs no space. Result: a figure-only
  slide is not reported "empty", and a figure squeezed below `figure-min` by
  too much text does raise the overflow warning.
- Figures weigh `100fr` so that `#source` (`v(1fr)`) cannot take half the space.

Auto-sizing applies when `body` is an `image` without `width`/`height`
(checked with `has()`: unset fields cannot be read on an unresolved element),
or a `grid` without `rows` (panels under one caption). Figure detection also
looks through wrappers such as `align`, `block`, and `pad`. Caption order follows
`figure.caption(position:)`.

Columns keep the fractional fill at flow level. A labelled grid show rule runs
after Touying processes reveals and compares natural column heights (with auto
figures replaced by minimum-height placeholders) against the allocated height.
The measurements are stored in metadata and queried before emitting a warning:
only final-layout metadata is queryable, which avoids false warnings from the
temporary 150pt region used during Touying's overflow measurement. Warnings use
`uniwarn`, like Touying, with a `[brownbag]` prefix.

## Design rules

- **Config surface is `accent`, `aspect-ratio`, `footer`, `text-size`.** In-body
  sizes (`size.small`, `size.note`) are in `em` so that they follow `text-size`
  or a scoped `#set text`; keep new components relative too. Everything else is
  reached through the `..args` passthrough of Touying `config-*` dictionaries.
  Do not add theme options for things Touying already exposes.
- **One accent, on text only.** Containers, rules and table lines are neutral.
  Accent appears on labels, `#alert`, links and the section number.
  Titles (slide, section, deck, focus) are not the accent but `title-ink(accent)`
  in `tokens.typ`: the accent's hue at ink darkness (blue gives navy, `mono`
  stays ink), so `#alert` remains the brightest thing on a slide. Never set a
  title in the accent itself. Slide titles are bold (700) over a hairline rule.
  The one exception to "accent on text only" is `#highlight`, a warm
  highlighter-pen fill (`marker` in `tokens.typ`, after JambroBeamerTheme); it
  is never the accent. List bullets stay the quiet grey `•` / `–`.
- **Margins are moderate, not keynote-wide** (40pt sides, 78pt top, 40pt
  bottom): the body is about 68% of the page, because regression tables and
  figures need the room. Do not widen them back, and do not go edge-to-edge
  either. List items are spaced wider than the line leading (`item-spacing` in
  `theme.typ`) so a new bullet is told apart from a wrapped line.
- **`*strong*` is weight only.** Touying defaults `show-strong-with-alert` to
  true; the theme turns it off deliberately.
- **Style native elements first** (`figure`, `table`, `cite`, `list`,
  `math.equation`); add a function only where Typst has no element (e.g.
  "Assumption"). Prefer `== Title` + a component over new `*-slide` functions.
- No software/GitHub visual idioms: badges, pills, breadcrumbs, terminal chrome,
  progress bars, gradients, filled cards.

## Touying and Typst gotchas (verified here)

- **How components get the accent.** The source of truth is
  `config-colors(primary:)`. Slide functions read `self.colors.primary`
  directly. Components must *not* use `touying-fn-wrapper` to reach `self`: it
  works in `cols`/`block`/`grid`/`table` but panics ("Unsupported mark … inside
  context") in figure captions. The pattern used instead: `init` mirrors the
  accent into `accent-state`; a component wraps only a leaf (the label, the
  keypoint arrow) in `context`, and the user's body stays outside `context`,
  which keeps `#pause` working inside the component. Verified in `cols`, table
  cells and captions.
- **Slides are `breakable: false`.** An overfull slide stays on one page and
  Touying warns with the height excess (printed by Typst as an "unknown font
  family: [touying] detecting slide content overflow…" warning — that is how
  `uniwarn` emits it). With the default `breakable: true`, hidden `#pause`
  content overflows silently onto extra blank pages on every subslide. Opt out
  per slide with `#slide(config: config-common(breakable: true))[..]`.
- Overflow detection only measures in-flow content. Never `place` a component
  at the bottom of a slide; `source` uses `v(1fr)` so that it is measured.
- `v(1fr)` works in a slide body because the body is a fixed-height container.
- Content hidden by `#pause` is still in the document: a `metadata` marker is
  queryable on every subslide of its slide, including those where it is not yet
  revealed (but a hidden `link` produces no PDF annotation). A heading label
  such as `== Title <x>` exists once and resolves to the slide's first subslide.
- Inter's `tnum` feature widens hyphens as well as digits, so tabular figures
  are applied per `table.cell`, only when the cell's plain text matches
  `_numeric-cell` in `theme.typ`.
- A `table.cell` show rule that returns anything other than `it` loses the
  cell's inset and alignment; re-apply them (`pad` + `align`), as Typst's own
  cell rendering does. Numeric cells are rebuilt from their plain text this way
  because each escaped `\*` is a separate text node.
- A table that declares `table.hline(y: 0)` draws its own frame (tinytable /
  `modelsummary` output does); the theme then adds no outer rules. `table.footer`
  cannot be targeted by a show rule.
- `show math.equation: it => { show regex("\p{L}{2,}"): .. }` sets words in math
  in Inter, skipping the names in `_math-operators`. A custom `op("Var")` is
  therefore Inter too, like `"Var"`.
- A bare `#set text(..)` in a slide body is **not** confined to that slide under
  Touying; it affects every later slide. Scope it with `#[ .. ]`.
- `typst compile` zero-pads `{n}` in PNG names once there are 10+ pages.
- For reviewing many slides at once, build a contact sheet: a Typst file with
  `#grid(columns: 3, ..pages.map(p => image(p)))`, compiled to one PNG.
- R with `modelsummary`/`tinytable`/`fixest` is installed here; Stata is not.
- To check where PDF links really go, read the `/Link` annotations with `pypdf`
  (installed here); rendering PNGs cannot show it.
- `#pause`/`#meanwhile` cannot appear inside a `context` block.
- `config-info(author:)` must be a string or an array of strings when there are
  coauthors: Touying forwards it to `set document(author:)`, which rejects an
  array of content.
- Unrevealed content is hidden, not dimmed, on purpose (seminar convention).
  Dimming is a documented opt-in through the passthrough:
  `config-methods(cover: utils.semi-transparent-cover)`. Do not add a theme
  option for it.
- After `#show: appendix` the slide counter keeps counting but the total is
  frozen, so `_footer` prints the number alone when `self.appendix` is set.
- Typst warns about *every* unknown family in a font list, even when an earlier
  one resolves, so every fallback is a permanent warning on platforms lacking
  it. Mono and math fall back to fonts embedded in the Typst binary (DejaVu Sans
  Mono, New Computer Modern Math), which never warn. Typst embeds no sans, so
  Inter falls back to Arial only (clean on macOS/Windows, one spurious warning
  on Linux without it). Do not lengthen these lists.
- Typst 0.15 instances variable fonts correctly. With the Homebrew Inter cask
  it picks `InterVariable` over the static files and applies optical sizing, so
  text sets slightly tighter than with static Inter; line breaks can differ
  between machines.
- `raw` text is already 0.8em; sizes set in `show raw` compound with that.
- Math is STIX Two Math scaled by `math-scale` to match Inter's x-height.
- A local variable named `left`/`right`/`top` shadows the alignment constant.
- Since Touying 0.7.3, content after `= Section` is not passed to the section
  slide (`receive-body-for-new-section-slide-fn` defaults to false).
- `counter(heading).at(..)` returns 0 for Touying-managed headings; the section
  number counts `query(heading.where(level: 1).before(here()))` instead.
- Touying's source is the best reference:
  `~/Library/Caches/typst/packages/preview/touying/0.7.4/` (`themes/simple.typ`
  for theme structure, `src/configs.typ` for every `config-*` option).

## Roadmap

Done: stage 1 (theme, content + section slides, example), stage 2
(`title-slide`, `focus-slide`, `muted`, quote/footnote/code-block styling,
appendix-aware counter) and stage 3 (statements, `keypoint`, `source`,
figure/booktabs-table/citation/bibliography styling, non-breakable slides) and
stage 4 (`goto` with automatic back-links, unnumbered appendix sections;
handout mode and second-screen speaker notes verified to work unchanged).

Also done, after testing with real images and real R output ("stage 4.5"):
auto-fitting figures and figure-aware `cols`, the `#outline()` roadmap with
current-section highlighting, numeric-cell typesetting (minus signs, balanced
stars) and tinytable compatibility, Inter for words in math, unbreakable inline
math, and `text-size`. `examples/figures/irf.svg` is generated from `irf.typ`.

Two planned functions were deliberately *not* built, because native elements
cover them: `table-note` (the figure `caption` is the table note) and
`references-slide` (`== References` + `#bibliography(..)`, styled by show
rules). Do not reintroduce them.

Next:

5. Release — `template/`, thumbnail, `[template]` in `typst.toml`,
   Typst Universe submission (needs a final package name).

Dark mode is deferred; keeping all colors in `tokens.typ` is what makes it cheap later.

Reference themes studied for this design: gh-minimal-slides (typography),
calmly-touying (package layout), typslides (API economy — GPL-3.0, so ideas
only, never code).
