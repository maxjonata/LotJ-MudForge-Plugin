"""Regression tests for the validator entry point used by CI."""

from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[3]
VALIDATOR = [sys.executable, str(ROOT / "scripts/ci/gmcp/validate.py")]


class ValidatorTests(unittest.TestCase):
    def run_lua(self, lua):
        with tempfile.TemporaryDirectory() as tmp:
            widgets = Path(tmp) / "src/widgets"
            widgets.mkdir(parents=True)
            (widgets / "plugin.lua").write_text(
                textwrap.dedent(lua).lstrip("\n"), encoding="utf-8"
            )
            return subprocess.run(
                VALIDATOR + ["src"], cwd=tmp, capture_output=True, text=True
            )

    def assert_valid(self, lua):
        result = self.run_lua(lua)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_invalid(self, lua, diagnostic, line):
        result = self.run_lua(lua)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        source = Path("src/widgets/plugin.lua")
        self.assertIn(f"{source}:{line}: {diagnostic}", result.stderr)

    def test_vitals_comment_and_documented_camel_case_pass(self):
        self.assert_valid('''
            -- GMCP handler: Char.Vitals (hp, maxHp, move, maxMove, mana, maxMana, wimpy)
            onGMCPUpdate("Char.Vitals", onVitals)
            function onVitals(packet)
                local values = {maxHp = packet.maxHp, maxMove = packet['maxMove']}
                values.force = packet.mana
                values.maxForce = packet.maxMana
                return values
            end
        ''')

    def test_ship_registration_and_documentation_pass(self):
        self.assert_valid('''
            -- Empty Ship.Info: hide the ship row
            onGMCPUpdate(
                'Ship.Info',
                function (packet)
                    if not packet or next(packet) == nil then return end
                    return packet.maxHull, packet[ [=[maxSpeed]=] ], packet.posZ
                end
            )
        ''')

    def test_comments_and_embedded_html_are_not_lua_calls_or_members(self):
        self.assert_valid('''
            -- setBoundValues({}) and addTrigger("^fake$")
            --[=[
              onGMCPUpdate("Ship.Info", function(p) return p.unknown end)
              drawRect()
            ]=]
            local html = [==[
              <script>setBoundValues(data.force);</script>
            ]==]
            function onGMCPUpdateCharVitals(data)
                -- data.force and data['maxForce'] are not keys
                local note = "data.maxhp -- not a field access"
                return html, note, data.hp
            end
        ''')

    def test_vitals_rejects_forbidden_dot_and_literal_bracket_keys(self):
        for field, access in (
            ("force", "payload.force"),
            ("maxForce", "payload[\"maxForce\"]"),
            ("maxhp", "payload\n    .maxhp"),
            ("maxmove", "payload -- comment\n    [\"maxmove\"]"),
        ):
            with self.subTest(field=field):
                self.assert_invalid(
                    f'function onGMCPUpdateCharVitals(payload)\n  return {access}\nend\n',
                    f"Char.Vitals: unsupported field '{field}'",
                    2 + access.count("\n"),
                )

    def test_unknown_ship_field_in_multiline_inline_handler_fails(self):
        self.assert_invalid('''
            onGMCPUpdate -- registration starts here
            (
              'Ship.Info', -- no field names on the registration line
              function (ship)
                if ship.hull then
                    return ship["unknown"]
                end
              end
            )
        ''', "Ship.Info: unsupported field 'unknown'", 6)

    def test_invalid_named_handler_bound_by_multiline_registration_fails(self):
        self.assert_invalid('''
            local function receive(payload)
              return payload.maxForce
            end
            onGMCPUpdate(
              "Char.Vitals",
              receive
            )
        ''', "Char.Vitals: unsupported field 'maxForce'", 2)

    def test_non_gmcp_tables_and_unrelated_event_payloads_pass(self):
        self.assert_valid('''
            onGMCPUpdate("Room.Info", function(data) return data.force end)
            function onGMCPUpdateCharVitals(data)
                local values = { force = data.mana }
                return values.force, values.maxForce, data.maxHp
            end
        ''')

    def test_real_set_bound_values_call_fails(self):
        self.assert_invalid('''
            setBoundValues
              ({ maxHp = 9 })
        ''', 'use sendWidgetMessage instead of setBoundValues for LOTJ widgets', 1)

    def test_multiline_regex_and_default_substring_triggers_pass(self):
        self.assert_valid('''
            addTrigger("^You enter (.*?)%.$", function(line)
                if line then return line end
            end, true)
            addTrigger('^Hello$', function() end, { type = 'regex' })
            addTrigger('A burst of chaff is released', function() end)
        ''')

    def test_anchored_trigger_without_regex_mode_fails(self):
        self.assert_invalid('''
            addTrigger
              ('^Hello$', function() end)
        ''', 'anchored addTrigger pattern needs explicit regex mode', 1)

    def test_first_draw_before_activation_fails(self):
        self.assert_invalid('''
            drawRect(1, 2, 3, 4)
            setActiveWidget(radar)
        ''', 'drawRect appears before any setActiveWidget call in this file', 1)

    def test_canvas_gauge_api_call_fails(self):
        self.assert_invalid('''
            local radar = createWidget({ type = 'canvas' })
            setGauge(radar, 'shield', 5)
        ''', 'setGauge is HTML-only; this file creates only canvas widgets', 2)


if __name__ == "__main__":
    unittest.main()
