-- Standalone Lua smoke for the two HTML widget modules. Host APIs are stubs;
-- this does not run MudForge, the plugin entry point, or the embedded JS.
assert(_VERSION == "Lua 5.4", "run the scaffold smoke with Lua 5.4")

local function load_widget(name, env)
  return assert(loadfile("src/widgets/" .. name .. ".lua", "t", setmetatable(env, { __index = _G })))()
end

local function expect_html(widget, property, html)
  assert(property == "content", widget .. ": expected initial content")
  assert(type(html) == "string" and html:match("^%s*<!DOCTYPE html>")
    and html:find("</html>", 1, true), widget .. ": expected an HTML document")
end

do
  local writes = 0
  local widget = load_widget("lotj-status-bar", {
    setWidgetProperty = function(id, property, html)
      assert(id == "status-test-id", "status bar wrote to the wrong widget")
      expect_html(id, property, html)
      writes = writes + 1
    end,
  })
  widget.init("status-test-id")
  assert(writes == 1, "status bar must set HTML content once on init")
  print("PASS: status bar initializes its HTML content")
end

do
  local writes, focus_calls = 0, 0
  local on_message, sent_message
  local message_count = 0
  local widget = load_widget("lotj-comms-hub", {
    setWidgetProperty = function(id, property, html)
      assert(id == "comms-test-id", "comms hub wrote to the wrong widget")
      assert(on_message, "the HTML receiver must be connected before the iframe loads")
      expect_html(id, property, html)
      writes = writes + 1
    end,
    registerWidgetEvent = function(id, event, callback)
      assert(id == "comms-test-id" and event == "luamsg", "wrong comms event registration")
      assert(not on_message and type(callback) == "function", "expected one comms message handler")
      on_message = callback
    end,
    sendWidgetMessage = function(id, message)
      assert(id == "comms-test-id", "comms hub sent to the wrong widget")
      sent_message = message
      message_count = message_count + 1
    end,
    focusPrompt = function()
      focus_calls = focus_calls + 1
    end,
  })
  widget.init("comms-test-id")
  assert(writes == 1 and on_message, "comms hub must set content and register a handler on init")

  local chat = { channel = "local", sender = "Pilot", text = "Hello" }
  widget.handleChatMessage(chat)
  assert(message_count == 0, "chat must wait for the HTML bridge")
  widget.resetHistory()
  widget.handleChatMessage(chat)
  on_message({ event = "ready" })
  on_message({ event = "ready" })
  assert(message_count == 1 and sent_message.msg == chat, "ready must flush pending chat once")
  assert(writes == 1 and focus_calls == 0, "ready must not reset content or refocus the prompt")
  on_message({ event = "tabClick", tab = "local" })
  assert(focus_calls == 1, "a tab click must request prompt focus")

  widget.handleChatMessage(chat)
  assert(sent_message and sent_message.event == "chatMessage" and sent_message.msg == chat,
    "comms hub must forward the chat payload")
  widget.resetHistory()
  assert(sent_message.event == "chatReset", "a fresh connection must reset visible history")
  print("PASS: comms hub initializes HTML, handles tab focus requests, and forwards chat")
end
