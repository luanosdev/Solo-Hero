local BaseWeapon = require("src.entities.equipments.weapons.base_weapon")

---@class ArrowProjectileE001 : BaseWeapon
local GenericArrowProjectile = setmetatable({}, { __index = BaseWeapon })
GenericArrowProjectile.__index = GenericArrowProjectile -- Herança

--- Cria uma nova instância do Arco.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return GenericArrowProjectile
function GenericArrowProjectile:new(config)
    ---@class GenericArrowProjectile : BaseWeapon
    local o = BaseWeapon.new(self, config)
    Logger.debug("[GenericArrowProjectile:new]",
        string.format(" Instance created, inheriting from BaseWeapon. Name: %s", o.name or o.itemBaseId))

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
function GenericArrowProjectile:equip(playerManager, itemData)
    BaseWeapon.equip(self, playerManager, itemData)
    -- A lógica de carregar AttackClass e criar a instância foi movida para BaseWeapon:equip.
    -- Esta função pode ser usada no futuro para lógicas de equip específicas deste item,
    -- se necessário.
end

--- Desequipa o Arco.
function GenericArrowProjectile:unequip()
    Logger.debug("[ArrowProjectileE001:unequip]", string.format(" Unequipping '%s'.", self.name or self.itemBaseId))
    BaseWeapon.unequip(self)
    Logger.debug("[ArrowProjectileE001:unequip]", string.format(" '%s' fully unequipped.", self.name or self.itemBaseId))
end

return GenericArrowProjectile
