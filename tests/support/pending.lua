-- Mark a roadmap card's acceptance criteria as not implemented yet (QA-08).
-- Prints them and records the card for tests/run.lua's pending count; never fails.
local PENDING = ".pending-specs"

return function(card, title, criteria)
  assert(type(card) == "string" and type(title) == "string" and type(criteria) == "table",
    "pending(card, title, { criteria... })")
  print(("PENDING: %s · %s"):format(card, title))
  for _, criterion in ipairs(criteria) do print("  - " .. criterion) end
  local out = io.open(PENDING, "a")
  if out then
    out:write(card, "\n")
    out:close()
  end
end
