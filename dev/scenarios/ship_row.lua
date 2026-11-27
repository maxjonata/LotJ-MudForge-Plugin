-- SHIP-01: Ship.Info shows the ship row; an empty packet hides it.
return { name = "status bar: ship row follows Ship.Info", run = function(t)
  t.gmcp("Ship.Info", { hull = 5, maxHull = 9, posX = 1, posY = 2, posZ = 3 })
  local ship = t.last("lotj-status-bar", "shipVisible")
  t.check(ship and ship.visible == true, "ship row should be visible")
  t.eq(ship.ship.hull, 5, "hull")
  t.gmcp("Ship.Info", {})
  t.eq(t.last("lotj-status-bar", "shipVisible").visible, false, "empty Ship.Info hides the row")
  t.eq(#t.sends(), 0, "Ship.Info is passive")
end }
