// Station console page script (UI-03) on top of the UI kit script (UI-02):
// tabs, keys, the guided form, the palette and Lua replies.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const widgetScript = require("./support/widget_script.js");
const { sandbox } = require("./support/mini_dom.js");

const LUA = "src/widgets/lotj-station-console.lua";
const body = /local BODY = \[==\[([\s\S]*?)\]==\]/.exec(fs.readFileSync(LUA, "utf8"))[1];
const env = sandbox(body);
widgetScript.run("src/widgets/lotj-ui-kit.lua", env);
widgetScript.run(LUA, env);
const { document, posted } = env;
const $ = id => document.getElementById(id);
const take = () => posted.splice(0);

assert.deepEqual(take(), [["ready", {}]]);
console.log("PASS: the page says ready once");

env.receive({ event: "stations", current: "pilot", list: [
  { id: "pilot", title: "PILOTO", group: "NAVE" }, { id: "nav", title: "NAVEGAÇÃO", group: "NAVE" },
  { id: "datapad", title: "DATAPAD", group: "OFÍCIOS" },
] });
assert.deepEqual($("groups").children.map(t => t.textContent), ["NAVE", "OFÍCIOS"]);
assert.deepEqual($("stations").children.map(t => t.textContent), ["PILOTO", "NAVEGAÇÃO"]);
assert.equal($("stations").children[0].getAttribute("aria-selected"), "true");
$("groups").children[1].click();
$("stations").children[1].click();
assert.deepEqual(take(), [["open", { id: "datapad" }], ["open", { id: "nav" }]]);
console.log("PASS: group and station tabs ask Lua to open a station");

const course = { label: "COURSE", hint: "<x> <y> <z>", color: "amber", input: true, variants: [
  { syntax: "course <x> <y>", notes: ["in space"], args: [{ name: "x", type: "number" }, { name: "mode", type: "choice", choices: ["on", "off"], optional: true }] },
  { syntax: "course away <target>", notes: [], args: [{ name: "target", type: "text" }] },
] };
const station = { event: "station", id: "pilot", title: "PILOTO", about: "Piloto", passive: ["SPACECRAFT"], keys: [
  { label: "AUTOPILOT", hint: "", color: "blue", input: false, variants: [{ syntax: "autopilot", notes: [], args: [] }] },
  course,
  { label: "OLD", hint: "", color: "amber", inactive: true, input: false, variants: [{ syntax: "old", notes: [], args: [] }] },
] };
env.receive(station);
const grid = $("grid").children;
assert.equal($("title").textContent, "PILOTO");
assert.equal($("passive").textContent, "PASSIVO · SPACECRAFT");
assert.equal($("device").hidden, true);
assert.equal(grid.length, 3);
assert.ok(grid[0].classList.contains("blue") && grid[2].classList.contains("off"));
assert.equal(grid[1].children[0].textContent, "COURSE ▸");
grid[0].click();
assert.deepEqual(take(), [["press", { id: "pilot", index: 1 }]]);
console.log("PASS: a station renders one key per command; direct keys press at once");

// The guided form.
grid[1].click();
assert.equal($("form").hidden, false);
assert.equal($("grid").hidden, true);
assert.equal($("form-title").textContent, "COURSE · <x> <y> <z>");
assert.equal($("variants").children.length, 2);
assert.equal($("variants").children[0].getAttribute("aria-pressed"), "true");
const rows = $("fields").children;
assert.equal(rows.length, 2);
assert.equal(rows[1].children[0].textContent, "mode (opcional)");
assert.equal($("notes").textContent, "course <x> <y> · in space");
const x = rows[0].children[1];
assert.equal(x.getAttribute("inputmode"), "numeric");
assert.equal(document.activeElement, x);
x.value = "12";
rows[1].children[3].click(); // chip "off"
x.dispatch("keydown", { key: "a" });
x.dispatch("keydown", { key: "Enter" });
$("go").click();
assert.deepEqual(take(), [
  ["press", { id: "pilot", index: 2, variant: 1, values: ["12", "off"] }],
  ["press", { id: "pilot", index: 2, variant: 1, values: ["12", "off"] }],
]);
$("variants").children[1].click();
assert.equal($("fields").children.length, 1);
assert.equal($("notes").textContent, "course away <target>");
$("fields").children[0].children[1].value = "Kuat";
$("go").click();
assert.deepEqual(take(), [["press", { id: "pilot", index: 2, variant: 2, values: ["Kuat"] }]]);
console.log("PASS: the form picks a variant, fills chips and sends values");

// Replies from Lua.
env.receive({ event: "invalid", field: 1, reason: "required" });
assert.ok($("fields").children[0].children[1].classList.contains("invalid"));
assert.equal($("readout").textContent, "CONFIRA target · obrigatório · nada enviado");
assert.ok($("readout").classList.contains("warn"));
env.receive({ event: "invalid", field: 5, reason: "range" });
assert.equal($("readout").textContent, "CONFIRA ? · fora da faixa · nada enviado");
env.receive({ event: "invalid", reason: "inactive", label: "OLD" });
assert.equal($("readout").textContent, "OLD · comando inativo no jogo");
env.receive({ event: "confirm", command: "kill x" });
assert.equal($("readout").textContent, "PRESSIONE DE NOVO PARA ENVIAR · kill x");
env.receive({ event: "offline" });
assert.equal($("readout").textContent, "SEM CONEXÃO · nada enviado");
env.receive({ event: "sent", command: "course away Kuat" });
assert.equal($("readout").textContent, "ENVIADO · course away Kuat");
assert.ok(!$("readout").classList.contains("warn"));
assert.equal($("form").hidden, true);
grid[1].click();
$("back").click();
assert.equal($("form").hidden, true);
assert.deepEqual(take(), [["cancel", {}]]);
console.log("PASS: invalid, confirm, offline and sent replies; CANCEL disarms");

// The palette.
$("find").value = "  auto ";
$("find").dispatch("input");
assert.deepEqual(take(), [["search", { query: "auto" }]]);
env.receive({ event: "results", list: [] });
assert.equal($("results").children[0].textContent, "nada encontrado");
env.receive({ event: "results", list: [
  { kind: "key", station: "pilot", title: "PILOTO", index: 2, label: "COURSE", hint: "<x>" },
  { kind: "key", station: "pilot", title: "PILOTO", index: 1, label: "AUTOPILOT", hint: "" },
  { kind: "reference", index: 7, topic: "PILOTING" },
] });
const hits = $("results").children;
assert.equal($("results").hidden, false);
assert.equal($("grid").hidden, true);
assert.deepEqual(hits.map(h => h.textContent), ["COURSE · PILOTO · <x>", "AUTOPILOT · PILOTO", "HOLOCRON · PILOTING"]);
hits[2].click();
hits[0].click();
assert.equal($("find").value, "");
assert.deepEqual(take(), [["help", { index: 7 }], ["open", { id: "pilot" }]]);
env.receive(station);
assert.equal($("form").hidden, false, "a palette hit opens its key's form");
assert.equal($("results").hidden, true);
hits[1].click();
env.receive(station);
assert.equal($("form").hidden, true, "a direct key is only shown, never pressed by the palette");
take();
$("find").value = "";
$("find").dispatch("input");
assert.equal($("results").hidden, true);
assert.deepEqual(take(), []);
console.log("PASS: the palette searches, opens keys and Holocron topics");

// The datapad station and kit messages.
env.receive({ event: "station", id: "datapad", title: "DATAPAD", passive: [], keys: [] });
assert.equal($("device").hidden, false);
assert.equal($("about").textContent, "");
assert.equal($("passive").textContent, "");
$("device").click();
assert.deepEqual(take(), [["device", {}]]);
env.receive({ event: "theme", vars: { ph: "#fff" } });
env.receive(null);
env.receive({ event: "other" });
assert.deepEqual(take(), []);
console.log("PASS: the datapad station opens the device; other messages are ignored");
