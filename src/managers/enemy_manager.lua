local HordeConfigManager = require("src.managers.horde_config_manager")
local BossHealthBar = require("src.ui.boss_health_bar")
local DropManager = require("src.managers.drop_manager")

local EnemyManager = {
    enemies = {},              -- Tabela contendo todas as instâncias de inimigos ativos
    maxEnemies = 300,           -- Número máximo de inimigos permitidos na tela simultaneamente
    
    -- Estado de Ciclo e Tempo
    worldConfig = nil,          -- Configuração carregada para o mundo (contém a lista de 'cycles')
    currentCycleIndex = 1,    -- Índice (base 1) do ciclo atual sendo executado (da lista worldConfig.cycles)
    gameTimer = 0,              -- Tempo total de jogo decorrido desde o início (em segundos)
    timeInCurrentCycle = 0,     -- Tempo decorrido dentro do ciclo atual (em segundos)

    -- Timers de Spawn (baseados no gameTimer)
    nextMajorSpawnTime = 0,     -- Tempo de jogo global agendado para o próximo spawn grande (Major Spawn)
    nextMinorSpawnTime = 0,     -- Tempo de jogo global agendado para o próximo spawn pequeno (Minor Spawn)
    nextMVPSpawnTime = 0,       -- Tempo de jogo global agendado para o próximo spawn de MVP
    nextBossIndex = 1,          -- Índice do próximo boss a ser spawnado
}

-- Inicializa o gerenciador de inimigos para um mundo específico
function EnemyManager:init(worldId)
    worldId = worldId or "default" -- Usa 'default' se nenhum ID de mundo for fornecido
    self.enemies = {}             -- Limpa a lista de inimigos
    self.gameTimer = 0            -- Reinicia o timer global
    self.timeInCurrentCycle = 0   -- Reinicia o timer do ciclo
    self.currentCycleIndex = 1  -- Começa no primeiro ciclo
    
    -- Inicializa a barra de vida do boss
    BossHealthBar:init()
    
    -- Carrega a configuração de ciclos para o mundo especificado
    self.worldConfig = HordeConfigManager.loadHordes(worldId)
    if not self.worldConfig or not self.worldConfig.cycles or #self.worldConfig.cycles == 0 then
        error("Erro: Configuração de ciclos inválida ou vazia para o mundo: " .. worldId)
    end
    
    -- Agenda os tempos iniciais de spawn com base nas regras do primeiro ciclo
    local firstCycle = self.worldConfig.cycles[1]
    if not firstCycle then error("Erro: Primeiro ciclo não encontrado na configuração.") end
    self.nextMajorSpawnTime = firstCycle.majorSpawn.interval -- O primeiro Major Spawn ocorre após o intervalo inicial
    self.nextMinorSpawnTime = self:calculateMinorSpawnInterval(firstCycle) -- O primeiro Minor Spawn ocorre após o intervalo inicial calculado
    self.nextMVPSpawnTime = self.worldConfig.mvpConfig.spawnInterval -- O primeiro MVP spawna após o intervalo inicial

    print(string.format("EnemyManager inicializado para '%s'. %d ciclo(s) carregados.", worldId, #self.worldConfig.cycles))
end

-- Atualiza o estado do gerenciador de inimigos e todos os inimigos ativos
function EnemyManager:update(dt, player)
    self.gameTimer = self.gameTimer + dt
    self.timeInCurrentCycle = self.timeInCurrentCycle + dt

    -- Verifica se é hora de spawnar um MVP
    if self.gameTimer >= self.nextMVPSpawnTime then
        self:spawnMVP(player)
        self.nextMVPSpawnTime = self.gameTimer + self.worldConfig.mvpConfig.spawnInterval
    end

    -- Verifica se é hora de spawnar um boss
    if self.worldConfig.bossConfig and self.worldConfig.bossConfig.spawnTimes then
        local nextBoss = self.worldConfig.bossConfig.spawnTimes[self.nextBossIndex]
        if nextBoss and self.gameTimer >= nextBoss.time then
            self:spawnBoss(nextBoss.boss, player, nextBoss.powerLevel)
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
        self.currentCycleIndex = self.currentCycleIndex + 1         -- Avança o índice do ciclo
        self.timeInCurrentCycle = self.timeInCurrentCycle - currentCycle.duration -- Ajusta o tempo para o novo ciclo
        currentCycle = self.worldConfig.cycles[self.currentCycleIndex] -- Atualiza a referência para o ciclo atual
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
        local countToSpawn = math.floor(spawnConfig.baseCount + (spawnConfig.baseCount * spawnConfig.countScalePerMin * minutesPassed))
        
        print(string.format("Major Spawn (Ciclo %d) no tempo %.2f: Tentando spawnar %d inimigos.", self.currentCycleIndex, self.gameTimer, countToSpawn))
        local spawnedCount = 0
        -- Tenta spawnar a quantidade calculada
        for i = 1, countToSpawn do
            if #self.enemies < self.maxEnemies then -- Verifica o limite global de inimigos
                local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies) -- Seleciona um inimigo permitido neste ciclo
                if enemyClass then
                    self:spawnSpecificEnemy(enemyClass, player)
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
        local spawnConfig = currentCycle.minorSpawn -- Pega a configuração do Minor Spawn para o ciclo atual
        local countToSpawn = spawnConfig.count      -- Quantidade de inimigos por Minor Spawn (geralmente 1)
        
        print(string.format("Minor Spawn (Ciclo %d) no tempo %.2f", self.currentCycleIndex, self.gameTimer)) -- Debug
        -- Tenta spawnar a quantidade definida
        for i = 1, countToSpawn do
            if #self.enemies < self.maxEnemies then -- Verifica o limite global de inimigos
                 local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies) -- Seleciona um inimigo permitido neste ciclo
                 if enemyClass then
                    self:spawnSpecificEnemy(enemyClass, player)
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
        enemy:update(dt, player, self.enemies) -- Atualiza a lógica do inimigo
        if not enemy.isAlive then
            -- Se for um boss, processa os drops antes de remover
            if enemy.isBoss then
                DropManager:processBossDrops(enemy)
            end
            table.remove(self.enemies, i) -- Remove inimigos mortos da lista
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
    -- Desenha a barra de vida do boss se houver um boss ativo
    for _, enemy in ipairs(self.enemies) do
        if enemy.isBoss and enemy.isAlive then
            BossHealthBar:show(enemy)
            break
        end
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
function EnemyManager:spawnSpecificEnemy(enemyClass, player)
    if not enemyClass then
       print("Erro: Tentativa de spawnar inimigo com classe nula.")
       return
    end
    -- Calcula um raio de spawn fora da área visível da tela
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    -- Gera um ângulo aleatório
    local angle = math.random() * 2 * math.pi
    -- Calcula as coordenadas X e Y com base no ângulo e raio a partir da posição do jogador
    local spawnX = player.positionX + math.cos(angle) * minSpawnRadius
    local spawnY = player.positionY + math.sin(angle) * minSpawnRadius
    -- Cria a nova instância do inimigo
    local enemy = enemyClass:new(spawnX, spawnY)
    -- Adiciona o inimigo à lista de inimigos ativos
    table.insert(self.enemies, enemy)
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
function EnemyManager:spawnMVP(player)
    if #self.enemies >= self.maxEnemies then
        print("Limite máximo de inimigos atingido, não é possível spawnar MVP.")
        return
    end
    
    -- Seleciona um tipo de inimigo aleatório do ciclo atual
    local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
    if not currentCycle then return end
    
    local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
    if not enemyClass then return end
    
    -- Spawna o inimigo normalmente
    local enemy = enemyClass:new(player.positionX, player.positionY)
    self:spawnSpecificEnemy(enemyClass, player)
    
    -- Transforma o último inimigo spawnado em MVP
    if #self.enemies > 0 then
        self:transformToMVP(self.enemies[#self.enemies])
    end
end

function EnemyManager:spawnBoss(bossClass, player, powerLevel)
    if #self.enemies >= self.maxEnemies then
        print("Limite máximo de inimigos atingido, não é possível spawnar boss.")
        return
    end

    -- Calcula posição de spawn (fora da tela)
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    local angle = math.random() * 2 * math.pi
    local spawnX = player.positionX + math.cos(angle) * minSpawnRadius
    local spawnY = player.positionY + math.sin(angle) * minSpawnRadius

    -- Cria o boss com o nível de poder especificado
    local boss = bossClass:new(spawnX, spawnY)
    boss.powerLevel = powerLevel or 3 -- Usa 3 como padrão se não for especificado
    table.insert(self.enemies, boss)

    print(string.format("Boss %s (Nível %d) spawnado!", boss.name, boss.powerLevel))
end

return EnemyManager