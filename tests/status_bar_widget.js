// Status bar page script (HUD-01/SHIP-01): every message the Lua side sends
// updates the right element, and partial or zero values never break it.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const widgetScript = require("./support/widget_script.js");

const LUA = "src/widgets/lotj-status-bar.lua";
const source = fs.readFileSync(LUA, "utf8");

function element() {
  const classes = new Set();
  return {
    textContent: "", className: "", style: {},
    classList: { add: name => classes.add(name), remove: name => classes.delete(name), has: name => classes.has(name) },
  };
}
const elements = new Map([...source.matchAll(/\bid="([^"]+)"/g)].map(match => [match[1], element()]));
const get = id => elements.get(id);
const posted = [];
let onMessage;
widgetScript.run(LUA, {
  Math,
  document: { getElementById: id => elements.get(id) },
  mudforge: { send: (event, data) => posted.push([event, data]), onMessage: listener => { onMessage = listener; } },
});
assert.deepEqual(JSON.parse(JSON.stringify(posted)), [["ready", { widget: "lotj-status-bar" }]]);

// Vitals: bars clamp to 0..100, wimpy tick shows only inside the HP range.
onMessage({ event: "vitals", values: { hp: 30, maxHp: 60, wimpy: 15, move: 120, maxMove: 100, force: 5, maxForce: 10 } });
assert.equal(get("hp-fill").style.width, "50%");
assert.equal(get("hp-text").textContent, "30/60");
assert.equal(get("wimpy-tick").style.left, "25%");
assert.equal(get("wimpy-tick").style.opacity, "1");
assert.equal(get("mv-fill").style.width, "100%", "move above max is clamped");
assert.equal(get("mv-text").textContent, "120/100");
assert.equal(get("gauge-force").style.display, "flex");
assert.equal(get("force-fill").style.width, "50%");
assert.equal(get("force-text").textContent, "5/10");

onMessage({ event: "vitals", values: { hp: -5, maxHp: 60, wimpy: 0, force: 0, maxForce: 0 } });
assert.equal(get("hp-fill").style.width, "0%", "negative HP is clamped");
assert.equal(get("wimpy-tick").style.opacity, "0", "no wimpy hides the tick");
assert.equal(get("gauge-force").style.display, "none", "no Force pool hides the bar");
assert.equal(get("mv-text").textContent, "120/100", "missing move keeps the last value");
onMessage({ event: "vitals" });
onMessage({ event: "vitals", values: {} });
console.log("PASS: vitals fill HP, MV, Force and the wimpy tick");

// Ship row: shown with gauges and the piloting label, hidden by visible=false.
onMessage({ event: "shipVisible", visible: true, ship: { shield: 25, maxShield: 50, hull: 10, maxHull: 10, energy: 1, maxEnergy: 4, piloting: "Red Fury" } });
assert.ok(get("ship-row").classList.has("visible"));
assert.equal(get("shield-fill").style.width, "50%");
assert.equal(get("hull-fill").style.width, "100%");
assert.equal(get("energy-fill").style.width, "25%");
assert.equal(get("comlink-indicator").textContent, "📡 Red Fury");
onMessage({ event: "shipVisible", visible: true, ship: {} });
assert.equal(get("shield-fill").style.width, "50%", "a partial packet keeps the old gauges");
onMessage({ event: "shipVisible", visible: false });
assert.ok(!get("ship-row").classList.has("visible"));
console.log("PASS: ship row shows gauges and hides on visible=false");

// Opponent and comlink.
onMessage({ event: "enemyInfo", enemy: { name: "a stormtrooper", percent: 42 } });
assert.ok(get("opponent-bar").classList.has("visible"));
assert.equal(get("target-name").textContent, "a stormtrooper");
assert.equal(get("target-fill").style.width, "42%");
assert.equal(get("target-pct").textContent, "42%");
onMessage({ event: "enemyInfo", enemy: {} });
assert.equal(get("target-name").textContent, "Unknown");
onMessage({ event: "enemyInfo" });
onMessage({ event: "comlink", channel: { active: true, name: "1234" } });
assert.equal(get("comlink-indicator").textContent, "📡 1234");
onMessage({ event: "comlink", channel: { active: true } });
assert.equal(get("comlink-indicator").textContent, "📡 ");
onMessage({ event: "comlink", channel: { active: false } });
assert.equal(get("comlink-indicator").textContent, "🔇 Muted");
assert.equal(get("comlink-indicator").className, "comlink");
onMessage({ event: "comlink" });
onMessage({ event: "unknown" });
console.log("PASS: opponent and comlink indicators follow their messages");
