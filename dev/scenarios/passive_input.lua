-- FND rule: nothing the MUD sends makes the plugin send a command by itself.
return { name = "passive: GMCP and lines never send", run = function(t)
  t.post("lotj-scrapper-cockpit", "ready")
  t.gmcp("Ship.Info", { posX = 1, posY = 2, posZ = 3 })
  t.gmcp("Ship.System", { x = 26, y = 41 })
  t.gmcp("Ship.System", "not a table")
  t.line("Your Coordinates: 8 8 8")
  t.line("[Status]: Hyperspace calculations have been completed.")
  t.line("You enter Docking Bay 94.")
  t.fireTimers()
  t.eq(#t.sends(), 0, "passive input sent a command")
end }
