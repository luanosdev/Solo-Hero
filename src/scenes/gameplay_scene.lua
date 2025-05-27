local SceneManager = require("src.core.scene_manager")

-- <<< NOVOS REQUIRES >>>
local Camera = require("src.config.camera")
local AnimationLoader = require("src.animations.animation_loader")
local LevelUpModal = require("src.ui.level_up_modal")
local RuneChoiceModal = require("src.ui.rune_choice_modal")
local HUD = require("src.ui.hud")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local InventoryScreen = require("src.ui.screens.inventory_screen")
local ItemDetailsModal = require("src.ui.item_details_modal")
local ManagerRegistry = require("src.managers.manager_registry")
local Bootstrap = require("src.core.bootstrap")
local TooltipManager = require("src.ui.tooltip_manager")
local colors = require("src.ui.colors")
local AssetManager = require("src.managers.asset_manager")
local portalDefinitions = require("src.data.portals.portal_definitions")
local Constants = require("src.config.constants")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local MapManager = require("src.managers.map_manager")
local RenderPipeline = require("src.core.render_pipeline")

local GameplayScene = {}
GameplayScene.__index = GameplayScene

-- Estado de Conjuração (Casting) para itens usáveis
GameplayScene.isCasting = false ---@type boolean
GameplayScene.castTimer = 0 ---@type number
GameplayScene.castDuration = 0 ---@type number
GameplayScene.castingItem = nil ---@type table|nil Instância do item sendo conjurado
GameplayScene.onCastCompleteCallback = nil ---@type function|nil
GameplayScene.currentCastType = nil ---@type string|nil -- Adicionado para armazenar o tipo de extração durante o cast

function GameplayScene:load(args)
    Logger.debug("GameplayScene", "GameplayScene:load - Inicializando sistemas de gameplay...")
    self.renderPipeline = RenderPipeline:new()
    self.portalId = args and args.portalId or "floresta_assombrada"
    self.hordeConfig = args and args.hordeConfig or nil
    self.hunterId = args and args.hunterId or nil

    -- Reseta estado de casting ao carregar a cena
    self:resetCastState()

    -- Carrega a definição completa do portal atual para mapDefinition
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
    -- self.camera = nil -- Camera é global
    -- REMOVIDO: self.groundTexture = nil (ChunkManager cuida do chão)
    -- REMOVIDO: self.grid = nil (ChunkManager cuida da grade)
    self.mapManager = nil -- INICIALIZA O MAPMANAGER AQUI

    if not fonts.main then fonts.load() end

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

    -- REMOVIDO: Carregamento de self.groundTexture e self.grid

    Camera:init()
    Logger.debug("GameplayScene", "Chamado Camera:init() no módulo global.")
    AnimationLoader.loadInitial() -- Carrega player e outras animações base
    if self.currentPortalData and self.currentPortalData.requiredUnitTypes then
        AnimationLoader.loadUnits(self.currentPortalData.requiredUnitTypes)
    else
        Logger.error("GameplayScene", string.format(
            "AVISO [GameplayScene:load]: Portal '%s' não possui requiredUnitTypes. Nenhuma animação de unidade específica do portal foi carregada.",
            self.portalId))
        -- Você pode querer carregar um conjunto padrão de unidades aqui como fallback, ou deixar vazio.
    end

    Bootstrap.initialize()

    local enemyMgr = ManagerRegistry:get("enemyManager")
    local dropMgr = ManagerRegistry:get("dropManager")
    local playerMgr = ManagerRegistry:get("playerManager")
    local itemDataMgr = ManagerRegistry:get("itemDataManager")
    local experienceOrbMgr = ManagerRegistry:get("experienceOrbManager")

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
                        -- Usar um tamanho máximo razoável para o batch, pode ser ajustado
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
        self.mapManager = MapManager:new(mapName, AssetManager) -- AssetManager já é global ou passado
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

    playerMgr:setupGameplay(ManagerRegistry, self.hunterId)
    local enemyManagerConfig = {
        hordeConfig = self.hordeConfig,
        playerManager = playerMgr,
        dropManager = dropMgr,
        mapManager = self.mapManager
    }
    enemyMgr:setupGameplay(enemyManagerConfig)

    local playerInitialPos = playerMgr.player.position
    if playerInitialPos then
        local initialCamX = playerInitialPos.x - (Camera.screenWidth / 2)
        local initialCamY = playerInitialPos.y - (Camera.screenHeight / 2)
        Camera:setPosition(initialCamX, initialCamY)
    else
        Camera:setPosition(0, 0)
    end

    --[[
    -- Test drop (mantido por enquanto)
    if dropMgr and playerMgr and playerMgr.player and itemDataMgr then
        local playerPos = playerMgr.player.position; local testWeaponId = "rune_aura_e"
        if itemDataMgr:getBaseItemData(testWeaponId) then
            dropMgr:createDrop({ type = "item", itemId = testWeaponId, quantity = 1 },
                { x = playerPos.x + 50, y = playerPos.y })
        end
    end
    --]]

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
    local mx, my = love.mouse.getPosition()

    -- 1. Atualiza UIs que podem estar visíveis (tooltips, hover de botões, etc.)
    InventoryScreen.update(dt, mx, my, self.inventoryDragState)
    if LevelUpModal.visible then LevelUpModal:update(dt) end
    if RuneChoiceModal.visible then RuneChoiceModal:update() end
    if ItemDetailsModal.isVisible then ItemDetailsModal:update(dt) end

    -- 2. Determina se alguma UI de bloqueio total está ativa
    local uiBlockingAllGameplay = LevelUpModal.visible or RuneChoiceModal.visible or ItemDetailsModal.isVisible

    -- 3. Lógica de Conjuração de Itens e Cancelamento por Movimento
    if self.isCasting then
        -- A conjuração progride a menos que uma UI de bloqueio total (LevelUp, etc.) esteja ativa.
        if not uiBlockingAllGameplay then
            self:updateCasting(dt) -- updateCasting já tem logs e pausa por modal
        end
        -- Movimento do jogador pode cancelar a conjuração.
        -- self:handlePlayerMovementCancellation() -- Chamada movida para dentro do if not self.isPaused ou após InputManager
    end

    -- 4. Define o estado de pausa principal da cena
    -- O jogo pausa se uma UI de bloqueio total estiver ativa,
    -- OU se o inventário estiver visível E NENHUMA conjuração estiver em progresso.
    self.isPaused = uiBlockingAllGameplay or (InventoryScreen.isVisible and not self.isCasting)

    -- 5. Atualiza InputManager (precisa saber se qualquer UI está ativa e o estado de pausa da cena)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:update(dt, uiBlockingAllGameplay or InventoryScreen.isVisible, self.isPaused)
    else
        Logger.error("GameplayScene", "AVISO - InputManager não encontrado no Registry para update")
    end

    -- 6. Atualização da lógica principal do jogo e movimentação
    if not self.isPaused then
        ManagerRegistry:update(dt) -- Atualiza Player, Enemy, Projectiles, Drops, Orbs, etc.

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

    -- 7. Lógica de Update do Drag do Inventário (já presente no código original, mantida)
    if InventoryScreen.isVisible and self.inventoryDragState.isDragging and self.inventoryDragState.draggedItem then
        -- Reseta informações do alvo no início do update
        self.inventoryDragState.targetGridId = nil
        self.inventoryDragState.targetSlotCoords = nil
        self.inventoryDragState.isDropValid = false

        -- Managers necessários (obter uma vez)
        local hunterManager = ManagerRegistry:get("hunterManager")
        local inventoryManager = ManagerRegistry:get("inventoryManager")
        local itemDataManager = ManagerRegistry:get("itemDataManager")

        if not hunterManager or not inventoryManager or not itemDataManager or not Constants then
            Logger.error("GameplayScene",
                "ERRO [GameplayScene.update - Drag]: Managers/Constants necessários não encontrados!")
            -- Poderia resetar o drag aqui, mas talvez seja melhor só não validar
        else
            local draggedItem = self.inventoryDragState.draggedItem
            local isRotated = self.inventoryDragState.draggedItemIsRotated

            -- Calcula dimensões visuais
            local visualW = draggedItem.gridWidth or 1
            local visualH = draggedItem.gridHeight or 1
            if isRotated then
                visualW = draggedItem.gridHeight or 1
                visualH = draggedItem.gridWidth or 1
            end

            -- Verifica hover sobre Slots de Equipamento (USA ÁREAS CACHEADAS DA CENA)
            local hoverEquipmentSlot = false
            for slotId, area in pairs(self.inventoryEquipmentAreas or {}) do
                if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                    self.inventoryDragState.targetGridId = "equipment"
                    self.inventoryDragState.targetSlotCoords = slotId
                    hoverEquipmentSlot = true

                    -- Verifica compatibilidade do item com o slot
                    local baseData = itemDataManager:getBaseItemData(draggedItem.itemBaseId)
                    local itemType = baseData and baseData.type
                    if itemType then
                        -- <<< CORRIGIDO: Determina o tipo esperado com base no slotId, como em EquipmentScreen >>>
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
                            -- Adicione outros slots de equipamento aqui (ring, amulet, etc.) se necessário
                        elseif string.sub(slotId, 1, #Constants.SLOT_IDS.RUNE) == Constants.SLOT_IDS.RUNE then -- Verifica prefixo 'rune_'
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
                    break -- Sai do loop de slots
                end
            end

            -- Verifica hover sobre Grade de Inventário (se não estiver sobre equipamento)
            if not hoverEquipmentSlot then
                local area = self.inventoryGridArea -- USA ÁREA CACHEADA DA CENA
                if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                    self.inventoryDragState.targetGridId = "inventory"

                    if not inventoryManager then
                        Logger.error("GameplayScene",
                            "ERRO GRAVE [GameplayScene.update - Drag]: inventoryManager é NIL ao tentar obter dimensões!")
                        self.inventoryDragState.isDropValid = false -- Impede drop se manager sumir
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
                                -- Verifica se pode colocar na grade (considera outros itens)
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
                                self.inventoryDragState.isDropValid = false -- Fora da grade
                            end
                        else
                            Logger.warn("GameplayScene",
                                "AVISO [GameplayScene.update - Drag]: inventoryManager:getDimensions() retornou nil ou inválido.")
                            self.inventoryDragState.isDropValid = false -- Impede drop se dimensões falharem
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

    -- 0. Limpa SpriteBatches de animação
    self.renderPipeline:reset()

    -- 2. Coleta renderizáveis NÃO-MAPA (EX: inimigos, jogador, drops)
    local playerMgr = ManagerRegistry:get("playerManager") ---@type PlayerManager
    local enemyMgr = ManagerRegistry:get("enemyManager") ---@type EnemyManager
    local dropMgr = ManagerRegistry:get("dropManager") ---@type DropManager
    local experienceOrbMgr = ManagerRegistry:get("experienceOrbManager") ---@type ExperienceOrbManager

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

    --Logger.debug("GameplayScene", "Chamando Camera:attach()...")
    Camera:attach()

    -- Desenha tudo que está sob a câmera usando o RenderPipeline
    self.renderPipeline:draw(self.mapManager, Camera.x, Camera.y)

    --Logger.debug("GameplayScene", "Chamando Camera:detach()...")
    Camera:detach()

    -- Desenha elementos de UI e outros que ficam sobre a câmera (ex: barras de vida de BaseEnemy)
    if playerMgr and playerMgr.drawFloatingTexts then
        playerMgr:drawFloatingTexts()
    end
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
    HUD:draw()
    TooltipManager.draw()

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
        love.graphics.setScissor()                               -- Limpa o scissor
        if fonts.main then love.graphics.setFont(fonts.main) end -- Reseta fonte
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

    -- Print de depuração para testar visibilidade básica
    love.graphics.setColor(1, 1, 0, 1) -- Amarelo
    love.graphics.print("DEBUG TEXT VISIBLE?", 10, love.graphics.getHeight() - 20)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.pop()
end

function GameplayScene:keypressed(key, scancode, isrepeat)
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
    local hunterId = playerManager:getCurrentHunterId()

    if not playerManager or not inventoryManager or not itemDataManager or not hunterId or not hunterManager or not archetypeManager then
        print("ERRO [GameplayScene:initiateExtraction]: Managers essenciais ou HunterID não encontrados!")
        SceneManager.switchScene("lobby_scene", { extractionSuccessful = false, irregularExit = true })
        return
    end

    -- Coleta de dados para HunterStatsColumn ANTES de modificar inventário/equipamentos
    local finalStatsForSummary = playerManager:getCurrentFinalStats()
    local archetypeIdsForSummary = hunterManager:getArchetypeIds(hunterId)

    local itemsToExtract = {}
    local equipmentToExtract = {}

    -- 1. Coleta Equipamentos
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
                        local newItemInstance = itemDataManager:createItemInstanceById(itemDataFromManager, 1) -- Cria uma instância com quantidade 1
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

    -- 2. Coleta Itens da Mochila
    if extractionType == "all_items" or extractionType == "all_items_instant" then
        if inventoryManager.getAllItemsGameplay then
            itemsToExtract = inventoryManager:getAllItemsGameplay()
            print(string.format("GameplayScene: %d itens coletados da mochila (tipo: %s).", #itemsToExtract,
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
                itemsToExtract = {}                                                      -- Inicia vazio
                local percentageToKeep = (extractionParams.percentageToKeep or 50) / 100 -- Default 50%
                local numToExtract = math.ceil(#allBackpackItems * percentageToKeep)
                numToExtract = math.max(1, numToExtract)                                 -- Garante pelo menos 1 se houver itens
                numToExtract = math.min(numToExtract, #allBackpackItems)                 -- Não tenta extrair mais do que tem

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
                    table.insert(itemsToExtract, allBackpackItems[randomIndex])
                end
                print(string.format("GameplayScene: %d itens da mochila selecionados aleatoriamente (tipo: %s).",
                    #itemsToExtract, extractionType))
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

    -- 3. Prepara os argumentos para a LobbyScene
    local extractionArgs = {
        extractionSuccessful = true,
        hunterId = hunterId,
        extractedItems = itemsToExtract,
        extractedEquipment = equipmentToExtract,
        -- Novos args para ExtractionSummaryScene
        portalName = self.currentPortalData and self.currentPortalData.name or "Portal Desconhecido",
        portalRank = self.currentPortalData and self.currentPortalData.rank or "E",
        gameplayStats = {}, -- Placeholder para estatísticas futuras
        -- Adiciona dados para HunterStatsColumn na ExtractionSummaryScene
        finalStats = finalStatsForSummary,
        archetypeIds = archetypeIdsForSummary,
        archetypeManagerInstance = archetypeManager
    }

    print("GameplayScene: Transicionando para ExtractionSummaryScene com dados de extração.")
    SceneManager.switchScene("extraction_summary_scene", extractionArgs)
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
            print(string.format(
                "  [ERROR] InventoryManager não encontrado. Não é possível consumir '%s'. Uso cancelado.", itemName))
            return false -- Não inicia o cast se o manager estiver faltando
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
        local mx, my = love.mouse.getPosition() -- Obter posições atuais do mouse
        TooltipManager.update(0, mx, my, nil)   -- dt=0 é ok aqui, o importante é o 'nil'
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

--- NOVO: Interrompe o processo de casting atual.
--- @param reason string (Opcional) Razão da interrupção.
function GameplayScene:interruptCast(reason)
    if not self.isCasting then return end
    print(string.format("GameplayScene: Conjuração de '%s' interrompida! Razão: %s",
        (self.castingItem and self.castingItem.itemBaseId) or "item desconhecido",
        reason or "desconhecida"))

    -- TODO: Feedback visual/sonoro da interrupção
    self:resetCastState()
end

--- NOVO: Reseta o estado de casting.
function GameplayScene:resetCastState()
    self.isCasting = false
    self.castTimer = 0
    self.castDuration = 0
    self.castingItem = nil
    self.onCastCompleteCallback = nil
    self.currentCastType = nil -- Limpa também o tipo de extração
    -- TODO: Parar feedback visual/sonoro de cast (barra de progresso, animação)
end

-- NOVA FUNÇÃO para cancelamento de conjuração por movimento
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

return GameplayScene
