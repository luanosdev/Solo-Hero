local BaseWeapon = require("src.items.weapons.base_weapon")

---@class DualDaggers : BaseWeapon
local DualDaggers = setmetatable({}, { __index = BaseWeapon })
DualDaggers.__index = DualDaggers -- Herança

--- Cria uma nova instância das Adagas Duplas.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return DualDaggers
function DualDaggers:new(config)
    local o = BaseWeapon.new(self, config)
    print(string.format("[DualDaggers:new] Instance created, inheriting from BaseWeapon. Name: %s",
        o.name or o.itemBaseId))
    o.previewColor = { 0.8, 0.1, 0.8, 0.2 }
    o.attackColor = { 0.8, 0.1, 0.8, 0.7 }
    print("  - Default preview/attack colors set.")
    return o
end

--- Equipa as Adagas Duplas.
--- Cria a instância da lógica de ataque. A aplicação de stats agora é feita
--- pela lógica de ataque buscando os valores dinamicamente.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function DualDaggers:equip(playerManager, itemData)
    BaseWeapon.equip(self, playerManager, itemData)
    print(string.format("[DualDaggers:equip] Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("DualDaggers:equip - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    print("  - Base data retrieved successfully.")

    if not baseData.attackClass then
        error(string.format("DualDaggers:equip - 'attackClass' não definido nos dados base para %s", self.itemBaseId))
        return
    end
    print(string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.abilities.player.attacks.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("DualDaggers:equip - Falha ao carregar AttackClass '%s'. Erro: %s", baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    print("  - AttackClass loaded successfully.")

    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("DualDaggers:equip - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    print(string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    print(string.format("[DualDaggers:equip] '%s' fully equipped. Attack instance created.", self.name or self
        .itemBaseId))
end

--- Desequipa as Adagas Duplas.
--- Remove a instância de ataque. A remoção de stats não é mais necessária aqui.
function DualDaggers:unequip()
    print(string.format("[DualDaggers:unequip] Unequipping '%s'.", self.name or self.itemBaseId))

    BaseWeapon.unequip(self)

    print(string.format("[DualDaggers:unequip] '%s' fully unequipped.", self.name or self.itemBaseId))
end

return DualDaggers
