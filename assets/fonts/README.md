# Fonts

`AurebeshAF-Canon.otf` is **Aurebesh AF — Canon** by AurekFonts. Its own name
table states the licence: "CC-0 public domain, created by AurekFonts", so it can
be embedded and redistributed in the plugin.

The widgets do not load this file directly: `scripts/ui/embed_font.py` turns it
into `src/widgets/lotj-ui-font.lua` (a base64 data URI) because an HTML widget
is its own page and cannot read plugin files. Rerun the script after replacing
the font; `tests/test_embed_font.py` fails if the two drift apart.

Other Aurebesh fonts on the designer's machine (`Aurebesh.ttf` by Neale
Davidson, "All Rights Reserved"; `Aurebesh-Droid.ttf`, no licence stated) must
not be shipped.
