-- LOTJ Plugin for MudForge NextGen Runtime
-- Legacy of the Jedi MUD companion plugin

plugin = {
  id          = "lotj",
  name        = "LOTJ Companion",
  version     = "0.1.0",
  author      = "Mindcloud Team",
  description = "Combat HUD, Force tracker, ship status, faction events, crafting progress, and character sheet for LOTJ.",
  settings    = { saveState = true },
}

-- ── Widget IDs (created in init) ──────────────────────────────
local WIDGET_STATUS_BAR = nil
local WIDGET_COMMS_HUB  = nil
local WIDGET_SHIP_HUD   = nil
local WIDGET_SPACE_RADAR = nil
local WIDGET_DATAPAD    = nil
local scrapperCockpit = nil

-- ── Init: create all widgets ───────────────────────────────────
function init()
  -- Load sub-widget modules
  local statusBar = loadModule("src/widgets/lotj-status-bar.lua")
  loadModule("src/widgets/lotj-comms-hub.lua")
  loadModule("src/widgets/lotj-ground-map.lua")
  local shipPosition = loadModule("src/domain/ship-position.lua")
  local cockpitApplication = loadModule("src/application/scrapper-cockpit.lua")
  local cockpitWidget = loadModule("src/widgets/lotj-scrapper-cockpit.lua")

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

  -- Datapad (HTML, tabbed)
  WIDGET_DATAPAD = createWidget({
    type     = "html",
    name     = "lotj-datapad",
    title    = "📋 HOLOCRON DATAPAD",
    position = { x = datapadX, y = datapadY },
    size     = { width = 360, height = 420 },
    zIndex   = 15,
    visible  = false,
  })

  -- Set initial active widget for canvas drawing
  setActiveWidget(WIDGET_SPACE_RADAR)

  -- Initialize sub-widgets with widget IDs
  statusBar.init(WIDGET_STATUS_BAR)
  if initCommsHub then initCommsHub(WIDGET_COMMS_HUB) end
  if initGroundMap then initGroundMap() end
  scrapperCockpit = cockpitWidget.openWidget(cockpitApplication, shipPosition)

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

  -- Datapad tab events
  registerWidgetEvent(WIDGET_DATAPAD, "click", function(data)
    handleDatapadClick(data)
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
  if scrapperCockpit and session and session.id == sessionId and session.connected then
    scrapperCockpit.observe()
  end
end

function onDisconnect(sessionId)
  local session = getSession()
  if scrapperCockpit and (not session or (session.id == sessionId and not session.connected)) then
    scrapperCockpit.observe()
  end
end

function onLine(sessionId, rawLine, cleanLine)
  -- Parse combat events, prompt data, faction messages
  -- Return false to suppress sensitive combat info display
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
-- GMCP handler: Char.Vitals (hp, maxHp, move, maxMove, mana, maxMana, wimpy)
-- Note: Force bar auto-hides when maxMana == 0 (per upstream info-panel.lua)
-- wimpy is the yellow threshold tick inside the HP bar
function onGMCPUpdateCharVitals(data)
  if not WIDGET_STATUS_BAR then return end
  local values = {
    hp = data.hp, maxHp = data.maxHp,
    move = data.move, maxMove = data.maxMove,
  }
  if data.mana ~= nil and data.maxMana ~= nil and data.maxMana > 0 then
    values.force = data.mana
    values.maxForce = data.maxMana
  end
  if data.mana ~= nil and data.maxMana ~= nil then
    values.mana = data.mana
    values.maxMana = data.maxMana
  end
  if data.wimpy then values.wimpy = data.wimpy end
  sendWidgetMessage(WIDGET_STATUS_BAR, { event = "vitals", values = values })
end

-- GMCP handler: Char.Enemy (name with color codes stripped, percent for idle reticle)
function onGMCPUpdateCharEnemy(data)
  if not WIDGET_STATUS_BAR then return end
  local name = data.name or ""
  name = name:gsub("&.", "")
  sendWidgetMessage(WIDGET_STATUS_BAR, { event = "enemyInfo", enemy = {
    name = name,
    enemyPercent = data.percent or 0,
  }})
end

-- GMCP handler: Char.Chat (commChannel, commEncrypt for comlink icon state)
function onGMCPUpdateCharChat(data)
  if not WIDGET_STATUS_BAR then return end
  sendWidgetMessage(WIDGET_STATUS_BAR, { event = "comlink", channel = {
    name = data.commChannel or "",
    active = data.commEncrypt or false,
  }})
end

-- Placeholder handlers
function handleCombatHUDClick(data) end
function handleShipHUDClick(data) end
function handleDatapadClick(data) end
function handleRadarClick(data) end
function loadSavedState() end