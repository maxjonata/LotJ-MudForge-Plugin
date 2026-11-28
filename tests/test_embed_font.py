"""The embedded widget font matches assets/fonts and stays CC-0 (UI-02)."""
import base64
import pathlib
import re
import struct
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def font_names(data):
    count = struct.unpack(">H", data[4:6])[0]
    for i in range(count):
        tag, _, offset, _ = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
        if tag == b"name":
            _, records, strings = struct.unpack(">HHH", data[offset:offset + 6])
            names = {}
            for j in range(records):
                pid, _, _, nid, length, start = struct.unpack(
                    ">HHHHHH", data[offset + 6 + 12 * j:offset + 18 + 12 * j])
                raw = data[offset + strings + start:offset + strings + start + length]
                names.setdefault(nid, raw.decode("utf-16-be" if pid in (0, 3) else "latin1"))
            return names
    return {}


class EmbedFontTest(unittest.TestCase):
    def test_module_is_current(self):
        result = subprocess.run([sys.executable, "scripts/ui/embed_font.py", "--check"],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_module_holds_the_font(self):
        module = (ROOT / "src/widgets/lotj-ui-font.lua").read_text(encoding="utf-8")
        encoded = re.search(r'base64,([A-Za-z0-9+/=]+)"', module).group(1)
        self.assertEqual(base64.b64decode(encoded),
                         (ROOT / "assets/fonts/AurebeshAF-Canon.otf").read_bytes())

    def test_font_is_public_domain(self):
        names = font_names((ROOT / "assets/fonts/AurebeshAF-Canon.otf").read_bytes())
        self.assertIn("CC-0", names.get(0, ""))


if __name__ == "__main__":
    unittest.main()
