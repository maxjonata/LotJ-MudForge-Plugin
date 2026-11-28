-- lotj-ui-kit.lua
-- Shared console kit (UI-02): every LotJ panel is a frameless MudForge HTML
-- widget that draws its own hardware (docs/ui/README.md "Console key and
-- depth"). The kit owns the theme tokens, the casing / bezel / CRT / Console
-- Key CSS, the embedded Aurebesh AF font, the drag grip, and the [_] dock and
-- OFF buttons. Feature widgets only supply their body markup and script.

-- Host port (QA-07): a plugin cannot reassign MudForge API names, so the DEV
-- harness (dev/harness.lua) supplies recorders through LotjHost. Release: nil.
local host = LotjHost or {}
local createWidget = host.createWidget or createWidget
local registerWidgetEvent = host.registerWidgetEvent or registerWidgetEvent
local sendWidgetMessage = host.sendWidgetMessage or sendWidgetMessage

-- Theme tokens. Neutral is the default console (Figma "Datapad · arquivos");
-- Empire is the approved clan console (gunmetal hull, red vector screens).
local THEMES = {
  neutral = {
    ["hull-1"] = "#8d8778", ["hull-2"] = "#6f6a5e", ["hull-3"] = "#57534a", ["hull-ink"] = "#2a2822",
    bezel = "#2b2a27", ["scr-1"] = "#1d2a14", ["scr-2"] = "#0d140a", ["scr-3"] = "#070a05",
    ph = "#a8e86a", ["ph-hi"] = "#d8ffa8", ["ph-dim"] = "#6f9a4a", ["ph-edge"] = "#3f5a2a",
    ["ph-glow"] = "rgba(168,232,106,.45)", ["soft-1"] = "#8ff06a", ["soft-2"] = "#3fae3a",
  },
  empire = {
    ["hull-1"] = "#6b7178", ["hull-2"] = "#4b5057", ["hull-3"] = "#33373d", ["hull-ink"] = "#e3e6ea",
    bezel = "#c9ccd1", ["scr-1"] = "#241010", ["scr-2"] = "#140808", ["scr-3"] = "#070303",
    ph = "#ff5a45", ["ph-hi"] = "#ffc2b8", ["ph-dim"] = "#a3392d", ["ph-edge"] = "#5a1f19",
    ["ph-glow"] = "rgba(255,90,69,.45)", ["soft-1"] = "#ff7a66", ["soft-2"] = "#c8281a",
  },
}

local function themeVars(name)
  return THEMES[name] or THEMES.neutral
end

local function cssVars(vars)
  local keys = {}
  for key in pairs(vars) do keys[#keys + 1] = key end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do parts[#parts + 1] = "--" .. key .. ":" .. vars[key] .. ";" end
  return ":root{" .. table.concat(parts) .. "}"
end

local CSS = [==[
*{box-sizing:border-box}
html,body{margin:0;height:100%;overflow:hidden;background:transparent;color:var(--ph);
  font:11px "Share Tech Mono",Consolas,"Courier New",monospace}
button,input{font:inherit;color:inherit}
[hidden]{display:none!important}
.grow{flex:1}
.case{position:absolute;inset:6px;display:flex;flex-direction:column;gap:8px;padding:8px 14px 10px;border-radius:22px;
  background:linear-gradient(180deg,var(--hull-1) 0%,var(--hull-2) 55%,var(--hull-3) 100%);
  box-shadow:0 10px 24px rgba(0,0,0,.6),inset 0 2px 0 rgba(255,255,255,.35),inset 0 -3px 0 rgba(0,0,0,.35)}
.head{display:flex;align-items:center;gap:10px;min-height:20px;color:var(--hull-ink);letter-spacing:2px;font-size:12px;
  user-select:none;cursor:move;touch-action:none}
.head .grip-lines{flex:1;height:6px;opacity:.5;
  background:repeating-linear-gradient(90deg,var(--hull-ink) 0 1px,transparent 1px 4px)}
.bezel{flex:1;min-height:0;display:flex;border-radius:14px;padding:8px;background:var(--bezel);
  box-shadow:inset 0 3px 8px rgba(0,0,0,.8),0 1px 0 rgba(255,255,255,.25)}
.crt{position:relative;flex:1;min-height:0;display:flex;flex-direction:column;border-radius:9px;overflow:hidden;
  background:radial-gradient(ellipse at 50% 40%,var(--scr-1) 0%,var(--scr-2) 70%,var(--scr-3) 100%);
  text-shadow:0 0 4px var(--ph-glow)}
.crt::after{content:"";position:absolute;inset:0;pointer-events:none;
  background:repeating-linear-gradient(0deg,rgba(0,0,0,.25) 0 1px,transparent 1px 3px),
    linear-gradient(160deg,rgba(255,255,255,.07),transparent 40%)}
.screen{flex:1;min-height:0;overflow:auto;display:flex;flex-direction:column;gap:6px;padding:6px 9px}
.tabs{display:flex;gap:2px;flex-wrap:wrap;align-items:center;border-bottom:1px solid var(--ph-edge);padding-bottom:4px}
.tab{border:0;background:none;padding:2px 8px;cursor:pointer;color:var(--ph-dim)}
.tab[aria-selected="true"]{background:var(--ph);color:var(--scr-3);text-shadow:none;box-shadow:0 0 8px var(--ph-glow)}
.field{background:rgba(0,0,0,.45);border:1px solid var(--ph-edge);color:var(--ph-hi);padding:2px 5px;min-width:0}
.field:focus{outline:none;border-color:var(--ph);box-shadow:0 0 6px var(--ph-glow)}
.field.invalid{border-color:#ff3b30}
.dim{color:var(--ph-dim)}
.note{font-size:9px;color:var(--ph-dim)}
.soft{border:1px solid var(--ph-edge);border-radius:3px;padding:3px 9px;cursor:pointer;color:var(--scr-3);text-shadow:none;
  background:linear-gradient(180deg,var(--soft-1),var(--soft-2));
  box-shadow:0 0 6px var(--ph-glow),inset 0 1px 0 rgba(255,255,255,.45),0 2px 0 rgba(0,0,0,.6)}
.soft:active{transform:translateY(1px);box-shadow:0 0 3px var(--ph-glow)}
.soft.danger{--soft-1:#ff6a5e;--soft-2:#c8221a;box-shadow:0 0 6px rgba(255,59,48,.5),inset 0 1px 0 rgba(255,255,255,.45)}
.soft.armed{outline:1px dashed #fff;animation:lotj-blink .6s steps(2) infinite}
.keys{display:flex;gap:12px;justify-content:center;flex-wrap:wrap;align-items:flex-end}
.key{border:0;background:none;padding:0;width:46px;cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:3px}
.key .lbl{font-size:10px;line-height:12px;height:12px;color:var(--hull-ink);white-space:nowrap}
.well{display:block;width:40px;height:34px;padding:3px;border-radius:5px;background:#1c1b18;
  box-shadow:inset 0 2px 3px #000,0 1px 0 rgba(255,255,255,.25)}
.cap{display:block;height:100%;border-radius:3px;
  background:linear-gradient(180deg,rgba(255,255,255,.55) 0%,var(--c) 30%,var(--c) 70%,rgba(0,0,0,.35) 100%);
  box-shadow:0 0 12px var(--c),0 2px 0 #000}
.key:active .cap{transform:translateY(2px);box-shadow:0 0 4px var(--c)}
.key:focus-visible,.soft:focus-visible,.tab:focus-visible{outline:1px dashed var(--ph-hi);outline-offset:2px}
.amber{--c:#ff9a1f}.green{--c:#4dff7a}.red{--c:#ff3b30}.blue{--c:#3d8bff}.white{--c:#e8edf2}
.script .key .lbl,.script .soft{font-family:"LotjAurebesh","Share Tech Mono",monospace}
.script .key:hover .lbl,.script .key:focus-visible .lbl,.script .soft:hover,.script .soft:focus-visible{
  font-family:"Share Tech Mono",Consolas,"Courier New",monospace}
@keyframes lotj-blink{50%{opacity:.45}}
@media (prefers-reduced-motion:reduce){.soft.armed{animation:none}}
]==]

local SCRIPT = [==[<script>
var LotjUi = (function () {
  var root = document.documentElement;
  function send(event, data) { mudforge.send(event, data || {}); }
  function applyTheme(vars) {
    for (var key in vars) root.style.setProperty("--" + key, vars[key]);
  }
  function setScript(on) {
    if (on === false) document.body.classList.remove("script");
    else document.body.classList.add("script");
  }
  // Drag grip: screen coordinates stay put while the widget moves under the
  // pointer, so deltas are summed per animation frame and Lua calls moveWidget.
  function grip(el) {
    var last = null, dx = 0, dy = 0, queued = false;
    function flush() {
      queued = false;
      if (dx || dy) { send("grip", { dx: dx, dy: dy }); dx = 0; dy = 0; }
    }
    el.addEventListener("pointerdown", function (event) {
      if (event.target.closest && event.target.closest("button,input")) return;
      last = { x: event.screenX, y: event.screenY };
      if (el.setPointerCapture) el.setPointerCapture(event.pointerId);
      event.preventDefault();
    });
    el.addEventListener("pointermove", function (event) {
      if (!last) return;
      dx += event.screenX - last.x; dy += event.screenY - last.y;
      last = { x: event.screenX, y: event.screenY };
      if (!queued) { queued = true; requestAnimationFrame(flush); }
    });
    function end() { last = null; }
    el.addEventListener("pointerup", end);
    el.addEventListener("pointercancel", end);
  }
  function bindWindow() {
    document.querySelectorAll("[data-grip]").forEach(grip);
    document.querySelectorAll("[data-window]").forEach(function (el) {
      el.addEventListener("click", function () { send("window", { action: el.getAttribute("data-window") }); });
    });
  }
  // Messages the kit owns; returns true when it handled one.
  function handle(message) {
    if (!message) return false;
    if (message.event === "theme") { applyTheme(message.vars || {}); return true; }
    if (message.event === "script") { setScript(message.on); return true; }
    return false;
  }
  return { send: send, applyTheme: applyTheme, setScript: setScript, grip: grip, bindWindow: bindWindow, handle: handle };
})();
</script>]==]

-- One HTML document: font, theme tokens, kit CSS, the widget's own CSS and
-- body, then the kit script before the widget's script.
local function page(options)
  return "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
    .. "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><style>"
    .. "@font-face{font-family:\"LotjAurebesh\";src:url(" .. (options.font or "") .. ") format(\"opentype\")}"
    .. cssVars(themeVars(options.theme)) .. CSS .. (options.css or "")
    .. "</style></head><body class=\"script\">" .. options.body .. SCRIPT .. (options.script or "")
    .. "</body></html>"
end

-- A frameless console window. config: name, title, position, size, zIndex,
-- visible, label (dock icon text), font, theme, css, body, script,
-- dock ({ add(id, label) }), onMessage(event, data).
local function window(config)
  local position = { x = config.position.x, y = config.position.y }
  local id = createWidget({
    type = "html", name = config.name, title = config.title,
    position = config.position, size = config.size, zIndex = config.zIndex, visible = config.visible,
    transparent = true,
    appearance = { showTitleBar = false, autoHideSettingsCog = true },
  })
  if not id then return nil end

  registerWidgetEvent(id, "move", function(event)
    if type(event) == "table" and tonumber(event.x) and tonumber(event.y) then
      position.x, position.y = tonumber(event.x), tonumber(event.y)
    end
  end)
  registerWidgetEvent(id, "luamsg", function(message)
    if type(message) ~= "table" then return end
    local data = type(message.data) == "table" and message.data or {}
    if message.event == "grip" then
      local dx, dy = tonumber(data.dx), tonumber(data.dy)
      if dx and dy then
        position.x, position.y = math.max(0, position.x + dx), math.max(0, position.y + dy)
        moveWidget(id, position.x, position.y)
      end
    elseif message.event == "window" then
      if data.action == "dock" and config.dock then
        config.dock.add(id, config.label or config.title)
      elseif data.action == "off" then
        hideWidget(id)
      end
    elseif config.onMessage then
      config.onMessage(message.event, data)
    end
  end)
  setWidgetProperty(id, "content", page(config))

  return {
    id = id,
    post = function(message) sendWidgetMessage(id, message) end,
    show = function() showWidget(id, true) end,
    theme = function(name) sendWidgetMessage(id, { event = "theme", vars = themeVars(name) }) end,
    position = function() return position.x, position.y end,
  }
end

return { window = window, page = page, themeVars = themeVars, THEMES = THEMES }
