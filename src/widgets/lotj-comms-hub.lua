-- lotj-comms-hub.lua
-- Tabbed chat panel with CombatStats and AutoPilot slots

-- Host port (QA-07): a plugin cannot reassign MudForge API names, so the DEV
-- harness (dev/harness.lua) supplies recorders through LotjHost. Release: nil.
local host = LotjHost or {}
local registerWidgetEvent = host.registerWidgetEvent or registerWidgetEvent
local sendWidgetMessage = host.sendWidgetMessage or sendWidgetMessage

local commsHub = nil
local ready = false
local pending = {}
local HISTORY_LIMIT = 250

function initCommsHub(id)
  commsHub = id
  ready, pending = false, {}
  if not id or id == "" then return end

  registerWidgetEvent(id, "luamsg", function(m)
    if commsHub ~= id then return end
    if m.event == "ready" and not ready then
      ready = true
      for _, msg in ipairs(pending) do
        sendWidgetMessage(id, { event = "chatMessage", msg = msg })
      end
      pending = {}
    elseif m.event == "tabClick" then
      focusPrompt()
    end
  end)

  -- Set initial HTML content with tabbed layout
  setWidgetProperty(commsHub, "content", [[
<!DOCTYPE html>
<html><head><meta charset="UTF-8"><style>
  :root {
    --lotj-bg: #0B0F14; --lotj-card: #1E293B; --lotj-border: #334155;
    --lotj-text: #F1F5F9; --lotj-muted: #94A3B8; --lotj-accent: #22D3EE;
    --lotj-active-tab: #1F5E66; --lotj-warn: #F59E0B;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: "JetBrains Mono", ui-monospace, monospace; font-size: 11px;
         background: var(--lotj-bg); color: var(--lotj-text); padding: 2px 6px;
         height: 100%; display: flex; flex-direction: column; }
  .tabs { display: flex; gap: 2px; border-bottom: 2px solid var(--lotj-border); padding-bottom: 2px; flex-wrap: wrap; }
  .tab { padding: 3px 6px; border-radius: 3px 3px 0 0; cursor: pointer;
         font-size: 0.75em; background: var(--lotj-card); color: var(--lotj-muted);
         border: 1px solid transparent; border-bottom: none; min-height: 24px;
         display: flex; align-items: center; gap: 3px; user-select: none; }
  .tab:hover { color: var(--lotj-text); }
  .tab.active { background: var(--lotj-active-tab); color: var(--lotj-text); border-color: var(--lotj-border); border-bottom-color: var(--lotj-active-tab); }
  .unread-badge { background: var(--lotj-warn); color: #000; font-size: 0.7em;
                  padding: 0 3px; border-radius: 8px; font-weight: bold; min-width: 14px; text-align: center; }
  .tab-content { flex: 1; overflow-y: auto; display: none; }
  .tab-content.active { display: block; }
  .msg { padding: 1px 3px; border-bottom: 1px solid rgba(51,65,85,0.3); font-size: 0.85em; line-height: 1.4; }
  .msg .ch { font-weight: bold; margin-right: 3px; }
  .msg .sender { color: var(--lotj-accent); margin-right: 3px; }
  .stats-row { display: flex; justify-content: space-between; padding: 1px 3px; font-size: 0.8em; border-bottom: 1px solid rgba(51,65,85,0.2); }
  .stats-row .label { color: var(--lotj-muted); }
  .stats-row .value { color: var(--lotj-text); font-weight: bold; }
  .route { padding: 3px; background: var(--lotj-card); border-radius: 3px; margin-bottom: 3px; }
  .route-name { color: var(--lotj-accent); font-weight: bold; }
  .route-detail { color: var(--lotj-muted); font-size: 0.9em; }
  .mods-slot { margin-top: 3px; padding-top: 3px; border-top: 1px solid var(--lotj-border); }
  @media (prefers-reduced-motion: reduce) { .tab-content { transition: none; } }
  @media (pointer: coarse) { .tab { min-height: 44px; min-width: 44px; } }
</style></head><body>
<div class="tabs" id="tabs">
  <div class="tab active" data-tab="all">All</div>
  <div class="tab" data-tab="local">Local <span class="unread-badge" id="lotj-local-badge" style="display:none">0</span></div>
  <div class="tab" data-tab="commnet">CommNet <span class="unread-badge" id="lotj-commnet-badge" style="display:none">0</span></div>
  <div class="tab" data-tab="clan">Clan <span class="unread-badge" id="lotj-clan-badge" style="display:none">0</span></div>
  <div class="tab" data-tab="broadcast">Broadcast <span class="unread-badge" id="lotj-broadcast-badge" style="display:none">0</span></div>
  <div class="tab" data-tab="ooc">OOC <span class="unread-badge" id="lotj-ooc-badge" style="display:none">0</span></div>
  <div class="tab" data-tab="tell">Tell <span class="unread-badge" id="lotj-tell-badge" style="display:none">0</span></div>
  <div class="tab" data-tab="imm">Imm <span class="unread-badge" id="lotj-imm-badge" style="display:none">0</span></div>
  <div class="tab" data-tab="stats">Stats</div>
  <div class="tab" data-tab="autopilot">AutoPilot</div>
</div>
<div class="tab-content active" id="tab-all"></div>
<div class="tab-content" id="tab-local"></div>
<div class="tab-content" id="tab-commnet"></div>
<div class="tab-content" id="tab-clan"></div>
<div class="tab-content" id="tab-broadcast"></div>
<div class="tab-content" id="tab-ooc"></div>
<div class="tab-content" id="tab-tell"></div>
<div class="tab-content" id="tab-imm"></div>
<div class="tab-content" id="tab-stats">
  <div class="stats-row"><span class="label">Damage Dealt</span><span class="value" id="stat-damage-dealt">0</span></div>
  <div class="stats-row"><span class="label">Hits Given</span><span class="value" id="stat-hits-given">0</span></div>
  <div class="stats-row"><span class="label">Misses</span><span class="value" id="stat-misses">0</span></div>
  <div class="stats-row"><span class="label">Dodges</span><span class="value" id="stat-dodges">0</span></div>
  <div class="stats-row"><span class="label">Damage Taken</span><span class="value" id="stat-damage-taken">0</span></div>
  <div class="stats-row"><span class="label">Bacta Change</span><span class="value" id="stat-bacta-change">0</span></div>
</div>
<div class="tab-content" id="tab-autopilot">
  <div id="autopilot-content"><p style="color:var(--lotj-muted);font-size:0.85em">No active route.</p></div>
</div>
<div class="mods-slot" id="mods-slot"></div>
<script>
  var channels = ["all", "local", "commnet", "clan", "broadcast", "ooc", "tell", "imm"];
  var activeChannel = "all";
  var unread = {};
  var historyLimit = 250;
  document.getElementById("tabs").addEventListener("click", function(e) {
    var tab = e.target.closest(".tab");
    if (!tab) return;
    var tabName = tab.getAttribute("data-tab");
    document.querySelectorAll(".tab").forEach(function(t) { t.classList.remove("active"); });
    document.querySelectorAll(".tab-content").forEach(function(c) { c.classList.remove("active"); });
    tab.classList.add("active");
    var content = document.getElementById("tab-" + tabName);
    if (content) content.classList.add("active");
    activeChannel = tabName;
    updateBadge(tabName, 0);
    // Return focus to MUD prompt after tab switch
    mudforge.send("tabClick", { tab: tabName });
  });
  mudforge.onMessage(function(data) {
    if (data.event === "chatMessage" && data.msg) appendChat(data.msg);
    if (data.event === "chatReset") resetHistory();
    if (data.event === "combatStats" && data.stats) updateStats(data.stats);
    if (data.event === "autopilotRoute" && data.route) updateAutopilot(data.route);
    if (data.event === "unreadBadge" && data.channel) updateBadge(data.channel, data.count);
  });
  function appendChat(msg) {
    var channel = channels.includes(msg.channel) ? msg.channel : "all";
    appendTo("all", channel, msg);
    if (channel === "all") return;
    appendTo(channel, channel, msg);
    if (activeChannel !== channel) {
      updateBadge(channel, Math.min(historyLimit, (unread[channel] || 0) + 1));
    }
  }
  function appendTo(tabName, channel, msg) {
    var tab = document.getElementById("tab-" + tabName);
    var row = document.createElement("div");
    row.className = "msg";
    addText(row, "ch", channel);
    addText(row, "sender", msg.sender);
    addText(row, "", msg.text);
    tab.appendChild(row);
    if (tab.childElementCount > historyLimit) tab.firstElementChild.remove();
    tab.scrollTop = tab.scrollHeight;
  }
  function addText(row, className, text) {
    if (!text) return;
    var span = document.createElement("span");
    span.className = className;
    span.textContent = text;
    row.appendChild(span);
  }
  function resetHistory() {
    channels.forEach(function(channel) {
      document.getElementById("tab-" + channel).replaceChildren();
      updateBadge(channel, 0);
    });
  }
  function updateStats(stats) {
    if (stats.damageDealt !== undefined) document.getElementById("stat-damage-dealt").textContent = stats.damageDealt;
    if (stats.hitsGiven !== undefined) document.getElementById("stat-hits-given").textContent = stats.hitsGiven;
    if (stats.misses !== undefined) document.getElementById("stat-misses").textContent = stats.misses;
    if (stats.dodges !== undefined) document.getElementById("stat-dodges").textContent = stats.dodges;
    if (stats.damageTaken !== undefined) document.getElementById("stat-damage-taken").textContent = stats.damageTaken;
    if (stats.bactaChange !== undefined) document.getElementById("stat-bacta-change").textContent = stats.bactaChange;
  }
  function updateAutopilot(route) {
    var el = document.getElementById("autopilot-content");
    if (!el) return;
    if (route && route.name) { el.innerHTML = '<div class="route"><div class="route-name">' + mudforge.escapeHTML(route.name) + '</div><div class="route-detail">' + mudforge.escapeHTML(route.detail || "") + '</div></div>'; }
    else { el.innerHTML = '<p style="color:var(--lotj-muted);font-size:0.85em">No active route.</p>'; }
  }
  function updateBadge(channel, count) {
    var badge = document.getElementById("lotj-" + channel + "-badge");
    if (badge) {
      unread[channel] = count;
      badge.textContent = count;
      badge.style.display = count > 0 ? "inline" : "none";
    }
  }
  mudforge.send("ready", { widget: "lotj-comms-hub" });
</script>
</body></html>]])
end

function handleChatMessage(msg)
  if not commsHub or commsHub == "" then return end
  if not ready then
    if #pending == HISTORY_LIMIT then table.remove(pending, 1) end
    pending[#pending + 1] = msg
    return
  end
  sendWidgetMessage(commsHub, { event = "chatMessage", msg = msg })
end

local function resetHistory()
  pending = {}
  if ready then sendWidgetMessage(commsHub, { event = "chatReset" }) end
end

function handleCombatStats(stats)
  if not commsHub then return end
  sendWidgetMessage(commsHub, { event = "combatStats", stats = stats })
end

function handleAutopilotRoute(route)
  if not commsHub then return end
  sendWidgetMessage(commsHub, { event = "autopilotRoute", route = route })
end

function handleUnreadBadge(channel, count)
  if not commsHub then return end
  sendWidgetMessage(commsHub, { event = "unreadBadge", channel = channel, count = count })
end

return {
  init = initCommsHub,
  handleChatMessage = handleChatMessage,
  resetHistory = resetHistory,
  handleCombatStats = handleCombatStats,
  handleAutopilotRoute = handleAutopilotRoute,
  handleUnreadBadge = handleUnreadBadge,
}
