local BaseWeapon = require("src.items.weapons.base_weapon")

---@class Flamethrower : BaseWeapon
local Flamethrower = setmetatable({}, { __index = BaseWeapon })
Flamethrower.__index = Flamethrower -- Herança

--- Cria uma nova instância do Lança-Chamas.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return Flamethrower
function Flamethrower:new(config)
    -- Chama o construtor da classe base
    local o = BaseWeapon.new(self, config)
    print(string.format("[Flamethrower:new] Instance created, inheriting from BaseWeapon. Name: %s",
        o.name or o.itemBaseId))

    -- Define propriedades específicas ou padrão para Flamethrower, como cores.
    o.previewColor = { 1, 0.5, 0, 0.2 } -- Laranja semi-transparente
    o.attackColor = { 1, 0.3, 0, 0.7 }  -- Laranja/Vermelho mais opaco
    print("  - Default preview/attack colors set.")

    -- REMOVIDO: attackType não é mais definido aqui
    -- o.attackType = FlameStream

    return o
end

--- Equipa o Lança-Chamas.
--- Cria a instância da lógica de ataque FlameStream.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function Flamethrower:equip(playerManager, itemData)
    -- Chama o método :equip da classe base primeiro
    BaseWeapon.equip(self, playerManager, itemData)
    print(string.format("[Flamethrower:equip] Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    -- 1. Obter dados base da arma
    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("Flamethrower:equip - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    print("  - Base data retrieved successfully.")

    -- 2. Verificar e carregar a classe de ataque definida nos dados base
    if not baseData.attackClass then
        error(string.format("Flamethrower:equip - 'attackClass' não definido nos dados base para %s", self.itemBaseId))
        return
    end
    print(string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local success, AttackClass = pcall(require, baseData.attackClass)
    if not success or not AttackClass then
        error(string.format("Flamethrower:equip - Falha ao carregar AttackClass '%s'. Erro: %s", baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    print("  - AttackClass loaded successfully.")

    -- 3. Criar a instância da classe de ataque (FlameStream)
    -- Passa o PlayerManager e a própria instância da arma (self)
    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("Flamethrower:equip - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    print(string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    -- 4. REMOVIDO: Aplicação de stats ao PlayerState.

    print(string.format("[Flamethrower:equip] '%s' fully equipped. Attack instance created.",
        self.name or self.itemBaseId))
end

--- Desequipa o Lança-Chamas.
function Flamethrower:unequip()
    print(string.format("[Flamethrower:unequip] Unequipping '%s'.", self.name or self.itemBaseId))

    -- REMOVIDO: Remoção de stats do PlayerState.

    -- Chama o método :unequip da classe base
    BaseWeapon.unequip(self)

    print(string.format("[Flamethrower:unequip] '%s' fully unequipped.", self.name or self.itemBaseId))
end

return Flamethrower
