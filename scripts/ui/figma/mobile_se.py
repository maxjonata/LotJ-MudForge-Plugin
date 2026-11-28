"""Phone screens sized for the smallest supported phone: iPhone SE, 375x667 pt.

Rules (FIG-07):
- every text is 11 pt or larger; the game log is 13 pt;
- every touch target is 44 pt tall or taller;
- keys show the Basic label (no hover on touch); Aurebesh stays a desktop setting;
- two states: KEYS (keyboard closed: log, 9 keys, command line, 5 tabs) and
  TYPING (iOS keyboard open, 260 pt: status strip, log, suggestions, command line).
Labels and hints come from the help catalog (svgkit.label_and_hint), never invented.
"""
import os
from xml.sax.saxutils import escape

from svgkit import Svg, PAL, catalog, label_and_hint, key_color

OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)

W, H, M = 375, 667, 12
NOTE_H = 48
KB_Y = H - 260          # iOS keyboard (216) + QuickType bar (44)
TAB_Y, TAB_H = H - 49, 44
CMD_Y, CMD_H = TAB_Y - 52, 44
KEY_H, GAP = 44, 8
LOG = [("Ruhn", PAL["hi"]), ('"Bay fee is fifty credits, pilot."', PAL["text"]),
       ("Ruhn taps the terminal.", "#cfa45a"), ("you", PAL["green"]),
       ('"Put it on the Lucky Dice\'s tab."', PAL["text"]),
       ("Kessa Vorr laughs and leans", "#cfa45a"), ("on the ramp.", "#cfa45a")]


class Phone(Svg):
    def __init__(self, title, right=""):
        super().__init__(W, H + NOTE_H)
        self.parts.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="{PAL["casing"]}" stroke="{PAL["casing_s"]}"/>')
        self.rect(0, 0, W, 20, "#000000")
        self.text(M, 4, "9:41", 11, PAL["white"])
        self.text(W - M, 4, "iPhone SE · 375×667", 11, PAL["dim"], anchor="end")
        self.rect(M, 24, W - 2 * M, 28, PAL["inset"], PAL["inset_s"], r=3)
        self.text(M + 8, 30, title, 13, PAL["amber"], "Bruno Ace SC")
        if right:
            self.text(W - M - 8, 31, right, 11, PAL["dim"], anchor="end")

    def pkey(self, x, y, w, col, label, hint="", h=KEY_H):
        """Phone key: lit cap, Basic label 13 pt, hint 11 pt (cut to fit)."""
        self.used.add(col)
        self.parts.append(f'<g filter="url(#f{col})"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="4" fill="url(#g{col})"/></g>')
        ink = "#7f7a6d" if col == "off" else "#14120f"
        size = 13 if len(label) <= int((w - 14) / 7.2) else 12  # long command words drop to 12 pt before cutting
        fit = int((w - 14) / (7.2 if size == 13 else 6.6))
        label = label if len(label) <= fit else label[: fit - 1] + "…"
        ly = y + (6 if hint else (h - size) / 2 - 1)
        self.text(x + 7, ly, label, size, ink)
        if hint:
            hf = int((w - 14) / 6.1)
            hint = hint if len(hint) <= hf else hint[: hf - 1] + "…"
            self.parts.append(f'<text x="{x + 7}" y="{y + 36}" font-size="11" fill="{ink}" fill-opacity="0.75">{escape(hint)}</text>')

    def vitals(self, y=56):
        self.rect(M, y, W - 2 * M, 22, PAL["screen"], PAL["off"], r=3)
        x = M + 6
        for lab, v, mx, col in (("HP", 1600, 1600, "green"), ("MV", 970, 1000, "amber"), ("FP", 210, 400, "blue")):
            self.text(x, y + 4, lab, 11, PAL["white"])
            self.rect(x + 20, y + 8, 56, 6, PAL["screen"], PAL["off"], r=2)
            self.rect(x + 20, y + 8, round(56 * v / mx, 1), 6, PAL[col], r=2)
            x += 117
        return y + 26

    def log(self, y0, y1, lines=LOG):
        self.rect(M, y0, W - 2 * M, y1 - y0, PAL["screen"], PAL["off"], r=3)
        n = int((y1 - y0 - 12) / 18)
        shown = (lines * 4)[-n:] if n > 0 else []
        for i, (t, c) in enumerate(shown):
            self.text(M + 8, y0 + 6 + i * 18, t, 13, c)

    def keys(self, entries, y=None, cols=3, more=True):
        y = CMD_Y - 8 - 3 * KEY_H - 2 * GAP if y is None else y
        kw = (W - 2 * M - (cols - 1) * GAP) / cols
        items = list(entries) + ([("off", "MORE ▾", "full list")] if more else [])
        for i, (col, lab, hint) in enumerate(items):
            r, c = divmod(i, cols)
            if not lab:  # empty compass cell: a flat well, not a key (every key must do something)
                self.rect(round(M + c * (kw + GAP), 1), y + r * (KEY_H + GAP), round(kw, 1), KEY_H, PAL["screen"], PAL["off"], r=4, dash="3 3")
                continue
            self.pkey(round(M + c * (kw + GAP), 1), y + r * (KEY_H + GAP), round(kw, 1), col, lab, hint)
        return y

    def cmdline(self, y=CMD_Y, text="> _", right="commands ▴"):
        self.rect(M, y, W - 2 * M, CMD_H, PAL["screen"], PAL["amber"], r=4)
        self.text(M + 10, y + 14, text, 13, PAL["hi"])
        self.text(W - M - 10, y + 15, right, 11, PAL["dim"], anchor="end")

    def tabs(self, names, active):
        tw = (W - 2 * M - 4 * 6) / 5
        for i, t in enumerate(names):
            self.pkey(round(M + i * (tw + 6), 1), TAB_Y, round(tw, 1), "amber" if t == active else "off", t)

    def keyboard(self, numeric=False, suggestions=("", "", "")):
        self.rect(0, KB_Y, W, H - KB_Y, "#2b2b2d")
        self.rect(0, KB_Y, W, 44, "#232325")
        for i, s in enumerate(suggestions):
            self.text(W / 6 + i * W / 3, KB_Y + 15, s, 13, "#e6e6e6", anchor="middle")
        rows = (["1 2 3", "4 5 6", "7 8 9", "− 0 ⌫"] if numeric else
                ["Q W E R T Y U I O P", "A S D F G H J K L", "⇧ Z X C V B N M ⌫", "123 space return"])
        for r, row in enumerate(rows):
            ks = row.split()
            if not numeric and r == 3:
                widths = [88, 183, 84]
            else:
                kw = (W - 8 - 6 * (len(ks) - 1)) / len(ks)
                widths = [kw] * len(ks)
            x = 4 + (0 if numeric or r != 1 else 18)
            for k, w in zip(ks, widths):
                w = w - (36 / len(ks) if (not numeric and r == 1) else 0)
                self.rect(round(x, 1), KB_Y + 50 + r * 53, round(w, 1), 44, "#6b6b6d", r=5)
                self.text(round(x + w / 2, 1), KB_Y + 63 + r * 53, k, 15 if len(k) == 1 else 13, "#ffffff", anchor="middle")
                x += w + 6

    def chips(self, y, items):
        x = M
        for col, t in items:
            w = 22 + 7.2 * len(t)
            self.pkey(round(x, 1), y, round(w, 1), col, t, h=KEY_H)
            x += w + 6

    def note(self, *lines):
        """Design notes under the screen, wrapped to the 375 pt width (52 chars at 11 pt)."""
        import textwrap
        out = [w for t in lines for w in textwrap.wrap(t, 52)]
        self.h = H + 12 + 16 * len(out)
        for i, t in enumerate(out):
            self.text(M, H + 6 + i * 16, t, 11, PAL["faint"])

    def svg(self):
        import re
        return re.sub(r'<filter id="fcase".*?</filter>', "", super().svg())  # phones have no casing shadow

    def save(self, name):
        open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8").write(self.svg())
        print(name)


def station_keys(station, prefer, n=8):
    es = [e for e in catalog()["entries"] if e.get("station") == station and e["kind"] != "reference"
          and e["pattern"] != "readout" and e.get("status") != "inactive"]
    es = [e for e in es if e["topic"].split(" ")[0] in prefer] + [e for e in es if e["topic"].split(" ")[0] not in prefer]
    out, seen = [], set()
    for e in es:
        lab, hint = label_and_hint(e)
        if lab in seen:
            continue
        seen.add(lab)
        out.append((key_color(e, station), lab, hint or ""))
        if len(out) == n:
            break
    return out


def completions(prefix, n=4):
    """What the fuzzy command bar offers for a typed prefix: real command words from the catalog."""
    seen, out = set(), []
    for e in catalog()["entries"]:
        if e["kind"] == "reference" or e.get("status") == "inactive":
            continue
        lab, hint = label_and_hint(e)
        word = lab.split(" ")[0].rstrip("▸ ").lower()
        if word.startswith(prefix) and word not in seen:
            seen.add(word)
            out.append(word + (" " + hint if hint.startswith("<") else ""))
    return sorted(out, key=len)[:n]


# ---- FIG-02 · space -------------------------------------------------------------------------
def radar(s, y0, y1, dim=False):
    s.rect(M, y0, W - 2 * M, y1 - y0, "#0d0b08", PAL["off"], r=3)
    cx, cy = W / 2, (y0 + y1) / 2 + 8
    a = PAL["amber"] if not dim else PAL["off"]
    for rx, ry in ((160, 52), (100, 32), (44, 14)):
        s.parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="none" stroke="{a}" stroke-opacity="0.55"/>')
    s.text(M + 8, y0 + 6, "RADAR · KUAT", 11, PAL["amber"])
    s.text(W - M - 8, y0 + 6, "RNG 1000 · AGE 4 s", 11, PAL["dim"], anchor="end")
    for x, top, base, name, col in ((cx + 70, cy - 58, cy - 6, "JUNKER 24 +120", PAL["red"]),
                                    (cx - 115, cy - 22, cy + 4, "JUNKER 32 +60", PAL["amber"]),
                                    (cx - 10, cy + 40, cy + 22, "KUAT STATION −40", PAL["green"])):
        top = max(top, y0 + 34)  # keep labels clear of the radar header on short radars
        s.line(x, top, x, base, col)
        s.circle(x, top, 5, col)
        s.text(x + 9, top - 7, name, 11, col)
    s.parts.append(f'<path d="M{cx - 6} {cy + 5} L{cx} {cy - 8} L{cx + 6} {cy + 5} Z" fill="none" stroke="{PAL["white"]}"/>')


def contacts(s, y):
    rows = (("▸ JUNKER 24", "354 u  +120", PAL["red"]), ("JUNKER 32", "948 u  +60", PAL["text"]),
            ("KUAT STATION", "612 u  −40", PAL["green"]))
    for i, (n, d, c) in enumerate(rows):
        yy = y + i * 46
        s.rect(M, yy, W - 2 * M, 44, PAL["screen"], PAL["red"] if i == 0 else PAL["off"], r=3)
        s.text(M + 10, yy + 14, n, 13, c)
        s.text(W - M - 10, yy + 15, d, 12, PAL["dim"], anchor="end")
    return y + 3 * 46


SPACE_TABS = ["NAV", "PILOT", "ARMS", "COMMS", "MORE"]

s = Phone("NAV", "● Z-95 · KUAT")
radar(s, 56, 258)
contacts(s, 262)
s.keys([("amber", "RADAR", ""), ("amber", "PROX ▾", ""), ("amber", "CHAFF", ""),
        ("red", "LAUNCH", ""), ("amber", "SHIPS", "filter"), ("amber", "PLANETS", "filter"),
        ("off", "MISSILES", "filter"), ("amber", "RNG −/+", "1000")], more=True)
s.cmdline()
s.tabs(SPACE_TABS, "NAV")
s.note("tap a contact row = target sheet · pinch zoom, two fingers rotate the radar",
       "stem = Δz · rows replace the desktop contact table at 44 pt")
s.save("se_radar")

s = Phone("TARGET", "swipe down to close")
radar(s, 56, 196, dim=True)
s.rect(0, 202, W, TAB_Y - 210, "#1d1a16", PAL["red"], r=14)
s.rect(W / 2 - 20, 210, 40, 4, PAL["off"], r=2)
s.text(M + 8, 222, "SENT", 11, PAL["red"])
s.text(M + 8, 240, "JUNKER 24", 16, PAL["amber"], "Bruno Ace SC")
s.text(M + 8, 264, "354 u · Δz +120 · hdg est. 040", 13, PAL["text"])
kw = (W - 2 * M - 2 * GAP) / 3
for i, (c, t) in enumerate((("red", "TARGET"), ("amber", "FACE"), ("red", "FIRE ▾"))):
    s.pkey(round(M + i * (kw + GAP), 1), 290, round(kw, 1), c, t)
s.text(M + 8, 346, "WEAPON", 11, PAL["dim"])
ww = (W - 2 * M - GAP) / 2
for i, t in enumerate(("▸ laser", "missile", "torpedo", "rocket")):
    r, c = divmod(i, 2)
    x, y = M + c * (ww + GAP), 366 + r * 52
    s.rect(round(x, 1), y, round(ww, 1), 44, PAL["screen"], PAL["red"] if i == 0 else PAL["off"], r=4)
    s.text(round(x + 12, 1), y + 14, t, 13, PAL["red"] if i == 0 else PAL["text"])
s.pkey(M, 474, W - 2 * M, "red", "FIRE LASER", h=52)
s.tabs(SPACE_TABS, "ARMS")
s.note("sheet over the radar; the command line comes back when it closes",
       "states as desktop: none · selected · sent · lost")
s.save("se_alvo")

s = Phone("PILOT", "flow · step 3 of 5")
for i, col in enumerate(("green", "green", "amber", "off", "off")):
    x = M + 14 + i * 80
    if i:
        s.line(x - 66, 66, x - 14, 66, PAL["off"])
    s.circle(x, 66, 7, PAL[col] if col != "off" else PAL["off"])
s.text(M, 80, "helm · launch · CALCULATE · land at · landing", 11, PAL["dim"])
s.rect(M, 100, W - 2 * M, 250, PAL["screen"], PAL["off"], r=6)
s.text(M + 12, 110, "TATOOINE → KUAT", 14, PAL["amber"], "Bruno Ace SC")
s.text(M + 12, 134, "SYSTEM", 11, PAL["dim"])
s.rect(M + 12, 152, W - 2 * M - 24, 44, "#1d1a16", PAL["off"], r=4)
s.text(M + 24, 166, "Kuat ▾", 13, PAL["text"])
s.text(M + 12, 206, "or coordinates", 11, PAL["dim"])
fw = (W - 2 * M - 24 - 2 * GAP) / 3
for i, (lab, val, focus) in enumerate((("x", "120", False), ("y", "-45_", True), ("z", "", False))):
    x = M + 12 + i * (fw + GAP)
    s.rect(round(x, 1), 224, round(fw, 1), 44, "#1d1a16", PAL["amber"] if focus else PAL["off"], r=4)
    s.text(round(x + 10, 1), 238, f"{lab}  {val}", 13, PAL["hi"] if focus else PAL["text"])
s.text(M + 12, 282, "HYPERSPACE unlocks after the", 11, PAL["dim"])
s.text(M + 12, 298, '"calculations have been completed" line', 11, PAL["dim"])
s.cmdline(KB_Y - CMD_H - 6, "> calculate 120 -45", "send ▸")
s.keyboard(numeric=True, suggestions=("‹ x", "y", "z ›"))
s.note("numeric pad (216 pt + bar) · form and command line stay above it",
       "HYPERSPACE / RECALCULATE come back when the keyboard closes")
s.save("se_fluxo_digitando")

# ---- FIG-03 · room, RP, map -----------------------------------------------------------------
ROOM_TABS = ["ROOM", "RP", "MAP", "SHIP", "MORE"]
s = Phone("ROOM", "Docking Bay 94")
for i, t in enumerate(("A wide hangar opens under a rusted", "dome. Fuel lines snake toward a",
                       "battered YT-1300.")):
    s.text(M + 4, 60 + i * 18, t, 13, PAL["text"])
s.text(M + 4, 118, "HERE", 11, PAL["amber"])
for i, (t, c) in enumerate((("☰ Dock master Ruhn", PAL["hi"]), ("☰ Kessa Vorr", PAL["hi"]),
                            ('☰ YT-1300 "Lucky Dice"', PAL["white"]))):
    s.rect(M, 136 + i * 48, W - 2 * M, 44, "#2a2621", PAL["off"], r=4)
    s.text(M + 12, 150 + i * 48, t, 13, c)
s.log(282, 398, LOG[:3])
y = s.keys([("amber", "ENTER", ""), ("amber", "N", ""), ("amber", "UP", ""),
            ("off", "W", ""), ("off", "LOOK", ""), ("red", "E ×", "locked"),
            ("off", "", ""), ("off", "S", ""), ("off", "", "")], more=False)
s.cmdline()
s.tabs(ROOM_TABS, "ROOM")
s.note("tap a name = its menu as a bottom sheet · × = locked door",
       "exits keep the compass layout; empty cells stay dark")
s.save("se_sala")

s = Phone("RP", "TELL • · CLAN · COMMNET 0 •")
s.log(56, 302)
s.chips(307, (("amber", "SAY"), ("off", "EMOTE"), ("off", "SAYTO ▸"), ("off", "Basic · calm")))
s.cmdline(KB_Y - CMD_H - 6, '"Then I\'ll fly her out myself."_', "")
s.keyboard(suggestions=("myself", "my", "mine"))
s.note("typing hides the tabs; channel and mode stay on screen",
       "about 13 RP lines stay visible above the keyboard")
s.save("se_rp_digitando")

s = Phone("MAP", "64% explored · deck 2")
s.rect(0, 56, W, TAB_Y - 64, "#05080c")
s.text(M + 4, 66, "MOS EISLEY SPACEPORT", 14, "#e6f6ff", "Bruno Ace SC")
cx, cy = W / 2, 300
for dx, dy in ((-60, -30), (0, -60), (60, -30), (-60, 30), (0, 0), (60, 30), (0, 60)):
    x, y = cx + dx, cy + dy
    s.parts.append(f'<path d="M{x - 30} {y} L{x} {y - 15} L{x + 30} {y} L{x} {y + 15} Z" fill="#3a8fd6" stroke="#9fd6ff"/>')
s.circle(cx + 60, cy - 30, 6, PAL["amber"])
s.keys([("blue", "DECK ▴▾", ""), ("blue", "RECENTER", ""), ("blue", "LEGEND", "")], y=TAB_Y - 52, more=False)
s.tabs(ROOM_TABS, "MAP")
s.note("pinch zoom · two fingers rotate · tap a room = walk there",
       "LEGEND opens as a sheet so the map keeps the screen")
s.save("se_mapa")

# ---- FIG-04..06 · stations ------------------------------------------------------------------
def station_phone(name, title, station, tabs, active, prefer, vitals=True):
    s = Phone(title, "● LOTJ")
    y = s.vitals() if vitals else 56
    ky = CMD_Y - 8 - 3 * KEY_H - 2 * GAP
    s.log(y, ky - 8)
    s.keys(station_keys(station, prefer))
    s.cmdline()
    s.tabs(tabs, active)
    s.note("8 most used keys + MORE ▾ (full station list as a sheet)",
           "long-press a key = its help syntax · Aurebesh labels are desktop only")
    s.save(name)


CHAR_TABS = ["SHEET", "COMBAT", "FORCE", "GEAR", "MORE"]
station_phone("se_combate", "COMBAT", "combat", CHAR_TABS, "COMBAT",
              ("KILL", "FLEE", "KICK", "BASH", "DISARM", "RESCUE", "AIM", "SNIPE"))
station_phone("se_oficina", "WORKSHOP", "workshop", ["TRADE", "SHOP", "SLICE", "DROID", "MORE"], "SHOP",
              ("GATHER", "DIG", "SURVEY", "MAKEBLASTER", "MAKEMEDPAC", "MAKEDATAPAD"))
station_phone("se_cla", "CLAN", "clan", ["CLAN", "PLANET", "EVENT", "HELP", "MORE"], "CLAN",
              ("ROSTER", "CGWHO", "CLANMOTD", "CLANBOUNTY", "INDUCT", "PROMOTE", "CLANDB", "CLANCRIMES"))

s = Phone("COMBAT", "● LOTJ")
y = s.vitals()
s.log(y, 302)
sug = completions("ki")
s.chips(307, [("amber" if i == 0 else "off", t) for i, t in enumerate(sug[:3])])
s.cmdline(KB_Y - CMD_H - 6, "> ki_", "send ▸")
s.keyboard(suggestions=tuple(t.split(" ")[0] for t in sug[:3]) + ("",) * (3 - len(sug[:3])))
s.note("typing: keys and tabs fold away; vitals, log and the fuzzy matches stay",
       "a match chip fills the command line; its <arg> picks from the room")
s.save("se_combate_digitando")
