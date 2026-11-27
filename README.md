# LotJ-MudForge-Plugin

Legacy of the Jedi companion plugin for the MudForge NextGen runtime.

**Status: developer preview, not ready for player installation.** This snapshot
includes a native plugin ZIP builder, but no published release, MudForge repository
index (`plugins.json`), or `.mfp` server package. Don't import GitHub's **Download ZIP**
archive into MudForge or paste `src/lotj.lua` on its own: the main script needs
three separately registered Lua modules. The workflow below follows MudForge's
authoring guide, not a verified run of this plugin in the current client.[1]

## Load the source in the Plugin Editor

Use a MudForge client with multi-file plugin support and a disposable,
disconnected test world. The plugin tries to apply the **LOTJ Holocron** theme
when it starts, so don't use a world whose layout or appearance you want to keep
unchanged.

1. Open **Plugin Manager → Editor** and start a new plugin draft. Copy the
   contents of [`src/lotj.lua`](src/lotj.lua) into the **main script**, keeping
   its `plugin` metadata (`LOTJ Companion`, `0.1.0`). Do not add `lotj.lua` as
   a module.[1]
2. In the same draft's **Files** panel, add the following three files. Copy the
   contents from the same checkout and make sure the saved paths match exactly,
   including case and a single `.lua` extension (the editor can append it).[1]
   - [`src/widgets/lotj-status-bar.lua`](src/widgets/lotj-status-bar.lua)
   - [`src/widgets/lotj-comms-hub.lua`](src/widgets/lotj-comms-hub.lua)
   - [`src/widgets/lotj-ground-map.lua`](src/widgets/lotj-ground-map.lua)
3. Only after all three files are in place, use **Save & Run** (`Ctrl+Enter`)
   to save and enable the plugin. Check **Problems** and **Console** before
   testing any widgets. A `loadModule/dofile` error naming a missing file means
   you should check the exact path in **Files**, not add a second plugin.[1]

The `loadModule` paths are relative to the plugin, not your working directory.
The two HTML widgets embed their markup and styles in Lua; the standalone HTML
and CSS files in the checkout are not needed for this workflow.

## Build and import the preview ZIP

From the repository root with Python 3:

```sh
python3 scripts/build_preview_zip.py LOTJ-Companion-preview.zip
```

Open **Plugin Manager** in a disposable, disconnected test world and import the
generated `LOTJ-Companion-preview.zip`. Then follow the smoke checklist below.
The archive is tested offline; import and startup in MudForge are not yet verified.

MudForge's **Plugin Manager** can import a native multi-file plugin ZIP with
one root script and a same-named directory holding the modules. For example, a
`LOTJ Companion.zip` would contain these entries at its root, with no enclosing
repository folder:[1]

```text
LOTJ Companion.lua
LOTJ Companion/src/widgets/lotj-status-bar.lua
LOTJ Companion/src/widgets/lotj-comms-hub.lua
LOTJ Companion/src/widgets/lotj-ground-map.lua
```

`LOTJ Companion.lua` is a copy of `src/lotj.lua`; each module keeps its
`src/widgets/` path inside the matching directory. This native ZIP layout
is not the `.mfp` server-package format, and a release ZIP is not supplied
by this snapshot.[1]

## Manual smoke checklist

These are checks to run in the client, not results. No LOTJ login is needed
for the initial load and display checks.

1. In a fresh test world, check that the plugin is enabled, that startup reports
   no `PLUGIN ERROR`, and that **LOTJ Status Bar** renders its initial HP and MV
   labels and `0/0` values. Those defaults do not establish that GMCP works.
2. **LOTJ Comms Hub** and **LOTJ Ground Map** start hidden. For a visual check,
   set `visible = true` only in the relevant `createWidget` calls in a fresh
   test copy ([main script](src/lotj.lua) for Comms Hub,
   [map module](src/widgets/lotj-ground-map.lua) for Ground Map). Click a Comms
   tab and check that it changes and returns keyboard focus to the prompt. For
   the map, check that the widget opens and check the console; an empty map
   offline is not a failure. Saved visibility can override these defaults.[1]
3. Disable the test plugin when finished. Check that its widgets are no longer
   active, and restore your previous theme if the preview changed it.

## Current limits

- **Status bar:** The layout includes HP, movement, a conditional Force gauge,
  and ship and opponent rows. Live updates depend on GMCP and the HTML widget
  bridge, neither of which has been checked in the client. The Lua handlers send
  `enemyPercent`, but the embedded HTML reads `percent`, so the opponent gauge
  is not fully wired.
- **Comms Hub:** Tab UI and message handlers exist. Live chat ingestion, combat
  stats, and autopilot are not wired to game input in this snapshot.
- **Ground Map:** MudForge tracks the player's room. Text captures and map
  refreshes leave the native cursor in place. Offline fixtures cover room
  changes and click targets. Live tracking still needs a client check. The
  resize handler passes tables where MudForge expects separate numbers.[1]
- **Ship HUD, Tactical Radar, and Holocron Datapad:** Hidden placeholders; no
  functional radar, galaxy map, or datapad is provided.

## Offline development checks

From the repository root in Bash, with Git, Lua 5.4 (`lua` and `luac`), and Python 3:

```sh
git ls-files -z -- 'src/*.lua' | xargs -0 -n 1 luac -p
lua tests/ui_scaffold_smoke.lua
lua tests/ground_map_triggers.lua
python3 tests/ci/gmcp/test_validate.py -v
python3 scripts/ci/gmcp/validate.py src
python3 tests/test_combat_regex_fixtures.py -v
python3 tests/test_build_preview_zip.py -v
```

The [widget smoke](tests/ui_scaffold_smoke.lua) stubs the host calls and does
not run `src/lotj.lua` or the embedded JavaScript. The
[ground-map regression](tests/ground_map_triggers.lua) supplies fixture captures
and does not run the client, its regex engine, or a live mapper. Neither test
establishes that the plugin loads in MudForge. The regex suite exercises Python
`re`; the ZIP suite verifies packaging, not client import. See the
[architecture guide](docs/architecture.md) for module boundaries.

## Sources

[1] https://mudforge.org/docs/ai-plugin-guide.md — MudForge — AI Plugin & Library Authoring Guide
