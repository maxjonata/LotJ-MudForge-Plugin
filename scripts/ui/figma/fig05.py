import os
from svgkit import Svg, card, bar, PAL

OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)


def save(name, s):
    open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8").write(s.svg())
    print(name, s.w, s.h)


LATER = {"LEADPLANET", "SHOWPLANET", "SHOWRACE"}  # move to FIG-06 planet / onboarding
filt = lambda e: e["topic"].split(" ")[0] not in LATER


def build(name, title, sub, station, w, cols, extra, notes, top=None, lights=()):
    h = card(Svg(w, 3000), 0, 0, w, "", "", station, cols, extra, notes, filt=filt, lights=lights)
    s = Svg(w, h)
    card(s, 0, 0, w, title, sub, station, cols, extra, notes, filt=filt, lights=lights)
    if top:
        top(s)
    save(name, s)


def trade_top(s):
    s.rect(14, 50, 712, 40, PAL["screen"], PAL["off"], r=3)
    s.text(24, 55, "CREDITS  (from money / bank output · example)", 8, PAL["sub"])
    s.text(24, 68, "on hand", 9, PAL["dim"]); s.text(80, 66, "12,450", 13, PAL["amber"], "Bruno Ace SC")
    s.text(240, 68, "bank", 9, PAL["dim"]); s.text(280, 66, "88,000", 13, PAL["amber"], "Bruno Ace SC")
    s.text(470, 68, "shop and vendor lists open as list + detail", 9, PAL["dim"])


build("fig05_comercio", "COMÉRCIO", "créditos · banco · lojas · imóveis", "trade", 740, 5, 48,
      ("BUY / SELL open the shop list of the room; amounts and targets are asked in a form",
       "STEAL, BRIBE and SWIPE are aggressive acts: first use asks once",
       "structures and homes (buystructure, homedesc, upkeep) keep their own rows"), trade_top)


def shop_top(s):
    s.rect(14, 50, 712, 40, PAL["screen"], PAL["off"], r=3)
    s.text(24, 55, "RECIPE  (craft pattern)", 8, PAL["sub"])
    s.text(24, 68, "MAKE ▸ choose item · the game names the parts it needs · inventory parts are ticked", 9, PAL["white"])
    s.text(24, 80, "gather / dig / survey feed the parts list; results stay in the log", 8, PAL["dim"])


build("fig05_oficina", "OFICINA", "fabricar · coletar · construir · melhorar", "workshop", 740, 5, 48,
      ("one key per make* recipe and per gathering skill; ▸ = asks the recipe arguments",
       "passive engineering skills are read from the skill list"), shop_top)

build("fig05_slicer", "SLICER", "hack · travas · câmeras · perícia", "slicer", 360, 3, 0,
      ("hacks and sabotage are aggressive acts: first use asks once",))


def droid_top(s):
    s.rect(14, 50, 332, 44, PAL["screen"], PAL["off"], r=3)
    s.text(22, 55, "DROIDS  (from droidstat · example)", 8, PAL["sub"])
    s.text(22, 68, "☰ R2-K7  astromech · following", 9, PAL["hi"])
    s.text(22, 81, "☰ GNK-3  power droid · idle", 9, PAL["white"])


build("fig05_droides", "DROIDES", "estado · nome · reparo", "droids", 360, 3, 52,
      ("droid orders live in COMBATE (duty droid)",), droid_top)

build("fig05_datapad", "DATAPAD", "datamem · datastat · mail · notas", "datapad", 360, 3, 0,
      ("the whole device is drawn in section FIG-03 · Datapad",
       "these keys open it on the matching screen"))
