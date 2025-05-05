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

local GameplayScene = {}
GameplayScene.__index = GameplayScene -- <<< ADICIONADO __index >>>

function GameplayScene:load(args)
    print("GameplayScene:load - Inicializando sistemas de gameplay...")
    self.portalId = args and args.portalId or "unknown_portal"
    self.hordeConfig = args and args.hordeConfig or nil
    self.hunterId = args and args.hunterId or nil

    -- Validações iniciais
    if not self.hordeConfig then
        error(
            "ERRO CRÍTICO [GameplayScene:load]: Nenhuma hordeConfig fornecida para iniciar a cena!")
    end
    if not self.hunterId then error("ERRO CRÍTICO [GameplayScene:load]: Nenhum hunterId fornecido para iniciar a cena!") end
    print(string.format("  - Carregando portal ID: %s, Hunter ID: %s", self.portalId, self.hunterId))

    -- 1. Carrega assets e configurações básicas da cena
    self.isPaused = false
    self.camera = nil
    self.groundTexture = nil
    self.grid = nil
    if not fonts.main then fonts.load() end

    -- <<< ADICIONADO: Estado de Drag do Inventário e Cache de Áreas >>>
    self.inventoryDragState = {
        isDragging = false,
        draggedItem = nil,
        draggedItemOffsetX = 0,
        draggedItemOffsetY = 0,
        sourceGridId = nil,
        sourceSlotId = nil,
        draggedItemIsRotated = false,
        targetGridId = nil,
        targetSlotCoords = nil,
        isDropValid = false
    }
    self.inventoryEquipmentAreas = {} -- Cache das áreas retornadas pelo InventoryScreen.draw
    self.inventoryGridArea = {}       -- Cache da área retornada pelo InventoryScreen.draw
    -- <<< FIM ADIÇÃO >>>

    local success, shaderOrErr = pcall(love.graphics.newShader, "assets/shaders/glow.fs")
    if success then
        elements.setGlowShader(shaderOrErr)
        InventoryScreen.setGlowShader(shaderOrErr)
        print("GameplayScene: Glow shader carregado.")
    else
        print("GameplayScene: Aviso - Falha ao carregar glow shader.", shaderOrErr)
    end

    local texSuccess, texErr = pcall(function()
        self.groundTexture = love.graphics.newImage("assets/ground.png")
        self.groundTexture:setWrap("repeat", "repeat")
    end)
    if not texSuccess then
        print("GameplayScene: ERRO ao carregar groundTexture!", texErr)
        -- Tratar erro como apropriado (ex: usar cor sólida)
    end

    self.grid = { size = 128, rows = 100, columns = 100, color = { 0.3, 0.3, 0.3, 0.2 } }
    Camera:init()
    print("GameplayScene: Chamado Camera:init() no módulo global.")
    print("GameplayScene: Chamando AnimationLoader.loadAll()...")
    AnimationLoader.loadAll()
    print("GameplayScene: AnimationLoader.loadAll() concluído.")

    -- 2. Chama Bootstrap para criar e registrar managers de GAMEPLAY
    print("GameplayScene: Chamando Bootstrap.initialize() para criar managers de gameplay...")
    Bootstrap.initialize()
    print("GameplayScene: Bootstrap.initialize() concluído.")

    -- 3. Obtém referências a TODOS os managers necessários do Registry
    print("GameplayScene: Obtendo managers (gameplay e persistentes) do Registry...")
    local enemyMgr = ManagerRegistry:get("enemyManager")
    local dropMgr = ManagerRegistry:get("dropManager")
    local playerMgr = ManagerRegistry:get("playerManager")
    local itemDataMgr = ManagerRegistry:get("itemDataManager") -- Persistente
    -- Adicionar outros managers necessários aqui (Input, Inventory, etc.)

    -- Validação PÓS-Bootstrap
    if not playerMgr or not enemyMgr or not dropMgr or not itemDataMgr then
        -- Imprime quais falharam
        local missing = {}
        if not playerMgr then table.insert(missing, "PlayerManager") end
        if not enemyMgr then table.insert(missing, "EnemyManager") end
        if not dropMgr then table.insert(missing, "DropManager") end
        if not itemDataMgr then table.insert(missing, "ItemDataManager") end
        error("ERRO CRÍTICO [GameplayScene:load]: Falha ao obter managers essenciais do Registry após Bootstrap: " ..
            table.concat(missing, ", "))
    end
    print("GameplayScene: Managers obtidos com sucesso.")

    -- 4. Configura managers com dados específicos da cena/jogo
    print("GameplayScene: Configurando PlayerManager...")
    playerMgr:setupGameplay(ManagerRegistry, self.hunterId) -- Passa o Registry inteiro para dependências internas

    print("GameplayScene: Configurando EnemyManager...")
    local enemyManagerConfig = {
        hordeConfig = self.hordeConfig,
        playerManager = playerMgr,
        dropManager = dropMgr
    }
    enemyMgr:setupGameplay(enemyManagerConfig)

    -- Posiciona a câmera após o jogador ser criado em setupGameplay
    local playerInitialPos = playerMgr.player.position
    if playerInitialPos then
        local initialCamX = playerInitialPos.x - (Camera.screenWidth / 2)
        local initialCamY = playerInitialPos.y - (Camera.screenHeight / 2)
        Camera:setPosition(initialCamX, initialCamY)
        print(string.format(
            "GameplayScene: Câmera GLOBAL ajustada para jogador em (%.1f, %.1f). Cam pos: (%.1f, %.1f)",
            playerInitialPos.x, playerInitialPos.y, Camera.x, Camera.y))
    else
        print("GameplayScene: AVISO - Posição inicial do jogador não encontrada após setup, câmera GLOBAL em (0,0).")
        Camera:setPosition(0, 0)
    end

    -- 5. Executa código de início de cena (Ex: drop de teste)
    -- [[ INÍCIO CÓDIGO DE TESTE TEMPORÁRIO ]]
    local function createTestDrop()
        if dropMgr and playerMgr and playerMgr.player and itemDataMgr then
            local playerPos = playerMgr.player.position
            local testWeaponId = "hammer" -- <<< CONFIRME ID VÁLIDO!

            if itemDataMgr:getBaseItemData(testWeaponId) then
                local dropConfig = { type = "item", itemId = testWeaponId, quantity = 1 }
                local dropPosition = { x = playerPos.x + 250, y = playerPos.y }
                print(string.format("[TESTE GameplayScene] Criando drop de '%s' perto do jogador.", testWeaponId))
                dropMgr:createDrop(dropConfig, dropPosition)
            else
                print(string.format("[TESTE GameplayScene] AVISO: Item de teste '%s' não encontrado.", testWeaponId))
            end
        else
            print(
                "[TESTE GameplayScene] AVISO: Dependências (DropMgr, Player, ItemDataMgr) não encontradas para criar drop.")
        end
    end
    createTestDrop()
    -- [[ FIM CÓDIGO DE TESTE TEMPORÁRIO ]]

    print("GameplayScene:load concluído.")
end

function GameplayScene:update(dt)
    -- Permite atualizar UIs que funcionam mesmo pausadas (transferido de main.lua)
    local mx, my = love.mouse.getPosition() -- <<< OBTÉM COORDENADAS >>>
    InventoryScreen.update(dt, mx, my)      -- <<< PASSA COORDENADAS >>>
    -- ItemDetailsModal foi movido para depois da lógica de pausa

    -- <<< ADICIONADO: Lógica de Update do Drag do Inventário (antes da pausa) >>>
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
                            print(string.format(
                                "[GameplayScene.update - Drag] Hover VÁLIDO sobre Equip Slot '%s'. Set isDropValid=true.",
                                slotId)) -- DEBUG
                            self.inventoryDragState.isDropValid = true
                        else
                            print(string.format(
                                "[GameplayScene.update - Drag] Hover INVÁLIDO sobre Equip Slot '%s'. Tipos não batem: Item='%s', Slot Espera='%s'",
                                slotId, tostring(itemType), tostring(expectedType)))
                        end
                    else
                        print(string.format(
                            "[GameplayScene.update - Drag] Hover INVÁLIDO sobre Equip Slot '%s'. Item '%s' não tem 'type' nos dados base.",
                            slotId, draggedItem.itemBaseId))
                    end
                    break -- Sai do loop de slots
                end
            end

            -- Verifica hover sobre Grade de Inventário (se não estiver sobre equipamento)
            if not hoverEquipmentSlot then
                local area = self.inventoryGridArea -- USA ÁREA CACHEADA DA CENA
                if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                    self.inventoryDragState.targetGridId = "inventory"

                    -- <<< ADICIONADA VERIFICAÇÃO EXPLÍCITA >>>
                    if not inventoryManager then
                        print(
                            "ERRO GRAVE [GameplayScene.update - Drag]: inventoryManager é NIL ao tentar obter dimensões!")
                    else
                        -- <<< CORRIGIDO: Chama getGridDimensions e extrai rows/cols >>>
                        local gridDims = inventoryManager:getGridDimensions()
                        local invRows = gridDims and gridDims.rows
                        local invCols = gridDims and gridDims.cols

                        if invRows and invCols then
                            local ItemGridUI = require("src.ui.item_grid_ui")
                            -- <<< Obtém grade interna e chama ItemGridLogic >>>
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
                                    draggedItem.instanceId, -- Passa ID do item sendo arrastado (opcional para a lógica atual de canPlaceItemAt)
                                    self.inventoryDragState.targetSlotCoords.row,
                                    self.inventoryDragState.targetSlotCoords.col,
                                    visualW,
                                    visualH
                                )
                            end
                        else
                            print(
                                "AVISO [GameplayScene.update - Drag]: inventoryManager:getDimensions() retornou nil ou inválido.")
                        end
                    end
                    -- <<< FIM VERIFICAÇÃO >>>
                end
            end
        end
    end
    -- <<< FIM: Lógica de Update do Drag >>>

    -- Verifica se alguma UI principal (modal ou inventário) está ativa
    local hasActiveModalOrInventory = LevelUpModal.visible or RuneChoiceModal.visible or InventoryScreen.isVisible or
        ItemDetailsModal.isVisible

    -- Atualiza o InputManager (lógica transferida)
    -- Passamos o estado de pausa da cena e se UI está ativa
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        -- Nota: A pausa do InputManager pode precisar ser ajustada. A cena gerencia self.isPaused
        -- mas talvez InputManager deva saber apenas se modais/inventário estão ativos.
        inputMgr:update(dt, hasActiveModalOrInventory, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para update")
    end

    -- Atualiza todos os managers do jogo (lógica principal transferida)
    ManagerRegistry:update(dt)
end

--- Desenha o grid isométrico com base na posição do jogador e câmera.
-- (Função movida de main.lua e adaptada para ser método da cena)
function GameplayScene:drawIsometricGrid()
    if not self.grid or not self.groundTexture then
        print("GameplayScene:drawIsometricGrid - Aviso: grid ou groundTexture não inicializados.")
        return
    end

    local iso_scale = 0.5 -- Isometric perspective scale
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local grid = self.grid
    local groundTexture = self.groundTexture

    -- Calcula o tamanho do chunk baseado no tamanho da tela
    local chunkSize = 32 -- número de células por chunk
    -- Adiciona o zoom da câmera ao cálculo de chunks visíveis
    local visibleCellsX = screenWidth / (grid.size / 2)
    local visibleCellsY = screenHeight / (grid.size / 2 * iso_scale)
    local visibleChunksX = math.ceil(visibleCellsX / chunkSize) + 4 -- chunks visíveis + buffer
    local visibleChunksY = math.ceil(visibleCellsY / chunkSize) + 4

    local playerMgr = ManagerRegistry:get("playerManager")
    local focusX, focusY = Camera.x + screenWidth / 2, Camera.y + screenHeight / 2 -- Usa centro da câmera como fallback
    if playerMgr and playerMgr.player and playerMgr.player.position then
        focusX = playerMgr.player.position.x
        focusY = playerMgr.player.position.y
    end

    local centerGridX = math.floor(focusX / (grid.size / 2))
    local centerGridY = math.floor(focusY / (grid.size / 2 * iso_scale))

    -- Calcula o chunk central
    local currentChunkX = math.floor(centerGridX / chunkSize)
    local currentChunkY = math.floor(centerGridY / chunkSize)

    -- Define a área de chunks a ser renderizada em volta do centro
    local startChunkX = currentChunkX - math.ceil(visibleChunksX / 2)
    local endChunkX = currentChunkX + math.ceil(visibleChunksX / 2)
    local startChunkY = currentChunkY - math.ceil(visibleChunksY / 2)
    local endChunkY = currentChunkY + math.ceil(visibleChunksY / 2)

    -- Apply camera transformation (já deve estar ativa no draw principal)
    -- Camera:attach()

    -- Define a cor branca para não afetar a textura
    love.graphics.setColor(1, 1, 1, 1)

    -- Renderiza os chunks visíveis
    for chunkX = startChunkX, endChunkX do
        for chunkY = startChunkY, endChunkY do
            -- Renderiza as células dentro do chunk
            local startX = chunkX * chunkSize
            local startY = chunkY * chunkSize
            local endX = startX + chunkSize
            local endY = startY + chunkSize

            for i = startX, endX do
                for j = startY, endY do
                    -- Calcula posição isométrica do ponto do grid
                    local isoX = (i - j) * (grid.size / 2)
                    local isoY = (i + j) * (grid.size / 2 * iso_scale)

                    -- Desenha a textura do terreno no tile
                    love.graphics.draw(
                        groundTexture,
                        isoX - grid.size / 2,                 -- Ajusta para desenhar tile centrado no ponto
                        isoY - grid.size / 2,
                        0,                                    -- rotação
                        grid.size / groundTexture:getWidth(), -- escala X
                        grid.size / groundTexture:getHeight() -- escala Y
                    )
                end
            end
        end
    end

    -- Camera:detach() -- Deve ser feito no draw principal
    love.graphics.setColor(1, 1, 1, 1) -- Garante reset da cor
end

function GameplayScene:draw()
    -- REMOVIDO: Checagem de self.camera não é mais necessária
    -- if not self.camera then ... end

    -- Clear screen (opcional, pode sobrepor com fundo do grid)
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1) -- <<< MUDADO: Cor de fundo mais escura >>>
    love.graphics.clear(0.1, 0.1, 0.1, 1)           -- <<< MUDADO: Limpa com a mesma cor >>>

    -- Aplica transformação da câmera para o mundo (usando Camera global)
    Camera:attach()

    -- Desenha o grid isométrico e o chão (Garantir que use Camera global internamente ou não precise)
    self:drawIsometricGrid() -- Verificar se drawIsometricGrid usa self.camera

    -- Desenha elementos do jogo que ficam sob a câmera
    ManagerRegistry:CameraDraw() -- Assumindo que isso desenha player, inimigos, projéteis, etc.

    -- Desfaz transformação da câmera (usando Camera global)
    Camera:detach()

    -- Desenha elementos da UI que ficam por cima de tudo
    ManagerRegistry:draw() -- Assumindo que isso desenha UI como FloatingText

    -- Desenha Modais e Telas de UI
    LevelUpModal:draw()
    RuneChoiceModal:draw()

    -- <<< MODIFICADO: Passa dragState e armazena áreas retornadas >>>
    if InventoryScreen.isVisible then -- Só chama se estiver visível
        local eqAreas, invArea = InventoryScreen.draw(self.inventoryDragState)
        self.inventoryEquipmentAreas = eqAreas or {}
        self.inventoryGridArea = invArea or {}
    end
    -- <<< FIM MODIFICAÇÃO >>>

    ItemDetailsModal:draw() -- Assumindo que verifica internamente se está visível
    HUD:draw()

    -- Desenha informações de Debug (opcional)
    local enemyMgr = ManagerRegistry:get("enemyManager")
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
    -- print(string.format("GameplayScene: Tecla pressionada: %s", key))

    -- <<< Primeiro, verifica input relacionado ao Inventário (se visível) >>>
    if InventoryScreen.isVisible then
        local consumed, wantsToRotate = InventoryScreen.keypressed(key) -- Chama a função atualizada

        if consumed and wantsToRotate then
            -- Verifica se estamos realmente arrastando
            if self.inventoryDragState.isDragging then
                self.inventoryDragState.draggedItemIsRotated = not self.inventoryDragState.draggedItemIsRotated
                print(string.format("[GameplayScene] Rotação do item arrastado alternada para: %s",
                    tostring(self.inventoryDragState.draggedItemIsRotated)))
            else
                print("[GameplayScene] Rotação solicitada, mas não aplicável (não arrastando?).")
            end
            return           -- Tecla consumida
        elseif consumed then -- Tecla foi ESC ou I (ou outra consumida pelo InventoryScreen)
            -- Consumida mas não para rotação (ex: fechar inventário com ESC/I)
            -- Verifica se o inventário FOI fechado (isVisible agora é false)
            if not InventoryScreen.isVisible then
                print(string.format(
                    "[GameplayScene] Inventário fechado (tecla: %s). Despausando e cancelando drag (se houver)...", key))
                self.isPaused = false -- <<< DESPAUSA O JOGO >>>
                -- Cancela drag se estava arrastando
                if self.inventoryDragState.isDragging then
                    -- Reseta o estado de drag
                    self.inventoryDragState = {
                        isDragging = false,
                        draggedItem = nil,
                        draggedItemOffsetX = 0,
                        draggedItemOffsetY = 0,
                        sourceGridId = nil,
                        sourceSlotId = nil,
                        draggedItemIsRotated = false,
                        targetGridId = nil,
                        targetSlotCoords = nil,
                        isDropValid = false
                    }
                end
            else
                -- Se consumiu mas não fechou (caso raro, talvez outra tecla?), apenas retorna.
            end
            return -- Tecla consumida (ex: ESC/I para fechar)
        end
        -- Se não foi consumida pelo inventário, continua...
    end

    -- Trata TAB para inventário (funciona mesmo se inventário estiver fechado)
    if key == "tab" and not isrepeat then -- Ignora repetição para TAB
        print("GameplayScene: TAB pressionado! Alternando inventário e pausa...")
        -- Chama toggle UMA VEZ e guarda o novo estado
        local newVisibility = InventoryScreen.toggle()
        self.isPaused = newVisibility -- Pausa/Despausa junto com a visibilidade
        print(string.format("GameplayScene: Estado de pausa: %s", tostring(self.isPaused)))

        -- Cancela drag se o inventário for fechado via TAB
        if not newVisibility and self.inventoryDragState.isDragging then -- Usa o estado recém definido
            print("[GameplayScene] Inventário fechado (TAB) durante drag. Cancelando drag...")
            self.inventoryDragState = {
                isDragging = false,
                draggedItem = nil,
                draggedItemOffsetX = 0,
                draggedItemOffsetY = 0,
                sourceGridId = nil,
                sourceSlotId = nil,
                draggedItemIsRotated = false,
                targetGridId = nil,
                targetSlotCoords = nil,
                isDropValid = false
            }
        end

        return -- Input tratado aqui
    end

    -- Delega o restante para o InputManager SE NÃO estiver pausado e Inventário fechado
    if not self.isPaused and not InventoryScreen.isVisible then
        local inputMgr = ManagerRegistry:get("inputManager")
        if inputMgr then
            inputMgr:keypressed(key, self.isPaused) -- Passa o estado de pausa da cena (que será false aqui)
        else
            print("GameplayScene: AVISO - InputManager não encontrado no Registry para keypressed")
        end
    else
        print(string.format("[GameplayScene] Keypress '%s' ignorado (Pausado: %s, Inv Visível: %s)", key,
            tostring(self.isPaused), tostring(InventoryScreen.isVisible)))
    end
end

function GameplayScene:keyreleased(key, scancode)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:keyreleased(key, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para keyreleased")
    end
end

function GameplayScene:mousepressed(x, y, button, istouch, presses)
    -- <<< Primeiro, verifica se o clique é para o inventário >>>
    if InventoryScreen.isVisible then
        local consumed, dragStartData = InventoryScreen.handleMousePress(x, y, button)
        if consumed and dragStartData then
            -- <<< ATUALIZA O DRAG STATE DA CENA >>>
            self.inventoryDragState.isDragging = true
            self.inventoryDragState.draggedItem = dragStartData.item
            self.inventoryDragState.sourceGridId = dragStartData.sourceGridId
            self.inventoryDragState.sourceSlotId = dragStartData.sourceSlotId -- Será nil se for da grade
            self.inventoryDragState.draggedItemOffsetX = dragStartData.offsetX
            self.inventoryDragState.draggedItemOffsetY = dragStartData.offsetY
            self.inventoryDragState.draggedItemIsRotated = dragStartData.isRotated or false
            -- Reseta o alvo ao iniciar
            self.inventoryDragState.targetGridId = nil
            self.inventoryDragState.targetSlotCoords = nil
            self.inventoryDragState.isDropValid = false
            print(string.format("[GameplayScene] Drag iniciado a partir do Inventário: Item %s, Origem: %s (%s)",
                dragStartData.item.itemBaseId, dragStartData.sourceGridId, dragStartData.sourceSlotId or "grid"))
            return -- Consumiu e iniciou drag, não passa para InputManager
        elseif consumed then
            print("[GameplayScene] Clique consumido pelo Inventário (sem iniciar drag). Nenhuma ação adicional.")
            return -- Consumiu, mas não iniciou drag (ex: clique em slot vazio)
        end
        -- Se não consumiu, permite que o InputManager processe (útil para cliques fora do inventário?)
    end

    -- Se o clique não foi consumido pelo inventário, passa para o InputManager
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:mousepressed(x, y, button, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para mousepressed")
    end
    -- Nota: O InputManager deve internamente verificar cliques em Modais (LevelUp, RuneChoice)
end

function GameplayScene:mousemoved(x, y, dx, dy, istouch)
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:mousemoved(x, y, dx, dy)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para mousemoved")
    end
end

function GameplayScene:mousereleased(x, y, button, istouch, presses)
    -- <<< Verifica se estávamos arrastando um item do inventário >>>
    if self.inventoryDragState.isDragging then
        -- DEBUG: Imprime o estado COMPLETO do dragState ANTES de chamar o handler
        print("--- [GameplayScene.mousereleased - Drop Detectado] ---")
        print("Final dragState ANTES de chamar InventoryScreen.handleMouseRelease:")
        if type(self.inventoryDragState) == "table" then
            for k, v in pairs(self.inventoryDragState) do
                if k == "draggedItem" and type(v) == "table" then
                    print(string.format("  %s: { itemBaseId=%s, instanceId=%s, ... }", k, v.itemBaseId or "nil",
                        v.instanceId or "nil"))
                elseif k == "targetSlotCoords" and type(v) == "table" then
                    print(string.format("  %s: { row=%s, col=%s, ... }", k, v.row or "nil", v.col or "nil"))
                elseif type(v) == "table" then
                    print(string.format("  %s: table", k))
                else
                    print(string.format("  %s: %s", tostring(k), tostring(v)))
                end
            end
        else
            print("  self.inventoryDragState não é uma tabela:", tostring(self.inventoryDragState))
        end
        print("-----------------------------------------------------")

        -- Chama o handler do InventoryScreen para executar a ação
        -- Passa o estado atual do drag da cena
        local success = InventoryScreen.handleMouseRelease(self.inventoryDragState)

        if success then
            print("[GameplayScene] Ação de drop do inventário concluída com SUCESSO.")
        else
            print("[GameplayScene] Ação de drop do inventário FALHOU ou foi inválida.")
        end

        -- <<< SEMPRE reseta o estado de drag da cena após o release >>>
        self.inventoryDragState = {
            isDragging = false,
            draggedItem = nil,
            draggedItemOffsetX = 0,
            draggedItemOffsetY = 0,
            sourceGridId = nil,
            sourceSlotId = nil,
            draggedItemIsRotated = false,
            targetGridId = nil,
            targetSlotCoords = nil,
            isDropValid = false
        }
        print("[GameplayScene] Estado de drag do inventário resetado.")
        return -- Consumiu o evento de release
    end

    -- Se não estava arrastando no inventário, passa para InputManager
    local inputMgr = ManagerRegistry:get("inputManager")
    if inputMgr then
        inputMgr:mousereleased(x, y, button, self.isPaused)
    else
        print("GameplayScene: AVISO - InputManager não encontrado no Registry para mousereleased")
    end
end

-- Adicionar outros handlers de input (keyreleased, mousepressed, etc.) conforme necessário

function GameplayScene:unload()
    print("GameplayScene:unload - Descarregando recursos do gameplay...")
    -- TODO: Limpar recursos específicos da cena de gameplay (inimigos, etc.)
    -- <<< ADICIONADO: Resetar estados estáticos de UI/Modals >>>
    LevelUpModal.visible = false
    RuneChoiceModal.visible = false
    InventoryScreen.isVisible = false
    ItemDetailsModal.isVisible = false
    if HUD.reset then HUD:reset() end -- Chama reset se existir

    -- <<< ADICIONADO: Parar/Limpar managers se necessário >>>
    -- Exemplo: Parar timers ou limpar listas
    local enemyMgr = ManagerRegistry:get("enemyManager")
    if enemyMgr and enemyMgr.reset then enemyMgr:reset() end
    -- Limpar outros managers se relevante
end

return GameplayScene
