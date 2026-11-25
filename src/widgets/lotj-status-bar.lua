-- lotj-status-bar.lua
-- Two-row live status bar: ship row (conditional) + vitals row with wimpy tick overlay

local statusBar = nil

function initStatusBar()
  statusBar = createWidget({
    type  = "html",
    name  = "lotj-status-bar",
    title = "LOTJ Status Bar",
    position = { x = 0, y = 0 },  -- repositioned on resize
    size = { width = 320, height = 64 },
    zIndex = 20,
    visible = true,
  })

  -- Set initial HTML content
  setWidgetProperty(statusBar, "content", [[
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><style>
  :root {
    --lotj-bg: #0B0F14; --lotj-card: #1E293B; --lotj-border: #334155;
    --lotj-text: #F1F5F9; --lotj-muted: #94A3B8; --lotj-accent: #22D3EE;
    --lotj-warn: #F59E0B; --lotj-danger: #EF4444; --lotj-hp: #009E73;
    --lotj-mv: #E69F00; --lotj-force: #56B4E9; --lotj-mana: #A78BFA;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: "JetBrains Mono", ui-monospace, monospace; font-size: 11px;
         background: var(--lotj-bg); color: var(--lotj-text); padding: 2px 6px; height: 100%; }
  .ship-row { display: none; flex-wrap: wrap; gap: 4px; align-items: center; padding: 1px 0; border-bottom: 1px solid var(--lotj-border); }
  .ship-row.visible { display: flex; }
  .vitals-row { display: flex; flex-wrap: wrap; gap: 2px; align-items: center; }
  .gauge { flex: 1 1 45%; min-width: 60px; display: flex; flex-direction: column; gap: 1px; }
  .gauge-label { font-size: 0.7em; color: var(--lotj-muted); display: flex; justify-content: space-between; }
  .gauge-bar { height: 6px; background: #0F172A; border-radius: 2px; overflow: hidden; position: relative; }
  .gauge-fill { height: 100%; border-radius: 2px; transition: width 0.3s ease; }
  .gauge-fill.hp { background: var(--lotj-hp); }
  .gauge-fill.mv { background: var(--lotj-mv); }
  .gauge-fill.force { background: var(--lotj-force); }
  .gauge-fill.mana { background: var(--lotj-mana); }
  .wimpy-tick { position: absolute; top: 0; left: 0; right: 0; bottom: 0;
                pointer-events: none; border-left: 2px solid var(--lotj-warn); opacity: 0; }
  .wimpy-tick.active { opacity: 1; }
  .opponent-bar { display: none; align-items: center; gap: 4px; padding: 1px 0;
                  border-top: 1px solid var(--lotj-border); font-size: 0.75em; }
  .opponent-bar.visible { display: flex; }
  .comlink { font-size: 0.7em; padding: 1px 3px; border-radius: 2px; background: var(--lotj-card); }
  @media (prefers-reduced-motion: reduce) { .gauge-fill { transition: none; } }
  @media (pointer: coarse) { .gauge { min-height: 44px; } }
</style></head><body>
<div id="ship-row" class="ship-row">
  <span style="color:var(--lotj-muted);font-size:0.7em">🛡️ Shield</span>
  <div class="gauge-bar" style="flex:1"><div class="gauge-fill" id="shield-fill" style="width:0%"></div></div>
  <span style="color:var(--lotj-muted);font-size:0.7em">Hull</span>
  <div class="gauge-bar" style="flex:1"><div class="gauge-fill" id="hull-fill" style="width:0%"></div></div>
  <span style="color:var(--lotj-muted);font-size:0.7em">Energy</span>
  <div class="gauge-bar" style="flex:1"><div class="gauge-fill" id="energy-fill" style="width:0%"></div></div>
  <span class="comlink" id="comlink-indicator">🔇</span>
</div>
<div class="vitals-row">
  <div class="gauge" id="gauge-hp">
    <div class="gauge-label"><span>❤️ HP</span><span id="hp-text">0/0</span></div>
    <div class="gauge-bar" style="position:relative"><div class="gauge-fill hp" id="hp-fill" style="width:0%"></div><div class="wimpy-tick" id="wimpy-tick"></div></div>
  </div>
  <div class="gauge" id="gauge-mv">
    <div class="gauge-label"><span>🏃 MV</span><span id="mv-text">0/0</span></div>
    <div class="gauge-bar"><div class="gauge-fill mv" id="mv-fill" style="width:0%"></div></div>
  </div>
  <div class="gauge" id="gauge-force" style="display:none">
    <div class="gauge-label"><span>✨ FORCE</span><span id="force-text">0/0</span></div>
    <div class="gauge-bar"><div class="gauge-fill force" id="force-fill" style="width:0%"></div></div>
  </div>
  <div class="gauge" id="gauge-mana" style="display:none">
    <div class="gauge-label"><span>💠 MANA</span><span id="mana-text">0/0</span></div>
    <div class="gauge-bar"><div class="gauge-fill mana" id="mana-fill" style="width:0%"></div></div>
  </div>
</div>
<div class="opponent-bar" id="opponent-bar">
  <span id="target-name" style="color:var(--lotj-muted)"></span>
  <div class="gauge-bar" style="flex:1"><div class="gauge-fill" id="target-fill" style="width:0%;background:var(--lotj-danger)"></div></div>
  <span id="target-pct" style="font-size:0.8em"></span>
</div>
<script>
  mudforge.send("ready", { widget: "lotj-status-bar" });
  mudforge.onMessage(function(data) {
    if (data.event === "setBoundValues" && data.values) updateVitals(data.values);
    if (data.event === "shipInfo" && data.ship) updateShipRow(data.ship);
    if (data.event === "enemyInfo" && data.enemy) updateOpponent(data.enemy);
    if (data.event === "comlink" && data.channel) updateComlink(data.channel);
  });
  function updateVitals(v) {
    if (v.hp !== undefined && v.maxHp !== undefined) {
      var pct = Math.min(100, Math.max(0, (v.hp / v.maxHp) * 100));
      document.getElementById("hp-fill").style.width = pct + "%";
      document.getElementById("hp-text").textContent = v.hp + "/" + v.maxHp;
      if (v.wimpy && v.maxHp > 0 && v.hp <= v.maxHp * (v.wimpy / 100)) {
        document.getElementById("wimpy-tick").classList.add("active");
      } else { document.getElementById("wimpy-tick").classList.remove("active"); }
    }
    if (v.move !== undefined && v.maxMove !== undefined) {
      var pct = Math.min(100, Math.max(0, (v.move / v.maxMove) * 100));
      document.getElementById("mv-fill").style.width = pct + "%";
      document.getElementById("mv-text").textContent = v.move + "/" + v.maxMove;
    }
    if (v.force !== undefined && v.maxForce !== undefined) {
      var fg = document.getElementById("gauge-force");
      if (v.maxForce > 0) { fg.style.display = "flex"; document.getElementById("force-fill").style.width = Math.min(100, (v.force / v.maxForce) * 100) + "%"; document.getElementById("force-text").textContent = v.force + "/" + v.maxForce; }
      else { fg.style.display = "none"; }
    }
    if (v.mana !== undefined && v.maxMana !== undefined) {
      var mg = document.getElementById("gauge-mana");
      if (v.maxMana > 0) { mg.style.display = "flex"; document.getElementById("mana-fill").style.width = Math.min(100, (v.mana / v.maxMana) * 100) + "%"; document.getElementById("mana-text").textContent = v.mana + "/" + v.maxMana; }
      else { mg.style.display = "none"; }
    }
  }
  function updateShipRow(ship) {
    var row = document.getElementById("ship-row");
    row.classList.add("visible");
    if (ship.shield !== undefined && ship.maxShield !== undefined) document.getElementById("shield-fill").style.width = Math.min(100, (ship.shield / ship.maxShield) * 100) + "%";
    if (ship.hull !== undefined && ship.maxHull !== undefined) document.getElementById("hull-fill").style.width = Math.min(100, (ship.hull / ship.maxHull) * 100) + "%";
    if (ship.energy !== undefined && ship.maxEnergy !== undefined) document.getElementById("energy-fill").style.width = Math.min(100, (ship.energy / ship.maxEnergy) * 100) + "%";
    if (ship.piloting) { document.getElementById("comlink-indicator").textContent = "📡 " + ship.piloting; }
  }
  function updateOpponent(enemy) {
    var bar = document.getElementById("opponent-bar");
    bar.classList.add("visible");
    document.getElementById("target-name").textContent = enemy.name || "Unknown";
    if (enemy.percent !== undefined) { document.getElementById("target-fill").style.width = enemy.percent + "%"; document.getElementById("target-pct").textContent = enemy.percent + "%"; }
  }
  function updateComlink(channel) {
    var el = document.getElementById("comlink-indicator");
    if (channel && channel.active) { el.textContent = "📡 " + (channel.name || ""); el.className = "comlink"; }
    else { el.textContent = "🔇 Muted"; el.className = "comlink"; }
  }
</script>
</body></html>]])

  -- Register luamsg handler for bound value updates
  -- NOTE: Do NOT call setWidgetProperty("content", ...) in the "ready" handler.
  -- That would reload the iframe, firing "ready" again endlessly.
  -- Push state via sendWidgetMessage instead (see onGMCPUpdate handlers below).
end

-- GMCP handlers
function onGMCPUpdateCharVitals(data)
  if not statusBar then return end
  local values = {
    hp = data.hp, maxHp = data.maxHp,
    move = data.move, maxMove = data.maxMove,
  }
  -- Force bar only shows when maxMana > 0 (per upstream info-panel.lua behavior)
  if data.mana ~= nil and data.maxMana ~= nil and data.maxMana > 0 then
    values.force = data.mana  -- Note: upstream uses mana for force when maxMana > 0
    values.maxForce = data.maxMana
  end
  if data.mana ~= nil and data.maxMana ~= nil then
    values.mana = data.mana
    values.maxMana = data.maxMana
  end
  if data.wimpy then values.wimpy = data.wimpy end
  sendWidgetMessage(statusBar, { event = "vitals", values = values })
end

function onGMCPUpdateShipInfo(data)
  if not statusBar then return end
  if not data or next(data) == nil then
    -- Empty Ship.Info: hide the ship row
    sendWidgetMessage(statusBar, { event = "shipVisible", visible = false })
    return
  end
  sendWidgetMessage(statusBar, { event = "shipVisible", visible = true, ship = {
    shield = data.shield, maxShield = data.maxShield,
    hull = data.hull, maxHull = data.maxHull,
    energy = data.energy, maxEnergy = data.maxEnergy,
    piloting = data.piloting,
    speed = data.speed, maxSpeed = data.maxSpeed,
    posX = data.posX, posY = data.posY, posZ = data.posZ,
  })
end

function onGMCPUpdateCharEnemy(data)
  if not statusBar then return end
  -- Strip Mud color codes (&r, &n, etc.) from enemy name
  local name = data.name or ""
  name = name:gsub("&&r", ""):gsub("&&n", ""):gsub("&&[^rN]", "")
  setBoundValues(statusBar, {
    enemyName = name,
    enemyPercent = data.percent or 0,
  })
end

function onGMCPUpdateCharChat(data)
  if not statusBar then return end
  setBoundValues(statusBar, {
    commChannel = data.commChannel or "",
    commEncrypt = data.commEncrypt or false,
  })
end

return {
  init = initStatusBar,
  onGMCPUpdateCharVitals = onGMCPUpdateCharVitals,
  onGMCPUpdateShipInfo = onGMCPUpdateShipInfo,
  onGMCPUpdateCharEnemy = onGMCPUpdateCharEnemy,
  onGMCPUpdateCharChat = onGMCPUpdateCharChat,
}