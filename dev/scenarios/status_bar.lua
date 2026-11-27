-- HUD-01: vitals, opponent and comlink GMCP reach the status bar.
return { name = "status bar: vitals, opponent and comlink", run = function(t)
  t.gmcp("Char.Vitals", { hp = 10, maxHp = 20, move = 5, maxMove = 9, mana = 7, maxMana = 8 })
  local vitals = t.last("lotj-status-bar", "vitals")
  t.check(vitals, "no vitals message")
  t.eq(vitals.values.hp, 10, "hp")
  t.eq(vitals.values.force, 7, "force uses mana")
  t.gmcp("Char.Enemy", { name = "&Ra &Wstormtrooper", percent = 42 })
  local enemy = t.last("lotj-status-bar", "enemyInfo").enemy
  t.eq(enemy.name, "a stormtrooper", "colour codes stripped")
  t.eq(enemy.percent, 42, "enemy percent")
  t.gmcp("Char.Chat", { commChannel = "1234" })
  t.eq(t.last("lotj-status-bar", "comlink").channel.name, "1234", "comlink channel")
  t.eq(#t.sends(), 0, "GMCP is passive")
end }
