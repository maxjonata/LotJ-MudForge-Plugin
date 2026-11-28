import os
from svgkit import Svg, card, bar, PAL, catalog

OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)


def save(name, s):
    open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8").write(s.svg())
    print(name, s.w, s.h)


def measure(station, w, cols, extra, notes=(), lights=()):
    s = Svg(w, 3000)
    return card(s, 0, 0, w, "", "", station, cols, extra, notes, lights=lights)


# FICHA
h = measure("sheet", 360, 3, 64, ("bars: GMCP Char.Vitals (hp/maxHp, move/maxMove, mana/maxMana)",))
s = Svg(360, h)
card(s, 0, 0, 360, "FICHA", "score · nível · prompt", "sheet", 3, 64,
     ("bars: GMCP Char.Vitals (hp/maxHp, move/maxMove, mana/maxMana)",))
s.rect(14, 50, 332, 58, PAL["screen"], PAL["off"], r=3)
bar(s, 22, 56, 316, "HP", 1600, 1600, "green", "Char.Vitals")
bar(s, 22, 72, 316, "MOVE", 970, 1000, "amber", "Char.Vitals")
bar(s, 22, 88, 316, "FORCE", 210, 400, "blue", "mana")
save("fig04_ficha", s)

# EQUIPAMENTO
notes = ("rows come from the game's equipment / inventory output",
         "wear locations: help WEAR LOCATIONS · right-click = item menu")
h = measure("gear", 360, 3, 88, notes)
s = Svg(360, h)
card(s, 0, 0, 360, "EQUIPAMENTO", "eq · inventário", "gear", 3, 88, notes)
s.rect(14, 50, 332, 82, PAL["screen"], PAL["off"], r=3)
s.text(22, 55, "WORN  (example rows)", 8, PAL["sub"])
for i, (slot, item) in enumerate([("wielded", "a blaster pistol"), ("body", "padded armor"), ("held", "a glowrod")]):
    s.text(22, 68 + i * 14, slot, 9, PAL["dim"])
    s.text(100, 68 + i * 14, "☰ " + item, 9, PAL["hi"])
s.text(250, 55, "CARRIED", 8, PAL["sub"])
s.text(250, 68, "☰ medpac", 9, PAL["white"])
s.text(250, 82, "☰ comlink", 9, PAL["white"])
save("fig04_equip", s)

# MEDICINA E MORTE
notes = ("wound list = the injurys output; HEALWOUND asks the wound location",
         "LACUNA: death, hospital and clone screens need the DEATH and CLONES",
         "help text; the local index has no prose, so no flow is drawn yet")
h = measure("medical", 360, 3, 70, notes)
s = Svg(360, h)
card(s, 0, 0, 360, "MEDICINA", "ferimentos · reviver · clones", "medical", 3, 70, notes)
s.rect(14, 50, 332, 64, PAL["screen"], PAL["off"], r=3)
s.text(22, 55, "INJURIES  (from injurys · example)", 8, PAL["sub"])
for i, (loc, st, col) in enumerate([("left arm", "wounded", "red"), ("torso", "bruised", "amber"), ("head", "ok", "green")]):
    s.light(27, 74 + i * 14, col)
    s.text(36, 68 + i * 14, loc, 9, PAL["white"])
    s.text(130, 68 + i * 14, st, 9, PAL[col])
save("fig04_medic", s)

# COMBATE
notes = ("red = aggressive act on a target: first use asks once, like TARGET on ships",
         "enemy from GMCP Char.Enemy (name, colour codes stripped)",
         "stealth, capture and troop orders live here too; keys grey when not possible")
lights = (("IN COMBAT", "red"), ("HIDDEN", "off"), ("MOUNTED", "off"), ("BOUND", "off"))
h = measure("combat", 740, 5, 44, notes, lights)
s = Svg(740, h)
card(s, 0, 0, 740, "COMBATE", "ataque · manobras · furtividade · captura", "combat", 5, 44, notes, lights=lights)
s.rect(14, 50, 712, 36, PAL["screen"], PAL["red"], r=3)
s.text(24, 55, "ENEMY", 8, PAL["sub"])
s.text(24, 66, "Stormtrooper", 12, PAL["red"], "Bruno Ace SC")
s.text(220, 58, "fighting you · from Char.Enemy", 9, PAL["dim"])
s.text(700, 58, "CONSIDER for odds", 9, PAL["dim"], anchor="end")
save("fig04_combate", s)

# FORCA
notes = ("Force pool = mana in GMCP Char.Vitals · powers send feel '<power>' as the help documents",
         "targeted powers open the target picker (room entities); self powers send at once",
         "only powers the character knows are lit; the rest stay dark (skill list)")
h = measure("force", 740, 5, 30, notes)
s = Svg(740, h)
card(s, 0, 0, 740, "FORÇA", "poderes · meditação · alinhamento · formas", "force", 5, 30, notes)
s.rect(14, 50, 712, 24, PAL["screen"], PAL["off"], r=3)
bar(s, 22, 56, 696, "FORCE", 210, 400, "blue", "GMCP Char.Vitals mana")
save("fig04_forca", s)
