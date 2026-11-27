-- NAV-02: proximity is one explicit command; a cockpit refusal ends a scan.
return { name = "radar: proximity click and cockpit refusal", run = function(t)
  t.post("lotj-scrapper-cockpit", "ready")
  t.post("lotj-scrapper-cockpit", "proximity")
  t.eq(t.lastSend(), "proximity", "proximity command")
  t.post("lotj-scrapper-cockpit", "radar")
  t.line("You must be in the cockpit or turret of a ship to do that!")
  t.eq(t.last("lotj-scrapper-cockpit", "position").scanState, "rejected", "refusal ends the scan")
  t.eq(#t.sends(), 2, "two clicks, two sends")
end }
