// Datapad page script (DATA-01) on top of the UI kit script (UI-02): keys post
// the right luamsg, and Lua replies update the slot, readout and armed keys.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const widgetScript = require("./support/widget_script.js");
const { sandbox } = require("./support/mini_dom.js");

const LUA = "src/widgets/lotj-datapad.lua";
const body = /local BODY = \[==\[([\s\S]*?)\]==\]/.exec(fs.readFileSync(LUA, "utf8"))[1];
const env = sandbox(body);
widgetScript.run("src/widgets/lotj-ui-kit.lua", env);
widgetScript.run(LUA, env);
const { document, posted } = env;
const $ = id => document.getElementById(id);
const all = selector => document.querySelectorAll(selector);
const take = () => posted.splice(0);

assert.deepEqual(take(), [["ready", {}]]);
console.log("PASS: the page says ready once");

// Tabs and the LOAD hardware key.
all('[data-tab="inbox"]')[0].click();
assert.equal(all('[data-panel="inbox"]')[0].hidden, false);
assert.equal(all('[data-panel="files"]')[0].hidden, true);
assert.equal(all('[data-tab="inbox"]')[0].getAttribute("aria-selected"), "true");
all('[data-goto="disks"]')[0].click();
assert.equal(all('[data-panel="disks"]')[0].hidden, false);
assert.equal(document.activeElement, $("keyword"));
assert.deepEqual(take(), [], "switching tabs sends nothing");
console.log("PASS: tabs and LOAD switch panels locally");

// Keys and fields.
all('[data-step="-1"]')[0].click();
all('[data-step="1"]')[0].click();
$("subject").value = "Late at bay 2";
all('[data-act="subject"]')[0].click();
$("target").value = "Varn";
all('[data-act="show"]')[0].click();
$("keyword").value = "disk";
all('[data-act="load"]')[0].click();
all('[data-act="view"]')[1].click(); // the OPEN hardware key
$("slot").value = "7";
$("slot").dispatch("change");
assert.deepEqual(take(), [
  ["step", { delta: -1 }], ["step", { delta: 1 }],
  ["command", { action: "subject", args: { text: "Late at bay 2" } }],
  ["command", { action: "show", args: { target: "Varn" } }],
  ["command", { action: "load", args: { keyword: "disk" } }],
  ["command", { action: "view", args: {} }],
  ["select", { slot: "7" }],
]);
console.log("PASS: keys post commands with their field values");

// Replies from Lua.
env.receive({ event: "slot", slot: 7 });
assert.equal($("slot").value, "7");
assert.equal($("slot-head").textContent, "7");
assert.ok(all(".slot-label").every(el => el.textContent === "7"));
env.receive({ event: "confirm", action: "delete", command: "datamem delete 7" });
assert.ok(all('[data-act="delete"]')[0].classList.contains("armed"));
assert.equal($("readout").textContent, "PRESS DELETE AGAIN · datamem delete 7");
assert.ok($("readout").classList.contains("warn"));
env.receive({ event: "invalid", field: "target" });
assert.ok($("target").classList.contains("invalid"));
assert.equal(document.activeElement, $("target"));
assert.equal(all(".armed").length, 0, "any reply disarms");
env.receive({ event: "invalid", field: "slot" });
assert.equal($("slot").value, "7", "a bad slot shows the current one again");
env.receive({ event: "invalid", field: "action" });
assert.equal($("readout").textContent, "CHECK ACTION · nothing sent");
env.receive({ event: "sent", command: "datamem view 7" });
assert.equal($("readout").textContent, "SENT · datamem view 7");
assert.ok(!$("readout").classList.contains("warn"));
assert.equal(all(".field.invalid").length, 0);
env.receive({ event: "offline" });
assert.equal($("readout").textContent, "NOT CONNECTED · nothing sent");
env.receive({ event: "other" });
env.receive(null);
env.receive({ event: "theme", vars: { ph: "#ff5a45" } });
assert.equal(document.documentElement.style.props["--ph"], "#ff5a45");
console.log("PASS: slot, confirm, invalid, sent and offline replies render");
