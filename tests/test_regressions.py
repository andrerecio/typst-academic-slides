"""Compile small decks and check warnings, PDF geometry, and navigation."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from pypdf import PdfReader


ROOT = Path(__file__).resolve().parents[1]
IMAGE = f'image({json.dumps(str(ROOT / "examples/figures/irf.svg"))})'


def text_positions(page):
    positions = {}

    def visit(text, cm, tm, font, size):
        if text.strip():
            # Transform the text origin into page coordinates.
            positions[text.strip()] = (
                tm[4] * cm[0] + tm[5] * cm[2] + cm[4],
                tm[4] * cm[1] + tm[5] * cm[3] + cm[5],
            )

    page.extract_text(visitor_text=visit)
    return positions


class RegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="brownbag-tests-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.serial = 0

    def compile(self, body, *, options="", overflow=False):
        self.serial += 1
        source = self.directory / f"case-{self.serial}.typ"
        source.write_text(
            f'#import {json.dumps(str(ROOT / "lib.typ"))}: *\n'
            '#show: brownbag-theme.with(config-info(title: [Review]), '
            f'{options})\n{body}\n'
        )
        output = source.with_suffix(".pdf")
        result = subprocess.run(
            ["typst", "compile", "--root", "/", str(source), str(output)],
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        if overflow:
            self.assertIn("detecting column content overflow", result.stderr)
        else:
            self.assertNotIn("overflow", result.stderr)
        self.assertNotIn("layout did not converge", result.stderr)
        return PdfReader(output), result.stderr

    def assert_source_clear(self, page):
        positions = text_positions(page)
        source = next(pos for text, pos in positions.items() if text.startswith("Source:"))
        self.assertGreater(source[1], positions["Review"][1] + 10)

    def test_numeric_inset_forms(self):
        positions = []
        for inset in ("4pt", "(x: 4pt, y: 4pt)",
                      "(left: 4pt, right: 4pt, top: 4pt, bottom: 4pt)"):
            with self.subTest(inset=inset):
                pdf, _ = self.compile(
                    f"== Table\n#table(columns: 2, inset: {inset}, "
                    "[Value], [-1.0], [Estimate], [0.41\\*\\*\\*])"
                )
                self.assertEqual(len(pdf.pages), 1)
                positions.append(text_positions(pdf.pages[0]))
        self.assertEqual(positions[0], positions[1])
        self.assertEqual(positions[0], positions[2])

    def test_wrapped_figures_leave_space_for_source(self):
        for wrap in ("{}", "align(center, {})", "block({})", "pad(5pt, {})",
                     "pad(5pt, block(align(center, {})))"):
            with self.subTest(wrap=wrap):
                figure = wrap.format(f"figure({IMAGE})")
                pdf, _ = self.compile(
                    f"== Wrapped\n#cols[Text][#{figure}]\n#source[Visible source.]"
                )
                self.assertEqual(len(pdf.pages), 1)
                self.assert_source_clear(pdf.pages[0])

    def test_column_overflow_warns_on_the_correct_page(self):
        long_text = "\n\n".join(f"Line {i}: example text." for i in range(19))
        pdf, warnings = self.compile(
            f"== Fits\n#cols[Short][#figure({IMAGE})]\n#source[First.]\n"
            f"== Overflow\n#cols[{long_text}][#figure({IMAGE})]\n#source[Second.]\n"
            f"== Fits again\n#cols[Short][#figure({IMAGE})]\n#source[Third.]",
            overflow=True,
        )
        self.assertEqual(len(pdf.pages), 3)
        self.assertIn("overflow at page 2", warnings)
        self.assertNotIn("overflow at page 1", warnings)
        self.assertNotIn("overflow at page 3", warnings)

    def test_caption_position(self):
        for position in ("top", "bottom"):
            for picture in (IMAGE, f"grid(columns: 2, {IMAGE}, {IMAGE})"):
                with self.subTest(position=position, picture=picture):
                    pdf, _ = self.compile(
                        f"== Caption\n#set figure.caption(position: {position})\n"
                        f"#figure({picture}, caption: [Caption marker])"
                    )
                    y = text_positions(pdf.pages[0])["Caption marker"][1]
                    if position == "top":
                        self.assertGreater(y, 300)
                    else:
                        self.assertLess(y, 150)

    def test_column_reveals_and_back_links(self):
        body = (
            "== Origin\n#cols[Before\n#pause\nAfter #goto(<backup>)[Details]]"
            f"[#align(center)[#figure({IMAGE})]]\n#source[Visible source.]\n"
            "#show: appendix\n== Backup <backup>\nDetails"
        )
        for handout in (False, True):
            with self.subTest(handout=handout):
                pdf, _ = self.compile(
                    body, options="config-common(handout: true)," if handout else ""
                )
                self.assertEqual(len(pdf.pages), 2 if handout else 3)
                if not handout:
                    self.assertNotIn("After", pdf.pages[0].extract_text())
                origin = len(pdf.pages) - 2
                self.assertIn("After", pdf.pages[origin].extract_text())
                self.assert_source_clear(pdf.pages[origin])
                destinations = [
                    annotation.get_object().get("/Dest")
                    for annotation in pdf.pages[-1].get("/Annots", [])
                ]
                self.assertTrue(any(
                    dest and dest[0] == pdf.pages[origin].indirect_reference
                    for dest in destinations
                ))

    def test_single_and_nested_columns(self):
        for content in (
            f"#cols[#figure({IMAGE})]",
            f"#cols[#cols[Left][#figure({IMAGE})]][Outer]",
            f"#cols(lazy-layout: true)[Left][#figure({IMAGE})]",
        ):
            with self.subTest(content=content):
                pdf, _ = self.compile(f"== Columns\n{content}\n#source[Visible source.]")
                self.assertEqual(len(pdf.pages), 1)
                self.assert_source_clear(pdf.pages[0])


if __name__ == "__main__":
    unittest.main()
