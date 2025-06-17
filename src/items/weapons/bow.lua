local BaseWeapon = require("src.items.weapons.base_weapon")

---@class Bow : BaseWeapon
local Bow = setmetatable({}, { __index = BaseWeapon })
Bow.__index = Bow -- Herança

--- Cria uma nova instância do Arco.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return Bow
function Bow:new(config)
    local o = BaseWeapon.new(self, config)
    print(string.format("[Bow:new] Instance created, inheriting from BaseWeapon. Name: %s", o.name or o.itemBaseId))

    -- Define propriedades VISUAIS específicas ou padrão para Bow.
    -- Stats como angle e projectiles vêm de weapons.lua
    o.previewColor = { 0.2, 0.8, 0.2, 0.2 } -- Verde semi-transparente
    o.attackColor = { 0.2, 0.8, 0.2, 0.7 }  -- Verde mais opaco

    -- REMOVIDO: attackType não é mais definido aqui
    -- REMOVIDO: angle e baseProjectiles vêm dos dados base agora

    return o
end

--- Equipa o Arco.
--- O método :equip da BaseWeapon cuidará da criação da attackInstance.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function Bow:equip(playerManager, itemData)
    BaseWeapon.equip(self, playerManager, itemData)
    -- A lógica de carregar AttackClass e criar a instância foi movida para BaseWeapon:equip.
end

--- Desequipa o Arco.
function Bow:unequip()
    print(string.format("[Bow:unequip] Unequipping '%s'.", self.name or self.itemBaseId))
    BaseWeapon.unequip(self)
    print(string.format("[Bow:unequip] '%s' fully unequipped.", self.name or self.itemBaseId))
end

return Bow
