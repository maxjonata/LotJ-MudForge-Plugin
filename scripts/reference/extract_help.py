"""Extract LotJ command metadata from locally cached public help pages.

Only metadata is written: topic, keywords, syntax lines, see-also links, the
official URL, and tags inferred from the text. Help prose is never copied.

Usage: python scripts/reference/extract_help.py <pages_dir> <out.json>
"""

from pathlib import Path
import html
import json
import re
import sys
import urllib.parse

SOURCE = "https://www.legendsofthejedi.com/help"
_SOURCE_RE = re.compile(r"<!-- source: (\S+) -->")
_BODY_RE = re.compile(r'<pre class="help-body[^"]*"[^>]*>(.*?)</pre>', re.S)
_KEYWORD_RE = re.compile(r"'([^']*)'|\"([^\"]*)\"|(\S+)")
_SYNTAX_RE = re.compile(r"^\s*syntax\s*:\s*(.*)$", re.I)
_SEE_ALSO_RE = re.compile(r"^\s*see also\s*:\s*(.*)$", re.I)
# Some pages keep the MUD's two-digit colour codes as plain text ("08Syntax: 14say").
_CODED_RE = re.compile(r"^\d{2}(?:syntax|see also)\s*:", re.I | re.M)
_CODE_RE = re.compile(r"(?<!\d)\d{2}(?!\d)")

# Tags are a search aid, flagged as inferred: they are guesses, not game facts.
TAG_WORDS = {
    "ship": ("ship", "pilot", "hyperspace", "radar", "launch", "spacecraft", "starship", "hangar"),
    "combat": ("attack", "damage", "weapon", "kill", "combat", "fight", "wield"),
    "force": ("force", "jedi", "sith", "lightsaber"),
    "comms": ("comlink", "channel", "tell", "chat", "commnet", "broadcast"),
    "economy": ("credits", "buy", "sell", "cargo", "price", "shop"),
}


def _keywords(topic):
    words = []
    for quoted1, quoted2, bare in _KEYWORD_RE.findall(topic):
        word = (quoted1 or quoted2 or bare).strip()
        if word:
            words.append(word)
    return words


def _block(lines, start, first):
    """Collect `first` plus indented, non-blank continuation lines."""
    items = [first] if first.strip() else []
    i = start + 1
    while i < len(lines) and lines[i].strip() and lines[i][:1].isspace():
        if _SYNTAX_RE.match(lines[i]) or _SEE_ALSO_RE.match(lines[i]):
            break
        items.append(lines[i])
        i += 1
    return [re.sub(r"\s+", " ", item).strip() for item in items]


def parse_page(text):
    body_match = _BODY_RE.search(text)
    source_match = _SOURCE_RE.search(text)
    if not body_match or not source_match:
        return None
    url = source_match.group(1)
    query = urllib.parse.urlparse(url).query
    topic = urllib.parse.unquote(urllib.parse.parse_qs(query).get("topic", [""])[0])
    body = html.unescape(body_match.group(1))
    if _CODED_RE.search(body):
        body = _CODE_RE.sub("", body)
    lines = body.splitlines()

    syntax, see_also = [], []
    for i, line in enumerate(lines):
        match = _SYNTAX_RE.match(line)
        if match:
            syntax.extend(_block(lines, i, match.group(1)))
            continue
        match = _SEE_ALSO_RE.match(line)
        if match:
            for chunk in _block(lines, i, match.group(1)):
                see_also.extend(part.strip() for part in chunk.split(",") if part.strip())

    lowered = body.lower()
    tags = sorted(tag for tag, words in TAG_WORDS.items()
                  if any(re.search(r"\b" + re.escape(w) + r"\b", lowered) for w in words))
    keywords = _keywords(topic)
    return {
        "topic": " ".join(keywords) if len(keywords) == 1 else topic,
        "keywords": keywords,
        "syntax": syntax,
        "see_also": see_also,
        "is_command": bool(syntax),
        "inferred_tags": tags,
        "url": url,
    }


def main(argv):
    pages, out = Path(argv[1]), Path(argv[2])
    topics, skipped = [], 0
    for path in sorted(pages.glob("*.html")):
        entry = parse_page(path.read_text(encoding="utf-8", errors="replace"))
        if entry is None:
            skipped += 1
        else:
            topics.append(entry)
    topics.sort(key=lambda e: e["topic"].upper())
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({
        "source": SOURCE,
        "note": "Metadata only. Read the full help text at the official URL of each topic.",
        "skipped": skipped,
        "topics": topics,
    }, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"{len(topics)} topics, {skipped} skipped -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
