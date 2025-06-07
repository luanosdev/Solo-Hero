local BaseWeapon = require("src.items.weapons.base_weapon")

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
--- Cria a instância da lógica de ataque ArrowProjectile.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function GenericArrowProjectile:equip(playerManager, itemData)
    BaseWeapon.equip(self, playerManager, itemData)
    Logger.debug("[GenericArrowProjectile:equip]",
        string.format(" Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("Bow:equip - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[ArrowProjectileE001:equip]", "  - Base data retrieved successfully.")

    if not baseData.attackClass then
        error(string.format("Bow:equip - 'attackClass' não definido nos dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[ArrowProjectileE001:equip]",
        string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.abilities.player.attacks.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("Bow:equip - Falha ao carregar AttackClass '%s'. Erro: %s", baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    Logger.debug("[ArrowProjectileE001:equip]", "  - AttackClass loaded successfully.")

    -- Cria a instância da classe de ataque (ArrowProjectile)
    self.attackInstance = AttackClass:new(playerManager, self) -- Passa playerManager e a instância da arma (self)
    if not self.attackInstance then
        error(string.format("Bow:equip - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    Logger.debug("[ArrowProjectileE001:equip]",
        string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    Logger.debug("[ArrowProjectileE001:equip]",
        string.format(" '%s' fully equipped. Attack instance created.", self.name or self.itemBaseId))
end

--- Desequipa o Arco.
function GenericArrowProjectile:unequip()
    Logger.debug("[ArrowProjectileE001:unequip]", string.format(" Unequipping '%s'.", self.name or self.itemBaseId))
    BaseWeapon.unequip(self)
    Logger.debug("[ArrowProjectileE001:unequip]", string.format(" '%s' fully unequipped.", self.name or self.itemBaseId))
end

return GenericArrowProjectile
