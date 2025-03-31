local BaseEnemy = require("src.classes.enemies.base_enemy")

local FastEnemy = setmetatable({}, { __index = BaseEnemy })

FastEnemy.radius = 6
FastEnemy.speed = 120
FastEnemy.maxHealth = 30
FastEnemy.damage = 5
FastEnemy.damageCooldown = 0.5
FastEnemy.color = {1, 0.5, 0} -- Laranja
FastEnemy.name = "FastEnemy"

function FastEnemy:new(x, y)
    local enemy = BaseEnemy.new(self, x, y)
    return setmetatable(enemy, { __index = self })
end

return FastEnemy 