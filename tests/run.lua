-- Test runner for Lua 5.1 (MudForge) and 5.4.
-- Runs every tracked tests/**/*_spec.lua in its own interpreter process, from
-- the repository root, and exits non-zero if any spec fails.
-- Usage: lua tests/run.lua [pattern]
local interpreter = arg[-1] or "lua"
local filter = arg[1]

local function list_specs()
  local pipe = assert(io.popen("git ls-files -- tests"))
  local specs = {}
  for path in pipe:lines() do
    if path:match("_spec%.lua$") and (not filter or path:find(filter, 1, true)) then
      specs[#specs + 1] = path
    end
  end
  pipe:close()
  table.sort(specs)
  return specs
end

local function succeeded(a, b, c)
  if type(a) == "number" then return a == 0 end -- Lua 5.1
  return a == true and b == "exit" and c == 0
end

local specs = list_specs()
assert(#specs > 0, "no *_spec.lua files found under tests/")

local failed = {}
for _, spec in ipairs(specs) do
  io.write("== ", spec, " (", _VERSION, ")\n")
  io.flush()
  if not succeeded(os.execute(interpreter .. ' "' .. spec .. '"')) then
    failed[#failed + 1] = spec
  end
end

print(("%d specs, %d failed"):format(#specs, #failed))
for _, spec in ipairs(failed) do print("FAILED: " .. spec) end
os.exit(#failed == 0 and 0 or 1)
