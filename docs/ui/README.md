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

## RP log is one timeline

Say, emote and comms share one chronological log. They differ only by layout signals, never by recolouring the game's ANSI text: say has a speaker-name column, emotes are indented narration, comms (tell, clan, ship) get a faint band, a channel-coloured left bar and a short tag, and OOC/system lines are small and dim. Chips filter each kind; CommNet 0 keeps its own tab.

## Screen layout (desktop 1440)

Status strip on top; left 340 px = room panel on the ground or the current station at the helm; centre = RP log (flexible, never covered by fixed panels); right 380 px = holographic map on the ground or radar + target cockpit at the helm; bottom = command bar with autocomplete and the window dock. Taking the helm (GMCP) swaps the left and right panels; the RP log stays put. Everything else opens as a floating window that docks. Side panels collapse; below 1280 px the right panel becomes a tab.

## Required elements (check every screen that shows the piece)

Shared pieces are Figma components; screens use instances, never redrawn copies.

- **Radar 3D** (component "Radar 3D · painel"): source + age + range; three range rings; our ship with the commanded-course arrow (SHIPHEAD); every contact with a Δz stem from our plane; trail dots; dashed estimated heading only after two readings, "hdg ?" otherwise; planets in green; selected target ringed in red; view filters (ships, planets, missiles); contact list with distance and Δz sharing the selection; RADAR, PROX, CHAFF keys and range; translucent LEGEND button whose tooltip (on hover) holds the legend.
- **Target cockpit**: state (none, selected, sent, lost); name, distance, Δz, heading; TARGET (confirm once per ship), FACE, FIRE ▾ (only when sent) with weapon list; lost = actions grey + RADAR.
- **Room panel**: name, area/planet, description, people/ships/objects with ☰ menus, exit list: direction, destination name from the mapper, door state, PEEK (scan <dir>) with the result and its age; no compass (the numpad already moves), actions, source + age.
- **RP log**: one timeline; say name column; indented emotes; comms band + channel bar + tag; own-line marker; dim OOC/system; filter chips with unread; game ANSI colours untouched.
- **Holo map**: area name, explored %, deck selector, you, a dotted trail of your last 3 steps fading from your room to nothing, explored/seen rooms, open/locked exits, turbolift, faded other deck, translucent LEGEND button with the legend as a hover tooltip, places list, controls.
- **Datapad**: a physical device window (casing, screen, lit hardware keys, BIO LOCK and RX lights) with FILES (slots; view, edit with to/from/subject, send, show, copy, download, eject, delete), INBOX (receive), DISKS (load), SECURITY (setbiometrics) and STATUS (datastat); docks with [_].
- **Legends** are never a fixed panel: always a translucent LEGEND button with the legend in a hover tooltip.
