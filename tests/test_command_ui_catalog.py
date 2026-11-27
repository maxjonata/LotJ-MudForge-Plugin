"""Tests for scripts/ui/build_catalog.py and docs/ui/command-ui.json (FIG-01)."""

from pathlib import Path
import json
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/ui"))
import build_catalog as bc  # noqa: E402


def topic(name, syntax=(), tags=(), is_command=None):
    syntax = list(syntax)
    return {"topic": name, "keywords": name.split(), "syntax": syntax, "see_also": [],
            "is_command": bool(syntax) if is_command is None else is_command,
            "inferred_tags": list(tags), "url": "https://www.legendsofthejedi.com/help?topic=" + name}


class ArgTests(unittest.TestCase):
    def test_types_from_placeholder_words(self):
        self.assertEqual([a["type"] for a in bc.args("throw <item> <direction> <target>")],
                         ["object", "direction", "character"])
        self.assertEqual([a["type"] for a in bc.args("loadship <smaller ship> <larger ship> <bay #>")],
                         ["ship", "ship", "number"])
        self.assertEqual([a["type"] for a in bc.args("renameship <ship> <new name>")], ["ship", "text"])

    def test_choices_and_toggles(self):
        self.assertEqual(bc.args("setblaster <full|high|normal|half|low|stun>"),
                         [{"name": "full|high|normal|half|low|stun", "type": "choice",
                           "choices": ["full", "high", "normal", "half", "low", "stun"]}])
        self.assertEqual(bc.args("rip <on/off>")[0]["type"], "toggle")

    def test_numeric_ranges(self):
        self.assertEqual(bc.args("promote <0-11>"), [{"name": "0-11", "type": "number", "min": 0, "max": 11}])
        self.assertEqual(bc.args("saberform <0 - 7>")[0]["max"], 7)

    def test_explanatory_parentheticals_are_notes(self):
        self.assertEqual(bc.args("description (opens the editor)"), [])
        self.assertEqual(bc.variant_pattern("description (opens the editor)"), "direct")
        self.assertEqual(bc.args("calculate (system) (x)")[0]["type"], "place")

    def test_literal_subcommands_are_not_args(self):
        self.assertEqual(bc.args("launch abort"), [])
        self.assertEqual(bc.args("launch"), [])


class PatternTests(unittest.TestCase):
    def test_variant_patterns(self):
        self.assertEqual(bc.variant_pattern("radar"), "direct")
        self.assertEqual(bc.variant_pattern("rip <on/off>"), "toggle")
        self.assertEqual(bc.variant_pattern("target <ship name>"), "target")
        self.assertEqual(bc.variant_pattern("reload <ship> <weapon> <amount>"), "form")

    def test_topic_level_rules(self):
        self.assertEqual(bc.entry(topic("RADAR", ["radar"], ["ship"]))["pattern"], "direct")
        self.assertEqual(bc.entry(topic("MAKEMEDPAC", ["makemedpac <medpac name>"]))["pattern"], "craft")
        self.assertEqual(bc.entry(topic("DUAL", ["Use of the skill is automatic once learned."], ["combat"]))["kind"], "passive")
        self.assertEqual(bc.entry(topic("RULES"))["pattern"], "reference")
        listing = bc.entry(topic("STANCE", ["stance <stance> OR stance list"]))
        self.assertEqual(listing["pattern"], "list")
        self.assertEqual([v["syntax"] for v in listing["variants"]], ["stance <stance>", "stance list"])

    def test_or_markers_split_variants(self):
        e = bc.entry(topic("NOTE", ["note list (number) OR: Mail list (number)", "Or: Palm list"]))
        self.assertEqual([v["syntax"] for v in e["variants"]], ["note list (number)", "Mail list (number)", "Palm list"])

    def test_clan_commands_stay_in_clan_area(self):
        self.assertEqual(bc.entry(topic("CLANCRIMES CRIMES", ["clancrimes"], ["ship", "economy"]))["area"], "clan")
        self.assertEqual(bc.entry(topic("CLANTALK", ["clantalk <message>"], ["comms"]))["area"], "comms")

    def test_abort_variant_makes_a_flow(self):
        self.assertEqual(bc.entry(topic("LAUNCH", ["launch", "launch orbit", "launch abort"], ["ship"]))["pattern"], "flow")

    def test_areas(self):
        self.assertEqual(bc.entry(topic("RADAR", ["radar"], ["ship"]))["area"], "space")
        self.assertEqual(bc.entry(topic("AFFLICTION", ["feel affliction <target>"], ["force"]))["area"], "force")
        self.assertEqual(bc.entry(topic("TIME", ["time"]))["area"], "general")

    def test_overrides_win(self):
        built = bc.build([topic("PTALK", ["ptalk <message>"])], {"PTALK": {"status": "inactive", "note": "x"}})
        self.assertEqual(built["entries"][0]["status"], "inactive")
        with self.assertRaises(ValueError):
            bc.build([topic("A", ["a"])], {"MISSING": {"status": "inactive"}})


class CommittedCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference = json.loads((ROOT / "docs/reference/lotj-commands.json").read_text(encoding="utf-8"))
        cls.catalog = json.loads((ROOT / "docs/ui/command-ui.json").read_text(encoding="utf-8"))
        cls.nodes = json.loads((ROOT / "docs/ui/figma-nodes.json").read_text(encoding="utf-8"))

    def test_every_help_topic_has_exactly_one_destination(self):
        topics = [t["url"] for t in self.reference["topics"]]
        entries = [e["url"] for e in self.catalog["entries"]]
        self.assertEqual(sorted(entries), sorted(topics))
        self.assertEqual(len(entries), len(set(entries)))

    def test_entries_use_known_values(self):
        for e in self.catalog["entries"]:
            self.assertIn(e["pattern"], bc.PATTERNS, e["topic"])
            self.assertIn(e["area"], bc.AREAS, e["topic"])
            self.assertIn(e["status"], bc.STATUSES, e["topic"])
            self.assertIn(e["kind"], bc.KINDS, e["topic"])
            if e["kind"] == "command":
                self.assertNotEqual(e["pattern"], "reference", e["topic"])
                self.assertTrue(e["variants"], e["topic"])

    def test_committed_catalog_is_regenerated(self):
        overrides = json.loads((ROOT / "docs/ui/overrides.json").read_text(encoding="utf-8"))
        rebuilt = bc.build(self.reference["topics"], overrides, bc.figma_links(self.nodes), bc.pattern_frames(self.nodes))
        self.assertEqual(rebuilt, self.catalog, "run: python scripts/ui/build_catalog.py")

    def test_every_pattern_has_a_figma_card(self):
        self.assertEqual(set(self.catalog["pattern_nodes"]), set(bc.PATTERNS))
        with self.assertRaises(ValueError):
            bc.build([topic("A", ["a"])], {}, {}, {"nope": "1:1"})

    def test_figma_links_point_to_exported_nodes(self):
        known = {n["id"] for n in self.nodes["nodes"]}
        for e in self.catalog["entries"]:
            if e["figma_node"]:
                self.assertIn(e["figma_node"], known, e["topic"])
                self.assertNotEqual(e["status"], "planned", e["topic"])


if __name__ == "__main__":
    unittest.main()
