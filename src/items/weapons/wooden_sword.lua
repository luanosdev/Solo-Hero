local BaseWeapon = require("src.items.weapons.base_weapon")

---@class WoodenSword : BaseWeapon
local WoodenSword = setmetatable({}, { __index = BaseWeapon })
WoodenSword.__index = WoodenSword -- Herança

--- Cria uma nova instância da Espada de Madeira.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return WoodenSword
function WoodenSword:new(config)
    -- Chama o construtor da classe base
    local o = BaseWeapon.new(self, config)
    print(string.format("[WoodenSword:new] Instance created, inheriting from BaseWeapon. Name: %s",
        o.name or o.itemBaseId))

    -- Define propriedades específicas ou padrão para WoodenSword, como cores.
    -- Se as cores estiverem nos dados base, podem ser lidas lá.
    o.previewColor = { 0.5, 0.3, 0.1, 0.2 }
    o.attackColor = { 0.3, 0.2, 0.1, 0.6 }
    print("  - Default preview/attack colors set.")

    return o
end

--- Equipa a Espada de Madeira.
--- Cria a instância da lógica de ataque ConeSlash.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function WoodenSword:equip(playerManager, itemData)
    -- Chama o método :equip da classe base primeiro
    BaseWeapon.equip(self, playerManager, itemData)
    print(string.format("[WoodenSword:equip] Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    -- 1. Obter dados base da arma
    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("WoodenSword:equip - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    print("  - Base data retrieved successfully.")

    -- 2. Verificar e carregar a classe de ataque definida nos dados base
    if not baseData.attackClass then
        error(string.format("WoodenSword:equip - 'attackClass' não definido nos dados base para %s", self.itemBaseId))
        return
    end
    print(string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local success, AttackClass = pcall(require, baseData.attackClass)
    if not success or not AttackClass then
        error(string.format("WoodenSword:equip - Falha ao carregar AttackClass '%s'. Erro: %s", baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    print("  - AttackClass loaded successfully.")

    -- 3. Criar a instância da classe de ataque (ConeSlash)
    -- Passa o PlayerManager e a própria instância da arma (self)
    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("WoodenSword:equip - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    print(string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    -- 4. REMOVIDO: Aplicação de stats ao PlayerState.

    print(string.format("[WoodenSword:equip] '%s' fully equipped. Attack instance created.", self.name or self
        .itemBaseId))
end

--- Desequipa a Espada de Madeira.
function WoodenSword:unequip()
    print(string.format("[WoodenSword:unequip] Unequipping '%s'.", self.name or self.itemBaseId))

    -- REMOVIDO: Remoção de stats do PlayerState.

    -- Chama o método :unequip da classe base
    BaseWeapon.unequip(self)

    print(string.format("[WoodenSword:unequip] '%s' fully unequipped.", self.name or self.itemBaseId))
end

return WoodenSword
