local BaseEnemy = require("src.classes.enemies.base_enemy")

local TankEnemy = setmetatable({}, { __index = BaseEnemy })

TankEnemy.radius = 12
TankEnemy.speed = 40
TankEnemy.maxHealth = 150
TankEnemy.damage = 15
TankEnemy.damageCooldown = 1.5
TankEnemy.color = {0.5, 0.5, 0.5} -- Cinza
TankEnemy.name = "TankEnemy"
TankEnemy.experienceValue = 25 -- Mais experiência por ter mais vida e ser mais difícil de matar

function TankEnemy:new(x, y)
    local enemy = BaseEnemy.new(self, x, y)
    return setmetatable(enemy, { __index = self })
end

return TankEnemy 