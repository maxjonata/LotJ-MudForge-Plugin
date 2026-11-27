const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync("src/widgets/lotj-scrapper-cockpit.lua", "utf8");
const script = source.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(script, "navigation HTML must contain its bridge script");

function element() {
  const events = new Map();
  const attributes = new Map();
  return {
    textContent: "", style: {}, dataset: {}, children: [],
    setAttribute(name, value) { attributes.set(name, value); },
    getAttribute(name) { return attributes.get(name); },
    addEventListener(event, listener) { events.set(event, listener); },
    click() { events.get("click")?.(); },
    focus() {},
    appendChild(child) { this.children.push(child); },
    replaceChildren(fragment) { this.children = fragment.children; },
    querySelector() { return this.children.find(child => child.getAttribute("aria-pressed") === "true"); },
  };
}
const elements = new Map([...source.matchAll(/\bid="([^"]+)"/g)].map(match => [match[1], element()]));
const markers = [];
const context = {
  beginPath() {}, stroke() {}, moveTo() {}, lineTo() {}, arc() {}, fill() {}, fillRect() {},
  clearRect() { markers.length = 0; },
  fillText(...value) { markers.push(value); },
};
Object.assign(elements.get("plot"), { width: 720, height: 448, getContext: () => context });

const posted = [];
let onMessage;
vm.runInNewContext(script[1], {
  document: {
    getElementById: id => elements.get(id),
    createElement: element,
    createDocumentFragment: element,
  },
  mudforge: {
    send: event => posted.push(event),
    onMessage: listener => { onMessage = listener; },
  },
});

assert.deepEqual(posted, ["ready"]);
elements.get("radar").click();
elements.get("proximity").click();
elements.get("zoom-in").click();
assert.equal(elements.get("range").textContent, "500");
assert.deepEqual(posted, ["ready", "radar", "proximity"]);
onMessage({ event: "disconnected" });
assert.match(elements.get("notice").textContent, /Connect to the game/);
onMessage({
  event: "position", position: { x: 0, y: -8, z: 2 }, scanState: "complete",
  contacts: {
    1: { name: "Above", category: "ship", x: 0, y: -8, z: 102 },
    2: { name: "Below", category: "ship", x: 0, y: -8, z: -98 },
    3: { name: "Outside", category: "ship", x: 0, y: -8, z: 802 },
  },
});
assert.equal(elements.get("position").textContent, "X 0 · Y -8 · Z 2");
assert.equal(elements.get("notice").textContent, "");
assert.equal(elements.get("contacts").children.length, 2);
const [above, below] = markers.filter(([glyph]) => glyph === "◆");
assert.equal(above[1], below[1], "height alone changes the projection vertically");
assert.ok(above[2] < below[2], "positive Z must display above negative Z");

const axisOrigin = [360, 246];
for (const label of ["X", "Y", "Z"]) {
  const [, x, y] = markers.find(([glyph]) => glyph === label);
  assert.ok(Math.abs(Math.hypot(x - 7 - axisOrigin[0], y - axisOrigin[1]) - 154) < 0.01,
    "the unit axes must use equal lengths in the isometric projection");
}
elements.get("contacts").children[0].click();
assert.match(elements.get("contact-detail").textContent, /Above.*ΔZ 100/);
elements.get("tab-galaxy").click();
assert.equal(elements.get("galaxy").hidden, false);
onMessage({ event: "galaxy", systems: { 1: { name: "System A", label: "A", x: 2, y: 3 } }, location: { x: 2, y: 3 } });
const system = elements.get("galaxy-chart").children[0];
assert.equal(system.dataset.current, "true");
system.click();
assert.match(elements.get("sector-detail").textContent, /X 2 · Y 3/);

elements.get("tab-map").click();
assert.equal(elements.get("map").hidden, false);
elements.get("open-map").click();
elements.get("open-comms").click();
elements.get("fit-panel").click();
assert.deepEqual(posted, ["ready", "radar", "proximity", "read-galaxy", "read-room", "open-map", "open-comms", "fit-panel"]);
console.log("PASS: isometric projection, contact altitude, range, and local navigation controls");
