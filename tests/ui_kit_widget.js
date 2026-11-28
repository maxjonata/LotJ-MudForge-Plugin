// UI kit script (UI-02) with the window dock page: theme and script-label
// messages, the drag grip, the [_]/OFF window keys and the dock's keys.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const widgetScript = require("./support/widget_script.js");
const { sandbox } = require("./support/mini_dom.js");

const DOCK = "src/widgets/lotj-window-dock.lua";
const body = /local BODY = \[==\[([\s\S]*?)\]==\]/.exec(fs.readFileSync(DOCK, "utf8"))[1]
  + '<button data-window="off"></button><button data-window="dock"></button>';
const env = sandbox(body);
widgetScript.run("src/widgets/lotj-ui-kit.lua", env);
widgetScript.run(DOCK, env);
const { document, posted, frames } = env;
const ui = env.LotjUi;
assert.deepEqual(posted.splice(0), [["ready", {}]]);

// Kit messages.
assert.equal(ui.handle(null), false);
assert.equal(ui.handle({ event: "windows" }), false);
assert.equal(ui.handle({ event: "theme" }), true);
assert.equal(ui.handle({ event: "theme", vars: { "hull-1": "#000" } }), true);
assert.equal(document.documentElement.style.props["--hull-1"], "#000");
assert.equal(ui.handle({ event: "script", on: false }), true);
assert.ok(!document.body.classList.contains("script"), "Aurebesh labels can be turned off");
env.receive({ event: "script", on: true });
assert.ok(document.body.classList.contains("script"));
console.log("PASS: theme tokens and Aurebesh labels follow kit messages");

// Window keys.
document.querySelectorAll('[data-window="off"]')[0].click();
document.querySelectorAll('[data-window="dock"]')[0].click();
assert.deepEqual(posted.splice(0), [["window", { action: "off" }], ["window", { action: "dock" }]]);
console.log("PASS: OFF and DOCK keys post window actions");

// Grip: deltas summed per animation frame, ignored on buttons and when idle.
const head = document.querySelectorAll("[data-grip]")[0];
head.dispatch("pointermove", { screenX: 5, screenY: 5 });
assert.equal(frames.length, 0, "no drag before pointerdown");
let captured = null;
head.setPointerCapture = id => { captured = id; };
const down = head.dispatch("pointerdown", { screenX: 100, screenY: 100, pointerId: 3 });
assert.ok(down.prevented && captured === 3);
head.dispatch("pointermove", { screenX: 110, screenY: 95 });
head.dispatch("pointermove", { screenX: 112, screenY: 90 });
assert.equal(frames.length, 1, "one frame queued for both moves");
frames.shift()();
assert.deepEqual(posted.splice(0), [["grip", { dx: 12, dy: -10 }]]);
head.dispatch("pointermove", { screenX: 112, screenY: 90 });
frames.shift()();
assert.deepEqual(posted.splice(0), [], "no move, no grip message");
head.dispatch("pointerup");
head.dispatch("pointermove", { screenX: 200, screenY: 200 });
assert.equal(frames.length, 0);
head.setPointerCapture = undefined;
head.dispatch("pointerdown", { screenX: 0, screenY: 0 });
head.dispatch("pointercancel");
const button = document.createElement("button");
head.appendChild(button);
head.dispatch("pointerdown", { target: button, screenX: 0, screenY: 0 });
head.dispatch("pointermove", { screenX: 9, screenY: 9 });
assert.equal(frames.length, 0, "pressing a button inside the head does not drag");
head.dispatch("pointerdown", { target: {}, screenX: 0, screenY: 0 });
head.dispatch("pointerup");
console.log("PASS: the grip posts summed drag deltas");

// Dock keys.
env.receive({ event: "windows", list: [{ id: "lotj-datapad", label: "DATAPAD" }] });
const slots = document.getElementById("slots");
assert.equal(slots.children.length, 1);
const key = slots.children[0];
assert.equal(key.children[0].textContent, "DATAPAD");
assert.equal(key.title, "Restore DATAPAD");
key.click();
assert.deepEqual(posted.splice(0), [["restore", { id: "lotj-datapad" }]]);
env.receive({ event: "windows" });
env.receive({ event: "other" });
env.receive(null);
assert.equal(slots.children.length, 0);
console.log("PASS: the dock draws one key per window and restores it");
