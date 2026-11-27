local HTML = [=[
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root { color-scheme: dark; --ink:#e6f3f9; --muted:#93adb9; --edge:#233c48; --mint:#68ead3;
    --amber:#f1ce8c; --blue:#9eb9fb; font:14px system-ui,sans-serif; }
  * { box-sizing:border-box; }
  body { margin:0; min-height:100vh; color:var(--ink); background:#081219; }
  button { font:inherit; color:inherit; cursor:pointer; }
  button:focus-visible { outline:2px solid var(--amber); outline-offset:2px; }
  button:disabled { opacity:.45; cursor:default; }
  [hidden] { display:none !important; }
  header { display:flex; align-items:center; justify-content:space-between; gap:9px; flex-wrap:wrap;
    border-bottom:1px solid var(--edge); padding:10px 12px; background:#0b1b24; }
  .tabs, .actions { display:flex; gap:6px; align-items:center; flex-wrap:wrap; }
  .tab, .tool { padding:7px 10px; min-height:36px; border-radius:6px; border:1px solid var(--edge); background:#11252e; }
  .tab[aria-selected="true"], .tool.primary { background:#143d41; border-color:#3fae9e; color:#b0ffef; }
  .tool:not(:disabled):hover, .tab:hover { border-color:var(--mint); }
  .panel { padding:10px 12px 12px; }
  .bar { display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:7px; margin-bottom:9px; }
  .readout, .range { font:12px ui-monospace,monospace; color:var(--muted); }
  .range { min-width:58px; text-align:center; }
  .radar { position:relative; overflow:hidden; border:1px solid var(--edge); border-radius:8px;
    background:radial-gradient(ellipse at 50% 67%,#13333c 0%,#0c202a 39%,#07131e 83%); }
  canvas { display:block; width:100%; height:auto; cursor:crosshair; }
  #notice { margin:8px 0; min-height:1.3em; color:var(--amber); font-size:12px; }
  .legend { display:flex; gap:12px; color:var(--muted); font-size:11px; flex-wrap:wrap; margin:6px 0 10px; }
  .legend b { margin-right:4px; }
  .ship { color:var(--mint); }.planet { color:var(--blue); }.star { color:var(--amber); }
  .contacts { display:flex; flex-wrap:wrap; gap:5px; max-height:106px; overflow:auto; padding:2px; }
  .contact { border:1px solid var(--edge); background:#10252f; border-radius:6px; padding:5px 7px;
    min-height:31px; text-align:left; overflow-wrap:anywhere; }
  .contact[aria-pressed="true"], .sector[aria-pressed="true"] { border-color:var(--mint); background:#1a4449; }
  .detail { min-height:1.3em; font:12px ui-monospace,monospace; color:var(--muted); margin:8px 0 0; }
  .sky { position:relative; width:100%; aspect-ratio:1.55; min-height:255px; isolation:isolate; border:1px solid var(--edge); border-radius:8px;
    overflow:hidden; background:
      radial-gradient(circle at 15% 13%,#88b1bf 0 1px,transparent 2px) 0 0/47px 41px,
      radial-gradient(circle at 73% 37%,#697aa2 0 .5px,transparent 1.5px) 9px 8px/31px 59px,
      radial-gradient(ellipse at 60% 45%,#263954,#0b1827 54%,#07121e 88%);
    }
  .sky::before { position:absolute; inset:0; z-index:-1; content:""; opacity:.45;
    background:linear-gradient(90deg,#436172 1px,transparent 1px) 0 0/10% 100%,
      linear-gradient(#436172 1px,transparent 1px) 0 0/100% 10%; }
  .sector { position:absolute; transform:translate(-50%,-50%); min-width:25px; min-height:25px; padding:2px 5px;
    border:1px solid #7596bb; background:#182c41; border-radius:11px; color:#e5edff; font-size:10px; }
  .sector::before { content:""; display:inline-block; width:6px; height:6px; margin-right:3px; border-radius:50%;
    background:#bad5ff; box-shadow:0 0 8px #95bdff; }
  .sector[data-current="true"] { color:#b0ffef; border-color:var(--mint); }
  .sector[data-current="true"]::before { background:var(--mint); }
  .map-info { padding:14px; border:1px solid var(--edge); border-radius:8px; background:#10242d; }
  .map-info p { margin:0 0 12px; color:var(--muted); }
  @media (max-width:430px) { .sector { font-size:0; width:29px; height:29px; } .sector::before { margin:0; width:8px; height:8px; }
    .panel,header { padding-inline:8px; } }
</style>
</head>
<body>
<header>
  <div class="tabs" role="tablist" aria-label="Navigation views">
    <button id="tab-map" class="tab" type="button" role="tab" aria-selected="false" aria-controls="map" tabindex="-1">Map</button>
    <button id="tab-system" class="tab" type="button" role="tab" aria-selected="true" aria-controls="system">System</button>
    <button id="tab-galaxy" class="tab" type="button" role="tab" aria-selected="false" aria-controls="galaxy" tabindex="-1">Galaxy</button>
  </div>
  <div class="actions">
    <button id="open-comms" class="tool" type="button">Comms</button>
    <button id="fit-panel" class="tool" type="button" aria-label="Fit navigation panel" title="Fit navigation panel">Fit</button>
  </div>
</header>
<section id="map" class="panel" role="tabpanel" aria-labelledby="tab-map" hidden>
  <div class="map-info"><p id="room">Waiting for room information</p>
    <button id="open-map" class="tool primary" type="button">Open ground map</button></div>
</section>
<section id="system" class="panel" role="tabpanel" aria-labelledby="tab-system">
  <div class="bar">
    <div class="actions">
      <button id="radar" class="tool primary" type="button">Radar</button>
      <button id="proximity" class="tool" type="button">Proximity</button>
    </div>
    <div class="actions">
      <button id="zoom-out" class="tool" type="button" aria-label="Increase radar range">−</button>
      <output id="range" class="range" aria-live="polite"></output>
      <button id="zoom-in" class="tool" type="button" aria-label="Decrease radar range">+</button>
    </div>
  </div>
  <div id="position" class="readout">Waiting for ship position</div>
  <div class="radar">
    <canvas id="plot" width="720" height="448" role="img" aria-label="Orthographic isometric radar with X, Y and Z axes"></canvas>
  </div>
  <div class="legend" aria-label="Contact symbols"><span><b class="ship">◆</b>Ship</span>
    <span><b class="planet">●</b>Planet</span><span><b class="star">✦</b>Star</span><span>Stems show elevation</span></div>
  <p id="notice" role="status"></p>
  <div id="contacts" class="contacts" aria-label="Contacts in range"></div>
  <p id="contact-detail" class="detail" aria-live="polite"></p>
</section>
<section id="galaxy" class="panel" role="tabpanel" aria-labelledby="tab-galaxy" hidden>
  <div class="bar"><span class="readout">Public systems · galactic X / Y</span>
    <a href="https://www.legendsofthejedi.com/galaxy-map" target="_blank" rel="noopener noreferrer" style="color:var(--mint)">Source</a></div>
  <div id="galaxy-chart" class="sky" aria-label="Public galaxy map"></div>
  <p id="sector-detail" class="detail" aria-live="polite">Select a system for its coordinates and planets.</p>
</section>
<script>
  const $ = id => document.getElementById(id);
  const list = value => value && typeof value === "object" ? Object.values(value) : [];
  const tabs = ["map", "system", "galaxy"];
  const ranges = [250, 500, 1000, 2500, 5000, 10000, 25000, 50000];
  const colors = { ship: "#68ead3", planet: "#9eb9fb", star: "#f1ce8c" };
  const glyphs = { ship: "◆", planet: "●", star: "✦" };
  const canvas = $("plot"), ctx = canvas.getContext("2d");
  let position, contacts = [], selected, plotted = [], rangeIndex = 2, scanState = "idle";
  let systems = [], galaxyLocation, sector;

  function switchTab(name, focus) {
    for (const id of tabs) {
      const active = id === name, tab = $("tab-" + id);
      tab.setAttribute("aria-selected", String(active));
      tab.tabIndex = active ? 0 : -1;
      $(id).hidden = !active;
    }
    if (focus) $("tab-" + name).focus();
    if (name === "map") mudforge.send("read-room", {});
    if (name === "galaxy" && !systems.length) mudforge.send("read-galaxy", {});
  }
  for (const [index, id] of tabs.entries()) {
    const tab = $("tab-" + id);
    tab.addEventListener("click", () => switchTab(id, false));
    tab.addEventListener("keydown", event => {
      if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
        event.preventDefault();
        const offset = event.key === "ArrowRight" ? 1 : -1;
        switchTab(tabs[(index + offset + tabs.length) % tabs.length], true);
      }
    });
  }
  for (const event of ["radar", "proximity", "open-map", "open-comms", "fit-panel"]) {
    $(event).addEventListener("click", () => mudforge.send(event, {}));
  }
  $("zoom-in").addEventListener("click", () => {
    if (rangeIndex > 0) { rangeIndex--; drawRadar(); }
  });
  $("zoom-out").addEventListener("click", () => {
    if (rangeIndex < ranges.length - 1) { rangeIndex++; drawRadar(); }
  });

  // Orthographic isometry: the projected X, Y and Z unit axes have equal length.
  function project(x, y, z, scale) {
    return [360 + (x - y) * 0.8660254038 * scale, 246 + ((x + y) * 0.5 - z) * scale];
  }
  function line(a, b, color) {
    ctx.beginPath(); ctx.strokeStyle = color; ctx.moveTo(...a); ctx.lineTo(...b); ctx.stroke();
  }
  function circle(radius, scale) {
    ctx.beginPath(); ctx.strokeStyle = "#365560";
    for (let i = 0; i <= 64; i++) {
      const t = i * Math.PI / 32;
      const point = project(radius * Math.cos(t), radius * Math.sin(t), 0, scale);
      if (i === 0) ctx.moveTo(...point); else ctx.lineTo(...point);
    }
    ctx.stroke();
  }
  function drawRadar() {
    const range = ranges[rangeIndex], scale = 154 / range;
    $("range").textContent = range.toLocaleString("en-US");
    $("zoom-in").disabled = rangeIndex === 0;
    $("zoom-out").disabled = rangeIndex === ranges.length - 1;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.font = "14px monospace";
    for (const fraction of [1, 2/3, 1/3]) circle(range * fraction, scale);
    for (const [x,y,z,label] of [[range,0,0,"X"],[0,range,0,"Y"],[0,0,range,"Z"]]) {
      line(project(-x,-y,-z,scale), project(x,y,z,scale), z ? "#59648c" : "#3d6370");
      const [px,py] = project(x,y,z,scale);
      ctx.fillStyle = z ? "#b1bee5" : "#a0becb"; ctx.fillText(label, px+7, py);
    }
    ctx.fillStyle = position ? "#c6fff1" : "#79919a";
    ctx.beginPath(); ctx.arc(360,246,5,0,Math.PI*2); ctx.fill();
    ctx.fillText("YOU", 369, 239);

    plotted = position ? contacts.map((c, id) => {
      const x = c.x - position.x, y = c.y - position.y, z = c.z - position.z;
      return { ...c, id, x, y, z, distance: Math.hypot(x,y,z) };
    }).filter(c => c.distance <= range) : [];
    const fragment = document.createDocumentFragment();
    for (const c of plotted) {
      const point = project(c.x,c.y,c.z,scale);
      c.point = point;
      const foot = project(c.x,c.y,0,scale), color = colors[c.category] || colors.ship;
      line(foot, point, c.id === selected ? color : "#6a8590");
      ctx.fillStyle = "#8da4ac"; ctx.fillRect(foot[0]-1,foot[1]-1,2,2);
      ctx.fillStyle = color;
      ctx.font = c.id === selected ? "bold 24px monospace" : "18px monospace";
      ctx.fillText(glyphs[c.category] || "◆", point[0]-5,point[1]+5);
      const button = document.createElement("button");
      button.type = "button"; button.className = "contact " + c.category;
      button.setAttribute("aria-pressed", String(c.id === selected));
      button.textContent = c.name + " · " + Math.round(c.distance);
      button.addEventListener("click", () => selectContact(c.id, true));
      fragment.appendChild(button);
    }
    $("contacts").replaceChildren(fragment);
    const c = plotted.find(item => item.id === selected);
    $("contact-detail").textContent = c ? c.name + " · ΔX " + c.x + " · ΔY " + c.y + " · ΔZ " + c.z
      : (["complete", "truncated"].includes(scanState) ? plotted.length + " of " + contacts.length + " contacts in range" : "");
  }
  function selectContact(id, focus) {
    selected = id;
    drawRadar();
    if (focus) $("contacts").querySelector('[aria-pressed="true"]')?.focus();
  }
  canvas.addEventListener("click", event => {
    const bounds = canvas.getBoundingClientRect();
    const x = (event.clientX - bounds.left) * canvas.width / bounds.width;
    const y = (event.clientY - bounds.top) * canvas.height / bounds.height;
    let nearest, distance = 16;
    for (const c of plotted) {
      const d = Math.hypot(c.point[0]-x,c.point[1]-y);
      if (d < distance) { nearest = c; distance = d; }
    }
    if (nearest) selectContact(nearest.id, false);
  });

  function drawGalaxy() {
    if (!systems.length) return;
    const fragment = document.createDocumentFragment();
    const xs = systems.map(s => s.x), ys = systems.map(s => s.y);
    const left = Math.min(...xs), top = Math.max(...ys);
    const spanX = Math.max(1,Math.max(...xs)-left), spanY = Math.max(1,top-Math.min(...ys));
    for (const s of systems) {
      const button = document.createElement("button");
      button.type = "button"; button.className = "sector";
      button.style.left = (9 + 82 * (s.x-left) / spanX) + "%";
      button.style.top = (11 + 78 * (top-s.y) / spanY) + "%";
      button.textContent = s.label;
      button.title = s.name;
      button.setAttribute("aria-label", s.name);
      button.setAttribute("aria-pressed", String(sector === s.name));
      const here = !!galaxyLocation && galaxyLocation.x === s.x && galaxyLocation.y === s.y;
      button.dataset.current = String(here);
      if (here) button.setAttribute("aria-current", "location");
      button.addEventListener("click", () => {
        sector = s.name;
        $("sector-detail").textContent = s.name + " · X " + s.x + " · Y " + s.y
          + (s.planets ? " · " + s.planets : " · No public planets");
        drawGalaxy();
        $("galaxy-chart").querySelector('[aria-pressed="true"]')?.focus();
      });
      fragment.appendChild(button);
    }
    $("galaxy-chart").replaceChildren(fragment);
  }

  mudforge.onMessage(message => {
    if (message.event === "position") {
      position = message.position;
      const next = list(message.contacts);
      const updated = JSON.stringify(next) !== JSON.stringify(contacts);
      if (updated) { contacts = next; selected = undefined; }
      scanState = message.scanState || "idle";
      $("position").textContent = position ? "X " + position.x + " · Y " + position.y + " · Z " + position.z
        : "Waiting for ship position";
      $("radar").disabled = message.radarBusy === true;
      const active = {
        scanning: "Waiting for radar readout…",
        timeout: message.radarBusy ? "Discarding late lines after an incomplete radar readout…" : "No complete radar readout arrived.",
        rejected: "The game requires a ship cockpit or turret to scan.",
        truncated: "Showing the first 256 contacts from this scan.",
        proximity: "Proximity readout goes to the terminal.",
        "awaiting-origin": "Run Radar to establish position in the new system.",
      };
      $("notice").textContent = active[scanState] || "";
      drawRadar();
    } else if (message.event === "disconnected") {
      $("notice").textContent = "Connect to the game to scan.";
    } else if (message.event === "galaxy") {
      if (message.systems) systems = list(message.systems);
      galaxyLocation = message.location;
      drawGalaxy();
    } else if (message.event === "room") {
      $("room").textContent = message.name ? message.name + (message.zone ? " · " + message.zone : "")
        : "Waiting for room information";
    }
  });
  drawRadar();
  mudforge.send("ready", {});
</script>
</body>
</html>
]=]

local function create(ports)
  local window = getWindowSize()
  local width = math.min(650, math.max(290, math.floor(window.width * 0.54)))
  local height = math.min(635, math.max(360, window.height - 140))
  local id = createWidget({
    type = "html",
    name = "lotj-scrapper-cockpit",
    title = "LOTJ Navigation",
    position = { x = math.max(12, window.width - width - 16), y = 68 },
    size = { width = width, height = height },
    visible = false,
  })
  if not id then return nil end

  local ready, location = false, nil

  local function publish(position, contacts, scanState, radarBusy)
    if not ready then return end
    local session = getSession()
    sendWidgetMessage(id, {
      event = "position", position = position, contacts = contacts,
      scanState = scanState, radarBusy = radarBusy,
      connected = session ~= nil and session.connected == true,
    })
  end

  local function publishGalaxy(includeCatalogue)
    if not ready then return end
    sendWidgetMessage(id, {
      event = "galaxy",
      systems = includeCatalogue and ports.publicGalaxy or nil,
      location = location,
    })
  end

  local function publishSystem(position)
    local hadLocation = location ~= nil
    location = position
    if hadLocation or location then publishGalaxy(false) end
  end

  local function publishRoom(room)
    if not ready then return end
    sendWidgetMessage(id, {
      event = "room", name = room and room.name, zone = room and (room.zone or room.area),
    })
  end

  local function bind(cockpit)
    registerWidgetEvent(id, "luamsg", function(message)
      if not message then return end
      if message.event == "ready" then
        ready = true
        publishGalaxy(true)
        cockpit.refresh()
      elseif message.event == "radar" or message.event == "proximity" then
        if not cockpit.requestScan(message.event) then
          sendWidgetMessage(id, { event = "disconnected" })
        end
      elseif message.event == "read-galaxy" then
        ready = true
        publishGalaxy(true)
      elseif message.event == "read-room" then
        publishRoom(getCurrentRoom())
      elseif message.event == "open-map" then
        ports.openMap()
      elseif message.event == "open-comms" then
        ports.openComms()
      elseif message.event == "fit-panel" then
        resizeWidget(id, width, height)
      end
    end)
    setWidgetProperty(id, "content", HTML)

    local function showNavigation()
      showWidget(id, true)
    end
    registerCommand("lotj-nav", showNavigation, "Open LOTJ Navigation")
    registerCommand("lotj-cockpit", showNavigation, "Open LOTJ Navigation")
  end

  return { bind = bind, publish = publish, publishSystem = publishSystem, publishRoom = publishRoom }
end

return { create = create }
