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
local colors = require("src.ui.colors")
local AssetManager = require("src.managers.asset_manager")
local portalDefinitions = require("src.data.portals.portal_definitions")
local Constants = require("src.config.constants")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local MapManager = require("src.managers.map_manager")
local RenderPipeline = require("src.core.render_pipeline")
local Culling = require("src.core.culling")
local GameOverManager = require("src.managers.game_over_manager")
local BossHealthBarManager = require("src.managers.boss_health_bar_manager")
local lume = require("src.libs.lume")
local BossPresentationManager = require("src.managers.boss_presentation_manager")

local GameplayScene = {}
GameplayScene.__index = GameplayScene

-- Estado de Conjuração (Casting) para itens usáveis
GameplayScene.isCasting = false ---@type boolean
GameplayScene.castTimer = 0 ---@type number
GameplayScene.castDuration = 0 ---@type number
GameplayScene.castingItem = nil ---@type table|nil Instância do item sendo conjurado
GameplayScene.onCastCompleteCallback = nil ---@type function|nil
GameplayScene.currentCastType = nil ---@type string|nil -- Adicionado para armazenar o tipo de extração durante o cast
GameplayScene.initialItemInstanceIds = {}   -- Usado para rastrear itens saqueados

GameplayScene.gameOverManager = nil         -- Instância do GameOverManager
GameplayScene.bossPresentationManager = nil -- Instância do BossPresentationManager

function GameplayScene:load(args)
    Logger.debug("GameplayScene", "GameplayScene:load - Inicializando sistemas de gameplay...")
    self.renderPipeline = RenderPipeline:new()
    self.portalId = args and args.portalId or "floresta_assombrada"
    self.hordeConfig = args and args.hordeConfig or nil
    self.hunterId = args and args.hunterId or nil

    -- Reseta estado de casting ao carregar a cena
    self:resetCastState()

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

    local enemyMgr = ManagerRegistry:get("enemyManager")
    local dropMgr = ManagerRegistry:get("dropManager")
    local playerMgr = ManagerRegistry:get("playerManager")
    local itemDataMgr = ManagerRegistry:get("itemDataManager")
    local experienceOrbMgr = ManagerRegistry:get("experienceOrbManager")
    local hudGameplayManager = ManagerRegistry:get("hudGameplayManager")

    if not playerMgr or not enemyMgr or not dropMgr or not itemDataMgr or not experienceOrbMgr then
        local missing = {}
        if not playerMgr then table.insert(missing, "PlayerManager") end
        if not enemyMgr then table.insert(missing, "EnemyManager") end
        if not dropMgr then table.insert(missing, "DropManager") end
        if not itemDataMgr then table.insert(missing, "ItemDataManager") end
        if not experienceOrbMgr then table.insert(missing, "ExperienceOrbManager") end
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

    if self.currentPortalData and self.currentPortalData.map then
        local mapName = self.currentPortalData.map
        self.mapManager = MapManager:new(mapName, AssetManager)
        if self.mapManager then
            local mapLoaded = self.mapManager:loadMap()
            if mapLoaded then
                Logger.debug("GameplayScene", "MapManager carregou o mapa '" .. mapName .. "' com sucesso.")
            else
                Logger.error("GameplayScene", "ERRO - MapManager falhou ao carregar o mapa: " .. mapName)
            end
        else
            Logger.error("GameplayScene",
                "ERRO CRÍTICO - Falha ao criar instância do MapManager para o mapa: " .. mapName)
        end
    else
        Logger.error("GameplayScene",
            "ERRO CRÍTICO [GameplayScene:load]: 'map' não definido nos dados do portal para inicializar MapManager!")
    end

    playerMgr:setupGameplay(ManagerRegistry, self.hunterId, self.hudGameplayManager)
    local enemyManagerConfig = {
        hordeConfig = self.hordeConfig,
        playerManager = playerMgr,
        dropManager = dropMgr,
        mapManager = self.mapManager
    }
    enemyMgr:setupGameplay(enemyManagerConfig)
    hudGameplayManager:setupGameplay(self.hunterId)

    self:_snapshotInitialItems()

    -- DEBUG: Spawna uma arma de rank E aleatória perto do jogador
    local rankEWeapons = {
        "circular_smash_e_001",
        "cone_slash_e_001",
        "alternating_cone_strike_e_001",
        "flame_stream_e_001",
        "arrow_projectile_e_001",
        "chain_lightning_e_001"
    }
    local randomWeaponId = rankEWeapons[math.random(#rankEWeapons)]
    self:createDropNearPlayer(randomWeaponId)
    Logger.info("GameplayScene", "Arma de rank E aleatória dropada perto do jogador: " .. randomWeaponId)

    -- Configura o callback de morte do jogador para usar o GameOverManager
    playerMgr:setOnPlayerDiedCallback(function()
        -- Ações da GameplayScene ANTES de iniciar o Game Over
        if InventoryScreen.isVisible then InventoryScreen.isVisible = false end
        if LevelUpModal.visible then LevelUpModal.visible = false end
        if RuneChoiceModal.visible then RuneChoiceModal.visible = false end
        if ItemDetailsModal.isVisible then ItemDetailsModal.isVisible = false end
        if self.isCasting then self:interruptCast("Morte do jogador") end

        -- Obtém a causa da morte (último inimigo que causou dano)
        local lastDamageSource = playerMgr.lastDamageSource
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

    local playerInitialPos = playerMgr.player.position
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

    local playerPos = playerMgr.player.position;
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

    -- Atualiza a apresentação do boss se estiver ativa
    if self.bossPresentationManager:isActive() then
        self.bossPresentationManager:update(dt)

        -- Atualiza a animação do boss durante a apresentação
        if self.bossPresentationManager.boss then
            local playerMgr = ManagerRegistry:get("playerManager")
            local enemyMgr = ManagerRegistry:get("enemyManager")
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

    if self.isCasting then
        if not uiBlockingAllGameplay then
            self:updateCasting(dt)
        end
    end

    self.isPaused = uiBlockingAllGameplay or (InventoryScreen.isVisible and not self.isCasting)

    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        if not (uiBlockingAllGameplay or InventoryScreen.isVisible or self.isPaused) then
            inputMgr:update(dt, false, false)
        elseif uiBlockingAllGameplay or (InventoryScreen.isVisible and not self.isCasting) then
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
            self.mapManager:update(dt)
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

    Camera:attach()

    -- Desenha tudo que está sob a câmera usando o RenderPipeline
    self.renderPipeline:draw(self.mapManager, Camera.x, Camera.y)

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

    if hudGameplayManager then
        hudGameplayManager:draw(self.isPaused)
    end

    -- Desenha a apresentação do boss por cima de tudo
    if self.bossPresentationManager then
        self.bossPresentationManager:draw()
    end

    -- Desenha UI de Casting (exemplo simples)
    if self.isCasting and self.castDuration > 0 then
        local barWidth = 200
        local barHeight = 20
        local barX = (love.graphics.getWidth() - barWidth) / 2
        local barY = love.graphics.getHeight() - barHeight - 60
        local progress = math.min(1, self.castTimer / self.castDuration)

        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        love.graphics.setColor(0.5, 0.7, 1, 0.9)
        love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setScissor(barX, barY, barWidth * progress, barHeight)
        if fonts.main_small then love.graphics.setFont(fonts.main_small) end
        local castItemName = "Conjurando..."
        if self.castingItem then
            local itemDataMgr = ManagerRegistry:get("itemDataManager")
            if itemDataMgr then
                local baseData = itemDataMgr:getBaseItemData(self.castingItem.itemBaseId)
                if baseData and baseData.name then castItemName = baseData.name end
            end
        end
        love.graphics.printf(castItemName, barX, barY + (barHeight - (fonts.main_small:getHeight())) / 2, barWidth,
            "center")
        love.graphics.setScissor()
        if fonts.main then love.graphics.setFont(fonts.main) end
    end

    -- Desenha informações de Debug (opcional)
    if enemyMgr then
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
            self:requestUseItem(useItemData.item)
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
    print("GameplayScene:unload - Descarregando recursos do gameplay...")
    LevelUpModal.visible = false; RuneChoiceModal.visible = false; InventoryScreen.isVisible = false; ItemDetailsModal.isVisible = false
    if HUD.reset then HUD:reset() end
    local enemyMgr = ManagerRegistry:get("enemyManager"); if enemyMgr and enemyMgr.reset then enemyMgr:reset() end

    if self.mapManager and self.mapManager.destroy then
        self.mapManager:destroy()
        self.mapManager = nil
        Logger.debug("GameplayScene", "MapManager destruído.")
    end

    if self.dropManager and self.dropManager.destroy then
        self.dropManager:destroy()
        self.dropManager = nil
        Logger.debug("GameplayScene", "DropManager destruído.")
    end

    if self.experienceOrbManager and self.experienceOrbManager.destroy then
        self.experienceOrbManager:destroy()
        self.experienceOrbManager = nil
        Logger.debug("GameplayScene", "ExperienceOrbManager destruído.")
    end

    -- Reseta HUDGameplayManager se existir
    if self.hudGameplayManager and self.hudGameplayManager.destroy then
        self.hudGameplayManager:destroy()
    end

    if self.bossPresentationManager and self.bossPresentationManager.destroy then
        self.bossPresentationManager:destroy()
        self.bossPresentationManager = nil
    end

    if self.enemyManager and self.enemyManager.destroy then
        self.enemyManager:destroy()
        self.enemyManager = nil
        Logger.debug("GameplayScene", "EnemyManager destruído.")
    end
end

--- Inicia o processo de extração da gameplay.
--- Coleta itens da mochila da partida e equipamentos atuais do jogador,
--- e então transita para a LobbyScene, passando esses dados.
--- @param extractionType string Tipo de extração (ex: "equipment_only", "all_items", "random_equipment").
--- @param extractionParams table (Opcional) Parâmetros adicionais para a extração (ex: para "random_equipment").
function GameplayScene:initiateExtraction(extractionType, extractionParams)
    print(string.format("[GameplayScene] Iniciando extração. Tipo: %s", extractionType))
    self:resetCastState()

    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager
    local inventoryManager = ManagerRegistry:get("inventoryManager") ---@type InventoryManager
    local itemDataManager = ManagerRegistry:get("itemDataManager") ---@type ItemDataManager
    local hunterManager = ManagerRegistry:get("hunterManager") ---@type HunterManager
    local archetypeManager = ManagerRegistry:get("archetypeManager") ---@type ArchetypeManager
    local gameStatisticsManager = ManagerRegistry:get("gameStatisticsManager") ---@type GameStatisticsManager
    local hunterId = playerManager:getCurrentHunterId()

    if not playerManager or not inventoryManager or not itemDataManager or not hunterId or not hunterManager or not archetypeManager or not gameStatisticsManager then
        print("ERRO [GameplayScene:initiateExtraction]: Managers essenciais ou HunterID não encontrados!")
        SceneManager.switchScene("lobby_scene", { extractionSuccessful = false, irregularExit = true })
        return
    end

    -- Coleta de dados para HunterStatsColumn ANTES de modificar inventário/equipamentos
    local finalStatsForSummary = playerManager:getCurrentFinalStats()
    local archetypeIdsForSummary = hunterManager:getArchetypeIds(hunterId)

    local backpackItemsToExtract = {}
    local equipmentToExtract = {}

    local currentEquipment = playerManager:getCurrentEquipmentGameplay()
    if extractionType == "equipment_only" or extractionType == "all_items" or extractionType == "all_items_instant" or extractionType == "random_backpack_items_plus_equipment" then
        if currentEquipment then
            for slotId, itemDataFromManager in pairs(currentEquipment) do
                local finalItemInstance = nil
                if itemDataFromManager then
                    if type(itemDataFromManager) == "table" then
                        -- Já é uma ItemInstance (esperado)
                        finalItemInstance = itemDataFromManager
                        print(string.format("  - Coletando equipamento (instância) do slot %s: %s (ID: %s)",
                            slotId,
                            finalItemInstance.itemBaseId,
                            finalItemInstance.instanceId))
                    elseif type(itemDataFromManager) == "number" then
                        -- É um itemBaseId, precisa criar a instância
                        print(string.format(
                            "  - WARN: Equipamento do slot %s é um itemBaseId numérico: %d. Tentando criar instância.",
                            slotId, itemDataFromManager))
                        local newItemInstance = itemDataManager:createItemInstanceById(itemDataFromManager, 1)
                        if newItemInstance then
                            print(string.format("    - Instância criada para ID %d: %s (Instance ID: %s)",
                                itemDataFromManager, newItemInstance.itemBaseId, newItemInstance.instanceId))
                            finalItemInstance = newItemInstance
                        else
                            print(string.format(
                                "    - ERRO: Falha ao criar instância para itemBaseId %d do slot %s. Item não será extraído.",
                                itemDataFromManager, slotId))
                        end
                    else
                        print(string.format(
                            "  - WARN: Tipo de dado inesperado para equipamento no slot %s: %s. Item não será extraído.",
                            slotId, type(itemDataFromManager)))
                    end

                    if finalItemInstance then
                        equipmentToExtract[slotId] = finalItemInstance
                    end
                end
            end
        end
    end

    if extractionType == "all_items" or extractionType == "all_items_instant" then
        if inventoryManager.getAllItemsGameplay then
            backpackItemsToExtract = inventoryManager:getAllItemsGameplay()
            print(string.format("GameplayScene: %d itens coletados da mochila (tipo: %s).", #backpackItemsToExtract,
                extractionType))
        else
            error(
                "[GameplayScene:initiateExtraction]: Método inventoryManager:getAllItemsGameplay() não encontrado para tipo " ..
                extractionType)
        end
    elseif extractionType == "random_backpack_items" then
        if inventoryManager.getAllItemsGameplay then
            local allBackpackItems = inventoryManager:getAllItemsGameplay() or {}
            if #allBackpackItems > 0 then
                backpackItemsToExtract = {}
                local percentageToKeep = (extractionParams.percentageToKeep or 50) / 100
                local numToExtract = math.ceil(#allBackpackItems * percentageToKeep)
                numToExtract = math.max(1, numToExtract)
                numToExtract = math.min(numToExtract, #allBackpackItems)

                -- Embaralha os itens da mochila para pegar uma seleção aleatória
                local backpackIndices = {}
                for i = 1, #allBackpackItems do table.insert(backpackIndices, i) end

                for i = #backpackIndices, 2, -1 do
                    local j = math.random(i)
                    backpackIndices[i], backpackIndices[j] = backpackIndices[j], backpackIndices[i]
                end

                print(string.format("GameplayScene: Tentando extrair %d de %d itens da mochila aleatoriamente.",
                    numToExtract, #allBackpackItems))
                for i = 1, numToExtract do
                    local randomIndex = backpackIndices[i]
                    table.insert(backpackItemsToExtract, allBackpackItems[randomIndex])
                end
                print(string.format("GameplayScene: %d itens da mochila selecionados aleatoriamente (tipo: %s).",
                    #backpackItemsToExtract, extractionType))
            else
                print(string.format("GameplayScene: Nenhum item na mochila para selecionar aleatoriamente (tipo: %s).",
                    extractionType))
            end
        else
            error(
                "[GameplayScene:initiateExtraction]: Método inventoryManager:getAllItemsGameplay() não encontrado para tipo " ..
                extractionType)
        end
    else
        print(string.format("GameplayScene: Nenhum item da mochila será extraído (tipo: %s).", extractionType))
    end

    -- COMBINA todos os itens extraídos (equipamento + mochila) para identificar o loot
    local allFinalItems = {}
    for _, itemInstance in pairs(equipmentToExtract) do
        table.insert(allFinalItems, itemInstance)
    end
    for _, itemInstance in ipairs(backpackItemsToExtract) do
        table.insert(allFinalItems, itemInstance)
    end

    -- IDENTIFICA os itens que foram looteados de fato
    local lootedItems = self:_getLootedItems(allFinalItems)

    -- Prepara os parâmetros para a cena de resumo
    local hunterData = hunterManager:getHunterData(hunterId)
    local params = {
        wasSuccess = true,
        hunterId = hunterId,
        hunterData = hunterData,
        portalData = self.currentPortalData,
        -- Passa os itens que vão para o storage/loadout
        extractedItems = backpackItemsToExtract,
        extractedEquipment = equipmentToExtract,
        -- Passa APENAS os itens que contam para a reputação
        lootedItems = lootedItems,
        -- Passa dados para a tela de resumo pós-partida
        finalStats = finalStatsForSummary,
        archetypeIds = archetypeIdsForSummary,
        archetypeManagerInstance = archetypeManager,
        gameplayStats = gameStatisticsManager:getRawStats()
    }

    print("[GameplayScene] Transicionando para ExtractionSummaryScene com dados de extração...")
    SceneManager.switchScene("extraction_summary_scene", params)
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

--- Solicita o uso de um item.
--- Verifica se o item é usável, CONSOME se aplicável, e inicia o processo de "casting".
--- @param itemInstance table A instância do item a ser usado (do inventário da partida).
--- @return boolean True se o uso foi iniciado com sucesso (e item consumido, se aplicável), false caso contrário.
function GameplayScene:requestUseItem(itemInstance)
    if self.isCasting then
        print("GameplayScene: Já está conjurando outro item.")
        -- TODO: Feedback para o jogador (som de erro, mensagem?)
        return false
    end

    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        error("[RequestUseItem] ERRO CRÍTICO: ItemDataManager não encontrado.")
        return false
    end

    local baseData = itemDataManager:getBaseItemData(itemInstance.itemBaseId)
    if not baseData or not baseData.useDetails then
        print(string.format("[RequestUseItem] Falha: Item '%s' não é usável ou não tem useDetails.",
            itemInstance.itemBaseId))
        return false
    end

    local useDetails = baseData.useDetails
    local itemName = baseData.name or itemInstance.itemBaseId

    print(string.format("[RequestUseItem] Tentando usar: %s (ID da Instância: %s)", itemName,
        itemInstance.instanceId or "N/A"))

    if useDetails.consumesOnUse then
        print(string.format("  Item '%s' é consumível. Tentando remover...", itemName))
        local inventoryManager = ManagerRegistry:get("inventoryManager") ---@type InventoryManager
        if inventoryManager then
            local removed = inventoryManager:removeItemInstance(itemInstance.instanceId, 1)
            if removed then
                print(string.format("  [SUCCESS] Item '%s' consumido com sucesso do inventário.", itemName))

                local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager
                if playerManager then
                    local itemRarity = itemInstance.rarity or 'E'
                    local rankStyle = colors.rankDetails[itemRarity]
                    local textColor = (rankStyle and rankStyle.text) or colors.text_main
                    local props = {
                        textColor = textColor,
                        scale = 1.2,
                        velocityY = -60,
                        lifetime = 2.0,
                        baseOffsetY = -50,
                    }
                    playerManager:addFloatingText("Consumiu " .. itemName .. "!", props)
                    print(string.format("    Texto flutuante para '%s' adicionado.", itemName))
                else
                    print("    [WARN] PlayerManager não encontrado para texto flutuante de consumo.")
                end
            else
                print(string.format(
                    "  [FAIL] Falha ao consumir '%s'. inventoryManager:removeItemInstance retornou false. Uso cancelado.",
                    itemName))
                -- Se não puder consumir um item que deveria ser consumido, não inicia o cast.
                return false
            end
        else
            error(string.format(
                "  [ERROR] InventoryManager não encontrado. Não é possível consumir '%s'. Uso cancelado.", itemName))
            return false
        end
    else
        print(string.format("  Item '%s' não é consumível (consumesOnUse=false)."), itemName)
    end

    -- Configura o estado de conjuração
    self.isCasting = true
    self.castTimer = 0
    self.castDuration = useDetails.castTime or 0
    self.castingItem = itemInstance
    self.currentCastType = useDetails.extractionType

    print(string.format("  Iniciando conjuração de '%s'. Duração: %.2f seg. Tipo Ext: %s",
        itemName, self.castDuration, self.currentCastType or "N/A"))

    self.onCastCompleteCallback = function()
        local extractionTypeForThisCast = self.currentCastType -- Captura o valor atual
        local itemUsedName = itemName                          -- Captura o nome
        print(string.format("[CastCallback] Conclusão para '%s'. Tipo Ext: %s",
            itemUsedName, extractionTypeForThisCast or "N/A"))

        if extractionTypeForThisCast then
            self:initiateExtraction(extractionTypeForThisCast, useDetails.extractionRandomParams)
        else
            if baseData.type == "consumable" and useDetails.extractionType == nil and (string.find(itemInstance.itemBaseId, "teleport", 1, true) or string.find(baseData.name, "Teleporte", 1, true)) then
                error(string.format("[CastCallback] 'extractionType' é nil para o item de teleporte '%s'.", itemUsedName))
            else
                print(string.format("[CastCallback] Nenhum extractionType para '%s', ou item não é de extração.",
                    itemUsedName))
            end
        end
    end

    -- Fecha o inventário se estiver visível ao iniciar a conjuração
    if InventoryScreen.isVisible then
        InventoryScreen.isVisible = false
        print("  GameplayScene: Inventário fechado automaticamente ao iniciar a conjuração.")
        -- O estado de self.isPaused será reavaliado no próximo GameplayScene:update()

        -- Informa imediatamente ao TooltipManager para limpar/esconder o tooltip
        local mx, my = love.mouse.getPosition()        -- Obter posições atuais do mouse
        ItemDetailsModalManager.update(0, mx, my, nil) -- dt=0 é ok aqui, o importante é o 'nil'
        print("  GameplayScene: TooltipManager.update(0, mx, my, nil) chamado para esconder tooltip.")
    end

    -- Se o castTime for 0 (ou muito pequeno), executa o callback e reseta.
    if self.castDuration <= 0.01 then
        print(string.format("  Conjuração de '%s' é instantânea. Executando callback.", itemName))
        if self.onCastCompleteCallback then
            self.onCastCompleteCallback()
        else
            print("  [WARN] onCastCompleteCallback é nil para conjuração instantânea.")
        end
        self:resetCastState()
    else
        print(string.format("  Conjuração de '%s' com duração > 0.01s. updateCasting irá gerenciar.", itemName))
    end

    return true -- Uso/Cast iniciado com sucesso
end

--- Atualiza o estado da conjuração (casting) de um item.
--- Chamado em GameplayScene:update() se self.isCasting for verdadeiro.
---@param dt number Delta time.
function GameplayScene:updateCasting(dt)
    if not self.isCasting or not self.castingItem then
        return
    end

    if LevelUpModal.visible or RuneChoiceModal.visible or ItemDetailsModal.isVisible then
        print("[Casting-PAUSED] Modal visível, timer do cast pausado.")
        return
    end

    self.castTimer = self.castTimer + dt

    if self.castTimer >= self.castDuration then
        print(string.format("[Casting-COMPLETE] Cast (pós-consumo) concluído para: %s. Timer: %.2f, Duration: %.2f",
            self.castingItem.name or self.castingItem.itemBaseId, self.castTimer, self.castDuration))

        if self.onCastCompleteCallback then
            print("[Casting-CALLBACK] Executando onCastCompleteCallback...")
            self.onCastCompleteCallback()
        else
            print("[Casting-CALLBACK] onCastCompleteCallback é nil ao final do cast.")
        end

        self:resetCastState()
        print("[Casting-END] Estado de cast resetado.")
    end
end

--- Interrompe o processo de casting atual.
--- @param reason string (Opcional) Razão da interrupção.
function GameplayScene:interruptCast(reason)
    if not self.isCasting then return end
    print(string.format("GameplayScene: Conjuração de '%s' interrompida! Razão: %s",
        (self.castingItem and self.castingItem.itemBaseId) or "item desconhecido",
        reason or "desconhecida"))

    -- TODO: Feedback visual/sonoro da interrupção
    self:resetCastState()
end

--- Reseta o estado de casting.
function GameplayScene:resetCastState()
    self.isCasting = false
    self.castTimer = 0
    self.castDuration = 0
    self.castingItem = nil
    self.onCastCompleteCallback = nil
    self.currentCastType = nil -- Limpa também o tipo de extração
    -- TODO: Parar feedback visual/sonoro de cast (barra de progresso, animação)
end

--- Lida com o cancelamento da conjuração se o jogador se mover.
--- Também garante que a última posição do jogador seja armazenada para a verificação no próximo frame.
function GameplayScene:handlePlayerMovementCancellation()
    local playerMgr = ManagerRegistry:get("playerManager")
    if not playerMgr then return end

    -- playerManager:hasMovedSinceLastFrame() precisaria ser implementado no PlayerManager.
    -- Por enquanto, vamos assumir que ele existe e retorna true se o jogador se moveu.
    -- Se não existir, esta parte não fará nada até que seja implementada.
    if playerMgr.hasMovedSinceLastFrame and playerMgr:hasMovedSinceLastFrame() then
        if self.isCasting then
            print("GameplayScene: Movimento do jogador cancelou a conjuração.")
            self:interruptCast("Movimento do jogador")
        end
    end

    -- playerManager:storeLastFramePosition() também precisaria ser implementado no PlayerManager.
    if playerMgr.storeLastFramePosition then
        playerMgr:storeLastFramePosition()
    end
end

--- Tira um "snapshot" dos IDs de todos os itens que o jogador possui no início da fase.
function GameplayScene:_snapshotInitialItems()
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
        Logger.debug("GameplayScene", string.format("  - %d itens instanciados capturados do equipamento.", count))
    end
    Logger.debug("GameplayScene",
        string.format("Snapshot concluído. Total de %d IDs de itens únicos.",
            #self.initialItemInstanceIds))
end

--- Identifica os itens que foram adquiridos durante a incursão.
---@param allFinalItems table<ItemInstance> Lista completa de todos os itens no final (mochila + equipamento).
---@return table<ItemInstance> Uma lista contendo apenas as instâncias de itens que são novas.
function GameplayScene:_getLootedItems(allFinalItems)
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
            local distance = lume.distance(playerPos.x, playerPos.y, enemy.position.x, enemy.position.y)
            local triggerDistance = (Camera.screenWidth / Camera.scale) * 0.50 -- 50% da largura da tela

            if distance < triggerDistance then
                self.bossPresentationManager:start(enemy, playerManager)
                -- Para a verificação assim que a primeira apresentação começar
                return
            end
        end
    end
end

return GameplayScene
