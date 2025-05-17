local SceneManager = require("src.core.scene_manager")

-- <<< NOVOS REQUIRES >>>
local Camera = require("src.config.camera")
local AnimationLoader = require("src.animations.animation_loader") -- Embora loadAll seja chamado aqui, pode ser necessário em outros lugares
local LevelUpModal = require("src.ui.level_up_modal")
local RuneChoiceModal = require("src.ui.rune_choice_modal")
local HUD = require("src.ui.hud")
local fonts = require("src.ui.fonts") -- Já era usado no loading, mas essencial aqui
local elements = require("src.ui.ui_elements")
local InventoryScreen = require("src.ui.screens.inventory_screen")
local ItemDetailsModal = require("src.ui.item_details_modal")
local ManagerRegistry = require("src.managers.manager_registry")
local Bootstrap = require("src.core.bootstrap")
local TooltipManager = require("src.ui.tooltip_manager")

local AssetManager = require("src.managers.asset_manager")
local ChunkManager = require("src.managers.chunk_manager")
local portalDefinitions = require("src.data.portals.portal_definitions") -- Para mapDefinition
local Constants = require("src.config.constants")

local GameplayScene = {}
GameplayScene.__index = GameplayScene -- <<< ADICIONADO __index >>>

-- Estado de Conjuração (Casting) para itens usáveis
GameplayScene.isCasting = false ---@type boolean
GameplayScene.castTimer = 0 ---@type number
GameplayScene.castDuration = 0 ---@type number
GameplayScene.castingItem = nil ---@type table|nil Instância do item sendo conjurado
GameplayScene.onCastCompleteCallback = nil ---@type function|nil

function GameplayScene:load(args)
    print("GameplayScene:load - Inicializando sistemas de gameplay...")
    self.renderList = {} -- <<< ADICIONADO PARA INICIALIZAR A LISTA DE RENDERIZAÇÃO
    self.portalId = args and args.portalId or "floresta_assombrada"
    self.hordeConfig = args and args.hordeConfig or nil
    self.hunterId = args and args.hunterId or nil

    -- Reseta estado de casting ao carregar a cena
    self:resetCastState()

    -- Carrega a definição completa do portal atual para mapDefinition
    self.currentPortalData = portalDefinitions[self.portalId]
    if not self.currentPortalData then
        error(string.format("ERRO CRÍTICO [GameplayScene:load]: Definição do portal '%s' não encontrada!", self.portalId))
    end
    -- Se hordeConfig não foi passado via args, pega do portalData (se existir)
    if not self.hordeConfig and self.currentPortalData.hordeConfig then
        self.hordeConfig = self.currentPortalData.hordeConfig
        print(string.format("GameplayScene: Usando hordeConfig do portalDefinition para '%s'", self.portalId))
    end

    -- Validações iniciais
    if not self.hordeConfig then
        error("ERRO CRÍTICO [GameplayScene:load]: Nenhuma hordeConfig fornecida ou encontrada no portalDefinition!")
    end
    if not self.hunterId then error("ERRO CRÍTICO [GameplayScene:load]: Nenhum hunterId fornecido!") end
    print(string.format("  - Carregando portal ID: %s, Hunter ID: %s", self.portalId, self.hunterId))

    self.isPaused = false
    -- self.camera = nil -- Camera é global
    -- REMOVIDO: self.groundTexture = nil (ChunkManager cuida do chão)
    -- REMOVIDO: self.grid = nil (ChunkManager cuida da grade)

    if not fonts.main then fonts.load() end

    self.inventoryDragState = { isDragging = false, draggedItem = nil, draggedItemOffsetX = 0, draggedItemOffsetY = 0, sourceGridId = nil, sourceSlotId = nil, draggedItemIsRotated = false, targetGridId = nil, targetSlotCoords = nil, isDropValid = false }
    self.inventoryEquipmentAreas = {}
    self.inventoryGridArea = {}

    local success, shaderOrErr = pcall(love.graphics.newShader, "assets/shaders/glow.fs")
    if success then
        elements.setGlowShader(shaderOrErr); InventoryScreen.setGlowShader(shaderOrErr); print(
            "GameplayScene: Glow shader carregado.")
    else
        print("GameplayScene: Aviso - Falha ao carregar glow shader.", shaderOrErr)
    end

    -- REMOVIDO: Carregamento de self.groundTexture e self.grid

    Camera:init()
    print("GameplayScene: Chamado Camera:init() no módulo global.")
    AnimationLoader.loadAll()

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
        error("ERRO CRÍTICO [GameplayScene:load]: Falha ao obter managers: " .. table.concat(missing, ", "))
    end

    playerMgr:setupGameplay(ManagerRegistry, self.hunterId)
    local enemyManagerConfig = { hordeConfig = self.hordeConfig, playerManager = playerMgr, dropManager = dropMgr }
    enemyMgr:setupGameplay(enemyManagerConfig)

    -- <<< ADICIONADO: Inicialização do ChunkManager >>>
    if self.currentPortalData and self.currentPortalData.mapDefinition then
        local gameSeed = os.time()                                             -- Ou uma seed específica
        local chunkSize = self.currentPortalData.mapDefinition.chunkSize or 32 -- Pega do mapDef ou usa default
        ChunkManager:initialize(self.currentPortalData, chunkSize, AssetManager, gameSeed)
        print("GameplayScene: ChunkManager inicializado.")
    else
        error(
            "ERRO CRÍTICO [GameplayScene:load]: mapDefinition não encontrado nos dados do portal para inicializar ChunkManager!")
    end

    local playerInitialPos = playerMgr.player.position
    if playerInitialPos then
        local initialCamX = playerInitialPos.x - (Camera.screenWidth / 2)
        local initialCamY = playerInitialPos.y - (Camera.screenHeight / 2)
        Camera:setPosition(initialCamX, initialCamY)
    else
        Camera:setPosition(0, 0)
    end

    -- Test drop (mantido por enquanto)
    if dropMgr and playerMgr and playerMgr.player and itemDataMgr then
        local playerPos = playerMgr.player.position; local testWeaponId = "rune_aura_e"
        if itemDataMgr:getBaseItemData(testWeaponId) then
            dropMgr:createDrop({ type = "item", itemId = testWeaponId, quantity = 1 },
                { x = playerPos.x + 50, y = playerPos.y })
        end
    end
    print("GameplayScene:load concluído.")
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
    InventoryScreen.update(dt, mx, my)
    if LevelUpModal.visible then LevelUpModal:update(dt) end

    local shouldBePaused = LevelUpModal.visible or RuneChoiceModal.visible or InventoryScreen.isVisible or
        ItemDetailsModal.isVisible
    self.isPaused = shouldBePaused

    -- 3. <<< LÓGICA DE UPDATE DO DRAG DO INVENTÁRIO >>>
    -- Deve rodar mesmo se pausado para o feedback visual do drag funcionar
    if InventoryScreen.isVisible and self.inventoryDragState.isDragging and self.inventoryDragState.draggedItem then
        -- Reseta informações do alvo no início do update
        self.inventoryDragState.targetGridId = nil
        self.inventoryDragState.targetSlotCoords = nil
        self.inventoryDragState.isDropValid = false

        -- Managers necessários (obter uma vez)
        local hunterManager = ManagerRegistry:get("hunterManager")
        local inventoryManager = ManagerRegistry:get("inventoryManager")
        local itemDataManager = ManagerRegistry:get("itemDataManager")
        local Constants = require("src.config.constants")

        if not hunterManager or not inventoryManager or not itemDataManager or not Constants then
            print("ERRO [GameplayScene.update - Drag]: Managers/Constants necessários não encontrados!")
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
                        print(
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
                            print(
                                "AVISO [GameplayScene.update - Drag]: inventoryManager:getDimensions() retornou nil ou inválido.")
                            self.inventoryDragState.isDropValid = false -- Impede drop se dimensões falharem
                        end
                    end
                end
            end
        end
    end
    -- <<< FIM: Lógica de Update do Drag >>>

    -- 4. Atualiza InputManager (passa se UI está ativa E se está pausado)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        -- Passa true para uiActive se QUALQUER modal/inventário estiver visível (shouldBePaused)
        -- Passa o estado de pausa da cena (self.isPaused)
        inputMgr:update(dt, shouldBePaused, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para update")
    end

    -- 5. <<< ATUALIZAÇÃO PRINCIPAL DO JOGO >>>
    -- Só atualiza a lógica principal do jogo se NÃO estiver pausado
    if not self.isPaused then
        -- Atualiza todos os managers do jogo (movimento, inimigos, projéteis, player state, etc.)
        ManagerRegistry:update(dt)
        -- Outras lógicas de gameplay que devem pausar...
        -- Ex: Timers específicos da cena, etc.

        -- <<< ADICIONADO: Atualização do ChunkManager >>>
        local playerMgr = ManagerRegistry:get("playerManager")
        if playerMgr and playerMgr.player and playerMgr.player.position then
            local tileSize = Constants.TILE_SIZE
            local playerWorldTileX = math.floor(playerMgr.player.position.x / tileSize)
            local playerWorldTileY = math.floor(playerMgr.player.position.y / (tileSize / 2))
            ChunkManager:update(playerWorldTileX, playerWorldTileY, Camera.x, Camera.y)
        else
            print("GameplayScene WARN: Não foi possível atualizar ChunkManager - player ausente.")
        end
    else
        -- O jogo está pausado.
        -- Lógica que pode rodar enquanto pausado (se houver, ex: animações de UI que não dependem do dt do jogo)
        -- ...
    end

    -- 6. Atualiza ItemDetailsModal se ele precisa de update mesmo pausado
    -- (Movido para fora do if not self.isPaused, mas pode ir para seção 1 também)
    ItemDetailsModal:update(dt, mx, my)
end

function GameplayScene:draw()
    -- Adicione este log para teste:
    local currentShader = love.graphics.getShader()
    if currentShader then
        print("ALERTA [GameplayScene:draw]: Um shader está ativo no início do frame! Shader: ", currentShader)
    else
        -- print("[GameplayScene:draw]: Nenhum shader ativo no início do frame.") -- Log opcional para confirmar que está nil
    end

    love.graphics.setBackgroundColor(0.1, 0.1, 0.1)
    love.graphics.clear(0.1, 0.1, 0.1, 1)

    -- 1. Limpa a lista de renderização
    for k in pairs(self.renderList) do self.renderList[k] = nil end

    -- 2. Coleta todos os renderizáveis
    if ChunkManager then
        ChunkManager:collectRenderables(Camera.x, Camera.y, self.renderList)
    end

    -- Obtém os managers do Registry para garantir que temos as instâncias corretas
    local playerMgr = ManagerRegistry:get("playerManager")
    local enemyMgr = ManagerRegistry:get("enemyManager")
    local dropMgr = ManagerRegistry:get("dropManager")
    local experienceOrbMgr = ManagerRegistry:get("experienceOrbManager")

    if playerMgr then
        playerMgr:collectRenderables(Camera.x, Camera.y, self.renderList)
    end
    if enemyMgr then
        enemyMgr:collectRenderables(Camera.x, Camera.y, self.renderList)
    end
    if dropMgr then -- Supondo que exista e tenha collectRenderables
        dropMgr:collectRenderables(Camera.x, Camera.y, self.renderList)
    end
    if experienceOrbMgr then
        experienceOrbMgr:collectRenderables(Camera.x, Camera.y, self.renderList)
    end

    -- 3. Ordena a lista de renderização
    table.sort(self.renderList, function(a, b)
        if a.depth == b.depth then
            return a.sortY < b.sortY -- Dentro da mesma camada (depth), ordena por sortY
        end
        return a.depth < b.depth     -- Primariamente, ordena por camada (depth)
    end)

    -- 4. Desenha os objetos ordenados
    Camera:attach()
    for _, item in ipairs(self.renderList) do
        if item.type == "tile_batch" then                         -- <<< NOVA CONDIÇÃO >>>
            love.graphics.draw(item.batch)                        -- Desenha o SpriteBatch diretamente
        elseif item.type == "decoration_batch" then               -- <<< NOVA CONDIÇÃO PARA DECORAÇÕES >>>
            love.graphics.draw(item.batch)                        -- Desenha o SpriteBatch de decorações
        elseif item.type == "player" or item.type == "enemy" then -- Assumindo que player/enemy adicionam 'drawFunction'
            if item.drawFunction then
                item.drawFunction()
            elseif item.image then -- Fallback simples se tiver imagem e posições
                love.graphics.draw(item.image, item.drawX, item.drawY, item.rotation_rad or 0, item.scaleX or 1,
                    item.scaleY or 1, item.ox or 0, item.oy or 0)
            end
        elseif item.type == "rune_ability" then
            if item.drawFunction then
                item.drawFunction()
            end
        elseif item.type == "experience_orb" then
            if item.drawFunction then
                item.drawFunction()
            end
        elseif item.type == "drop_entity" then
            if item.drawFunction then
                item.drawFunction()
            end
        end
        -- Adicione outros tipos conforme necessário
    end
    Camera:detach()

    if playerMgr and playerMgr.drawFloatingTexts then
        playerMgr:drawFloatingTexts()
    end
    -- Desenha UI (fora da câmera, sobre tudo)
    ManagerRegistry:draw() -- Presumindo que isso desenha UI como barras de vida sobre entidades, etc.
    -- Se não, precisará de um ManagerRegistry:drawUI() separado.
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
        local barY = love.graphics.getHeight() - barHeight - 60 -- Acima da HUD inferior
        local progress = math.min(1, self.castTimer / self.castDuration)

        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
        love.graphics.setColor(0.5, 0.7, 1, 0.9)
        love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setScissor(barX, barY, barWidth * progress, barHeight) -- Para o texto não sair da parte preenchida
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
        if enemies and #enemies > 0 then -- <<< ADICIONADO: Verifica se enemies existe
            -- Código de debug dos inimigos (transferido e adaptado)
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle('fill', love.graphics.getWidth() - 210, 5, 205, 150)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(fonts.debug or fonts.main_small)
            local debugText = string.format(
                "Enemy Info:\nTotal: %d | Ciclo: %d | Timer: %.1f",
                #enemies,
                enemyMgr.currentCycleIndex or 0, -- <<< ADICIONADO: Default 0 se nil
                enemyMgr.gameTimer or 0          -- <<< ADICIONADO: Default 0 se nil
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
    love.graphics.setFont(fonts.main) -- Reseta fonte
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
end

--- Inicia o processo de extração da gameplay.
--- Coleta itens da mochila da partida e equipamentos atuais do jogador,
--- e então transita para a LobbyScene, passando esses dados.
--- @param extractionType string Tipo de extração (ex: "equipment_only", "all_items", "random_equipment").
--- @param extractionParams table (Opcional) Parâmetros adicionais para a extração (ex: para "random_equipment").
function GameplayScene:initiateExtraction(extractionType, extractionParams)
    extractionType = extractionType or "all_items" -- Default se nada for passado
    extractionParams = extractionParams or {}      -- Default para evitar erros de nil
    print(string.format("GameplayScene: Iniciando extração... Tipo: '%s'", extractionType))

    local inventoryManager = ManagerRegistry:get("inventoryManager") ---@type InventoryManager
    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager
    local hunterManager = ManagerRegistry:get("hunterManager") ---@type HunterManager

    if not inventoryManager or not playerManager or not hunterManager then
        error(
            "[GameplayScene:initiateExtraction]: Um ou mais managers necessários (Inventory, Player, Hunter) não foram encontrados no Registry.")
    end

    local extractedBackpackItems = {}
    if extractionType == "all_items" or extractionType == "all_items_instant" then
        if inventoryManager.getAllItemsGameplay then
            extractedBackpackItems = inventoryManager:getAllItemsGameplay()
            print(string.format("GameplayScene: %d itens coletados da mochila (tipo: %s).", #extractedBackpackItems,
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
                extractedBackpackItems = {}                                              -- Inicia vazio
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
                    table.insert(extractedBackpackItems, allBackpackItems[randomIndex])
                end
                print(string.format("GameplayScene: %d itens da mochila selecionados aleatoriamente (tipo: %s).",
                    #extractedBackpackItems, extractionType))
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

    local extractedEquipment = {}
    if playerManager.getCurrentEquipmentGameplay then
        local currentEquipment = playerManager:getCurrentEquipmentGameplay()

        -- Para "random_backpack_items_plus_equipment", todos os equipamentos são mantidos
        if extractionType == "equipment_only" or extractionType == "all_items" or extractionType == "all_items_instant" or extractionType == "random_backpack_items_plus_equipment" then -- <<< ADICIONADO NOVO TIPO AQUI
            extractedEquipment = currentEquipment
            local equipCount = 0
            for _ in pairs(extractedEquipment) do equipCount = equipCount + 1 end
            print(string.format("GameplayScene: %d equipamentos atuais do jogador coletados (tipo: %s).", equipCount,
                extractionType))

            -- REMOVIDO: elseif extractionType == "random_equipment" then ... (lógica antiga movida e adaptada acima para mochila)
        else
            print(string.format("GameplayScene: Nenhum equipamento será extraído (tipo: %s).", extractionType))
        end
    else
        error(
            "[GameplayScene:initiateExtraction]: Método playerManager:getCurrentEquipmentGameplay() não encontrado.")
    end

    local currentHunterId = hunterManager:getActiveHunterId()

    -- Prepara os argumentos para a LobbyScene
    local extractionArgs = {
        extractionSuccessful = true,
        hunterId = currentHunterId, -- Passa o ID do caçador que está extraindo
        extractedItems = extractedBackpackItems,
        extractedEquipment = extractedEquipment
    }

    print("GameplayScene: Transicionando para LobbyScene com dados de extração.")
    SceneManager.switchScene("lobby_scene", extractionArgs)
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
--- Verifica se o item é usável e inicia o processo de "casting".
--- @param itemInstance table A instância do item a ser usado (do inventário da partida).
--- @return boolean True se o uso foi iniciado, false caso contrário.
function GameplayScene:requestUseItem(itemInstance)
    if self.isCasting then
        print("GameplayScene: Já está conjurando outro item.")
        -- TODO: Feedback para o jogador (som de erro, mensagem?)
        return false
    end

    local itemDataManager = ManagerRegistry:get("itemDataManager")
    if not itemDataManager then
        error("[GameplayScene:requestUseItem] ItemDataManager não encontrado.")
        return false
    end

    local baseData = itemDataManager:getBaseItemData(itemInstance.itemBaseId)
    if not baseData or not baseData.useDetails then
        print("GameplayScene: Item não é usável ou não tem useDetails.")
        return false
    end

    local useDetails = baseData.useDetails
    self.isCasting = true
    self.castTimer = 0
    self.castDuration = useDetails.castTime or 0
    self.castingItem = itemInstance -- Armazena a instância do item sendo usado

    print(string.format("GameplayScene: Iniciando conjuração de '%s' (ID da instância: %s) por %.2f segundos.",
        baseData.name, tostring(itemInstance.instanceId), self.castDuration))

    -- Define o que fazer quando a conjuração terminar
    self.onCastCompleteCallback = function()
        print(string.format("GameplayScene: Concluiu conjuração de '%s'.", baseData.name))

        if useDetails.consumesOnUse then
            local inventoryManager = ManagerRegistry:get("inventoryManager")
            if inventoryManager then
                inventoryManager:removeItemInstance(self.castingItem.instanceId, 1) -- Remove 1 da pilha
                print("GameplayScene: Item consumido.")
            else
                error("[GameplayScene:onCastCompleteCallback] InventoryManager não encontrado para consumir item.")
            end
        end

        -- Chama a extração com o tipo específico
        if useDetails.extractionType then
            self:initiateExtraction(useDetails.extractionType, baseData.useDetails.extractionRandomParams)
        else
            error(string.format(
                "[GameplayScene:onCastCompleteCallback] 'extractionType' não definido nos useDetails do item %s",
                baseData.name))
        end
    end

    -- Se o castTime for 0 (ou muito pequeno), executa imediatamente
    if self.castDuration <= 0.01 then
        print("GameplayScene: Cast time é zero, executando imediatamente.")
        local callback = self.onCastCompleteCallback
        self:resetCastState()
        if callback then
            callback()
        end
    else
        -- TODO: Iniciar feedback visual/sonoro de que o cast começou
        -- Ex: player entra em animação de cast, barra de progresso aparece
    end

    return true
end

--- NOVO: Atualiza a lógica de casting.
--- @param dt number Delta time.
function GameplayScene:updateCasting(dt)
    if not self.isCasting then
        return
    end

    self.castTimer = self.castTimer + dt
    -- print(string.format("Casting progress: %.2f / %.2f", self.castTimer, self.castDuration)) -- Log frequente, remover depois

    -- TODO: Implementar lógica de interrupção do cast
    -- Exemplo: Se o jogador se mover ou tomar dano (dependendo das regras do item)
    -- local playerManager = ManagerRegistry:get("playerManager")
    -- if playerManager and playerManager:hasMovedSinceLastFrame() then -- Método hipotético
    --     self:interruptCast("Jogador se moveu")
    --     return
    -- end
    -- if playerManager and playerManager:tookDamageThisFrame() then -- Método hipotético
    --    self:interruptCast("Dano recebido")
    --    return
    -- end

    if self.castTimer >= self.castDuration then
        local callback = self.onCastCompleteCallback
        self:resetCastState() -- Reseta ANTES de chamar o callback para evitar recursão ou estado inconsistente
        if callback then
            callback()
        end
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
    -- TODO: Parar feedback visual/sonoro de cast (barra de progresso, animação)
end

return GameplayScene
