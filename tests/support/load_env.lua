-- Load a Lua file with a custom global environment on Lua 5.1 and 5.4.
-- Returns the compiled chunk; the caller decides when to run it.
return function(path, env)
  if setfenv then
    return setfenv(assert(loadfile(path)), env)
  end
  return assert(loadfile(path, "t", env))
end
