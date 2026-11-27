-- Message shapes follow the public LotJ Mudlet chat triggers. This parser
-- consumes MudForge's clean line and returns at most one channel per line.
local speech = {
  say = "says", whisper = "whispers", exclaim = "exclaims",
  ask = "asks", yell = "yells", radio = "radios",
}

local function localSpeaker(header)
  for firstPerson, thirdPerson in pairs(speech) do
    local verb, speaker = thirdPerson, nil
    if header:match("^[Yy]ou ") then verb = firstPerson end
    local tail
    speaker, tail = header:match("^(.+) " .. verb .. "(.*)$")
    if speaker and (tail == "" or tail == "," or tail:match("^,? to .+") or
        tail:match("^,? at .+") or tail:match("^, in .+")) then
      speaker = speaker:gsub(" %a+ly$", "")
      if speaker:lower() == "you" then return "You" end
      return (speaker:gsub('^"(.*)"$', "%1"))
    end
  end
end

local function read(line)
  if type(line) ~= "string" or line == "" then return nil end

  local ooc = line:match("^%(OOC%) (.+)$")
  if ooc then
    local sender, message = ooc:match("^(.-) tells you +%b() +'(.+)'$")
    if not sender then sender, message = ooc:match("^(.-) tells you +'(.+)'$") end
    if sender then return { channel = "tell", sender = sender, text = message } end
    local receiver, outgoing = ooc:match("^You tell (.+) '(.+)'$")
    if receiver then return { channel = "tell", sender = "You → " .. receiver, text = outgoing } end

    sender, message = ooc:match("^(%S+ %b[]): (.+)$")
    if not sender then sender, message = ooc:match("^(%S+): (.+)$") end
    if sender then return { channel = "ooc", sender = sender, text = message } end
    return nil
  end

  local network, sender, message = line:match("^(CommNet %d+) %[(.-)%][%(%)%a<> ]*: (.+)$")
  if sender then return { channel = "commnet", sender = network .. " · " .. sender, text = message } end
  network, message = line:match("^.+ buzzes '%(Translating channel (%d+)%) (.+)'$")
  if network then return { channel = "commnet", sender = "CommNet " .. network, text = message } end

  sender, message = line:match("^.-%b{}%b<>%[(.-)%][^:]*: (.+)$")
  if sender then return { channel = "clan", sender = sender, text = message } end
  if line:match("^%[Incoming Transmission from ") or line:match("^%[Outgoing Transmission to ") then
    return { channel = "clan", text = line }
  end
  if line:match("^Broadcasting Network %b[]") then return { channel = "broadcast", text = line } end
  if line:match("^%(IMM%) %S+: .+") or line:match("^%( IMM | CHAT %).+'.+'$") or
      line:match("^ImmNet%b[]: .+") or line:match("^ImmNet%b[]<%d+>: .+") or
      line:match("^CouncilNet%b[]: .+") or line:match("^%(R|P|C%) .+: .+") or
      line:match("^%(R|P|C%) .+ '.+'$") then
    return { channel = "imm", text = line }
  end

  if line:match("^%[Hail from ") or line:match("^%[Broadcasting Hail to ") or
      line:match("^%[INTERCOM:") or line:match("^.+ speaks in your mind '.+'$") or
      line:match("^You speak through your mind '.+'$") or
      line:match("^You sign, in Lorrdian '.+'$") or line:match("^'.+' you sign, in Lorrdian%.$") then
    return { channel = "local", text = line }
  end
  local dialogue = line:gsub("^%(OSAY%) ", "")
  local header
  message, header = dialogue:match("^'(.+)' (.+)%.$")
  if not header then header, message = dialogue:match("^(.-) '(.+)'$") end
  if not header then return nil end

  -- LotJ can insert a tone before the speech verb. Keep the displayed
  -- speech and target in the terminal; the hub shows the speaker and text.
  local speaker = localSpeaker(header)
  if speaker then
    return { channel = "local", sender = speaker, text = message }
  end
  return nil
end

return { read = read }
