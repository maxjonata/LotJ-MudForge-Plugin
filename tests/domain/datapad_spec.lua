-- Pure domain spec for datapad commands (src/domain/datapad.lua, DATA-01).
-- Every command matches a syntax line of HELP DATAMEM / HELP DATASTAT.
local datapad = dofile("src/domain/datapad.lua")
local command = datapad.command

local cases = {
  { "new", nil, "datamem write new" },
  { "write", { slot = 3 }, "datamem write 3" },
  { "subject", { slot = 3, text = "Repair schedule" }, "datamem write 3 subject Repair schedule" },
  { "to", { slot = "3", text = "Kessa Vorr" }, "datamem write 3 to Kessa Vorr" },
  { "from", { slot = 3, text = "you" }, "datamem write 3 from you" },
  { "view", { slot = 1 }, "datamem view 1" },
  { "copy", { slot = 1 }, "datamem copy 1" },
  { "copy", { slot = 1, amount = "" }, "datamem copy 1" },
  { "copy", { slot = 1, amount = 4 }, "datamem copy 1 4" },
  { "receive", nil, "datamem receive" },
  { "send", { slot = 2 }, "datamem send 2" },
  { "show", { slot = 2, target = "Varn" }, "datamem show 2 Varn" },
  { "eject", { slot = 2 }, "datamem eject 2" },
  { "load", { keyword = "disk" }, "datamem load disk" },
  { "delete", { slot = 2 }, "datamem delete 2" },
  { "download", { slot = 2 }, "datamem download 2" },
  { "setbiometrics", {}, "datamem setbiometrics" },
  { "datastat", {}, "datastat" },
}
for _, case in ipairs(cases) do
  local got = command(case[1], case[2])
  assert(got == case[3], case[1] .. ": expected " .. case[3] .. ", got " .. tostring(got))
end
print("PASS: every datapad action builds its help syntax")

local function rejects(action, args, field)
  local got, reason = command(action, args)
  assert(got == nil and reason == field,
    tostring(action) .. " should fail on " .. field .. ", got " .. tostring(got) .. " / " .. tostring(reason))
end
rejects("view", {}, "slot")
rejects("view", { slot = 0 }, "slot")
rejects("view", { slot = 1.5 }, "slot")
rejects("view", { slot = 1000 }, "slot")
rejects("view", { slot = "x" }, "slot")
rejects("subject", { slot = 1, text = "   " }, "subject")
rejects("to", { slot = 1 }, "to")
rejects("show", { slot = 1, target = "" }, "target")
rejects("copy", { slot = 1, amount = -2 }, "amount")
rejects("load", { keyword = 7 }, "keyword")
rejects("format", { slot = 1 }, "action")
rejects(nil, nil, "action")
print("PASS: bad slots, empty text and unknown actions send nothing")

assert(command("subject", { slot = 1, text = "  a;b\ncd\t " }) == "datamem write 1 subject a,b cd",
  "control characters and the ; stack separator never reach send()")
print("PASS: free text is one argument")

assert(datapad.needsConfirm("delete") and datapad.needsConfirm("eject"))
assert(not datapad.needsConfirm("view") and not datapad.needsConfirm(nil))
assert(datapad.slot(" 7 ") == "7" and datapad.slot(nil) == nil)
print("PASS: delete and eject ask first")
