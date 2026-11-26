"""Static checks for LOTJ's direct Lua GMCP and widget API references.

This is a token scan, not a Lua parser or runtime test. GMCP checks cover
literal fields on the first parameter of inline or same-file named handlers,
plus the two conventional handler names used by the status-bar module. They
skip nested functions and do not resolve aliases, shadowing, or computed keys.
"""

import argparse
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
import re
import sys


# Case-sensitive LOTJ wire fields (LotJ/lotj-mudlet-ui's info panel).
FIELDS = {
    'Char.Vitals': frozenset('hp maxHp move maxMove mana maxMana wimpy'.split()),
    'Ship.Info': frozenset(
        'shield maxShield hull maxHull energy maxEnergy piloting speed maxSpeed posX posY posZ'.split()
    ),
}
HANDLER_EVENTS = {
    'onGMCPUpdateCharVitals': 'Char.Vitals',
    'onGMCPUpdateShipInfo': 'Ship.Info',
}
DRAW = {'drawRect', 'drawText', 'drawCircle', 'drawLine', 'drawPolygon'}
GAUGE = {'setGauge', 'setGauges', 'gaugeHTML'}
APIS = DRAW | GAUGE | {
    'onGMCPUpdate', 'addTrigger', 'setBoundValues', 'setActiveWidget', 'createWidget',
}

TOKEN = re.compile(
    r'''(?P<space>\s+)|(?P<comment>--) | (?P<word>[a-zA-Z_][a-zA-Z_0-9]*)
      | (?P<long>\[=*\[) | (?P<quoted>"(?:\\[\s\S]|[^"\\\n])*"|'(?:\\[\s\S]|[^'\\\n])*')
      | (?P<symbol>\.\.\.?|.)''',
    re.VERBOSE,
)
LONG_OPEN = re.compile(r'\[(=*)\[')
ESCAPES = {'a': '\a', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t', 'v': '\v'}
GROUP_END = {
    '(': ')', '[': ']', '{': '}', 'function': 'end', 'if': 'end',
    'do': 'end', 'repeat': 'until',
}


@dataclass(frozen=True)
class Token:
    kind: str
    value: str
    line: int

    @property
    def code(self):
        """String contents never act as Lua syntax."""
        return None if self.kind == 'string' else self.value


def quoted_value(raw):
    def unescape(match: re.Match[str]) -> str:
        escaped = match[1]
        return chr(int(escaped)) if escaped.isdigit() else ESCAPES.get(escaped, escaped)

    return re.sub(r'\\([0-9]{1,3}|[\s\S])', unescape, raw[1:-1])


def tokenize(source):
    pos, line = 0, 1
    while pos < len(source):
        match = TOKEN.match(source, pos)
        if match is None or match.lastgroup is None:
            raise ValueError(f'{line}: cannot tokenize Lua source')
        kind, start_line = match.lastgroup, line
        end = match.end()
        value = match[0]
        long_open = None
        if kind in ('long', 'comment'):
            long_open = LONG_OPEN.match(source, end if kind == 'comment' else pos)
        if long_open:
            close = ']' + long_open[1] + ']'
            finish = source.find(close, long_open.end())
            if finish < 0:
                raise ValueError(f'{line}: unterminated Lua long string or comment')
            end = finish + len(close)
            if kind != 'comment':
                kind = 'string'
                value = source[long_open.end():finish].removeprefix('\n')
        elif kind == 'comment':
            newline = source.find('\n', end)
            end = len(source) if newline < 0 else newline
        elif kind == 'quoted':
            kind, value = 'string', quoted_value(value)
        elif value in ('"', "'"):
            raise ValueError(f'{line}: unterminated Lua quoted string')
        line += source.count('\n', pos, end)
        pos = end
        if kind not in ('space', 'comment'):
            yield Token(kind, value, start_line)


class LuaTokens:
    def __init__(self, source):
        self.tokens = list(tokenize(source))
        self.ends = {}
        stack = []
        for i, token in enumerate(self.tokens):
            code = token.code
            if code in GROUP_END:
                stack.append((i, GROUP_END[code]))
            elif code in (')', ']', '}', 'end', 'until'):
                if not stack or stack[-1][1] != code:
                    raise ValueError(f'{token.line}: unexpected Lua {code!r}')
                self.ends[stack.pop()[0]] = i
        if stack:
            i, expected = stack[-1]
            raise ValueError(f'{self.tokens[i].line}: missing Lua {expected!r}')

    def code(self, i):
        return self.tokens[i].code if 0 <= i < len(self.tokens) else None

    def parts(self, start, end, separators=(',',)):
        """Top-level list entries as half-open ranges, skipping nested groups."""
        parts = []
        i = start
        while i < end:
            if self.code(i) in separators:
                parts.append((start, i))
                start = i + 1
            i = self.ends.get(i, i) + 1
        if start < end:
            parts.append((start, end))
        return parts

    def string(self, start, end):
        if end == start + 1 and self.tokens[start].kind == 'string':
            return self.tokens[start].value
        return None

    def table_type(self, start, end):
        if self.code(start) != '{' or self.ends[start] != end - 1:
            return None
        for lo, hi in self.parts(start + 1, end - 1, separators=(',', ';')):
            if self.code(lo) == 'type' and self.code(lo + 1) == '=':
                return self.string(lo + 2, hi)
            if self.code(lo) == '[' and self.ends[lo] == lo + 2:
                if self.string(lo + 1, lo + 2) == 'type' and self.code(lo + 3) == '=':
                    return self.string(lo + 4, hi)
        return None

    def calls(self):
        for i, token in enumerate(self.tokens[:-1]):
            if token.code not in APIS or self.code(i - 1) in ('.', ':', 'function'):
                continue
            arg = self.tokens[i + 1]
            if arg.code == '(':
                yield token, self.parts(i + 2, self.ends[i + 1])
            elif arg.code == '{' or arg.kind == 'string':
                yield token, [(i + 1, self.ends.get(i + 1, i + 1) + 1)]

    def handlers(self, calls):
        named = defaultdict(list)
        bindings = set()
        for i, token in enumerate(self.tokens):
            if token.code != 'function':
                continue
            if self.code(i + 2) == '(':
                name, params = self.code(i + 1), i + 2
            elif self.code(i + 1) == '(' and self.code(i - 1) == '=':
                name, params = self.code(i - 2), i + 1
            else:
                continue
            named[name].append((i, params))
            if name in HANDLER_EVENTS:
                bindings.add((i, params, HANDLER_EVENTS[name]))
        for token, args in calls:
            if token.value != 'onGMCPUpdate' or len(args) < 2:
                continue
            event = self.string(*args[0])
            if event not in FIELDS:
                continue
            start, end = args[1]
            if self.code(start) == 'function' and self.code(start + 1) == '(':
                bindings.add((start, start + 1, event))
            elif end == start + 1:
                bindings.update((i, params, event) for i, params in named[self.code(start)])
        return sorted(bindings)

    def payload_fields(self, function, params):
        end_params = self.ends[params]
        if end_params == params + 1 or self.tokens[params + 1].kind != 'word':
            return
        payload = self.code(params + 1)
        i = end_params + 1
        while i < self.ends[function]:
            if self.code(i) == 'function':
                i = self.ends[i] + 1
                continue
            if self.code(i) == payload and self.code(i - 1) not in ('.', ':'):
                if self.code(i + 1) == '.' and self.tokens[i + 2].kind == 'word':
                    yield self.tokens[i + 2]
                elif self.code(i + 1) == '[' and self.ends[i + 1] == i + 3:
                    if self.tokens[i + 2].kind == 'string':
                        yield self.tokens[i + 2]
            i += 1


def validate(source):
    lua = LuaTokens(source)
    calls = list(lua.calls())
    for function, params, event in lua.handlers(calls):
        for key in lua.payload_fields(function, params):
            if key.value not in FIELDS[event]:
                yield key.line, f'{event}: unsupported field {key.value!r}'

    # These are source-level guardrails, not widget ownership/control-flow analysis.
    widget_types = {
        lua.table_type(*args[0]) if args else None
        for token, args in calls if token.value == 'createWidget'
    }
    active_seen = False
    for token, args in calls:
        name = token.value
        if name == 'setBoundValues':
            yield token.line, 'use sendWidgetMessage instead of setBoundValues for LOTJ widgets'
        elif name == 'addTrigger' and args:
            pattern = lua.string(*args[0])
            if pattern and (pattern.startswith('^') or pattern.endswith('$')):
                mode = args[2] if len(args) > 2 else None
                if mode:
                    lo, hi = mode
                    if (hi == lo + 1 and lua.code(lo) == 'true') or lua.table_type(lo, hi) == 'regex':
                        continue
                yield token.line, 'anchored addTrigger pattern needs explicit regex mode'
        elif name == 'setActiveWidget':
            active_seen = True
        elif name in DRAW and not active_seen:
            yield token.line, f'{name} appears before any setActiveWidget call in this file'
        elif name in GAUGE and widget_types == {'canvas'}:
            yield token.line, f'{name} is HTML-only; this file creates only canvas widgets'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_dir', type=Path, nargs='?', default=Path('src'))
    root = parser.parse_args().source_dir
    files = sorted(path for path in root.rglob('*.lua') if path.is_file())
    if not files:
        parser.error(f'no Lua files found under {root}')
    failed = False
    for path in files:
        try:
            for line, message in sorted(validate(path.read_text(encoding='utf-8'))):
                print(f'{path}:{line}: {message}', file=sys.stderr)
                failed = True
        except (OSError, ValueError) as error:
            print(f'{path}: {error}', file=sys.stderr)
            return 2
    if failed:
        return 1
    print(f'GMCP and widget API validation passed ({len(files)} Lua files).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
