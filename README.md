# LotJ-MudForge-Plugin

Legacy of the Jedi companion plugin for the MudForge NextGen runtime.

**Status: developer preview, not ready for player installation.** This snapshot
includes a native plugin ZIP builder, but no published release, MudForge repository
index (`plugins.json`), or `.mfp` server package. Don't import GitHub's **Download ZIP**
archive into MudForge or paste `src/lotj.lua` on its own: the main script needs
the separately registered Lua modules listed below. The installation
workflow follows MudForge's authoring guide.[1]

## Load the source in the Plugin Editor

Use a MudForge client with multi-file plugin support and a disposable,
disconnected test world. The plugin tries to apply the **LOTJ Holocron** theme
when it starts, so don't use a world whose layout or appearance you want to keep
unchanged.

1. Open **Plugin Manager → Editor** and start a new plugin draft. Copy the
   contents of [`src/lotj.lua`](src/lotj.lua) into the **main script**, keeping
   its `plugin` metadata (`LOTJ Companion`, `0.2.0`). Do not add `lotj.lua` as
   a module.[1]
2. In the same draft's **Files** panel, add the following files. Copy the
   contents from the same checkout and make sure the saved paths match exactly,
   including case and a single `.lua` extension (the editor can append it).[1]
   - [`src/widgets/lotj-status-bar.lua`](src/widgets/lotj-status-bar.lua)
   - [`src/widgets/lotj-comms-hub.lua`](src/widgets/lotj-comms-hub.lua)
   - [`src/domain/chat-line.lua`](src/domain/chat-line.lua)
   - [`src/widgets/lotj-ground-map.lua`](src/widgets/lotj-ground-map.lua)
   - [`src/domain/ship-position.lua`](src/domain/ship-position.lua)
   - [`src/domain/radar-scan.lua`](src/domain/radar-scan.lua)
   - [`src/domain/public-galaxy.lua`](src/domain/public-galaxy.lua)
   - [`src/application/scrapper-cockpit.lua`](src/application/scrapper-cockpit.lua)
   - [`src/domain/target-lock.lua`](src/domain/target-lock.lua)
   - [`src/application/target-cockpit.lua`](src/application/target-cockpit.lua)
   - [`src/widgets/lotj-scrapper-cockpit.lua`](src/widgets/lotj-scrapper-cockpit.lua)
3. Only after all eleven files are in place, use **Save & Run** (`Ctrl+Enter`)
   to save and enable the plugin. Check **Problems** and **Console** before
   testing any widgets. A `loadModule/dofile` error naming a missing file means
   you should check the exact path in **Files**, not add a second plugin.[1]

The `loadModule` paths are relative to the plugin, not your working directory.
The HTML widgets embed their markup and styles in Lua; the standalone HTML
and CSS files in the checkout are not needed for this workflow.

## Build and import the preview ZIP

From the repository root with Python 3:

```sh
python3 scripts/build_preview_zip.py LOTJ-Companion-preview.zip
```

Open **Plugin Manager** in a disposable, disconnected test world and import the
generated `LOTJ-Companion-preview.zip`. Then follow the smoke checklist below.
The previous preview was imported into MudForge 2.0.6762 and confirmed to
show live HP and movement. Use the checklist below when testing a new ZIP.

MudForge's **Plugin Manager** can import a native multi-file plugin ZIP with
one root script and a same-named directory holding the modules. For example, a
`LOTJ Companion.zip` would contain these entries at its root, with no enclosing
repository folder:[1]

```text
LOTJ Companion.lua
LOTJ Companion/src/widgets/lotj-status-bar.lua
LOTJ Companion/src/widgets/lotj-comms-hub.lua
LOTJ Companion/src/domain/chat-line.lua
LOTJ Companion/src/widgets/lotj-ground-map.lua
LOTJ Companion/src/domain/ship-position.lua
LOTJ Companion/src/domain/radar-scan.lua
LOTJ Companion/src/domain/public-galaxy.lua
LOTJ Companion/src/application/scrapper-cockpit.lua
LOTJ Companion/src/domain/target-lock.lua
LOTJ Companion/src/application/target-cockpit.lua
LOTJ Companion/src/widgets/lotj-scrapper-cockpit.lua
```

`LOTJ Companion.lua` is a copy of `src/lotj.lua`; each module keeps its
path inside the matching directory. This native ZIP layout
is not the `.mfp` server-package format, and a release ZIP is not supplied
by this snapshot.[1]

## Manual smoke checklist

These are checks to run in the client, not results. No LOTJ login is needed
for the initial load and display checks.

1. In a fresh test world, check that the plugin is enabled, that startup reports
   no `PLUGIN ERROR`, and that **LOTJ Status Bar** renders its initial HP and MV
   labels and `0/0` values. Those defaults do not establish that GMCP works.
2. Type `/lotj-nav` to open **LOTJ Navigation**. `/lotj-cockpit` also works.
   In **Map**, select **Open ground map** to show the native ground map.
   **Comms** opens the separate Comms Hub. **Galaxy** lists the public systems
   and their coordinates offline. Use **Fit** if an older saved layout leaves
   the panel too small to see the radar.
3. On **System**, check the range buttons and the separate X, Y, and Z axes.
   While disconnected, **Radar** and **Proximity** show a connection notice.
   In a ship cockpit or turret, click **Radar** and check that the objects in
   the completed readout appear at their relative positions. **Proximity**
   sends the game's text readout to the terminal.[2] Click a ship contact to
   open the target panel, then check that **Target** warns once before sending
   `target <ship>`, and that **Face** and **Fire** send one command each.
4. Disable the test plugin when finished. Check that its widgets are no longer
   active, and restore your previous theme if the preview changed it.

## Current limits

- **Status bar:** The layout includes HP, movement, a conditional Force gauge,
  and ship and opponent rows. HP and movement have been checked in a live
  client session. The opponent row receives the name without colour codes and
  `percent` from `Char.Enemy`; it still needs a live combat check.
- **Comms Hub:** Recognized Local, CommNet, Clan, Broadcast, OOC, Tell, and
  Imm lines appear in All and their channel tab. The hub keeps the most recent
  250 lines per tab and resets history on a new connection. Opening a channel
  clears its unread count. The terminal keeps the original line. Offline tests
  use formats from the [community chat triggers](https://github.com/LotJ/lotj-mudlet-ui/blob/dc6ae9c471c6aa8e4dcfdb4814b79a4cc0c3753c/src/triggers/chat/triggers.json).
  Live channel verification, Debug, combat stats, and autopilot are pending.
- **Ground Map:** MudForge tracks the player's room. Text captures and map
  refreshes leave the native cursor in place. Offline fixtures cover room
  changes, click targets, and the resize handler. Live tracking still needs a
  client check.[1]
- **Navigation:** **System** projects relative X/Y/Z onto an isometric radar.
  The range buttons filter by three-dimensional distance. Select a dot or
  contact to inspect its height difference. **Radar** processes a complete
  manual readout using the format observed in the community Mudlet package.[3]
  The terminal protocol carries no request ID. The plugin waits briefly for
  trailing contact rows and discards late rows while a timed-out scan drains.
  A scan displays at most 256 contacts and reports truncation. After a known
  system change, request Radar to establish the new origin before live
  coordinates resume. The successful ship scan path still needs a live LotJ
  check. **Galaxy** uses
  the public catalogue verified on 2026-11-27 and highlights a matching
  `Ship.System` position when available.[4] **Map** opens MudForge's native
  map in its own widget.
- **Target cockpit (NAV-08):** Clicking a radar ship selects it. The panel shows
  distance, bearing, elevation and ΔX/ΔY/ΔZ, and the radar draws a reticle.
  **Target**, **Face** and **Fire** (best weapon or one of the eight weapon
  types in HELP FIRE) each send one documented command. Because HELP TARGET
  calls targeting an aggressive act, **Target** asks for a second click per ship.
  The help documents no reply messages, so the panel shows "Target sent ·
  unconfirmed" instead of a confirmed lock. Geometry uses the last radar
  readout, and a ship missing from a new readout is shown as lost. Whether we
  are in an enemy's sights (NAV-09) is still under research.
- **Ship HUD and Holocron Datapad:** Hidden placeholders.

## Offline development checks

From the repository root in Bash, with Git, Lua 5.1 and/or 5.4 (`lua` and `luac`), Node.js, and Python 3. MudForge runs Lua 5.1, and CI runs every Lua check on both versions:

```sh
git ls-files -z -- 'src/*.lua' | xargs -0 -n 1 luac -p
lua tests/run.lua --coverage
lua tests/coverage.lua
node tests/comms_hub_widget.js
node tests/scrapper_cockpit_widget.js
node tests/target_cockpit_widget.js
python3 tests/ci/gmcp/test_validate.py -v
python3 scripts/ci/gmcp/validate.py src
python3 tests/test_combat_regex_fixtures.py -v
python3 tests/test_build_preview_zip.py -v
```

`tests/run.lua` runs every tracked `tests/**/*_spec.lua` in its own process and
exits non-zero if any fails; pass a substring to run a subset
(`lua tests/run.lua cockpit`). Specs load modules with a custom environment
through [`tests/support/load_env.lua`](tests/support/load_env.lua), which works
on Lua 5.1 and 5.4.

`--coverage` records which `src/` lines the specs run; `tests/coverage.lua`
prints per-file line coverage and fails if the total drops below this Lua
version's floor in [`tests/coverage-floor.txt`](tests/coverage-floor.txt).
Executable lines come from `luac -l -l` (set `LUAC` if the compiler has another
name). When a change raises coverage, run `lua tests/coverage.lua --update` on
each version and commit the new floor; the floor never goes down. Specs that
need the client use the recording host in
[`tests/support/fake_host.lua`](tests/support/fake_host.lua).

The [widget smoke](tests/ui_scaffold_smoke_spec.lua) stubs the host calls and does
not run `src/lotj.lua` or the embedded JavaScript. The
[ground-map regression](tests/ground_map_triggers_spec.lua) supplies fixture captures
and does not run the client, its regex engine, or a live mapper. Neither test
establishes that the plugin loads in MudForge. The regex suite exercises Python
`re`; the ZIP suite verifies packaging, not client import. See the
[architecture guide](docs/architecture.md) for module boundaries.

The [cockpit regression](tests/scrapper_cockpit_spec.lua) exercises module loading,
GMCP dispatch, grouped terminal readouts, the HTML message interface, and
manual scan requests against a stubbed host. The JavaScript test checks the
view controls and projection of different elevations.

## Sources

[1] https://mudforge.org/docs/ai-plugin-guide.md — MudForge — AI Plugin & Library Authoring Guide

[2] https://www.legendsofthejedi.com/help?topic=SPACE+SHIP+SHIPS+FLIGHT — Legends of the Jedi ship command help

[3] https://github.com/LotJ/lotj-mudlet-ui/tree/dc6ae9c471c6aa8e4dcfdb4814b79a4cc0c3753c/src/triggers/system-map — LotJ Mudlet radar readout patterns

[4] https://www.legendsofthejedi.com/galaxy-map — Public galaxy map
