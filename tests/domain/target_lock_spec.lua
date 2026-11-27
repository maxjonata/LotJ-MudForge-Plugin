-- Pure domain spec for NAV-08 target state. No host stubs.
local lock = dofile("src/domain/target-lock.lua")

local function near(a, b) return math.abs(a - b) < 1e-6 end

local origin = { x = 100, y = 200, z = -50 }
local contacts = {
  { kind = "contact", category = "ship", name = "Red Fury", x = 100, y = 300, z = -50 },
  { kind = "contact", category = "planet", name = "Tatooine", x = 0, y = 0, z = 0 },
  { kind = "contact", category = "ship", name = "Red Fury", x = 400, y = 200, z = -50 },
  { kind = "contact", category = "star", name = "Tatoo", x = 1, y = 1, z = 1 },
}

do -- empty state
  local s = lock.empty()
  assert(s.status == "none" and s.name == nil, "a new lock has no target")
end

do -- selecting a ship computes relative geometry from the nearest same-named contact
  local s = lock.select(lock.empty(), origin, contacts, "Red Fury")
  assert(s.status == "selected" and s.name == "Red Fury")
  assert(s.dx == 0 and s.dy == 100 and s.dz == 0, "relative offset is contact minus origin")
  assert(near(s.distance, 100))
  assert(near(s.bearing, 90), "bearing is degrees from +X toward +Y")
  assert(near(s.elevation, 0))
  print("PASS: select computes distance, bearing and elevation")
end

do -- bearing is normalized to [0, 360) and elevation is signed
  local s = lock.select(lock.empty(), { x = 0, y = 0, z = 0 },
    { { category = "ship", name = "Low", x = 0, y = -10, z = -10 } }, "Low")
  assert(near(s.bearing, 270) and near(s.elevation, -45))
  print("PASS: bearing wraps and elevation keeps its sign")
end

do -- only ships can be targeted (HELP TARGET: target <ship name>)
  local before = lock.empty()
  assert(lock.select(before, origin, contacts, "Tatooine") == before, "planets are not targets")
  assert(lock.select(before, origin, contacts, "Tatoo") == before, "stars are not targets")
  assert(lock.select(before, origin, contacts, "Nobody") == before, "unknown names change nothing")
  assert(lock.select(before, nil, contacts, "Red Fury") == before, "no origin, no geometry")
  assert(lock.select(before, origin, nil, "Red Fury") == before)
  assert(lock.select(before, origin, contacts, nil) == before)
  print("PASS: non-ship, unknown and incomplete selections are ignored")
end

do -- a new radar readout recomputes, and loss keeps the last geometry
  local s = lock.select(lock.empty(), origin, contacts, "Red Fury")
  s = lock.markSent(s)
  assert(s.status == "sent", "sending target marks the command as sent, not confirmed")
  local moved = lock.onRadar(s, origin, {
    { category = "ship", name = "Red Fury", x = 100, y = 250, z = -50 } })
  assert(moved.status == "sent" and near(moved.distance, 50), "a sent target keeps its status when seen again")
  local lost = lock.onRadar(moved, origin, {})
  assert(lost.status == "lost" and near(lost.distance, 50), "missing from radar marks it lost with last geometry")
  local back = lock.onRadar(lost, origin, contacts)
  assert(back.status == "selected", "a lost target seen again must be targeted again")
  assert(lock.onRadar(lock.empty(), origin, contacts).status == "none", "radar never selects by itself")
  local unknown = lock.onRadar(s, nil, contacts)
  assert(unknown.status == "lost", "a readout without origin cannot confirm the target")
  print("PASS: radar updates recompute, lose and recover the target")
end

do -- markSent only applies to a visible target
  assert(lock.markSent(lock.empty()).status == "none")
  local lost = lock.onRadar(lock.select(lock.empty(), origin, contacts, "Red Fury"), origin, {})
  assert(lock.markSent(lost).status == "lost", "a lost target cannot be sent")
  print("PASS: markSent requires a visible target")
end

do -- commands follow the documented syntax and reject unsafe names
  local s = lock.select(lock.empty(), origin, contacts, "Red Fury")
  assert(lock.command("target", s) == "target Red Fury")
  assert(lock.command("face", s) == "face Red Fury")
  assert(lock.command("fire", s) == "fire")
  assert(lock.command("fire", s, "Ion") == "fire ion", "weapon types come from HELP FIRE")
  assert(lock.command("fire", s, "Plasma") == nil, "undocumented weapons are refused")
  assert(lock.command("target", lock.empty()) == nil)
  assert(lock.command("dance", s) == nil, "unknown actions are refused")
  local evil = { status = "selected", name = "Bad;quit" }
  assert(lock.command("target", evil) == nil, "names outside the radar charset are refused")
  assert(#lock.WEAPONS == 8)
  print("PASS: commands use documented syntax only")
end

do -- state values are immutable snapshots
  local s = lock.select(lock.empty(), origin, contacts, "Red Fury")
  local t = lock.markSent(s)
  assert(s.status == "selected" and t ~= s, "transitions return new tables")
  print("PASS: transitions do not mutate their input")
end

do -- the nearest same-named ship wins regardless of order
  local o = { x = 0, y = 0, z = 0 }
  local far = { category = "ship", name = "Twin", x = 300, y = 0, z = 0 }
  local close = { category = "ship", name = "Twin", x = 10, y = 0, z = 0 }
  local other = { category = "ship", name = "Other", x = 1, y = 0, z = 0 }
  assert(lock.select(lock.empty(), o, { far, other, close }, "Twin").distance == 10)
  assert(lock.select(lock.empty(), o, { close, other, far }, "Twin").distance == 10)
  print("PASS: duplicate names resolve to the nearest ship")
end
