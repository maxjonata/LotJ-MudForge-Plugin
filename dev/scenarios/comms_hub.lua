-- COMMS-01: channel lines reach the Comms Hub once its page is ready.
return { name = "comms hub: CommNet and OOC lines are routed", run = function(t)
  t.post("lotj-comms-hub", "ready")
  t.line("CommNet 1 [Bob]: hello there")
  local message = t.last("lotj-comms-hub", "chatMessage")
  t.check(message, "no chatMessage")
  t.eq(message.msg.channel, "commnet", "channel")
  t.eq(message.msg.text, "hello there", "text")
  t.line("(OOC) Ana: hi all")
  t.eq(t.last("lotj-comms-hub", "chatMessage").msg.channel, "ooc", "ooc channel")
  t.eq(#t.sends(), 0, "routing is passive")
end }
