"""Regression tests for the native LOTJ plugin-only ZIP."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
BUILDER = ROOT / "scripts/build_preview_zip.py"


class PreviewZipTests(unittest.TestCase):
    def test_project_archive_has_only_exact_runtime_files(self):
        expected = {
            "LOTJ Companion.lua": "src/lotj.lua",
            "LOTJ Companion/src/widgets/lotj-comms-hub.lua": "src/widgets/lotj-comms-hub.lua",
            "LOTJ Companion/src/widgets/lotj-ground-map.lua": "src/widgets/lotj-ground-map.lua",
            "LOTJ Companion/src/widgets/lotj-status-bar.lua": "src/widgets/lotj-status-bar.lua",
        }
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "preview.zip"
            result = subprocess.run(
                [sys.executable, str(BUILDER), str(output)],
                cwd=tmp, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            with zipfile.ZipFile(output) as archive:
                self.assertCountEqual(archive.namelist(), expected)
                self.assertIsNone(archive.testzip())
                for member, source in expected.items():
                    with self.subTest(member=member):
                        self.assertEqual(archive.read(member), (ROOT / source).read_bytes())


if __name__ == "__main__":
    unittest.main()
