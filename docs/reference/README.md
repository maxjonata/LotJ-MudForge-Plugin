# LotJ command reference

`lotj-commands.json` holds metadata for the public LotJ help topics: topic,
keywords, syntax lines, see-also links, the official URL and `inferred_tags`.
The tags are search aids guessed from the text, not game facts. The help text
itself is not copied here; read it at each topic's `url`.

UI buttons, menus and the command palette use only commands listed here. A
feature with no listed command stays marked as research on the roadmap.

## Regenerate

1. Cache the public help pages locally (the `.cache/` folder is gitignored),
   one file per topic, each starting with `<!-- source: <url> -->`.
2. Run:

```sh
python scripts/reference/extract_help.py .cache/referencia/raw/lotj-help docs/reference/lotj-commands.json
python tests/test_extract_help.py -v
```
