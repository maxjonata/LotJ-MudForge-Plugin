"""FIG-07: phone screens fit an iPhone SE (375x667) with the keyboard open or closed."""

from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / "scripts/ui/figma"
OUT = GEN / "out"
W, H, KB_Y = 375, 667, 667 - 260
TYPING = ("se_rp_digitando", "se_combate_digitando", "se_fluxo_digitando")


def screens():
    return {p.stem: p.read_text(encoding="utf-8") for p in sorted(OUT.glob("se_*.svg"))}


def screen_part(svg):
    """Drop the design notes drawn under the 667 pt screen."""
    return [t for t in re.findall(r"<(?:rect|text|circle|line|ellipse|path)\b[^>]*>", svg)
            if not re.search(r'\by="(\d+(?:\.\d+)?)"', t) or float(re.search(r'\by="(\d+(?:\.\d+)?)"', t).group(1)) < H]


class MobileSeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run([sys.executable, "-W", "ignore", "mobile_se.py"], cwd=GEN, check=True, capture_output=True)
        cls.svgs = screens()

    def test_all_ten_screens_are_generated(self):
        self.assertEqual(len(self.svgs), 10, sorted(self.svgs))

    def test_no_text_below_11pt(self):
        for name, svg in self.svgs.items():
            sizes = [int(s) for s in re.findall(r'font-size="(\d+)"', svg)]
            self.assertTrue(sizes and min(sizes) >= 11, (name, min(sizes)))

    def test_every_key_is_a_44pt_touch_target(self):
        for name, svg in self.svgs.items():
            for h in re.findall(r'<rect [^>]*height="([\d.]+)"[^>]*fill="url\(#g', svg):
                self.assertGreaterEqual(float(h), 44, name)

    def test_nothing_spills_past_the_screen_width(self):
        for name, svg in self.svgs.items():
            for x, w in re.findall(r'<rect x="([\d.]+)" y="[\d.]+" width="([\d.]+)"', svg):
                self.assertLessEqual(float(x) + float(w), W + 0.5, name)

    def test_typing_screens_keep_their_ui_above_the_keyboard(self):
        for name in TYPING:
            for tag in screen_part(self.svgs[name]):
                y = re.search(r'\by="([\d.]+)"', tag)
                h = re.search(r'height="([\d.]+)"', tag)
                if not y or 'fill="#6b6b6d"' in tag or 'fill="#2b2b2d"' in tag or 'fill="#232325"' in tag \
                        or 'fill="#ffffff"' in tag or 'fill="#e6e6e6"' in tag or 'height="667"' in tag:
                    continue  # the iOS keyboard itself and the screen background
                bottom = float(y.group(1)) + (float(h.group(1)) if h else 0)
                self.assertLessEqual(bottom, KB_Y, (name, tag[:80]))

    def test_keys_state_has_tabs_and_command_line(self):
        for name, svg in self.svgs.items():
            if name in TYPING or name == "se_alvo":
                continue
            self.assertIn('y="618" width="65.4" height="44"', svg, name)  # 5 station tabs
            if name != "se_mapa":
                self.assertIn("commands ▴", svg, name)


if __name__ == "__main__":
    unittest.main()
