local PersistenceManager = require("src.core.persistence_manager")
-- local ItemDataManager = require("src.managers.item_data_manager") -- Será injetado

--- Gerencia o armazenamento persistente do jogador no Lobby (baú com seções).
local LobbyStorageManager = {}
LobbyStorageManager.__index = LobbyStorageManager

local SAVE_FILE = "lobby_storage.dat"
local DEFAULT_SECTION_ROWS = 8
local DEFAULT_SECTION_COLS = 10
local STARTING_SECTIONS = 1

-- Contador para IDs únicos de instância de item DENTRO do storage
local nextInstanceId = 1

--- Cria uma nova instância do gerenciador de armazenamento do lobby.
--- @param itemDataManager Instância do ItemDataManager.
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

    -- Tenta carregar dados existentes
    if not instance:loadStorage() then
        print("[LobbyStorageManager] Nenhum save encontrado. Inicializando com seções padrão.")
        -- Inicializa com o número padrão de seções vazias se o carregamento falhar
        for i = 1, STARTING_SECTIONS do
            instance.sections[i] = instance:_createEmptySection(instance.sectionRows, instance.sectionCols)
        end
        -- Reseta IDs se está começando do zero
        nextInstanceId = 1
    end

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

--- Helper interno para verificar se uma área está livre em uma seção específica.
--- @param section table A seção a ser verificada.
--- @param startRow number Linha inicial.
--- @param startCol number Coluna inicial.
--- @param width number Largura do item.
--- @param height number Altura do item.
--- @return boolean True se a área estiver livre.
function LobbyStorageManager:_isAreaFree(section, startRow, startCol, width, height)
    if startRow < 1 or startRow + height - 1 > section.rows or startCol < 1 or startCol + width - 1 > section.cols then
        return false
    end
    for r = startRow, startRow + height - 1 do
        for c = startCol, startCol + width - 1 do
            -- Verifica se a célula existe antes de acessar
            if not section.grid[r] or section.grid[r][c] ~= nil then
                return false -- Célula fora dos limites ou ocupada
            end
        end
    end
    return true
end

--- Helper interno para encontrar espaço livre em uma seção específica.
--- @param section table A seção onde procurar.
--- @param width number Largura do item.
--- @param height number Altura do item.
--- @return table|nil Posição {row, col} ou nil se não encontrar.
function LobbyStorageManager:_findFreeSpace(section, width, height)
    for r = 1, section.rows - height + 1 do
        for c = 1, section.cols - width + 1 do
            if self:_isAreaFree(section, r, c, width, height) then
                return { row = r, col = c }
            end
        end
    end
    return nil
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
        local freeSpace = self:_findFreeSpace(section, width, height)

        if freeSpace then
            local instanceId = self:_getNextInstanceId()
            local newItemInstance = {
                instanceId = instanceId,
                itemBaseId = itemBaseId,
                quantity = amountForThisInstance,
                row = freeSpace.row,
                col = freeSpace.col,
                -- Inclui dados base para conveniência
                gridWidth = width,
                gridHeight = height,
                stackable = stackable,
                maxStack = maxStack,
                name = baseData.name, -- Adiciona o nome para facilitar debug/tooltips
                icon = baseData.icon, -- Adiciona o ícone diretamente se disponível nos dados base
                -- Outros dados como rarity, description podem ser adicionados aqui
            }
            section.items[instanceId] = newItemInstance

            -- Marcar a grade
            for r = freeSpace.row, freeSpace.row + height - 1 do
                for c = freeSpace.col, freeSpace.col + width - 1 do
                    if section.grid[r] then -- Garante que a linha existe
                        section.grid[r][c] = instanceId
                    end
                end
            end

            addedQuantity = addedQuantity + amountForThisInstance
            remainingQuantity = remainingQuantity - amountForThisInstance
            -- print(string.format("Colocado novo item/stack %s (ID %d) em [%d,%d] q: %d", itemBaseId, instanceId, freeSpace.row, freeSpace.col, amountForThisInstance))

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
        print("AVISO [LobbyStorageManager]: Tentativa de remover instância de item inexistente:", instanceId)
        return false
    end

    local quantityToRemove = quantity or instance.quantity

    if instance.stackable and quantityToRemove < instance.quantity then
        -- Remove apenas uma parte da pilha
        instance.quantity = instance.quantity - quantityToRemove
        -- print(string.format("Removido %d de %s (ID %d). Restante: %d", quantityToRemove, instance.itemBaseId, instanceId, instance.quantity))
        return true
    else
        -- Remove a instância inteira
        -- Limpa a grade
        for r = instance.row, instance.row + (instance.gridHeight or 1) - 1 do
            for c = instance.col, instance.col + (instance.gridWidth or 1) - 1 do
                if section.grid[r] then -- Verifica se a linha existe
                    section.grid[r][c] = nil
                end
            end
        end
        -- Remove da tabela de itens
        section.items[instanceId] = nil
        -- print(string.format("Removida instância %d (%s) da seção.", instanceId, instance.itemBaseId))
        return true
    end
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
                col = item.col
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
        print("[LobbyStorageManager] Nenhum dado de save válido encontrado para o armazenamento.")
        return false
    end

    -- Verifica versão (para compatibilidade futura)
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
                                -- Recria a instância completa do item
                                local newItemInstance = {
                                    instanceId = numInstanceId,
                                    itemBaseId = itemSaveData.itemBaseId,
                                    quantity = itemSaveData.quantity,
                                    row = itemSaveData.row,
                                    col = itemSaveData.col,
                                    -- Adiciona dados base novamente
                                    gridWidth = width,
                                    gridHeight = height,
                                    stackable = baseData.stackable or false,
                                    maxStack = baseData.maxStack or (baseData.stackable and 99) or 1,
                                    name = baseData.name,
                                    icon = baseData.icon
                                    -- Adicionar outros dados base aqui se necessário
                                }
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
        return false       -- Indica que o carregamento não foi totalmente bem-sucedido em termos de conteúdo
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

return LobbyStorageManager
