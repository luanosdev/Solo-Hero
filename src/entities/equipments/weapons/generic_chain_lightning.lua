local BaseWeapon = require("src.entities.equipments.weapons.base_weapon")

---@class GenericChainLightning : BaseWeapon
local GenericChainLightning = setmetatable({}, { __index = BaseWeapon })
GenericChainLightning.__index = GenericChainLightning -- Herança

--- Cria uma nova instância do ChainLaser.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return GenericChainLightning
function GenericChainLightning:new(config)
    ---@class GenericChainLightning : BaseWeapon
    local o = BaseWeapon.new(self, config)
    Logger.debug("[GenericChainLightning:new]", string.format(" Instance created, inheriting from BaseWeapon. Name: %s", o.name or o
        .itemBaseId))

    -- Define propriedades VISUAIS específicas ou padrão para ChainLaser.
    o.previewColor = { 0.2, 0.8, 1, 0.2 } -- Azul claro semi-transparente
    o.attackColor = { 0.5, 1, 1, 0.9 }    -- Ciano brilhante quase opaco

    -- REMOVIDO: attackType não é mais definido aqui
    return o
end

--- Equipa o ChainLaser.
--- Cria a instância da lógica de ataque ChainLightning.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function GenericChainLightning:equip(playerManager, itemData)
    BaseWeapon.equip(self, playerManager, itemData)
    Logger.debug("[GenericChainLightning:equip]", string.format(" Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("[GenericChainLightning:equip] - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[GenericChainLightning:equip]", "  - Base data retrieved successfully.")

    if not baseData.attackClass then
        error(string.format("[GenericChainLightning:equip] - 'attackClass' não definido nos dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[GenericChainLightning:equip]", string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.abilities.player.attacks.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("[GenericChainLightning:equip] - Falha ao carregar AttackClass '%s'. Erro: %s", baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    Logger.debug("[GenericChainLightning:equip]", "  - AttackClass loaded successfully.")

    -- Cria a instância da classe de ataque (ChainLightning)
    self.attackInstance = AttackClass:new(playerManager, self) -- Passa playerManager e a instância da arma (self)
    if not self.attackInstance then
        error(string.format("[GenericChainLightning:equip] - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    Logger.debug("[GenericChainLightning:equip]", string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    Logger.debug("[GenericChainLightning:equip]", string.format(" '%s' fully equipped. Attack instance created.", self.name or self.itemBaseId))
end

--- Desequipa o ChainLaser.
function GenericChainLightning:unequip()
    Logger.debug("[GenericChainLightning:unequip]", string.format(" Unequipping '%s'.", self.name or self.itemBaseId))
    BaseWeapon.unequip(self)
    Logger.debug("[GenericChainLightning:unequip]", string.format(" '%s' fully unequipped.", self.name or self.itemBaseId))
end

return GenericChainLightning
