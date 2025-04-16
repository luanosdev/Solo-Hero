local BaseItem = require("src.items.base_item")

local BaseWeapon = BaseItem:new({
    type = "weapon",
    damage = 0,
    cooldown = 1.0, -- Cooldown base da arma em segundos
    range = 1.0,
    attackType = nil, -- Será definido por cada arma específica
    equipped = false
})

function BaseWeapon:new(overrides)
    local o = BaseItem:new(overrides)
    setmetatable(o, self)
    self.__index = self
    
    -- Garante que o tipo seja weapon
    o.type = "weapon"
    
    return o
end

-- Método para equipar a arma
function BaseWeapon:equip(owner)
    print("Equipando arma:", self.name)
    
    self.equipped = true
    self.owner = owner
    
    if self.attackType then
        print("Criando instância do ataque")
        -- Cria uma nova instância do attackType com as propriedades da arma
        local attackInstance = setmetatable({}, { __index = self.attackType })
        
        -- Copia as propriedades da arma para o ataque
        attackInstance.damage = self.damage
        attackInstance.cooldown = self.cooldown
        attackInstance.range = self.range
        attackInstance.previewColor = self.previewColor
        attackInstance.attackColor = self.attackColor
        
        print("Propriedades do ataque:")
        print("- Dano:", attackInstance.damage)
        print("- Cooldown:", attackInstance.cooldown)
        print("- Alcance:", attackInstance.range)
        print("- Cor de preview:", attackInstance.previewColor)
        print("- Cor de ataque:", attackInstance.attackColor)
        
        -- Inicializa o ataque com o dono
        attackInstance:init(owner)
        
        -- Armazena a instância do ataque
        self.attackInstance = attackInstance
        print("Instância do ataque criada com sucesso")
    else
        print("Nenhum tipo de ataque definido!")
    end
end

-- Método para desequipar a arma
function BaseWeapon:unequip()
    self.equipped = false
    self.owner = nil
    self.attackInstance = nil
end

-- Método para obter a instância do ataque
function BaseWeapon:getAttackInstance()
    return self.attackInstance
end

return BaseWeapon 