-- lotj-window-dock.lua
-- Window dock (UI-02): a console window minimised with its [_] key hides and
-- leaves a lit key here; pressing the key brings it back. A plain hideWidget is
-- not recorded as the player closing it, so a plain showWidget restores it.
-- The dock itself hides while it holds nothing.

local BODY = [==[
<div class="case dock">
  <div class="head" data-grip><span>DOCK</span><span class="grip-lines"></span></div>
  <div class="keys" id="slots" role="toolbar" aria-label="Docked windows"></div>
</div>
]==]

local CSS = [==[
.dock{border-radius:14px;padding:6px 10px;gap:4px}
.dock .keys{justify-content:flex-start;gap:8px}
.dock .key{width:auto;min-width:46px}
]==]

local SCRIPT = [==[<script>
(function () {
  var slots = document.getElementById("slots");
  function render(list) {
    slots.textContent = "";
    (list || []).forEach(function (item) {
      var key = document.createElement("button");
      key.className = "key green";
      key.type = "button";
      key.title = "Restore " + item.label;
      var label = document.createElement("span");
      label.className = "lbl";
      label.textContent = item.label;
      var well = document.createElement("span");
      well.className = "well";
      var cap = document.createElement("span");
      cap.className = "cap";
      well.appendChild(cap);
      key.appendChild(label);
      key.appendChild(well);
      key.addEventListener("click", function () { LotjUi.send("restore", { id: item.id }); });
      slots.appendChild(key);
    });
  }
  mudforge.onMessage(function (message) {
    if (LotjUi.handle(message)) return;
    if (message && message.event === "windows") render(message.list);
  });
  LotjUi.bindWindow();
  LotjUi.send("ready", {});
})();
</script>]==]

local function create(ports)
  local kit = ports.kit
  local docked = {}
  local dock

  local function publish()
    if not dock then return end
    dock.post({ event = "windows", list = docked })
    if #docked > 0 then showWidget(dock.id) else hideWidget(dock.id) end
  end

  local function find(id)
    for index, item in ipairs(docked) do
      if item.id == id then return index end
    end
  end

  local api = {}
  function api.add(id, label)
    hideWidget(id)
    if not find(id) then docked[#docked + 1] = { id = id, label = tostring(label or id) } end
    publish()
  end
  function api.remove(id)
    local index = find(id)
    if index then
      table.remove(docked, index)
      publish()
    end
  end
  function api.restore(id)
    if find(id) then
      showWidget(id)
      api.remove(id)
    end
  end
  function api.list() return docked end

  local size = ports.size or { width = 320, height = 84 }
  dock = kit.window({
    name = "lotj-window-dock", title = "LOTJ Dock",
    position = ports.position or { x = 20, y = 20 }, size = size, zIndex = 25, visible = false,
    font = ports.font, theme = ports.theme, css = CSS, body = BODY, script = SCRIPT,
    onMessage = function(event, data)
      if event == "ready" then
        dock.post({ event = "windows", list = docked })
      elseif event == "restore" then
        api.restore(data.id)
      end
    end,
  })
  if not dock then return nil end
  api.id = dock.id
  return api
end

return { create = create }
