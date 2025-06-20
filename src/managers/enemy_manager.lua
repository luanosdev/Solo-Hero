local SpatialGridIncremental = require("src.utils.spatial_grid_incremental")
local TablePool = require("src.utils.table_pool")
local Camera = require("src.config.camera")
local RenderPipeline = require("src.core.render_pipeline")
local Culling = require("src.core.culling")
local DamageNumberManager = require("src.managers.damage_number_manager")
local MVPTitlesData = require("src.data.mvp_titles_data")
local EnemyNamesData = require("src.data.enemy_names_data")
local Colors = require("src.ui.colors")
local Fonts = require("src.ui.fonts")

---@class EnemyManager
---@field enemies table<number, BaseEnemy>
---@field maxEnemies number
---@field nextEnemyId number
---@field worldConfig table|nil
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
---@field spatialGrid SpatialGridIncremental|nil
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

    -- Para um mapa procedural "infinito", definimos uma grande "área de jogo" para o SpatialGrid.
    -- Isso garante que o sistema de detecção de colisão tenha limites para operar,
    -- mesmo que o mapa em si não tenha.
    local playableAreaSize = 20000 -- Define uma área de 20k x 20k pixels.
    self.mapDimensions = { width = playableAreaSize, height = playableAreaSize }
    -- Para um mundo grande, células de grid maiores são mais eficientes.
    self.gridCellSize = 256

    self.worldConfig = config.hordeConfig

    if self.mapDimensions.width <= 0 or self.mapDimensions.height <= 0 or self.gridCellSize <= 0 then
        error(string.format(
            "[EnemyManager:setupGameplay] Erro: Dimensões do mapa (w:%s, h:%s) ou tamanho da célula (%s) inválidos para SpatialGrid.",
            tostring(self.mapDimensions.width), tostring(self.mapDimensions.height), tostring(self.gridCellSize)))
    end

    -- Destruir grid anterior se existir (ao re-entrar no gameplay, por exemplo)
    if self.spatialGrid and self.spatialGrid.destroy then
        self.spatialGrid:destroy()
    end
    self.spatialGrid = SpatialGridIncremental:new(self.mapDimensions.width, self.mapDimensions.height, self.gridCellSize,
        self.gridCellSize)

    self.enemies = {}
    self.enemyPool = {}

    self.nextEnemyId = 1
    self.gameTimer = 0
    self.timeInCurrentCycle = 0
    self.currentCycleIndex = 1
    self.nextBossIndex = 1

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

    -- Atualiza o DamageNumberManager
    DamageNumberManager:update(dt)

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
            self:spawnBoss(nextBoss)
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
    local camX, camY, camWidth, camHeight = Camera:getViewPort() -- Obtém a visão da câmera

    local margin = 300                                           -- Margem para culling de update (isOffScreen)

    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]

        -- Lógica de Despawn Inteligente (antes do update do inimigo)
        if enemy and enemy.isAlive and not enemy.isBoss and not enemy.isMVP then
            -- Verifica se o inimigo está fora da área (visão da câmera + despawnMargin)
            if Culling.isOffScreen(enemy, camX, camY, camWidth, camHeight, self.despawnMargin) then
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
        local inViewForUpdate = Culling.isInView(enemy, camX, camY, camWidth, camHeight, margin)

        -- Atualiza a lógica do inimigo
        if enemy and (enemy.isAlive or enemy.isDying) then -- MODIFICADO: Permite update para inimigos morrendo
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

            Logger.debug("EnemyManager:update", "Processing drops for enemy: " .. enemy.name)
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
    local activeBosses = {}
    for _, enemy in ipairs(self.enemies) do
        if enemy.isBoss and enemy.isAlive and enemy.isPresentationFinished then
            table.insert(activeBosses, enemy)
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

--- Coleta renderizáveis dos inimigos para a renderList principal da cena.
---@param renderPipelineInstance RenderPipeline Instância do RenderPipeline.
function EnemyManager:collectRenderables(renderPipelineInstance)
    if not self.enemies or #self.enemies == 0 then return end

    -- Lazy initialization do DamageNumberManager com a instância do pipeline
    if not DamageNumberManager.isInitialized then
        DamageNumberManager:init(renderPipelineInstance)
    end

    DamageNumberManager:collectRenderables()

    local AnimatedSpritesheet = require("src.animations.animated_spritesheet") -- Necessário para pegar quads/texturas

    -- Obtém informações da câmera e tela
    local camX = Camera.x
    local camY = Camera.y
    local screenW, screenH = love.graphics.getDimensions()

    for _, enemy in ipairs(self.enemies) do
        if enemy and enemy.position and enemy.sprite then -- Garante que o inimigo e seu sprite existem
            local shouldDrawSprite = (enemy.isAlive or (enemy.isDying and not enemy.isDeathAnimationComplete))
            if not enemy.shouldRemove and shouldDrawSprite then
                -- Usa Culling.isInView para verificar se o inimigo está na tela para renderização
                -- Passa uma margem de 0, pois Culling.isInView já considera o entity.radius
                if Culling.isInView(enemy, camX, camY, screenW, screenH, 0) then
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

                    local rendable = TablePool.get()
                    rendable.type = "enemy_sprite"
                    rendable.sortY = sortY
                    rendable.depth = RenderPipeline.DEPTH_ENTITIES
                    rendable.texture = enemySheetTexture
                    rendable.quad = quad
                    rendable.x = instanceAnimConfig.position.x
                    rendable.y = instanceAnimConfig.position.y
                    rendable.rotation = 0
                    rendable.scale = instanceAnimConfig.scale
                    rendable.ox = ox
                    rendable.oy = oy

                    renderPipelineInstance:add(rendable)

                    if enemy.isBoss and enemy.draw then
                        local bossDrawRenderable = TablePool.get()
                        bossDrawRenderable.type = "drawFunction"
                        bossDrawRenderable.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI -- Renderiza sobre os sprites
                        bossDrawRenderable.sortY = sortY + 1000

                        local capturedEnemy = enemy
                        bossDrawRenderable.drawFunction = function()
                            capturedEnemy:draw()
                        end
                        renderPipelineInstance:add(bossDrawRenderable)
                    end

                    -- <<< NOVA LÓGICA PARA BARRAS DE VIDA DE MVP >>>
                    if enemy.isMVP and enemy.isAlive then
                        local mvpBarRenderable = TablePool.get()
                        mvpBarRenderable.type = "drawFunction"
                        mvpBarRenderable.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI -- Renderiza sobre os sprites
                        mvpBarRenderable.sortY = sortY + 1000

                        local capturedEnemy = enemy
                        mvpBarRenderable.drawFunction = function()
                            self:drawMvpBar(capturedEnemy, capturedEnemy.position.x, capturedEnemy.position.y)
                        end
                        renderPipelineInstance:add(mvpBarRenderable)
                    end

                    -- Barras de vida e outros elementos de BaseEnemy podem ser desenhados separadamente
                    -- ou também adicionados à renderList se BaseEnemy.draw for adaptado.
                    -- Por simplicidade, se BaseEnemy:draw desenha diretamente, ele será chamado *depois* que os batches forem desenhados
                    -- ou precisará ser chamado de uma forma que não conflite com a câmera/batches.
                    -- Para agora, vamos focar em ter o sprite na renderList.
                    -- Se BaseEnemy:draw existe, ele deve ser chamado pela GameplayScene após os batches
                    -- ou seu conteúdo (barra de vida) adicionado à renderList aqui com seu próprio sortY/depth.
                    if enemy.drawBarraDeVida then -- Exemplo, se existisse tal função
                        -- enemy:drawBarraDeVida(renderPipelineInstance) -- Passaria o pipeline
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

--- Spawna um inimigo (normal ou MVP) com base nas opções.
--- @param enemyClass table A classe do inimigo a ser spawnada.
---@param options table|nil Tabela de opções. Pode incluir: isMVP (boolean).
function EnemyManager:spawnSpecificEnemy(enemyClass, options)
    options = options or {}

    if not enemyClass then
        print("Erro: Tentativa de spawnar inimigo com classe nula.")
        return nil
    end

    local enemyClassName = enemyClass.className
    if not enemyClassName then
        print("ERRO CRÍTICO [EnemyManager:spawnSpecificEnemy]: Classe de inimigo sem 'className'.")
        return nil
    end

    -- Obter instância do pool ou criar nova
    local enemyInstance = self:getOrCreateEnemyInstance(enemyClassName, enemyClass)

    -- Calcular posição de spawn
    local spawnX, spawnY = self:calculateSpawnPosition()
    enemyInstance:reset({ x = spawnX, y = spawnY }, self.nextEnemyId)
    self.nextEnemyId = self.nextEnemyId + 1

    -- Se for um MVP, aplica as transformações
    if options.isMVP then
        self:transformToMVP(enemyInstance)
    end

    -- Adiciona à lista de ativos
    table.insert(self.enemies, enemyInstance)

    print(string.format("Inimigo ID: %d (Classe: %s, MVP: %s) spawnado em (%.1f, %.1f).",
        enemyInstance.id, enemyClassName, tostring(options.isMVP or false), spawnX, spawnY))

    return enemyInstance
end

--- Obtém um inimigo do pool ou cria uma nova instância.
---@param enemyClassName string
---@param enemyClass table
---@return BaseEnemy
function EnemyManager:getOrCreateEnemyInstance(enemyClassName, enemyClass)
    if self.enemyPool[enemyClassName] and #self.enemyPool[enemyClassName] > 0 then
        return table.remove(self.enemyPool[enemyClassName])
    else
        return enemyClass:new({ x = 0, y = 0 }, -1) -- Posição e ID temporários
    end
end

-- Adiciona um inimigo ao pool para reutilização
function EnemyManager:returnEnemyToPool(enemy)
    if not enemy or not enemy.className then
        print("AVISO [EnemyManager:returnEnemyToPool]: Tentativa de retornar inimigo inválido ou sem className ao pool.")
        return
    end

    -- Reseta o estado do inimigo para um estado "limpo"
    -- Esta função é implementada na classe BaseEnemy.
    enemy:resetStateForPooling()

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

    -- 1. Marcação e Boosts Base
    enemy.isMVP = true
    enemy.maxHealth = enemy.maxHealth * 10
    enemy.radius = enemy.radius * 1.2
    enemy.sprite.scale = enemy.sprite.scale * 1.2 -- Assumindo que a escala está no sprite

    -- 2. Seleção de Título
    local mapRank = self.worldConfig.mapRank or "E"
    local title = self:selectMvpTitle(mapRank)
    enemy.mvpTitleData = title

    -- 3. Seleção de Nome
    local nameType = enemy.nameType or "generic_monster"
    local names = EnemyNamesData[nameType]
    if names and #names > 0 then
        enemy.mvpProperName = names[math.random(#names)]
    else
        enemy.mvpProperName = "Ser Sem Nome"
    end

    -- 4. Aplicação dos Modificadores do Título
    if title and title.modifiers then
        for _, mod in ipairs(title.modifiers) do
            self:applyModifier(enemy, mod)
        end
    end

    -- A vida atual deve ser igual à vida máxima após todas as modificações
    enemy.currentHealth = enemy.maxHealth

    print(string.format("Transformado em MVP: %s, %s", enemy.mvpProperName, title.name))
end

--- Seleciona um título de MVP com base no rank do mapa, com chance de upgrade.
---@param mapRank string
---@return table|nil
function EnemyManager:selectMvpTitle(mapRank)
    local ranks = { "E", "D", "C", "B", "A", "S" }
    local rankIndex = 1
    for i, r in ipairs(ranks) do
        if r == mapRank then
            rankIndex = i
            break
        end
    end

    -- Chance de 10% de pegar um rank acima (se não for S)
    if rankIndex < #ranks and math.random() <= 0.1 then
        rankIndex = rankIndex + 1
    end
    local targetRank = ranks[rankIndex]

    -- Filtra títulos pelo rank alvo
    local validTitles = {}
    for _, title in pairs(MVPTitlesData.Titles) do
        if title.rank == targetRank then
            table.insert(validTitles, title)
        end
    end

    if #validTitles > 0 then
        return validTitles[math.random(#validTitles)]
    else
        -- Fallback para o rank original se não houver títulos no rank superior
        validTitles = {}
        for _, title in pairs(MVPTitlesData.Titles) do
            if title.rank == mapRank then
                table.insert(validTitles, title)
            end
        end
        if #validTitles > 0 then
            return validTitles[math.random(#validTitles)]
        end
    end

    return nil -- Nenhum título encontrado
end

--- Aplica um modificador de stat a um inimigo.
---@param enemy BaseEnemy
---@param modifier table
function EnemyManager:applyModifier(enemy, modifier)
    local stat = modifier.stat
    local type = modifier.type
    local value = modifier.value

    if not enemy[stat] then
        print(string.format("Aviso: Tentando modificar stat '%s' inexistente no inimigo.", stat))
        return
    end

    if type == "fixed" then
        enemy[stat] = enemy[stat] + value
    elseif type == "percentage" then
        enemy[stat] = enemy[stat] * (1 + value / 100)
    elseif type == "fixed_percentage_as_fraction" then
        -- Assume que o stat base é um multiplicador (ex: critChance)
        enemy[stat] = enemy[stat] + value
    end
end

-- Função para spawnar um MVP
function EnemyManager:spawnMVP()
    if #self.enemies >= self.maxEnemies then
        print("Limite máximo de inimigos atingido, não é possível spawnar MVP.")
        return
    end

    local currentCycle = self.worldConfig.cycles[self.currentCycleIndex]
    if not currentCycle then return end

    local enemyClass = self:selectEnemyFromList(currentCycle.allowedEnemies)
    if not enemyClass then return end

    self:spawnSpecificEnemy(enemyClass, { isMVP = true })
end

--- Spawna um boss específico.
---@param bossConfig BossSpawn Configuração do boss a ser spawnado.
function EnemyManager:spawnBoss(bossConfig)
    local bossClass = bossConfig.class
    if not bossClass then
        error("[EnemyManager:spawnBoss]: Tentativa de spawnar boss com classe nula.")
    end

    local enemyClassName = bossClass.className
    if not enemyClassName then
        error("[EnemyManager:spawnBoss]: Classe de boss sem 'className'.")
    end

    -- Obter instância do pool ou criar nova
    local bossInstance = self:getOrCreateEnemyInstance(enemyClassName, bossClass)

    -- Calcular posição de spawn
    local spawnX, spawnY = self:calculateSpawnPosition()
    bossInstance:reset({ x = spawnX, y = spawnY }, self.nextEnemyId)
    self.nextEnemyId = self.nextEnemyId + 1

    -- Propriedades específicas do Boss
    local rank = bossConfig.rank or "E"
    bossInstance.rank = rank -- Armazena o rank na instância do boss

    -- Aplica os multiplicadores com base no rank
    local rankMultipliers = { E = 1, D = 2, C = 3, B = 4, A = 5, S = 6 }
    local speedMultipliers = { E = 1.0, D = 1.1, C = 1.2, B = 1.3, A = 1.4, S = 1.5 }
    local cooldownMultipliers = { E = 1.0, D = 0.9, C = 0.8, B = 0.7, A = 0.6, S = 0.5 }

    local statMultiplier = rankMultipliers[rank] or 1
    local speedMultiplier = speedMultipliers[rank] or 1.0
    local cooldownMultiplier = cooldownMultipliers[rank] or 1.0

    bossInstance.maxHealth = bossInstance.maxHealth * statMultiplier
    bossInstance.currentHealth = bossInstance.maxHealth
    bossInstance.speed = bossInstance.speed * speedMultiplier
    bossInstance.damageMultiplier = (bossInstance.damageMultiplier or 1) * statMultiplier
    bossInstance.abilityCooldownMultiplier = (bossInstance.abilityCooldownMultiplier or 1) * cooldownMultiplier

    -- Adiciona à lista de ativos
    table.insert(self.enemies, bossInstance)

    -- Notifica o gerenciador de barras de vida
    local BossHealthBarManager = require("src.managers.boss_health_bar_manager")
    BossHealthBarManager:addBoss(bossInstance)

    Logger.info(
        "[EnemyManager:spawnBoss]",
        string.format("Boss %s (ID: %d, Rank %s) spawnado!", bossInstance.name, bossInstance.id, bossInstance.rank)
    )
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
    DamageNumberManager:destroy()
    Logger.info("[EnemyManager]", "EnemyManager destruído.")
end

--- Calcula uma posição de spawn inteligente fora da tela, com viés na direção do movimento do jogador.
---@return number spawnX, number spawnY
function EnemyManager:calculateSpawnPosition()
    local camX, camY, camWidth, camHeight = Camera:getViewPort()
    local playerVel = self.playerManager.player and self.playerManager.player.velocity

    -- Define um buffer para spawnar fora da tela, garantindo que inimigos não apareçam visivelmente
    local buffer = 150

    -- Define as 4 possíveis zonas de spawn (retângulos fora da câmera)
    local spawnZones = {
        top = { x = camX - buffer, y = camY - buffer, width = camWidth + buffer * 2, height = buffer },
        bottom = { x = camX - buffer, y = camY + camHeight, width = camWidth + buffer * 2, height = buffer },
        left = { x = camX - buffer, y = camY, width = buffer, height = camHeight },
        right = { x = camX + camWidth, y = camY, width = buffer, height = camHeight }
    }

    -- Pesos para cada direção. Aumentar o peso aumenta a chance de spawn naquela direção.
    local weights = { top = 1, bottom = 1, left = 1, right = 1 }
    local isMoving = playerVel and (playerVel.x ~= 0 or playerVel.y ~= 0)

    -- Se o jogador estiver se movendo, aumenta o peso das zonas à sua frente
    if isMoving then
        local movementBias = 4 -- Quão mais provável é o spawn na frente do jogador

        -- Aumenta o peso na direção do movimento.
        -- Se o jogador vai para cima (Y negativo), aumenta o peso da zona 'top'.
        if playerVel.y < -0.1 then weights.top = weights.top + movementBias end
        -- Se vai para baixo (Y positivo), aumenta o peso da zona 'bottom'.
        if playerVel.y > 0.1 then weights.bottom = weights.bottom + movementBias end
        -- Se vai para a esquerda (X negativo), aumenta o peso da zona 'left'.
        if playerVel.x < -0.1 then weights.left = weights.left + movementBias end
        -- Se vai para a direita (X positivo), aumenta o peso da zona 'right'.
        if playerVel.x > 0.1 then weights.right = weights.right + movementBias end
    end

    -- Seleciona uma zona com base nos pesos
    local totalWeight = weights.top + weights.bottom + weights.left + weights.right
    local randomVal = math.random() * totalWeight
    local selectedZoneKey

    if randomVal <= weights.top then
        selectedZoneKey = "top"
    elseif randomVal <= weights.top + weights.bottom then
        selectedZoneKey = "bottom"
    elseif randomVal <= weights.top + weights.bottom + weights.left then
        selectedZoneKey = "left"
    else
        selectedZoneKey = "right"
    end

    local selectedZone = spawnZones[selectedZoneKey]

    -- Gera uma posição aleatória dentro da zona selecionada
    local spawnX = math.random(selectedZone.x, selectedZone.x + selectedZone.width)
    local spawnY = math.random(selectedZone.y, selectedZone.y + selectedZone.height)

    return spawnX, spawnY
end

--- Desenha a barra de vida e o nome de um inimigo MVP específico.
---@param enemy BaseEnemy O inimigo MVP a ser desenhado.
---@param x number Posição X na tela.
---@param y number Posição Y na tela.
function EnemyManager:drawMvpBar(enemy, x, y)
    -- Configurações
    local barWidth = 100
    local barHeight = 8
    local nameToBarSpacing = 4
    local spaceAboveSprite = 5

    -- Informações de Rank e Cor
    local titleData = enemy.mvpTitleData
    local rank = titleData and titleData.rank or "S"
    local rankColors = Colors.rankDetails[rank] or Colors.rankDetails["E"]

    -- 1. Preparar texto e calcular sua altura
    local fullName = string.format("%s, %s", enemy.mvpProperName, titleData.name)
    love.graphics.setFont(Fonts.main)
    local font = love.graphics.getFont()
    local _, wrappedLines = font:getWrap(fullName, barWidth)
    local textHeight = #wrappedLines * font:getHeight()

    -- 2. Calcular a altura total e a posição do bloco
    local totalBlockHeight = textHeight + nameToBarSpacing + barHeight
    local spriteTopY = y - (enemy.radius or 32)
    local blockTopY = spriteTopY - spaceAboveSprite - totalBlockHeight

    local barX = x - (barWidth / 2)
    local barY = blockTopY + textHeight + nameToBarSpacing

    -- 3. Desenhar o Nome (manualmente, linha por linha)
    local currentTextY = blockTopY
    love.graphics.setColor(rankColors.gradientStart)
    for _, line in ipairs(wrappedLines) do
        local lineWidth = font:getWidth(line)
        love.graphics.print(line, x - (lineWidth / 2) + 1, currentTextY + 1)
        currentTextY = currentTextY + font:getHeight()
    end

    currentTextY = blockTopY
    love.graphics.setColor(rankColors.text)
    for _, line in ipairs(wrappedLines) do
        local lineWidth = font:getWidth(line)
        love.graphics.print(line, x - (lineWidth / 2), currentTextY)
        currentTextY = currentTextY + font:getHeight()
    end

    -- 4. Desenhar a Barra de Vida
    local healthRatio = enemy.currentHealth / enemy.maxHealth
    healthRatio = math.max(0, math.min(1, healthRatio))
    local currentHPFillWidth = barWidth * healthRatio

    love.graphics.setColor(Colors.bar_bg[1], Colors.bar_bg[2], Colors.bar_bg[3], 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

    if currentHPFillWidth > 0 then
        love.graphics.setColor(unpack(Colors.hp_fill))
        love.graphics.rectangle("fill", barX, barY, currentHPFillWidth, barHeight)
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(unpack(Colors.bar_border))
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)

    love.graphics.setColor(1, 1, 1, 1)
end

return EnemyManager
