local HordeConfigManager = require("src.managers.horde_config_manager")
local BossHealthBar = require("src.ui.boss_health_bar")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local SpatialGridIncremental = require("src.utils.SpatialGridIncremental")
local TablePool = require("src.utils.TablePool")
local Camera = require("src.config.camera")

---@class EnemyManager
---@field enemies table<number, BaseEnemy>
---@field maxEnemies number
---@field nextEnemyId number
---@field worldConfig table
---@field currentCycleIndex number
---@field gameTimer number
---@field timeInCurrentCycle number
---@field nextMajorSpawnTime number
---@field nextMinorSpawnTime number
---@field nextMVPSpawnTime number
---@field nextBossIndex number
---@field bossDeathTimer number
---@field bossDeathDuration number
---@field lastBossDeathTime number
---@field playerManager PlayerManager
---@field dropManager DropManager
---@field enemyPool table<string, table<number, BaseEnemy>> Pool de inimigos reutilizáveis, categorizados por classe
---@field spatialGrid SpatialGridIncremental
---@field mapDimensions table
---@field gridCellSize number
---@field despawnMargin number
local EnemyManager = {
    enemies = {},     -- Tabela contendo todas as instâncias de inimigos ativos
    maxEnemies = 800, -- Número máximo de inimigos permitidos na tela simultaneamente
    nextEnemyId = 1,  -- Próximo ID a ser atribuído a um inimigo
    enemyPool = {},   -- Pool de inimigos inativos para reutilização

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

    -- Timer para controlar quando esconder a barra de vida do boss após sua morte
    bossDeathTimer = 0,
    bossDeathDuration = 3, -- Tempo em segundos para manter a barra visível após a morte
    lastBossDeathTime = 0, -- Momento em que o último boss morreu
    spatialGrid = nil,
    mapDimensions = { width = 3000, height = 3000 },
    gridCellSize = 64,
    despawnMargin = 500,
}

-- Inicializa o gerenciador de inimigos com uma configuração de horda específica
---@param config table Tabela de configuração contendo { hordeConfig, playerManager, dropManager, mapManager }
function EnemyManager:setupGameplay(config)
    if not config or not config.hordeConfig or not config.playerManager or not config.dropManager or not config.mapManager then
        error("ERRO CRÍTICO [EnemyManager:setupGameplay]: Configuração inválida ou incompleta fornecida.")
    end

    -- Armazena referências diretas para managers se passados na config
    self.playerManager = config.playerManager 
    self.dropManager = config.dropManager
    self.mapManager = config.mapManager
    self.mapDimensions = { width = 0, height = 0 } -- Será preenchido abaixo
    self.gridCellSize = 64

    self.worldConfig = config.hordeConfig

    self.mapDimensions.width = self.mapManager:getMapPixelWidth()
    self.mapDimensions.height = self.mapManager:getMapPixelHeight()

    if self.mapDimensions.width <= 0 or self.mapDimensions.height <= 0 or self.gridCellSize <= 0 then
        error(string.format("[EnemyManager:setupGameplay] Erro: Dimensões do mapa (w:%s, h:%s) ou tamanho da célula (%s) inválidos para SpatialGrid.",
            tostring(self.mapDimensions.width), tostring(self.mapDimensions.height), tostring(self.gridCellSize)))
    end
    
    -- Destruir grid anterior se existir (ao re-entrar no gameplay, por exemplo)
    if self.spatialGrid and self.spatialGrid.destroy then
        self.spatialGrid:destroy()
    end
    self.spatialGrid = SpatialGridIncremental:new(self.mapDimensions.width, self.mapDimensions.height, self.gridCellSize, self.gridCellSize)

    self.enemies = {}
    self.enemyPool = {}

    self.nextEnemyId = 1                      
    self.gameTimer = 0                        
    self.timeInCurrentCycle = 0               
    self.currentCycleIndex = 1                
    self.nextBossIndex = 1                    

    -- Inicializa a barra de vida do boss
    BossHealthBar:init()

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
    local viewPort = Camera:getViewPort() -- Obtém a visão da câmera
    
    local margin = 200 -- Margem para culling de update (isOffScreen)

    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]

        -- Lógica de Despawn Inteligente (antes do update do inimigo)
        if enemy and enemy.isAlive and not enemy.isBoss and not enemy.isMVP then
            local enemyRadius = enemy.radius or 0 -- Raio do inimigo para cálculo de bounding box
            -- Verifica se o inimigo está fora da área (visão da câmera + despawnMargin)
            if enemy.position.x + enemyRadius < viewPort.x - self.despawnMargin or
               enemy.position.x - enemyRadius > viewPort.x + viewPort.width + self.despawnMargin or
               enemy.position.y + enemyRadius < viewPort.y - self.despawnMargin or -- Usar viewY para o topo da câmera
               enemy.position.y - enemyRadius > viewPort.y + viewPort.height + self.despawnMargin then

                -- print(string.format("Despawning enemy ID %d (Class: %s) due to distance.", enemy.id, enemy.className)) -- Para Debug
                if self.spatialGrid then
                    self.spatialGrid:removeEntityCompletely(enemy)
                end
                self:returnEnemyToPool(enemy)
                table.remove(self.enemies, i)
                goto continue_enemy_loop -- Pula o resto do update para este inimigo, já que foi removido
            end
        end

        -- Determina se o inimigo está dentro da área visível + margem de update
        local inViewForUpdate = (enemy.position.x + (enemy.radius or 0) > viewPort.x - margin and
                                 enemy.position.x - (enemy.radius or 0) < viewPort.x + viewPort.width + margin and
                                 enemy.position.y + (enemy.radius or 0) > viewPort.y - margin and
                                 enemy.position.y - (enemy.radius or 0) < viewPort.y + viewPort.height + margin)

        -- Atualiza a lógica do inimigo
        if enemy and enemy.isAlive then
            -- Atualiza a posição da entidade no grid ANTES de seu update de lógica
            if self.spatialGrid then
                self.spatialGrid:updateEntityInGrid(enemy)
            end
            enemy:update(dt, self.playerManager, self, not inViewForUpdate) 
        end

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

        -- Remove o inimigo se estiver marcado para remoção (flag setada pelo próprio inimigo em seu update)
        if enemy.shouldRemove then
            if self.spatialGrid then -- Adicionado: Remove do grid ao remover da lista
                self.spatialGrid:removeEntityCompletely(enemy)
            end
            table.remove(self.enemies, i)
            self:returnEnemyToPool(enemy) 
        end
        ::continue_enemy_loop::
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
end

--- Coleta renderizáveis dos inimigos para a renderList principal da cena.
---@param cameraX number Posição X da câmera.
---@param cameraY number Posição Y da câmera.
---@param dt number Delta time (pode não ser usado diretamente aqui, mas mantido para consistência se necessário no futuro).
---@param renderList table Lista onde os dados de renderização dos inimigos serão adicionados.
---@param spriteBatches_map_by_texture table Tabela de SpriteBatches (usada para referência de textura, mas não para adicionar diretamente aqui).
function EnemyManager:collectRenderables(cameraX, cameraY, dt, renderList, spriteBatches_map_by_texture)
    if not self.enemies or #self.enemies == 0 then return end

    local Constants = require("src.config.constants")
    local AnimatedSpritesheet = require("src.animations.animated_spritesheet") -- Necessário para pegar quads/texturas
    local screenW, screenH = love.graphics.getDimensions()

    for _, enemy in ipairs(self.enemies) do
        if enemy and enemy.position and enemy.sprite then -- Garante que o inimigo e seu sprite existem
            local shouldDrawSprite = (enemy.isAlive or (enemy.isDying and not enemy.isDeathAnimationComplete))
            if not enemy.shouldRemove and shouldDrawSprite then
                local cullRadius = enemy.radius or Constants.TILE_WIDTH / 2
                if enemy.position.x + cullRadius > cameraX and
                    enemy.position.x - cullRadius < cameraX + screenW and
                    enemy.position.y + cullRadius > cameraY and
                    enemy.position.y - cullRadius < cameraY + screenH then
                    local instanceAnimConfig = enemy.sprite
                    local unitType = instanceAnimConfig.unitType -- Agora temos isso no sprite config
                    local animState = instanceAnimConfig.animation

                    if not unitType or not animState then
                        print(string.format(
                            "AVISO [EM:collectRenderables]: unitType (%s) ou animState faltando para inimigo ID %s",
                            tostring(unitType), enemy.id or "N/A"))
                        goto continue_enemy_loop -- Usar goto para pular para o próximo inimigo do loop
                    end

                    local currentAnimationKey
                    if animState.isDead then
                        currentAnimationKey = animState.chosenDeathType
                    else
                        currentAnimationKey = animState.activeMovementType
                    end

                    if not currentAnimationKey then
                        -- print(string.format("AVISO [EM:collectRenderables]: Não foi possível determinar currentAnimationKey para %s (ID %s)", unitType, enemy.id or "N/A"))
                        goto continue_enemy_loop
                    end

                    local enemySheetTexture = AnimatedSpritesheet.assets[unitType] and
                        AnimatedSpritesheet.assets[unitType].sheets and
                        AnimatedSpritesheet.assets[unitType].sheets[currentAnimationKey]

                    local quadsForAnimation = AnimatedSpritesheet.assets[unitType] and
                        AnimatedSpritesheet.assets[unitType].quads and
                        AnimatedSpritesheet.assets[unitType].quads[currentAnimationKey]

                    local maxFramesForCurrentAnim = AnimatedSpritesheet.assets[unitType] and
                        AnimatedSpritesheet.assets[unitType].maxFrames and
                        AnimatedSpritesheet.assets[unitType].maxFrames[currentAnimationKey]


                    if not enemySheetTexture or not quadsForAnimation or not maxFramesForCurrentAnim or maxFramesForCurrentAnim == 0 then
                        print(string.format(
                            "AVISO [EM:collectRenderables]: Textura, quads ou maxFrames ausentes para %s, animKey '%s'.",
                            unitType, currentAnimationKey))
                        goto continue_enemy_loop
                    end

                    local angleToDraw = animState.direction
                    local quadsForAngle = quadsForAnimation[angleToDraw]

                    if not quadsForAngle then
                        -- print(string.format("AVISO [EM:collectRenderables]: Quads para ângulo %s não encontrados para %s, animKey '%s'.", angleToDraw, unitType, currentAnimationKey))
                        goto continue_enemy_loop
                    end

                    local frameToDraw = animState.currentFrame
                    if frameToDraw > maxFramesForCurrentAnim or frameToDraw <= 0 then
                        frameToDraw = 1 -- Fallback para o primeiro frame
                    end
                    local quad = quadsForAngle[frameToDraw]

                    if not quad then
                        -- print(string.format("AVISO [EM:collectRenderables]: Quad específico (frame %s, angulo %s) não encontrado para %s, animKey '%s'.", frameToDraw, angleToDraw, unitType, currentAnimationKey))
                        goto continue_enemy_loop
                    end

                    local baseUnitConfig = AnimatedSpritesheet.configs[unitType]
                    local ox, oy
                    if baseUnitConfig and baseUnitConfig.origin then
                        ox = baseUnitConfig.origin.x
                        oy = baseUnitConfig.origin.y
                    else
                        local _, _, q_w, q_h = quad:getViewport()
                        ox = q_w / 2
                        oy = q_h / 2
                    end

                    -- Define sortY para ordenação. Pode ser ajustado.
                    -- Usar a base do sprite para ordenação é comum.
                    local sortY = instanceAnimConfig.position.y + oy * instanceAnimConfig.scale

                    table.insert(renderList, {
                        type = "enemy_sprite",
                        sortY = sortY,
                        depth = 3,                   -- Usar uma constante de profundidade
                        texture = enemySheetTexture, -- A textura (love.graphics.Image)
                        quad = quad,                 -- O quad específico
                        x = instanceAnimConfig.position.x,
                        y = instanceAnimConfig.position.y,
                        rotation = 0, -- Adicione rotação se necessário
                        scale = instanceAnimConfig.scale,
                        ox = ox,
                        oy = oy
                    })

                    -- Barras de vida e outros elementos de BaseEnemy podem ser desenhados separadamente
                    -- ou também adicionados à renderList se BaseEnemy.draw for adaptado.
                    -- Por simplicidade, se BaseEnemy:draw desenha diretamente, ele será chamado *depois* que os batches forem desenhados
                    -- ou precisará ser chamado de uma forma que não conflite com a câmera/batches.
                    -- Para agora, vamos focar em ter o sprite na renderList.
                    -- Se BaseEnemy:draw existe, ele deve ser chamado pela GameplayScene após os batches
                    -- ou seu conteúdo (barra de vida) adicionado à renderList aqui com seu próprio sortY/depth.
                    if enemy.drawBarraDeVida then -- Exemplo, se existisse tal função
                        -- enemy:drawBarraDeVida(renderList)
                    end
                end
            end
        end
        ::continue_enemy_loop:: -- Label para o goto
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

    local enemyClassName = enemyClass.className -- Supondo que a classe do inimigo tenha um campo 'className'
    if not enemyClassName then
        -- Tenta obter o nome da classe de uma forma mais genérica se não houver 'className'
        -- Isso é um fallback e pode não ser ideal. Idealmente, cada classe de inimigo define seu 'className'.
        for k, v in pairs(_G) do
            if v == enemyClass then
                enemyClassName = k
                break
            end
        end
        if not enemyClassName then
            print(
                "ERRO CRÍTICO [EnemyManager:spawnSpecificEnemy]: Não foi possível determinar o className para a enemyClass fornecida.")
            -- Fallback para um nome de classe genérico se não conseguir determinar
            -- Isso pode levar a um pooling incorreto se várias classes acabarem com o mesmo nome genérico.
            -- Seria melhor que cada 'enemyClass' tivesse uma propriedade estática 'className'.
            -- Por agora, vamos usar um nome padrão e logar um aviso.
            enemyClassName = "UnknownEnemyType"
            print(string.format(
                "AVISO [EnemyManager:spawnSpecificEnemy]: Usando className '%s' para pooling. Isso pode não ser ideal.",
                enemyClassName))
            -- Como alternativa, poderia simplesmente não usar o pool para classes sem nome definido:
            -- print("AVISO [EnemyManager:spawnSpecificEnemy]: enemyClass não tem um 'className' definido. Criando nova instância sem pooling.")
            -- local newEnemy = enemyClass:new({x = 0, y = 0}, self.nextEnemyId) -- Posição e ID serão definidos depois
            -- table.insert(self.enemies, newEnemy)
            -- self.nextEnemyId = self.nextEnemyId + 1
            -- -- ... (código para definir posição e outras propriedades) ...
            -- return newEnemy -- Ou apenas retornar se a função for usada para obter um inimigo
        end
    end


    local enemyInstance = nil

    -- Tenta pegar um inimigo do pool
    if self.enemyPool[enemyClassName] and #self.enemyPool[enemyClassName] > 0 then
        enemyInstance = table.remove(self.enemyPool[enemyClassName])
        -- print(string.format("Reutilizando inimigo da classe %s do pool. Pool agora tem %d.", enemyClassName, #self.enemyPool[enemyClassName]))
    end

    -- Obtém o próximo ID disponível
    local enemyId
    if enemyInstance then
        -- Reutiliza o ID existente do inimigo se ele já tiver um, ou atribui um novo se necessário.
        -- A lógica de ID pode precisar de ajuste dependendo de como os IDs são gerenciados (se eles devem ser únicos por instância viva ou únicos globalmente).
        -- Para este exemplo, vamos assumir que o ID pode ser reutilizado ou que a função de reset cuida disso.
        -- Se o ID é para ser sempre novo, então mesmo para instâncias do pool, um novo ID deve ser atribuído.
        -- Vamos atribuir um novo ID para consistência.
        enemyId = self.nextEnemyId
        self.nextEnemyId = self.nextEnemyId + 1
    else
        enemyId = self.nextEnemyId
        self.nextEnemyId = self.nextEnemyId + 1
    end


    -- Calcula um raio de spawn fora da área visível da tela
    local minSpawnRadius = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
    local angle = math.random() * 2 * math.pi
    local spawnX = self.playerManager.player.position.x + math.cos(angle) * minSpawnRadius
    local spawnY = self.playerManager.player.position.y + math.sin(angle) * minSpawnRadius

    if enemyInstance then
        -- Reinicializa o inimigo existente
        -- A função 'reset' ou 'reinitialize' deve ser implementada na classe BaseEnemy ou específica do inimigo
        if enemyInstance.reset then
            enemyInstance:reset({ x = spawnX, y = spawnY }, enemyId)
        else
            -- Fallback de reinicialização manual se 'reset' não existir
            enemyInstance.position.x = spawnX
            enemyInstance.position.y = spawnY
            enemyInstance.id = enemyId
            enemyInstance.isAlive = true
            enemyInstance.isDying = false
            enemyInstance.isDeathAnimationComplete = false
            enemyInstance.shouldRemove = false
            enemyInstance.isMVP = false
            enemyInstance.isBoss = false
            -- Recarregar vida, etc.
            if enemyInstance.setup then enemyInstance:setup() end -- Chama setup se existir
        end
    else
        -- Cria uma nova instância do inimigo com o ID se não houver no pool
        enemyInstance = enemyClass:new({ x = spawnX, y = spawnY }, enemyId)
    end

    -- Adiciona o inimigo à lista de inimigos ativos
    table.insert(self.enemies, enemyInstance)

    print(string.format("Inimigo ID: %d (Classe: %s) spawnado em (%.1f, %.1f). Reutilizado: %s", enemyInstance.id,
        enemyClassName, spawnX, spawnY, tostring(enemyInstance.originalId ~= nil and enemyInstance.originalId == enemyId)))
end

-- Adiciona um inimigo ao pool para reutilização
function EnemyManager:returnEnemyToPool(enemy)
    if not enemy or not enemy.className then
        print("AVISO [EnemyManager:returnEnemyToPool]: Tentativa de retornar inimigo inválido ou sem className ao pool.")
        return
    end

    -- Reseta o estado do inimigo para um estado "limpo"
    -- Esta função precisará ser implementada na classe BaseEnemy ou nas classes específicas
    if enemy.resetStateForPooling then
        enemy:resetStateForPooling()
    else
        -- Fallback básico se resetStateForPooling não existir
        enemy.isAlive = false
        enemy.isDying = false
        enemy.isDeathAnimationComplete = false
        enemy.shouldRemove = false
        enemy.isMVP = false
        enemy.isBoss = false
        -- Adicione outros resets básicos conforme necessário
    end

    local enemyClassName = enemy.className
    if not self.enemyPool[enemyClassName] then
        self.enemyPool[enemyClassName] = {}
    end
    table.insert(self.enemyPool[enemyClassName], enemy)
    -- print(string.format("Inimigo ID %s (Classe: %s) retornado ao pool. Pool para %s agora tem %d.",
    --     tostring(enemy.id), enemyClassName, enemyClassName, #self.enemyPool[enemyClassName]))
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

--- Retorna uma instância de inimigo ativa pelo seu ID.
---@param id number O ID do inimigo a ser procurado.
---@return BaseEnemy|nil A instância do inimigo se encontrada, caso contrário nil.
function EnemyManager:getEnemyById(id)
    if not id then return nil end
    for _, enemy in ipairs(self.enemies) do
        if enemy.id == id then
            return enemy
        end
    end
    if self.currentBoss and self.currentBoss.id == id then
        return self.currentBoss
    end
    return nil
end

-- Função para ser chamada quando o EnemyManager não for mais necessário (ex: sair do jogo/cena)
function EnemyManager:destroy()
    if self.spatialGrid and self.spatialGrid.destroy then
        self.spatialGrid:destroy()
        self.spatialGrid = nil
    end
    -- Limpar pools de inimigos, etc., se necessário.
    -- Zerar contadores e listas
    self.enemies = {}
    self.enemyPool = {}
    self.gameTimer = 0
    print("EnemyManager destruído.")
end

return EnemyManager
