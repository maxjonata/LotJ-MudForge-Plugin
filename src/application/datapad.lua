-- Datapad use case (DATA-01): keeps the selected slot, asks once before a
-- destructive action and sends each command through the injected port.
-- Ports:
--   rules   = src/domain/datapad.lua
--   send(command) -> true when the game received it, false when offline
--   publish(message) -> tells the view what happened ({ event = ... })

local function new(ports)
  local rules, send, publish = ports.rules, ports.send, ports.publish
  local selected = 1
  local armed = nil

  local function select(value)
    local number = rules.slot(value)
    if number then selected = tonumber(number) end
    armed = nil
    publish({ event = "slot", slot = selected })
  end

  local function step(delta)
    select(math.max(1, selected + (tonumber(delta) or 0)))
  end

  local function run(action, args)
    args = type(args) == "table" and args or {}
    if args.slot == nil then args.slot = selected end
    local command, field = rules.command(action, args)
    if not command then
      armed = nil
      publish({ event = "invalid", action = action, field = field })
      return false
    end
    if rules.needsConfirm(action) and armed ~= command then
      armed = command
      publish({ event = "confirm", action = action, command = command })
      return false
    end
    armed = nil
    if not send(command) then
      publish({ event = "offline", command = command })
      return false
    end
    publish({ event = "sent", action = action, command = command })
    return true
  end

  local function cancel()
    armed = nil
  end

  return {
    select = select, step = step, run = run, cancel = cancel,
    slot = function() return selected end,
  }
end

return { new = new }
