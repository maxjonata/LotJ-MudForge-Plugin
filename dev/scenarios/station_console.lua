-- UI-03: a station console key sends its help syntax; the palette finds Holocron topics.
return { name = "station console: keys send help syntax, palette opens help", run = function(t)
  t.post("lotj-station-console", "ready")
  t.eq(t.last("lotj-station-console", "stations").list[1].id, "pilot", "stations start at the helm")
  t.post("lotj-station-console", "open", { id = "nav" })
  local station = t.last("lotj-station-console", "station")
  t.eq(station.title, "NAVEGAÇÃO", "the nav console opens")
  local radar
  for index, key in ipairs(station.keys) do
    if key.label == "RADAR" then radar = index end
  end
  t.post("lotj-station-console", "press", { id = "nav", index = radar })
  t.eq(t.lastSend(), "radar", "RADAR key")
  t.post("lotj-station-console", "search", { query = "piloting" })
  local hit
  for _, item in ipairs(t.last("lotj-station-console", "results").list) do
    if item.kind == "reference" then hit = hit or item end
  end
  t.post("lotj-station-console", "help", { index = hit.index })
  t.eq(t.lastSend(), "help " .. hit.help, "Holocron opens the game's help")
  t.post("lotj-station-console", "open", { id = "pilot" })
end }
