// NAV-08 target panel inside the navigation widget, run in a VM with DOM stubs.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync("src/widgets/lotj-scrapper-cockpit.lua", "utf8");
const script = source.match(/<script>([\s\S]*?)<\/script>/)[1];

function element() {
  const events = new Map();
  return {
    textContent: "", style: {}, dataset: {}, children: [], hidden: false, disabled: false, value: "",
    setAttribute() {}, getAttribute() {},
    addEventListener(event, listener) { events.set(event, listener); },
    click() { events.get("click")?.(); },
    focus() {},
    appendChild(child) { this.children.push(child); },
    replaceChildren(fragment) { this.children = fragment.children; },
    querySelector() {},
  };
}
const elements = new Map([...source.matchAll(/\bid="([^"]+)"/g)].map(m => [m[1], element()]));
const arcs = [];
const ctx = {
  beginPath() {}, stroke() {}, moveTo() {}, lineTo() {}, fill() {}, fillRect() {}, fillText() {},
  arc(...args) { arcs.push(args); }, clearRect() { arcs.length = 0; },
};
Object.assign(elements.get("plot"), { width: 720, height: 448, getContext: () => ctx });

const posted = [];
let onMessage;
vm.runInNewContext(script, {
  document: { getElementById: id => elements.get(id), createElement: element, createDocumentFragment: element },
  mudforge: { send: (event, data) => posted.push(JSON.parse(JSON.stringify([event, data ?? null]))), onMessage: fn => { onMessage = fn; } },
});
const $ = id => elements.get(id);
const sent = () => posted.map(([event]) => event).filter(e => e !== "ready");

// Hidden until a target exists.
onMessage({ event: "target", target: { status: "none" } });
assert.equal($("target").hidden, true);

// Clicking a ship contact asks Lua to select it; a planet does not.
onMessage({
  event: "position", position: { x: 0, y: 0, z: 0 }, scanState: "complete",
  contacts: { 1: { name: "Red Fury", category: "ship", x: 30, y: 40, z: 0 },
              2: { name: "Tatooine", category: "planet", x: 10, y: 0, z: 0 } },
});
const [ship, planet] = $("contacts").children;
planet.click();
assert.deepEqual(sent(), [], "planets are not targets");
ship.click();
assert.deepEqual(posted.at(-1), ["select-target", { name: "Red Fury" }]);

// Selected: panel shows geometry, Target and Face enabled, Fire disabled.
const geometry = { name: "Red Fury", dx: 30, dy: 40, dz: 0, distance: 50, bearing: 53.13, elevation: 0 };
arcs.length = 0;
onMessage({ event: "target", target: { ...geometry, status: "selected" } });
assert.equal($("target").hidden, false);
assert.equal($("target").dataset.status, "selected");
assert.equal($("target-name").textContent, "Red Fury");
assert.match($("target-status").textContent, /not targeted/);
assert.match($("target-geo").textContent, /Distance 50 · Bearing 53° · Elevation 0° · ΔX 30 · ΔY 40 · ΔZ 0/);
assert.equal($("target-aim").disabled, false);
assert.equal($("target-face").disabled, false);
assert.equal($("target-fire").disabled, true);
assert.ok(arcs.some(a => a[2] === 13), "the radar draws a reticle on the selected ship");

// Target needs a second click after the aggression warning.
const before = posted.length;
$("target-aim").click();
assert.equal(posted.length, before, "first click only warns");
assert.equal($("target-warning").hidden, false);
$("target-aim").click();
assert.deepEqual(posted.at(-1), ["aim", {}]);
assert.equal($("target-warning").hidden, true);

// Sent: Fire enabled, weapon choice forwarded.
onMessage({ event: "target", target: { ...geometry, status: "sent" } });
assert.match($("target-status").textContent, /unconfirmed/);
assert.equal($("target-fire").disabled, false);
$("target-fire").click();
assert.deepEqual(posted.at(-1), ["fire", { weapon: null }]);
$("target-weapon").value = "ion";
$("target-fire").click();
assert.deepEqual(posted.at(-1), ["fire", { weapon: "ion" }]);
$("target-face").click();
assert.deepEqual(posted.at(-1), ["face", {}]);
$("target-aim").click();
assert.deepEqual(posted.at(-1), ["aim", {}], "the same target is not re-confirmed");

// Lost: actions disabled. A new target name needs confirmation again.
onMessage({ event: "target", target: { ...geometry, status: "lost" } });
assert.equal($("target-aim").disabled, true);
assert.equal($("target-fire").disabled, true);
onMessage({ event: "target", target: { ...geometry, name: "Other", status: "selected" } });
const count = posted.length;
$("target-aim").click();
assert.equal(posted.length, count, "a different ship must be confirmed again");
$("target-clear").click();
assert.deepEqual(posted.at(-1), ["clear-target", {}]);
onMessage({ event: "target", target: null });
assert.equal($("target").hidden, true);
console.log("PASS: target panel selects ships, confirms aggression, gates actions and draws a reticle");
