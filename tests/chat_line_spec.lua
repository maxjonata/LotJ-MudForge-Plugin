-- Synthetic messages based on the community UI's public chat formats.
local chat = dofile("src/domain/chat-line.lua")
local examples = {
  {"You say 'Ready.'", "local", "You", "Ready."},
  {"You exclaim, 'Ready!'", "local", "You", "Ready!"},
  {"A pilot quietly says to you 'It\'s time.'", "local", "A pilot", "It's time."},
  {"'Report in.' you ask, in Basic.", "local", "You", "Report in."},
  {"(OSAY) A pilot says 'Hello.'", "local", "A pilot", "Hello."},
  {"CommNet 42 [Pilot] (Encrypted): Hold position", "commnet", "CommNet 42 · Pilot", "Hold position"},
  {"A comlink buzzes '(Translating channel 42) Clear'", "commnet", "CommNet 42", "Clear"},
  {"Guild{Flight}<Officer>[Pilot] ( calm ): All clear", "clan", "Pilot", "All clear"},
  {"[Incoming Transmission from Deck]", "clan", nil, "[Incoming Transmission from Deck]"},
  {"Broadcasting Network [News]: Bulletin", "broadcast", nil, "Broadcasting Network [News]: Bulletin"},
  {"(OOC) Pilot: Have a good one", "ooc", "Pilot", "Have a good one"},
  {"(OOC) @Pilot [Team]: Have a good one", "ooc", "@Pilot [Team]", "Have a good one"},
  {"(OOC) Pilot tells you (Cadet) 'Ready?'", "tell", "Pilot", "Ready?"},
  {"(OOC) Pilot tells you 'Ready?'", "tell", "Pilot", "Ready?"},
  {"(OOC) You tell Commander 'Ready.'", "tell", "You → Commander", "Ready."},
  {"ImmNet[Moderator]<12>: Advisory", "imm", nil, "ImmNet[Moderator]<12>: Advisory"},
}
for _, example in ipairs(examples) do
  local result = assert(chat.read(example[1]), example[1])
  assert(result.channel == example[2] and result.sender == example[3] and result.text == example[4],
    "wrong channel, sender or message: " .. example[1])
end
for _, line in ipairs({
  "", "A crate says nothing 'sealed'", "North - Main Thoroughfare", "Your Coordinates: 0 0 0",
  "(OOC) inactive", "Debug: unknown packet", "You see a sign reading 'CommNet is offline'",
}) do
  assert(chat.read(line) == nil, "classified a terminal line as chat: " .. line)
end
assert(chat.read(nil) == nil)
print("PASS: LotJ chat lines route to a single channel and terminal noise stays unclassified")
