-- DATA-01 / UI-02: datapad keys send help syntax; delete asks once.
return { name = "datapad: keys send datamem commands, delete asks first", run = function(t)
  t.post("lotj-datapad", "ready")
  t.eq(t.last("lotj-datapad", "slot").slot, 1, "starts on slot 1")
  t.post("lotj-datapad", "select", { slot = "3" })
  t.post("lotj-datapad", "command", { action = "to", args = { text = "Varn" } })
  t.eq(t.lastSend(), "datamem write 3 to Varn", "TO field")
  t.post("lotj-datapad", "command", { action = "delete", args = {} })
  t.eq(#t.sends(), 1, "delete waits for the second press")
  t.eq(t.last("lotj-datapad", "confirm").command, "datamem delete 3", "confirm shows the command")
  t.post("lotj-datapad", "command", { action = "delete", args = {} })
  t.eq(t.lastSend(), "datamem delete 3", "second press sends")
  t.post("lotj-datapad", "select", { slot = "1" })
end }
