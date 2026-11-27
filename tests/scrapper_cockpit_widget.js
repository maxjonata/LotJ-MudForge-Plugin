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
const paths = [];
let path;
const context = {
  beginPath() { path = []; },
  stroke() { paths.push(path); },
  moveTo(...point) { path.push(point); },
  lineTo(...point) { path.push(point); },
  arc() {}, fill() {}, fillRect() {},
  clearRect() { markers.length = 0; paths.length = 0; },
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
const segments = paths.filter(path => path.length === 2);
const close = (actual, expected) => Math.abs(actual - expected) < 0.01;
const segmentEndsAt = (segment, [x, y]) => close(segment[1][0], x) && close(segment[1][1], y);
for (const label of ["X", "Y", "Z"]) {
  const [, x, y] = markers.find(([glyph]) => glyph === label);
  const tip = [x - 7, y];
  assert.ok(close(Math.hypot(tip[0] - axisOrigin[0], tip[1] - axisOrigin[1]), 154),
    "the unit axes must use equal lengths in the isometric projection");
  assert.ok(segments.some(segment => segmentEndsAt(segment, tip)
    && close((segment[0][0] + tip[0]) / 2, axisOrigin[0])
    && close((segment[0][1] + tip[1]) / 2, axisOrigin[1])), "the axis must be drawn through the origin");
}
for (const marker of [above, below]) {
  assert.ok(segments.some(segment => segmentEndsAt(segment, [marker[1] + 5, marker[2] - 5])
    && close(segment[0][0], axisOrigin[0]) && close(segment[0][1], axisOrigin[1])),
  "the elevation stem must connect the contact with its ground projection");
}
elements.get("contacts").children[0].click();
assert.match(elements.get("contact-detail").textContent, /Above.*ΔZ 100/);
onMessage({ event: "position", scanState: "truncated", contacts: [] });
assert.match(elements.get("notice").textContent, /first 256 contacts/);
onMessage({ event: "position", scanState: "timeout", radarBusy: true });
assert.ok(elements.get("radar").disabled);
assert.match(elements.get("notice").textContent, /Discarding late lines/);
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
assert.deepEqual(posted, ["ready", "radar", "proximity", "select-target", "read-galaxy", "read-room", "open-map", "open-comms", "fit-panel"]);
console.log("PASS: isometric projection, contact altitude, range, and local navigation controls");
