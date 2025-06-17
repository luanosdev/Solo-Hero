local BaseWeapon = require("src.entities.equipments.weapons.base_weapon")

---@class GenericFlameStream : BaseWeapon
local GenericFlameStream = setmetatable({}, { __index = BaseWeapon })
GenericFlameStream.__index = GenericFlameStream -- Herança

--- Cria uma nova instância do Lança-Chamas.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return GenericFlameStream
function GenericFlameStream:new(config)
    ---@class GenericFlameStream : BaseWeapon
    local o = BaseWeapon.new(self, config)
    Logger.debug("[GenericFlameStream:new]", string.format(" Instance created, inheriting from BaseWeapon. Name: %s",
        o.name or o.itemBaseId))

    -- Define propriedades específicas ou padrão para Flamethrower, como cores.
    o.previewColor = { 1, 0.5, 0, 0.2 } -- Laranja semi-transparente
    o.attackColor = { 1, 0.3, 0, 0.7 }  -- Laranja/Vermelho mais opaco

    -- REMOVIDO: attackType não é mais definido aqui
    -- o.attackType = FlameStream

    return o
end

--- Equipa o Lança-Chamas.
--- Cria a instância da lógica de ataque FlameStream.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function GenericFlameStream:equip(playerManager, itemData)
    -- Chama o método :equip da classe base primeiro
    BaseWeapon.equip(self, playerManager, itemData)
    Logger.debug("[GenericFlameStream:equip]",
        string.format(" Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    -- 1. Obter dados base da arma
    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("[GenericFlameStream:equip] - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[GenericFlameStream:equip]", "  - Base data retrieved successfully.")

    -- 2. Verificar e carregar a classe de ataque definida nos dados base
    if not baseData.attackClass then
        error(string.format("[GenericFlameStream:equip] - 'attackClass' não definido nos dados base para %s",
            self.itemBaseId))
        return
    end

    Logger.debug("[GenericFlameStream:equip]",
        string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.entities.attacks.player.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("[GenericFlameStream:equip] - Falha ao carregar AttackClass '%s'. Erro: %s",
            baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    Logger.debug("[GenericFlameStream:equip]", "  - AttackClass loaded successfully.")

    -- 3. Criar a instância da classe de ataque (FlameStream)
    -- Passa o PlayerManager e a própria instância da arma (self)
    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("[GenericFlameStream:equip] - Falha ao criar instância de AttackClass '%s'.",
            baseData.attackClass))
        return
    end
    Logger.debug("[GenericFlameStream:equip]",
        string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    -- 4. REMOVIDO: Aplicação de stats ao PlayerState.

    Logger.debug("[GenericFlameStream:equip]", string.format(" '%s' fully equipped. Attack instance created.",
        self.name or self.itemBaseId))
end

--- Desequipa o Lança-Chamas.
function GenericFlameStream:unequip()
    Logger.debug("[GenericFlameStream:unequip]", string.format(" Unequipping '%s'.", self.name or self.itemBaseId))

    -- REMOVIDO: Remoção de stats do PlayerState.

    -- Chama o método :unequip da classe base
    BaseWeapon.unequip(self)

    print(string.format("[Flamethrower:unequip] '%s' fully unequipped.", self.name or self.itemBaseId))
end

return GenericFlameStream
