"""Tiny SVG builder for LotJ console cards, in the FIG-02/03 palette.

Shapes are written so classify.py can later give them the Depth styles:
casing = first full-size rect, keys = 16-60px rects with an uppercase label inside,
lights = 10px circles, insets = dark rects.
"""
import json
import os
import re
from xml.sax.saxutils import escape

PAL = {
    "casing": "#2f2c27", "casing_s": "#5c574e", "inset": "#1a1208", "inset_s": "#6b665c", "screen": "#14120f",
    "key": "#2a2723", "amber": "#f0b13a", "red": "#e5674e", "blue": "#6fb2e6", "green": "#7fd36b", "white": "#d9d3c6",
    "dim": "#8a8478", "faint": "#6b665c", "sub": "#8a7a50", "text": "#e8d9b5", "hi": "#ffe7b0", "off": "#4a463f",
}
CATALOG = None

CAPS = {"amber": ("#ffdb80", "#ff9e1f", "#b35905", "1 0.62 0.12"), "red": ("#ff9980", "#eb2e24", "#800d0a", "0.92 0.18 0.14"),
        "blue": ("#a6e0ff", "#3399ff", "#0d4099", "0.2 0.6 1"), "white": ("#ffffff", "#d9e0e6", "#80878f", "0.85 0.88 0.9"),
        "green": ("#b3ffbf", "#33d966", "#0d732e", "0.2 0.85 0.4"), "off": ("#37393b", "#393c40", "#1d1e20", None)}


def _filter(fid, glow):
    g = ""
    if glow:
        g = (f'<feOffset in="SourceAlpha"/><feGaussianBlur stdDeviation="5"/><feColorMatrix type="matrix" '
             f'values="0 0 0 0 {glow.split()[0]} 0 0 0 0 {glow.split()[1]} 0 0 0 0 {glow.split()[2]} 0 0 0 0.55 0"/>'
             f'<feBlend mode="normal" in2="BackgroundImageFix" result="e1"/>')
    first = "e1" if glow else "BackgroundImageFix"
    return (f'<filter id="{fid}" x="-30%" y="-50%" width="160%" height="220%" color-interpolation-filters="sRGB">'
            f'<feFlood flood-opacity="0" result="BackgroundImageFix"/>{g}'
            f'<feOffset in="SourceAlpha" dy="3"/><feGaussianBlur stdDeviation="1"/>'
            f'<feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.8 0"/>'
            f'<feBlend mode="normal" in2="{first}" result="e2"/>'
            f'<feOffset in="SourceAlpha" dy="-1"/><feColorMatrix type="matrix" values="0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 0 0 0 0.35 0"/>'
            f'<feBlend mode="normal" in2="e2" result="e3"/><feBlend mode="normal" in="SourceGraphic" in2="e3"/></filter>')


def defs(used):
    out = []
    for name, (top, mid, low, glow) in CAPS.items():
        if name not in used:
            continue
        out.append(f'<linearGradient id="g{name}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
                   f'<stop offset="0.45" stop-color="{mid}"/><stop offset="1" stop-color="{low}"/></linearGradient>')
        out.append(_filter("f" + name, glow))
    out.append('<filter id="fcase" x="-10%" y="-10%" width="120%" height="130%" color-interpolation-filters="sRGB">'
               '<feFlood flood-opacity="0" result="BackgroundImageFix"/><feOffset in="SourceAlpha" dy="10"/><feGaussianBlur stdDeviation="9"/>'
               '<feColorMatrix type="matrix" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.55 0"/><feBlend mode="normal" in2="BackgroundImageFix" result="e1"/>'
               '<feBlend mode="normal" in="SourceGraphic" in2="e1"/></filter>')
    return "<defs>" + "".join(out) + "</defs>"


def catalog():
    global CATALOG
    if CATALOG is None:
        CATALOG = json.load(open(os.path.join(os.path.dirname(__file__), "..", "..", "..", "docs", "ui", "command-ui.json"), encoding="utf-8"))
    return CATALOG


class Svg:
    def __init__(self, w, h):
        self.w, self.h, self.parts, self.used = w, h, [], set()

    def rect(self, x, y, w, h, fill, stroke=None, r=0, dash=None, opacity=None):
        a = f'<rect x="{x}" y="{y}" width="{w}" height="{h}"' + (f' rx="{r}"' if r else "") + f' fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}"'
        if dash:
            a += f' stroke-dasharray="{dash}"'
        if opacity is not None:
            a += f' fill-opacity="{opacity}"'
        self.parts.append(a + "/>")

    def key(self, x, y, w, h, col, label, hint):
        """Lit square key: gradient cap, glow, drop shadow, Aurebesh label (Basic on hover), dark ink hint."""
        self.used.add(col)
        self.parts.append(f'<g filter="url(#f{col})"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="3" fill="url(#g{col})"/></g>')
        ink = "#7f7a6d" if col == "off" else "#14120f"
        self.parts.append(f'<text x="{x + 7}" y="{y + 13}" font-family="Aurebesh AF" font-size="8" fill="{ink}">{escape(label)}</text>')
        if hint:
            self.parts.append(f'<text x="{x + 7}" y="{y + 26}" font-size="8" fill="{ink}" fill-opacity="0.75">{escape(hint)}</text>')

    def light(self, cx, cy, col):
        c = "off" if col == "off" else col
        self.used.add(c)
        self.parts.append(f'<g filter="url(#f{c})"><circle cx="{cx}" cy="{cy}" r="5" fill="url(#g{c})"/></g>')

    def casing(self, x, y, w, h):
        self.parts.append(f'<g filter="url(#fcase)"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="#2f2c27" stroke="#5c574e"/></g>')

    def circle(self, cx, cy, r, fill, stroke=None):
        a = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"'
        if stroke:
            a += f' stroke="{stroke}"'
        self.parts.append(a + "/>")

    def line(self, x1, y1, x2, y2, stroke, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}"{d}/>')

    def text(self, x, y, s, size=10, fill=PAL["text"], font="Share Tech Mono", anchor="start"):
        ff = "" if font == "Share Tech Mono" else f' font-family="{font}"'
        an = "" if anchor == "start" else f' text-anchor="{anchor}"'
        self.parts.append(f'<text x="{x}" y="{y + size}"{ff} font-size="{size}" fill="{fill}"{an}>{escape(s)}</text>')

    def svg(self):
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}" font-family="Share Tech Mono">' + defs(self.used) + "".join(self.parts) + "</svg>"


def _cmd_tokens(syn):
    out = []
    for t in syn.replace("/", " / ").split():
        t2 = t.strip("'\"")
        if re.fullmatch(r"[A-Za-z][A-Za-z_-]*", t2):
            out.append(t2.lower())
        else:
            break
    return out


def label_and_hint(entry):
    """Label = command words shared by the help's syntax lines; hint = subcommands or placeholders (never invented)."""
    syns = [v["syntax"] for v in entry["variants"]] or [entry["topic"].split(" ")[0].strip("'\"")]
    toks = [_cmd_tokens(x) for x in syns]
    toks = [t for t in toks if t] or [[entry["topic"].split(" ")[0].strip("'\"").lower()]]
    common = toks[0]
    for t in toks[1:]:
        n = 0
        while n < min(len(common), len(t)) and common[n] == t[n]:
            n += 1
        common = common[:n] or common[:1]
    if common and common[0] in ("feel", "cast") and len(toks[0]) > 1:
        common = toks[0][1:] if len(toks) == 1 else common[1:] or toks[0][1:]
    label = " ".join(common).upper()[:20]
    subs = []
    for t in toks:
        nxt = t[len(common) + (1 if toks[0][:1] in (["feel"], ["cast"]) else 0):]
        if nxt and nxt[0] not in subs:
            subs.append(nxt[0])
    if len(subs) > 1:
        hint = " · ".join(subs)
    else:
        first = re.sub(r"\(.*?\)", "", syns[0])
        m = re.search(r"[<\[]", first)
        hint = first[m.start():].strip() if m else ""
    return label, hint


def key_color(entry, station):
    p = entry["pattern"]
    if p == "toggle":
        return "blue"
    if station == "combat" and p == "target":
        return "red"
    if p == "target":
        return "white"
    return "amber"


def card(svg, x, y, w, title, subtitle, station, cols=3, extra_top=0, notes=(), filt=None, lights=()):
    """Console card with one key per command of a station. Returns the card height."""
    es = [e for e in catalog()["entries"] if e.get("station") == station and e["kind"] != "reference" and (filt is None or filt(e))]
    keys, seen = [], set()
    for e in es:
        if e["pattern"] == "readout":
            continue
        lab = label_and_hint(e)[0]
        if lab in seen:
            continue
        seen.add(lab)
        keys.append(e)
    passive = [e for e in es if e["pattern"] == "readout"]
    kw = (w - 28 - (cols - 1) * 8) / cols
    rows = (len(keys) + cols - 1) // cols
    h_keys = rows * 38
    h_pass = (14 + ((len(passive) + 1) // 2) * 13) if passive else 0
    h_lights = 22 if lights else 0
    h = 52 + extra_top + h_keys + (10 + h_pass if passive else 0) + h_lights + 16 + 13 * len(notes) + 18
    svg.casing(x, y, w, h)
    svg.rect(x + 10, y + 10, w - 20, 30, PAL["inset"], PAL["inset_s"], r=3)
    svg.text(x + 20, y + 17, title, 13, PAL["amber"], "Bruno Ace SC")
    svg.text(x + w - 20, y + 20, subtitle, 9, PAL["sub"], anchor="end")
    cy = y + 52 + extra_top
    for i, e in enumerate(keys):
        cx = x + 14 + (i % cols) * (kw + 8)
        ky = cy + (i // cols) * 38
        col = key_color(e, station)
        label, hint = label_and_hint(e)
        if e["pattern"] in ("form", "flow", "editor", "list", "craft", "comms"):
            label += " ▸"
        maxc = int((kw - 12) / 4.8)
        hint = hint if len(hint) <= maxc else hint[: maxc - 1] + "…"
        svg.key(round(cx, 1), ky, round(kw, 1), 32, col, label, hint or "")
    cy += h_keys
    if passive:
        cy += 6
        svg.rect(x + 14, cy, w - 28, h_pass, PAL["screen"], PAL["off"], r=3)
        svg.text(x + 22, cy + 3, "PASSIVE · read from score / skill output", 8, PAL["sub"])
        for i, e in enumerate(passive):
            svg.text(x + 22 + (i % 2) * ((w - 40) / 2), cy + 15 + (i // 2) * 13, "· " + e["topic"].split(" ")[0].strip("'\"").title(), 9, PAL["white"])
        cy += h_pass + 4
    if lights:
        lx = x + 18
        for name, col in lights:
            svg.light(lx + 5, cy + 9, col)
            svg.text(lx + 14, cy + 4, name, 8, PAL["white"])
            lx += 18 + len(name) * 5 + 18
        cy += h_lights
    cy += 6
    for n in notes:
        svg.text(x + 14, cy, n, 8, PAL["dim"])
        cy += 13
    svg.text(x + 14, y + h - 16, f"{len(es)} topics · station '{station}'", 8, PAL["faint"])
    return h


def bar(svg, x, y, w, label, value, maxv, col, src):
    bw = w - 200
    svg.text(x, y, label, 9, PAL["white"])
    svg.rect(x + 46, y + 2, bw, 8, PAL["screen"], PAL["off"], r=2)
    svg.rect(x + 46, y + 2, round(bw * value / maxv, 1), 8, PAL[col], r=2)
    svg.text(x + 52 + bw, y, f"{value}/{maxv}", 9, PAL[col])
    svg.text(x + w, y + 1, src, 7, PAL["faint"], anchor="end")
