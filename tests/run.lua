-- Test runner for Lua 5.1 (MudForge) and 5.4.
-- Runs every tests/**/*_spec.lua that git tracks or would track in its own interpreter process, from
-- the repository root, and exits non-zero if any spec fails.
-- Usage: lua tests/run.lua [--coverage] [pattern]
--   --coverage records executed src/ lines into .coverage-hits for tests/coverage.lua.
local interpreter = arg[-1] or "lua"
local coverage, filter = false, nil
for _, value in ipairs(arg) do
  if value == "--coverage" then coverage = true else filter = value end
end
local HITS = ".coverage-hits"

local function list_specs()
  local pipe = assert(io.popen("git ls-files --cached --others --exclude-standard -- tests"))
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

if coverage then os.remove(HITS) end

local failed = {}
for _, spec in ipairs(specs) do
  io.write("== ", spec, " (", _VERSION, ")\n")
  io.flush()
  local command = coverage
    and (interpreter .. ' tests/support/coverage.lua "' .. spec .. '" ' .. HITS)
    or (interpreter .. ' "' .. spec .. '"')
  if not succeeded(os.execute(command)) then
    failed[#failed + 1] = spec
  end
end

print(("%d specs, %d failed"):format(#specs, #failed))
for _, spec in ipairs(failed) do print("FAILED: " .. spec) end
os.exit(#failed == 0 and 0 or 1)
