-- Datapad window, window dock and UI kit through the fake host (UI-02, DATA-01).
local fake_host = dofile("tests/support/fake_host.lua")

local function calls(host, name)
  local found = {}
  for _, call in ipairs(host.calls) do
    if call[1] == name then found[#found + 1] = call end
  end
  return found
end

do -- frameless kit windows with the embedded font
  local host = fake_host.new()
  host.loadPlugin()
  for _, name in ipairs({ "lotj-datapad", "lotj-window-dock" }) do
    local widget = assert(host.widgets[name], name .. " was not created")
    assert(widget.config.transparent == true and widget.config.appearance.showTitleBar == false,
      name .. " must hide MudForge's frame")
    assert(widget.config.visible == false, name .. " opens hidden")
    local html = widget.properties.content
    assert(html:find("data:font/otf;base64,", 1, true), "Aurebesh font is embedded")
    assert(html:find("var LotjUi", 1, true) and html:find("--hull-1:#8d8778", 1, true), "kit script and neutral theme")
  end
  assert(host.commands["lotj-datapad"], "the datapad has an open command")
  print("PASS: datapad and dock are frameless kit windows")
end

do -- keys send datamem commands through the use case
  local host = fake_host.new()
  host.loadPlugin()
  host.post("lotj-datapad", "ready", {})
  assert(host.last("lotj-datapad", "slot").slot == 1)
  host.post("lotj-datapad", "step", { delta = 1 })
  host.post("lotj-datapad", "command", { action = "view", args = {} })
  assert(host.sends[1] == "datamem view 2")
  host.post("lotj-datapad", "select", { slot = "5" })
  host.post("lotj-datapad", "command", { action = "subject", args = { text = "Late at bay 2" } })
  assert(host.sends[2] == "datamem write 5 subject Late at bay 2")
  host.post("lotj-datapad", "command", { action = "delete", args = {} })
  assert(#host.sends == 2 and host.last("lotj-datapad", "confirm").command == "datamem delete 5")
  host.post("lotj-datapad", "command", { action = "delete", args = {} })
  assert(host.sends[3] == "datamem delete 5" and host.last("lotj-datapad").event == "sent")
  host.post("lotj-datapad", "unknown", {})
  assert(#host.sends == 3)
  print("PASS: datapad keys send help syntax once, delete asks first")
end

do -- offline: nothing reaches the game and the screen says so
  local host = fake_host.new({ connected = false })
  host.loadPlugin()
  host.post("lotj-datapad", "command", { action = "datastat", args = {} })
  assert(#host.sends == 0 and host.last("lotj-datapad").event == "offline")
  print("PASS: offline datapad sends nothing")
end

do -- grip drags with moveWidget; player moves are tracked
  local host = fake_host.new()
  host.loadPlugin()
  local luamsg = host.events["lotj-datapad"].luamsg
  luamsg({ event = "grip", data = { dx = 15, dy = -5 } })
  local move = calls(host, "moveWidget")[1]
  assert(move[2] == "lotj-datapad" and move[3] == 35 and move[4] == 55, "grip moves from the created position")
  host.events["lotj-datapad"].move({ x = 400, y = 3, source = "player" })
  luamsg({ event = "grip", data = { dx = -10, dy = -50 } })
  move = calls(host, "moveWidget")[2]
  assert(move[3] == 390 and move[4] == 0, "grip starts from where the player left it and stays on screen")
  luamsg({ event = "grip", data = { dx = "x" } })
  host.events["lotj-datapad"].move("bad")
  luamsg("bad")
  assert(#calls(host, "moveWidget") == 2, "bad grip data moves nothing")
  print("PASS: the casing grip drags the window")
end

do -- [_] docks, the dock key restores, OFF hides, the command reopens
  local host = fake_host.new()
  host.loadPlugin()
  host.widgets["lotj-datapad"].visible = true
  host.post("lotj-datapad", "window", { action = "dock" })
  assert(host.widgets["lotj-datapad"].visible == false and host.widgets["lotj-window-dock"].visible == true)
  local list = host.last("lotj-window-dock", "windows").list
  assert(#list == 1 and list[1].id == "lotj-datapad" and list[1].label == "DATAPAD")
  host.post("lotj-datapad", "window", { action = "dock" })
  assert(#host.last("lotj-window-dock", "windows").list == 1, "docking twice keeps one key")
  host.post("lotj-window-dock", "ready", {})
  assert(#host.last("lotj-window-dock", "windows").list == 1, "the dock asks for its keys when it loads")
  host.post("lotj-window-dock", "restore", { id = "nope" })
  host.post("lotj-window-dock", "restore", { id = "lotj-datapad" })
  assert(host.widgets["lotj-datapad"].visible == true and host.widgets["lotj-window-dock"].visible == false,
    "restoring the last window hides the empty dock")
  host.post("lotj-datapad", "window", { action = "off" })
  assert(host.widgets["lotj-datapad"].visible == false and host.widgets["lotj-window-dock"].visible == false)
  host.post("lotj-datapad", "window", { action = "dock" })
  host.commands["lotj-datapad"]()
  assert(host.widgets["lotj-datapad"].visible == true and #host.last("lotj-window-dock", "windows").list == 0,
    "the open command leaves the dock")
  host.post("lotj-window-dock", "window", { action = "dock" })
  assert(#host.last("lotj-window-dock", "windows").list == 0, "the dock has no dock of its own")
  assert(#host.sends == 0)
  print("PASS: dock, restore, OFF and the open command")
end

do -- kit pieces on their own
  local host = fake_host.new()
  local kit = host.env.loadModule("src/widgets/lotj-ui-kit.lua")
  assert(kit.themeVars("empire").ph == "#ff5a45" and kit.themeVars("nope") == kit.THEMES.neutral)
  local window = kit.window({ name = "w", title = "W", position = { x = 1, y = 2 }, size = { width = 9, height = 9 }, body = "" })
  window.theme("empire")
  assert(host.last("w", "theme").vars.ph == "#ff5a45")
  assert(window.position() == 1)
  host.events.w.luamsg({ event = "window", data = { action = "dock" } })
  host.events.w.luamsg({ event = "other", data = "x" })
  local failed = fake_host.new({ failWidget = { ["lotj-datapad"] = true, ["lotj-window-dock"] = true } })
  failed.loadPlugin()
  assert(failed.commands["lotj-datapad"] == nil, "no command without a datapad widget")
  print("PASS: kit themes and failed widgets")
end
