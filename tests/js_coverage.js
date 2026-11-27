// Line coverage for the JavaScript embedded in src/widgets/*.lua (QA-06).
// Runs every tests/*_widget.js with Node's built-in V8 coverage
// (NODE_V8_COVERAGE, no npm packages), maps the scripts loaded through
// tests/support/widget_script.js back to their .lua lines, and gates the total
// with a ratchet floor in tests/coverage-floor-js.txt.
// Usage: node tests/js_coverage.js [--update]
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { fileURLToPath } = require("node:url");
const { extract, SUFFIX } = require("./support/widget_script.js");

const FLOOR = "tests/coverage-floor-js.txt";
const OUT = ".coverage-js";

// Per-character execution counts for one script. V8 lists each function's
// ranges outer to inner, and functions in source order, so applying them in
// order lets the innermost range win.
function charCounts(length, functions) {
  const counts = new Array(length).fill(1);
  for (const fn of functions) {
    for (const range of fn.ranges) {
      const end = Math.min(range.endOffset, length);
      for (let i = range.startOffset; i < end; i++) counts[i] = range.count;
    }
  }
  return counts;
}

// Executable lines are those with code besides closing punctuation (blank,
// `//` comment and lines like `});` are skipped). A line is covered when its
// first character after any leading closers ran: standard line coverage, so
// `} else if (x) {` is judged by its `else if`, not by the block it closes.
function lineCoverage(code, functions) {
  const counts = charCounts(code.length, functions);
  const lines = new Map();
  let offset = 0;
  code.split("\n").forEach((text, index) => {
    const trimmed = text.trim();
    const lead = /^[\s})\];,]*/.exec(text)[0].length;
    if (lead < text.length && !trimmed.startsWith("//")) {
      lines.set(index, counts[offset + lead] > 0);
    }
    offset += text.length + 1;
  });
  return lines;
}

function widgetTests() {
  return fs.readdirSync("tests").filter(name => name.endsWith("_widget.js")).sort()
    .map(name => path.join("tests", name));
}

function collect() {
  fs.rmSync(OUT, { recursive: true, force: true });
  let failed = false;
  for (const test of widgetTests()) {
    const result = spawnSync(process.execPath, [test], {
      stdio: "inherit", env: { ...process.env, NODE_V8_COVERAGE: path.resolve(OUT) },
    });
    if (result.status !== 0) { console.error(`FAILED: ${test}`); failed = true; }
  }
  const files = new Map(); // .lua path -> { script, lines: Map(line -> covered) }
  for (const name of fs.readdirSync(OUT)) {
    const { result } = JSON.parse(fs.readFileSync(path.join(OUT, name), "utf8"));
    for (const entry of result) {
      if (!entry.url.endsWith(SUFFIX)) continue;
      const luaPath = path.relative(process.cwd(), fileURLToPath(entry.url.slice(0, -SUFFIX.length)));
      const key = luaPath.split(path.sep).join("/");
      const file = files.get(key) || { script: extract(luaPath), lines: new Map() };
      for (const [line, covered] of lineCoverage(file.script.code, entry.functions)) {
        file.lines.set(line, file.lines.get(line) || covered);
      }
      files.set(key, file);
    }
  }
  return { files, failed };
}

function readFloor() {
  if (!fs.existsSync(FLOOR)) return 0;
  const match = /^JS widgets\s+([\d.]+)$/m.exec(fs.readFileSync(FLOOR, "utf8"));
  return match ? Number(match[1]) : 0;
}

function main() {
  const update = process.argv.includes("--update");
  const { files, failed } = collect();
  if (failed) process.exit(1);
  const widgets = fs.readdirSync("src/widgets").filter(name => name.endsWith(".lua"))
    .map(name => `src/widgets/${name}`)
    .filter(file => /<script>/.test(fs.readFileSync(file, "utf8")));
  let total = 0, hit = 0;
  for (const widget of widgets) {
    const file = files.get(widget);
    if (!file) {
      const lines = lineCoverage(extract(widget).code, []).size;
      total += lines;
      console.log(`   0.0% ${String(lines).padStart(5)} lines  ${widget} (no test loads it)`);
      continue;
    }
    const covered = [...file.lines.values()].filter(Boolean).length;
    total += file.lines.size; hit += covered;
    const missed = [...file.lines].filter(([, ok]) => !ok).map(([line]) => line + file.script.lineOffset + 1);
    console.log(`${(100 * covered / file.lines.size).toFixed(1).padStart(6)}% ${String(file.lines.size).padStart(5)} lines  ${widget}` +
      (missed.length ? `  missed: ${missed.slice(0, 12).join(",")}${missed.length > 12 ? ",…" : ""}` : ""));
  }
  const percent = total ? 100 * hit / total : 100;
  const floor = readFloor();
  console.log(`TOTAL ${percent.toFixed(1)}% of ${total} widget JS lines, floor ${floor.toFixed(1)}%`);
  if (update) {
    const measured = Math.floor(percent * 10) / 10;
    if (measured > floor) {
      fs.writeFileSync(FLOOR, `JS widgets ${measured.toFixed(1)}\n`);
      console.log(`floor raised to ${measured.toFixed(1)}%`);
    }
  } else if (percent + 1e-9 < floor) {
    console.log("FAILED: widget JS coverage fell below the floor");
    process.exit(1);
  }
}

if (require.main === module) main();
module.exports = { charCounts, lineCoverage };
