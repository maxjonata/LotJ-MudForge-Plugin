-- lotj-station-console.lua
-- Station consoles (UI-03, Figma FIG-02..06): one console window drawn with
-- the UI kit that shows any station of docs/ui/command-ui.json. Each key is
-- one help command (label, hint and colour as on the Figma cards); keys with
-- arguments open a guided form; the search field is the command palette and
-- also finds Holocron topics, which open the game's own help. Replies stay in
-- the main window: nothing on this console shows data the game did not send.
-- Live readouts (UI-04) draw the GMCP gauges of the open station above its keys.

-- Host port (QA-07): a plugin cannot reassign MudForge API names, so the DEV
-- harness (dev/harness.lua) supplies recorders through LotjHost. Release: nil.
local host = LotjHost or {}
local registerCommand = host.registerCommand or registerCommand

local BODY = [==[
<div class="case console">
  <div class="head" data-grip><span>CONSOLE</span><span class="grip-lines"></span><span id="title" class="dim-ink">-</span></div>
  <div class="bezel"><div class="crt"><div class="screen">
    <div id="groups" class="tabs" role="tablist" aria-label="Grupos"></div>
    <div id="stations" class="tabs sub" role="tablist" aria-label="Postos"></div>
    <div class="row"><input id="find" class="field grow" placeholder="buscar comando ou tópico do help" aria-label="Buscar comando">
      <button id="device" class="soft" type="button" hidden>ABRIR DATAPAD</button></div>
    <div id="live" class="live" aria-label="Leituras do jogo" hidden></div>
    <div id="about" class="note"></div>
    <div id="grid" class="grid" role="group" aria-label="Comandos do posto"></div>
    <div id="passive" class="note"></div>
    <div id="results" class="results" hidden></div>
    <div id="form" class="form" hidden>
      <div id="form-title" class="dim"></div>
      <div id="variants" class="softs"></div>
      <div id="fields" class="fields"></div>
      <div id="notes" class="note"></div>
      <div class="row"><button id="go" class="soft" type="button">ENVIAR</button>
        <button id="back" class="soft" type="button">CANCELAR</button></div>
    </div>
    <div id="readout" class="readout" aria-live="polite">PRONTO · as respostas do jogo aparecem na janela principal</div>
  </div></div></div>
  <div class="keys">
    <button class="key white" type="button" data-window="dock"><span class="lbl">DOCK</span><span class="well"><span class="cap"></span></span></button>
    <button class="key red" type="button" data-window="off"><span class="lbl">OFF</span><span class="well"><span class="cap"></span></span></button>
  </div>
</div>
]==]

local CSS = [==[
.dim-ink{color:var(--hull-ink);font-size:10px}
.tabs.sub .tab{font-size:10px}
.row{display:flex;align-items:center;gap:5px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(104px,1fr));gap:6px}
.ck{border:0;border-radius:3px;padding:4px 6px;min-height:30px;cursor:pointer;text-align:left;display:flex;flex-direction:column;
  color:#14120f;text-shadow:none;background:linear-gradient(180deg,rgba(255,255,255,.5) 0%,var(--c) 30%,var(--c) 70%,rgba(0,0,0,.35) 100%);
  box-shadow:0 0 8px var(--c),0 2px 0 #000}
.ck:active{transform:translateY(1px)}
.ck .lbl{font-size:10px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ck .hint{font-size:8px;opacity:.75;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ck.off{--c:#4a4740;color:#7f7a6d;cursor:not-allowed}
.ck.armed{outline:1px dashed #fff;animation:lotj-blink .6s steps(2) infinite}
.script .ck .lbl{font-family:"LotjAurebesh","Share Tech Mono",monospace}
.script .ck:hover .lbl,.script .ck:focus-visible .lbl{font-family:"Share Tech Mono",Consolas,monospace}
.results{display:flex;flex-direction:column;gap:2px}
.hit{border:0;background:none;text-align:left;cursor:pointer;color:var(--ph);padding:2px 4px}
.hit:hover,.hit:focus-visible{background:rgba(168,232,106,.12);outline:none}
.form,.fields{display:flex;flex-direction:column;gap:5px}
.fields label{display:flex;align-items:center;gap:6px}
.fields .name{width:120px;flex:none;color:var(--ph-dim)}
.fields .field{flex:1}
.softs{display:flex;flex-wrap:wrap;gap:4px}
.chip{border:1px solid var(--ph-edge);background:none;color:var(--ph-dim);cursor:pointer;padding:0 5px;font-size:9px}
.live{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:3px 10px;border-bottom:1px solid var(--ph-edge);padding-bottom:4px}
.lv{display:flex;align-items:center;gap:5px;font-size:10px;--t:var(--ph)}
.lv.green{--t:#8fe36a}.lv.amber{--t:#ffb13b}.lv.blue{--t:#6ec3ff}.lv.red{--t:#ff5a4a}
.lv-name{width:92px;flex:none;color:var(--ph-dim);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.lv-bar{position:relative;flex:1;height:6px;background:rgba(0,0,0,.5);box-shadow:inset 0 0 0 1px var(--ph-edge)}
.lv-fill{position:absolute;left:0;top:0;bottom:0;background:var(--t);box-shadow:0 0 6px var(--t)}
.lv-mark{position:absolute;top:-2px;bottom:-2px;width:2px;background:#ffb13b}
.lv-val{flex:none;color:var(--t);min-width:56px;text-align:right}
.readout{margin-top:auto;border-top:1px solid var(--ph-edge);padding-top:4px;color:var(--ph-hi)}
.readout.warn{color:#ffb13b}
]==]

local SCRIPT = [==[<script>
(function () {
  var $ = function (id) { return document.getElementById(id); };
  var stations = [], station = null, key = null, keyIndex = 0, variant = 1, inputs = [], pending = null;
  var readout = $("readout");

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text !== undefined) node.textContent = text;
    if (tag === "button") node.type = "button";
    return node;
  }
  function say(text, warn) {
    readout.textContent = text;
    if (warn) readout.classList.add("warn"); else readout.classList.remove("warn");
  }
  function tab(label, selected, onClick) {
    var button = el("button", "tab", label);
    button.setAttribute("role", "tab");
    button.setAttribute("aria-selected", selected ? "true" : "false");
    button.addEventListener("click", onClick);
    return button;
  }
  function open(id) { LotjUi.send("open", { id: id }); }

  function renderTabs(current) {
    var group = null, groups = $("groups"), list = $("stations");
    stations.forEach(function (s) { if (s.id === current) group = s.group; });
    groups.textContent = ""; list.textContent = "";
    var seen = {};
    stations.forEach(function (s) {
      if (!seen[s.group]) {
        seen[s.group] = true;
        groups.appendChild(tab(s.group, s.group === group, function () { open(s.id); }));
      }
      if (s.group === group) list.appendChild(tab(s.title, s.id === current, function () { open(s.id); }));
    });
  }

  function showForm(on) {
    $("form").hidden = !on;
    $("grid").hidden = on;
  }
  function renderFields() {
    var v = key.variants[variant - 1], fields = $("fields");
    fields.textContent = ""; inputs = [];
    v.args.forEach(function (arg) {
      var row = el("label");
      row.appendChild(el("span", "name", arg.name + (arg.optional ? " (opcional)" : "")));
      var input = el("input", "field");
      input.setAttribute("aria-label", arg.name);
      if (arg.type === "number") input.setAttribute("inputmode", "numeric");
      input.addEventListener("keydown", function (event) { if (event.key === "Enter") submit(); });
      row.appendChild(input);
      (arg.choices || []).forEach(function (choice) {
        var chip = el("button", "chip", choice);
        chip.addEventListener("click", function () { input.value = choice; });
        row.appendChild(chip);
      });
      inputs.push(input);
      fields.appendChild(row);
    });
    $("notes").textContent = v.syntax + (v.notes.length ? " · " + v.notes.join(" · ") : "");
    Array.prototype.forEach.call($("variants").children, function (b, i) {
      b.setAttribute("aria-pressed", i === variant - 1 ? "true" : "false");
    });
    if (inputs[0]) inputs[0].focus();
  }
  function openForm(index) {
    keyIndex = index; key = station.keys[index - 1]; variant = 1;
    $("form-title").textContent = key.label + (key.hint ? " · " + key.hint : "");
    var variants = $("variants");
    variants.textContent = "";
    if (key.variants.length > 1) {
      key.variants.forEach(function (v, i) {
        var b = el("button", "chip", v.syntax);
        b.addEventListener("click", function () { variant = i + 1; renderFields(); });
        variants.appendChild(b);
      });
    }
    renderFields();
    showForm(true);
  }
  function submit() {
    LotjUi.send("press", { id: station.id, index: keyIndex, variant: variant,
      values: inputs.map(function (input) { return input.value; }) });
  }

  function renderStation(message) {
    station = message;
    $("title").textContent = message.title;
    $("about").textContent = message.about || "";
    $("device").hidden = message.id !== "datapad";
    $("passive").textContent = message.passive.length ? "PASSIVO · " + message.passive.join(" · ") : "";
    var grid = $("grid");
    grid.textContent = "";
    message.keys.forEach(function (k, i) {
      var b = el("button", "ck " + (k.inactive ? "off" : k.color));
      b.title = k.variants[0].syntax;
      b.appendChild(el("span", "lbl", k.label + (k.input ? " ▸" : "")));
      b.appendChild(el("span", "hint", k.hint || ""));
      b.addEventListener("click", function () {
        if (k.input) openForm(i + 1);
        else LotjUi.send("press", { id: message.id, index: i + 1 });
      });
      grid.appendChild(b);
    });
    showForm(false);
    $("results").hidden = true;
    renderTabs(message.id);
    if (pending && pending.id === message.id && message.keys[pending.index - 1].input) openForm(pending.index);
    pending = null;
  }

  // UI-04: gauges come from GMCP only; the tooltip names the source.
  function renderLive(items) {
    var box = $("live");
    box.textContent = "";
    items.forEach(function (it) {
      var row = el("div", "lv " + (it.tone || ""));
      row.title = it.source;
      row.appendChild(el("span", "lv-name", it.label + (it.kind === "gauge" && it.text ? " · " + it.text : "")));
      if (it.kind === "gauge") {
        var bar = el("span", "lv-bar"), fill = el("span", "lv-fill");
        fill.style.width = it.pct + "%";
        bar.appendChild(fill);
        if (it.mark !== undefined) {
          var mark = el("span", "lv-mark");
          mark.style.left = it.mark + "%";
          bar.appendChild(mark);
        }
        row.appendChild(bar);
        row.appendChild(el("span", "lv-val", it.id === "enemy" ? it.pct + "%" : it.value + "/" + it.max));
      } else row.appendChild(el("span", "lv-val", it.text));
      box.appendChild(row);
    });
    box.hidden = !items.length;
  }

  function renderResults(list) {
    var results = $("results");
    results.textContent = "";
    if (!list.length) results.appendChild(el("div", "note", "nada encontrado"));
    list.forEach(function (hit) {
      var b = el("button", "hit", hit.kind === "key" ? hit.label + " · " + hit.title + (hit.hint ? " · " + hit.hint : "")
        : "HOLOCRON · " + hit.topic);
      b.addEventListener("click", function () {
        $("find").value = "";
        if (hit.kind === "key") { pending = { id: hit.station, index: hit.index }; open(hit.station); }
        else LotjUi.send("help", { index: hit.index });
      });
      results.appendChild(b);
    });
    results.hidden = false; $("grid").hidden = true; $("form").hidden = true;
  }

  $("find").addEventListener("input", function () {
    var query = $("find").value.trim();
    if (query) LotjUi.send("search", { query: query });
    else { $("results").hidden = true; showForm(false); }
  });
  $("go").addEventListener("click", submit);
  $("back").addEventListener("click", function () { showForm(false); LotjUi.send("cancel", {}); });
  $("device").addEventListener("click", function () { LotjUi.send("device", {}); });

  mudforge.onMessage(function (message) {
    if (LotjUi.handle(message) || !message) return;
    if (message.event === "stations") { stations = message.list; renderTabs(message.current); }
    else if (message.event === "station") renderStation(message);
    else if (message.event === "results") renderResults(message.list);
    else if (message.event === "live") renderLive(message.items);
    else if (message.event === "confirm") say("PRESSIONE DE NOVO PARA ENVIAR · " + message.command, true);
    else if (message.event === "sent") { showForm(false); say("ENVIADO · " + message.command); }
    else if (message.event === "offline") say("SEM CONEXÃO · nada enviado", true);
    else if (message.event === "invalid") {
      if (message.reason === "inactive") { say(message.label + " · comando inativo no jogo", true); return; }
      var input = inputs[message.field - 1];
      if (input) { input.classList.add("invalid"); input.focus(); }
      say("CONFIRA " + (key && key.variants[variant - 1].args[message.field - 1] || { name: "?" }).name
        + " · " + ({ required: "obrigatório", number: "número inteiro", range: "fora da faixa" })[message.reason] + " · nada enviado", true);
    }
  });
  LotjUi.bindWindow();
  LotjUi.send("ready", {});
})();
</script>]==]

-- ports: kit, font, theme, dock, position, openDatapad, newApp(publish) -> station console use case,
-- newLive(publish) -> live readout use case (optional, UI-04)
local function create(ports)
  local window
  local function post(message)
    if window then window.post(message) end
  end
  local app = ports.newApp(post)
  local live = ports.newLive and ports.newLive(post)
  local function focus()
    if live then live.focus(app.current()) end
  end
  window = ports.kit.window({
    name = "lotj-station-console", title = "LOTJ Console", label = "CONSOLE",
    position = ports.position or { x = 40, y = 80 }, size = { width = 640, height = 500 },
    zIndex = 15, visible = false,
    font = ports.font, theme = ports.theme, css = CSS, body = BODY, script = SCRIPT, dock = ports.dock,
    onMessage = function(event, data)
      if event == "ready" then
        app.list()
        app.open(app.current())
        focus()
      elseif event == "open" then
        app.open(data.id)
        focus()
      elseif event == "press" then
        app.press(data.id, data.index, data.variant, data.values)
      elseif event == "search" then
        app.search(data.query)
      elseif event == "help" then
        app.help(data.index)
      elseif event == "cancel" then
        app.cancel()
      elseif event == "device" and ports.openDatapad then
        ports.openDatapad()
      end
    end,
  })
  if not window then return nil end

  local function show(args)
    local id = tostring(args or ""):match("^%s*(.-)%s*$")
    if id ~= "" then app.open(id) end
    focus()
    if ports.dock then ports.dock.remove(window.id) end
    window.show()
  end
  registerCommand("lotj-console", show, "Open the LOTJ station console (optional station, e.g. lotj-console pilot)")
  return { id = window.id, show = show, live = live }
end

return { create = create }
