--[[
    Drop Manager
    Gerencia os drops de bosses e outros inimigos
]]

local ManagerRegistry = require("src.managers.manager_registry")
local DropEntity = require("src.entities.drop_entity")
local Jewel = require("src.items.jewel")

local DropManager = {
    activeDrops = {}, -- Lista de drops ativos no mundo
    mapRank = "E", -- Rank base do mapa atual (pode ser carregado de outro lugar no futuro)
    enemyDropChance = 0.10, -- 10% de chance de um inimigo normal dropar joia
    mvpDropChance = 0.50, -- 50% de chance de um MVP dropar joia de rank superior
    bossHigherRankDropChance = 0.75, -- 75% de chance do boss dropar joias de rank +1
    bossHigherRankDropAmount = {min = 1, max = 3}, -- Quantidade de joias rank +1 que o boss pode dropar
}

--[[
    Inicializa o gerenciador de drops
    @param config (table): Tabela contendo as dependências { playerManager, enemyManager, runeManager, floatingTextManager, itemDataManager, mapRank }
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
    self.mapRank = config.mapRank or "E" 

    -- Validação
    if not self.playerManager or not self.enemyManager or not self.runeManager or not self.floatingTextManager or not self.itemDataManager then
        error("ERRO CRÍTICO [DropManager]: Uma ou mais dependências não foram injetadas!")
    end

    print("DropManager inicializado com rank de mapa:", self.mapRank)
end

--[[
    Processa os drops de um inimigo derrotado (Normal ou MVP)
    @param enemy O inimigo que foi derrotado
]]
function DropManager:processEnemyDrop(enemy)
    local dropConfig = nil

    if enemy.isMVP then
        -- MVP: Chance de dropar joia de rank +1
        if math.random() <= self.mvpDropChance then
            local jewelRank = Jewel.getNextRank(self.mapRank, 1)
            local jewelDetails = Jewel.getRankDetails(jewelRank)
            print(string.format("MVP dropou Joia: [%s] %s %s", jewelRank, jewelDetails.prefix, jewelDetails.name))
            dropConfig = { type = "jewel", rank = jewelRank }
        end
    else
        -- Inimigo Normal: Chance de dropar joia do rank do mapa
        if math.random() <= self.enemyDropChance then
             local jewelDetails = Jewel.getRankDetails(self.mapRank)
             print(string.format("Inimigo dropou Joia: [%s] %s %s", self.mapRank, jewelDetails.prefix, jewelDetails.name))
            dropConfig = { type = "jewel", rank = self.mapRank }
        end
    end

    -- Se um drop foi determinado, cria a entidade
    if dropConfig then
        -- Cria o drop na posição do inimigo
        self:createDrop(dropConfig, {x = enemy.position.x, y = enemy.position.y})
    end
end

--[[
    Processa os drops de um boss derrotado
    @param boss O boss que foi derrotado
]]
function DropManager:processBossDrops(boss)
    -- Obtém a configuração de drops do mundo atual
    local worldConfig = self.enemyManager.worldConfig
    if not worldConfig or not worldConfig.bossConfig or not worldConfig.bossConfig.drops then
        print("Aviso: Configuração de drops não encontrada para o mundo atual")
        return
    end

    local bossDropTable = worldConfig.bossConfig.drops[boss.class]
    if not bossDropTable then
        print("Aviso: Configuração de drops não encontrada para o boss:", boss.class.name)
        return
    end

    print("Processando drops do boss:", boss.class.name)

    -- Lista para armazenar todos os drops que serão criados
    local dropsToCreate = {}

    -- 1. Adiciona drops garantidos da tabela de configuração (ex: runas, ouro)
    if bossDropTable.guaranteed then
        for _, drop in ipairs(bossDropTable.guaranteed) do
            print("Criando drop garantido (config):", drop.type)
            table.insert(dropsToCreate, drop)
        end
    end

    -- 2. Adiciona drop GARANTIDO de Joia Rank+2
    local guaranteedJewelRank = Jewel.getNextRank(self.mapRank, 2)
    local guaranteedJewelDetails = Jewel.getRankDetails(guaranteedJewelRank)
    print(string.format("Criando drop garantido: Joia [%s] %s %s", guaranteedJewelRank, guaranteedJewelDetails.prefix, guaranteedJewelDetails.name))
    table.insert(dropsToCreate, { type = "jewel", rank = guaranteedJewelRank })

    -- 3. Processa drops com chance da tabela de configuração
    if bossDropTable.chance then
        for _, drop in ipairs(bossDropTable.chance) do
             local chance = drop.chance or drop.weight -- Compatibilidade
             if chance and math.random() <= (chance / 100) then
                print("Criando drop com chance (config):", drop.type)
                table.insert(dropsToCreate, drop)
            end
        end
    end

    -- 4. Processa drop com CHANCE de Joias Rank+1
    if math.random() <= self.bossHigherRankDropChance then
        local amount = math.random(self.bossHigherRankDropAmount.min, self.bossHigherRankDropAmount.max)
        local higherJewelRank = Jewel.getNextRank(self.mapRank, 1)
        local higherJewelDetails = Jewel.getRankDetails(higherJewelRank)
        print(string.format("Criando %d drop(s) com chance: Joia [%s] %s %s", amount, higherJewelRank, higherJewelDetails.prefix, higherJewelDetails.name))
        for _ = 1, amount do
            table.insert(dropsToCreate, { type = "jewel", rank = higherJewelRank })
        end
    end

    -- Espalha os drops em um círculo ao redor do boss
    local dropCount = #dropsToCreate
    if dropCount == 0 then return end -- Sai se não houver drops

    local spreadRadius = 30 -- Raio do círculo onde os drops serão espalhados
    local angleStep = (2 * math.pi) / dropCount -- Ângulo entre cada drop

    for i, drop in ipairs(dropsToCreate) do
        -- Calcula o ângulo para este drop
        local angle = angleStep * (i - 1) + (math.random() * 0.2 - 0.1) -- Adiciona aleatoriedade

        -- Calcula a posição do drop no círculo
        local dropX = boss.position.x + math.cos(angle) * spreadRadius
        local dropY = boss.position.y + math.sin(angle) * spreadRadius

        self:createDrop(drop, {x = dropX, y = dropY})
    end
end

--[[
    Cria uma entidade de drop no mundo
    @param dropConfig Configuração do drop (ex: {type="rune", rarity="D"} ou {type="jewel", rank="C"})
    @param position Posição {x, y} do drop
]]
function DropManager:createDrop(dropConfig, position)
    -- Passa a configuração diretamente para DropEntity
    local dropEntity = DropEntity:new(position, dropConfig)
    table.insert(self.activeDrops, dropEntity)
    -- print(string.format("DropEntity criado em (%.1f, %.1f) para tipo: %s", position.x, position.y, dropConfig.type)) -- Log mais genérico
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
    if dropConfig.type == "rune" then
        print("Coletado: Runa de raridade:", dropConfig.rarity)
        local rune = self.runeManager:generateRune(dropConfig.rarity)
        self.runeManager:applyRune(rune)

    elseif dropConfig.type == "jewel" then
        print(string.format("[DEBUG] Depois de require ItemDetailsModal - Tipo: %s", type(ItemDetailsModal))) -- DEBUG (Corrigido)
        -- Construir o ID base da joia
        local itemBaseId = dropConfig.type .. "_" .. dropConfig.rank 
        
        -- Tenta adicionar ao inventário usando o ID base
        -- PlayerManager.addInventoryItem agora retorna a quantidade realmente adicionada (0 ou 1 neste caso)
        local addedQuantity = self.playerManager:addInventoryItem(itemBaseId, 1)

        -- Só mostra texto flutuante se foi adicionado com sucesso
        if addedQuantity > 0 then
            -- Obter dados base para nome e cor (do ItemDataManager)
            local baseData = nil
            local itemName = itemBaseId -- Fallback
            local itemColor = {1, 1, 1} -- Cor branca como fallback
            if self.itemDataManager then
                baseData = self.itemDataManager:getBaseItemData(itemBaseId)
                if baseData then
                    itemName = baseData.name or itemName
                    itemColor = baseData.color or itemColor
                end
            end

            -- Mostra texto flutuante
            self.floatingTextManager:addText(
                self.playerManager.player.position.x,
                self.playerManager.player.position.y - self.playerManager.radius - 30,
                "+ " .. itemName, 
                true,
                self.playerManager.player.position,
                itemColor 
            )
        else
            -- Opcional: Mostrar uma mensagem de "Inventário Cheio" aqui também?
            print(string.format("Falha ao coletar %s (Inventário provavelmente cheio).", itemBaseId))
        end
        
    else
        print("Aviso: Tipo de drop desconhecido:", dropConfig.type)
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

return DropManager 