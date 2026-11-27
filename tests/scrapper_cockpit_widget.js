const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync("src/widgets/lotj-scrapper-cockpit.lua", "utf8");
const script = source.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(script, "cockpit HTML must contain its bridge script");

const elements = new Map([...source.matchAll(/\bid="([^"]+)"/g)].map((match) => [
  match[1],
  {
    textContent: "",
    addEventListener(event, listener) {
      assert.equal(event, "click");
      this.click = listener;
    },
  },
]));

const posted = [];
let onMessage;
vm.runInNewContext(script[1], {
  document: { getElementById: (id) => elements.get(id) },
  mudforge: {
    send: (event) => posted.push(event),
    onMessage: (listener) => { onMessage = listener; },
  },
});

assert.deepEqual(posted, ["ready"]);
elements.get("radar").click();
elements.get("proximity").click();
assert.deepEqual(posted, ["ready", "radar", "proximity"]);
onMessage({ event: "disconnected" });
assert.match(elements.get("notice").textContent, /Connect to the game/);
onMessage({ event: "position", position: { x: 0, y: -8, z: 2 }, connected: true });
assert.equal(elements.get("position").textContent, "X 0 · Y -8 · Z 2");
assert.equal(elements.get("notice").textContent, "");
assert.deepEqual(posted, ["ready", "radar", "proximity"], "rendering must not request scans");
console.log("PASS: cockpit HTML buttons post their scan events and render connection updates");
