# LOTJ MudForge Plugin

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

## Development

```bash
# Lint
lua-check src/

# Unit tests
lua-test-runner tests/unit/

# Integration tests (headless MudForge)
npm run test:integration
```
