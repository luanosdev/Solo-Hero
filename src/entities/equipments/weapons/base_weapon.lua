local ManagerRegistry = require("src.managers.manager_registry")

---@class BaseWeapon : BaseItem
---@field type string Sempre "weapon"
---@field itemBaseId string ID base do item (ex: "dual_daggers")
---@field equipped boolean Indica se a arma está equipada
---@field owner PlayerManager|nil Referência ao PlayerManager que equipou a arma
---@field attackInstance table|nil Instância da lógica de ataque associada
---@field itemData table|nil Dados específicos da instância do item (pode incluir encantamentos, etc.)
---@field modifiers HunterModifier[]|nil Modificadores da arma
---@field previewColor? table Cor de visualização da arma.
---@field attackColor? table Cor de ataque da arma.
local BaseWeapon = {}
BaseWeapon.__index = BaseWeapon -- Herança básica

--- Cria uma nova instância de uma arma.
--- Busca os dados base do ItemDataManager usando o itemBaseId fornecido.
---@param config table Tabela de configuração. Deve conter 'itemBaseId'.
---@return BaseWeapon|nil A nova instância da arma, ou nil em caso de erro.
function BaseWeapon:new(config)
    local o = setmetatable({}, self)
    Logger.debug(
        "[BaseWeapon:new]",
        string.format(
            "Creating new weapon instance. Config itemBaseId: %s",
            config and config.itemBaseId or "N/A"
        )
    )

    -- Garante que o tipo seja weapon
    o.type = "weapon"
    o.equipped = false
    o.owner = nil
    o.attackInstance = nil
    o.itemData = nil

    -- Verifica se itemBaseId foi fornecido na configuração
    if not config or not config.itemBaseId then
        error("BaseWeapon:new - 'itemBaseId' é obrigatório na tabela de configuração.")
    end

    o.itemBaseId = config.itemBaseId
    Logger.debug("[BaseWeapon:new]", string.format("itemBaseId set to: %s", o.itemBaseId))

    ---@type ItemDataManager
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        error("BaseWeapon:new - ItemDataManager não encontrado no ManagerRegistry.")
    end

    local baseData = itemDataManager:getBaseItemData(o.itemBaseId)

    -- Atribui dados base ao objeto 'o' (propriedades como name, description, rarity, etc.)
    -- NÃO copiamos stats como damage, cooldown, range aqui, pois eles podem ser modificados
    -- e devem ser gerenciados pela attackInstance ou pelo PlayerState.
    -- Copiamos apenas metadados e identificadores.
    o.name = baseData.name
    o.description = baseData.description
    o.rarity = baseData.rarity
    o.rank = baseData.rank
    o.modifiers = baseData.modifiers

    o.previewColor = baseData.previewColor or { 1, 1, 1, 1 }
    o.attackColor = baseData.attackColor or { 1, 1, 1, 1 }

    -- Aplica quaisquer outros overrides específicos que não sejam dados base
    for key, value in pairs(config) do
        if key ~= "itemBaseId" and o[key] == nil then
            o[key] = value
            Logger.debug("[BaseWeapon:new]", string.format("Applied override: %s = %s", key, tostring(value)))
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
    Logger.debug("[BaseWeapon:equip]", string.format(" Equipping '%s' (ID: %s).", self.name, self.itemBaseId))

    self.equipped = true
    self.owner = playerManager
    self.itemData = itemData

    local baseData = self:getBaseData()

    -- Carregamento dinâmico da Classe de Ataque
    local attackClassPath = "src.entities.attacks.player." .. baseData.attackClass
    local success, AttackClass = pcall(require, attackClassPath)
    if not success or not AttackClass then
        error(
            string.format(
                "BaseWeapon:equip - Falha ao carregar AttackClass '%s' em '%s'",
                baseData.attackClass,
                attackClassPath
            )
        )
    end

    -- Cria a instância da habilidade, passando a classe do projétil
    self.attackInstance = AttackClass:new(playerManager, self)
    if not self.attackInstance then
        error(string.format("BaseWeapon:equip - Falha ao criar instância de '%s'", baseData.attackClass))
    end

    Logger.debug(
        "[BaseWeapon:equip]",
        string.format(
            " '%s' equipado. Instância de ataque '%s' criada.",
            self.name,
            baseData.attackClass
        )
    )
end

--- Desequipa a arma.
--- Remove a referência ao dono e à instância de ataque.
--- A lógica de remover os stats do PlayerManager deve ser tratada pela classe filha
--- ou pelo próprio PlayerManager ao trocar de arma.
function BaseWeapon:unequip()
    Logger.debug("[BaseWeapon:unequip]",
        string.format(" Unequipping '%s' (ID: %s).", self.name or "Unknown", self.itemBaseId)
    )
    self.equipped = false
    self.owner = nil
    self.attackInstance = nil
    self.itemData = nil
    Logger.debug("[BaseWeapon:unequip]", "Owner, attackInstance, and itemData cleared.")
end

--- Retorna a instância da lógica de ataque associada a esta arma.
---@return table|nil A instância de ataque, ou nil se não houver.
function BaseWeapon:getAttackInstance()
    return self.attackInstance
end

--- Retorna os dados base da arma buscando no ItemDataManager.
--- Útil para classes filhas ou a attackInstance acessarem os stats base.
---@return Weapon|table baseItemData Os dados base da arma, ou nil se não encontrados.
function BaseWeapon:getBaseData()
    ---@type ItemDataManager
    local itemDataManager = ManagerRegistry:get("itemDataManager")
    return itemDataManager:getBaseItemData(self.itemBaseId)
end

--- Ativa ou desativa a visualização do ataque da arma.
function BaseWeapon:togglePreview()
    self.attackInstance:togglePreview()
end

return BaseWeapon
