local HTML = [=[
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  :root { color-scheme: dark; }
  body { margin: 0; padding: 14px; background: #101826; color: #eef4fc;
    font: 14px system-ui, sans-serif; }
  p { margin: 0 0 8px; }
  #position { font: 600 16px ui-monospace, monospace; overflow-wrap: anywhere; }
  .actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
  button { padding: 7px 13px; border: 1px solid #467f91; border-radius: 5px;
    background: #183347; color: #e3faff; font: inherit; cursor: pointer; }
  button:hover { background: #215170; }
  #notice { margin-top: 8px; color: #f7cd93; }
</style>
</head>
<body>
<p>Ship position</p>
<p id="position" aria-live="polite">Waiting for ship position</p>
<div class="actions">
  <button id="radar" type="button">Radar</button>
  <button id="proximity" type="button">Proximity</button>
</div>
<p id="notice" role="status"></p>
<script>
  const position = document.getElementById("position");
  const notice = document.getElementById("notice");
  for (const event of ["radar", "proximity"]) {
    document.getElementById(event).addEventListener("click", () => {
      notice.textContent = "";
      mudforge.send(event, {});
    });
  }
  mudforge.onMessage(message => {
    if (message.event === "position") {
      const p = message.position;
      position.textContent = p ? "X " + p.x + " · Y " + p.y + " · Z " + p.z
        : "Waiting for ship position";
    }
    if (message.event === "disconnected") notice.textContent = "Connect to the game to scan.";
  });
  mudforge.send("ready", {});
</script>
</body>
</html>
]=]

local function openWidget(application, shipPosition)
  local id = createWidget({
    type = "html",
    name = "lotj-scrapper-cockpit",
    title = "LOTJ Scrapper Cockpit",
    position = { x = 20, y = 90 },
    size = { width = 320, height = 168 },
    visible = false,
  })
  if not id then return nil end

  local ready = false
  local cockpit = application.new({
    shipPosition = shipPosition,
    publish = function(position)
      if ready then
        sendWidgetMessage(id, { event = "position", position = position })
      end
    end,
    scan = function(kind)
      local session = getSession()
      if not session or not session.connected then return false end
      send(kind)
      focusPrompt()
      return true
    end,
  })

  registerWidgetEvent(id, "luamsg", function(message)
    if not message then return end
    if message.event == "ready" then
      ready = true
      cockpit.refresh()
    elseif message.event == "radar" or message.event == "proximity" then
      if not cockpit.requestScan(message.event) then
        sendWidgetMessage(id, { event = "disconnected" })
      end
    end
  end)
  setWidgetProperty(id, "content", HTML)
  registerCommand("lotj-cockpit", function()
    showWidget(id, true)
  end, "Open the LOTJ Scrapper Cockpit")

  return cockpit
end

return { openWidget = openWidget }
