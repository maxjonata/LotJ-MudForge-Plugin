// Unit checks for tests/js_coverage.js line mapping (QA-06).
const assert = require("node:assert/strict");
const { lineCoverage } = require("./js_coverage.js");

const code = "a();\n\n// note\nif (x) {\n  b();\n}\n";
// Whole script ran once; the block inside `if` (offsets of "  b();\n") never ran.
const start = code.indexOf("  b();"), end = code.indexOf("}");
const lines = lineCoverage(code, [
  { ranges: [{ startOffset: 0, endOffset: code.length, count: 1 }] },
  { ranges: [{ startOffset: start, endOffset: end, count: 0 }] },
]);
assert.deepEqual([...lines], [[0, true], [3, true], [4, false]],
  "blank, comment and closing-brace lines are skipped; an unrun block marks its line missed");

const elseIf = "if (a) {\n  x();\n} else if (b) {\n  y();\n}\n";
const xs = elseIf.indexOf("  x();"), xe = elseIf.indexOf("} else");
const branch = lineCoverage(elseIf, [
  { ranges: [{ startOffset: 0, endOffset: elseIf.length, count: 1 }] },
  { ranges: [{ startOffset: xs, endOffset: xe + 1, count: 0 }] },
]);
assert.equal(branch.get(1), false, "the unrun branch body is missed");
assert.equal(branch.get(2), true, "an else-if line is judged after the brace it closes");

const never = lineCoverage("f();\n", [{ ranges: [{ startOffset: 0, endOffset: 5, count: 0 }] }]);
assert.deepEqual([...never], [[0, false]]);
console.log("PASS: V8 ranges map to executable widget lines");
