--- Gerencia as estatísticas do jogo durante uma partida.
--- @class GameStatisticsManager
local GameStatisticsManager = {}
GameStatisticsManager.__index = GameStatisticsManager

--- Cria uma nova instância do GameStatisticsManager.
--- @return GameStatisticsManager
function GameStatisticsManager:new()
    local instance = setmetatable({}, GameStatisticsManager)
    instance.registry = nil ---@type ManagerRegistry
    instance:resetStats() -- Inicia com estatísticas zeradas
    return instance
end

--- Inicializa o manager com dependências necessárias.
--- @param registry ManagerRegistry A instância do registro de managers.
function GameStatisticsManager:init(registry)
    self.registry = registry
    self:resetStats()
end

--- Reseta todas as estatísticas para uma nova partida.
function GameStatisticsManager:resetStats()
    self.stats = {
        -- Geral
        playTime = 0,
        startTime = love.timer.getTime(),

        -- Combate (Dano)
        totalDamageDealt = 0,
        totalDamageTaken = 0,
        totalDamageReduced = 0,
        highestDamageDealt = 0,
        highestDamageTaken = 0,

        -- Combate (Derrotados)
        enemiesDefeated = 0,
        mvpsDefeated = 0,
        bossesDefeated = 0,

        -- Combate (Críticos)
        criticalHits = 0,
        totalCriticalDamage = 0,
        superCriticalHits = 0,
        totalSuperCriticalDamage = 0,

        -- Sobrevivência
        healthRecovered = 0,
        maxHealthRecovered = 0,
        timesHealed = 0,
        timesHit = 0,
        longestTimeWithoutTakingDamage = 0,
        lastDamageTimestamp = 0, -- Auxiliar

        -- Detalhes de Dano
        weaponStats = {},  -- {weaponId = {hits = 0, damage = 0, crits = 0, sCrits = 0}}
        abilityStats = {}, -- {abilityId = {uses = 0, damage = 0}}
        maxEnemiesHitAtOnce = 0,

        -- Progressão
        distanceTraveled = 0, -- Em "unidades" do jogo
        itemsCollected = 0,
        levelsGained = 0,
        totalXpCollected = 0,
        levelUpChoices = {}, -- Formato: {level = N, choice = "Descrição da melhoria"}
    }
end

--- Atualiza o tempo de jogo e outras estatísticas baseadas em tempo.
--- @param dt number Delta time.
function GameStatisticsManager:update(dt)
    self.stats.playTime = love.timer.getTime() - self.stats.startTime

    -- Calcula o tempo sem tomar dano
    local timeSinceLastDamage = self.stats.playTime - self.stats.lastDamageTimestamp
    if timeSinceLastDamage > self.stats.longestTimeWithoutTakingDamage then
        self.stats.longestTimeWithoutTakingDamage = timeSinceLastDamage
    end
end

--- Registra dano causado.
--- @param amount number Quantidade de dano.
--- @param isCritical boolean Se foi um golpe crítico.
--- @param isSuperCritical boolean Se foi um golpe super crítico.
--- @param source table A fonte do dano, contendo `weaponId` ou `abilityId`.
function GameStatisticsManager:registerDamageDealt(amount, isCritical, isSuperCritical, source)
    self.stats.totalDamageDealt = self.stats.totalDamageDealt + amount
    if amount > self.stats.highestDamageDealt then
        self.stats.highestDamageDealt = amount
    end

    if isSuperCritical then
        self.stats.superCriticalHits = self.stats.superCriticalHits + 1
        self.stats.totalSuperCriticalDamage = self.stats.totalSuperCriticalDamage + amount
    elseif isCritical then
        self.stats.criticalHits = self.stats.criticalHits + 1
        self.stats.totalCriticalDamage = self.stats.totalCriticalDamage + amount
    end

    local weaponId = source and source.weaponId
    local abilityId = source and source.abilityId

    if weaponId then
        if not self.stats.weaponStats[weaponId] then
            self.stats.weaponStats[weaponId] = { hits = 0, damage = 0, crits = 0, sCrits = 0 }
        end
        local ws = self.stats.weaponStats[weaponId]
        ws.hits = ws.hits + 1
        ws.damage = ws.damage + amount
        if isSuperCritical then
            ws.sCrits = ws.sCrits + 1
        elseif isCritical then
            ws.crits = ws.crits + 1
        end
    end

    if abilityId then
        if not self.stats.abilityStats[abilityId] then
            self.stats.abilityStats[abilityId] = { uses = 0, damage = 0 }
        end
        self.stats.abilityStats[abilityId].uses = self.stats.abilityStats[abilityId].uses + 1
        self.stats.abilityStats[abilityId].damage = self.stats.abilityStats[abilityId].damage + amount
    end
end

--- Registra dano recebido e dano mitigado.
--- @param amount number Quantidade de dano recebido.
--- @param reducedAmount number Quantidade de dano que foi reduzida pela defesa.
function GameStatisticsManager:registerDamageTaken(amount, reducedAmount)
    self.stats.totalDamageTaken = self.stats.totalDamageTaken + amount
    self.stats.timesHit = self.stats.timesHit + 1
    if amount > self.stats.highestDamageTaken then
        self.stats.highestDamageTaken = amount
    end

    if reducedAmount and reducedAmount > 0 then
        self.stats.totalDamageReduced = self.stats.totalDamageReduced + reducedAmount
    end

    -- Atualiza o timestamp do último dano para o cálculo do tempo sem dano
    self.stats.lastDamageTimestamp = self.stats.playTime
end

--- Registra cura recebida.
--- @param amount number Quantidade de vida recuperada.
function GameStatisticsManager:registerHealthRecovered(amount)
    self.stats.healthRecovered = self.stats.healthRecovered + amount
    self.stats.timesHealed = self.stats.timesHealed + 1
    if amount > self.stats.maxHealthRecovered then
        self.stats.maxHealthRecovered = amount
    end
end

--- Registra um inimigo derrotado e verifica seu tipo.
--- @param enemyType string Tipo do inimigo ('normal', 'mvp', 'boss').
function GameStatisticsManager:registerEnemyDefeated(enemyType)
    self.stats.enemiesDefeated = self.stats.enemiesDefeated + 1
    if enemyType == "mvp" then
        self.stats.mvpsDefeated = self.stats.mvpsDefeated + 1
    elseif enemyType == "boss" then
        self.stats.bossesDefeated = self.stats.bossesDefeated + 1
    end
end

--- Registra movimento.
--- @param distance number Distância percorrida.
function GameStatisticsManager:registerMovement(distance)
    self.stats.distanceTraveled = self.stats.distanceTraveled + distance
end

--- Registra um item coletado.
function GameStatisticsManager:registerItemCollected()
    self.stats.itemsCollected = self.stats.itemsCollected + 1
end

--- Registra experiência ganha.
--- @param amount number Quantidade de XP.
function GameStatisticsManager:registerXpCollected(amount)
    self.stats.totalXpCollected = self.stats.totalXpCollected + amount
end

--- Registra um level up.
function GameStatisticsManager:registerLevelGained()
    self.stats.levelsGained = self.stats.levelsGained + 1
end

--- Registra uma escolha de melhoria de level up.
--- @param level number O nível em que a escolha foi feita.
--- @param choiceText string A descrição da melhoria escolhida.
function GameStatisticsManager:registerLevelUpChoice(level, choiceText)
    -- verifica se a melhoria já existe, se existir, incrementa o nível
    for _, choice in ipairs(self.stats.levelUpChoices) do
        if choice.choice == choiceText then
            choice.level = choice.level + 1
            return
        end
    end

    table.insert(self.stats.levelUpChoices, { level = level, choice = choiceText })
end

--- Registra o número de inimigos atingidos por um único ataque.
--- @param count number O número de inimigos.
function GameStatisticsManager:registerEnemiesHit(count)
    if count > self.stats.maxEnemiesHitAtOnce then
        self.stats.maxEnemiesHitAtOnce = count
    end
end

--- Retorna as estatísticas formatadas para exibição.
--- @return table Estatísticas formatadas
function GameStatisticsManager:getFormattedStats()
    -- Esta função precisará ser completamente refeita na GameStatsColumn.lua.
    -- Por enquanto, retornamos os dados brutos para a UI lidar.
    return self:getRawStats()
end

--- Retorna as estatísticas brutas.
--- @return table Estatísticas brutas
function GameStatisticsManager:getRawStats()
    return self.stats
end

return GameStatisticsManager
