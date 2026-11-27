"""Tests for scripts/dev/install_dev_plugin.py (QA-07)."""

from pathlib import Path
import sys
import tempfile
import unittest
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/dev"))
import install_dev_plugin as dev  # noqa: E402


class PluginFilesTests(unittest.TestCase):
    def test_main_script_and_modules_keep_their_load_paths(self):
        files = dev.plugin_files()
        self.assertEqual(files["LotJ Plugin DEV.lua"], (ROOT / "dev/main.lua").read_bytes())
        for path in ("release/lotj.lua", "release/domain/target-lock.lua", "dev/harness.lua", "dev/scenarios/index.lua"):
            self.assertIn(f"LotJ Plugin DEV/{path}", files)
        self.assertFalse(any(name.startswith("LotJ Plugin DEV/src/") for name in files))
        widget = "src/widgets/lotj-status-bar.lua"
        self.assertEqual(files["LotJ Plugin DEV/release/widgets/lotj-status-bar.lua"], (ROOT / widget).read_bytes())
        self.assertNotIn("LotJ Plugin DEV/dev/main.lua", files)
        self.assertFalse(any("/tests/" in name for name in files), "specs stay out of the plugin")

    def test_release_entry_point_is_renamed_and_loads_from_release(self):
        entry = dev.plugin_files()["LotJ Plugin DEV/release/lotj.lua"]
        self.assertNotIn(b"\nplugin = {", entry, "the watcher would match it to the release plugin")
        self.assertIn(b"\nLotjReleasePlugin = {", entry)
        self.assertNotIn(b'loadModule("src/', entry)
        self.assertIn(b'loadModule("release/widgets/lotj-status-bar.lua")', entry)
        original = (ROOT / "src/lotj.lua").read_bytes()
        self.assertEqual(entry.count(b"\n"), original.count(b"\n"), "only names change, never lines")

    def test_zip_matches_the_mudforge_export_layout(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "dev.zip"
            dev.build_zip(output)
            with ZipFile(output) as archive:
                names = archive.namelist()
                self.assertIn("LotJ Plugin DEV.lua", names)
                self.assertEqual([n for n in names if "/" not in n], ["LotJ Plugin DEV.lua"])
                self.assertEqual(archive.read("LotJ Plugin DEV.lua"), (ROOT / "dev/main.lua").read_bytes())

    def test_release_zip_never_contains_the_harness(self):
        sys.path.insert(0, str(ROOT / "scripts"))
        import build_preview_zip  # noqa: E402
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "release.zip"
            build_preview_zip.build(output)
            with ZipFile(output) as archive:
                self.assertFalse(any("dev/" in n or "LotJ Plugin DEV" in n for n in archive.namelist()))


class InstallTests(unittest.TestCase):
    def test_refuses_a_missing_plugins_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                dev.install(Path(tmp) / "missing")

    def test_copies_changed_files_and_always_rewrites_the_main_script_last(self):
        with tempfile.TemporaryDirectory() as tmp:
            first = dev.install(tmp)
            self.assertEqual(first[-1], "LotJ Plugin DEV.lua")
            self.assertEqual((Path(tmp) / "LotJ Plugin DEV/release/domain/target-lock.lua").read_bytes(),
                             (ROOT / "src/domain/target-lock.lua").read_bytes())
            self.assertEqual(dev.install(tmp), ["LotJ Plugin DEV.lua"], "unchanged modules are not rewritten")


if __name__ == "__main__":
    unittest.main()
