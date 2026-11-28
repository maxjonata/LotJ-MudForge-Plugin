"""Generate src/domain/console-catalog.lua from docs/ui/command-ui.json (UI-03).

The station consoles in the plugin are the Figma console cards (FIG-02..06):
one key per command of a station, with the same label, hint and colour rules
as scripts/ui/figma/svgkit.py. Each key carries the help syntax of its
variants as a template ("course {1} {2} {3}") plus typed arguments, so the
plugin sends exactly what the help documents and never invents a command.

    python scripts/ui/build_consoles.py          # write the Lua module
    python scripts/ui/build_consoles.py --check  # fail when it is out of date
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(HERE, "figma"))
sys.path.insert(0, HERE)

from svgkit import key_color, label_and_hint  # noqa: E402
import build_catalog  # noqa: E402

CATALOG = os.path.join(ROOT, "docs", "ui", "command-ui.json")
OUT = os.path.join(ROOT, "src", "domain", "console-catalog.lua")

# Console order and titles follow the Figma sections (FIG-02..06).
GROUPS = [
    ("NAVE", ["pilot", "nav", "weapons", "access", "comms", "fleet", "engineering", "shipyard"]),
    ("SALA", ["room", "rp"]),
    ("PERSONAGEM", ["sheet", "gear", "combat", "force", "medical"]),
    ("OFÍCIOS", ["trade", "workshop", "slicer", "droids", "datapad"]),
    ("MUNDO", ["clan", "planet", "events"]),
    ("SISTEMA", ["onboarding", "system"]),
]
TITLES = {
    "pilot": "PILOTO", "nav": "NAVEGAÇÃO", "weapons": "ARMAS", "access": "ACESSO", "comms": "RÁDIO",
    "fleet": "FROTA", "engineering": "ENGENHARIA", "shipyard": "ESTALEIRO", "room": "SALA", "rp": "RP",
    "sheet": "FICHA", "gear": "EQUIPAMENTO", "combat": "COMBATE", "force": "FORÇA", "medical": "MEDICINA",
    "trade": "COMÉRCIO", "workshop": "OFICINA", "slicer": "SLICER", "droids": "DROIDES", "datapad": "DATAPAD",
    "clan": "CLÃ", "planet": "PLANETA", "events": "EVENTOS", "onboarding": "BOAS-VINDAS", "system": "SISTEMA",
}
INPUT_PATTERNS = {"form", "flow", "editor", "list", "craft", "comms"}
_SLASH_WORD = re.compile(r"^[^\s<>()\[\]]*[/|][^\s<>()\[\]]*")
_OR_WORD = re.compile(r"\s+or\s+", re.I)
# Words the help uses to name a placeholder inside a choice ("<object/direction>",
# "<troop/all>"): they are not literal values, so they are never suggested.
PLACEHOLDER_WORDS = {"object", "objects", "direction", "target", "planet", "ship", "person", "player",
                     "character", "name", "amount", "troop", "item", "number", "skill", "class",
                     "door", "1 if blank", "name of either person", "date"}


def _fix(syntax):
    """The same repairs build_catalog.args applies before reading placeholders."""
    syntax = syntax.rstrip()
    if syntax.count("(") > syntax.count(")") and syntax.rfind("(") > syntax.rfind(")"):
        syntax = syntax[:syntax.rfind("(")].rstrip()
    for opener, closer in (("<", ">"), ("[", "]")):
        if syntax.count(opener) > syntax.count(closer) and syntax.rfind(opener) > syntax.rfind(closer):
            syntax += closer
    return syntax


def _clean_arg(arg):
    out = {"name": " ".join(arg["name"].split()), "type": arg["type"]}
    if arg.get("optional"):
        out["optional"] = True
    choices = [c.strip() for c in arg.get("choices", []) if c.strip()]
    if arg["type"] == "toggle":
        choices = ["on", "off"]
    if choices:
        out["choices"] = choices
    for bound in ("min", "max"):
        if bound in arg:
            out[bound] = arg[bound]
    return out


def template(syntax):
    """'course <x> <y> (note words here)' -> ('course {1} {2}', [args]).

    Literal words are lower-cased (the game is case-insensitive); a literal
    slash list such as "Gender 0/1/2" or "+/-<option>" becomes a choice; an
    "a or b" alias keeps its first form.
    """
    syntax = _fix(syntax)
    parts, args, last = [], [], 0
    for match in build_catalog._TOKEN_RE.finditer(syntax):
        inner = next(g for g in match.groups() if g is not None)
        parts.append(("lit", syntax[last:match.start()]))
        last = match.end()
        if match.group(2) is not None and build_catalog._is_note(inner):
            continue
        arg = build_catalog._arg(inner)
        if match.group(3) is not None:
            arg["optional"] = True
        args.append(_clean_arg(arg))
        parts.append(("arg", len(args)))
    parts.append(("lit", syntax[last:]))

    open_, close_ = "\x01", "\x02"  # private markers for help placeholders
    text = ""
    for kind, value in parts:
        text += value.lower() if kind == "lit" else open_ + str(value) + close_
    if not args:
        text = _OR_WORD.split(text)[0]
    # Literal slash lists become choices, renumbering the arguments after them.
    out_args, number, rebuilt = [], 0, []
    for word in text.split(" "):
        lead = _SLASH_WORD.match(word)
        if lead and lead.group(0):
            choices = [c for c in re.split(r"[/|]", lead.group(0)) if c]
            if len(choices) > 1:
                number += 1
                out_args.append({"name": lead.group(0), "type": "choice", "choices": choices})
                word = "{%d}" % number + word[lead.end():]

        def renumber(m):
            nonlocal number
            number += 1
            out_args.append(args[int(m.group(1)) - 1])
            return "{%d}" % number
        rebuilt.append(re.sub(open_ + r"(\d+)" + close_, renumber, word))
    text = " ".join(" ".join(rebuilt).split())
    # "{1}/no argument": the argument is optional. "all/{1}": "all" is a value of {1}.
    def optional(m):
        out_args[int(m.group(1)) - 1]["optional"] = True
        return "{%s}" % m.group(1)
    text = re.sub(r"\{(\d+)\}/no argument", optional, text)

    def literal(m):
        arg = out_args[int(m.group(2)) - 1]
        arg["choices"] = [m.group(1)] + [c for c in arg.get("choices", []) if c != m.group(1)]
        return "{%s}" % m.group(2)
    text = re.sub(r"([a-z]+)/\{(\d+)\}", literal, text)
    for arg in out_args:
        if "choices" in arg:
            arg["choices"] = [c for c in arg["choices"] if c.lower() not in PLACEHOLDER_WORDS]
            if not arg["choices"]:
                del arg["choices"]
                if arg["type"] == "choice":
                    arg["type"] = "text"
    return text, out_args


def _passive_label(entry):
    return label_and_hint(entry)[0]


def build(catalog):
    entries = catalog["entries"]
    known = {s for _, group in GROUPS for s in group}
    stations, keys, passive = [], {}, {}
    for group, ids in GROUPS:
        for sid in ids:
            stations.append({"id": sid, "group": group, "title": TITLES[sid],
                             "about": catalog["stations"].get(sid, "")})
    for entry in entries:
        sid = entry.get("station")
        if not sid or entry["kind"] == "reference":
            continue
        if sid not in known:
            raise ValueError("station %r has no console" % sid)
        if entry["pattern"] == "readout":
            label = _passive_label(entry)
            if label not in passive.setdefault(sid, []):
                passive[sid].append(label)
            continue
        label, hint = label_and_hint(entry)
        variants = []
        for v in entry["variants"] or [{"syntax": label.lower(), "preconditions": []}]:
            for syntax in re.split(r"\s+/\s+", " ".join(v["syntax"].split())):
                tpl, args = template(syntax)
                if not tpl or any(t["template"] == tpl for t in variants):
                    continue
                variants.append({"syntax": syntax, "template": tpl, "args": args,
                                 "notes": [" ".join(n.split()) for n in v.get("preconditions", [])]})
        if not variants:
            raise ValueError("topic %r has no sendable syntax" % entry["topic"])
        station_keys = keys.setdefault(sid, [])
        same = next((k for k in station_keys if k["label"] == label), None)
        if same:  # the Figma card shows one key per label; keep every variant behind it
            same["topics"].append(entry["topic"])
            seen = {v["template"] for v in same["variants"]}
            same["variants"].extend(v for v in variants if v["template"] not in seen)
            continue
        color = key_color(entry, sid)
        station_keys.append({
            "label": label, "hint": hint, "color": color, "topics": [entry["topic"]],
            "input": entry["pattern"] in INPUT_PATTERNS or any(v["args"] for v in variants) or len(variants) > 1,
            "confirm": color == "red", "inactive": entry.get("status") == "inactive",
            "variants": variants,
        })
    for station_keys in keys.values():
        for key in station_keys:
            key["input"] = key["input"] or len(key["variants"]) > 1 or any(v["args"] for v in key["variants"])
    references = []
    for entry in entries:
        if entry["kind"] != "reference":
            continue
        word = (entry["keywords"] or [entry["topic"]])[0]
        references.append({"topic": " ".join(entry["topic"].split()), "help": " ".join(word.split()).lower()})
    return {"stations": stations, "keys": keys, "passive": passive, "references": references}


def _lua(value):
    """Compact Lua literal (one line per key keeps the module small and diffable)."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{" + ",".join(_lua(v) for v in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join((k if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k) else "[" + json.dumps(k) + "]")
                              + "=" + _lua(value[k]) for k in sorted(value)) + "}"
    raise TypeError(type(value))


def render(data):
    return ("-- console-catalog.lua (UI-03). GENERATED by scripts/ui/build_consoles.py\n"
            "-- from docs/ui/command-ui.json: do not edit by hand.\n"
            "local C = {}\n"
            "C.stations = " + _lua(data["stations"]) + "\n"
            "C.passive = " + _lua(data["passive"]) + "\n"
            "C.keys = {}\n"
            + "".join("C.keys.%s = {\n%s}\n" % (sid, "".join(_lua(k) + ",\n" for k in data["keys"][sid]))
                      for sid in sorted(data["keys"]))
            + "C.references = {\n" + "".join(_lua(r) + ",\n" for r in data["references"]) + "}\n"
            "return C\n")


def main(argv):
    catalog = json.load(open(CATALOG, encoding="utf-8"))
    text = render(build(catalog))
    if "--check" in argv:
        current = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if current != text:
            print("console-catalog.lua is out of date: run python scripts/ui/build_consoles.py")
            return 1
        print("console-catalog.lua is up to date")
        return 0
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print("wrote", os.path.relpath(OUT, ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
