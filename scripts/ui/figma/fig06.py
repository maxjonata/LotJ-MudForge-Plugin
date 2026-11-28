import json
import os
from svgkit import Svg, card, PAL

OUT = os.path.join(os.path.dirname(__file__), "out")
os.makedirs(OUT, exist_ok=True)
NODES = os.path.join(os.path.dirname(__file__), "..", "..", "..", "docs", "ui", "figma-nodes.json")
DESIGNED = {t for n in json.load(open(NODES, encoding="utf-8"))["nodes"] for t in n["topics"]}


def save(name, s):
    open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8").write(s.svg())
    print(name, s.w, s.h)


def build(name, title, sub, station, w, cols, extra, notes, top=None, filt=None, lights=()):
    h = card(Svg(w, 3000), 0, 0, w, "", "", station, cols, extra, notes, filt=filt, lights=lights)
    s = Svg(w, h)
    card(s, 0, 0, w, title, sub, station, cols, extra, notes, filt=filt, lights=lights)
    if top:
        top(s)
    save(name, s)


def clan_top(s):
    s.rect(14, 50, 712, 40, PAL["screen"], PAL["off"], r=3)
    s.text(24, 55, "CLAN  (GMCP CLAN · colour from clancolorname)", 8, PAL["sub"])
    s.text(24, 66, "Galactic Empire", 13, PAL["red"], "Bruno Ace SC")
    s.text(250, 69, "the clan picks the console theme (see 05 · Consoles por tema)", 9, PAL["dim"])


build("fig06_cla", "CLÃ", "membros · cargos · divisões · recompensas · crimes", "clan", 740, 5, 48,
      ("leader-only keys stay dark with the reason (\"needs clan power\") for other members",
       "rosters, bounties and crimes open as list + detail; messages and MOTD use the text editor"), clan_top)
build("fig06_planeta", "PLANETAS", "escudos · governo · residência", "planet", 360, 3, 0,
      ("planet rows come from the planets output; the ground map stays the FIG-03 hologram",))
build("fig06_eventos", "EVENTOS", "notícias · votos · RPC · dados", "events", 360, 3, 0,
      ("news and votes open as list + detail; dice results land in the RP log",))
build("fig06_onboarding", "BOAS-VINDAS", "ajuda · raça · cores · conta", "onboarding", 740, 5, 0,
      ("first login: HELP / NEWBIE_INDEX open the Holocron (reference topics, 446 of them)",
       "race and class help topics are reference pages; character creation itself runs in the game's own prompts",
       "screen reader and colour keys change plugin and game settings together"))
build("fig06_sistema", "SISTEMA", "utilidades sem painel próprio", "system", 740, 5, 0,
      ("every command that fits no other panel lands here, so nothing is unreachable",
       "the command bar (fuzzy autocomplete) reaches all of them too"))
SPACE = ("pilot", "nav", "weapons", "engineering", "shipyard", "access", "comms", "fleet", "combat")
build("fig06_complementos", "COMPLEMENTOS", "nave e combate · tópicos achados depois", SPACE, 740, 5, 0,
      ("help topics routed to FIG-02 stations and to COMBATE after those screens were drawn",
       "in the plugin each key sits on its station; here they are listed together"),
      filt=lambda e: e["topic"] not in DESIGNED)
