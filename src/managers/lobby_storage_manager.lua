local PersistenceManager = require("src.core.persistence_manager")
local ItemGridLogic = require("src.core.item_grid_logic")

---@class LobbyStorageManager
local LobbyStorageManager = {}
LobbyStorageManager.__index = LobbyStorageManager

local SAVE_FILE = "lobby_storage.dat"
local DEFAULT_SECTION_ROWS = 8
local DEFAULT_SECTION_COLS = 10
local STARTING_SECTIONS = 1

--- Cria uma nova instância do gerenciador de armazenamento do lobby.
--- @param itemDataManager ItemDataManager Instância do ItemDataManager.
--- @return LobbyStorageManager
function LobbyStorageManager:new(itemDataManager)
    Logger.debug("[LobbyStorageManager]", "Criando nova instância...")
    ---@class LobbyStorageManager
    local instance = setmetatable({}, LobbyStorageManager)
    instance.itemDataManager = itemDataManager
    if not instance.itemDataManager then
        error("ERRO CRÍTICO [LobbyStorageManager]: itemDataManager não foi injetado!")
    end

    instance.sections = {}          -- Tabela para guardar as grades das seções { [index] = { grid={}, items={}, rows=R, cols=C }, ... }
    instance.activeSectionIndex = 1 -- Qual seção está visível/ativa
    instance.sectionRows = DEFAULT_SECTION_ROWS
    instance.sectionCols = DEFAULT_SECTION_COLS

    instance:loadStorage()

    -- Garante que o índice ativo seja válido
    if not instance.sections[instance.activeSectionIndex] then
        instance.activeSectionIndex = 1 -- Volta para a primeira se caso o índice salvo seja inválido
    end

    Logger.debug("[LobbyStorageManager]", string.format("Pronto. %d seções carregadas/inicializadas. Seção ativa: %d.",
        instance:getTotalSections(), instance.activeSectionIndex))

    return instance
end

--- Helper interno para criar a estrutura de uma seção vazia.
--- @param rows number Número de linhas.
--- @param cols number Número de colunas.
--- @param index number O índice desta seção.
--- @return table Estrutura da seção.
function LobbyStorageManager:_createEmptySection(rows, cols, index)
    local section = {
        index = index, -- Armazena o próprio índice
        grid = {},     -- Grade 2D para referência rápida de ocupação (armazena instanceId ou nil)
        items = {},    -- Tabela de instâncias de itens na seção { [instanceId] = itemInstanceData }
        rows = rows,
        cols = cols
    }
    for r = 1, rows do
        section.grid[r] = {}
        for c = 1, cols do
            section.grid[r][c] = nil
        end
    end
    return section
end

-- == Funções de Gerenciamento de Seção ==

--- Define qual seção está ativa.
--- @param index number O índice da seção a ser ativada.
--- @return boolean hasChangedSection True se o índice for válido e a seção foi ativada, false caso contrário.
function LobbyStorageManager:setActiveSection(index)
    if self.sections[index] then
        self.activeSectionIndex = index
        Logger.info("[LobbyStorageManager:setActiveSection]", string.format("Seção ativa alterada para: %d", index))
        return true
    else
        Logger.warn("[LobbyStorageManager:setActiveSection]",
            string.format("Tentativa de ativar seção inválida: %d", index))
        return false
    end
end

--- Obtém o índice da seção atualmente ativa.
--- @return number Índice da seção ativa.
function LobbyStorageManager:getActiveSectionIndex()
    return self.activeSectionIndex
end

--- Obtém o número total de seções de armazenamento disponíveis.
--- @return number totalSections Total de seções.
function LobbyStorageManager:getTotalSections()
    local count = 0
    for _ in pairs(self.sections) do
        count = count + 1
    end
    return count
end

--- Obtém a configuração (linhas, colunas) da seção ativa.
--- @return number rows Linhas da seção ativa.
--- @return number cols Colunas da seção ativa.
function LobbyStorageManager:getActiveSectionDimensions()
    local activeSection = self.sections[self.activeSectionIndex]
    if activeSection then
        return activeSection.rows, activeSection.cols
    end
    return self.sectionRows, self.sectionCols
end

--- Obtém a instância do item em coordenadas específicas da grade da seção ativa ou especificada.
--- @param targetRow integer Linha alvo (1-indexed).
--- @param targetCol integer Coluna alvo (1-indexed).
--- @param sectionIndexParam? integer (Opcional) Índice da seção a verificar. Usa seção ativa se nil.
--- @return table|nil itemInstance A instância do item se encontrada, caso contrário nil.
function LobbyStorageManager:getItemInstanceAtCoords(targetRow, targetCol, sectionIndexParam)
    local sectionIdx = sectionIndexParam or self.activeSectionIndex
    local section = self.sections[sectionIdx]

    if not section or not section.items or not targetRow or not targetCol then
        return nil
    end
    if DEV then
        Logger.debug("[LobbyStorageManager:getItemInstanceAtCoords]",
            string.format("Section %d: Checking for item at [%d,%d]",
                sectionIdx, targetRow, targetCol))
        local itemCount = 0
        for _ in pairs(section.items) do itemCount = itemCount + 1 end
        Logger.debug("[LobbyStorageManager:getItemInstanceAtCoords]",
            string.format("Total items in section %d: %d", sectionIdx, itemCount))
    end

    for instanceId, item in pairs(section.items) do
        local itemOriginX, itemOriginY = item.col, item.row
        local itemDisplayW = item.isRotated and item.gridHeight or item.gridWidth
        local itemDisplayH = item.isRotated and item.gridWidth or item.gridHeight

        Logger.debug("[LobbyStorageManager:getItemInstanceAtCoords]",
            string.format("    S%d Checking item: %s (ID %s) at [%d,%d] size [%dx%d] (display: %dx%d, rotated: %s)",
                sectionIdx, item.itemBaseId, instanceId, itemOriginY, itemOriginX, item.gridWidth, item.gridHeight,
                itemDisplayW, itemDisplayH, tostring(item.isRotated)))

        -- Verifica se (targetRow, targetCol) está dentro da área ocupada pelo item
        if targetCol >= itemOriginX and targetCol < itemOriginX + itemDisplayW and
            targetRow >= itemOriginY and targetRow < itemOriginY + itemDisplayH then
            Logger.debug("[LobbyStorageManager:getItemInstanceAtCoords]",
                string.format("    S%d FOUND item: %s (ID %s) at coords [%d,%d]", sectionIdx, item.itemBaseId,
                    instanceId, targetRow, targetCol))
            return item
        end
    end

    Logger.debug("[LobbyStorageManager:getItemInstanceAtCoords]",
        string.format("  S%d: No item found at [%d,%d]", sectionIdx,
            targetRow, targetCol))

    return nil -- Nenhum item encontrado nesta célula
end

-- == Funções de Manipulação de Itens (na Seção Ativa) ==

--- Obtém a tabela de itens da seção especificada (ou da ativa).
--- @param sectionIndex number (Opcional) Índice da seção. Se omitido, usa a seção ativa.
--- @return table items Tabela de itens { [instanceId] = itemInstanceData } da seção, ou {} se inválido.
function LobbyStorageManager:getItems(sectionIndex)
    local indexToUse = sectionIndex or self.activeSectionIndex
    if self.sections[indexToUse] then
        return self.sections[indexToUse].items
    end
    return {} -- Retorna tabela vazia em vez de nil para evitar erros em loops
end

--- Adiciona um item (ou quantidade) à seção ativa.
--- @param itemBaseId string ID base do item.
--- @param quantity number Quantidade a adicionar.
--- @return number addedQuantity Quantidade realmente adicionada.
function LobbyStorageManager:addItem(itemBaseId, quantity)
    local activeSection = self.sections[self.activeSectionIndex]
    if not activeSection then
        error("ERRO [LobbyStorageManager]: Tentando adicionar item sem seção ativa válida.")
    end

    if not itemBaseId or not quantity or quantity <= 0 then return 0 end

    return self:_addItemToSection(activeSection, itemBaseId, quantity)
end

--- Remove uma instância específica de item da seção ativa.
--- @param instanceId any ID da instância a remover.
--- @param quantity number (Opcional) Quantidade a remover. Se omitido ou >= quantidade atual, remove tudo.
--- @return boolean success True se removeu com sucesso.
function LobbyStorageManager:removeItemInstance(instanceId, quantity)
    local activeSection = self.sections[self.activeSectionIndex]
    if not activeSection then
        error("ERRO [LobbyStorageManager]: Tentando remover item sem seção ativa válida.")
    end

    return self:_removeItemInstanceFromSection(activeSection, instanceId, quantity, self.activeSectionIndex)
end

--- Remove uma instância de item específica pelo ID, de qualquer seção.
--- @param instanceId any ID da instância a remover.
--- @return boolean success True se removeu com sucesso.
--- @return number|nil sectionIndex Índice da seção se removeu, nil caso contrário.
function LobbyStorageManager:removeItemByInstanceId(instanceId)
    for index, section in pairs(self.sections) do
        if section.items[instanceId] then
            local success = self:_removeItemInstanceFromSection(section, instanceId, nil, index)
            if success then
                Logger.info("[LobbyStorageManager:removeItemByInstanceId]",
                    string.format("Item %s removido da seção %d", tostring(instanceId), index))
                return true, index
            else
                error("[LobbyStorageManager:removeItemByInstanceId] " ..
                    string.format("Falha ao remover item %s encontrado na seção %d",
                        tostring(instanceId), index))
            end
        end
    end
    Logger.warn("[LobbyStorageManager:removeItemByInstanceId]",
        string.format("Tentativa de remover item %s (não encontrado)", tostring(instanceId)))
    return false, nil
end

--- Verifica se um item pode ser colocado em uma posição específica na seção ativa.
---@param item table Instância do item a ser colocado.
---@param targetRow integer Linha alvo (1-indexed).
---@param targetCol integer Coluna alvo (1-indexed).
---@param checkWidth integer|nil Largura a ser usada para a checagem (usa item.gridWidth se nil).
---@param checkHeight integer|nil Altura a ser usada para a checagem (usa item.gridHeight se nil).
---@return boolean success True se o item pode ser colocado, false caso contrário.
function LobbyStorageManager:canPlaceItemAt(item, targetRow, targetCol, checkWidth, checkHeight)
    if not item or not targetRow or not targetCol then
        error("ERRO (canPlaceItemAt - Storage): Parâmetros inválidos.")
    end

    local section = self.sections[self.activeSectionIndex]
    if not section then
        error("ERRO (canPlaceItemAt - Storage): Seção ativa inválida: " .. self.activeSectionIndex)
    end

    local itemW = checkWidth or item.gridWidth or 1
    local itemH = checkHeight or item.gridHeight or 1

    -- Verifica se já existe um item no slot alvo
    local itemAtTarget = self:getItemInstanceAtCoords(targetRow, targetCol)
    if itemAtTarget and itemAtTarget.instanceId ~= item.instanceId then
        local baseData = self.itemDataManager:getBaseItemData(itemAtTarget.itemBaseId)
        if baseData and baseData.stackable and itemAtTarget.itemBaseId == item.itemBaseId then
            local maxStack = baseData.maxStack or 99
            if itemAtTarget.quantity < maxStack then
                return true
            end
        end
        return false
    end

    return ItemGridLogic.canPlaceItemAt(section.grid, section.rows, section.cols, item.instanceId, targetRow, targetCol,
        itemW, itemH)
end

--- Adiciona um item em uma posição específica na grade da seção ativa.
--- @param itemInstance table A instância do item a ser adicionado.
--- @param targetRow integer Linha alvo (1-indexed).
--- @param targetCol integer Coluna alvo (1-indexed).
--- @param isRotated boolean|nil Se o item deve ser armazenado como rotacionado.
--- @return boolean success True se o item foi adicionado, false caso contrário.
function LobbyStorageManager:addItemInstanceAt(itemInstance, targetRow, targetCol, isRotated)
    if not itemInstance or not targetRow or not targetCol then
        error("ERRO (addItemAt - Storage): Parâmetros inválidos.")
    end

    local section = self.sections[self.activeSectionIndex]
    if not section then
        error("ERRO (addItemAt - Storage): Seção ativa inválida: " .. self.activeSectionIndex)
    end

    local itemW = itemInstance.gridWidth or 1
    local itemH = itemInstance.gridHeight or 1

    itemInstance.row = targetRow
    itemInstance.col = targetCol
    itemInstance.isRotated = isRotated or false

    local actualW = itemInstance.isRotated and itemH or itemW
    local actualH = itemInstance.isRotated and itemW or itemH

    if not ItemGridLogic.canPlaceItemAt(section.grid, section.rows, section.cols, itemInstance.instanceId, targetRow, targetCol, actualW, actualH) then
        Logger.error("[LobbyStorageManager:addItemAt]", string.format(
            "ERRO [LobbyStorageManager:addItemAt]: Não é possível colocar o item %s em [%d,%d] na seção %d.",
            itemInstance.itemBaseId, targetRow, targetCol, self.activeSectionIndex))
        return false
    end

    section.items[itemInstance.instanceId] = itemInstance
    ItemGridLogic.markGridOccupied(section.grid, section.rows, section.cols, itemInstance.instanceId, targetRow,
        targetCol, actualW, actualH)

    Logger.info("[LobbyStorageManager:addItemAt]",
        string.format("(Storage) Item %s (ID %s) adicionado/atualizado na seção %d em [%d,%d], Rotacionado: %s",
            itemInstance.itemBaseId, tostring(itemInstance.instanceId), self.activeSectionIndex, targetRow, targetCol,
            tostring(itemInstance.isRotated)))

    return true
end

--- Adiciona uma instância de item específica à seção ativa em qualquer lugar vago.
--- @param itemInstance table A instância do item a ser adicionado.
--- @return boolean success True se conseguiu adicionar, false caso contrário.
function LobbyStorageManager:addItemInstance(itemInstance)
    local activeSection = self.sections[self.activeSectionIndex]
    if not activeSection or not itemInstance then
        error("ERRO [LobbyStorageManager:addItemInstance]: Seção ativa inválida ou item inválido.")
    end

    local width = itemInstance.gridWidth or 1
    local height = itemInstance.gridHeight or 1
    local freeSpace = ItemGridLogic.findFreeSpace(activeSection.grid, activeSection.rows, activeSection.cols, width,
        height)

    if freeSpace then
        -- Reusa a lógica de addItemAt para colocar na seção ativa
        -- Passa isRotated como nil ou false por padrão aqui, pois estamos apenas adicionando, não movendo um item rotacionado
        return self:addItemInstanceAt(itemInstance, freeSpace.row, freeSpace.col, itemInstance.isRotated or false)
    else
        Logger.warn("[LobbyStorageManager:addItemInstance]", string.format("Sem espaço na seção ativa para item %s (%s)",
            tostring(itemInstance.instanceId), itemInstance.itemBaseId))
        return false
    end
end

-- == Funções Auxiliares de Item (Operam em uma Seção Específica) ==

--- Helper interno para obter dados base do item.
--- @param itemBaseId string ID base do item.
--- @return table baseData Dados base do item.
function LobbyStorageManager:_getItemBaseData(itemBaseId)
    if self.itemDataManager and self.itemDataManager.getBaseItemData then
        return self.itemDataManager:getBaseItemData(itemBaseId)
    else
        error("AVISO [LobbyStorageManager]: itemDataManager ausente ou método de busca de dados não encontrado.")
    end
end

--- Lógica principal para adicionar item a uma seção específica.
--- @param section table Seção onde adicionar o item.
--- @param itemBaseId string ID base do item.
--- @param quantity number Quantidade a adicionar.
--- @return number addedQuantity Quantidade realmente adicionada.
function LobbyStorageManager:_addItemToSection(section, itemBaseId, quantity)
    local baseData = self:_getItemBaseData(itemBaseId)
    if not baseData then
        error("ERRO [LobbyStorageManager]: Não foi possível obter dados para o item ID: " .. itemBaseId)
    end

    local width = baseData.gridWidth or 1
    local height = baseData.gridHeight or 1
    local stackable = baseData.stackable or false
    local maxStack = baseData.maxStack or (stackable and 99) or 1
    local addedQuantity = 0
    local remainingQuantity = quantity

    -- 1. Tentar Empilhar
    if stackable then
        for id, instance in pairs(section.items) do
            if instance.itemBaseId == itemBaseId and instance.quantity < maxStack then
                local spaceAvailable = maxStack - instance.quantity
                local amountToStack = math.min(remainingQuantity, spaceAvailable)
                instance.quantity = instance.quantity + amountToStack
                addedQuantity = addedQuantity + amountToStack
                remainingQuantity = remainingQuantity - amountToStack
                Logger.info("[LobbyStorageManager:_addItemToSection]",
                    string.format("Item %s (ID %s) empilhado com %d de %d", itemBaseId, id, amountToStack, quantity))
                if remainingQuantity <= 0 then break end
            end
        end
    end

    -- 2. Tentar Colocar Novos Stacks/Itens
    while remainingQuantity > 0 do
        local amountForThisInstance = stackable and math.min(remainingQuantity, maxStack) or 1
        local freeSpace = ItemGridLogic.findFreeSpace(section.grid, section.rows, section.cols, width, height)

        if freeSpace then
            local newItemInstance = self.itemDataManager:createItemInstanceById(itemBaseId, amountForThisInstance)

            if newItemInstance then
                newItemInstance.row = freeSpace.row
                newItemInstance.col = freeSpace.col
                newItemInstance.isRotated = false

                section.items[newItemInstance.instanceId] = newItemInstance
                ItemGridLogic.markGridOccupied(section.grid, section.rows, section.cols, newItemInstance.instanceId,
                    newItemInstance.row, newItemInstance.col, width, height)

                addedQuantity = addedQuantity + amountForThisInstance
                remainingQuantity = remainingQuantity - amountForThisInstance
            else
                error(string.format("ERRO [LobbyStorageManager:_addItemToSection] Falha ao criar instância para %s",
                    itemBaseId))
                break
            end
        else
            Logger.warn("[LobbyStorageManager:_addItemToSection]",
                string.format("Sem espaço na seção para %s (%dx%d).", itemBaseId, width, height))
            break
        end
    end

    if remainingQuantity > 0 then
        Logger.warn("[LobbyStorageManager:_addItemToSection]",
            string.format("Não foi possível adicionar %d de %s (armazenamento cheio).", remainingQuantity, itemBaseId))
    end

    return addedQuantity
end

--- Lógica principal para remover uma instância de item de uma seção.
--- @param section table Seção onde remover o item.
--- @param instanceId any ID da instância a remover.
--- @param quantity? number Quantidade a remover. Se omitido, remove tudo.
--- @param sectionIndex number O índice da seção (para logs).
--- @return boolean success True se removeu com sucesso.
function LobbyStorageManager:_removeItemInstanceFromSection(section, instanceId, quantity, sectionIndex)
    local instance = section.items[instanceId]
    if not instance then
        error("AVISO [LobbyStorageManager]: Tentativa de remover instância de item inexistente: " .. tostring(instanceId))
    end

    Logger.debug("[LobbyStorageManager:_removeItemInstanceFromSection]",
        string.format("Removendo item %s (ID %s) da seção %d", instance.itemBaseId, instanceId, sectionIndex))
    local quantityToRemove = quantity or instance.quantity
    if instance.stackable and quantityToRemove < instance.quantity then
        -- Remove apenas uma parte da pilha
        instance.quantity = instance.quantity - quantityToRemove
        Logger.info("[LobbyStorageManager:_removeItemInstanceFromSection]",
            string.format("Item %s (ID %s) removido parcialmente da seção %d", instance.itemBaseId, instanceId,
                sectionIndex))
        return true
    else
        local actualW = instance.isRotated and instance.gridHeight or instance.gridWidth
        local actualH = instance.isRotated and instance.gridWidth or instance.gridHeight
        ItemGridLogic.clearGridArea(section.grid, section.rows, section.cols, instanceId, instance.row, instance.col,
            actualW, actualH)
        section.items[instanceId] = nil
        return true
    end
end

-- == Funções de Persistência ==

--- Salva o estado do armazenamento.
function LobbyStorageManager:saveStorage()
    Logger.info("[LobbyStorageManager:saveStorage]", "Salvando estado do armazenamento em " .. SAVE_FILE)

    local dataToSave = {
        activeSectionIndex = self.activeSectionIndex,
        sections = {}
    }

    -- Serializa apenas os dados necessários de cada seção
    for index, section in pairs(self.sections) do
        local serializableItems = {}
        for instanceId, itemInstance in pairs(section.items) do
            serializableItems[instanceId] = {
                instanceId = itemInstance.instanceId,
                itemBaseId = itemInstance.itemBaseId,
                quantity = itemInstance.quantity,
                row = itemInstance.row,
                col = itemInstance.col,
                isRotated = itemInstance.isRotated or false,
            }
        end

        dataToSave.sections[index] = {
            rows = section.rows,
            cols = section.cols,
            items = serializableItems
        }
    end

    PersistenceManager.saveData(SAVE_FILE, dataToSave)
    Logger.info("[LobbyStorageManager:saveStorage]", "Armazenamento salvo.")
end

--- Carrega o estado do armazenamento.
function LobbyStorageManager:loadStorage()
    Logger.info("[LobbyStorageManager:loadStorage]", "Carregando estado do armazenamento de " .. SAVE_FILE)
    local loadedData = PersistenceManager.loadData(SAVE_FILE)
    if not loadedData then
        Logger.warn("[LobbyStorageManager:loadStorage]", "Nenhum arquivo de save encontrado. Inicializando com padrões.")
        self:clearAllStorage() -- Garante que a primeira seção seja criada
        return
    end

    self.sections = {}
    self.activeSectionIndex = loadedData.activeSectionIndex or 1

    for index, savedSectionData in pairs(loadedData.sections or {}) do
        local newSection = self:_createEmptySection(
            savedSectionData.rows or DEFAULT_SECTION_ROWS,
            savedSectionData.cols or DEFAULT_SECTION_COLS,
            index -- Passa o índice aqui
        )

        local loadedItemsData = savedSectionData.items or {}
        for instanceId, savedItemData in pairs(loadedItemsData) do
            local baseData = self:_getItemBaseData(savedItemData.itemBaseId)
            if baseData then
                local newItemInstance = self.itemDataManager:createItemInstanceById(savedItemData.itemBaseId,
                    savedItemData.quantity)

                newItemInstance.instanceId = savedItemData.instanceId
                newItemInstance.row = savedItemData.row
                newItemInstance.col = savedItemData.col
                newItemInstance.isRotated = savedItemData.isRotated

                newSection.items[newItemInstance.instanceId] = newItemInstance

                local actualW = newItemInstance.isRotated and newItemInstance.gridHeight or newItemInstance.gridWidth
                local actualH = newItemInstance.isRotated and newItemInstance.gridWidth or newItemInstance.gridHeight
                ItemGridLogic.markGridOccupied(newSection.grid, newSection.rows, newSection.cols,
                    newItemInstance.instanceId,
                    newItemInstance.row, newItemInstance.col, actualW, actualH)
            else
                Logger.warn("[LobbyStorageManager:loadStorage]", string.format(
                    "AVISO [LobbyStorageManager]: Dados base não encontrados para item '%s' (instância %s) na seção %d. Item ignorado.",
                    savedItemData.itemBaseId, tostring(savedItemData.instanceId), index))
            end
        end
        self.sections[index] = newSection
    end

    -- Se, após carregar, não houver nenhuma seção, cria a primeira
    if self:getTotalSections() == 0 then
        print("[LobbyStorageManager] Nenhum dado de seção válido encontrado no save. Inicializando primeira seção.")
        self.sections[1] = self:_createEmptySection(self.sectionRows, self.sectionCols, 1)
        self.activeSectionIndex = 1
    end
end

--- Limpa completamente todo o armazenamento, removendo todas as seções e itens.
function LobbyStorageManager:clearAllStorage()
    Logger.info("[LobbyStorageManager:clearAllStorage]", "LIMPANDO TODO O ARMAZENAMENTO...")
    self.sections = {}
    self.sections[1] = self:_createEmptySection(self.sectionRows, self.sectionCols, 1)
    self.activeSectionIndex = 1
    -- self:saveStorage() -- Opcional: salvar imediatamente o estado vazio/inicial.
end

return LobbyStorageManager
