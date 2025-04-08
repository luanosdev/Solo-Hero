local BaseEnemy = require("src.classes.enemies.base_enemy")

local CommonEnemy = setmetatable({}, { __index = BaseEnemy })

CommonEnemy.radius = 8
CommonEnemy.speed = 60 -- Velocidade moderada, segue o jogador
CommonEnemy.maxHealth = 25
CommonEnemy.damage = 8
CommonEnemy.damageCooldown = 1 -- Cooldown padrão
CommonEnemy.color = {0.6, 0.4, 0.2} -- Cor marrom claro (neutra)
CommonEnemy.name = "CommonEnemy"
CommonEnemy.experienceValue = 5 -- Pouca experiência

function CommonEnemy:new(x, y)
    local enemy = BaseEnemy.new(self, x, y)
    return setmetatable(enemy, { __index = self })
end

return CommonEnemy