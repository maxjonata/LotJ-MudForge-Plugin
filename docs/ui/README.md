# UI command catalog (FIG-01)

Every LotJ help topic has exactly one UI destination in [command-ui.json](command-ui.json).
The Figma file [LotJ Flight Deck](https://www.figma.com/design/di7gVGyxuNJgE6WZq6Li2g/LotJ-Flight-Deck)
draws the patterns and screens; screens are approved there before any plugin code is written.

| File | Role |
|---|---|
| `command-ui.json` | Generated. Kind, area, pattern, typed arguments per syntax variant, status, Figma frame. |
| `overrides.json` | Hand decisions by topic (`status`, `pattern`, `area`, `kind`, `note`). |
| `figma-nodes.json` | Figma frames and the help topics each one draws. A topic claimed by a frame becomes `designed`. |

Regenerate after changing any input:

```
python scripts/ui/build_catalog.py
python tests/test_command_ui_catalog.py -v
```

CI fails if a topic has no destination, the committed catalog is stale, or a frame link points at a node that is not in the export.

## Values

- **kind**: `command` (has syntax), `passive` (automatic skill), `reference` (no syntax line).
- **pattern**: `direct`, `target`, `form`, `flow`, `toggle`, `list`, `editor`, `craft`, `comms`, `readout`, `reference`, `palette`. Definitions are in the `patterns` table of the catalog.
- **status**: `planned` → `designed` once drawn; `gap` (no data source or API), `inactive` (help says it is no longer used), `restricted` (needs a role).

## Known limits

- Patterns are inferred from the syntax line. Each FIG phase reviews its area by hand and records corrections in `overrides.json`.
- 446 topics have no `Syntax:` line. Some of them are still commands described in prose (for example `NAVCOMMANDS`). The phase that owns the area moves them out of `reference` with an override.
- Responses to commands are not known without a live session; flows show them as pending until they are confirmed in game.

## Visual direction

- Old Star Wars computer terminal: amber phosphor on near-black by default, square corners, Share Tech Mono / Rajdhani / Bruno Ace SC, glow on active frames, tick rulers and segment bars (reference: Figma community file "Star Wars UI Library").
- Hardware language: every panel lives in a physical console — gunmetal hull with seams and vents, light-grey screen bezels with an LED pill and status dot, red vector screen art, white square keys, LED dashes and knobs on the deck (reference photo supplied by the user; section "05 · Console de ponte").
- Dense: spacing 2–16 px, text 10–13 px.
- Long text is an in-world object: the datapad is a floating window that minimizes to the window dock.
- Universal fallback: the command bar with fuzzy autocomplete. It is our own widget, because MudForge does not expose what is typed in its native command line; a choice can be handed to it with `focusPrompt(text)`.
- Themes: default amber, or the clan theme derived from the clan name colour (GMCP `CLAN`, colours set in game with `clancolorname`). Presets: amber, blue sensor, imperial red, green console.
- Ground map (FIG-03): holographic isometric map in the style of Star Wars Jedi: Fallen Order, built from MudForge mapper coordinates.

## Every control has a purpose

No loose decoration that looks like a control. Each key sends one real command (radar, proximity, chaff, launch, land, autopilot), each light shows a named state read from GMCP or confirmed text (shields up, hyper ready, target sent, unread channel), each toggle is a real on/off command (autopilot, headlights, cloak), and each display says its data source and age. Hull structure (vents, seams, rivets) is the only non-functional art.

## Console per theme

Each theme is a whole console, not a recolour: hull, bezels, screen art, keys and screen colour all change, while the screen layout and the components on them stay the same.

| Theme | Console | Used when |
|---|---|---|
| Neutral (default) | Freighter: warm grey ribbed hull with rivets, rounded CRT bezels with scanlines, amber screens, round coloured buttons and toggles | Default for everyone, and for any clan without its own console |
| Empire (clan) | Bridge: gunmetal hull with vents, light-grey bezels with LED pills, red vector screens, white square keys | Player in that clan chooses the clan UI |
| Other clans | One console each, designed when the in-game `clans` list (name and colour) is confirmed | Same rule |

The clan comes from GMCP (`CLAN`); its colour from the clan name colour set with `clancolorname`.
