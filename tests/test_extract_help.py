"""Regression tests for scripts/reference/extract_help.py.

Fixtures are synthetic pages shaped like the public LotJ help site; they do not
copy real help text.
"""

from pathlib import Path
import json
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/reference"))
import extract_help  # noqa: E402


def page(topic, body):
    return (f"<!-- source: https://www.legendsofthejedi.com/help?topic={topic} -->\n"
            "<html><body><article><pre class=\"help-body font-mono\" data-x>\n"
            f"{body}</pre></article><div>Index</div></body></html>")


COMMAND = page("FAKEFIRE", """Syntax: fakefire
Syntax: fakefire &lt;target&gt;

Made-up text that fires a pretend weapon at the ship you target.

See Also: FAKETARGET, PILOTINGFAQ""")

MULTI = page("%27FAKE%20DODGE%27%20%27DODGE%27", """Syntax:  fake dodge
         fake dodge stop

Pretend skill.""")

PROSE = page("FAKEFAQ", "Made-up guide with no syntax line.\n\nSee also: FAKEFIRE")


class ParseTests(unittest.TestCase):
    def test_command_page(self):
        entry = extract_help.parse_page(COMMAND)
        self.assertEqual(entry["topic"], "FAKEFIRE")
        self.assertEqual(entry["keywords"], ["FAKEFIRE"])
        self.assertEqual(entry["syntax"], ["fakefire", "fakefire <target>"])
        self.assertEqual(entry["see_also"], ["FAKETARGET", "PILOTINGFAQ"])
        self.assertTrue(entry["is_command"])
        self.assertEqual(entry["url"], "https://www.legendsofthejedi.com/help?topic=FAKEFIRE")

    def test_quoted_keywords_and_indented_syntax_continuation(self):
        entry = extract_help.parse_page(MULTI)
        self.assertEqual(entry["keywords"], ["FAKE DODGE", "DODGE"])
        self.assertEqual(entry["syntax"], ["fake dodge", "fake dodge stop"])

    def test_prose_page_is_not_a_command(self):
        entry = extract_help.parse_page(PROSE)
        self.assertFalse(entry["is_command"])
        self.assertEqual(entry["syntax"], [])
        self.assertEqual(entry["see_also"], ["FAKEFIRE"])

    def test_page_without_help_body_is_rejected(self):
        self.assertIsNone(extract_help.parse_page("<html>no body</html>"))

    def test_entries_never_carry_help_prose(self):
        entry = extract_help.parse_page(COMMAND)
        self.assertNotIn("pretend weapon", json.dumps(entry))

    def test_categories_are_marked_as_inferred(self):
        entry = extract_help.parse_page(COMMAND)
        self.assertIn("ship", entry["inferred_tags"])


class CliTests(unittest.TestCase):
    def test_writes_sorted_json_and_skips_broken_pages(self):
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "pages"
            src.mkdir()
            (src / "b.html").write_text(COMMAND, encoding="utf-8")
            (src / "a.html").write_text(PROSE, encoding="utf-8")
            (src / "c.html").write_text("<html>broken</html>", encoding="utf-8")
            out = Path(tmp) / "out.json"
            subprocess.run([sys.executable, str(ROOT / "scripts/reference/extract_help.py"),
                            str(src), str(out)], check=True, capture_output=True)
            data = json.loads(out.read_text(encoding="utf-8"))
            self.assertEqual([e["topic"] for e in data["topics"]], ["FAKEFAQ", "FAKEFIRE"])
            self.assertEqual(data["skipped"], 1)
            self.assertIn("legendsofthejedi.com/help", data["source"])


if __name__ == "__main__":
    unittest.main()
