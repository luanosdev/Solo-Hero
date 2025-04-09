local BaseEnemy = require("src.classes.enemies.base_enemy")
local CommonEnemy = require("src.classes.enemies.common_enemy")

local SplitterEnemy = setmetatable({}, { __index = BaseEnemy })

SplitterEnemy.name = "Splitter Enemy"
SplitterEnemy.radius = 12
SplitterEnemy.speed = 45
SplitterEnemy.maxHealth = 80
SplitterEnemy.damage = 12
SplitterEnemy.color = {0.2, 0.8, 0.2} -- Verde
SplitterEnemy.experienceValue = 20 -- Mais experiência por ser mais difícil de matar

-- Configurações dos inimigos menores
SplitterEnemy.minSplitCount = 2
SplitterEnemy.maxSplitCount = 3
SplitterEnemy.splitRadius = 30 -- Distância que os inimigos menores spawnam do original

function SplitterEnemy:new(x, y)
    local enemy = BaseEnemy.new(self, x, y)
    setmetatable(enemy, { __index = self })
    return enemy
end

function SplitterEnemy:takeDamage(damage, isCritical)
    -- Aplica o dano normalmente
    local died = BaseEnemy.takeDamage(self, damage, isCritical)
    
    -- Se morreu, spawna os inimigos menores
    if died then
        self:splitIntoSmallerEnemies()
    end
    
    return died
end

function SplitterEnemy:splitIntoSmallerEnemies()
    -- Determina quantos inimigos menores spawnar
    local splitCount = math.random(self.minSplitCount, self.maxSplitCount)
    
    -- Para cada inimigo menor
    for i = 1, splitCount do
        -- Calcula um ângulo para spawnar o inimigo menor
        local angle = (i / splitCount) * math.pi * 2 + math.random() * 0.2 -- Adiciona um pouco de aleatoriedade
        
        -- Calcula a posição do inimigo menor
        local spawnX = self.positionX + math.cos(angle) * self.splitRadius
        local spawnY = self.positionY + math.sin(angle) * self.splitRadius
        
        -- Cria o inimigo menor
        local smallEnemy = CommonEnemy:new(spawnX, spawnY)
        
        -- Ajusta os atributos do inimigo menor
        smallEnemy.radius = self.radius * 0.6
        smallEnemy.speed = self.speed * 1.2
        smallEnemy.maxHealth = self.maxHealth * 0.4
        smallEnemy.currentHealth = smallEnemy.maxHealth
        smallEnemy.damage = self.damage * 0.5
        smallEnemy.color = {0.4, 0.9, 0.4} -- Verde mais claro
        smallEnemy.experienceValue = self.experienceValue * 0.3
        
        -- Adiciona o inimigo menor à lista de inimigos
        local EnemyManager = require("src.managers.enemy_manager")
        table.insert(EnemyManager.enemies, smallEnemy)
    end
end

return SplitterEnemy 