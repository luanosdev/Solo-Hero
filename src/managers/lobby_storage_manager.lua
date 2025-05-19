local PersistenceManager = require("src.core.persistence_manager")
local ItemGridLogic = require("src.core.item_grid_logic")
local uuid = require("src.utils.uuid")
-- local ItemDataManager = require("src.managers.item_data_manager") -- Será injetado

---@class LobbyStorageManager
local LobbyStorageManager = {}
LobbyStorageManager.__index = LobbyStorageManager

local SAVE_FILE = "lobby_storage.dat"
local DEFAULT_SECTION_ROWS = 8
local DEFAULT_SECTION_COLS = 10
local STARTING_SECTIONS = 1

-- Contador para IDs únicos de instância de item DENTRO do storage
local nextInstanceId = 1

--- Cria uma nova instância do gerenciador de armazenamento do lobby.
--- @param itemDataManager ItemDataManager Instância do ItemDataManager.
--- @return LobbyStorageManager
function LobbyStorageManager:new(itemDataManager)
    print("[LobbyStorageManager] Criando nova instância...")
    local instance = setmetatable({}, LobbyStorageManager)
    instance.itemDataManager = itemDataManager
    if not instance.itemDataManager then
        print("ERRO CRÍTICO [LobbyStorageManager]: itemDataManager não foi injetado!")
        -- Considerar retornar nil ou lançar um erro aqui dependendo da política de erro
        return nil
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

    print(string.format("[LobbyStorageManager] Pronto. %d seções carregadas/inicializadas. Seção ativa: %d.",
        instance:getTotalSections(), instance.activeSectionIndex)) -- Usa getTotalSections para contagem correta

    return instance
end

--- Helper interno para criar a estrutura de uma seção vazia.
--- @param rows number Número de linhas.
--- @param cols number Número de colunas.
--- @return table Estrutura da seção.
function LobbyStorageManager:_createEmptySection(rows, cols)
    local section = {
        grid = {},  -- Grade 2D para referência rápida de ocupação (armazena instanceId ou nil)
        items = {}, -- Tabela de instâncias de itens na seção { [instanceId] = itemInstanceData }
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
--- @return boolean True se o índice for válido e a seção foi ativada, false caso contrário.
function LobbyStorageManager:setActiveSection(index)
    if self.sections[index] then
        self.activeSectionIndex = index
        print("[LobbyStorageManager] Seção ativa alterada para:", index)
        return true
    else
        print("[LobbyStorageManager] Tentativa de ativar seção inválida:", index)
        return false
    end
end

--- Obtém o índice da seção atualmente ativa.
--- @return number Índice da seção ativa.
function LobbyStorageManager:getActiveSectionIndex()
    return self.activeSectionIndex
end

--- Obtém o número total de seções de armazenamento disponíveis.
--- @return number Total de seções.
function LobbyStorageManager:getTotalSections()
    local count = 0
    for _ in pairs(self.sections) do
        count = count + 1
    end
    return count
end

--- Obtém a configuração (linhas, colunas) da seção ativa.
--- @return number, number Linhas e Colunas da seção ativa.
function LobbyStorageManager:getActiveSectionDimensions()
    local activeSection = self.sections[self.activeSectionIndex]
    if activeSection then
        return activeSection.rows, activeSection.cols
    end
    -- Fallback para padrões se algo der errado
    return self.sectionRows, self.sectionCols
end

--- NOVO: Obtém a instância do item em coordenadas específicas da grade da seção ativa ou especificada.
--- @param targetRow integer Linha alvo (1-indexed).
--- @param targetCol integer Coluna alvo (1-indexed).
--- @param sectionIndexParam integer (Opcional) Índice da seção a verificar. Usa seção ativa se nil.
--- @return table|nil A instância do item se encontrada, caso contrário nil.
function LobbyStorageManager:getItemInstanceAtCoords(targetRow, targetCol, sectionIndexParam)
    local sectionIdx = sectionIndexParam or self.activeSectionIndex
    local section = self.sections[sectionIdx]

    if not section or not section.items or not targetRow or not targetCol then
        return nil
    end
    print(string.format("  [LobbyStorageManager:getItemInstanceAtCoords] Section %d: Checking for item at [%d,%d]",
        sectionIdx, targetRow, targetCol))
    local itemCount = 0
    for _ in pairs(section.items) do itemCount = itemCount + 1 end
    print(string.format("    Total items in section %d: %d", sectionIdx, itemCount))

    for instanceId, item in pairs(section.items) do
        local itemOriginX, itemOriginY = item.col, item.row
        local itemDisplayW = item.isRotated and item.gridHeight or item.gridWidth
        local itemDisplayH = item.isRotated and item.gridWidth or item.gridHeight

        print(string.format("    S%d Checking item: %s (ID %s) at [%d,%d] size [%dx%d] (display: %dx%d, rotated: %s)",
            sectionIdx, item.itemBaseId, instanceId, itemOriginY, itemOriginX, item.gridWidth, item.gridHeight,
            itemDisplayW, itemDisplayH, tostring(item.isRotated)))

        -- Verifica se (targetRow, targetCol) está dentro da área ocupada pelo item
        if targetCol >= itemOriginX and targetCol < itemOriginX + itemDisplayW and
            targetRow >= itemOriginY and targetRow < itemOriginY + itemDisplayH then
            print(string.format("    S%d FOUND item: %s (ID %s) at coords [%d,%d]", sectionIdx, item.itemBaseId,
                instanceId, targetRow, targetCol))
            return item -- Encontrou o item que ocupa esta célula
        end
    end
    print(string.format("  [LobbyStorageManager:getItemInstanceAtCoords] S%d: No item found at [%d,%d]", sectionIdx,
        targetRow, targetCol))
    return nil -- Nenhum item encontrado nesta célula
end

-- == Funções de Manipulação de Itens (na Seção Ativa) ==

--- Obtém a tabela de itens da seção especificada (ou da ativa).
--- @param sectionIndex number (Opcional) Índice da seção. Se omitido, usa a seção ativa.
--- @return table Tabela de itens { [instanceId] = itemInstanceData } da seção, ou {} se inválido.
function LobbyStorageManager:getItems(sectionIndex)
    local indexToUse = sectionIndex or self.activeSectionIndex
    if self.sections[indexToUse] then
        return self.sections[indexToUse].items
    end
    return {} -- Retorna tabela vazia em vez de nil para evitar erros em loops
end

--- Adiciona um item (ou quantidade) à seção ativa.
-- Similar ao InventoryManager, tenta empilhar primeiro, depois encontrar espaço.
--- @param itemBaseId string ID base do item.
--- @param quantity number Quantidade a adicionar.
--- @return number Quantidade realmente adicionada.
function LobbyStorageManager:addItem(itemBaseId, quantity)
    local activeSection = self.sections[self.activeSectionIndex]
    if not activeSection then
        print("ERRO [LobbyStorageManager]: Tentando adicionar item sem seção ativa válida.")
        return 0
    end

    if not itemBaseId or not quantity or quantity <= 0 then return 0 end

    -- Delega para uma função auxiliar que opera na seção específica
    return self:_addItemToSection(activeSection, itemBaseId, quantity)
end

--- Remove uma instância específica de item da seção ativa.
--- @param instanceId number ID da instância a remover.
--- @param quantity number (Opcional) Quantidade a remover. Se omitido ou >= quantidade atual, remove tudo.
--- @return boolean True se removeu com sucesso.
function LobbyStorageManager:removeItemInstance(instanceId, quantity)
    local activeSection = self.sections[self.activeSectionIndex]
    if not activeSection then
        print("ERRO [LobbyStorageManager]: Tentando remover item sem seção ativa válida.")
        return false
    end

    -- Delega para função auxiliar
    return self:_removeItemInstanceFromSection(activeSection, instanceId, quantity)
end

--- Remove uma instância de item específica pelo ID, de qualquer seção.
-- Útil para drag-and-drop.
--- @param instanceId number ID da instância a remover.
--- @return boolean, number|nil Retorna true e o índice da seção se removeu, false e nil caso contrário.
function LobbyStorageManager:removeItemByInstanceId(instanceId)
    for index, section in pairs(self.sections) do
        if section.items[instanceId] then
            local success = self:_removeItemInstanceFromSection(section, instanceId, nil) -- Remove tudo
            if success then
                print(string.format("[LobbyStorageManager] Item %s removido da seção %d", instanceId, index))
                return true, index
            else
                -- Isso não deveria acontecer se o item foi encontrado, mas por segurança:
                print(string.format("ERRO [LobbyStorageManager] Falha ao remover item %s encontrado na seção %d",
                    instanceId, index))
                return false, index
            end
        end
    end
    print(string.format("AVISO [LobbyStorageManager] Tentativa de remover item %s (não encontrado)", instanceId))
    return false, nil -- Item não encontrado em nenhuma seção
end

--- Verifica se um item pode ser colocado em uma posição específica na seção ativa.
---@param item table Instância do item a ser colocado.
---@param targetRow integer Linha alvo (1-indexed).
---@param targetCol integer Coluna alvo (1-indexed).
---@param checkWidth integer|nil Largura a ser usada para a checagem (usa item.gridWidth se nil).
---@param checkHeight integer|nil Altura a ser usada para a checagem (usa item.gridHeight se nil).
---@return boolean True se o item pode ser colocado, false caso contrário.
function LobbyStorageManager:canPlaceItemAt(item, targetRow, targetCol, checkWidth, checkHeight)
    if not item or not targetRow or not targetCol then
        print("ERRO (canPlaceItemAt - Storage): Parâmetros inválidos.")
        return false
    end

    local section = self.sections[self.activeSectionIndex]
    if not section then
        print("ERRO (canPlaceItemAt - Storage): Seção ativa inválida:", self.activeSectionIndex)
        return false
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

--- Adiciona um item em uma posição específica na seção ativa.
--- Assume que canPlaceItemAt já foi chamado e retornou true.
---@param item table A instância do item a ser adicionado.
---@param targetRow integer Linha alvo (1-indexed).
---@param targetCol integer Coluna alvo (1-indexed).
---@param isRotated boolean|nil Se o item deve ser armazenado como rotacionado.
---@return boolean True se o item foi adicionado, false caso contrário.
function LobbyStorageManager:addItemAt(item, targetRow, targetCol, isRotated)
    if not item or not targetRow or not targetCol then
        print("ERRO (addItemAt - Storage): Parâmetros inválidos.")
        return false
    end
    local section = self.sections[self.activeSectionIndex]
    if not section then
        print(string.format("ERRO (addItemAt - Storage): Seção ativa inválida: %d", self.activeSectionIndex))
        return false
    end

    print(string.format(
        "[LobbyStorageManager:addItemAt] Tentando adicionar item ID %s (BaseID %s) na seção %d em [%d,%d], Rotacionado: %s",
        item.instanceId, item.itemBaseId, self.activeSectionIndex, targetRow, targetCol, tostring(isRotated)))
    print(string.format("  Item details: gridW=%d, gridH=%d, current qty=%d", item.gridWidth or 1, item.gridHeight or 1,
        item.quantity or 1))

    -- Log do estado ANTES da modificação
    local itemCountBefore = 0
    for _ in pairs(section.items) do itemCountBefore = itemCountBefore + 1 end
    print(string.format("  Estado ANTES: %d itens na seção. Item com mesmo instanceId (%s) já existe? %s",
        itemCountBefore, item.instanceId, tostring(section.items[item.instanceId] ~= nil)))
    if section.items[item.instanceId] then
        local existing = section.items[item.instanceId]
        print(string.format("    Detalhes do item existente com mesmo instanceId: BaseID %s, Qty %d, Pos [%d,%d]",
            existing.itemBaseId, existing.quantity, existing.row, existing.col))
    end

    -- Usa as dimensões REAIS do item (rotação NÃO é aplicada aqui, apenas armazenada)
    local itemW = item.gridWidth or 1
    local itemH = item.gridHeight or 1

    -- Atualiza a posição e o estado de rotação do item
    item.row = targetRow
    item.col = targetCol
    item.isRotated = isRotated or false           -- Armazena o estado de rotação
    item.storageSection = self.activeSectionIndex -- Marca em qual seção ele está

    -- Adiciona o item à lista da seção
    -- Se já existe (caso de mover item que foi pego da mesma seção), atualiza. Senão, adiciona.
    section.items[item.instanceId] = item

    local actualW = item.isRotated and itemH or itemW
    local actualH = item.isRotated and itemW or itemH

    print(string.format("  Marcando grid: instanceId %s, targetRow %d, targetCol %d, actualW %d, actualH %d",
        item.instanceId, targetRow, targetCol, actualW, actualH))
    ItemGridLogic.markGridOccupied(section.grid, section.rows, section.cols, item.instanceId, targetRow, targetCol,
        actualW, actualH)

    -- Log do estado DEPOIS da modificação
    local itemCountAfter = 0
    for _ in pairs(section.items) do itemCountAfter = itemCountAfter + 1 end
    print(string.format("  Estado DEPOIS: %d itens na seção.", itemCountAfter))
    if itemCountAfter < itemCountBefore then
        print("  ALERTA: Número de itens na seção diminuiu após addItemAt! Isso é inesperado.")
    end

    print(string.format("(Storage) Item %s (%s) adicionado/atualizado na seção %d em [%d,%d], Rotacionado: %s",
        item.instanceId, item.itemBaseId,
        self.activeSectionIndex, targetRow, targetCol, tostring(item.isRotated)))
    return true
end

--- NOVO: Tenta adicionar uma instância de item específica em qualquer espaço livre NA SEÇÃO ATIVA.
--- Utiliza _findFreeSpace e addItemAt.
--- @param itemInstance table A instância completa do item a adicionar.
--- @return boolean True se conseguiu adicionar, false caso contrário.
function LobbyStorageManager:addItemInstance(itemInstance)
    local activeSection = self.sections[self.activeSectionIndex]
    if not activeSection or not itemInstance then
        print("ERRO [LobbyStorageManager:addItemInstance]: Seção ativa inválida ou item inválido.")
        return false
    end

    local width = itemInstance.gridWidth or 1
    local height = itemInstance.gridHeight or 1
    local freeSpace = ItemGridLogic.findFreeSpace(activeSection.grid, activeSection.rows, activeSection.cols, width,
        height)

    if freeSpace then
        -- Reusa a lógica de addItemAt para colocar na seção ativa
        -- Passa isRotated como nil ou false por padrão aqui, pois estamos apenas adicionando, não movendo um item rotacionado
        return self:addItemAt(itemInstance, freeSpace.row, freeSpace.col, itemInstance.isRotated or false)
    else
        print(string.format("[LobbyStorageManager:addItemInstance] Sem espaço na seção ativa para item %d (%s)",
            itemInstance.instanceId, itemInstance.itemBaseId))
        return false
    end
end

-- == Funções Auxiliares de Item (Operam em uma Seção Específica) ==

--- Helper interno para obter dados base do item.
function LobbyStorageManager:_getItemBaseData(itemBaseId)
    -- Assume que itemDataManager tem um método getData ou similar
    if self.itemDataManager and self.itemDataManager.getData then
        return self.itemDataManager:getData(itemBaseId)
    elseif self.itemDataManager and self.itemDataManager.getBaseItemData then
        -- Fallback para o nome usado no InventoryManager, caso seja esse
        return self.itemDataManager:getBaseItemData(itemBaseId)
    else
        print("AVISO [LobbyStorageManager]: itemDataManager ausente ou método de busca de dados não encontrado.")
        return nil
    end
end

--- Helper interno para gerar ID único para instâncias DENTRO do storage.
function LobbyStorageManager:_getNextInstanceId()
    local id = nextInstanceId
    nextInstanceId = nextInstanceId + 1
    return id
end

--- Lógica principal para adicionar item a uma seção específica.
function LobbyStorageManager:_addItemToSection(section, itemBaseId, quantity)
    local baseData = self:_getItemBaseData(itemBaseId)
    if not baseData then
        print("ERRO [LobbyStorageManager]: Não foi possível obter dados para o item ID:", itemBaseId)
        return 0
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
                -- print(string.format("Empilhado %d em %s (ID %d). Total: %d/%d", amountToStack, itemBaseId, id, instance.quantity, maxStack))
                if remainingQuantity <= 0 then break end
            end
        end
    end

    -- 2. Tentar Colocar Novos Stacks/Itens
    while remainingQuantity > 0 do
        local amountForThisInstance = stackable and math.min(remainingQuantity, maxStack) or 1
        local freeSpace = ItemGridLogic.findFreeSpace(section.grid, section.rows, section.cols, width, height)

        if freeSpace then
            local instanceId = uuid.generate()
            local newItemInstance = {
                instanceId = instanceId,
                itemBaseId = itemBaseId,
                quantity = amountForThisInstance,
                row = freeSpace.row,
                col = freeSpace.col,
                isRotated = false,
                -- Inclui dados base para conveniência
                gridWidth = width,
                gridHeight = height,
                stackable = stackable,
                maxStack = maxStack,
                name = baseData.name, -- Adiciona o nome para facilitar debug/tooltips
                icon = baseData.icon, -- Adiciona o ícone diretamente se disponível nos dados base
                rarity = baseData.rarity or 'E'
            }
            -- <<< LOG ADICIONADO para verificar o ícone >>>
            print(string.format("  [_addItemToSection] Processando item %s. Tipo do baseData.icon: %s", itemBaseId,
                type(baseData.icon)))
            print(string.format("    -> Tipo do newItemInstance.icon: %s", type(newItemInstance.icon)))
            -- <<< FIM LOG >>>
            section.items[instanceId] = newItemInstance

            self:addItemAt(newItemInstance, freeSpace.row, freeSpace.col, newItemInstance.isRotated)

            addedQuantity = addedQuantity + amountForThisInstance
            remainingQuantity = remainingQuantity - amountForThisInstance

            if not stackable and remainingQuantity > 0 then
                -- print(string.format("Item %s não empilhável, procurando espaço para próxima instância.", itemBaseId))
            end
        else
            print(string.format("Sem espaço na seção ativa para %s (%dx%d).", itemBaseId, width, height))
            break -- Sai do loop se não encontrar espaço
        end
    end

    if remainingQuantity > 0 then
        print(string.format("Não foi possível adicionar %d de %s (seção cheia ou sem espaço adequado).",
            remainingQuantity, itemBaseId))
    end

    return addedQuantity
end

--- Lógica principal para remover item de uma seção específica.
function LobbyStorageManager:_removeItemInstanceFromSection(section, instanceId, quantity)
    local instance = section.items[instanceId]
    if not instance then
        print(string.format(
            "AVISO [LobbyStorageManager:_removeItemInstanceFromSection]: Tentativa de remover instância de item inexistente: %s na seção %d (seção ativa: %d)",
            tostring(instanceId), self:getSectionIndexForItem(instanceId) or -1, self.activeSectionIndex))
        return false
    end

    print(string.format(
        "[LobbyStorageManager:_removeItemInstanceFromSection] Removendo item ID %s (BaseID %s), Qty a remover: %s, Qty atual: %d",
        instance.instanceId, instance.itemBaseId, tostring(quantity or 'ALL'), instance.quantity))

    local quantityToRemove = quantity or instance.quantity

    if instance.stackable and quantityToRemove < instance.quantity then
        -- Remove apenas uma parte da pilha
        instance.quantity = instance.quantity - quantityToRemove
        -- print(string.format("Removido %d de %s (ID %d). Restante: %d", quantityToRemove, instance.itemBaseId, instanceId, instance.quantity))
        return true
    else
        -- Remove a instância inteira
        -- Limpa a grade
        -- Calcula dimensões REAIS de ocupação baseadas na rotação ARMAZENADA
        local itemW = instance.gridWidth or 1
        local itemH = instance.gridHeight or 1
        local actualW = instance.isRotated and itemH or itemW
        local actualH = instance.isRotated and itemW or itemH

        ItemGridLogic.clearGridArea(section.grid, section.rows, section.cols, instanceId, instance.row, instance.col,
            actualW, actualH)

        -- Remove da tabela de itens
        section.items[instanceId] = nil
        print(string.format("  Instância %s (BaseID %s) completamente removida da lista de itens da seção.", instanceId,
            instance.itemBaseId))
        return true
    end
end

-- Helper para encontrar a qual seção um item pertence (se existir)
function LobbyStorageManager:getSectionIndexForItem(instanceId)
    for index, sectionData in pairs(self.sections) do
        if sectionData.items[instanceId] then
            return index
        end
    end
    return nil
end

-- == Funções de Persistência ==

--- Salva o estado atual de todas as seções de armazenamento.
function LobbyStorageManager:saveStorage()
    print("[LobbyStorageManager] Solicitando salvamento do armazenamento...")
    local dataToSave = {
        version = 1, -- Para futuras migrações de formato
        activeSectionIndex = self.activeSectionIndex,
        sections = {},
        nextInstanceId = nextInstanceId -- Salva o próximo ID a ser usado
    }

    -- Serializa apenas os dados necessários de cada seção
    for index, section in pairs(self.sections) do
        local serializableItems = {}
        for id, item in pairs(section.items) do
            -- Salva apenas o essencial para recriar o item ao carregar
            serializableItems[id] = {
                itemBaseId = item.itemBaseId,
                quantity = item.quantity,
                row = item.row,
                col = item.col,
                isRotated = item.isRotated or false -- Salva o estado de rotação
                -- Não precisa salvar gridWidth/Height etc., pois são pegos do ItemDataManager ao carregar
            }
        end
        dataToSave.sections[index] = {
            items = serializableItems,
            rows = section.rows, -- Salva as dimensões caso possam mudar no futuro
            cols = section.cols
        }
    end

    local success = PersistenceManager.saveData(SAVE_FILE, dataToSave)
    if success then
        print("[LobbyStorageManager] Armazenamento salvo com sucesso.")
    else
        print("ERRO [LobbyStorageManager]: Falha ao salvar o armazenamento.")
    end
    return success
end

--- Carrega o estado do armazenamento do arquivo de save.
--- @return boolean True se carregou com sucesso, False caso contrário.
function LobbyStorageManager:loadStorage()
    print("[LobbyStorageManager] Tentando carregar armazenamento...")
    local loadedData = PersistenceManager.loadData(SAVE_FILE)

    if not loadedData or type(loadedData) ~= "table" then
        print("[LobbyStorageManager] Nenhum dado de save válido encontrado.")
        -- <<< ADICIONADO: Popula com itens iniciais se o save não existir >>>
        self:_initializeEmptyStorage()
        self:_populateInitialItems()
        -- <<< FIM ADIÇÃO >>>
        return false
    end

    if loadedData.version ~= 1 then
        print(string.format(
            "AVISO [LobbyStorageManager]: Versão do save (%s) incompatível com a atual (1). Tentando carregar mesmo assim...",
            tostring(loadedData.version)))
        -- Aqui poderia ter lógica de migração se necessário
    end

    -- Carrega o próximo ID de instância
    nextInstanceId = loadedData.nextInstanceId or 1 -- Usa 1 como fallback

    -- Carrega o índice da seção ativa
    self.activeSectionIndex = loadedData.activeSectionIndex or 1

    -- Limpa seções atuais antes de carregar
    self.sections = {}

    local sectionCount = 0
    local maxInstanceIdFound = 0 -- Para garantir que nextInstanceId seja maior que qualquer ID carregado

    -- Recria as seções e itens a partir dos dados salvos
    if loadedData.sections and type(loadedData.sections) == "table" then
        for index, sectionData in pairs(loadedData.sections) do
            -- Converte o índice para número, pois pode vir como string do JSON/serialização
            local numIndex = tonumber(index)
            if numIndex then
                local rows = sectionData.rows or DEFAULT_SECTION_ROWS
                local cols = sectionData.cols or DEFAULT_SECTION_COLS
                local newSection = self:_createEmptySection(rows, cols)

                if sectionData.items and type(sectionData.items) == "table" then
                    for id, itemSaveData in pairs(sectionData.items) do
                        local numInstanceId = tonumber(id)
                        if numInstanceId then
                            local baseData = self:_getItemBaseData(itemSaveData.itemBaseId)
                            if baseData then
                                local width = baseData.gridWidth or 1
                                local height = baseData.gridHeight or 1
                                -- <<< LOG ADICIONADO para verificar o ícone >>>
                                print(string.format("  [LoadStorage] Processando item %s. Tipo do baseData.icon: %s",
                                    itemSaveData.itemBaseId, type(baseData.icon)))
                                -- Recria a instância completa do item
                                local newItemInstance = {
                                    instanceId = numInstanceId,
                                    itemBaseId = itemSaveData.itemBaseId,
                                    quantity = itemSaveData.quantity,
                                    row = itemSaveData.row,
                                    col = itemSaveData.col,
                                    isRotated = itemSaveData.isRotated or false, -- Carrega o estado de rotação
                                    -- Adiciona dados base novamente
                                    gridWidth = width,
                                    gridHeight = height,
                                    stackable = baseData.stackable or false,
                                    maxStack = baseData.maxStack or (baseData.stackable and 99) or 1,
                                    name = baseData.name,
                                    icon = baseData.icon,
                                    rarity = baseData.rarity or 'E'
                                }
                                print(string.format("    -> Tipo do newItemInstance.icon: %s", type(newItemInstance.icon)))
                                -- <<< FIM LOG >>>
                                newSection.items[numInstanceId] = newItemInstance

                                -- Marca a grade da seção
                                for r = itemSaveData.row, itemSaveData.row + height - 1 do
                                    for c = itemSaveData.col, itemSaveData.col + width - 1 do
                                        if newSection.grid[r] and newSection.grid[r][c] == nil then
                                            newSection.grid[r][c] = numInstanceId
                                        else
                                            print(string.format(
                                                "ERRO/AVISO [LobbyStorageManager]: Célula de grid [%d,%d] inválida ou já ocupada ao carregar item %d (%s). Verifique save ou lógica.",
                                                r, c, numInstanceId, itemSaveData.itemBaseId))
                                        end
                                    end
                                end
                                -- Atualiza o maior ID encontrado
                                maxInstanceIdFound = math.max(maxInstanceIdFound, numInstanceId)
                            else
                                print(string.format(
                                    "AVISO [LobbyStorageManager]: Não foi possível encontrar dados base para o item ID '%s' (instância %d) ao carregar save. Item ignorado.",
                                    tostring(itemSaveData.itemBaseId), numInstanceId))
                            end
                        else
                            print(string.format(
                                "AVISO [LobbyStorageManager]: ID de instância inválido ('%s') encontrado ao carregar itens da seção %d. Ignorando.",
                                tostring(id), numIndex))
                        end
                    end
                end
                self.sections[numIndex] = newSection -- Usa índice numérico
                sectionCount = sectionCount + 1
            else
                print(string.format(
                    "AVISO [LobbyStorageManager]: Índice de seção inválido ('%s') encontrado ao carregar. Ignorando seção.",
                    tostring(index)))
            end
        end
    end

    -- Garante que o próximo ID seja maior que qualquer ID carregado
    if nextInstanceId <= maxInstanceIdFound then
        print(string.format(
            "AVISO [LobbyStorageManager]: nextInstanceId (%d) era menor ou igual ao maior ID carregado (%d). Ajustando para %d.",
            nextInstanceId, maxInstanceIdFound, maxInstanceIdFound + 1))
        nextInstanceId = maxInstanceIdFound + 1
    end

    print(string.format(
        "[LobbyStorageManager] Carregamento concluído. %d seções carregadas. Seção ativa: %d. Próximo ID: %d",
        sectionCount, self.activeSectionIndex, nextInstanceId))

    -- Se nenhuma seção foi carregada (arquivo de save existia mas estava vazio/corrompido nas seções?)
    if sectionCount == 0 then
        print("[LobbyStorageManager] Nenhuma seção encontrada nos dados carregados. Inicializando com seção padrão.")
        self.sections[1] = self:_createEmptySection(self.sectionRows, self.sectionCols)
        self.activeSectionIndex = 1
        nextInstanceId = 1 -- Reseta ID se começou do zero
        -- <<< ADICIONADO: Popula a seção recém-criada >>>
        self:_populateInitialItems()
        -- <<< FIM ADIÇÃO >>>
        return false -- Indica que o carregamento não foi totalmente bem-sucedido em termos de conteúdo
    end

    -- Garante que activeSectionIndex seja válido após o carregamento
    if not self.sections[self.activeSectionIndex] then
        print(string.format(
            "AVISO [LobbyStorageManager]: activeSectionIndex (%d) inválido após carregar. Resetando para 1.",
            self.activeSectionIndex))
        self.activeSectionIndex = 1
    end

    return true
end

--- Helper para inicializar armazenamento vazio (quando save falha ou não existe).
function LobbyStorageManager:_initializeEmptyStorage()
    print("[LobbyStorageManager] Inicializando armazenamento vazio...")
    self.sections = {}
    for i = 1, STARTING_SECTIONS do
        self.sections[i] = self:_createEmptySection(self.sectionRows, self.sectionCols)
    end
    self.activeSectionIndex = 1
    nextInstanceId = 1 -- Reseta contador de ID
end

--- Helper para adicionar itens iniciais (chamado após _initializeEmptyStorage).
function LobbyStorageManager:_populateInitialItems()
    print("[LobbyStorageManager] Populando com itens iniciais...")
    local section = self.sections[1] -- Popula a primeira seção
    if not section then
        print("ERRO: Seção 1 não encontrada ao popular itens iniciais.")
        return
    end

    -- Adicione chamadas a _addItemToSection aqui
    self:_addItemToSection(section, "chain_laser", 1)
    self:_addItemToSection(section, "bow", 1)
    self:_addItemToSection(section, "flamethrower", 1)
    self:_addItemToSection(section, "dual_daggers", 1)
    self:_addItemToSection(section, "wooden_sword", 1)
    self:_addItemToSection(section, "hammer", 1)
end

return LobbyStorageManager
