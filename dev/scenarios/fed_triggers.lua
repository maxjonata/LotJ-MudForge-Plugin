-- ROOM-03: room lines go through the real trigger engine (feedTriggers) and
-- stay passive. Inside MudForge this runs the client's own JS-regex engine.
return { name = "triggers: fed room lines run plugin triggers passively", run = function(t)
  t.feed({ "You enter Docking Bay 94.", "The room is dark." }, function()
    t.eq(#t.sends(), 0, "room triggers sent a command")
  end)
end }
