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
local WIDGET_COMBAT_HUD  = nil
local WIDGET_SHIP_HUD    = nil
local WIDGET_SPACE_RADAR = nil
local WIDGET_DATAPAD     = nil

-- ── Init: create all widgets ───────────────────────────────────
function init()
  -- Combat HUD (HTML)
  WIDGET_COMBAT_HUD = createWidget({
    type     = "html",
    name     = "lotj-combat-hud",
    title    = "⚡ COMBAT & FORCE",
    position = { x = 0, y = 0 },  -- will be repositioned on resize
    size     = { width = 320, height = 210 },
    zIndex   = 20,
  })

  -- Ship HUD (HTML)
  WIDGET_SHIP_HUD = createWidget({
    type     = "html",
    name     = "lotj-ship-hud",
    title    = "🛡️ SHIP STATUS",
    position = { x = 0, y = 0 },
    size     = { width = 320, height = 220 },
    zIndex   = 18,
    visible  = false,
  })

  -- Space Radar (Canvas)
  WIDGET_SPACE_RADAR = createWidget({
    type     = "canvas",
    name     = "lotj-space-radar",
    title    = "🚀 TACTICAL RADAR",
    position = { x = 0, y = 0 },
    size     = { width = 180, height = 180 },
    zIndex   = 18,
    visible  = false,
  })

  -- Datapad (HTML, tabbed)
  WIDGET_DATAPAD = createWidget({
    type     = "html",
    name     = "lotj-datapad",
    title    = "📋 HOLOCRON DATAPAD",
    position = { x = 0, y = 0 },
    size     = { width = 360, height = 420 },
    zIndex   = 15,
    visible  = false,
  })

  -- Set initial active widget for canvas drawing
  setActiveWidget(WIDGET_SPACE_RADAR)

  -- Register theme on connect (also handled in onConnect for reconnects)
  registerLOTJTheme()

  -- Register event handlers
  registerWidgetEvents()
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
  -- Combat HUD click events (force power buttons)
  registerWidgetEvent(WIDGET_COMBAT_HUD, "click", function(data)
    handleCombatHUDClick(data)
    focusPrompt()
  end)

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

function onGMCPUpdate(sessionId, package, data)
  -- Handle structured Char.Vitals, Room.Info, etc.
end

function onSaveState(sessionId)
  -- Persist combat state, crafting timers, faction data
end

function cleanup()
  -- Clean up widget event handlers, timers, etc.
end

-- ── Placeholder handlers ───────────────────────────────────────
function handleCombatHUDClick(data) end
function handleShipHUDClick(data) end
function handleDatapadClick(data) end
function handleRadarClick(data) end
function loadSavedState() end