-- Datapad commands (DATA-01): turns one datapad action into the exact
-- `datamem` / `datastat` command from the game's help (HELP DATAMEM).
-- Pure: no host calls. A bad slot or empty text returns nil plus the field.

local MAX_SLOT = 999

local function slot(value)
  local number = tonumber(value)
  if number and number >= 1 and number <= MAX_SLOT and number == math.floor(number) then
    return string.format("%d", number)
  end
end

-- Free text is one game argument: control characters become spaces, and ";"
-- becomes "," because MudForge's send() stacks commands on ";".
local function text(value)
  if type(value) ~= "string" then return nil end
  value = value:gsub("%c", " "):gsub(";", ","):gsub("^%s+", ""):gsub("%s+$", "")
  if value ~= "" then return value end
end

local ON_SLOT = { view = true, send = true, eject = true, delete = true, download = true, write = true }
local FIELDS = { subject = true, to = true, from = true }
local FIXED = {
  new = "datamem write new",
  receive = "datamem receive",
  setbiometrics = "datamem setbiometrics",
  datastat = "datastat",
}

-- Actions that destroy or give away a file ask once before sending.
local CONFIRM = { delete = true, eject = true }

local function command(action, args)
  args = type(args) == "table" and args or {}
  if FIXED[action] then return FIXED[action] end
  if action == "load" then
    local keyword = text(args.keyword)
    if not keyword then return nil, "keyword" end
    return "datamem load " .. keyword
  end
  if not (ON_SLOT[action] or FIELDS[action] or action == "copy" or action == "show") then
    return nil, "action"
  end
  local number = slot(args.slot)
  if not number then return nil, "slot" end
  if ON_SLOT[action] then return "datamem " .. action .. " " .. number end
  if FIELDS[action] then
    local value = text(args.text)
    if not value then return nil, action end
    return "datamem write " .. number .. " " .. action .. " " .. value
  end
  if action == "copy" then
    if args.amount == nil or args.amount == "" then return "datamem copy " .. number end
    local amount = slot(args.amount)
    if not amount then return nil, "amount" end
    return "datamem copy " .. number .. " " .. amount
  end
  local target = text(args.target)
  if not target then return nil, "target" end
  return "datamem show " .. number .. " " .. target
end

local function needsConfirm(action)
  return CONFIRM[action] == true
end

return { command = command, needsConfirm = needsConfirm, slot = slot }
