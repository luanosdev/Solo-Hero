local BaseWeapon = require("src.items.weapons.base_weapon")

---@class GenericConeSlash : BaseWeapon
local GenericConeSlash = setmetatable({}, { __index = BaseWeapon })
GenericConeSlash.__index = GenericConeSlash -- Herança

--- Cria uma nova instância da Espada de Ferro.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return GenericConeSlash
function GenericConeSlash:new(config)
    ---@class GenericConeSlash : BaseWeapon
    local o = BaseWeapon.new(self, config)
    Logger.debug("[GenericConeSlash:new]", string.format(" Instance created, inheriting from BaseWeapon. Name: %s",
        o.name or o.itemBaseId))

    -- Define propriedades específicas ou padrão para WoodenSword, como cores.
    -- Se as cores estiverem nos dados base, podem ser lidas lá.
    o.previewColor = { 0.5, 0.3, 0.1, 0.2 }
    o.attackColor = { 0.3, 0.2, 0.1, 0.6 }
    Logger.debug("[GenericConeSlash:new]", "  - Default preview/attack colors set.")

    return o
end

--- Equipa a Espada de Madeira.
--- Cria a instância da lógica de ataque ConeSlash.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function GenericConeSlash:equip(playerManager, itemData)
    -- Chama o método :equip da classe base primeiro
    BaseWeapon.equip(self, playerManager, itemData)
    Logger.debug("[GenericConeSlash:equip]",
        string.format(" Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    -- 1. Obter dados base da arma
    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("[GenericConeSlash:equip] - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[GenericConeSlash:equip]", "  - Base data retrieved successfully.")

    -- 2. Verificar e carregar a classe de ataque definida nos dados base
    if not baseData.attackClass then
        error(string.format("[GenericConeSlash:equip] - 'attackClass' não definido nos dados base para %s",
            self.itemBaseId))
        return
    end
    Logger.debug("[GenericConeSlash:equip]",
        string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.abilities.player.attacks.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("[GenericConeSlash:equip] - Falha ao carregar AttackClass '%s'. Erro: %s",
            baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    Logger.debug("[GenericConeSlash:equip]", "  - AttackClass loaded successfully.")

    -- 3. Criar a instância da classe de ataque (ConeSlash)
    -- Passa o PlayerManager e a própria instância da arma (self)
    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("GenericConeSlash:equip - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    Logger.debug("[GenericConeSlash:equip]",
        string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    -- 4. REMOVIDO: Aplicação de stats ao PlayerState.

    Logger.debug("[GenericConeSlash:equip]",
        string.format(" '%s' fully equipped. Attack instance created.", self.name or self
            .itemBaseId))
end

--- Desequipa a Espada de Madeira.
function GenericConeSlash:unequip()
    Logger.debug("[GenericConeSlash:unequip]", string.format(" Unequipping '%s'.", self.name or self.itemBaseId))

    -- REMOVIDO: Remoção de stats do PlayerState.

    -- Chama o método :unequip da classe base
    BaseWeapon.unequip(self)

    Logger.debug("[GenericConeSlash:unequip]", string.format(" '%s' fully unequipped.", self.name or self.itemBaseId))
end

return GenericConeSlash
