local BaseWeapon = require("src.items.weapons.base_weapon")

---@class GenericAlternativeConeStrike : BaseWeapon
local GenericAlternativeConeStrike = setmetatable({}, { __index = BaseWeapon })
GenericAlternativeConeStrike.__index = GenericAlternativeConeStrike -- Herança

--- Cria uma nova instância das Adagas Duplas.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return GenericAlternativeConeStrike
function GenericAlternativeConeStrike:new(config)
    ---@class GenericAlternativeConeStrike : BaseWeapon
    local o = BaseWeapon.new(self, config)
    Logger.debug("[GenericAlternativeConeStrike:new]", string.format(" Instance created, inheriting from BaseWeapon. Name: %s",
        o.name or o.itemBaseId))
    o.previewColor = { 0.8, 0.1, 0.8, 0.2 }
    o.attackColor = { 0.8, 0.1, 0.8, 0.7 }
    Logger.debug("[GenericAlternativeConeStrike:new]", "  - Default preview/attack colors set.")
    return o
end

--- Equipa as Adagas Duplas.
--- Cria a instância da lógica de ataque. A aplicação de stats agora é feita
--- pela lógica de ataque buscando os valores dinamicamente.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function GenericAlternativeConeStrike:equip(playerManager, itemData)
    BaseWeapon.equip(self, playerManager, itemData)
    Logger.debug("[GenericAlternativeConeStrike:equip]",
        string.format(" Equipping '%s'. Calling base equip done.", self.name or self
            .itemBaseId))

    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("[GenericAlternativeConeStrike:equip] - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[GenericAlternativeConeStrike:equip]", "  - Base data retrieved successfully.")

    if not baseData.attackClass then
        error(string.format("[GenericAlternativeConeStrike:equip] - 'attackClass' não definido nos dados base para %s",
            self.itemBaseId))
        return
    end
    Logger.debug("[GenericAlternativeConeStrike:equip]",
        string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.abilities.player.attacks.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("[GenericAlternativeConeStrike:equip] - Falha ao carregar AttackClass '%s'. Erro: %s",
            baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    Logger.debug("[GenericAlternativeConeStrike:equip]", "  - AttackClass loaded successfully.")

    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("[" .. self.name .. ":equip] - Falha ao criar instância de AttackClass '%s'.",
            baseData.attackClass))
        return
    end
    Logger.debug("[GenericAlternativeConeStrike:equip]",
        string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    Logger.debug("[GenericAlternativeConeStrike:equip]",
        string.format(" '%s' fully equipped. Attack instance created.", self.name or self
            .itemBaseId))
end

--- Desequipa as Adagas Duplas.
--- Remove a instância de ataque. A remoção de stats não é mais necessária aqui.
function GenericAlternativeConeStrike:unequip()
    Logger.debug("[GenericAlternativeConeStrike:unequip]", string.format(" Unequipping '%s'.", self.name or self.itemBaseId))

    BaseWeapon.unequip(self)

    Logger.debug("[GenericAlternativeConeStrike:unequip]", string.format(" '%s' fully unequipped.", self.name or self.itemBaseId))
end

return GenericAlternativeConeStrike
