-- LOTJ Plugin for MudForge NextGen Runtime
-- Legacy of the Jedi MUD companion plugin

plugin = {
  id          = "lotj",
  name        = "LOTJ Companion",
  version     = "0.2.0",
  author      = "Mindcloud Team",
  description = "Navigation panel with an isometric radar, public galaxy chart, ground mapper and live vitals for LOTJ.",
  settings    = { saveState = true },
}

-- Host port (QA-07): a plugin cannot reassign MudForge API names, so the DEV
-- harness (dev/harness.lua) supplies recorders through LotjHost. Release: nil.
local host = LotjHost or {}
local send = host.send or send
local getSession = host.getSession or getSession
local addTimer = host.addTimer or addTimer
local removeTimer = host.removeTimer or removeTimer
local createWidget = host.createWidget or createWidget
local onGMCPUpdate = host.onGMCPUpdate or onGMCPUpdate
local registerWidgetEvent = host.registerWidgetEvent or registerWidgetEvent

-- ── Widget IDs (created in init) ──────────────────────────────
local WIDGET_STATUS_BAR = nil
local WIDGET_COMMS_HUB  = nil
local WIDGET_SHIP_HUD   = nil
local WIDGET_SPACE_RADAR = nil
local WIDGET_DATAPAD    = nil
local scrapperCockpit = nil
local targetCockpit = nil
local commsHub, chatLine

local function sendGameCommand(command)
  local session = getSession()
  if not session or not session.connected then return false end
  send(command)
  focusPrompt()
  return true
end

local function scheduleNavigationReadout(milliseconds, callback)
  local timer = addTimer(milliseconds, callback)
  if not timer or timer == "" then
    callback()
    return nil
  end
  return function() removeTimer(timer) end
end

-- ── Init: create all widgets ───────────────────────────────────
function init()
  -- Load sub-widget modules
  local statusBar = loadModule("src/widgets/lotj-status-bar.lua")
  local commsWidget = loadModule("src/widgets/lotj-comms-hub.lua")
  local chatParser = loadModule("src/domain/chat-line.lua")
  local groundMap = loadModule("src/widgets/lotj-ground-map.lua")
  local shipPosition = loadModule("src/domain/ship-position.lua")
  local radarScan = loadModule("src/domain/radar-scan.lua")
  local publicGalaxy = loadModule("src/domain/public-galaxy.lua")
  local cockpitApplication = loadModule("src/application/scrapper-cockpit.lua")
  local targetLock = loadModule("src/domain/target-lock.lua")
  local targetApplication = loadModule("src/application/target-cockpit.lua")
  local cockpitWidget = loadModule("src/widgets/lotj-scrapper-cockpit.lua")
  local uiFont = loadModule("src/widgets/lotj-ui-font.lua")
  local uiKit = loadModule("src/widgets/lotj-ui-kit.lua")
  local windowDock = loadModule("src/widgets/lotj-window-dock.lua")
  local datapadRules = loadModule("src/domain/datapad.lua")
  local datapadApplication = loadModule("src/application/datapad.lua")
  local datapadWidget = loadModule("src/widgets/lotj-datapad.lua")
  local consoleCatalog = loadModule("src/domain/console-catalog.lua")
  local commandForm = loadModule("src/domain/command-form.lua")
  local consoleApplication = loadModule("src/application/station-console.lua")
  local consoleWidget = loadModule("src/widgets/lotj-station-console.lua")

  -- Compute positions based on window size (60/40 split)
  local win = getWindowSize()
  local winW, winH = win.width, win.height
  local statusBarX = 20
  local statusBarY = winH - 96
  local commsHubX = math.floor(winW * 0.60) + 20
  local commsHubY = math.floor(winH * 0.50)
  local shipHudX = math.floor(winW * 0.60) + 20
  local shipHudY = 20
  local radarX = math.floor(winW * 0.60) + 20
  local radarY = 20
  local datapadX = 20
  local datapadY = 60

  -- Status Bar (HTML) — two-row layout: ship row (conditional) + vitals row
  WIDGET_STATUS_BAR = createWidget({
    type     = "html",
    name     = "lotj-status-bar",
    title    = "LOTJ Status Bar",
    position = { x = statusBarX, y = statusBarY },
    size     = { width = 320, height = 64 },
    zIndex   = 20,
  })

  -- Comms Hub (HTML) — tabbed chat panel
  WIDGET_COMMS_HUB = createWidget({
    type     = "html",
    name     = "lotj-comms-hub",
    title    = "LOTJ Comms Hub",
    position = { x = commsHubX, y = commsHubY },
    size     = { width = 360, height = 420 },
    zIndex   = 15,
    visible  = false,
  })

  -- Ship HUD (HTML)
  WIDGET_SHIP_HUD = createWidget({
    type     = "html",
    name     = "lotj-ship-hud",
    title    = "🛡️ SHIP STATUS",
    position = { x = shipHudX, y = shipHudY },
    size     = { width = 320, height = 220 },
    zIndex   = 18,
    visible  = false,
  })

  -- Space Radar (Canvas)
  WIDGET_SPACE_RADAR = createWidget({
    type     = "canvas",
    name     = "lotj-space-radar",
    title    = "🚀 TACTICAL RADAR",
    position = { x = radarX, y = radarY },
    size     = { width = 180, height = 180 },
    zIndex   = 18,
    visible  = false,
  })

  -- Console windows (UI-02): frameless widgets drawn by the UI kit; [_] docks them.
  local dock = windowDock.create({
    kit = uiKit, font = uiFont,
    position = { x = statusBarX + 340, y = statusBarY },
  })
  local datapad = datapadWidget.create({
    kit = uiKit, font = uiFont, dock = dock,
    position = { x = datapadX, y = datapadY },
    newApp = function(publish)
      return datapadApplication.new({ rules = datapadRules, send = sendGameCommand, publish = publish })
    end,
  })
  WIDGET_DATAPAD = datapad and datapad.id
  -- Station consoles (UI-03): every catalog command on a key, the palette and the Holocron.
  consoleWidget.create({
    kit = uiKit, font = uiFont, dock = dock,
    position = { x = datapadX + 20, y = datapadY + 20 },
    openDatapad = datapad and function()
      dock.remove(datapad.id)
      datapad.show()
    end,
    newApp = function(publish)
      return consoleApplication.new({ catalog = consoleCatalog, rules = commandForm, send = sendGameCommand, publish = publish })
    end,
  })

  -- Set initial active widget for canvas drawing
  setActiveWidget(WIDGET_SPACE_RADAR)

  -- Initialize sub-widgets with widget IDs
  statusBar.init(WIDGET_STATUS_BAR)
  commsWidget.init(WIDGET_COMMS_HUB)
  commsHub, chatLine = commsWidget, chatParser
  local navigation = cockpitWidget.create({
    publicGalaxy = publicGalaxy,
    openMap = groundMap.open,
    openComms = function()
      if WIDGET_COMMS_HUB then showWidget(WIDGET_COMMS_HUB, true) end
    end,
  })
  if navigation then
    targetCockpit = targetApplication.new({
      targetLock = targetLock,
      send = sendGameCommand,
      publish = navigation.publishTarget,
    })
    scrapperCockpit = cockpitApplication.new({
      shipPosition = shipPosition,
      radarScan = radarScan,
      publish = function(position, contacts, scanState, radarBusy)
        navigation.publish(position, contacts, scanState, radarBusy)
        targetCockpit.onRadar(position, contacts)
      end,
      publishSystem = navigation.publishSystem,
      scan = sendGameCommand,
      schedule = scheduleNavigationReadout,
    })
    navigation.bind(scrapperCockpit, targetCockpit)
  end
  groundMap.init(navigation and navigation.publishRoom)

  -- Register theme on connect (also handled in onConnect for reconnects)
  registerLOTJTheme()

  -- Register event handlers
  registerWidgetEvents()

  -- Register GMCP handlers (onGMCPUpdate is MudForge's global hook)
  onGMCPUpdate("Char.Vitals", onGMCPUpdateCharVitals)
  onGMCPUpdate("Ship.Info", function(data)
    if type(data) ~= "table" then data = nil end
    statusBar.onGMCPUpdateShipInfo(data)
    local session = getSession()
    if scrapperCockpit and session and session.connected then
      if data then
        scrapperCockpit.observe(data.posX, data.posY, data.posZ)
      else
        scrapperCockpit.observe()
      end
    end
  end)
  onGMCPUpdate("Ship.System", function(data)
    local session = getSession()
    if scrapperCockpit and session and session.connected then
      if type(data) == "table" then
        scrapperCockpit.observeSystem(data.x, data.y)
      else
        scrapperCockpit.observeSystem()
      end
    end
  end)
  onGMCPUpdate("Char.Enemy", onGMCPUpdateCharEnemy)
  onGMCPUpdate("Char.Chat", onGMCPUpdateCharChat)
end

-- ── Theme Registration ─────────────────────────────────────────
function registerLOTJTheme()
  local themeId = registerTheme({
    id     = "lotj-holocron",
    name   = "LOTJ Holocron",
    colors = {
      background        = "220 35% 7%",
      foreground        = "0 0% 92%",
      card              = "222 41% 13%",
      cardForeground    = "0 0% 92%",
      primary           = "215 28% 9%",
      primaryForeground = "0 0% 92%",
      accent            = "197 72% 55%",
      accentForeground  = "0 0% 92%",
      destructive       = "0 76% 65%",
      destructiveForeground = "0 0% 92%",
      border            = "220 20% 18%",
      input             = "222 41% 13%",
      ring              = "197 72% 55%",
      muted             = "220 20% 15%",
      mutedForeground   = "215 15% 65%",
      popover           = "222 41% 13%",
      popoverForeground = "0 0% 92%",
      secondary         = "220 20% 18%",
      secondaryForeground = "0 0% 92%",
    },
    skin = "forge",
  })
  if themeId then
    setTheme(themeId)
  end
end

-- ── Widget Event Registration ──────────────────────────────────
function registerWidgetEvents()
  -- Ship HUD click events
  registerWidgetEvent(WIDGET_SHIP_HUD, "click", function(data)
    handleShipHUDClick(data)
    focusPrompt()
  end)

  -- Space radar click events (target selection)
  registerWidgetEvent(WIDGET_SPACE_RADAR, "click", function(data)
    handleRadarClick(data)
    focusPrompt()
  end)
end

-- ── Hook Stubs (to be filled in) ───────────────────────────────
function onConnect(sessionId)
  -- Re-register theme on reconnect
  registerLOTJTheme()
  -- Load saved state
  loadSavedState()
  local session = getSession()
  if session and session.id == sessionId and session.connected then
    if scrapperCockpit then scrapperCockpit.resetSession() end
    if targetCockpit then targetCockpit.reset() end
    if commsHub then commsHub.resetHistory() end
  end
end

function onDisconnect(sessionId)
  local session = getSession()
  if scrapperCockpit and (not session or (session.id == sessionId and not session.connected)) then
    scrapperCockpit.resetSession()
    if targetCockpit then targetCockpit.reset() end
  end
end

function onLine(sessionId, rawLine, cleanLine)
  local session = getSession()
  if not session or not session.connected or session.id ~= sessionId then return end
  if scrapperCockpit then scrapperCockpit.readLine(cleanLine) end
  if commsHub and chatLine then
    local message = chatLine.read(cleanLine)
    if message then commsHub.handleChatMessage(message) end
  end
end

function onCommand(sessionId, command)
  -- Intercept custom slash commands before alias processing
end

function onSend(sessionId, text)
  -- Block or modify commands (e.g., auto-format force power sends)
end



function onSaveState(sessionId)
  -- Persist combat state, crafting timers, faction data
end



function cleanup()
  -- Clean up widget event handlers, timers, etc.
end

-- ── Placeholder handlers ───────────────────────────────────────
-- Char.Vitals, Char.Enemy and Char.Chat are handled by the status bar module
-- (src/widgets/lotj-status-bar.lua), which defines onGMCPUpdateCharVitals,
-- onGMCPUpdateCharEnemy and onGMCPUpdateCharChat before init() registers them.

-- Placeholder handlers
function handleCombatHUDClick(data) end
function handleShipHUDClick(data) end
function handleRadarClick(data) end
function loadSavedState() end
