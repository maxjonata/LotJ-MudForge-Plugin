-- Command forms (src/domain/command-form.lua, UI-03): help syntax + typed values -> one game command.
local form = dofile("src/domain/command-form.lua")

local course = {
  template = "course {1} {2} {3}",
  args = { { name = "x", type = "number" }, { name = "y", type = "number" }, { name = "z", type = "number" } },
}

do
  assert(form.fill(course, { "10", " -20 ", "3" }) == "course 10 -20 3")
  local command, index, reason = form.fill(course, { "10", "", "3" })
  assert(command == nil and index == 2 and reason == "required", "empty required argument")
  command, index, reason = form.fill(course, { "1.5", "2", "3" })
  assert(command == nil and index == 1 and reason == "number", "numbers are whole")
  command, index, reason = form.fill({ template = "slice {1}", args = { { name = "#", type = "number", min = 0, max = 7 } } }, { "8" })
  assert(command == nil and index == 1 and reason == "range")
  assert(form.fill({ template = "slice {1}", args = { { name = "#", type = "number", min = 0, max = 7 } } }, { "7" }) == "slice 7")
  print("PASS: numbers are checked before anything is sent")
end

do
  local challenge = { template = "challenge {1} {2}", args = { { name = "target", type = "character" }, { name = "bet", type = "text", optional = true } } }
  assert(form.fill(challenge, { "Kel" }) == "challenge Kel", "an empty optional argument is dropped")
  assert(form.fill(challenge, { "Kel", "100" }) == "challenge Kel 100")
  local say = { template = "say {1}", args = { { name = "message", type = "text" } } }
  assert(form.fill(say, { "hi;quit\nnow %1" }) == "say hi,quit now %1", "; and control characters cannot stack commands")
  assert(form.fill({ template = "radar", args = {} }) == "radar", "no arguments")
  assert(form.fill({ template = "radar", args = {} }, "junk") == "radar")
  assert(form.fill("bad") == nil)
  assert(form.text(42) == nil and form.text("  ") == nil and form.text(" a ") == "a")
  print("PASS: free text is one safe argument; optional ones drop")
end

do
  local catalog = {
    stations = { { id = "pilot", title = "PILOTO", group = "NAVE" }, { id = "rp", title = "RP", group = "SALA" } },
    keys = {
      pilot = {
        { label = "AUTOPILOT", hint = "", variants = { { syntax = "autopilot", template = "autopilot", args = {} } }, topics = { "AUTOPILOT" } },
        { label = "COURSE", hint = "<x> <y> <z>", variants = { course }, topics = { "COURSE" } },
      },
      rp = { { label = "SAY", hint = "<message>", variants = { { syntax = "say <message>", template = "say {1}", args = {} } }, topics = { "SAY" } } },
    },
    references = { { topic = "PILOTING TUTORIAL", help = "piloting" }, { topic = "AUTOPILOTS EXPLAINED", help = "autopilots" } },
  }
  local found = form.search(catalog, "auto")
  assert(#found == 2 and found[1].kind == "key" and found[1].label == "AUTOPILOT" and found[1].station == "pilot" and found[1].index == 1,
    "keys whose label starts with the query come first")
  assert(found[2].kind == "reference" and found[2].help == "autopilots")
  assert(#form.search(catalog, "course 10") == 0, "every word must match")
  assert(#form.search(catalog, "say") == 1 and form.search(catalog, "SAY")[1].station == "rp")
  assert(#form.search(catalog, "") == 0 and #form.search(catalog, nil) == 0)
  assert(#form.search(catalog, "o", 1) == 1, "the limit is kept")
  assert(form.help({ help = "piloting" }) == "help piloting")
  assert(form.help({ help = "a;b" }) == "help a,b" and form.help({}) == nil and form.help(nil) == nil)
  print("PASS: the palette finds keys first, then Holocron topics")
end

do
  local catalog = dofile("src/domain/console-catalog.lua")
  local keys, variants, filled = 0, 0, 0
  for _, station in ipairs(catalog.stations) do
    for _, key in ipairs(catalog.keys[station.id] or {}) do
      keys = keys + 1
      for _, variant in ipairs(key.variants) do
        variants = variants + 1
        local values = {}
        for index, arg in ipairs(variant.args) do
          values[index] = arg.type == "number" and tostring(arg.min or 1) or (arg.choices and arg.choices[1] or "x")
        end
        local command = form.fill(variant, values)
        assert(command and not command:find("[{}<>]"), "variant fills to a plain command: " .. tostring(variant.syntax))
        filled = filled + 1
      end
    end
  end
  assert(keys > 400 and variants == filled, "every generated variant can be sent")
  assert(#catalog.references > 400)
  print("PASS: all " .. variants .. " generated variants fill to a plain command")
end
