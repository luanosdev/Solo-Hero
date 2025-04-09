local BaseEnemy = require("src.classes.enemies.base_enemy")
local PuddleManager = require("src.managers.puddle_manager") -- Precisa referenciar o manager

local PuddleEnemy = setmetatable({}, { __index = BaseEnemy })

PuddleEnemy.name = "Puddle Enemy"
PuddleEnemy.radius = 10
PuddleEnemy.speed = 50
PuddleEnemy.maxHealth = 60
PuddleEnemy.damage = 12 -- Dano de contato (se houver)
PuddleEnemy.color = {0.1, 0.6, 0.1} -- Verde escuro
PuddleEnemy.experienceValue = 18

-- Configurações da poça deixada ao morrer
PuddleEnemy.puddleRadius = 30
PuddleEnemy.puddleDuration = 7
PuddleEnemy.puddleDamagePerSecond = 4

function PuddleEnemy:new(x, y)
    local enemy = BaseEnemy.new(self, x, y)
    -- Sobrescreve a metatable para usar o __index desta classe
    return setmetatable(enemy, { __index = self }) 
end

-- Sobrescreve a função takeDamage da classe BaseEnemy
function PuddleEnemy:takeDamage(damage, isCritical)
    -- Chama a função original de BaseEnemy para aplicar dano, mostrar texto, etc.
    -- e pega o resultado (true se morreu, false caso contrário)
    local died = BaseEnemy.takeDamage(self, damage, isCritical)

    -- Se o inimigo morreu como resultado deste dano
    if died then
        print(string.format("%s morreu, criando poça de dano!", self.name))
        -- Chama o PuddleManager para criar a poça na posição atual do inimigo
        PuddleManager:addPuddle(
            self.positionX, 
            self.positionY,
            self.puddleRadius,
            self.puddleDuration,
            self.puddleDamagePerSecond
        )
    end

    -- Retorna o mesmo resultado da função base (se morreu ou não)
    return died
end

-- Reutiliza update e draw da base, a menos que queira comportamento específico
-- function PuddleEnemy:update(dt, player, enemies)
--    BaseEnemy.update(self, dt, player, enemies)
-- end

-- function PuddleEnemy:draw()
--    BaseEnemy.draw(self)
-- end

return PuddleEnemy
