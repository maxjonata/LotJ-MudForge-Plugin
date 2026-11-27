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
