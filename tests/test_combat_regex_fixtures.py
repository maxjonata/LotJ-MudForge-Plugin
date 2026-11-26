"""Test inherited draft log patterns against synthetic lines using Python re.

These patterns are not registered by the plugin. These tests do not validate
MudForge's regex engine, trigger registration, or real LOTJ log formats.
"""

import re
import unittest


# Name, pattern, example line, expected captures, and a nonmatching line.
CASES = (
    (
        "damage.weapon", r"^Your (.*?) (misses|barely scratches|hits|slams|strikes).*?\((.*?)\)$",
        "Your blaster hits the droid (42)", ("blaster", "hits", "42"),
        "Your blaster blocks the droid (42)",
    ),
    (
        "damage.direct", r"^You hit (.*?) for (\d+).*$",
        "You hit a scout for 35 damage.", ("a scout", "35"), "You hit a scout for no damage.",
    ),
    (
        "damage.miss", r"^Your attack on (.*?) misses\.$",
        "Your attack on the droid misses.", ("the droid",), "Your attack on the droid misses!",
    ),
    (
        "damage.dodge", r"^You dodge (.*?)'s attack\.$",
        "You dodge the guard's attack.", ("the guard",), "You dodge the guards' attack.",
    ),
    (
        "force.channel", r"^You channel the Force into (.*?)\.$",
        "You channel the Force into the crystal.", ("the crystal",),
        "A Jedi says: You channel the Force into the crystal.",
    ),
    (
        "force.power", r"^You use (.*?) Force power\.$",
        "You use Battle Meditation Force power.", ("Battle Meditation",),
        "You use Battle Meditation Force power again.",
    ),
    (
        "force.pool", r"^Your Force pool: (\d+)/(.*?)$",
        "Your Force pool: 32/90", ("32", "90"), "Your Force pool: full/90",
    ),
    (
        "ship.damage", r"^Your ship takes (\d+) damage from (.*?)\.$",
        "Your ship takes 24 damage from a laser.", ("24", "a laser"),
        "Your ship takes heavy damage from a laser.",
    ),
    (
        "ship.hull", r"^Your hull integrity: (\d+)%\.$",
        "Your hull integrity: 91%.", ("91",), "Your hull integrity: 91 percent.",
    ),
    (
        "ship.shields", r"^Your shields: (\d+)% \| Recharging in (\d+)s\.$",
        "Your shields: 20% | Recharging in 8s.", ("20", "8"),
        "Your shields: 20% / Recharging in 8s.",
    ),
    (
        "prompt.with_force",
        r"^HP: (\d+)/(\d+)\s+MV: (\d+)/(\d+)\s+Mana: (\d+)/(\d+)\s+Force: (\d+)/(\d+)$",
        "HP: 100/120  MV: 40/90 Mana: 0/0 Force: 12/30",
        ("100", "120", "40", "90", "0", "0", "12", "30"),
        "HP: 100/120  MV: 40/90 Mana: 0/0",
    ),
    (
        "prompt.without_force", r"^HP: (\d+)/(\d+)\s+MV: (\d+)/(\d+)\s+Mana: (\d+)/(\d+)$",
        "HP: 18/100 MV: 32/50 Mana: 0/0", ("18", "100", "32", "50", "0", "0"),
        "HP: 18/100 MV: 32/50 Mana: 0/0 Force: 12/30",
    ),
    (
        "faction.standing", r"^Your standing with (.*?) is now (\d+).*$",
        "Your standing with New Republic is now 3 points.", ("New Republic", "3"),
        "Your standing with New Republic is now neutral.",
    ),
    (
        "faction.alert", r"^Faction alert: (.*?) has declared (.*?)\.$",
        "Faction alert: New Republic has declared peace.", ("New Republic", "peace"),
        "Faction news: New Republic has declared peace.",
    ),
    (
        "faction.mission", r"^New mission available: (.*?)\.$",
        "New mission available: Cargo delivery.", ("Cargo delivery",), "Mission complete: Cargo delivery.",
    ),
    (
        "crafting.start", r"^You begin crafting (.*?)\.$",
        "You begin crafting a comlink.", ("a comlink",), "You stop crafting a comlink.",
    ),
    (
        "crafting.progress", r"^Your craft of (.*?) is (\d+)% complete\.$",
        "Your craft of a comlink is 75% complete.", ("a comlink", "75"),
        "Your craft of a comlink is nearly complete.",
    ),
    (
        "crafting.success", r"^You successfully craft (.*?)\.$",
        "You successfully craft a comlink.", ("a comlink",), "You fail to craft a comlink.",
    ),
    (
        "crafting.failure", r"^Your craft of (.*?) fails\.$",
        "Your craft of a comlink fails.", ("a comlink",), "Your craft of a comlink succeeds.",
    ),
)


class DraftLogRegexTests(unittest.TestCase):
    def test_expected_capture_groups(self):
        for name, pattern, sample, expected, _ in CASES:
            with self.subTest(pattern=name):
                match = re.search(pattern, sample)
                if match is None:
                    self.fail(f"expected pattern to match {sample!r}")
                self.assertEqual(match.span(), (0, len(sample)))
                self.assertEqual(match.groups(), expected)

    def test_rejects_nonmatching_lines(self):
        for name, pattern, _, _, nonmatch in CASES:
            with self.subTest(pattern=name):
                self.assertIsNone(re.search(pattern, nonmatch))


if __name__ == "__main__":
    unittest.main()
