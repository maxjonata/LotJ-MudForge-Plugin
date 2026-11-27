"""Generate pending acceptance specs for open roadmap cards (QA-08).

Reads `gh project item-list 1 --owner maxjonata --format json` output and writes
tests/acceptance/<id>_spec.lua for every Todo card that has no spec yet. Existing
files are never overwritten: once work on a card starts, its spec is edited into
real assertions (TDD) and stays.

Usage: python scripts/roadmap/pending_specs.py <board.json> <tests/acceptance>
"""

from pathlib import Path
import json
import re
import sys

_ID_RE = re.compile(r"^([A-Z]+-\d+)\s*·\s*(.+)$")
_ACCEPT_RE = re.compile(r"\*\*Aceite:\*\*\s*(.+?)(?:\n\s*\n|\n\*\*|\Z)", re.S)


def card_id(title):
    match = _ID_RE.match(title.strip())
    return match.group(1) if match else None


def card_title(title):
    match = _ID_RE.match(title.strip())
    return match.group(2).strip() if match else title.strip()


def acceptance(body):
    match = _ACCEPT_RE.search(body or "")
    if not match:
        return []
    text = re.sub(r"\s+", " ", match.group(1)).strip()
    return [part.strip() for part in text.split(";") if part.strip()]


def spec_path(directory, cid):
    return Path(directory) / (cid.lower().replace("-", "_") + "_spec.lua")


def lua_string(text):
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{escaped}"'


def render(cid, title, criteria):
    lines = [
        f"-- QA-08 acceptance placeholder for {cid}. Generated from the roadmap card;",
        "-- when work on the card starts, replace the pending() call with real",
        "-- assertions that fail first (TDD). This file is never regenerated.",
        'local pending = dofile("tests/support/pending.lua")',
        f"pending({lua_string(cid)}, {lua_string(title)}, {{",
    ]
    lines += [f"  {lua_string(c)}," for c in criteria] or ['  "(no acceptance criteria on the card yet)",']
    lines.append("})")
    return "\n".join(lines) + "\n"


def main(argv):
    board, out = Path(argv[1]), Path(argv[2])
    items = json.loads(board.read_text(encoding="utf-8"))["items"]
    out.mkdir(parents=True, exist_ok=True)
    written = kept = 0
    for entry in items:
        if entry.get("status") != "Todo":
            continue
        cid = card_id(entry.get("title", ""))
        if not cid:
            continue
        path = spec_path(out, cid)
        if path.exists():
            kept += 1
            continue
        body = (entry.get("content") or {}).get("body") or ""
        path.write_text(render(cid, card_title(entry["title"]), acceptance(body)), encoding="utf-8", newline="\n")
        written += 1
    print(f"wrote {written}, kept {kept} -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
