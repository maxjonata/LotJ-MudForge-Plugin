"""The station console catalog is generated from docs/ui/command-ui.json (UI-03)."""
import json
import pathlib
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "scripts/ui"), str(ROOT / "scripts/ui/figma")]

import build_consoles  # noqa: E402

CATALOG = json.loads((ROOT / "docs/ui/command-ui.json").read_text(encoding="utf-8"))


class BuildConsolesTest(unittest.TestCase):
    def test_module_is_current(self):
        result = subprocess.run([sys.executable, "scripts/ui/build_consoles.py", "--check"],
                                cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_every_station_command_has_a_key_and_every_reference_a_topic(self):
        data = build_consoles.build(CATALOG)
        topics = {t for keys in data["keys"].values() for k in keys for t in k["topics"]}
        passive = {sid for sid, labels in data["passive"].items() if labels}
        for entry in CATALOG["entries"]:
            if entry["kind"] == "reference":
                continue
            if entry["pattern"] == "readout":
                self.assertIn(entry["station"], passive, entry["topic"])
            else:
                self.assertIn(entry["topic"], topics)
        refs = {r["topic"] for r in data["references"]}
        self.assertEqual(len(refs), sum(1 for e in CATALOG["entries"] if e["kind"] == "reference"))
        self.assertEqual({s["id"] for s in data["stations"]}, set(CATALOG["stations"]))

    def test_templates(self):
        t = build_consoles.template
        self.assertEqual(t("course <x> <y> <z>")[0], "course {1} {2} {3}")
        self.assertEqual(t("kick (when in combat)"), ("kick", []))
        self.assertEqual(t("south or s"), ("south", []))
        text, args = t("Gender 0/1/2")
        self.assertEqual((text, args[0]["choices"]), ("gender {1}", ["0", "1", "2"]))
        text, args = t("aconfig +/-<option>")
        self.assertEqual(text, "aconfig {1}{2}")
        self.assertEqual(args[0]["choices"], ["+", "-"])
        self.assertEqual(args[1]["name"], "option")
        text, args = t("locker open all/<#>")
        self.assertEqual((text, args[0]["choices"]), ("locker open {1}", ["all"]))
        text, args = t("feel 'cure blindness' <target>/no argument")
        self.assertEqual(text, "feel 'cure blindness' {1}")
        self.assertTrue(args[0]["optional"])
        text, args = t("open <object/direction>")
        self.assertEqual(args[0]["type"], "text")
        self.assertNotIn("choices", args[0])
        self.assertEqual(t("challenge <target> <optional: bet>")[1][1]["optional"], True)

    def test_red_keys_confirm_and_inactive_keys_are_marked(self):
        data = build_consoles.build(CATALOG)
        keys = [k for ks in data["keys"].values() for k in ks]
        self.assertTrue(all(k["confirm"] == (k["color"] == "red") for k in keys))
        self.assertTrue(any(k["confirm"] for k in data["keys"]["combat"]))
        self.assertEqual(sum(k["inactive"] for k in keys),
                         sum(1 for e in CATALOG["entries"] if e.get("status") == "inactive"
                             and e["kind"] != "reference" and e["pattern"] != "readout"))

    def test_unknown_station_fails(self):
        broken = json.loads(json.dumps(CATALOG))
        broken["entries"].append({"topic": "X", "kind": "command", "station": "nowhere", "pattern": "direct",
                                  "variants": [], "keywords": ["X"]})
        with self.assertRaises(ValueError):
            build_consoles.build(broken)


if __name__ == "__main__":
    unittest.main()
