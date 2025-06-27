local SceneManager = require("src.core.scene_manager")
local Camera = require("src.config.camera")
local AnimationLoader = require("src.animations.animation_loader")
local LevelUpModal = require("src.ui.level_up_modal")
local RuneChoiceModal = require("src.ui.rune_choice_modal")
local HUD = require("src.ui.hud")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local InventoryScreen = require("src.ui.screens.inventory_screen")
local ItemDetailsModal = require("src.ui._item_details_modal")
local ManagerRegistry = require("src.managers.manager_registry")
local Bootstrap = require("src.core.bootstrap")
local ItemDetailsModalManager = require("src.managers.item_details_modal_manager")
local AssetManager = require("src.managers.asset_manager")
local portalDefinitions = require("src.data.portals.portal_definitions")
local Constants = require("src.config.constants")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local ProceduralMapManager = require("src.managers.procedural_map_manager")
local RenderPipeline = require("src.core.render_pipeline")
local Culling = require("src.core.culling")
local GameOverManager = require("src.managers.game_over_manager")
local BossHealthBarManager = require("src.managers.boss_health_bar_manager")
local BossPresentationManager = require("src.managers.boss_presentation_manager")

local GameplayScene = {}
GameplayScene.__index = GameplayScene

GameplayScene.initialItemInstanceIds = {}   -- Usado para rastrear itens saqueados

GameplayScene.gameOverManager = nil         -- Instância do GameOverManager
GameplayScene.bossPresentationManager = nil -- Instância do BossPresentationManager

function GameplayScene:load(args)
    Logger.debug("GameplayScene", "GameplayScene:load - Inicializando sistemas de gameplay...")
    self.renderPipeline = RenderPipeline:new()
    self.portalId = args and args.portalId or "floresta_assombrada"
    self.hordeConfig = args and args.hordeConfig or nil
    self.hunterId = args and args.hunterId or nil

    -- Instancia e inicializa o GameOverManager
    self.gameOverManager = GameOverManager:new()
    self.gameOverManager:init(ManagerRegistry, SceneManager) -- Passa dependências
    self.gameOverManager:reset()                             -- Garante estado inicial limpo

    -- Instancia o BossPresentationManager
    self.bossPresentationManager = BossPresentationManager:new()

    -- Instancia o UiGameplayManager

    self.currentPortalData = portalDefinitions[self.portalId]
    if not self.currentPortalData then
        Logger.error("GameplayScene",
            string.format("ERRO CRÍTICO [GameplayScene:load]: Definição do portal '%s' não encontrada!", self.portalId))
    end
    -- Se hordeConfig não foi passado via args, pega do portalData (se existir)
    if not self.hordeConfig and self.currentPortalData.hordeConfig then
        self.hordeConfig = self.currentPortalData.hordeConfig
        Logger.debug("GameplayScene",
            string.format("GameplayScene: Usando hordeConfig do portalDefinition para '%s'", self.portalId))
    end

    -- Validações iniciais
    if not self.hordeConfig then
        Logger.error("GameplayScene",
            "ERRO CRÍTICO [GameplayScene:load]: Nenhuma hordeConfig fornecida ou encontrada no portalDefinition!")
    end
    if not self.hunterId then
        Logger.error("GameplayScene",
            "ERRO CRÍTICO [GameplayScene:load]: Nenhum hunterId fornecido!")
    end
    Logger.debug("GameplayScene",
        string.format("  - Carregando portal ID: %s, Hunter ID: %s", self.portalId, self.hunterId))

    self.isPaused = false
    self.mapManager = nil

    if not fonts.main then fonts.load() end
    -- Garante que a fonte de game over seja carregada
    if not fonts.gameOver then
        local success, font = pcall(love.graphics.newFont, "assets/fonts/Roboto-Bold.ttf", 48)
        if success then fonts.gameOver = font else fonts.gameOver = fonts.title_large or fonts.main end
    end
    if not fonts.gameOverDetails then
        local success, font = pcall(love.graphics.newFont, "assets/fonts/Roboto-Regular.ttf", 24)
        if success then fonts.gameOverDetails = font else fonts.gameOverDetails = fonts.main_small or fonts.main end
    end
    if not fonts.gameOverFooter then
        local success, font = pcall(love.graphics.newFont, "assets/fonts/Roboto-Regular.ttf", 20)
        if success then fonts.gameOverFooter = font else fonts.gameOverFooter = fonts.debug or fonts.main_small end
    end

    self.inventoryDragState = { isDragging = false, draggedItem = nil, draggedItemOffsetX = 0, draggedItemOffsetY = 0, sourceGridId = nil, sourceSlotId = nil, draggedItemIsRotated = false, targetGridId = nil, targetSlotCoords = nil, isDropValid = false }
    self.inventoryEquipmentAreas = {}
    self.inventoryGridArea = {}

    local success, shaderOrErr = pcall(love.graphics.newShader, "assets/shaders/glow.fs")
    if success then
        elements.setGlowShader(shaderOrErr); InventoryScreen.setGlowShader(shaderOrErr);
        Logger.debug("GameplayScene", "Glow shader carregado.")
    else
        Logger.warn("GameplayScene", "Aviso - Falha ao carregar glow shader.")
    end

    Camera:init()
    Logger.debug("GameplayScene", "Chamado Camera:init() no módulo global.")
    AnimationLoader.loadInitial()
    if self.currentPortalData and self.currentPortalData.requiredUnitTypes then
        AnimationLoader.loadUnits(self.currentPortalData.requiredUnitTypes)
    else
        Logger.error("GameplayScene", string.format(
            "AVISO [GameplayScene:load]: Portal '%s' não possui requiredUnitTypes. Nenhuma animação de unidade específica do portal foi carregada.",
            self.portalId))
    end

    Bootstrap.initialize()

    ---@type EnemyManager
    local enemyMgr = ManagerRegistry:get("enemyManager")
    ---@type DropManager
    local dropMgr = ManagerRegistry:get("dropManager")
    ---@type PlayerManager
    local playerMgr = ManagerRegistry:get("playerManager")
    ---@type ItemDataManager
    local itemDataMgr = ManagerRegistry:get("itemDataManager")
    ---@type ExperienceOrbManager
    local experienceOrbMgr = ManagerRegistry:get("experienceOrbManager")
    ---@type HUDGameplayManager
    local hudGameplayManager = ManagerRegistry:get("hudGameplayManager")
    ---@type ExtractionPortalManager
    local extractionPortalManager = ManagerRegistry:get("extractionPortalManager")
    ---@type ExtractionManager
    local extractionManager = ManagerRegistry:get("extractionManager")

    if not playerMgr or not enemyMgr or not dropMgr or not itemDataMgr or not experienceOrbMgr or not extractionPortalManager then
        local missing = {}
        if not playerMgr then table.insert(missing, "PlayerManager") end
        if not enemyMgr then table.insert(missing, "EnemyManager") end
        if not dropMgr then table.insert(missing, "DropManager") end
        if not itemDataMgr then table.insert(missing, "ItemDataManager") end
        if not experienceOrbMgr then table.insert(missing, "ExperienceOrbManager") end
        if not extractionPortalManager then table.insert(missing, "ExtractionPortalManager") end
        Logger.error("GameplayScene",
            "ERRO CRÍTICO [GameplayScene:load]: Falha ao obter managers: " .. table.concat(missing, ", "))
    end

    -- CRIAR SPRITEBATCHES PARA ANIMAÇÕES CARREGADAS
    if AnimatedSpritesheet and AnimatedSpritesheet.assets then
        for unitType, unitAssets in pairs(AnimatedSpritesheet.assets) do
            if unitAssets.sheets then
                for animName, sheetTexture in pairs(unitAssets.sheets) do
                    if sheetTexture and not self.renderPipeline.spriteBatchReferences[sheetTexture] then
                        local maxSpritesInBatch = enemyMgr and enemyMgr.maxEnemies or 200
                        local newBatch = love.graphics.newSpriteBatch(sheetTexture, maxSpritesInBatch)
                        self.renderPipeline:registerSpriteBatch(sheetTexture, newBatch)
                        Logger.debug("GameplayScene",
                            string.format("GameplayScene: Criado e Registrado SpriteBatch para textura de %s - %s",
                                unitType,
                                animName))
                    end
                end
            end
        end
    end

    local mapName = self.currentPortalData.map
    if not mapName then
        error("GameplayScene:load  O portal " .. self.portalId .. " não define um 'map'.")
    end
    self.mapManager = ProceduralMapManager:new(mapName, AssetManager)
    self.renderPipeline:setMapManager(self.mapManager) -- Configura no RenderPipeline
    Logger.debug("GameplayScene", "ProceduralMapManager instanciado e configurado no RenderPipeline.")

    playerMgr:setupGameplay(ManagerRegistry, self.hunterId)
    local enemyManagerConfig = {
        hordeConfig = self.hordeConfig,
        playerManager = playerMgr,
        dropManager = dropMgr,
        mapManager = self.mapManager
    }
    enemyMgr:setupGameplay(enemyManagerConfig)
    hudGameplayManager:setupGameplay()

    -- Limpa o estado do ExtractionManager ao carregar a cena
    extractionManager:reset(self.currentPortalData)
    extractionPortalManager:spawnPortals()

    self:_snapshotInitialItems()

    -- DEBUG: Spawna uma arma de rank E aleatória perto do jogador
    local rankEWeapons = {
        "circular_smash_e_001",
        "cone_slash_e_001",
        "alternating_cone_strike_e_001",
        "flame_stream_e_001",
        "arrow_projectile_e_001",
        "chain_lightning_e_001",
        "sequential_projectile_e_001",
        "burst_projectile_e_001",
    }
    local randomWeaponId = rankEWeapons[math.random(#rankEWeapons)]
    self:createDropNearPlayer(randomWeaponId)
    Logger.info("GameplayScene", "Arma de rank E aleatória dropada perto do jogador: " .. randomWeaponId)

    -- Configura o callback de morte do jogador para usar o GameOverManager
    playerMgr:setOnPlayerDiedCallback(function()
        Logger.info("GameplayScene", "Callback de morte do jogador acionado - iniciando limpeza para Game Over...")

        -- Executa limpeza específica para Game Over
        self:_cleanupForGameOver()

        -- Obtém a causa da morte (último inimigo que causou dano)
        local lastDamageSource = playerMgr.healthController:getLastDamageSource()
        local deathCause = "Desconhecido"
        if lastDamageSource then
            if lastDamageSource.isBoss then
                deathCause = string.format("Boss: %s", lastDamageSource.name or "Desconhecido")
            elseif lastDamageSource.isMVP then
                deathCause = string.format("MVP: %s", lastDamageSource.name or "Desconhecido")
            else
                deathCause = string.format("Inimigo: %s", lastDamageSource.name or "Desconhecido")
            end
        end

        self.gameOverManager:start(self.currentPortalData, deathCause)
    end)

    local playerInitialPos = playerMgr:getPlayerPosition()
    if playerInitialPos then
        local initialCamX = playerInitialPos.x - (Camera.screenWidth / 2)
        local initialCamY = playerInitialPos.y - (Camera.screenHeight / 2)
        Camera:setPosition(initialCamX, initialCamY)
    else
        Camera:setPosition(0, 0)
    end

    Logger.debug("GameplayScene", "GameplayScene:load concluído.")
end

function GameplayScene:createDropNearPlayer(dropId)
    local playerMgr = ManagerRegistry:get("playerManager")
    local dropMgr = ManagerRegistry:get("dropManager")
    local itemDataMgr = ManagerRegistry:get("itemDataManager")

    local playerPos = playerMgr:getPlayerPosition()
    if itemDataMgr:getBaseItemData(dropId) then
        dropMgr:createDrop({ type = "item", itemId = dropId, quantity = 1 },
            { x = playerPos.x + 250, y = playerPos.y })
    end
end

function GameplayScene:update(dt)
    -- Se Game Over, GameOverManager lida com update e bloqueia o resto
    if self.gameOverManager and self.gameOverManager.isGameOverActive then
        self.gameOverManager:update(dt)
        return
    end

    ---@type PlayerManager
    local playerMgr = ManagerRegistry:get("playerManager")
    ---@type EnemyManager
    local enemyMgr = ManagerRegistry:get("enemyManager")
    ---@type ExtractionPortalManager
    local extractionPortalManager = ManagerRegistry:get("extractionPortalManager")

    if extractionPortalManager then
        extractionPortalManager:update(dt)
    end

    -- Atualiza a apresentação do boss se estiver ativa
    if self.bossPresentationManager:isActive() then
        self.bossPresentationManager:update(dt)

        -- Atualiza a animação do boss durante a apresentação
        if self.bossPresentationManager.boss then
            self.bossPresentationManager.boss:update(dt, playerMgr, enemyMgr)
            -- Força a atualização da barra de vida do boss
            BossHealthBarManager:update(dt)
        end

        -- Trava o resto da lógica do jogo durante a apresentação
        return
    end

    local mx, my = love.mouse.getPosition()

    InventoryScreen.update(dt, mx, my, self.inventoryDragState)
    if LevelUpModal.visible then LevelUpModal:update(dt) end
    if RuneChoiceModal.visible then RuneChoiceModal:update() end
    if ItemDetailsModal.isVisible then ItemDetailsModal:update(dt) end

    local uiBlockingAllGameplay = LevelUpModal.visible or RuneChoiceModal.visible or ItemDetailsModal.isVisible

    self.isPaused = uiBlockingAllGameplay or (InventoryScreen.isVisible)

    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        if not (uiBlockingAllGameplay or InventoryScreen.isVisible or self.isPaused) then
            inputMgr:update(dt, false, false)
        elseif uiBlockingAllGameplay or (InventoryScreen.isVisible) then
            inputMgr:update(dt, true, true)
        end
    else
        Logger.error("GameplayScene", "AVISO - InputManager não encontrado no Registry para update")
    end

    if not self.isPaused then
        ManagerRegistry:update(dt)

        -- Verifica se um boss precisa ser apresentado
        self:checkForBossPresentation()

        if self.mapManager then
            -- Passa a posição do jogador para o update do mapa procedural
            local playerPosition = playerMgr:getPlayerPosition()
            self.mapManager:update(dt, playerPosition)
        end

        -- Lida com cancelamento de movimento AQUI, APÓS o PlayerManager ter sido atualizado por ManagerRegistry:update(dt)
        -- e ANTES que a próxima frame de input/movimento seja processada.
        --- self:handlePlayerMovementCancellation()
    else -- O jogo está pausado
        -- Mesmo se pausado (ex: pelo inventário aberto, sem conjuração),
        -- o PlayerManager pode precisar saber a última posição para `hasMovedSinceLastFrame()` funcionar corretamente
        -- se o jogador puder se mover enquanto o inventário está aberto (o que não deveria acontecer se o InputManager bloquear).
        -- Chamamos handlePlayerMovementCancellation aqui para garantir que storeLastFramePosition seja chamado.
        -- A verificação de cancelamento de cast não ocorrerá se isCasting for false, o que é bom.
        -- if InventoryScreen.isVisible and not uiBlockingAllGameplay then
        --     self:handlePlayerMovementCancellation()  -- Garante storeLastFramePosition
        -- end
    end

    if InventoryScreen.isVisible and self.inventoryDragState.isDragging and self.inventoryDragState.draggedItem then
        self.inventoryDragState.targetGridId = nil
        self.inventoryDragState.targetSlotCoords = nil
        self.inventoryDragState.isDropValid = false

        local hunterManager = ManagerRegistry:get("hunterManager")
        local inventoryManager = ManagerRegistry:get("inventoryManager")
        local itemDataManager = ManagerRegistry:get("itemDataManager")

        if not hunterManager or not inventoryManager or not itemDataManager or not Constants then
            Logger.error("GameplayScene",
                "ERRO [GameplayScene.update - Drag]: Managers/Constants necessários não encontrados!")
        else
            local draggedItem = self.inventoryDragState.draggedItem
            local isRotated = self.inventoryDragState.draggedItemIsRotated

            local visualW = draggedItem.gridWidth or 1
            local visualH = draggedItem.gridHeight or 1
            if isRotated then
                visualW = draggedItem.gridHeight or 1
                visualH = draggedItem.gridWidth or 1
            end

            local hoverEquipmentSlot = false
            for slotId, area in pairs(self.inventoryEquipmentAreas or {}) do
                if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                    self.inventoryDragState.targetGridId = "equipment"
                    self.inventoryDragState.targetSlotCoords = slotId
                    hoverEquipmentSlot = true

                    local baseData = itemDataManager:getBaseItemData(draggedItem.itemBaseId)
                    local itemType = baseData and baseData.type
                    if itemType then
                        local expectedType = nil
                        if slotId == Constants.SLOT_IDS.WEAPON then
                            expectedType = "weapon"
                        elseif slotId == Constants.SLOT_IDS.HELMET then
                            expectedType = "helmet"
                        elseif slotId == Constants.SLOT_IDS.CHEST then
                            expectedType = "chest"
                        elseif slotId == Constants.SLOT_IDS.GLOVES then
                            expectedType = "gloves"
                        elseif slotId == Constants.SLOT_IDS.BOOTS then
                            expectedType = "boots"
                        elseif slotId == Constants.SLOT_IDS.LEGS then
                            expectedType = "legs"
                        elseif string.sub(slotId, 1, #Constants.SLOT_IDS.RUNE) == Constants.SLOT_IDS.RUNE then
                            expectedType = "rune"
                        end
                        if expectedType and expectedType == itemType then
                            self.inventoryDragState.isDropValid = true
                        else
                            -- Tipos não batem, drop inválido
                            self.inventoryDragState.isDropValid = false
                        end
                    else
                        -- Item sem 'type', drop inválido
                        self.inventoryDragState.isDropValid = false
                    end
                    break
                end
            end

            -- Verifica hover sobre Grade de Inventário (se não estiver sobre equipamento)
            if not hoverEquipmentSlot then
                local area = self.inventoryGridArea
                if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                    self.inventoryDragState.targetGridId = "inventory"

                    if not inventoryManager then
                        Logger.error("GameplayScene",
                            "ERRO GRAVE [GameplayScene.update - Drag]: inventoryManager é NIL ao tentar obter dimensões!")
                        self.inventoryDragState.isDropValid = false
                    else
                        local gridDims = inventoryManager:getGridDimensions()
                        local invRows = gridDims and gridDims.rows
                        local invCols = gridDims and gridDims.cols

                        if invRows and invCols then
                            local ItemGridUI = require("src.ui.item_grid_ui")
                            local internalGrid = inventoryManager:getInternalGrid()
                            local ItemGridLogic = require("src.core.item_grid_logic")

                            self.inventoryDragState.targetSlotCoords = ItemGridUI.getSlotCoordsAtMouse(mx, my, invRows,
                                invCols, area.x, area.y, area.w, area.h)
                            if self.inventoryDragState.targetSlotCoords then
                                self.inventoryDragState.isDropValid = ItemGridLogic.canPlaceItemAt(
                                    internalGrid, -- Passa a grade interna
                                    invRows,
                                    invCols,
                                    draggedItem.instanceId, -- Passa ID do item sendo arrastado (opcional)
                                    self.inventoryDragState.targetSlotCoords.row,
                                    self.inventoryDragState.targetSlotCoords.col,
                                    visualW,
                                    visualH
                                )
                            else
                                self.inventoryDragState.isDropValid = false
                            end
                        else
                            Logger.warn("GameplayScene",
                                "AVISO [GameplayScene.update - Drag]: inventoryManager:getDimensions() retornou nil ou inválido.")
                            self.inventoryDragState.isDropValid = false
                        end
                    end
                end
            end
        end
    end
end

function GameplayScene:draw()
    local currentShader = love.graphics.getShader()
    if currentShader then
        Logger.warn("GameplayScene",
            "ALERTA [GameplayScene:draw]: Um shader está ativo no início do frame! Shader: " .. currentShader)
    end

    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    if not self.gameOverManager or not self.gameOverManager.isGameOverActive then
        self.renderPipeline:reset()
    end

    local playerMgr = ManagerRegistry:get("playerManager") ---@type PlayerManager
    local enemyMgr = ManagerRegistry:get("enemyManager") ---@type EnemyManager
    local dropMgr = ManagerRegistry:get("dropManager") ---@type DropManager
    local experienceOrbMgr = ManagerRegistry:get("experienceOrbManager") ---@type ExperienceOrbManager
    local hudGameplayManager = ManagerRegistry:get("hudGameplayManager") ---@type HUDGameplayManager
    local extractionPortalManager = ManagerRegistry:get("extractionPortalManager") ---@type ExtractionPortalManager
    local extractionManager = ManagerRegistry:get("extractionManager") ---@type ExtractionManager

    if playerMgr then
        playerMgr:collectRenderables(self.renderPipeline)
    end
    if enemyMgr then
        enemyMgr:collectRenderables(self.renderPipeline)
    end
    if dropMgr then
        dropMgr:collectRenderables(self.renderPipeline)
    end
    if experienceOrbMgr then
        experienceOrbMgr:collectRenderables(self.renderPipeline)
    end
    if extractionPortalManager then
        extractionPortalManager:collectRenderables(self.renderPipeline)
    end
    if extractionManager then
        extractionManager:collectRenderables(self.renderPipeline)
    end

    Camera:attach()

    -- Desenha tudo que está sob a câmera usando o RenderPipeline
    self.renderPipeline:draw(Camera.x, Camera.y)

    -- DEBUG: Desenha informações de debug dos inimigos (como raios de colisão)
    if DEBUG_SHOW_PARTICLE_COLLISION_RADIUS and enemyMgr and enemyMgr.getEnemies then
        local enemies = enemyMgr:getEnemies()
        if enemies then
            for _, enemyInstance in ipairs(enemies) do
                if enemyInstance and enemyInstance.isAlive and enemyInstance.drawDebug then
                    -- Verifica se o inimigo está aproximadamente na visão da câmera antes de desenhar debug
                    -- Isso é um culling simples para o debug, pode ser ajustado
                    if Culling.isInView(enemyInstance, Camera.x, Camera.y, Camera.screenWidth, Camera.screenHeight, 100) then
                        enemyInstance:drawDebug()
                    end
                end
            end
        end
    end

    Camera:detach()

    -- Desenha elementos de UI e outros que ficam sobre a câmera (ex: barras de vida de BaseEnemy)
    -- if playerMgr and playerMgr.drawFloatingTexts then
    --    playerMgr:drawFloatingTexts()
    --end
    -- Se BaseEnemy:draw desenha barras de vida diretamente, ele precisa ser chamado aqui para cada inimigo visível
    -- ou suas barras de vida precisam ser adicionadas à renderList com um depth maior.
    -- Exemplo simples (ineficiente, apenas para ilustração):
    if enemyMgr and enemyMgr.getEnemies then
        for _, enemyInstance in ipairs(enemyMgr:getEnemies()) do
            if enemyInstance.isAlive and enemyInstance.drawHealthBar then -- Supondo que exista um drawHealthBar
                -- enemyInstance:drawHealthBar()                             -- Esta função desenharia a barra de vida diretamente na tela
            end
        end
    end

    LevelUpModal:draw()
    RuneChoiceModal:draw()

    if InventoryScreen.isVisible then
        local eqAreas, invArea = InventoryScreen.draw(self.inventoryDragState)
        self.inventoryEquipmentAreas = eqAreas or {}
        self.inventoryGridArea = invArea or {}
    end
    ItemDetailsModal:draw()
    --HUD:draw()
    ItemDetailsModalManager.draw()

    hudGameplayManager:draw(self.isPaused)

    -- Desenha a apresentação do boss por cima de tudo
    if self.bossPresentationManager then
        self.bossPresentationManager:draw()
    end

    -- Desenha informações de Debug (opcional)
    if enemyMgr and DEV then
        local enemies = enemyMgr:getEnemies()
        if enemies and #enemies > 0 then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle('fill', love.graphics.getWidth() - 210, 5, 205, 150)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(fonts.debug or fonts.main_small)
            local debugText = string.format(
                "Enemy Info:\nTotal: %d | Ciclo: %d | Timer: %.1f",
                #enemies,
                enemyMgr.currentCycleIndex or 0,
                enemyMgr.gameTimer or 0
            )
            local bossCount = 0
            local bossLines = {}
            for _, enemy in ipairs(enemies) do
                if enemy.isBoss and enemy.isAlive then
                    bossCount = bossCount + 1
                    table.insert(bossLines, string.format(
                        "B%d: %s H:%.0f (%.0f,%.0f)",
                        bossCount, enemy.name or "?", enemy.currentHealth or 0, enemy.position.x, enemy.position.y
                    ))
                end
            end
            if bossCount > 0 then
                debugText = debugText .. "\nBosses Vivos:\n" .. table.concat(bossLines, "\n")
            end
            love.graphics.print(debugText, love.graphics.getWidth() - 200, 10)
        end
    end
    love.graphics.setFont(fonts.main)

    love.graphics.push()
    love.graphics.origin()

    love.graphics.pop()

    if self.gameOverManager and self.gameOverManager.isGameOverActive then
        self.gameOverManager:draw()
    end
end

function GameplayScene:keypressed(key, scancode, isrepeat)
    if self.gameOverManager and self.gameOverManager.isGameOverActive then
        self.gameOverManager:keypressed(key, scancode, isrepeat)
        return
    end

    if InventoryScreen.isVisible then
        local consumed, wantsToRotate = InventoryScreen.keypressed(key)
        if consumed and wantsToRotate then
            if self.inventoryDragState.isDragging then
                self.inventoryDragState.draggedItemIsRotated = not self
                    .inventoryDragState.draggedItemIsRotated
            end
            return
        elseif consumed then
            if not InventoryScreen.isVisible and self.inventoryDragState.isDragging then self.inventoryDragState = { isDragging = false } end
            return
        end
    end
    if key == "tab" and not isrepeat then
        local newVisibility = InventoryScreen.toggle(); self.isPaused = newVisibility
        if not newVisibility and self.inventoryDragState.isDragging then self.inventoryDragState = { isDragging = false } end
        return
    end
    if not self.isPaused and not InventoryScreen.isVisible then
        local inputMgr = ManagerRegistry:get("inputManager")
        if inputMgr then inputMgr:keypressed(key, self.isPaused) end
    end
end

function GameplayScene:keyreleased(key, scancode)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then inputMgr:keyreleased(key, self.isPaused) end
end

function GameplayScene:mousepressed(x, y, button, istouch, presses)
    -- Impede inputs durante a apresentação do boss
    if self.bossPresentationManager and self.bossPresentationManager:isActive() then
        return
    end

    if self.gameOverManager and self.gameOverManager.isGameOverActive then
        if self.gameOverManager.canExit then
            self.gameOverManager:handleExit()
            return
        end
        -- Ignora outros inputs durante o Game Over se não for para sair
        return
    end

    if InventoryScreen.isVisible then
        local consumed, dragStartData, useItemData = InventoryScreen.handleMousePress(x, y, button)

        if consumed and dragStartData then
            self.inventoryDragState.isDragging = true; self.inventoryDragState.draggedItem = dragStartData.item; self.inventoryDragState.sourceGridId =
                dragStartData.sourceGridId; self.inventoryDragState.sourceSlotId = dragStartData.sourceSlotId; self.inventoryDragState.draggedItemOffsetX =
                dragStartData.offsetX; self.inventoryDragState.draggedItemOffsetY = dragStartData.offsetY; self.inventoryDragState.draggedItemIsRotated =
                dragStartData.isRotated or false;
            self.inventoryDragState.targetGridId = nil; self.inventoryDragState.targetSlotCoords = nil; self.inventoryDragState.isDropValid = false;
            return
        elseif consumed and useItemData and useItemData.item then
            ---@type ExtractionManager
            local extractionManager = ManagerRegistry:get("extractionManager")
            if extractionManager then
                extractionManager:requestUseItem(useItemData.item)
            end
            return
        elseif consumed then
            return
        end
    end

    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then inputMgr:mousepressed(x, y, button, self.isPaused) end
end

function GameplayScene:mousemoved(x, y, dx, dy, istouch)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then inputMgr:mousemoved(x, y, dx, dy) end
end

function GameplayScene:mousereleased(x, y, button, istouch, presses)
    if self.inventoryDragState.isDragging then
        InventoryScreen.handleMouseRelease(self.inventoryDragState)
        self.inventoryDragState = { isDragging = false }
        return
    end
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then inputMgr:mousereleased(x, y, button, self.isPaused) end
end

function GameplayScene:unload()
    Logger.info(
        "gameplay_scene.unload.started",
        "[GameplayScene:unload] Iniciando descarregamento completo dos recursos do gameplay..."
    )

    -- Fecha todos os modais e UIs primeiro
    LevelUpModal.visible = false
    RuneChoiceModal.visible = false
    InventoryScreen.isVisible = false
    ItemDetailsModal.isVisible = false

    -- Reset HUD se disponível
    if HUD.reset then
        HUD:reset()
    end

    -- Limpa managers específicos do GameplayScene primeiro
    self:_cleanupGameplayManagers()

    -- Limpa sistemas locais do GameplayScene
    self:_cleanupLocalSystems()

    -- Força limpeza de memória
    collectgarbage("collect")

    Logger.info("gameplay_scene.unload.finalized", "[GameplayScene:unload] Descarregamento completo finalizado.")
end

--- Limpa todos os managers específicos do gameplay de forma segura
function GameplayScene:_cleanupGameplayManagers()
    Logger.debug("GameplayScene", "Iniciando limpeza dos managers de gameplay...")

    -- Lista de managers de gameplay na ordem correta de limpeza
    local gameplayManagers = {
        "extractionManager",
        "extractionPortalManager",
        "hudGameplayManager",
        "experienceOrbManager",
        "dropManager",
        "enemyManager",
        "playerManager",
        "inventoryManager",
        "inputManager"
    }

    for _, managerName in ipairs(gameplayManagers) do
        local manager = ManagerRegistry:tryGet(managerName)
        if manager then
            Logger.debug("gameplay_scene.cleanup_gameplay_managers.started", string.format("Limpando %s...", managerName))

            -- Tenta diferentes métodos de limpeza
            if manager.destroy and type(manager.destroy) == "function" then
                manager:destroy()
                Logger.debug(
                    "gameplay_scene.cleanup_gameplay_managers.destroyed",
                    string.format("%s destruído via destroy()", managerName)
                )
            elseif manager.reset and type(manager.reset) == "function" then
                manager:reset()
                Logger.debug(
                    "gameplay_scene.cleanup_gameplay_managers.reset",
                    string.format("%s limpo via reset()", managerName)
                )
            elseif manager.cleanup and type(manager.cleanup) == "function" then
                manager:cleanup()
                Logger.debug(
                    "gameplay_scene.cleanup_gameplay_managers.cleanup",
                    string.format("%s limpo via cleanup()", managerName)
                )
            else
                Logger.warn(
                    "gameplay_scene.cleanup_gameplay_managers.no_cleanup_method",
                    string.format("%s não possui método de limpeza adequado", managerName)
                )
            end

            -- Remove do registry para evitar referências pendentes
            ManagerRegistry:unregister(managerName)
            Logger.debug(
                "gameplay_scene.cleanup_gameplay_managers.unregistered",
                string.format("%s removido do ManagerRegistry", managerName)
            )
        end
    end
end

--- Limpa sistemas locais do GameplayScene
function GameplayScene:_cleanupLocalSystems()
    Logger.debug("gameplay_scene.cleanup_local_systems.started", "Limpando sistemas locais do GameplayScene...")

    -- Limpa ProceduralMapManager
    if self.mapManager then
        if self.mapManager.destroy and type(self.mapManager.destroy) == "function" then
            self.mapManager:destroy()
            Logger.debug("gameplay_scene.cleanup_local_systems.map_manager_destroyed", "ProceduralMapManager destruído")
        end
        self.mapManager = nil
    end

    -- Limpa RenderPipeline
    if self.renderPipeline then
        if self.renderPipeline.destroy and type(self.renderPipeline.destroy) == "function" then
            self.renderPipeline:destroy()
            Logger.debug("gameplay_scene.cleanup_local_systems.render_pipeline_destroyed", "RenderPipeline destruído")
        end
        self.renderPipeline = nil
    end

    -- Limpa GameOverManager
    if self.gameOverManager then
        if self.gameOverManager.destroy and type(self.gameOverManager.destroy) == "function" then
            self.gameOverManager:destroy()
        end
        self.gameOverManager = nil
        Logger.debug("gameplay_scene.cleanup_local_systems.game_over_manager_destroyed", "GameOverManager destruído")
    end

    -- Limpa BossPresentationManager
    if self.bossPresentationManager then
        if self.bossPresentationManager.destroy and type(self.bossPresentationManager.destroy) == "function" then
            self.bossPresentationManager:destroy()
        end
        self.bossPresentationManager = nil
        Logger.debug("gameplay_scene.cleanup_local_systems.boss_presentation_manager_destroyed",
        "BossPresentationManager destruído")
    end

    -- Limpa BossHealthBarManager global
    local BossHealthBarManager = require("src.managers.boss_health_bar_manager")
    if BossHealthBarManager and BossHealthBarManager.destroy then
        BossHealthBarManager:destroy()
        Logger.debug("GameplayScene", "BossHealthBarManager global destruído")
    end

    -- Limpa estado interno
    self.initialItemInstanceIds = {}
    self.inventoryDragState = { isDragging = false }
    self.inventoryEquipmentAreas = {}
    self.inventoryGridArea = {}
    self.currentPortalData = nil
    self.hordeConfig = nil
    self.hunterId = nil
    self.isPaused = false

    Logger.debug("GameplayScene", "Sistemas locais limpos")
end

--- Executa limpeza específica para situações de Game Over
function GameplayScene:_cleanupForGameOver()
    Logger.info("GameplayScene", "Executando limpeza específica para Game Over...")

    -- Para todas as animações e efeitos visuais
    if self.bossPresentationManager and self.bossPresentationManager:isActive() then
        self.bossPresentationManager:destroy()
    end

    -- Limpa todos os modais
    LevelUpModal.visible = false
    RuneChoiceModal.visible = false
    InventoryScreen.isVisible = false
    ItemDetailsModal.isVisible = false

    Logger.debug("gameplay_scene.cleanup_for_game_over.finalized", "Limpeza de Game Over concluída")
end

--- Tira um "snapshot" dos IDs de todos os itens que o jogador possui no início da fase.
function GameplayScene:_snapshotInitialItems()
    -- Esta lógica pode ser movida para o HunterManager ou permanecer aqui se for específica da cena.
    -- Por agora, vamos deixar aqui, mas poderia ser um candidato para refatoração futura.
    Logger.debug("GameplayScene", "Capturando snapshot dos itens iniciais...")
    self.initialItemInstanceIds = {}
    local inventoryManager = ManagerRegistry:get("inventoryManager") ---@type InventoryManager
    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager

    -- 1. Itens no inventário (mochila)
    if inventoryManager and inventoryManager.getAllItemsGameplay then
        local backpackItems = inventoryManager:getAllItemsGameplay()
        for _, itemInstance in ipairs(backpackItems) do
            if itemInstance and itemInstance.instanceId then
                self.initialItemInstanceIds[itemInstance.instanceId] = true
            end
        end
        Logger.debug("GameplayScene", string.format("  - %d itens capturados da mochila.", #backpackItems))
    end

    -- 2. Itens equipados
    if playerManager and playerManager.getCurrentEquipmentGameplay then
        local equippedItems = playerManager:getCurrentEquipmentGameplay()
        local count = 0
        for _, itemData in pairs(equippedItems) do
            -- CORREÇÃO: Verifica se o item é uma instância (tabela com instanceId)
            -- antes de tentar acessá-lo. Ignora se for apenas um itemBaseId (número).
            if type(itemData) == "table" and itemData.instanceId then
                self.initialItemInstanceIds[itemData.instanceId] = true
                count = count + 1
            end
        end
        Logger.debug(
            "gameplay_scene.snapshot_initial_items.captured_items",
            string.format("  - %d itens instanciados capturados do equipamento.", count)
        )
    end
    Logger.debug(
        "gameplay_scene.snapshot_initial_items.finalized",
        string.format("Snapshot concluído. Total de %d IDs de itens únicos.",
            #self.initialItemInstanceIds))
end

--- Identifica os itens que foram adquiridos durante a incursão.
---@param allFinalItems table<ItemInstance> Lista completa de todos os itens no final (mochila + equipamento).
---@return table<ItemInstance> Uma lista contendo apenas as instâncias de itens que são novas.
function GameplayScene:_getLootedItems(allFinalItems)
    -- This logic will be called by ExtractionManager if needed, but the manager has its own version now.
    -- Keeping it here for now in case it's used elsewhere, but it's likely dead code.
    local lootedItems = {}
    if not self.initialItemInstanceIds then
        Logger.warn("GameplayScene",
            "_getLootedItems chamada, mas initialItemInstanceIds não existe. Retornando todos os itens como loot.")
        return allFinalItems or {}
    end

    for _, itemInstance in ipairs(allFinalItems) do
        if itemInstance and itemInstance.instanceId and not self.initialItemInstanceIds[itemInstance.instanceId] then
            table.insert(lootedItems, itemInstance)
        end
    end
    Logger.debug("GameplayScene", string.format("Identificados %d itens saqueados.", #lootedItems))
    return lootedItems
end

--- DEBUG: Adiciona um item especificado diretamente ao inventário do jogador na partida.
--- Pode ser chamada via console do Lovebird.
--- @param itemId string O ID base do item a ser adicionado.
--- @param quantity integer (Opcional) A quantidade a ser adicionada (padrão 1).
function GameplayScene:debugAddItemToPlayerInventory(itemId, quantity)
    quantity = quantity or 1
    print(string.format("[DEBUG] Tentando adicionar %d de '%s' ao inventário do jogador...", quantity, itemId))

    local inventoryManager = ManagerRegistry:get("inventoryManager") ---@type InventoryManager
    local itemDataManager = ManagerRegistry:get("itemDataManager") ---@type ItemDataManager

    if not inventoryManager or not itemDataManager then
        print("[DEBUG] ERRO: InventoryManager ou ItemDataManager não encontrado no Registry.")
        return
    end

    if not itemDataManager:getBaseItemData(itemId) then
        print(string.format("[DEBUG] ERRO: Item com ID base '%s' não encontrado no ItemDataManager.", itemId))
        return
    end

    local addedQuantity = inventoryManager:addItem(itemId, quantity)
    if addedQuantity > 0 then
        print(string.format("[DEBUG] Adicionado %d de '%s' ao inventário.", addedQuantity, itemId))
    else
        print(
            string.format("[DEBUG] Não foi possível adicionar '%s' ao inventário (pode estar cheio ou item inválido)."),
            itemId)
    end
end

--- DEBUG: Cria um drop de item especificado perto do jogador.
--- Pode ser chamada via console do Lovebird.
--- @param itemId string O ID base do item a ser dropado.
--- @param quantity integer (Opcional) A quantidade do item (padrão 1).
function GameplayScene:debugDropItemAtPlayer(itemId, quantity)
    quantity = quantity or 1
    print(string.format("[DEBUG] Tentando dropar %d de '%s' perto do jogador...", quantity, itemId))

    local dropManager = ManagerRegistry:get("dropManager") ---@type DropManager
    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager
    local itemDataManager = ManagerRegistry:get("itemDataManager") ---@type ItemDataManager

    if not dropManager or not playerManager or not itemDataManager then
        print("[DEBUG] ERRO: DropManager, PlayerManager ou ItemDataManager não encontrado no Registry.")
        return
    end

    if not playerManager.player or not playerManager.player.position then
        print("[DEBUG] ERRO: Posição do jogador não disponível para dropar o item.")
        return
    end

    if not itemDataManager:getBaseItemData(itemId) then
        print(string.format("[DEBUG] ERRO: Item com ID base '%s' não encontrado no ItemDataManager.", itemId))
        return
    end

    local playerPos = playerManager.player.position
    local dropPosition = { x = playerPos.x + 50, y = playerPos.y } -- Dropa um pouco à direita do jogador

    local dropData = { type = "item", itemId = itemId, quantity = quantity }
    local success, message = dropManager:createDrop(dropData, dropPosition)

    if success then
        print(string.format("[DEBUG] Item '%s' dropado em (%.0f, %.0f)."), itemId, dropPosition.x, dropPosition.y)
    else
        print(string.format("[DEBUG] Falha ao dropar item '%s': %s"), itemId, message or "Erro desconhecido")
    end
end

--- Verifica se há um boss próximo que necessite de uma apresentação.
function GameplayScene:checkForBossPresentation()
    if self.bossPresentationManager:isActive() then return end

    local enemyManager = ManagerRegistry:get("enemyManager")
    local playerManager = ManagerRegistry:get("playerManager")
    if not enemyManager or not playerManager or not playerManager.player then return end

    local playerPos = playerManager.player.position
    local enemies = enemyManager:getEnemies()

    for _, enemy in ipairs(enemies) do
        if enemy.isBoss and not enemy.isPresented then
            local distanceX = math.abs(playerPos.x - enemy.position.x)
            local distanceY = math.abs(playerPos.y - enemy.position.y)

            local triggerDistanceX = (Camera.screenWidth / Camera.scale) * 0.3
            local triggerDistanceY = (Camera.screenHeight / Camera.scale) * 0.3

            if distanceX < triggerDistanceX and distanceY < triggerDistanceY then
                self.bossPresentationManager:start(enemy, playerManager)
                -- Para a verificação assim que a primeira apresentação começar
                return
            end
        end
    end
end

return GameplayScene
