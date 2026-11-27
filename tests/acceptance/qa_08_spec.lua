-- QA-08: every acceptance spec is either real or a pending() call whose card id
-- matches its file name, so the pending count reflects the roadmap.
local pipe = assert(io.popen("git ls-files --cached --others --exclude-standard -- tests/acceptance"))
local checked = 0
for path in pipe:lines() do
  local name = path:match("([%w_]+)_spec%.lua$")
  if name and name ~= "qa_08" then
    local file = assert(io.open(path))
    local text = file:read("*a")
    file:close()
    local card = text:match('pending%("([%u]+%-%d+)"')
    if card then
      assert((card:lower():gsub("%-", "_")) == name, path .. " declares " .. card)
      assert(text:find('dofile%("tests/support/pending%.lua"%)'), path .. " must use the shared pending helper")
    end
    checked = checked + 1
  end
end
pipe:close()
assert(checked > 0, "no acceptance specs found")
print(("PASS: %d acceptance specs name their own roadmap card"):format(checked))
