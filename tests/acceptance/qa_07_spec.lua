-- QA-07: the DEV plugin (dev/main.lua) runs feature scenarios against the real
-- plugin code. Here it runs on the offline fake host; inside MudForge the same
-- files run on the real client (scripts/dev/install_dev_plugin.py).
local fake_host = dofile("tests/support/fake_host.lua")
local load_env = dofile("tests/support/load_env.lua")

local function output(host)
  local lines = {}
  for _, call in ipairs(host.calls) do
    if call[1] == "print" then lines[#lines + 1] = tostring(call[2]) end
  end
  return lines
end

local function find(lines, pattern)
  for _, line in ipairs(lines) do
    if line:find(pattern) then return line end
  end
end

do -- loading the DEV plugin runs every scenario once and reports a summary
  local host = fake_host.new()
  load_env("dev/main.lua", host.env)()
  assert(host.env.plugin.name == "LotJ Plugin DEV" and host.env.plugin.id == "lotj-dev",
    "the DEV plugin keeps its own identity after loading the production entry point")
  host.env.init()
  local lines = output(host)
  local summary = assert(find(lines, "^LOTJDEV SUMMARY "), "no summary line")
  local passed, failed = summary:match("passed=(%d+) failed=(%d+)")
  assert(tonumber(passed) > 0 and failed == "0", summary .. "\n" .. table.concat(lines, "\n"))
  assert(#host.sends == 0, "scenarios must never reach the real send()")
  assert(host.commands.lotjdev, "lotjdev command must be registered")
  print("PASS: DEV plugin runs " .. passed .. " scenarios without touching the MUD")

  local again = host.commands.lotjdev(" radar ")
  assert(again:find("^LOTJDEV SUMMARY passed=%d+ failed=0"), again)
  local filtered = tonumber(again:match("passed=(%d+)"))
  assert(filtered > 0 and filtered < tonumber(passed), "a name filter runs a subset")
  print("PASS: lotjdev <filter> reruns matching scenarios")
end

do -- a failing scenario is reported, the run continues, and state is reset
  local host = fake_host.new()
  load_env("dev/main.lua", host.env)()
  host.env.init()
  local harness = host.env.LotjDev
  local results = harness.run({
    { name = "boom", run = function(t) t.send("x"); t.check(false, "expected failure") end },
    { name = "crash", run = function() error("bad scenario") end },
    { name = "ok", run = function(t) t.check(#t.sends() == 0, "sends reset between scenarios") end },
  })
  assert(results.passed == 1 and results.failed == 2, "two failures, one pass")
  local lines = output(host)
  assert(find(lines, "^LOTJDEV FAIL boom: expected failure$"))
  assert(find(lines, "^LOTJDEV FAIL crash: .*bad scenario"))
  assert(find(lines, "^LOTJDEV PASS ok$"))
  print("PASS: failures are reported per scenario in a machine-readable form")
end

do -- the scenario index lists every scenario file, so none is skipped in the client
  local index = dofile("dev/scenarios/index.lua")
  local listed = {}
  for _, path in ipairs(index) do listed[path] = true end
  local pipe = assert(io.popen("git ls-files --cached --others --exclude-standard -- dev/scenarios"))
  local count = 0
  for path in pipe:lines() do
    if path ~= "dev/scenarios/index.lua" then
      assert(listed[path], path .. " is missing from dev/scenarios/index.lua")
      count = count + 1
    end
  end
  pipe:close()
  assert(count == #index, "index lists a file that does not exist")
  print("PASS: dev/scenarios/index.lua lists all " .. count .. " scenarios")
end
