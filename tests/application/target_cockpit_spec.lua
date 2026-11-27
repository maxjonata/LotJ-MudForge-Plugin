-- Application spec for NAV-08 with recording ports.
local lock = dofile("src/domain/target-lock.lua")
local app = dofile("src/application/target-cockpit.lua")

local function harness(connected)
  local h = { sends = {}, snapshots = {}, connected = connected ~= false }
  h.cockpit = app.new({
    targetLock = lock,
    send = function(command)
      if not h.connected then return false end
      h.sends[#h.sends + 1] = command
      return true
    end,
    publish = function(snapshot) h.snapshots[#h.snapshots + 1] = snapshot end,
  })
  h.last = function() return h.snapshots[#h.snapshots] end
  return h
end

local origin = { x = 0, y = 0, z = 0 }
local contacts = { { category = "ship", name = "Red Fury", x = 30, y = 40, z = 0 } }

do -- passive updates never send
  local h = harness()
  h.cockpit.onRadar(origin, contacts)
  h.cockpit.onRadar(origin, contacts)
  assert(#h.sends == 0, "radar updates must not send")
  assert(h.cockpit.select("Red Fury") == true and #h.sends == 0, "selecting must not send")
  assert(h.last().status == "selected" and h.last().distance == 50)
  h.cockpit.onRadar(origin, {})
  assert(h.last().status == "lost" and #h.sends == 0)
  print("PASS: selection and radar updates are passive")
end

do -- each explicit click sends exactly one documented command
  local h = harness()
  h.cockpit.onRadar(origin, contacts)
  h.cockpit.select("Red Fury")
  assert(h.cockpit.aim() == true)
  assert(#h.sends == 1 and h.sends[1] == "target Red Fury")
  assert(h.last().status == "sent")
  assert(h.cockpit.face() == true and h.sends[2] == "face Red Fury")
  assert(h.cockpit.fire() == true and h.sends[3] == "fire")
  assert(h.cockpit.fire("Missile") == true and h.sends[4] == "fire missile")
  assert(h.cockpit.fire("Plasma") == false and #h.sends == 4, "undocumented weapon sends nothing")
  print("PASS: one send per click with documented syntax")
end

do -- preconditions
  local h = harness()
  assert(h.cockpit.aim() == false and h.cockpit.face() == false and h.cockpit.fire() == false,
    "nothing to act on without a target")
  h.cockpit.onRadar(origin, contacts)
  h.cockpit.select("Red Fury")
  assert(h.cockpit.fire() == false and #h.sends == 0, "fire requires target to have been sent")
  h.cockpit.onRadar(origin, {})
  assert(h.cockpit.aim() == false and h.cockpit.face() == false, "a lost target cannot be acted on")
  assert(h.cockpit.select("Nobody") == false)
  assert(#h.sends == 0)
  print("PASS: actions respect preconditions")
end

do -- disconnected: nothing recorded, state unchanged, caller told
  local h = harness(false)
  h.cockpit.onRadar(origin, contacts)
  h.cockpit.select("Red Fury")
  assert(h.cockpit.aim() == false and h.last().status == "selected", "failed send keeps the state")
  print("PASS: a failed send keeps state")
end

do -- clear and reset publish an empty target
  local h = harness()
  h.cockpit.onRadar(origin, contacts)
  h.cockpit.select("Red Fury")
  h.cockpit.clear()
  assert(h.last().status == "none")
  h.cockpit.select("Red Fury")
  h.cockpit.reset()
  assert(h.last().status == "none")
  assert(h.cockpit.select("Red Fury") == false, "reset also forgets the last radar readout")
  print("PASS: clear and reset")
end

do -- publish only on change
  local h = harness()
  h.cockpit.onRadar(origin, contacts)
  local n = #h.snapshots
  h.cockpit.onRadar(origin, contacts)
  assert(#h.snapshots == n, "no target, no change, no publish")
  h.cockpit.select("Red Fury")
  n = #h.snapshots
  h.cockpit.onRadar(origin, contacts)
  assert(#h.snapshots == n, "same geometry must not republish")
  h.cockpit.refresh()
  assert(#h.snapshots == n + 1, "refresh always publishes")
  print("PASS: publishes on change and on refresh")
end
