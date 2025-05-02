local HordeConfigManager = require("src.managers.horde_config_manager")
local BossHealthBar = require("src.ui.boss_health_bar")
local ManagerRegistry = require("src.managers.manager_registry")

local EnemyManager = {
    enemies = {},     -- Tabela contendo todas as instâncias de inimigos ativos
    maxEnemies = 400, -- Número máximo de inimigos permitidos na tela simultaneamente
    nextEnemyId = 1,  -- Próximo ID a ser atribuído a um inimigo

    -- Estado de Ciclo e Tempo
    worldConfig = nil,      -- Configuração carregada para o mundo (contém a lista de 'cycles')
    currentCycleIndex = 1,  -- Índice (base 1) do ciclo atual sendo executado (da lista worldConfig.cycles)
    gameTimer = 0,          -- Tempo total de jogo decorrido desde o início (em segundos)
    timeInCurrentCycle = 0, -- Tempo decorrido dentro do ciclo atual (em segundos)

    -- Timers de Spawn (baseados no gameTimer)
    nextMajorSpawnTime = 0, -- Tempo de jogo global agendado para o próximo spawn grande (Major Spawn)
    nextMinorSpawnTime = 0, -- Tempo de jogo global agendado para o próximo spawn pequeno (Minor Spawn)
    nextMVPSpawnTime = 0,   -- Tempo de jogo global agendado para o próximo spawn de MVP
    nextBossIndex = 1,      -- Índice do próximo boss a ser spawnado

    spawnTimer = 0,
    spawnInterval = 2, -- Tempo entre spawns em segundos

    -- Timer para controlar quando esconder a barra de vida do boss após sua morte
    bossDeathTimer = 0,
    bossDeathDuration = 3, -- Tempo em segundos para manter a barra visível após a morte
    lastBossDeathTime = 0, -- Momento em que o último boss morreu
}

-- Inicializa o gerenciador de inimigos com uma configuração de horda específica
---@param config table Tabela de configuração contendo { hordeConfig, playerManager, dropManager }
function EnemyManager:setupGameplay(config)
    if not config or not config.hordeConfig or not config.playerManager or not config.dropManager then
        error("ERRO CRÍTICO [EnemyManager:setupGameplay]: Configuração inválida ou incompleta fornecida.")
    end

    self.playerManager = config.playerManager -- ManagerRegistry:get("playerManager")
    self.dropManager = config.dropManager     -- ManagerRegistry:get("dropManager")
    self.worldConfig = config.hordeConfig     -- USA A CONFIGURAÇÃO PASSADA DIRETAMENTE

    self.nextEnemyId = 1                      -- Reseta o contador de IDs
    self.enemies = {}                         -- Limpa a lista de inimigos
    self.gameTimer = 0                        -- Reinicia o timer global
    self.timeInCurrentCycle = 0               -- Reinicia o timer do ciclo
    self.currentCycleIndex = 1                -- Começa no primeiro ciclo
    self.nextBossIndex = 1                    -- Reseta índice do boss

    -- Inicializa a barra de vida do boss
    BossHealthBar:init()

    -- REMOVIDO: Carregamento via HordeConfigManager
    -- worldId = worldId or "default"
    -- self.worldConfig = HordeConfigManager.loadHordes(worldId)

    -- Valida a configuração carregada
    if not self.worldConfig or not self.worldConfig.cycles or #self.worldConfig.cycles == 0 then
        error("Erro [EnemyManager:init]: Configuração de horda inválida ou vazia fornecida.")
    end
    if not self.worldConfig.mvpConfig then
        error("Erro [EnemyManager:init]: Configuração de horda não possui 'mvpConfig'.")
    end
    -- bossConfig é opcional, não precisa de erro

    -- Determina o rank do mapa a partir da configuração do mundo
    local mapRank = self.worldConfig.mapRank or "E" -- Assume 'E' se não definido

    -- Agenda os tempos iniciais de spawn com base nas regras do primeiro ciclo
    local firstCycle = self.worldConfig.cycles[1]
    if not firstCycle or not firstCycle.majorSpawn or not firstCycle.minorSpawn then
        error("Erro [EnemyManager:init]: Primeiro ciclo inválido ou sem configuração de spawn.")
    end
    self.nextMajorSpawnTime = firstCycle.majorSpawn.interval
    self.nextMinorSpawnTime = self:calculateMinorSpawnInterval(firstCycle)
    self.nextMVPSpawnTime = self.worldConfig.mvpConfig.spawnInterval

    print(string.format("EnemyManager inicializado com Horda Config. Rank Mapa: %s. %d ciclo(s).",
        mapRank, #self.worldConfig.cycles))
end

-- Atualiza o estado do gerenciador de inimigos e todos os inimigos ativos
function EnemyManager:update(dt)
    self.gameTimer = self.gameTimer + dt
    self.timeInCurrentCycle = self.timeInCurrentCycle + dt

    -- Atualiza o timer de morte do boss
    if self.lastBossDeathTime > 0 then
        self.bossDeathTimer = self.gameTimer - self.lastBossDeathTime
    end

    -- Verifica se é hora de spawnar um MVP
    if self.gameTimer >= self.nextMVPSpawnTime then
        self:spawnMVP()
        self.nextMVPSpawnTime = self.gameTimer + self.worldConfig.mvpConfig.spawnInterval
    end

    -- Verifica se é hora de spawnar um boss
    if self.worldConfig.bossConfig and self.worldConfig.bossConfig.spawnTimes then
        local nextBoss = self.worldConfig.bossConfig.spawnTimes[self.nextBossIndex]
        if nextBoss and self.gameTimer >= nextBoss.time then
            self:spawnBoss(nextBoss.class, nextBoss.powerLevel)
            self.nextBossIndex = self.nextBossIndex + 1
        end
    end

    -- 1. Determina o Ciclo Atual e Verifica Transições
    local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
    if not currentCycle then
        -- Se não houver mais ciclos definidos, os spawns param.
        print("Fim dos ciclos definidos.")
        goto update_enemies_only -- Pula a lógica de spawn
    end

    -- Verifica se a duração do ciclo atual foi excedida para avançar para o próximo
    if self.timeInCurrentCycle >= currentCycle.duration and self.currentCycleIndex < #self.worldConfig.cycles then
        self.currentCycleIndex = self.currentCycleIndex + 1                       -- Avança o índice do ciclo
        self.timeInCurrentCycle = self.timeInCurrentCycle - currentCycle.duration -- Ajusta o tempo para o novo ciclo
        currentCycle = self.worldConfig.cycles
            [self.currentCycleIndex]                                              -- Atualiza a referência para o ciclo atual
        print(string.format("Entrando no Ciclo %d no tempo %.2f", self.currentCycleIndex, self.gameTimer))

        -- Recalcula e reagenda os próximos tempos de spawn com base nas regras do NOVO ciclo
        self.nextMajorSpawnTime = self.gameTimer + currentCycle.majorSpawn.interval
        self.nextMinorSpawnTime = self.gameTimer + self:calculateMinorSpawnInterval(currentCycle)
    end

    -- 2. Verifica Major Spawns (Grandes ondas cronometradas)
    if self.gameTimer >= self.nextMajorSpawnTime then
        local spawnConfig = currentCycle.majorSpawn
        local minutesPassed = self.gameTimer / 60

        -- Calcula a quantidade de inimigos a spawnar:
        -- Base + (Base * PorcentagemDeEscala * MinutosPassados)
        local countToSpawn = math.floor(spawnConfig.baseCount +
            (spawnConfig.baseCount * spawnConfig.countScalePerMin * minutesPassed))

        print(string.format("Major Spawn (Ciclo %d) no tempo %.2f: Tentando spawnar %d inimigos.", self
            .currentCycleIndex, self.gameTimer, countToSpawn))
        local spawnedCount = 0
        -- Tenta spawnar a quantidade calculada
        for i = 1, countToSpawn do
            if #self.enemies < self.maxEnemies then                                      -- Verifica o limite global de inimigos
                local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies) -- Seleciona um inimigo permitido neste ciclo
                if enemyClass then
                    self:spawnSpecificEnemy(enemyClass)
                    spawnedCount = spawnedCount + 1
                end
            else
                print("Limite máximo de inimigos atingido durante Major Spawn.")
                break -- Interrompe o spawn se o limite for atingido
            end
        end
        print(string.format("Major Spawn concluído. %d inimigos spawnados.", spawnedCount))

        -- Agenda o próximo Major Spawn para daqui a 'spawnConfig.interval' segundos
        self.nextMajorSpawnTime = self.gameTimer + spawnConfig.interval
    end

    -- 3. Verifica Minor Spawns (Pequenos spawns aleatórios contínuos)
    if self.gameTimer >= self.nextMinorSpawnTime then
        local spawnConfig = currentCycle
            .minorSpawn                                                                                      -- Pega a configuração do Minor Spawn para o ciclo atual
        local countToSpawn = spawnConfig
            .count                                                                                           -- Quantidade de inimigos por Minor Spawn (geralmente 1)

        print(string.format("Minor Spawn (Ciclo %d) no tempo %.2f", self.currentCycleIndex, self.gameTimer)) -- Debug
        -- Tenta spawnar a quantidade definida
        for i = 1, countToSpawn do
            if #self.enemies < self.maxEnemies then                                      -- Verifica o limite global de inimigos
                local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies) -- Seleciona um inimigo permitido neste ciclo
                if enemyClass then
                    self:spawnSpecificEnemy(enemyClass)
                end
            else
                print("Limite máximo de inimigos atingido durante Minor Spawn.")
                break -- Interrompe se o limite for atingido
            end
        end

        -- Agenda o próximo Minor Spawn usando o intervalo calculado (que diminui com o tempo)
        local nextInterval = self:calculateMinorSpawnInterval(currentCycle)
        self.nextMinorSpawnTime = self.gameTimer + nextInterval
    end

    -- Label usado pelo 'goto' para pular a lógica de spawn se não houver mais ciclos
    ::update_enemies_only::

    -- 4. Atualiza Inimigos Existentes (sempre executa)
    -- Itera de trás para frente para permitir remoção segura
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]

        -- Atualiza a lógica do inimigo
        enemy:update(dt, self.playerManager, self.enemies)

        -- Se o inimigo estiver morto e não estiver em animação de morte
        if not enemy.isAlive and not enemy.isDying then
            -- Marca como em processo de morte
            enemy.isDying = true

            -- Inicia a animação de morte
            if enemy.startDeathAnimation then
                enemy:startDeathAnimation()
            end

            -- Processa os drops usando a função unificada
            self.dropManager:processEntityDrop(enemy)

            -- Registra o momento da morte se for um boss (para a barra de vida)
            if enemy.isBoss then
                self.lastBossDeathTime = self.gameTimer
            end
        end

        -- Remove o inimigo se estiver marcado para remoção
        if enemy.shouldRemove then
            table.remove(self.enemies, i)
        end
    end

    -- Atualiza a barra de vida do boss
    self:updateBossHealthBarVisibility(dt)
end

-- Função auxiliar para gerenciar visibilidade da barra de vida do boss
function EnemyManager:updateBossHealthBarVisibility(dt)
    local activeBoss = nil
    for _, enemy in ipairs(self.enemies) do
        if enemy.isBoss and enemy.isAlive then
            activeBoss = enemy
            break
        end
    end

    if activeBoss then
        BossHealthBar:show(activeBoss)
        self.lastBossDeathTime = 0 -- Reseta se um boss estiver vivo
        self.bossDeathTimer = 0
    else
        -- Se não houver boss vivo, mas um morreu recentemente
        if self.lastBossDeathTime > 0 then
            self.bossDeathTimer = self.gameTimer - self.lastBossDeathTime
            if self.bossDeathTimer <= self.bossDeathDuration then
                BossHealthBar:show(nil) -- Mostra barra vazia
            else
                BossHealthBar:hide()
                self.lastBossDeathTime = 0 -- Reseta timers após esconder
                self.bossDeathTimer = 0
            end
        else
            -- Nenhum boss vivo e nenhum morreu recentemente
            BossHealthBar:hide()
        end
    end
end

-- Função auxiliar: Calcula o intervalo para o próximo Minor Spawn com base na configuração do ciclo atual e no tempo de jogo.
-- O intervalo diminui ao longo do tempo, até um limite mínimo.
function EnemyManager:calculateMinorSpawnInterval(cycleConfig)
    local spawnConfig = cycleConfig.minorSpawn
    local minutesPassed = self.gameTimer / 60
    local interval = spawnConfig.baseInterval - (spawnConfig.intervalReductionPerMin * minutesPassed)
    -- Garante que o intervalo não seja menor que o mínimo definido no ciclo
    return math.max(interval, spawnConfig.minInterval)
end

-- Função auxiliar: Seleciona aleatoriamente uma classe de inimigo de uma lista fornecida, respeitando os pesos definidos.
function EnemyManager:selectEnemyFromList(enemyList)
    if not enemyList or #enemyList == 0 then
        print("Aviso: Tentando selecionar inimigo de uma lista vazia ou inválida.")
        return nil
    end

    -- Calcula o peso total da lista
    local totalWeight = 0
    for _, enemyType in ipairs(enemyList) do
        totalWeight = totalWeight + (enemyType.weight or 1) -- Assume peso 1 se não estiver definido
    end

    -- Lida com caso de peso total inválido (ou lista com apenas pesos zero)
    if totalWeight <= 0 then
        print("Aviso: Peso total zero ou negativo na lista de inimigos.")
        return #enemyList > 0 and enemyList[1].class or nil -- Retorna o primeiro como fallback
    end

    -- Sorteia um valor aleatório dentro do peso total
    local randomValue = math.random() * totalWeight

    -- Itera pela lista subtraindo os pesos até encontrar o inimigo correspondente ao valor sorteado
    for _, enemyType in ipairs(enemyList) do
        randomValue = randomValue - (enemyType.weight or 1)
        if randomValue <= 0 then
            return enemyType.class -- Retorna a classe do inimigo selecionado
        end
    end

    -- Fallback (não deve acontecer com pesos positivos, mas por segurança)
    print("Aviso: Falha ao selecionar inimigo por peso, retornando o primeiro da lista.")
    return #enemyList > 0 and enemyList[1].class or nil
end

-- Desenha todos os inimigos ativos na tela
function EnemyManager:draw()
    -- Desenha a barra de vida do boss se houver um boss ativo ou se ainda não passou o tempo de exibição após a morte
    local shouldShowBossBar = false
    for _, enemy in ipairs(self.enemies) do
        if enemy.isBoss and enemy.isAlive then
            shouldShowBossBar = true
            BossHealthBar:show(enemy)
            break
        end
    end

    -- Se não houver boss vivo, mas ainda estiver dentro do tempo de exibição após a morte
    if not shouldShowBossBar and self.bossDeathTimer > 0 and self.bossDeathTimer <= self.bossDeathDuration then
        BossHealthBar:show(nil)    -- Mostra a barra vazia
    elseif self.bossDeathTimer > self.bossDeathDuration then
        BossHealthBar:hide()       -- Esconde a barra após o tempo limite
        self.lastBossDeathTime = 0 -- Reseta o timer
        self.bossDeathTimer = 0
    end

    -- Desenha os inimigos (dentro da transformação da câmera)
    for _, enemy in ipairs(self.enemies) do
        enemy:draw()
    end
end

-- Retorna a lista atual de inimigos ativos (para colisões, etc.)
function EnemyManager:getEnemies()
    return self.enemies
end

-- Cria e adiciona um inimigo de uma classe específica em uma posição aleatória fora da tela
function EnemyManager:spawnSpecificEnemy(enemyClass)
    if not enemyClass then
        print("Erro: Tentativa de spawnar inimigo com classe nula.")
        return
    end

    -- Obtém o próximo ID disponível antes de criar o inimigo
    local enemyId = self.nextEnemyId
    print(string.format("Próximo ID disponível: %d", enemyId))

    -- Calcula um raio de spawn fora da área visível da tela
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    -- Gera um ângulo aleatório
    local angle = math.random() * 2 * math.pi
    -- Calcula as coordenadas X e Y com base no ângulo e raio a partir da posição do jogador
    local spawnX = self.playerManager.player.position.x + math.cos(angle) * minSpawnRadius
    local spawnY = self.playerManager.player.position.y + math.sin(angle) * minSpawnRadius

    -- Cria a nova instância do inimigo com o ID
    local enemy = enemyClass:new({ x = spawnX, y = spawnY }, enemyId)

    -- Incrementa o contador de IDs
    self.nextEnemyId = self.nextEnemyId + 1
    print(string.format("ID incrementado para: %d", self.nextEnemyId))

    -- Adiciona o inimigo à lista de inimigos ativos
    table.insert(self.enemies, enemy)

    print(string.format("Inimigo ID: %d spawnado em (%.1f, %.1f)", enemy.id, spawnX, spawnY))
end

-- Função para transformar um inimigo em MVP
function EnemyManager:transformToMVP(enemy)
    if not enemy or not enemy.isAlive then return end

    local mvpConfig = self.worldConfig.mvpConfig

    -- Aumenta os status do inimigo usando as configurações do mundo
    enemy.maxHealth = enemy.maxHealth * mvpConfig.statusMultiplier
    enemy.currentHealth = enemy.maxHealth
    enemy.damage = enemy.damage * mvpConfig.statusMultiplier
    enemy.speed = enemy.speed * mvpConfig.speedMultiplier
    enemy.radius = enemy.radius * mvpConfig.sizeMultiplier
    enemy.experienceValue = enemy.experienceValue * mvpConfig.experienceMultiplier

    -- Marca como MVP
    enemy.isMVP = true
end

-- Função para spawnar um MVP
function EnemyManager:spawnMVP()
    if #self.enemies >= self.maxEnemies then
        print("Limite máximo de inimigos atingido, não é possível spawnar MVP.")
        return
    end

    -- Seleciona um tipo de inimigo aleatório do ciclo atual
    local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
    if not currentCycle then return end

    local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
    if not enemyClass then return end

    -- Obtém o próximo ID disponível
    local enemyId = self.nextEnemyId
    print(string.format("Próximo ID disponível para MVP: %d", enemyId))

    -- Spawna o inimigo normalmente
    self:spawnSpecificEnemy(enemyClass)

    -- Transforma o último inimigo spawnado em MVP
    if #self.enemies > 0 then
        local mvp = self.enemies[#self.enemies]
        self:transformToMVP(mvp)
        print(string.format("MVP ID: %d criado", mvp.id))
    end
end

function EnemyManager:spawnBoss(bossClass, powerLevel)
    if #self.enemies >= self.maxEnemies then
        print("Limite máximo de inimigos atingido, não é possível spawnar boss.")
        return
    end

    -- Calcula posição de spawn (fora da tela)
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    local angle = math.random() * 2 * math.pi
    local spawnX = self.playerManager.player.position.x + math.cos(angle) * minSpawnRadius
    local spawnY = self.playerManager.player.position.y + math.sin(angle) * minSpawnRadius

    -- Obtém o próximo ID disponível
    local enemyId = self.nextEnemyId
    self.nextEnemyId = self.nextEnemyId + 1

    -- Cria o boss com o nível de poder especificado
    local boss = bossClass:new({ x = spawnX, y = spawnY }, enemyId)
    boss.powerLevel = powerLevel or 3 -- Usa 3 como padrão se não for especificado
    table.insert(self.enemies, boss)

    print(string.format("Boss %s (ID: %d, Nível %d) spawnado!", boss.name, enemyId, boss.powerLevel))
end

return EnemyManager
