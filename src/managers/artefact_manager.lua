------------------------------------------------------------------------------------------------
-- ArtefactManager.lua
-- Gerencia os Artefatos Dimensionais coletados pelo jogador
------------------------------------------------------------------------------------------------

local PersistenceManager = require("src.core.persistence_manager")
local artefactDefinitions = require("src.data.artefacts")
local artefactDrops = require("src.data.artefact_drops")

---@class ArtefactManager
---@field collectedArtefacts table<string, number> Artefatos coletados (id -> quantidade)
---@field filename string Nome do arquivo de persistência
---@field artefactDefinitions table<string, ArtefactDefinition> Definições dos artefatos
local ArtefactManager = {}
ArtefactManager.__index = ArtefactManager

--- Cria uma nova instância do ArtefactManager
---@return ArtefactManager
function ArtefactManager:new()
    local instance = setmetatable({}, ArtefactManager)
    instance.collectedArtefacts = {}
    instance.filename = "artefacts.dat"
    instance.artefactDefinitions = artefactDefinitions

    -- Carrega ícones dos artefatos
    instance:loadArtefactIcons()

    return instance
end

--- Carrega os ícones dos artefatos
function ArtefactManager:loadArtefactIcons()
    Logger.info("artefact_manager.load_icon", "[ArtefactManager] Iniciando carregamento de ícones...")

    local loadedCount = 0
    local failedCount = 0

    for artefactId, artefactData in pairs(self.artefactDefinitions) do
        if artefactData.icon and type(artefactData.icon) == "string" then
            local iconPath = artefactData.icon
            Logger.info("artefact_manager.load_icon",
                "[ArtefactManager] Tentando carregar: " .. iconPath)

            local success, iconImage = pcall(love.graphics.newImage, iconPath)
            if success then
                -- Substitui o caminho pela imagem carregada
                artefactData.icon = iconImage
                loadedCount = loadedCount + 1
                Logger.info("artefact_manager.load_icon",
                    "[ArtefactManager] ✓ Ícone carregado para " ..
                    artefactData.name .. ": " .. artefactData.icon:getWidth() .. "x" .. artefactData.icon:getHeight())
            else
                failedCount = failedCount + 1
                Logger.warn("artefact_manager.load_icon",
                    "[ArtefactManager] ✗ Falha ao carregar ícone para " ..
                    artefactData.name .. " (" .. iconPath .. "): " .. tostring(iconImage))
                artefactData.icon = nil
            end
        else
            Logger.warn("artefact_manager.load_icon",
                "[ArtefactManager] Ícone inválido para " .. artefactData.name .. ": " .. tostring(artefactData.icon))
        end
    end

    Logger.info("artefact_manager.load_icon",
        "[ArtefactManager] Carregamento concluído. Sucessos: " .. loadedCount .. ", Falhas: " .. failedCount)
end

--- Inicializa o gerenciador carregando dados salvos
function ArtefactManager:initialize()
    self:loadData()
    Logger.info("artefact_manager.initialize", "[ArtefactManager:initialize] Sistema de artefatos inicializado")
end

--- Carrega dados dos artefatos coletados
function ArtefactManager:loadData()
    local data = PersistenceManager.loadData(self.filename)
    if data and data.collectedArtefacts then
        self.collectedArtefacts = data.collectedArtefacts
        Logger.info(
            "artefact_manager.load",
            "[ArtefactManager:loadData] Artefatos carregados: " .. self:getTotalArtefactsCount() .. " total"
        )
    else
        -- Inicializa vazio para novos jogadores
        self.collectedArtefacts = {}
        Logger.info("artefact_manager.load", "[ArtefactManager:loadData] Nova coleção de artefatos criada")
        self:saveData()
    end
end

--- Salva dados dos artefatos coletados
function ArtefactManager:saveData()
    local data = {
        collectedArtefacts = self.collectedArtefacts
    }

    local success = PersistenceManager.saveData(self.filename, data)
    if success then
        Logger.info("artefact_manager.save", "[ArtefactManager:saveData] Artefatos salvos com sucesso")
    else
        Logger.error("artefact_manager.save", "[ArtefactManager:saveData] Falha ao salvar artefatos")
    end
end

--- Adiciona artefatos à coleção
---@param artefactId string ID do artefato
---@param quantity number Quantidade a adicionar
---@return boolean success Se a adição foi bem-sucedida
function ArtefactManager:addArtefact(artefactId, quantity)
    if not artefactId or quantity <= 0 then
        Logger.warn(
            "artefact_manager.add_artefact",
            "[ArtefactManager:addArtefact] Parâmetros inválidos: ID=" ..
            tostring(artefactId) .. ", Qty=" .. tostring(quantity)
        )
        return false
    end

    -- Verifica se o artefato existe nas definições
    if not self.artefactDefinitions[artefactId] then
        Logger.warn(
            "artefact_manager.add_artefact",
            "[ArtefactManager:addArtefact] Artefato desconhecido: " .. artefactId
        )
        return false
    end

    -- Adiciona à coleção
    self.collectedArtefacts[artefactId] = (self.collectedArtefacts[artefactId] or 0) + quantity

    local artefactData = self.artefactDefinitions[artefactId]
    Logger.info(
        "artefact_manager.add_artefact",
        "[ArtefactManager:addArtefact] +" .. quantity .. "x " .. artefactData.name ..
        ". Total: " .. self.collectedArtefacts[artefactId]
    )

    -- Exibir notificação de coleta de artefato
    if NotificationDisplay and artefactData then
        NotificationDisplay.showItemPickup(artefactData.name, quantity, artefactData.icon, artefactData.rank)
        Logger.debug("artefact_manager.notification.pickup",
            "[ArtefactManager:addArtefact] Notificação de artefato exibida: " .. artefactData.name .. " x" .. quantity)
    end

    return true
end

--- Remove artefatos da coleção
---@param artefactId string ID do artefato
---@param quantity number Quantidade a remover
---@return boolean success Se a remoção foi bem-sucedida
function ArtefactManager:removeArtefact(artefactId, quantity)
    if not artefactId or quantity <= 0 then
        return false
    end

    local currentQuantity = self.collectedArtefacts[artefactId] or 0
    if currentQuantity < quantity then
        Logger.warn(
            "artefact_manager.remove_artefact",
            "[ArtefactManager:removeArtefact] Quantidade insuficiente. ID=" .. artefactId ..
            ", Solicitado=" .. quantity .. ", Disponível=" .. currentQuantity
        )
        return false
    end

    self.collectedArtefacts[artefactId] = currentQuantity - quantity

    -- Remove da tabela se chegou a zero
    if self.collectedArtefacts[artefactId] <= 0 then
        self.collectedArtefacts[artefactId] = nil
    end

    local artefactData = self.artefactDefinitions[artefactId]
    Logger.info(
        "artefact_manager.remove_artefact",
        "[ArtefactManager:removeArtefact] -" ..
        quantity .. "x " .. (artefactData and artefactData.name or artefactId) ..
        ". Restante: " .. (self.collectedArtefacts[artefactId] or 0)
    )

    return true
end

--- Obtém a quantidade de um artefato específico
---@param artefactId string ID do artefato
---@return number quantity Quantidade coletada
function ArtefactManager:getArtefactQuantity(artefactId)
    return self.collectedArtefacts[artefactId] or 0
end

--- Obtém todos os artefatos coletados
---@return table<string, number> collectedArtefacts Tabela de artefatos (id -> quantidade)
function ArtefactManager:getAllArtefacts()
    return self.collectedArtefacts
end

--- Obtém a definição de um artefato específico
---@param artefactId string ID do artefato
---@return ArtefactDefinition|nil artefactData Dados do artefato ou nil se não encontrado
function ArtefactManager:getArtefactDefinition(artefactId)
    return self.artefactDefinitions[artefactId]
end

--- Conta o total de artefatos coletados
---@return number totalCount Total de artefatos
function ArtefactManager:getTotalArtefactsCount()
    local total = 0
    for _, quantity in pairs(self.collectedArtefacts) do
        total = total + quantity
    end
    return total
end

--- Calcula o valor total dos artefatos coletados
---@return number totalValue Valor total em ouro
function ArtefactManager:getTotalArtefactsValue()
    local totalValue = 0
    for artefactId, quantity in pairs(self.collectedArtefacts) do
        local artefactData = self.artefactDefinitions[artefactId]
        if artefactData then
            totalValue = totalValue + (artefactData.value * quantity)
        end
    end
    return totalValue
end

--- Vende todos os artefatos coletados
---@return number totalValue Valor total vendido
function ArtefactManager:sellAllArtefacts()
    local patrimonyManager = getManager("PatrimonyManager")
    local totalValue = self:getTotalArtefactsValue()

    if totalValue <= 0 then
        Logger.info("artefact_manager.sell_all", "[ArtefactManager:sellAllArtefacts] Nenhum artefato para vender")
        return 0
    end

    -- Registra os artefatos vendidos para log
    local soldItems = {}
    for artefactId, quantity in pairs(self.collectedArtefacts) do
        local artefactData = self.artefactDefinitions[artefactId]
        if artefactData then
            table.insert(soldItems, quantity .. "x " .. artefactData.name)
        end
    end

    -- Limpa a coleção
    self.collectedArtefacts = {}

    -- Adiciona ouro ao patrimônio
    if patrimonyManager then
        patrimonyManager:addGold(totalValue, "artefacts_bulk_sale")
    end

    Logger.info(
        "artefact_manager.sell_all",
        "[ArtefactManager:sellAllArtefacts] Vendidos artefatos por " .. totalValue .. " gold: " ..
        table.concat(soldItems, ", ")
    )

    self:saveData()
    return totalValue
end

--- Processa drops de artefatos quando um inimigo morre
---@param artefactDrops ArtefactDropTable Drops de artefatos
---@param isMvp boolean Se é um MVP
---@param luckMultiplier number Multiplicador de sorte
function ArtefactManager:processEnemyDrop(artefactDrops, isMvp, luckMultiplier)
    if (artefactDrops == nil) then
        Logger.error("artefact_manager.process_enemy_drop", "[ArtefactManager:processEnemyDrop] ArtefactDrops is nil")
        return
    end

    local dropTable = isMvp and artefactDrops.mvp or artefactDrops.normal

    -- Processa drops garantidos
    for _, drop in ipairs(dropTable.guaranteed or {}) do
        if drop.type == "artefact" then
            local amount = 1
            if drop.amount then
                amount = math.random(drop.amount.min, drop.amount.max)
            end
            self:addArtefact(drop.artefactId, amount)
        end
    end

    -- Processa drops por chance
    for _, drop in ipairs(dropTable.chance or {}) do
        if drop.type == "artefact" then
            local roll = math.random(1, 100) * luckMultiplier
            if roll <= drop.chance then
                local amount = 1
                if drop.amount then
                    amount = math.random(drop.amount.min, drop.amount.max)
                end
                self:addArtefact(drop.artefactId, amount)
            end
        end
    end
end

return ArtefactManager
