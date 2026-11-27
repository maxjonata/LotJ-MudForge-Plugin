-- Run one spec with a line hook and append the lines it executed under src/.
-- Usage: lua tests/support/coverage.lua <spec> <hits-file>
local spec, hitsPath = arg[1], arg[2]
assert(spec and hitsPath, "usage: coverage.lua <spec> <hits-file>")

local hits = {}
local getinfo = debug.getinfo
debug.sethook(function(_, line)
  local source = getinfo(2, "S").source
  if source:sub(1, 5) == "@src/" then
    local lines = hits[source]
    if not lines then lines = {}; hits[source] = lines end
    lines[line] = true
  end
end, "l")

local ok, err = pcall(dofile, spec)
debug.sethook()

local out = assert(io.open(hitsPath, "a"))
for source, lines in pairs(hits) do
  for line in pairs(lines) do out:write(source:sub(2), "\t", line, "\n") end
end
out:close()

if not ok then
  io.stderr:write(tostring(err), "\n")
  os.exit(1)
end
