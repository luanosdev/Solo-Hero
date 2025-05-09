--[[
    Drop Manager
    Gerencia os drops de bosses e outros inimigos
]]

local DropEntity = require("src.entities.drop_entity")

---@class DropManager
---@field activeDrops table[] Lista de drops ativos no mundo
---@field playerManager PlayerManager Gerenciador do jogador
---@field enemyManager EnemyManager Gerenciador de inimigos
---@field runeManager RuneManager Gerenciador de runas
---@field floatingTextManager FloatingTextManager Gerenciador de textos flutuantes
---@field itemDataManager ItemDataManager Gerenciador de dados de itens
local DropManager = {
    activeDrops = {}, -- Lista de drops ativos no mundo
}

-- Adicione esta tabela dentro do DropManager, logo após a definição da tabela DropManager = {}
local raritySettings = {
    -- Raridades de Itens (Contagem de Feixes Aumentada)
    ["E"] = { color = { 0.8, 0.8, 0.8 }, height = 80, glow = 0.8, beamCount = 1 },  -- 1 total
    ["D"] = { color = { 0.2, 0.5, 1.0 }, height = 110, glow = 1.0, beamCount = 3 }, -- 3 total (1 central + 1 par)
    ["C"] = { color = { 1.0, 1.0, 0.2 }, height = 140, glow = 1.2, beamCount = 3 }, -- 3 total
    ["B"] = { color = { 1.0, 0.6, 0.0 }, height = 170, glow = 1.5, beamCount = 5 }, -- 5 total (1 central + 2 pares)
    ["A"] = { color = { 1.0, 0.2, 0.2 }, height = 200, glow = 1.8, beamCount = 7 }, -- 7 total (1 central + 3 pares)
}

--[[
    Inicializa o gerenciador de drops
    @param config (table): Tabela contendo as dependências { playerManager, enemyManager, runeManager, floatingTextManager, itemDataManager }
]]
function DropManager:init(config)
    config = config or {}
    self.activeDrops = {}
    -- Obtém managers da config
    self.playerManager = config.playerManager
    self.enemyManager = config.enemyManager
    self.runeManager = config.runeManager
    self.floatingTextManager = config.floatingTextManager
    self.itemDataManager = config.itemDataManager

    -- DEBUG: Print the type right after assignment
    print(string.format("[DropManager:init] self.itemDataManager type: %s", type(self.itemDataManager)))

    -- Validação
    if not self.playerManager or not self.enemyManager or not self.runeManager or not self.floatingTextManager or not self.itemDataManager then
        error("ERRO CRÍTICO [DropManager]: Uma ou mais dependências não foram injetadas!")
    end

    print("DropManager inicializado") -- Removido rank do mapa que não estava definido
end

--[[
    Processa os drops de uma entidade derrotada (Inimigo, MVP, Boss)
    Lê a dropTable da classe da entidade.
    @param entity A entidade que foi derrotada
]]
function DropManager:processEntityDrop(entity)
    -- Usa a posição da entidade como base para os drops
    local entityPosition = { x = entity.position.x, y = entity.position.y }

    -- Tenta processar a tabela de drops específica da entidade
    local entityClass = getmetatable(entity).__index
    local dropTable = entityClass and entityClass.dropTable

    if not dropTable then
        print(string.format("Aviso: Nenhuma dropTable encontrada para a classe %s",
            entityClass and entityClass.name or 'desconhecida'))
        return -- Sai se não houver tabela de drops
    end

    -- Determina qual sub-tabela usar (boss, mvp, ou normal)
    local dropsToProcess = nil
    if entity.isBoss then
        dropsToProcess = dropTable.boss
    elseif entity.isMVP then
        dropsToProcess = dropTable.mvp or dropTable.normal -- Fallback para normal se mvp não estiver definida
    else
        dropsToProcess = dropTable.normal
    end

    if not dropsToProcess then
        print(string.format("Aviso: Nenhuma sub-tabela de drop ('boss', 'mvp', ou 'normal') encontrada para %s (%s)",
            entity.name, entity.isBoss and 'Boss' or (entity.isMVP and 'MVP' or 'Normal')))
        return -- Sai se a sub-tabela apropriada não for encontrada
    end

    local dropsCreated = {}

    -- Processa drops garantidos
    if dropsToProcess.guaranteed then
        for _, dropConfig in ipairs(dropsToProcess.guaranteed) do
            if dropConfig.type == "item_pool" then
                if dropConfig.itemIds and #dropConfig.itemIds > 0 then
                    local randomIndex = love.math.random(#dropConfig.itemIds)
                    local selectedItemId = dropConfig.itemIds[randomIndex]
                    -- Cria um drop config temporário do tipo item com o ID selecionado
                    local finalDrop = { type = "item", itemId = selectedItemId, quantity = 1 }
                    print(string.format("Drop garantido (Pool -> %s): %s", selectedItemId, entity.name))
                    table.insert(dropsCreated, finalDrop)
                else
                    print("Aviso: Drop garantido do tipo 'item_pool' sem itemIds válidos.")
                end
            elseif dropConfig.type == "item" then -- Lida com itens/joias normais
                local amount = dropConfig.amount
                local count = 1
                if type(amount) == "table" then
                    count = math.random(amount.min, amount.max)
                elseif type(amount) == "number" then
                    count = amount
                end
                for _ = 1, count do
                    print(string.format("Drop garantido (%s): %s", entity.name, dropConfig.type))
                    table.insert(dropsCreated, dropConfig)
                end
            else
                print("Aviso: Tipo de drop garantido desconhecido:", dropConfig.type)
            end
        end
    end

    -- Processa drops com chance
    if dropsToProcess.chance then
        for _, dropConfig in ipairs(dropsToProcess.chance) do
            local chance = dropConfig.chance or 0
            if math.random() <= (chance / 100) then
                if dropConfig.type == "item_pool" then
                    if dropConfig.itemIds and #dropConfig.itemIds > 0 then
                        local randomIndex = love.math.random(#dropConfig.itemIds)
                        local selectedItemId = dropConfig.itemIds[randomIndex]
                        local finalDrop = { type = "item", itemId = selectedItemId, quantity = 1 }
                        print(string.format("Drop com chance (Pool -> %s): %s (%.1f%%)", selectedItemId, entity.name,
                            chance))
                        table.insert(dropsCreated, finalDrop)
                    else
                        print("Aviso: Drop com chance do tipo 'item_pool' sem itemIds válidos.")
                    end
                elseif dropConfig.type == "item" or dropConfig.type == "jewel" then
                    local amount = dropConfig.amount
                    local count = 1
                    if type(amount) == "table" then
                        count = math.random(amount.min, amount.max)
                    elseif type(amount) == "number" then
                        count = amount
                    end
                    for _ = 1, count do
                        print(string.format("Drop com chance (%s): %s (%.1f%%)", entity.name, dropConfig.type, chance))
                        table.insert(dropsCreated, dropConfig)
                    end
                else
                    print("Aviso: Tipo de drop com chance desconhecido:", dropConfig.type)
                end
            end
        end
    end

    -- Espalha os drops criados (se houver)
    if #dropsCreated > 0 then
        self:spreadDrops(dropsCreated, entityPosition)
    end
end

--[[
    Obtém as configurações visuais (cor, altura, brilho) para um drop.
    @param dropConfig A configuração do drop.
    @return table Cor {r, g, b}.
    @return number Altura do feixe.
    @return number Escala do brilho base.
]]
function DropManager:_getDropVisualSettings(dropConfig)
    local settingsKey = "E"
    local isItemWithRarity = false

    if dropConfig.type == "item" and dropConfig.itemId then
        local baseData = self.itemDataManager:getBaseItemData(dropConfig.itemId)
        if baseData and baseData.rarity then
            settingsKey = baseData.rarity
            isItemWithRarity = true
        end
    elseif raritySettings[dropConfig.type] then
        settingsKey = dropConfig.type
    end

    -- Lógica específica para Runas (se aplicável)
    -- if dropConfig.type == "rune" and dropConfig.rarity then ... end

    local finalSettings = raritySettings[settingsKey]
    if not finalSettings then
        print(string.format("Aviso crítico: Chave '%s' não encontrada em raritySettings. Usando 'E'.", settingsKey))
        finalSettings = raritySettings["E"]
    end

    -- Retorna todos os valores, incluindo beamCount (com fallback para 1)
    return finalSettings.color, finalSettings.height, finalSettings.glow, finalSettings.beamCount or 1
end

--[[
    Cria uma entidade de drop no mundo
    @param dropConfig Configuração do drop (ex: {type="rune", rarity="D"} ou {type="item", itemId="sword_01"})
    @param position Posição {x, y} do drop
]]
function DropManager:createDrop(dropConfig, position)
    -- Determina as propriedades visuais
    local color, height, glowScale, beamCount = self:_getDropVisualSettings(dropConfig)

    -- Cria a entidade passando beamCount também
    local dropEntity = DropEntity:new(position, dropConfig, color, height, glowScale, beamCount)
    table.insert(self.activeDrops, dropEntity)
    -- print(string.format("DropEntity criado em (%.1f, %.1f) para tipo: %s", position.x, position.y, dropConfig.type))
end

--[[
    Atualiza os drops ativos
    @param dt Delta time
]]
function DropManager:update(dt)
    for i = #self.activeDrops, 1, -1 do
        local drop = self.activeDrops[i]
        if drop:update(dt, self.playerManager) then
            -- Se o drop foi coletado, aplica seus efeitos
            self:applyDrop(drop.config) -- Passa a configuração original do drop
            table.remove(self.activeDrops, i)
        end
    end
end

--[[
    Aplica um drop ao jogador
    @param dropConfig A configuração do drop coletado (contém 'type' e outros dados)
]]
function DropManager:applyDrop(dropConfig)
    if dropConfig.type == "item" then
        print(string.format("Tentando coletar item: %s", dropConfig.itemId or 'ID Inválido'))
        if dropConfig.itemId then
            local itemBaseId = dropConfig.itemId
            local quantity = dropConfig.quantity or 1 -- Padrão para 1 se não especificado
            local addedQuantity = self.playerManager:addInventoryItem(itemBaseId, quantity)

            if addedQuantity > 0 then
                local baseData = self.itemDataManager:getBaseItemData(itemBaseId)
                local itemName = baseData and baseData.name or itemBaseId
                -- A cor do item não é mais passada diretamente, a raridade controlará a cor no FloatingTextManager
                local itemRarity = baseData and baseData.rarity or "E" -- Fallback para raridade comum "E"

                -- Posição inicial do texto flutuante (o Y será ajustado pelo baseOffsetY em FloatingText)
                local textPosition = self.playerManager.player.position
                local displayText = string.format("+%d %s", addedQuantity, itemName)

                self.floatingTextManager:addItemCollectedText(
                    textPosition,
                    displayText,
                    itemRarity,
                    self.playerManager.player -- O alvo para o texto seguir
                )
            else
                print(string.format("Falha ao coletar %s (Inventário cheio?).", itemBaseId))
            end
        else
            print("Aviso: Drop do tipo 'item' sem 'itemId' definido.")
        end
    else
        print("Aviso: Tipo de drop desconhecido ou não implementado em applyDrop:", dropConfig.type)
    end
end

--[[
    Desenha os drops ativos
]]
function DropManager:draw()
    for _, drop in ipairs(self.activeDrops) do
        drop:draw()
    end
end

--[[
    Função auxiliar para espalhar os drops em um círculo
    @param dropsToCreate (table) Lista de configurações de drop a serem criadas
    @param centerPosition (table) Posição {x, y} central para espalhar os drops
]]
function DropManager:spreadDrops(dropsToCreate, centerPosition)
    local dropCount = #dropsToCreate
    if dropCount == 0 then return end

    local spreadRadius = 30                     -- Raio do círculo onde os drops serão espalhados
    local angleStep = (2 * math.pi) / dropCount -- Ângulo entre cada drop
    if dropCount == 1 then spreadRadius = 0 end -- Se for só um drop, não espalha

    for i, dropConfig in ipairs(dropsToCreate) do
        local angle = angleStep * (i - 1) + (math.random() * 0.2 - 0.1) -- Adiciona aleatoriedade
        local dropX = centerPosition.x + (dropCount > 1 and math.cos(angle) * spreadRadius or 0)
        local dropY = centerPosition.y + (dropCount > 1 and math.sin(angle) * spreadRadius or 0)

        self:createDrop(dropConfig, { x = dropX, y = dropY })
    end
end

return DropManager
