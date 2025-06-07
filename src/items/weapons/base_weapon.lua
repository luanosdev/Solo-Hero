local ManagerRegistry = require("src.managers.manager_registry")

---@class BaseWeapon : BaseItem
---@field type string Sempre "weapon"
---@field itemBaseId string ID base do item (ex: "dual_daggers")
---@field equipped boolean Indica se a arma está equipada
---@field owner PlayerManager|nil Referência ao PlayerManager que equipou a arma
---@field attackInstance table|nil Instância da lógica de ataque associada
---@field itemData table|nil Dados específicos da instância do item (pode incluir encantamentos, etc.)
local BaseWeapon = {}
BaseWeapon.__index = BaseWeapon -- Herança básica

--- Cria uma nova instância de uma arma.
--- Busca os dados base do ItemDataManager usando o itemBaseId fornecido.
---@param config table Tabela de configuração. Deve conter 'itemBaseId'.
---@return BaseWeapon|nil A nova instância da arma, ou nil em caso de erro.
function BaseWeapon:new(config)
    local o = setmetatable({}, self)
    Logger.debug("[BaseWeapon:new]", string.format(" Creating new weapon instance. Config itemBaseId: %s",
        config and config.itemBaseId or "N/A"))

    -- Garante que o tipo seja weapon
    o.type = "weapon"
    o.equipped = false
    o.owner = nil
    o.attackInstance = nil
    o.itemData = nil -- Dados específicos da instância (ex: encantamentos) serão passados no :equip

    -- Verifica se itemBaseId foi fornecido na configuração
    if not config or not config.itemBaseId then
        error("BaseWeapon:new - 'itemBaseId' é obrigatório na tabela de configuração.")
        return nil
    end
    o.itemBaseId = config.itemBaseId
    Logger.debug("[BaseWeapon:new]", string.format("  - itemBaseId set to: %s", o.itemBaseId))

    -- Busca dados base do ItemDataManager
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        error("BaseWeapon:new - ItemDataManager não encontrado no ManagerRegistry.")
        return nil
    end
    local baseData = itemDataManager:getBaseItemData(o.itemBaseId)
    if not baseData then
        error("BaseWeapon:new - Dados base não encontrados para itemBaseId: " .. o.itemBaseId)
        return nil
    end
    Logger.debug("[BaseWeapon:new]", "  - Base item data fetched successfully.")

    -- Atribui dados base ao objeto 'o' (propriedades como name, description, rarity, etc.)
    -- NÃO copiamos stats como damage, cooldown, range aqui, pois eles podem ser modificados
    -- e devem ser gerenciados pela attackInstance ou pelo PlayerState.
    -- Copiamos apenas metadados e identificadores.
    o.name = baseData.name
    o.description = baseData.description
    o.rarity = baseData.rarity
    -- o.damage = baseData.damage -- Removido daqui
    -- o.cooldown = baseData.cooldown -- Removido daqui
    -- o.range = baseData.range -- Removido daqui
    -- o.baseProjectiles = baseData.baseProjectiles -- Removido daqui
    -- ... outras propriedades base se necessário ...

    -- Aplica quaisquer outros overrides específicos que não sejam dados base
    -- (Ex: previewColor, etc., que podem vir da definição da arma específica como 'dual_daggers.lua')
    -- Note: Evitamos sobrescrever o itemBaseId ou dados base já definidos.
    for key, value in pairs(config) do
        if key ~= "itemBaseId" and o[key] == nil then -- Só atribui se não existir
            o[key] = value
            Logger.debug("[BaseWeapon:new]", string.format("  - Applied override: %s = %s", key, tostring(value)))
        end
    end

    Logger.debug("[BaseWeapon:new]", string.format(" Weapon instance '%s' created.", o.name or o.itemBaseId))
    return o
end

--- Equipa a arma no PlayerManager fornecido.
--- Este método base armazena referências e os dados do item. A lógica principal
--- de criação da attackInstance e aplicação de stats é feita nas classes filhas.
---@param playerManager PlayerManager Instância do PlayerManager.
---@param itemData table Dados da instância específica do item sendo equipado.
function BaseWeapon:equip(playerManager, itemData)
    Logger.debug("[BaseWeapon:equip]", string.format(" Equipping '%s' (ID: %s) on PlayerManager.", self.name or "Unknown",
        self.itemBaseId))
    if not playerManager then
        error("BaseWeapon:equip - 'playerManager' é obrigatório.")
        return
    end
    self.equipped = true
    self.owner = playerManager
    self.itemData = itemData -- Armazena os dados da instância específica (pode ter bônus, etc.)
    Logger.debug("[BaseWeapon:equip]", "  - Owner (PlayerManager) and itemData stored.")
    -- A criação da attackInstance e a aplicação de stats serão feitas no :equip da classe filha.
end

--- Desequipa a arma.
--- Remove a referência ao dono e à instância de ataque.
--- A lógica de remover os stats do PlayerManager deve ser tratada pela classe filha
--- ou pelo próprio PlayerManager ao trocar de arma.
function BaseWeapon:unequip()
    Logger.debug("[BaseWeapon:unequip]", string.format(" Unequipping '%s' (ID: %s).", self.name or "Unknown", self.itemBaseId))
    self.equipped = false
    self.owner = nil
    self.attackInstance = nil -- Limpa a instância de ataque
    self.itemData = nil
    Logger.debug("[BaseWeapon:unequip]", "  - Owner, attackInstance, and itemData cleared.")
end

--- Retorna a instância da lógica de ataque associada a esta arma.
---@return table|nil A instância de ataque, ou nil se não houver.
function BaseWeapon:getAttackInstance()
    return self.attackInstance
end

--- Retorna os dados base da arma buscando no ItemDataManager.
--- Útil para classes filhas ou a attackInstance acessarem os stats base.
---@return table|nil Os dados base da arma, ou nil se não encontrados.
function BaseWeapon:getBaseData()
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        Logger.debug("[BaseWeapon:getBaseData]", "  - WARN: ItemDataManager não encontrado.")
        return nil
    end
    return itemDataManager:getBaseItemData(self.itemBaseId)
end

return BaseWeapon
