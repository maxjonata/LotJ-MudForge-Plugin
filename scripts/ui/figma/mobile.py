import os
from svgkit import Svg, card, bar, PAL, catalog, label_and_hint

OUT = os.path.join(os.path.dirname(__file__), "out")


def first_keys(station, n, prefer=()):
    es = [e for e in catalog()["entries"] if e.get("station") == station and e["kind"] != "reference" and e["pattern"] != "readout"]
    pick = [e for e in es if e["topic"].split(" ")[0] in prefer] + [e for e in es if e["topic"].split(" ")[0] not in prefer]
    return {e["topic"] for e in pick[:n]}


def phone(name, title, station, tabs, active, prefer, top=None, top_h=0):
    s = Svg(390, 780)
    s.parts.append('<g filter="url(#fcase)"><rect x="0" y="0" width="390" height="780" rx="28" fill="#2f2c27" stroke="#5c574e"/></g>')
    s.rect(14, 16, 362, 22, PAL["inset"], PAL["inset_s"], r=3)
    s.text(22, 21, title, 9, PAL["amber"])
    s.text(368, 21, "CONNECTED · LOTJ", 8, PAL["dim"], anchor="end")
    keep = first_keys(station, 12, prefer)
    h = card(s, 14, 48 + top_h, 362, station.upper(), "top keys · ▾ more", station, 3, 0,
             ("long-press a key = Basic label; ▾ MORE opens the full list",), filt=lambda e: e["topic"] in keep)
    if top:
        top(s)
    ly = 48 + top_h + h + 12
    s.rect(14, ly, 362, 628 - ly, PAL["screen"], PAL["off"], r=3)
    s.text(22, ly + 6, "GAME LOG · the game's own lines, ANSI kept · newest at the bottom", 8, PAL["sub"])
    for i in range(int((628 - ly - 30) / 14)):
        s.rect(22, ly + 26 + i * 14, 140 + (i * 53) % 190, 5, PAL["off"], r=2)
    s.rect(14, 640, 362, 34, PAL["screen"], PAL["off"], r=3)
    s.text(24, 651, "> _", 10, PAL["amber"])
    s.text(366, 652, "commands ▾", 8, PAL["dim"], anchor="end")
    for i, t in enumerate(tabs):
        s.key(14 + i * 73, 690, 67, 40, "amber" if t == active else "off", t, "")
    s.text(14, 752, "one station on screen · tabs switch stations · keyboard above the tabs", 8, PAL["faint"])
    open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8").write(s.svg())
    print(name, 48 + top_h + h)


def vitals(s):
    s.rect(14, 48, 362, 56, PAL["screen"], PAL["off"], r=3)
    bar(s, 22, 54, 346, "HP", 1600, 1600, "green", "Char.Vitals")
    bar(s, 22, 70, 346, "MOVE", 970, 1000, "amber", "")
    bar(s, 22, 86, 346, "FORCE", 210, 400, "blue", "mana")


phone("mob_combate", "COMBAT · 390", "combat", ["SHEET", "COMBAT", "FORCE", "GEAR", "MORE"], "COMBAT",
      ("KILL", "FLEE", "KICK", "BASH", "DISARM", "RESCUE", "AIM", "SNIPE", "HIDE"), vitals, 64)
phone("mob_oficina", "WORKSHOP · 390", "workshop", ["TRADE", "SHOP", "SLICE", "DROID", "MORE"], "SHOP",
      ("GATHER", "DIG", "SURVEY", "MAKEBLASTER", "MAKEMEDPAC", "MAKEDATAPAD"))
phone("mob_cla", "CLAN · 390", "clan", ["CLAN", "PLANET", "EVENT", "HELP", "MORE"], "CLAN",
      ("ROSTER", "CGWHO", "CLANMOTD", "BOUNTY", "INDUCT", "PROMOTE"))
