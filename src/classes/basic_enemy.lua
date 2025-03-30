local Enemy = require("src.classes.enemy")
local ContactDamage = require("src.abilities.contact_damage")

local BasicEnemy = setmetatable({}, {__index = Enemy})

-- Sobrescreve as propriedades base
BasicEnemy.name = "Basic Enemy"
BasicEnemy.maxHealth = 80
BasicEnemy.speed = 80
BasicEnemy.color = {1, 0.2, 0.2, 1} -- Vermelho mais claro

-- Sobrescreve o método initAbilities
function BasicEnemy:initAbilities()
    -- Inicializa a habilidade de dano ao contato
    local contactDamage = setmetatable({}, {__index = ContactDamage})
    contactDamage:init(self)
    table.insert(self.abilities, contactDamage)
end

-- Sobrescreve o método init para garantir que o inimigo seja inicializado corretamente
function BasicEnemy:init(x, y)
    -- Chama o método init da classe base
    Enemy.init(self, x, y)
    
    -- Inicializa as habilidades específicas do inimigo básico
    self:initAbilities()
end

return BasicEnemy 