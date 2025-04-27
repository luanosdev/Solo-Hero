local BaseItem = require("src.items.base_item")
local ManagerRegistry = require("src.managers.manager_registry")

local BaseWeapon = BaseItem:new({
    type = "weapon",
    attackType = nil, -- Será definido por cada arma específica
    equipped = false
})

function BaseWeapon:new(overrides)
    local o = BaseItem:new({})
    setmetatable(o, self)
    self.__index = self

    -- Garante que o tipo seja weapon
    o.type = "weapon"

    -- Verifica se itemBaseId foi fornecido nos overrides
    if not overrides or not overrides.itemBaseId then
        error("BaseWeapon:new - itemBaseId é obrigatório nos overrides.")
        return nil
    end
    o.itemBaseId = overrides.itemBaseId

    -- Busca dados base do ItemDataManager
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        error("BaseWeapon:new - ItemDataManager não encontrado no ManagerRegistry.")
        return nil
    end
    local baseData = itemDataManager:getBaseItemData(o.itemBaseId)
    if not baseData then
        error("BaseWeapon:new - Dados base não encontrados para itemBaseId: " .. o.itemBaseId)
        return nil
    end

    -- Atribui dados base ao objeto 'o'
    for key, value in pairs(baseData) do
        o[key] = value -- Copia todos os dados base (name, description, rarity, damage, range, etc.)
    end

    -- Aplica quaisquer outros overrides específicos que não sejam dados base
    -- (Ex: attackType, previewColor, etc., que vêm da definição da arma como 'bow.lua')
    for key, value in pairs(overrides) do
        if key ~= "itemBaseId" then -- Evita sobrescrever o itemBaseId
            o[key] = value
        end
    end

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
        attackInstance.baseProjectiles = self.baseProjectiles -- Passa o número de projéteis

        print("Propriedades do ataque:")
        print("- Dano:", attackInstance.damage)
        print("- Cooldown:", attackInstance.cooldown)
        print("- Alcance:", attackInstance.range)
        print("- Cor de preview:", attackInstance.previewColor)
        print("- Cor de ataque:", attackInstance.attackColor)
        print("- Projéteis base:", attackInstance.baseProjectiles)

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
