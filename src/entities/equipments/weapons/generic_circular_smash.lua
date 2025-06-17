local BaseWeapon = require("src.entities.equipments.weapons.base_weapon")

---@class GenericCircularSmash : BaseWeapon
local GenericCircularSmash = setmetatable({}, { __index = BaseWeapon })
GenericCircularSmash.__index = GenericCircularSmash -- Herança

--- Cria uma nova instância do Martelo de Guerra.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return GenericCircularSmash
function GenericCircularSmash:new(config)
    ---@class GenericCircularSmash : BaseWeapon
    local o = BaseWeapon.new(self, config)
    Logger.debug("[GenericCircularSmash:new]", string.format(" Instance created, inheriting from BaseWeapon. Name: %s", o.name or o.itemBaseId))

    -- Define propriedades específicas ou padrão para Hammer, como cores.
    o.previewColor = { 0.6, 0.6, 0.6, 0.2 } -- Cinza semi-transparente
    o.attackColor = { 0.8, 0.8, 0.7, 0.8 }  -- Cinza-claro quase opaco
    Logger.debug("[CircularSmashE001:new]", "  - Default preview/attack colors set.")

    return o
end

--- Equipa o Martelo de Guerra.
--- Cria a instância da lógica de ataque CircularSmash.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function GenericCircularSmash:equip(playerManager, itemData)
    -- Chama o método :equip da classe base primeiro
    BaseWeapon.equip(self, playerManager, itemData)
    Logger.debug("[GenericCircularSmash:equip]", string.format(" Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    -- 1. Obter dados base da arma
    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("GenericCircularSmash:equip - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[GenericCircularSmash:equip]", "  - Base data retrieved successfully.")

    -- 2. Verificar e carregar a classe de ataque definida nos dados base
    if not baseData.attackClass then
        error(string.format("GenericCircularSmash:equip - 'attackClass' não definido nos dados base para %s", self.itemBaseId))
        return
    end
    Logger.debug("[GenericCircularSmash:equip]", string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.abilities.player.attacks.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("GenericCircularSmash:equip - Falha ao carregar AttackClass '%s'. Erro: %s", baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    Logger.debug("[GenericCircularSmash:equip]", "  - AttackClass loaded successfully.")

    -- 3. Criar a instância da classe de ataque (CircularSmash)
    -- Passa o PlayerManager e a própria instância da arma (self)
    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("GenericCircularSmash:equip - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    Logger.debug("[GenericCircularSmash:equip]", string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    Logger.debug("[CircularSmashE001:equip]", string.format(" '%s' fully equipped. Attack instance created.", self.name or self.itemBaseId))
end

--- Desequipa o Martelo de Guerra.
function GenericCircularSmash:unequip()
    Logger.debug("[GenericCircularSmash:unequip]", string.format(" Unequipping '%s'.", self.name or self.itemBaseId))

    -- Chama o método :unequip da classe base
    BaseWeapon.unequip(self)

    print(string.format("[GenericCircularSmash:unequip] '%s' fully unequipped.", self.name or self.itemBaseId))
end

return GenericCircularSmash
