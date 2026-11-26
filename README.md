# LotJ-MudForge-Plugin

Legacy of the Jedi companion plugin for MudForge NextGen Runtime.

## Widgets

| Widget | Type | Description |
|--------|------|-------------|
| `lotj-status-bar` | HTML | 2-row live status bar with HP/MV/Force/Mana gauges, wimpy tick overlay, conditional Ship.Info row, comlink indicator, opponent bar |
| `lotj-comms-hub` | HTML | Tabbed chat + automation drawer (All, Local, CommNet, Clan, Broadcast, OOC, Tell, Imm, Stats, AutoPilot) |
| `lotj-ground-map` | Map | Ground mapper using MudForge Mapper API |
| `lotj-space-canvas` | Canvas | System radar & galaxy map (toggled via header tabs) |

## API Corrections (from @ui-ux-designer audit)

- `addTimer` takes `(intervalMs, callback, repeating?)` — **no name string**, milliseconds not seconds
- `window.mudforge.hasFocus("prompt")` does **not** exist — assert prompt focus on the host input element after `focusPrompt()`
- `setGauge`/`setGauges` are HTML-widget-only — calling them on canvas triggers PLUGIN WARNING
- Every `data-mud-action` handler must call `focusPrompt()` at the end

## Setup

1. Clone the LotJ Mudlet UI repo: `https://github.com/LotJ/lotj-mudlet-ui`
2. Extract trigger/alias patterns from `combatstats.mpackage` and `src/triggers/`
3. Port regex patterns to MudForge `addTrigger(pattern, callback, { type = "regex" })`
4. Port alias patterns to MudForge `addAlias(pattern, callback)`
5. Port Numpad bindings to `addMacro` (not `addAlias`)

## Development checks

Run the same checks as GitHub Actions from the repository root in Bash. Use Git,
Lua 5.4 (`lua` and `luac`; CI uses 5.4.8), and Python 3. No Python packages or
MudForge installation are needed.

```bash
git ls-files -z -- 'src/*.lua' | xargs -0 -n 1 luac -p
lua tests/ui_scaffold_smoke.lua
lua tests/ground_map_triggers.lua
python3 tests/ci/gmcp/test_validate.py -v
python3 scripts/ci/gmcp/validate.py src
python3 tests/test_combat_regex_fixtures.py -v
python3 tests/test_build_preview_zip.py -v
```

The widget tests stub MudForge APIs and use fabricated gameplay inputs. The
regex fixtures exercise Python `re`, not MudForge's regex engine. The ZIP test
builds the archive and checks its contents, but does not import it into MudForge.
These checks do not connect to LOTJ or validate the live MudForge runtime.
