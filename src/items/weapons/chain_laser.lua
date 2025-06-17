local BaseWeapon = require("src.items.weapons.base_weapon")
local ChainLightning = require("src.entities.attacks.player.chain_lightning") -- Criaremos este arquivo

---@class ChainLaser : BaseWeapon
local ChainLaser = setmetatable({}, { __index = BaseWeapon })
ChainLaser.__index = ChainLaser -- Herança

--- Cria uma nova instância do ChainLaser.
---@param config table Tabela de configuração, deve conter 'itemBaseId'.
---@return ChainLaser
function ChainLaser:new(config)
    local o = BaseWeapon.new(self, config)
    print(string.format("[ChainLaser:new] Instance created, inheriting from BaseWeapon. Name: %s", o.name or o
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
function ChainLaser:equip(playerManager, itemData)
    BaseWeapon.equip(self, playerManager, itemData)
    print(string.format("[ChainLaser:equip] Equipping '%s'. Calling base equip done.", self.name or self.itemBaseId))

    local baseData = self:getBaseData()
    if not baseData then
        error(string.format("ChainLaser:equip - Falha ao obter dados base para %s", self.itemBaseId))
        return
    end
    print("  - Base data retrieved successfully.")

    if not baseData.attackClass then
        error(string.format("ChainLaser:equip - 'attackClass' não definido nos dados base para %s", self.itemBaseId))
        return
    end
    print(string.format("  - attackClass found: %s. Attempting to load...", baseData.attackClass))

    local attackClassPath = string.format("src.abilities.player.attacks.%s", baseData.attackClass)
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(string.format("ChainLaser:equip - Falha ao carregar AttackClass '%s'. Erro: %s", baseData.attackClass,
            tostring(AttackClass)))
        return
    end
    print("  - AttackClass loaded successfully.")

    -- Cria a instância da classe de ataque (ChainLightning)
    self.attackInstance = AttackClass:new(playerManager, self) -- Passa playerManager e a instância da arma (self)
    if not self.attackInstance then
        error(string.format("ChainLaser:equip - Falha ao criar instância de AttackClass '%s'.", baseData.attackClass))
        return
    end
    print(string.format("  - Attack instance created (Type: %s).", type(self.attackInstance)))

    print(string.format("[ChainLaser:equip] '%s' fully equipped. Attack instance created.", self.name or self.itemBaseId))
end

--- Desequipa o ChainLaser.
function ChainLaser:unequip()
    print(string.format("[ChainLaser:unequip] Unequipping '%s'.", self.name or self.itemBaseId))
    BaseWeapon.unequip(self)
    print(string.format("[ChainLaser:unequip] '%s' fully unequipped.", self.name or self.itemBaseId))
end

return ChainLaser
