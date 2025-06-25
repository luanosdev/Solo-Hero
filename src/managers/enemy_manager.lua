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
local Constants = require("src.config.constants")
local SpawnController = require("src.controllers.spawn_controller")
local Logger = require("src.libs.logger")

---@class EnemyManager
---@field enemies table<number, BaseEnemy>
---@field maxEnemies number
---@field nextEnemyId number
---@field gameTimer number
---@field bossDeathTimer number
---@field bossDeathDuration number
---@field lastBossDeathTime number
---@field playerManager PlayerManager
---@field dropManager DropManager
---@field enemyPool table<string, table<number, BaseEnemy>> Pool de inimigos reutilizáveis, categorizados por classe
---@field spawnController SpawnController|nil
---@field spatialGrid SpatialGridIncremental|nil
---@field mapDimensions table
---@field gridCellSize number
---@field despawnMargin number
local EnemyManager = {
    enemies = {},     -- Tabela contendo todas as instâncias de inimigos ativos
    maxEnemies = 800, -- Número máximo de inimigos permitidos na tela simultaneamente
    nextEnemyId = 1,  -- Próximo ID a ser atribuído a um inimigo
    enemyPool = {},   -- Pool de inimigos inativos para reutilização

    -- Estado e Tempo
    gameTimer = 0, -- Tempo total de jogo decorrido desde o início (em segundos)

    -- Timer para controlar quando esconder a barra de vida do boss após sua morte
    bossDeathTimer = 0,
    bossDeathDuration = 3, -- Tempo em segundos para manter a barra visível após a morte
    lastBossDeathTime = 0, -- Momento em que o último boss morreu
    spatialGrid = nil,
    mapDimensions = { width = 3000, height = 3000 },
    gridCellSize = 64,
    despawnMargin = 500,
    spawnController = nil,
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

    self.spawnController = SpawnController:new(self, self.playerManager, self.mapManager)
    self.spawnController:setup(config.hordeConfig)

    -- Para um mapa procedural "infinito", definimos uma grande "área de jogo" para o SpatialGrid.
    -- Isso garante que o sistema de detecção de colisão tenha limites para operar,
    -- mesmo que o mapa em si não tenha.
    local playableAreaSize = 20000 -- Define uma área de 20k x 20k pixels.
    self.mapDimensions = { width = playableAreaSize, height = playableAreaSize }
    -- Para um mundo grande, células de grid maiores são mais eficientes.
    self.gridCellSize = 256

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
end

-- Atualiza o estado do gerenciador de inimigos e todos os inimigos ativos
function EnemyManager:update(dt)
    self.gameTimer = self.gameTimer + dt

    -- Atualiza o controller de spawn
    if self.spawnController then
        self.spawnController:update(dt)
    end

    -- Atualiza o DamageNumberManager
    DamageNumberManager:update(dt)

    -- Atualiza o timer de morte do boss
    if self.lastBossDeathTime > 0 then
        self.bossDeathTimer = self.gameTimer - self.lastBossDeathTime
    end

    -- 4. Atualiza Inimigos Existentes (sempre executa)
    -- Itera de trás para frente para permitir remoção segura
    local camX, camY, camWidth, camHeight = Camera:getViewPort() -- Obtém a visão da câmera

    local margin = 300                                           -- Margem para culling de update (isOffScreen)

    local playerPosition = self.playerManager:getPlayerPosition()
    for i = #self.enemies, 1, -1 do
        local enemy = self.enemies[i]

        -- Lógica de reposicionamento para Boss/MVP
        if enemy and enemy.isAlive and (enemy.isBoss or enemy.isMVP) then
            if self.playerManager then
                local dx = enemy.position.x - playerPosition.x
                local dy = enemy.position.y - playerPosition.y
                local distance = math.sqrt(dx * dx + dy * dy)
                local repositionDistance = 1500 -- Distância em pixels para acionar o teleporte

                if distance > repositionDistance then
                    Logger.info("[EnemyManager]",
                        string.format("Reposicionando inimigo especial (ID: %d) por estar muito distante.", enemy.id))
                    self:repositionBossOrMvp(enemy)
                end
            end
        end

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

--- Retorna a lista de inimigos ativos.
---@return BaseEnemy[]
function EnemyManager:getEnemies()
    return self.enemies
end

--- Spawna um inimigo (normal ou MVP) com base nas opções.
---@param enemyClass table A classe do inimigo a ser spawnada.
---@param position { x: number, y: number } Posição de spawn.
---@param options table|nil Tabela de opções. Pode incluir: isMVP (boolean).
function EnemyManager:spawnSpecificEnemy(enemyClass, position, options)
    options = options or {}

    if not enemyClass then
        print("Erro: Tentativa de spawnar inimigo com classe nula.")
    end

    local enemyClassName = enemyClass.className
    if not enemyClassName then
        print("ERRO CRÍTICO [EnemyManager:spawnSpecificEnemy]: Classe de inimigo sem 'className'.")
    end

    -- Obter instância do pool ou criar nova
    local enemyInstance = self:getOrCreateEnemyInstance(enemyClassName, enemyClass)

    enemyInstance:reset(position, self.nextEnemyId)
    self.nextEnemyId = self.nextEnemyId + 1

    -- Se for um MVP, aplica as transformações
    if options.isMVP then
        self:transformToMVP(enemyInstance)
    end

    -- Adiciona à lista de ativos
    table.insert(self.enemies, enemyInstance)

    Logger.debug("[EnemyManager:spawnSpecificEnemy]",
        string.format("Inimigo ID: %d (Classe: %s, MVP: %s) spawnado em (%.1f, %.1f).",
            enemyInstance.id, enemyClassName, tostring(options.isMVP or false), position.x, position.y))


    return enemyInstance
end

--- Obtém um inimigo do pool ou cria uma nova instância.
---@param enemyClassName string
---@param enemyClass table
---@return BaseEnemy | BaseBoss
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
---@param enemy BaseEnemy
function EnemyManager:transformToMVP(enemy)
    if not enemy or not enemy.isAlive then return end

    -- 1. Marcação e Boosts Base
    enemy.isMVP = true
    enemy.maxHealth = enemy.maxHealth * 30
    enemy.radius = enemy.radius * 1.2
    enemy.knockbackResistance = Constants.KNOCKBACK_RESISTANCE.IMMUNE
    enemy.sprite.scale = enemy.sprite.scale * 1.2
    enemy.speed = enemy.speed * 1.5

    -- 2. Seleção de Título
    local mapRank = self.spawnController.worldConfig.mapRank or "E"
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

--- Spawna um boss específico.
---@param bossConfig BossSpawn Configuração do boss a ser spawnado.
---@param position { x: number, y: number } Posição de spawn.
function EnemyManager:spawnBoss(bossConfig, position)
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

    bossInstance:reset(position, self.nextEnemyId)
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
    return nil
end

--- Verifica se é possível spawnar mais inimigos.
---@return boolean
function EnemyManager:canSpawnMoreEnemies()
    return #self.enemies < self.maxEnemies
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

--- Reposiciona um boss ou MVP que está muito longe do jogador.
--- A nova posição é calculada na direção em que o jogador está se movendo.
---@param enemy BaseEnemy O inimigo a ser reposicionado.
function EnemyManager:repositionBossOrMvp(enemy)
    local camX, camY, camWidth, camHeight = Camera:getViewPort()
    local player = self.playerManager:getPlayerPosition()
    if not player then return end
    local playerVel = self.playerManager:getPlayerVelocity()

    -- Buffer para garantir que o inimigo seja reposicionado fora da tela
    local buffer = 150

    -- Zonas de reposicionamento ao redor da câmera
    local spawnZones = {
        top = { x = camX - buffer, y = camY - buffer, width = camWidth + buffer * 2, height = buffer },
        bottom = { x = camX - buffer, y = camY + camHeight, width = camWidth + buffer * 2, height = buffer },
        left = { x = camX - buffer, y = camY, width = buffer, height = camHeight },
        right = { x = camX + camWidth, y = camY, width = buffer, height = camHeight }
    }

    local weights = { top = 1, bottom = 1, left = 1, right = 1 }
    local isMoving = playerVel and (playerVel.x ~= 0 or playerVel.y ~= 0)

    if isMoving then
        local movementBias = 4 -- Aumenta a probabilidade de reposicionar na direção do movimento

        -- Aumenta o peso na direção do movimento do jogador.
        if playerVel.y < -0.1 then weights.top = weights.top + movementBias end      -- Movendo para cima, reposiciona para cima
        if playerVel.y > 0.1 then weights.bottom = weights.bottom + movementBias end -- Movendo para baixo, reposiciona para baixo
        if playerVel.x < -0.1 then weights.left = weights.left + movementBias end    -- Movendo para esquerda, reposiciona para esquerda
        if playerVel.x > 0.1 then weights.right = weights.right + movementBias end   -- Movendo para direita, reposiciona para direita
    end

    -- Seleciona a zona com base nos pesos
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
    local newX = math.random(selectedZone.x, selectedZone.x + selectedZone.width)
    local newY = math.random(selectedZone.y, selectedZone.y + selectedZone.height)

    -- Atualiza a posição do inimigo
    enemy.position.x = newX
    enemy.position.y = newY

    -- Importante: Atualiza a posição no spatial grid para que as colisões funcionem corretamente
    if self.spatialGrid then
        self.spatialGrid:updateEntityInGrid(enemy)
    end
end

return EnemyManager
