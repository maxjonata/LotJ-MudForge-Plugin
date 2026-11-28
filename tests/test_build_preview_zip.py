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
            "LOTJ Companion/src/application/scrapper-cockpit.lua": "src/application/scrapper-cockpit.lua",
            "LOTJ Companion/src/application/target-cockpit.lua": "src/application/target-cockpit.lua",
            "LOTJ Companion/src/domain/chat-line.lua": "src/domain/chat-line.lua",
            "LOTJ Companion/src/domain/public-galaxy.lua": "src/domain/public-galaxy.lua",
            "LOTJ Companion/src/domain/radar-scan.lua": "src/domain/radar-scan.lua",
            "LOTJ Companion/src/domain/ship-position.lua": "src/domain/ship-position.lua",
            "LOTJ Companion/src/domain/target-lock.lua": "src/domain/target-lock.lua",
            "LOTJ Companion/src/widgets/lotj-scrapper-cockpit.lua": "src/widgets/lotj-scrapper-cockpit.lua",
            "LOTJ Companion/src/widgets/lotj-comms-hub.lua": "src/widgets/lotj-comms-hub.lua",
            "LOTJ Companion/src/widgets/lotj-ground-map.lua": "src/widgets/lotj-ground-map.lua",
            "LOTJ Companion/src/widgets/lotj-status-bar.lua": "src/widgets/lotj-status-bar.lua",
            "LOTJ Companion/src/application/datapad.lua": "src/application/datapad.lua",
            "LOTJ Companion/src/domain/datapad.lua": "src/domain/datapad.lua",
            "LOTJ Companion/src/widgets/lotj-datapad.lua": "src/widgets/lotj-datapad.lua",
            "LOTJ Companion/src/widgets/lotj-ui-font.lua": "src/widgets/lotj-ui-font.lua",
            "LOTJ Companion/src/widgets/lotj-ui-kit.lua": "src/widgets/lotj-ui-kit.lua",
            "LOTJ Companion/src/widgets/lotj-window-dock.lua": "src/widgets/lotj-window-dock.lua",
            "LOTJ Companion/src/domain/console-catalog.lua": "src/domain/console-catalog.lua",
            "LOTJ Companion/src/domain/command-form.lua": "src/domain/command-form.lua",
            "LOTJ Companion/src/application/station-console.lua": "src/application/station-console.lua",
            "LOTJ Companion/src/widgets/lotj-station-console.lua": "src/widgets/lotj-station-console.lua",
            "LOTJ Companion/src/domain/live-readout.lua": "src/domain/live-readout.lua",
            "LOTJ Companion/src/application/live-readout.lua": "src/application/live-readout.lua",
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
