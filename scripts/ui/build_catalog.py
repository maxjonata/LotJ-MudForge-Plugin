"""Build docs/ui/command-ui.json: one UI destination for every LotJ help topic (FIG-01).

Inputs (all committed, so CI can check the catalog is current):
  docs/reference/lotj-commands.json  help metadata (scripts/reference/extract_help.py)
  docs/ui/overrides.json             hand decisions by topic: status, pattern, area, kind, note
  docs/ui/figma-nodes.json           Figma frames and the topics each one draws

Every topic gets a kind (command, passive or reference), an area, an interaction
pattern and, per syntax variant, typed arguments. A topic is "designed" once a
Figma frame claims it; until then it is "planned".

Usage: python scripts/ui/build_catalog.py
"""

from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / "docs/reference/lotj-commands.json"
OVERRIDES = ROOT / "docs/ui/overrides.json"
NODES = ROOT / "docs/ui/figma-nodes.json"
OUTPUT = ROOT / "docs/ui/command-ui.json"

PATTERNS = {
    "direct": "One button or shortcut; no arguments.",
    "target": "Action on one entity, offered in that entity's context menu.",
    "form": "Several arguments filled in a small form before sending.",
    "flow": "Multi-step manoeuvre with progress and an abort control.",
    "toggle": "On/off or mode switch that shows its current state.",
    "list": "List with detail and per-item actions.",
    "editor": "Multi-line text editor with send/save.",
    "craft": "Recipe crafting: pick type, components, then build.",
    "comms": "Message composer bound to a channel, tone or language.",
    "readout": "Passive panel or indicator; nothing to send.",
    "reference": "Holocron article linked to the official help.",
    "palette": "Reachable only from the command palette with guided syntax.",
}
AREAS = ["space", "room", "comms", "character", "combat", "force", "economy", "crafting",
         "datapad", "clan", "general", "reference"]
STATUSES = ["planned", "designed", "gap", "inactive", "restricted"]
KINDS = ["command", "passive", "reference"]
OVERRIDE_FIELDS = {"status", "pattern", "area", "kind", "note"}

_TOKEN_RE = re.compile(r"<([^<>]+)>|\(([^()]+)\)|\[([^\[\]]+)\]")
_PRECONDITION_RE = re.compile(r"^(while|when|in|on|only|must|requires?)\b", re.I)
_TYPE_WORDS = [
    ("ship", {"ship", "ships", "vessel", "starship", "shuttle", "fighter"}),
    ("character", {"target", "victim", "character", "char", "player", "mob", "person", "receiver",
                   "someone", "pilot", "member", "recipient", "opponent", "enemy", "ally"}),
    ("object", {"object", "obj", "item", "container", "weapon", "armor", "corpse", "keyring", "key"}),
    ("direction", {"direction", "dir", "exit"}),
    ("place", {"planet", "system", "starsystem", "location", "room", "destination", "hangar", "bay"}),
    ("number", {"#", "number", "num", "amount", "x", "y", "z", "coordinate", "coordinates", "level",
                "percent", "credits", "distance", "speed", "id", "slot"}),
    ("name", {"skill", "spell", "social", "class", "race", "language", "tone", "option", "ability",
              "power", "channel", "frequency", "clan", "type"}),
]
_TOGGLES = {"on/off", "on|off", "off/on", "off|on", "yes/no", "yes|no"}
_AREA_KEYWORDS = {
    "room": {"north", "south", "east", "west", "up", "down", "northeast", "northwest", "southeast",
             "southwest", "look", "exits", "open", "close", "lock", "unlock", "enter", "leave",
             "follow", "scan", "search", "sit", "stand", "rest", "sleep", "wake"},
    "datapad": {"datamem", "datapad", "mail", "note", "board", "boards", "message"},
    "clan": {"clan", "clans", "induct", "outcast", "empower", "demote", "promote", "war", "govern"},
    "character": {"score", "practice", "train", "research", "skills", "inventory", "equipment",
                  "title", "description", "bio", "gender", "wimpy", "save", "worth", "affects"},
}
_TAG_AREAS = [("ship", "space"), ("force", "force"), ("combat", "combat"), ("economy", "economy"),
              ("comms", "comms")]
_COMMS_KEYWORDS = {"say", "tell", "reply", "emote", "pemote", "yell", "shout", "whisper", "ooc",
                   "chat", "commnet", "broadcast", "clantalk", "shiptalk", "gtell", "ptalk",
                   "think", "speak", "language", "tone", "beep", "osay", "to"}
_EDITOR_KEYWORDS = {"datamem", "mail", "note", "description", "bio", "write", "proposedesc"}
_RANK = ["direct", "toggle", "target", "form"]


def _words(text):
    return re.findall(r"[a-z]+|#", text.lower())


def _arg(inner):
    inner = " ".join(inner.split())
    low = inner.lower()
    if low in _TOGGLES:
        return {"name": inner, "type": "toggle"}
    if "|" in inner or ("/" in inner and " " not in inner):
        return {"name": inner, "type": "choice", "choices": [c for c in re.split(r"[|/]", inner) if c]}
    words = set(_words(inner))
    if "#" in words:
        return {"name": inner, "type": "number"}
    for kind, vocabulary in _TYPE_WORDS:
        if words & vocabulary:
            return {"name": inner, "type": kind}
    return {"name": inner, "type": "text"}


def args(syntax):
    out = []
    for match in _TOKEN_RE.finditer(syntax):
        inner = next(g for g in match.groups() if g is not None)
        if match.group(2) is not None and _PRECONDITION_RE.match(inner.strip()):
            continue
        arg = _arg(inner)
        if match.group(3) is not None:
            arg["optional"] = True
        out.append(arg)
    return out


def preconditions(syntax):
    return [g.strip() for g in re.findall(r"\(([^()]+)\)", syntax) if _PRECONDITION_RE.match(g.strip())]


def variant_pattern(syntax):
    found = args(syntax)
    if not found:
        return "direct"
    if all(a["type"] == "toggle" for a in found):
        return "toggle"
    if len(found) == 1 and found[0]["type"] in {"ship", "character", "object", "direction"}:
        return "target"
    return "form"


def _variants(syntax_lines):
    variants = []
    for line in syntax_lines:
        for part in re.split(r"\s+OR\s+", line):
            part = " ".join(part.split())
            if part:
                variants.append({"syntax": part, "pattern": variant_pattern(part),
                                 "args": args(part), "preconditions": preconditions(part)})
    return variants


def _kind(t):
    if not t["syntax"]:
        return "reference"
    first = t["syntax"][0].strip().lower()
    if first.startswith(("passive", "n/a")) or "automatic" in first:
        return "passive"
    return "command"


def _area(t, kind, pattern):
    if kind == "reference":
        return "reference"
    if pattern == "craft":
        return "crafting"
    keywords = {k.lower() for k in t["keywords"]}
    for area, vocabulary in _AREA_KEYWORDS.items():
        if keywords & vocabulary:
            return area
    if keywords & _COMMS_KEYWORDS:
        return "comms"
    tags = set(t["inferred_tags"])
    for tag, area in _TAG_AREAS:
        if tag in tags:
            return area
    return "general"


def _pattern(t, kind, variants):
    if kind == "reference":
        return "reference"
    if kind == "passive":
        return "readout"
    keywords = {k.lower() for k in t["keywords"]}
    if any(k.startswith("make") for k in keywords):
        return "craft"
    if keywords & _EDITOR_KEYWORDS:
        return "editor"
    if keywords & _COMMS_KEYWORDS:
        return "comms"
    syntaxes = [v["syntax"].lower().split() for v in variants]
    if any(s and s[-1] in {"abort", "cancel"} for s in syntaxes):
        return "flow"
    if any(len(s) > 1 and s[1] == "list" for s in syntaxes):
        return "list"
    return max((v["pattern"] for v in variants), key=_RANK.index, default="palette")


def entry(t):
    kind = _kind(t)
    variants = _variants(t["syntax"]) if kind == "command" else []
    pattern = _pattern(t, kind, variants)
    return {
        "topic": t["topic"],
        "keywords": t["keywords"],
        "url": t["url"],
        "kind": kind,
        "area": _area(t, kind, pattern),
        "pattern": pattern,
        "variants": variants,
        "status": "planned",
        "figma_node": None,
    }


def figma_links(nodes):
    links = {}
    for node in nodes.get("nodes", []):
        for name in node.get("topics", []):
            links.setdefault(name, node["id"])
    return links


def build(topics, overrides, links=None):
    links = links or {}
    names = {t["topic"] for t in topics}
    unknown = sorted((set(overrides) | set(links)) - names)
    if unknown:
        raise ValueError("unknown topics: " + ", ".join(unknown))
    entries = []
    for t in sorted(topics, key=lambda t: (t["topic"], t["url"])):
        e = entry(t)
        if t["topic"] in links:
            e["figma_node"] = links[t["topic"]]
            e["status"] = "designed"
        override = overrides.get(t["topic"], {})
        bad = set(override) - OVERRIDE_FIELDS
        if bad:
            raise ValueError(f"{t['topic']}: unknown override fields {sorted(bad)}")
        e.update(override)
        entries.append(e)
    counts = {}
    for e in entries:
        counts[e["pattern"]] = counts.get(e["pattern"], 0) + 1
    return {
        "source": "docs/reference/lotj-commands.json",
        "note": "Generated by scripts/ui/build_catalog.py. Edit docs/ui/overrides.json, not this file.",
        "patterns": PATTERNS,
        "counts": dict(sorted(counts.items())),
        "entries": entries,
    }


def main():
    topics = json.loads(REFERENCE.read_text(encoding="utf-8"))["topics"]
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8"))
    nodes = json.loads(NODES.read_text(encoding="utf-8"))
    catalog = build(topics, overrides, figma_links(nodes))
    OUTPUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(catalog['entries'])} topics -> {OUTPUT.relative_to(ROOT)} {catalog['counts']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
