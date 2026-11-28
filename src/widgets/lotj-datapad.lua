-- lotj-datapad.lua
-- Datapad device (DATA-01, Figma "Datapad · arquivos (aparelho)"): a physical
-- datapad window drawn with the UI kit. Every key sends one datamem/datastat
-- command through the datapad use case. Game replies stay in the main window:
-- their format is not known without a live session, so nothing is faked here.

-- Host port (QA-07): a plugin cannot reassign MudForge API names, so the DEV
-- harness (dev/harness.lua) supplies recorders through LotjHost. Release: nil.
local host = LotjHost or {}
local registerCommand = host.registerCommand or registerCommand

local BODY = [==[
<div class="case">
  <div class="head" data-grip><span>DATAPAD</span><span class="grip-lines"></span>
    <span class="dim-ink">SLOT <b id="slot-head">1</b></span></div>
  <div class="bezel"><div class="crt"><div class="screen">
    <div class="tabs" role="tablist">
      <button class="tab" type="button" role="tab" data-tab="files" aria-selected="true">FILES</button>
      <button class="tab" type="button" role="tab" data-tab="inbox" aria-selected="false">INBOX</button>
      <button class="tab" type="button" role="tab" data-tab="disks" aria-selected="false">DISKS</button>
      <button class="tab" type="button" role="tab" data-tab="security" aria-selected="false">SECURITY</button>
      <button class="tab" type="button" role="tab" data-tab="status" aria-selected="false">STATUS</button>
      <span class="grow"></span>
      <label class="dim">SLOT <input id="slot" class="field num" inputmode="numeric" value="1" aria-label="Slot number"></label>
    </div>

    <section data-panel="files" class="cols">
      <div class="col">
        <div class="dim"># SLOT <b class="slot-label">1</b> · FILE</div>
        <div class="softs">
          <button class="soft" type="button" data-act="view">VIEW</button>
          <button class="soft" type="button" data-act="write">EDIT</button>
          <button class="soft" type="button" data-act="send">SEND</button>
          <button class="soft" type="button" data-act="download">DOWNLOAD</button>
          <button class="soft" type="button" data-act="eject">EJECT</button>
          <button class="soft danger" type="button" data-act="delete">DELETE</button>
        </div>
        <div class="row"><span class="dim">SHOW TO</span><input id="target" class="field" aria-label="Show to">
          <button class="soft" type="button" data-act="show" data-arg="target">SHOW</button></div>
        <div class="row"><span class="dim">COPIES</span><input id="amount" class="field num" placeholder="1" aria-label="Copies">
          <button class="soft" type="button" data-act="copy" data-arg="amount">COPY</button></div>
        <div class="note">EDIT = datamem write # · SEND beams the file · SHOW lets someone here read it</div>
      </div>
      <div class="col">
        <div class="dim">WRITE · SLOT <b class="slot-label">1</b></div>
        <div class="row"><span class="dim">TO</span><input id="to" class="field" aria-label="To">
          <button class="soft" type="button" data-act="to" data-arg="text" data-input="to">SET</button></div>
        <div class="row"><span class="dim">FROM</span><input id="from" class="field" aria-label="From">
          <button class="soft" type="button" data-act="from" data-arg="text" data-input="from">SET</button></div>
        <div class="row"><span class="dim">SUBJECT</span><input id="subject" class="field" aria-label="Subject">
          <button class="soft" type="button" data-act="subject" data-arg="text" data-input="subject">SET</button></div>
        <button class="soft wide" type="button" data-act="new">+ WRITE NEW</button>
        <div class="note">The body is typed in the game's own editor after EDIT or WRITE NEW.</div>
      </div>
    </section>
    <section data-panel="inbox" hidden>
      <button class="soft" type="button" data-act="receive">RECEIVE</button>
      <div class="note">datamem receive · takes a file someone beamed to your datapad</div>
    </section>
    <section data-panel="disks" hidden>
      <div class="row"><span class="dim">DISK</span><input id="keyword" class="field" aria-label="Disk keyword">
        <button class="soft" type="button" data-act="load" data-arg="keyword">LOAD</button></div>
      <div class="note">datamem load &lt;disk&gt; · a data disk from your inventory</div>
    </section>
    <section data-panel="security" hidden>
      <button class="soft" type="button" data-act="setbiometrics">SET BIOMETRICS</button>
      <div class="note">datamem setbiometrics · only you can read this datapad</div>
    </section>
    <section data-panel="status" hidden>
      <button class="soft" type="button" data-act="datastat">DATASTAT</button>
      <div class="note">datastat · memory and slots used</div>
    </section>
    <div id="readout" class="readout" aria-live="polite">READY · replies from the game appear in the main window</div>
  </div></div></div>
  <div class="keys">
    <button class="key amber" type="button" data-step="-1"><span class="lbl">PREV</span><span class="well"><span class="cap"></span></span></button>
    <button class="key amber" type="button" data-step="1"><span class="lbl">NEXT</span><span class="well"><span class="cap"></span></span></button>
    <button class="key green" type="button" data-act="view"><span class="lbl">OPEN</span><span class="well"><span class="cap"></span></span></button>
    <button class="key blue" type="button" data-act="receive"><span class="lbl">RECEIVE</span><span class="well"><span class="cap"></span></span></button>
    <button class="key white" type="button" data-goto="disks"><span class="lbl">LOAD</span><span class="well"><span class="cap"></span></span></button>
    <span class="gap"></span>
    <button class="key white" type="button" data-window="dock"><span class="lbl">DOCK</span><span class="well"><span class="cap"></span></span></button>
    <button class="key red" type="button" data-window="off"><span class="lbl">OFF</span><span class="well"><span class="cap"></span></span></button>
  </div>
</div>
]==]

local CSS = [==[
.dim-ink{color:var(--hull-ink);font-size:10px}
.cols{display:flex;flex-wrap:wrap;gap:10px}
.col{flex:1 1 220px;display:flex;flex-direction:column;gap:5px;min-width:0}
.col+.col{border-left:1px solid var(--ph-edge);padding-left:10px}
.softs{display:flex;flex-wrap:wrap;gap:4px}
.row{display:flex;align-items:center;gap:5px}
.row .dim{width:56px;flex:none}
.row .field{flex:1}
.num{width:44px;flex:none!important}
.wide{align-self:flex-start;padding:5px 14px}
section{display:flex;flex-direction:column;gap:6px}
.readout{margin-top:auto;border-top:1px solid var(--ph-edge);padding-top:4px;color:var(--ph-hi)}
.readout.warn{color:#ffb13b}
.gap{width:18px}
]==]

local SCRIPT = [==[<script>
(function () {
  var slotInput = document.getElementById("slot");
  var readout = document.getElementById("readout");
  var current = 1;

  function all(selector) { return Array.prototype.slice.call(document.querySelectorAll(selector)); }
  function say(text, warn) {
    readout.textContent = text;
    if (warn) readout.classList.add("warn"); else readout.classList.remove("warn");
  }
  function disarm() { all(".armed").forEach(function (el) { el.classList.remove("armed"); }); }
  function showTab(name) {
    all("[data-tab]").forEach(function (tab) {
      tab.setAttribute("aria-selected", tab.getAttribute("data-tab") === name ? "true" : "false");
    });
    all("[data-panel]").forEach(function (panel) { panel.hidden = panel.getAttribute("data-panel") !== name; });
  }
  function setSlot(slot) {
    current = slot;
    slotInput.value = String(slot);
    document.getElementById("slot-head").textContent = String(slot);
    all(".slot-label").forEach(function (el) { el.textContent = String(slot); });
  }

  all("[data-tab]").forEach(function (tab) {
    tab.addEventListener("click", function () { showTab(tab.getAttribute("data-tab")); });
  });
  all("[data-goto]").forEach(function (key) {
    key.addEventListener("click", function () {
      showTab(key.getAttribute("data-goto"));
      document.getElementById("keyword").focus();
    });
  });
  all("[data-step]").forEach(function (key) {
    key.addEventListener("click", function () { LotjUi.send("step", { delta: Number(key.getAttribute("data-step")) }); });
  });
  all("[data-act]").forEach(function (button) {
    button.addEventListener("click", function () {
      var args = {};
      var arg = button.getAttribute("data-arg");
      if (arg) args[arg] = document.getElementById(button.getAttribute("data-input") || arg).value;
      LotjUi.send("command", { action: button.getAttribute("data-act"), args: args });
    });
  });
  slotInput.addEventListener("change", function () { LotjUi.send("select", { slot: slotInput.value }); });

  mudforge.onMessage(function (message) {
    if (LotjUi.handle(message) || !message) return;
    if (message.event === "slot") {
      setSlot(message.slot); disarm();
    } else if (message.event === "confirm") {
      disarm();
      all('[data-act="' + message.action + '"]').forEach(function (el) { el.classList.add("armed"); });
      say("PRESS " + message.action.toUpperCase() + " AGAIN · " + message.command, true);
    } else if (message.event === "sent") {
      disarm(); all(".field.invalid").forEach(function (el) { el.classList.remove("invalid"); });
      say("SENT · " + message.command);
    } else if (message.event === "invalid") {
      disarm();
      var field = document.getElementById(message.field);
      if (field) { field.classList.add("invalid"); field.focus(); }
      if (message.field === "slot") setSlot(current);
      say("CHECK " + String(message.field).toUpperCase() + " · nothing sent", true);
    } else if (message.event === "offline") {
      disarm(); say("NOT CONNECTED · nothing sent", true);
    }
  });
  LotjUi.bindWindow();
  LotjUi.send("ready", {});
})();
</script>]==]

-- ports: kit, font, theme, dock, position, newApp(publish) -> datapad use case
local function create(ports)
  local window
  local app = ports.newApp(function(message)
    if window then window.post(message) end
  end)
  window = ports.kit.window({
    name = "lotj-datapad", title = "LOTJ Datapad", label = "DATAPAD",
    position = ports.position or { x = 20, y = 60 }, size = { width = 600, height = 470 },
    zIndex = 15, visible = false,
    font = ports.font, theme = ports.theme, css = CSS, body = BODY, script = SCRIPT, dock = ports.dock,
    onMessage = function(event, data)
      if event == "ready" then
        window.post({ event = "slot", slot = app.slot() })
      elseif event == "command" then
        app.run(data.action, data.args)
      elseif event == "select" then
        app.select(data.slot)
      elseif event == "step" then
        app.step(data.delta)
      end
    end,
  })
  if not window then return nil end

  registerCommand("lotj-datapad", function()
    if ports.dock then ports.dock.remove(window.id) end
    window.show()
  end, "Open the LOTJ datapad")
  return window
end

return { create = create }
