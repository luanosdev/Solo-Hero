---@class HunterManager
local HunterManager = {
    loadoutManager = nil, ---@type LoadoutManager
    itemDataManager = nil, ---@type ItemDataManager
    activeHunterId = nil, ---@type string
    hunterBaseStats = {}, ---@type table<string, table>
    equippedItems = {}, ---@type table<string, table<string, table|nil>> { [hunterId] = { [slotId] = itemInstance | nil } }
}
HunterManager.__index = HunterManager

local PersistenceManager = require("src.core.persistence_manager")
local CharacterData = require("src.data.character_data") -- Para obter stats base

local SAVE_FILE = "hunters.dat"
local DEFAULT_HUNTER_ID = "hunter_default" -- ID do Caçador inicial

-- Define os slots de equipamento válidos COMO PARTE DA CLASSE
HunterManager.EQUIPMENT_SLOTS = {
    "weapon",
    "helmet",
    "chest",
    "gloves",
    "boots",
    "legs" -- Adicionado para consistência com EquipmentSection
    -- Adicione outros slots aqui (amuleto, anéis, etc.)
}

--- Cria uma nova instância do gerenciador de caçadores.
--- @param loadoutManager LoadoutManager Instância do gerenciador de loadout.
--- @param itemDataManager ItemDataManager Instância do gerenciador de dados de itens.
--- @return HunterManager
function HunterManager:new(loadoutManager, itemDataManager)
    print("[HunterManager] Criando nova instância...")
    local instance = setmetatable({}, HunterManager)
    instance.loadoutManager = loadoutManager
    instance.itemDataManager = itemDataManager
    instance.activeHunterId = DEFAULT_HUNTER_ID
    instance.hunterBaseStats = {}
    instance.equippedItems = {} -- Inicializa tabela principal de equipamento

    if not instance.loadoutManager or not instance.itemDataManager then
        error("ERRO CRÍTICO [HunterManager]: loadoutManager ou itemDataManager não foi injetado!")
    end

    instance:loadState() -- Carrega estado (incluindo equipamento salvo)

    -- Garante que temos stats base para o caçador ativo
    instance:loadHunterBaseStats(instance.activeHunterId)

    -- Garante que a estrutura de equipamento exista para o caçador ativo
    if not instance.equippedItems[instance.activeHunterId] then
        instance:_initializeEquippedItems(instance.activeHunterId)
    end

    -- Carrega o loadout do caçador ativo inicial
    print(string.format("  [HunterManager] Solicitando carregamento do loadout para %s...", instance.activeHunterId))
    instance.loadoutManager:loadLoadout(instance.activeHunterId)

    print(string.format("[HunterManager] Pronto. Caçador ativo: %s", instance.activeHunterId))
    return instance
end

--- Helper interno para inicializar a tabela de equipamento para um caçador.
--- @param hunterId string
function HunterManager:_initializeEquippedItems(hunterId)
    print(string.format("  [HunterManager] Inicializando slots de equipamento para %s", hunterId))
    self.equippedItems[hunterId] = {}
    -- Acessa via self.EQUIPMENT_SLOTS ou HunterManager.EQUIPMENT_SLOTS
    for _, slotId in ipairs(self.EQUIPMENT_SLOTS) do
        self.equippedItems[hunterId][slotId] = nil -- Nenhum item equipado inicialmente
    end
end

--- Carrega os dados base de um caçador específico (se ainda não carregado).
--- @param hunterId string ID do caçador.
function HunterManager:loadHunterBaseStats(hunterId)
    if not self.hunterBaseStats[hunterId] then
        -- Assume que CharacterData tem uma entrada com o mesmo nome do hunterId
        local stats = CharacterData[hunterId] or CharacterData.warrior -- Fallback para guerreiro
        if stats then
            print(string.format("  [HunterManager] Carregando stats base para %s", hunterId))
            self.hunterBaseStats[hunterId] = stats
        else
            print(string.format("AVISO [HunterManager]: Não foi possível carregar stats base para %s. Usando fallback.",
                hunterId))
            self.hunterBaseStats[hunterId] = CharacterData.warrior or {} -- Tenta guerreiro de novo ou vazio
        end
    end
end

--- Retorna o ID do caçador atualmente ativo.
--- @return string
function HunterManager:getActiveHunterId()
    return self.activeHunterId
end

--- Define o caçador ativo.
-- Salva o loadout/equipamento anterior e carrega o novo.
--- @param hunterId string ID do novo caçador ativo.
--- @return boolean True se trocou com sucesso, false caso contrário.
function HunterManager:setActiveHunter(hunterId)
    if not CharacterData[hunterId] then -- Verifica se o ID do caçador é válido nos dados base
        print(string.format("ERRO [HunterManager]: Tentativa de ativar caçador inválido: %s", hunterId))
        return false
    end

    if hunterId ~= self.activeHunterId then
        local previousHunterId = self.activeHunterId
        print(string.format("[HunterManager] Trocando caçador ativo de %s para %s", previousHunterId, hunterId))

        -- Salva dados do caçador ANTERIOR (loadout + equipamento)
        self:saveActiveHunterData(previousHunterId)

        -- Troca o ID ativo e carrega stats base
        self.activeHunterId = hunterId
        self:loadHunterBaseStats(hunterId)

        -- Garante que a estrutura de equipamento exista para o NOVO caçador
        if not self.equippedItems[self.activeHunterId] then
            self:_initializeEquippedItems(self.activeHunterId)
        end

        -- Carrega o loadout do NOVO caçador ativo
        print(string.format("  [HunterManager] Solicitando carregamento do loadout para %s...", self.activeHunterId))
        self.loadoutManager:loadLoadout(self.activeHunterId)

        -- Salva o estado do HunterManager (qual ID está ativo)
        self:saveState()
        print(string.format("[HunterManager] Caçador ativo alterado para %s.", hunterId))
        return true
    end
    return false
end

--- Retorna os stats base do caçador ativo.
--- @return table Stats base ou {} se não encontrado.
function HunterManager:getActiveHunterBaseStats()
    return self.hunterBaseStats[self.activeHunterId] or {}
end

--- Retorna a tabela de itens equipados para o caçador ativo.
--- @return table<string, table|nil> Tabela { [slotId] = itemInstance | nil } ou nil.
function HunterManager:getActiveEquippedItems()
    if not self.activeHunterId then return nil end
    return self.equippedItems[self.activeHunterId]
end

--- Tenta equipar um item em um slot específico para o caçador ativo.
--- @param itemInstance table Instância completa do item (do loadout/storage).
--- @param slotId string ID do slot onde equipar (ex: "weapon", "helmet").
--- @return boolean, table|nil Retorna true e a instância do item antigo (se houver), ou false e nil.
function HunterManager:equipItem(itemInstance, slotId)
    if not self.activeHunterId or not itemInstance or not slotId then
        print("ERRO [HunterManager:equipItem]: Argumentos inválidos.")
        return false, nil
    end

    -- Verifica se o slotId é válido
    local isValidSlot = false
    -- Acessa via self.EQUIPMENT_SLOTS ou HunterManager.EQUIPMENT_SLOTS
    for _, validSlot in ipairs(self.EQUIPMENT_SLOTS) do
        if slotId == validSlot then
            isValidSlot = true
            break
        end
    end
    if not isValidSlot then
        print(string.format("ERRO [HunterManager:equipItem]: Slot de equipamento inválido: %s", slotId))
        return false, nil
    end

    -- TODO: Verificar se o TIPO do item é compatível com o slotId
    local baseData = self.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
    if not baseData then
        print(string.format("ERRO [HunterManager:equipItem]: Não foi possível obter dados base para %s",
            itemInstance.itemBaseId))
        return false, nil
    end
    -- Exemplo: if slotId == "weapon" and baseData.type ~= "weapon" then return false, nil end

    local hunterEquipment = self.equippedItems[self.activeHunterId]
    if not hunterEquipment then
        print("ERRO [HunterManager:equipItem]: Estrutura de equipamento não encontrada para o caçador ativo.")
        return false, nil
    end

    local oldItemInstance = hunterEquipment[slotId] -- <<< Pega a instância antiga diretamente

    if oldItemInstance then
        print(string.format("  [HunterManager] Desequipando item anterior (%s, ID: %d) do slot %s",
            oldItemInstance.itemBaseId, oldItemInstance.instanceId, slotId))
    end

    -- Equipa a nova instância
    hunterEquipment[slotId] = itemInstance -- <<< Armazena a instância completa
    print(string.format("[HunterManager] Item %d (%s) equipado no slot %s para %s", itemInstance.instanceId,
        itemInstance.itemBaseId, slotId, self.activeHunterId))

    -- TODO: Recalcular stats totais do caçador

    -- Retorna sucesso e a instância do item antigo (que a UI precisa colocar de volta)
    return true, oldItemInstance -- <<< Retorna a instância antiga
end

--- Desequipa o item de um slot específico para o caçador ativo.
--- @param slotId string ID do slot a desequipar.
--- @return table|nil Retorna a instância do item que foi desequipado, ou nil.
function HunterManager:unequipItem(slotId)
    if not self.activeHunterId or not slotId then return nil end

    local hunterEquipment = self.equippedItems[self.activeHunterId]
    if not hunterEquipment then return nil end

    local itemToUnequip = hunterEquipment[slotId] -- <<< Pega a instância
    if itemToUnequip then
        print(string.format("[HunterManager] Desequipando item (%s, ID: %d) do slot %s para %s",
            itemToUnequip.itemBaseId, itemToUnequip.instanceId, slotId, self.activeHunterId))
        hunterEquipment[slotId] = nil
        -- TODO: Recalcular stats totais do caçador
        return itemToUnequip -- <<< Retorna a instância completa
    end
    return nil
end

--- Salva os dados associados a um caçador específico (loadout + equipamento).
--- @param hunterId string O ID do caçador cujos dados salvar.
function HunterManager:saveActiveHunterData(hunterId)
    if not hunterId then
        print("ERRO [HunterManager:saveActiveHunterData]: hunterId não fornecido!")
        return
    end
    print(string.format("[HunterManager] Solicitando salvamento dos dados do caçador (%s)...", hunterId))
    if self.loadoutManager then
        self.loadoutManager:saveLoadout(hunterId)
    else
        print("ERRO [HunterManager:saveActiveHunterData]: LoadoutManager não disponível!")
    end
    -- O equipamento já é salvo junto com o estado geral em saveState
end

--- Salva o estado do HunterManager (incluindo dados ESSENCIAIS dos itens equipados).
function HunterManager:saveState()
    print("[HunterManager] Solicitando salvamento de estado (activeHunterId e equipamento)...")

    -- Cria uma cópia serializável do equipamento
    local serializableEquippedItems = {}
    for hunterId, equipmentSlots in pairs(self.equippedItems) do
        serializableEquippedItems[hunterId] = {}
        for slotId, itemInstance in pairs(equipmentSlots) do
            if itemInstance then
                -- Salva apenas dados essenciais e serializáveis
                serializableEquippedItems[hunterId][slotId] = {
                    instanceId = itemInstance.instanceId,
                    itemBaseId = itemInstance.itemBaseId,
                    quantity = itemInstance.quantity or 1 -- Equipamento geralmente não tem quantidade, mas por segurança
                    -- Não salvamos row/col pois não faz sentido para item equipado
                    -- Não salvamos icon, name, rarity, etc. pois são recarregados do baseData
                }
            else
                serializableEquippedItems[hunterId][slotId] = nil
            end
        end
    end

    local dataToSave = {
        version = 1,
        activeHunterId = self.activeHunterId,
        hunters = serializableEquippedItems -- <<< Salva a cópia serializável
    }
    local success = PersistenceManager.saveData(SAVE_FILE, dataToSave)
    if success then
        print("[HunterManager] Estado (activeHunterId e equipamento) salvo com sucesso.")
    else
        print("ERRO [HunterManager]: Falha ao salvar estado (activeHunterId e equipamento).")
    end
    return success
end

--- Carrega o estado do arquivo de save.
function HunterManager:loadState()
    print("[HunterManager] Tentando carregar estado...")
    local loadedData = PersistenceManager.loadData(SAVE_FILE)

    self.equippedItems = {} -- Limpa antes de carregar

    if not loadedData or type(loadedData) ~= "table" then
        print("[HunterManager] Nenhum dado de save válido encontrado. Usando padrão:", DEFAULT_HUNTER_ID)
        self.activeHunterId = DEFAULT_HUNTER_ID
        self:_initializeEquippedItems(self.activeHunterId)
        return false
    end

    if loadedData.version ~= 1 then
        print(string.format(
            "AVISO [HunterManager]: Versão do save (%s) incompatível com a atual (1). Tentando carregar mesmo assim...",
            tostring(loadedData.version)))
        -- TODO: Adicionar lógica de migração se necessário
    end

    self.activeHunterId = loadedData.activeHunterId or DEFAULT_HUNTER_ID
    local loadedHunterEquipmentData = loadedData.hunters or {}

    -- Reconstrói as instâncias de itens equipados
    for hunterId, savedSlots in pairs(loadedHunterEquipmentData) do
        self.equippedItems[hunterId] = {}
        for slotId, savedItemData in pairs(savedSlots) do
            if savedItemData then
                local baseData = self.itemDataManager:getBaseItemData(savedItemData.itemBaseId)
                if baseData then
                    -- Recria a instância completa do item equipado
                    self.equippedItems[hunterId][slotId] = {
                        instanceId = savedItemData.instanceId,
                        itemBaseId = savedItemData.itemBaseId,
                        quantity = savedItemData.quantity,
                        -- Adiciona dados base novamente para exibição/uso
                        gridWidth = baseData.gridWidth or 1,
                        gridHeight = baseData.gridHeight or 1,
                        stackable = baseData.stackable or false,
                        maxStack = baseData.maxStack or (baseData.stackable and 99) or 1,
                        name = baseData.name,
                        icon = baseData.icon,
                        rarity = baseData.rarity or 'E'
                        -- Não precisa de row/col aqui
                    }
                else
                    print(string.format(
                        "AVISO [HunterManager]: Não foi possível encontrar dados base para item equipado '%s' (instância %d) do caçador '%s'. Slot ficará vazio.",
                        savedItemData.itemBaseId, savedItemData.instanceId, hunterId))
                    self.equippedItems[hunterId][slotId] = nil
                end
            else
                self.equippedItems[hunterId][slotId] = nil
            end
        end
    end

    -- Garante que a estrutura exista para o caçador ativo (caso não estivesse no save)
    if not self.equippedItems[self.activeHunterId] then
        self:_initializeEquippedItems(self.activeHunterId)
    end

    -- Garante que todos os slots definidos existam para o caçador ativo (caso novos slots sejam adicionados)
    local hunterEq = self.equippedItems[self.activeHunterId]
    -- Acessa via self.EQUIPMENT_SLOTS ou HunterManager.EQUIPMENT_SLOTS
    for _, slotId in ipairs(self.EQUIPMENT_SLOTS) do
        if hunterEq[slotId] == nil then -- Checa se é nil, não ausente (false não é nil)
            hunterEq[slotId] = nil      -- Garante que o slot exista como nil
        end
    end

    print("[HunterManager] Carregamento concluído. Caçador ativo:", self.activeHunterId)
    return true
end

return HunterManager
