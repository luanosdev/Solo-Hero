local BaseWeapon = require("src.items.weapons.base_weapon")

---@class Hammer : BaseWeapon
local Hammer = setmetatable({}, { __index = BaseWeapon })
Hammer.__index = Hammer -- Herança

--- Cria uma nova instância do Martelo de Guerra.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return Hammer
function Hammer:new(config)
    -- Chama o construtor da classe base
    local o = BaseWeapon.new(self, config)
    print(string.format("[Hammer:new] Instance created, inheriting from BaseWeapon. Name: %s", o.name or o.itemBaseId))

    -- Define propriedades específicas ou padrão para Hammer, como cores.
    o.previewColor = { 0.6, 0.6, 0.6, 0.2 } -- Cinza semi-transparente
    o.attackColor = { 0.8, 0.8, 0.7, 0.8 }  -- Cinza-claro quase opaco
    print("  - Default preview/attack colors set.")

    return o
end

--- Equipa o Martelo de Guerra.
--- Cria a instância da lógica de ataque CircularSmash.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function Hammer:equip(playerManager, itemData)
    -- Chama o método :equip da classe base primeiro
    BaseWeapon.equip(self, playerManager, itemData)
    print(string.format("[Hammer:equip] Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    -- 1. Obter dados base da arma
    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("Hammer:equip - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    print("  - Base data retrieved successfully.")

    -- 2. Verificar e carregar a classe de ataque definida nos dados base
    if not baseData.attackClass then
        error(string.format("Hammer:equip - 'attackClass' não definido nos dados base para %s", self.itemBaseId))
        return
    end
    print(string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.abilities.player.attacks.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("[Hammer:equip] - Falha ao carregar AttackClass '%s'. Erro: %s", baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    print("  - AttackClass loaded successfully.")

    -- 3. Criar a instância da classe de ataque (CircularSmash)
    -- Passa o PlayerManager e a própria instância da arma (self)
    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("Hammer:equip - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    print(string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    print(string.format("[Hammer:equip] '%s' fully equipped. Attack instance created.", self.name or self.itemBaseId))
end

--- Desequipa o Martelo de Guerra.
function Hammer:unequip()
    print(string.format("[Hammer:unequip] Unequipping '%s'.", self.name or self.itemBaseId))

    -- Chama o método :unequip da classe base
    BaseWeapon.unequip(self)

    print(string.format("[Hammer:unequip] '%s' fully unequipped.", self.name or self.itemBaseId))
end

return Hammer
