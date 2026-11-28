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

    def test_optional_marker_inside_angle_brackets(self):
        self.assertEqual(bc.args("challenge <target> <optional: bet>")[1],
                         {"name": "bet", "type": "text", "optional": True})

    def test_or_inside_a_placeholder_is_one_argument(self):
        e = bc.entry(topic("INDUCTLOG", ["inductlog <name of either person OR date OR induct OR outcast>"]))
        self.assertEqual(len(e["variants"]), 1)
        self.assertEqual(e["variants"][0]["args"], [{"name": "name of either person OR date OR induct OR outcast",
                                                     "type": "choice", "choices": ["name of either person", "date", "induct", "outcast"]}])
        self.assertEqual(e["pattern"], "form")

    def test_automatic_as_an_argument_is_not_passive(self):
        e = bc.entry(topic("PTURRETS", ["pturrets <manual/automatic>"], ["ship"]))
        self.assertEqual((e["kind"], e["pattern"]), ("command", "form"))

    def test_trailing_explanation_is_not_syntax(self):
        v = bc.entry(topic("CHARSHEET", ["charsheet status: See all available entry options"]))["variants"][0]
        self.assertEqual(v["syntax"], "charsheet status")
        self.assertEqual(v["preconditions"], ["See all available entry options"])

    def test_short_annotations_are_notes(self):
        self.assertEqual(bc.args("arm (no argument)"), [])
        self.assertEqual(bc.args("affected (abbrevation: af)"), [])
        self.assertEqual(bc.variant_pattern("affected (abbrevation: af)"), "direct")

    def test_role_restrictions_are_notes(self):
        self.assertEqual(bc.args("speak all (immortals only)"), [])

    def test_prose_rows_are_notes_not_variants(self):
        e = bc.entry(topic("HISTORY BIO BACKGROUND", ["history (opens a prompt)", "Required by level 30"]))
        self.assertEqual([v["syntax"] for v in e["variants"]], ["history (opens a prompt)"])
        self.assertEqual(e["notes"], ["Required by level 30"])
        self.assertEqual(len(bc.entry(topic("DISGUISE", ["Disguise list", "Fire <Weapon Type>"]))["variants"]), 2)

    def test_unclosed_last_placeholder_is_kept(self):
        self.assertEqual([a["type"] for a in bc.args("clanbounty <character> <amount")], ["character", "number"])
        self.assertEqual(len(bc.args("inductlog <name OR date> (For")), 1)

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

    def test_force_powers_route_to_force(self):
        self.assertEqual(bc.entry(topic("SLEEP", ["feel sleep <victim>"], ["force"]))["area"], "force")
        self.assertEqual(bc.entry(topic("REST SLEEP STAND WAKE", ["sleep"]))["area"], "room")

    def test_a_ship_argument_routes_to_space(self):
        self.assertEqual(bc.entry(topic("BOARD", ["board <target ship>"], ["ship"]))["area"], "space")
        self.assertEqual(bc.entry(topic("CLANBUYSHIP", ["clanbuyship <ship>"], ["ship"]))["area"], "clan")

    def test_help_indexes_are_not_routed_by_prose_tags(self):
        self.assertEqual(bc.entry(topic("NEWBIE_INDEX INDEX", ["HELP #"], ["ship"]))["area"], "general")
        self.assertEqual(bc.entry(topic("CHAFF", ["chaff"], ["ship"]))["area"], "space")

    def test_editor_only_when_a_variant_writes(self):
        self.assertEqual(bc.entry(topic("MAIL", ["mail list <sent/received/all>", "mail read <#>"]))["pattern"], "list")
        self.assertEqual(bc.entry(topic("DATAMEM", ["datamem write new", "datamem list"]))["pattern"], "editor")

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

    def test_every_help_space_command_has_a_station(self):
        stations = {e["topic"]: e["station"] for e in self.catalog["entries"]}
        for e in self.catalog["entries"]:
            if e["station"] is not None:
                self.assertIn(e["station"], bc.STATIONS, e["topic"])
        # The commands listed in HELP SPACE SHIP SHIPS FLIGHT (FIG-02 scope).
        for topic in ["BOARD", "LAUNCH", "LAND", "RADAR", "PROXIMITY PROX", "TARGET", "FIRE", "CHAFF",
                      "HYPERSPACE HYPER LIGHTSPEED", "COORDINATES CALC CALCULATE NAVCOMPUTER", "DOCK",
                      "UNDOCK", "HAIL", "RADIO", "BATTLEGROUP", "SQUADRON", "ACONFIG", "BUYSHIP SELLSHIP"]:
            self.assertIsNotNone(stations.get(topic), topic)

    def test_room_and_rp_commands_have_a_panel(self):
        panels = {e["topic"]: e["station"] for e in self.catalog["entries"]}
        for topic in ["NORTH SOUTH EAST WEST UP DOWN", "EXAMINE LOOK", "OPEN CLOSE LOCK UNLOCK PICK", "TURBOLIFT",
                      "DROP GET GIVE PUT TAKE"]:
            self.assertEqual(panels.get(topic), "room", topic)
        for topic in ["SAY", "SAYTO", "EMOTE , POSE SOCIAL", "TELL REPLY", "WHISPER", "CLANTALK", "TUNE"]:
            self.assertEqual(panels.get(topic), "rp", topic)

    def test_character_and_combat_commands_have_a_panel(self):
        panels = {e["topic"]: e["station"] for e in self.catalog["entries"]}
        for topic, panel in [("SCORE", "sheet"), ("KILL MURDER", "combat"), ("FLEE", "combat"), ("MEDITATE", "force"),
                             ("HEALWOUND", "medical"), ("CLONES CLONE CLONING", "medical"), ("AMMO AMMUNITION BATTERY", "gear")]:
            self.assertEqual(panels.get(topic), panel, topic)

    def test_profession_and_economy_commands_have_a_panel(self):
        panels = {e["topic"]: e["station"] for e in self.catalog["entries"]}
        for topic, panel in [("BANK", "trade"), ("MAKEBLASTER", "workshop"), ("HACK", "slicer"),
                             ("DROIDSTAT", "droids"), ("DATAMEM", "datapad")]:
            match = [t for t in panels if t.split(" ")[0] == topic]
            self.assertTrue(match, topic)
            self.assertEqual(panels[match[0]], panel, topic)

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
