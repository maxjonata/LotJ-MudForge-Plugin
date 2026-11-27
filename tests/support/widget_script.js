// Runs the <script> embedded in a widget's .lua file inside a node:vm sandbox.
// The script is compiled with the .lua file's URL (plus "#script") and its
// line/column offset, so stack traces and V8 coverage point at the real lines
// in src/widgets/*.lua (QA-06, read by tests/js_coverage.js).
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { pathToFileURL } = require("node:url");

const SUFFIX = "#script";

function extract(luaPath) {
  const source = fs.readFileSync(luaPath, "utf8");
  const match = /<script>([\s\S]*?)<\/script>/.exec(source);
  if (!match) throw new Error(`${luaPath} has no <script> block`);
  const start = match.index + "<script>".length;
  const before = source.slice(0, start);
  return {
    source,
    code: match[1],
    lineOffset: before.split("\n").length - 1,
    columnOffset: start - (before.lastIndexOf("\n") + 1),
    filename: pathToFileURL(path.resolve(luaPath)).href + SUFFIX,
  };
}

function run(luaPath, sandbox) {
  const script = extract(luaPath);
  new vm.Script(script.code, {
    filename: script.filename,
    lineOffset: script.lineOffset,
    columnOffset: script.columnOffset,
  }).runInNewContext(sandbox);
  return script;
}

module.exports = { extract, run, SUFFIX };
