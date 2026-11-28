# Figma card generators

`python scripts/ui/figma/fig04.py` writes one SVG per console card into `out/` (ignored). Each key is one command of a catalog station; its label and hint come from the help syntax in `docs/ui/command-ui.json`. The SVGs carry the depth look (gradient caps, glow and shadow filters) and are imported into the Figma file with Figwright `import_svg`.
