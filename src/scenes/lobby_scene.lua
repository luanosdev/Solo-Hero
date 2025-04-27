local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local LobbyPortalManager = require("src.managers.lobby_portal_manager")
local ItemDataManager = require("src.managers.item_data_manager")
local LobbyStorageManager = require("src.managers.lobby_storage_manager")
local LoadoutManager = require("src.managers.loadout_manager")
local MockPlayerManager = require("src.managers.mock_player_manager")
local ArchetypeManager = require("src.managers.archetype_manager")
local HunterManager = require("src.managers.hunter_manager")
local ManagerRegistry = require("src.managers.manager_registry")
local EquipmentScreen = require("src.ui.equipment_screen")
local PortalScreen = require("src.ui.portal_screen")
local Constants = require("src.config.constants")


local TabIds = Constants.TabIds

--- Cena principal do Lobby.
---Exibe o mapa de fundo quando "Portais" está ativo e a barra de navegação inferior.
---@class LobbyScene
---@field portalScreen PortalScreen
---@field equipmentScreen EquipmentScreen
local LobbyScene = {}

-- Estado da cena
LobbyScene.activeTabIndex = 0 ---@type integer
LobbyScene.portalManager = nil ---@type LobbyPortalManager|nil Instância do gerenciador de portais
LobbyScene.itemDataManager = nil ---@type ItemDataManager|nil Instância do gerenciador de dados de itens
LobbyScene.lobbyStorageManager = nil ---@type LobbyStorageManager|nil Instância do gerenciador de armazenamento do lobby
LobbyScene.loadoutManager = nil ---@type LoadoutManager|nil Instância do gerenciador de loadout
LobbyScene.archetypeManager = nil ---@type ArchetypeManager|nil Instância do gerenciador de archetype
LobbyScene.hunterManager = nil ---@type HunterManager|nil Instância do gerenciador de caçadores
LobbyScene.equipmentScreen = nil ---@type EquipmentScreen|nil Instância da tela de equipamento
LobbyScene.portalScreen = nil ---@type PortalScreen|nil Instância da tela de portal

-- Configs da névoa
LobbyScene.fogNoiseScale = 4.0 ---@type number Escala do ruído (valores menores = "zoom maior")
LobbyScene.fogNoiseSpeed = 0.08 ---@type number Velocidade de movimento da névoa
LobbyScene.fogDensityPower = 2.5 ---@type number Expoente para controlar a densidade (maior = mais denso/opaco)
LobbyScene.fogBaseColor = { 0.3, 0.4, 0.6, 1.0 } ---@type table Cor base da névoa (para combinar com o filtro do mapa)

-- Configuração dos botões/tabs inferiores
local tabs = {
    { id = TabIds.VENDOR,    text = "Vendedor" },
    { id = TabIds.CRAFTING,  text = "Criação" },
    { id = TabIds.EQUIPMENT, text = "Equipamento" },
    { id = TabIds.PORTALS,   text = "Portais" },
    { id = TabIds.HEROES,    text = "Herois" },
    { id = TabIds.SETTINGS,  text = "Configurações" },
    { id = TabIds.QUIT,      text = "Sair" },
}

local tabSettings = {
    height = 50,
    padding = 10,
    yPosition = 0,
    colors = {
        bgColor = colors.tab_bg,
        hoverColor = colors.tab_hover,
        highlightedBgColor = colors.tab_highlighted_bg,
        highlightedHoverColor = colors.tab_highlighted_hover,
        textColor = colors.tab_text,
        borderColor = colors.tab_border
    }
}

LobbyScene.isDragging = false ---@type boolean Se um item está sendo arrastado.
LobbyScene.draggedItem = nil ---@type table|nil A instância do item sendo arrastado.
LobbyScene.draggedItemOffsetX = 0 ---@type number Offset X do clique no item.
LobbyScene.draggedItemOffsetY = 0 ---@type number Offset Y do clique no item.
LobbyScene.sourceGridId = nil ---@type string|nil ID da grade de origem ("storage" ou "loadout").
LobbyScene.draggedItemIsRotated = false ---@type boolean Se a *visualização* do item está rotada.
LobbyScene.targetGridId = nil ---@type string|nil ID da grade de destino (calculado no update).
LobbyScene.targetSlotCoords = nil ---@type table|nil Coordenadas {row, col} do slot alvo (calculado no update).
LobbyScene.isDropValid = false ---@type boolean Se a posição atual do drop é válida (calculado no update).
-- As áreas agora são gerenciadas/retornadas pelo EquipmentScreen
LobbyScene.storageGridArea = {} ---@type table Retângulo da área da grade de storage {x,y,w,h} (atualizado pelo EquipmentScreen)
LobbyScene.loadoutGridArea = {} ---@type table Retângulo da área da grade de loadout {x,y,w,h} (atualizado pelo EquipmentScreen)
LobbyScene.equipmentSlotAreas = {} ---@type table<string, table> { [slotId] = {x,y,w,h} } (atualizado pelo EquipmentScreen)

--- Chamado quando a cena é carregada.
-- Calcula layout dos tabs, carrega imagem do mapa e define tab inicial.
---@param args table|nil
function LobbyScene:load(args)
    print("LobbyScene:load")
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    self.portalManager = LobbyPortalManager:new()
    self.itemDataManager = ItemDataManager:new()
    self.lobbyStorageManager = LobbyStorageManager:new(self.itemDataManager)
    self.loadoutManager = LoadoutManager:new(self.itemDataManager)
    self.archetypeManager = ArchetypeManager:new()
    self.hunterManager = HunterManager:new(self.loadoutManager, self.itemDataManager, self.archetypeManager)

    self.equipmentScreen = EquipmentScreen:new(self.itemDataManager, self.hunterManager, self.lobbyStorageManager,
        self.loadoutManager)
    self.portalScreen = PortalScreen:new(self.portalManager, self.hunterManager)

    -- <<< CRIA E REGISTRA O MOCK PLAYER MANAGER (Mantido por enquanto) >>>
    local mockPlayerManagerInstance = MockPlayerManager:new()
    ManagerRegistry:register("playerManager", mockPlayerManagerInstance)
    print("LobbyScene: MockPlayerManager registrado no ManagerRegistry.")

    -- <<< INÍCIO: Adiciona runas ao storage para teste >>>
    if self.lobbyStorageManager then
        --local addedOrbital = self.lobbyStorageManager:addItem("rune_orbital_e", 1)
        --local addedThunder = self.lobbyStorageManager:addItem("rune_thunder_e", 1)
        --local addedAura = self.lobbyStorageManager:addItem("rune_aura_e", 1)
        --print(string.format("LobbyScene: Tentativa de adicionar runas ao storage - Orbital:%s, Thunder:%s, Aura:%s",
        --    tostring(addedOrbital > 0), tostring(addedThunder > 0), tostring(addedAura > 0)))
    else
        print("AVISO (LobbyScene): LobbyStorageManager não inicializado, não foi possível adicionar runas de teste.")
    end
    -- <<< FIM: Adiciona runas ao storage para teste >>>

    -- Reseta estado de zoom/seleção
    self.portalScreen.isZoomedIn = false
    self.portalScreen.selectedPortal = nil

    -- Carrega a imagem do mapa
    local mapSuccess, mapErr = pcall(function()
        self.portalScreen.mapImage = love.graphics.newImage(self.portalScreen.mapImagePath)
    end)
    if not mapSuccess or not self.portalScreen.mapImage then
        print(string.format("Erro ao carregar imagem do mapa '%s': %s", self.portalScreen.mapImagePath,
            tostring(mapErr or "not found")))
        self.portalScreen.mapImage = nil
        self.portalScreen.mapOriginalWidth = 0
        self.portalScreen.mapOriginalHeight = 0
    else
        -- Armazena dimensões originais e inicializa pan/zoom
        self.portalScreen.mapOriginalWidth = self.portalScreen.mapImage:getWidth()
        self.portalScreen.mapOriginalHeight = self.portalScreen.mapImage:getHeight()
        self.portalScreen.mapTargetPanX = self.portalScreen.mapOriginalWidth / 2 -- Começa centrado
        self.portalScreen.mapTargetPanY = self.portalScreen.mapOriginalHeight / 2
        self.portalScreen.mapCurrentPanX = self.portalScreen.mapTargetPanX
        self.portalScreen.mapCurrentPanY = self.portalScreen.mapTargetPanY
        self.portalManager:initialize(self.portalScreen.mapOriginalWidth, self.portalScreen.mapOriginalHeight)
    end

    -- Carrega o shader de névoa
    local shaderSuccess, shaderErr = pcall(function()
        self.portalScreen.fogShader = love.graphics.newShader(self.portalScreen.fogShaderPath)
    end)
    if not shaderSuccess or not self.portalScreen.fogShader then
        print(string.format("Erro ao carregar shader de névoa '%s': %s - EFEITO DESABILITADO",
            self.portalScreen.fogShaderPath,
            tostring(shaderErr or "error")))
        self.portalScreen.fogShader = nil
    else
        print("Shader de névoa carregado com sucesso.")
    end

    -- Calcula a posição Y dos tabs
    tabSettings.yPosition = screenH - tabSettings.height

    -- Calcula largura e posição X dos tabs
    local totalTabs = #tabs
    local totalPadding = (totalTabs + 1) * tabSettings.padding
    local availableWidth = screenW - totalPadding
    local tabWidth = availableWidth / totalTabs
    local currentX = tabSettings.padding

    for i, tab in ipairs(tabs) do
        tab.x = currentX
        tab.y = tabSettings.yPosition
        tab.w = tabWidth
        tab.h = tabSettings.height
        tab.isHovering = false
        currentX = currentX + tabWidth + tabSettings.padding
        -- Define o tab "Portais" como ativo inicialmente (usando ID)
        if tab.id == TabIds.PORTALS then
            self.activeTabIndex = i
        end
    end

    -- Garante que haja um tab ativo se "Portais" não for encontrado (fallback)
    if self.activeTabIndex == 0 and #tabs > 0 then
        self.activeTabIndex = 1
    end

    print("LobbyScene: Tab ativo inicial:", self.activeTabIndex, tabs[self.activeTabIndex].text)
end

--- Atualiza a lógica da cena (verificação de hover, animação de zoom/pan).
---@param dt number
function LobbyScene:update(dt)
    local mx, my = love.mouse.getPosition()
    local activeTab = tabs[self.activeTabIndex]
    local isPortalScreenActive = activeTab and activeTab.id == TabIds.PORTALS
    local isPortalScreenZoomed = self.portalScreen and
        self.portalScreen
        .isZoomedIn -- Verifica estado interno da tela de portal

    -- 1. Hover das Tabs inferiores (só se portal screen NÃO estiver com zoom)
    local tabHoverHandled = false
    if not isPortalScreenZoomed then
        for i, tab in ipairs(tabs) do
            tab.isHovering = (mx >= tab.x and mx <= tab.x + tab.w and my >= tab.y and my <= tab.y + tab.h)
            if tab.isHovering then tabHoverHandled = true end
        end
    else
        for i, tab in ipairs(tabs) do tab.isHovering = false end
    end

    -- 2. Atualiza a Tela de Portais (se ativa ou com zoom)
    if self.portalScreen and (isPortalScreenActive or isPortalScreenZoomed) then
        -- Determina se hover é permitido dentro da tela de portal
        -- Hover é permitido se o mouse não estiver sobre uma tab (e o zoom não estiver ativo, o que já filtramos)
        local allowPortalScreenHover = not tabHoverHandled
        self.portalScreen:update(dt, mx, my, allowPortalScreenHover)
    end

    -- 3. Atualiza a Tela de Equipamento (se ativa)
    if activeTab and activeTab.id == TabIds.EQUIPMENT then
        -- A tela de equipamento não tem lógica de update complexa por enquanto
        -- Mas a lógica de cálculo de alvo do drag-and-drop permanece aqui na cena
        if self.isDragging then
            self.targetGridId = nil
            self.targetSlotCoords = nil
            self.isDropValid = false

            -- Calcula dimensões visuais baseadas na rotação
            local visualW = self.draggedItem.gridWidth or 1
            local visualH = self.draggedItem.gridHeight or 1
            if self.draggedItemIsRotated then
                visualW = self.draggedItem.gridHeight or 1
                visualH = self.draggedItem.gridWidth or 1
            end

            -- Verifica hover sobre Storage/Loadout (usa áreas atualizadas no draw anterior)
            local isMouseOverStorage = mx >= self.storageGridArea.x and
                mx < self.storageGridArea.x + self.storageGridArea.w and my >= self.storageGridArea.y and
                my < self.storageGridArea.y + self.storageGridArea.h
            local isMouseOverLoadout = mx >= self.loadoutGridArea.x and
                mx < self.loadoutGridArea.x + self.loadoutGridArea.w and my >= self.loadoutGridArea.y and
                my < self.loadoutGridArea.y + self.loadoutGridArea.h

            if isMouseOverStorage then
                self.targetGridId = "storage"
                local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
                local ItemGridUI = require("src.ui.item_grid_ui")
                self.targetSlotCoords = ItemGridUI.getSlotCoordsAtMouse(mx, my, storageRows, storageCols,
                    self.storageGridArea.x, self.storageGridArea.y, self.storageGridArea.w, self.storageGridArea.h)
                if self.targetSlotCoords then
                    self.isDropValid = self.lobbyStorageManager:canPlaceItemAt(
                        self.draggedItem, self.targetSlotCoords.row, self.targetSlotCoords.col, visualW, visualH)
                end
            elseif isMouseOverLoadout then
                self.targetGridId = "loadout"
                local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
                local ItemGridUI = require("src.ui.item_grid_ui")
                self.targetSlotCoords = ItemGridUI.getSlotCoordsAtMouse(mx, my, loadoutRows, loadoutCols,
                    self.loadoutGridArea.x, self.loadoutGridArea.y, self.loadoutGridArea.w, self.loadoutGridArea.h)
                if self.targetSlotCoords then
                    self.isDropValid = self.loadoutManager:canPlaceItemAt(self.draggedItem,
                        self.targetSlotCoords.row, self.targetSlotCoords.col, visualW, visualH)
                end
            end
            -- TODO: Adicionar verificação de hover sobre os slots de equipamento (usando self.equipmentSlotAreas)
        end
    end
end

--- Desenha os elementos da cena.
-- Desenha o mapa ou fundo padrão, o modal (se ativo) e a barra de tabs.
function LobbyScene:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local activeTab = tabs[self.activeTabIndex]
    local isPortalScreenZoomed = self.portalScreen and self.portalScreen.isZoomedIn

    -- 1. Desenha Fundo/Tela Principal da Aba Ativa
    if activeTab and activeTab.id == TabIds.PORTALS or isPortalScreenZoomed then
        -- <<< CHAMA O DRAW DO PORTAL SCREEN >>>
        if self.portalScreen then
            self.portalScreen:draw(screenW, screenH)
        else -- Fallback se portalScreen for nil
            love.graphics.setColor(colors.red)
            love.graphics.printf("Erro: PortalScreen não inicializado!", screenW / 2, screenH / 2, 0, "center")
        end
    else
        -- Desenha fundo padrão para outras abas
        love.graphics.setColor(colors.lobby_background)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(colors.white)

        -- Desenha conteúdo específico da aba (exceto Portais)
        if activeTab then
            if activeTab.id == TabIds.EQUIPMENT then
                -- <<< CHAMA O DRAW DO EQUIPMENT SCREEN >>>
                local dragState = {
                    isDragging = self.isDragging,
                    draggedItem = self.draggedItem,
                    draggedItemOffsetX =
                        self.draggedItemOffsetX,
                    draggedItemOffsetY = self.draggedItemOffsetY,
                    draggedItemIsRotated = self.draggedItemIsRotated,
                    targetGridId = self.targetGridId,
                    targetSlotCoords =
                        self.targetSlotCoords,
                    isDropValid = self.isDropValid,
                    equipmentSlotAreas = self.equipmentSlotAreas
                }
                self.storageGridArea, self.loadoutGridArea, self.equipmentSlotAreas = self.equipmentScreen:draw(screenW,
                    screenH, tabSettings, dragState)
            elseif activeTab.id == TabIds.VENDOR then
                -- Espaço para desenhar a UI do Vendedor
                love.graphics.printf("VENDEDOR", screenW / 2, screenH / 2, 0, "center")
            elseif activeTab.id == TabIds.CRAFTING then
                -- Espaço para desenhar a UI de Criação
                love.graphics.printf("CRIAÇÃO", screenW / 2, screenH / 2, 0, "center")
            elseif activeTab.id == TabIds.HEROES then
                -- Espaço para desenhar a UI de Herois
                love.graphics.printf("HEROIS", screenW / 2, screenH / 2, 0, "center")
            elseif activeTab.id == TabIds.SETTINGS then
                -- Espaço para desenhar a UI de Configurações
                love.graphics.printf("CONFIGURAÇÕES", screenW / 2, screenH / 2, 0, "center")
            end
        end
    end

    -- 2. Desenha Tabs (sempre por cima)
    local tabFont = fonts.main or love.graphics.getFont()
    for i, tab in ipairs(tabs) do
        elements.drawTabButton({
            x = tab.x,
            y = tab.y,
            w = tab.w,
            h = tab.h,
            text = tab.text,
            isHovering = tab.isHovering,
            highlighted = (i == self.activeTabIndex),
            font = tabFont,
            colors = tabSettings.colors
        })
    end

    -- Reset final
    love.graphics.setColor(colors.white)
    if fonts.main then love.graphics.setFont(fonts.main) end
end

--- Processa cliques do mouse.
-- Atualiza o tab ativo, lida com cliques no modal ou seleciona um portal.
---@param x number
---@param y number
---@param buttonIdx number
---@param istouch boolean
---@param presses number
function LobbyScene:mousepressed(x, y, buttonIdx, istouch, presses)
    if buttonIdx == 1 then
        local activeTab = tabs[self.activeTabIndex]
        local isPortalScreenZoomed = self.portalScreen and self.portalScreen.isZoomedIn

        -- 1. Se a tela de Portal está com zoom, TENTA delegar o clique para ela PRIMEIRO
        if isPortalScreenZoomed and self.portalScreen then
            local consumed = self.portalScreen:handleMousePress(x, y, buttonIdx)
            if consumed then return end -- Se o portal screen consumiu, termina aqui
        end

        -- 2. Se não estava com zoom no portal (ou o clique não foi consumido lá),
        --    verifica clique nas TABS inferiores
        local tabClicked = false
        for i, tab in ipairs(tabs) do
            if tab.isHovering then
                tabClicked = true
                print(string.format("LobbyScene: Tab '%s' clicado!", tab.text))
                if tab.id == TabIds.QUIT then
                    SceneManager.requestQuit()
                else
                    self.activeTabIndex = i
                    -- Se estava com zoom no portal, mudar de tab cancela
                    if isPortalScreenZoomed and self.portalScreen then
                        print("LobbyScene: Mudança de tab cancelando zoom do portal.")
                        self.portalScreen.isZoomedIn = false
                        self.portalScreen.selectedPortal = nil
                    end
                end
                break
            end
        end
        if tabClicked then return end -- Se clicou na tab, termina aqui

        -- 3. Se não clicou em tab, delega para a TELA da aba ativa
        if activeTab and activeTab.id == TabIds.EQUIPMENT then
            -- Delega para EquipmentScreen
            if self.equipmentScreen then
                local consumed, dragStartData = self.equipmentScreen:handleMousePress(x, y, buttonIdx)
                if consumed and dragStartData then
                    self.isDragging = true
                    self.draggedItem = dragStartData.item
                    self.sourceGridId = dragStartData.sourceGridId
                    self.draggedItemOffsetX = dragStartData.offsetX
                    self.draggedItemOffsetY = dragStartData.offsetY
                    self.draggedItemIsRotated = dragStartData.isRotated or false
                    if self.sourceGridId == "equipment" then
                        self.sourceSlotId = dragStartData.sourceSlotId
                    else
                        self.sourceSlotId = nil
                    end
                    print(string.format("LobbyScene: Drag iniciado: Item %d (%s) from %s%s. Estava rotacionado: %s",
                        self.draggedItem.instanceId,
                        self.draggedItem.itemBaseId, self.sourceGridId,
                        self.sourceSlotId and ("[" .. self.sourceSlotId .. "]") or "",
                        tostring(self.draggedItemIsRotated)))
                    return
                elseif consumed then
                    return -- Consumiu sem iniciar drag (ex: tab storage)
                end
            end
        elseif activeTab and activeTab.id == TabIds.PORTALS then
            -- Delega para PortalScreen (somente se não estava com zoom, pois isso foi tratado no passo 1)
            if self.portalScreen and not isPortalScreenZoomed then
                local consumed = self.portalScreen:handleMousePress(x, y, buttonIdx)
                if consumed then return end
            end
            -- elseif activeTab.id == TabIds.VENDOR then ...
            -- elseif activeTab.id == TabIds.CRAFTING then ...
            -- etc.
        end
    end
end

--- Processa o soltar do mouse, finalizando o drag-and-drop.
-- Agora delega para o EquipmentScreen se a aba estiver ativa.
function LobbyScene:mousereleased(x, y, buttonIdx, istouch, presses)
    if buttonIdx == 1 then
        if self.isDragging then
            print("LobbyScene: Drag finalizado.")

            local activeTab = tabs[self.activeTabIndex]
            local dragConsumed = false

            -- Se a aba Equipamento está ativa, tenta delegar o drop
            if activeTab and activeTab.id == TabIds.EQUIPMENT then
                -- Monta o estado de drag completo para passar
                local dragState = {
                    isDragging = self.isDragging,
                    draggedItem = self.draggedItem,
                    sourceGridId = self.sourceGridId,
                    sourceSlotId = self.sourceSlotId,
                    draggedItemIsRotated = self.draggedItemIsRotated,
                    targetGridId = self.targetGridId,            -- Calculado no update
                    targetSlotCoords = self.targetSlotCoords,    -- Calculado no update
                    isDropValid = self.isDropValid,              -- Calculado no update
                    equipmentSlotAreas = self.equipmentSlotAreas -- Calculado/Retornado pelo draw do equipment screen
                }
                -- <<< DELEGA O SOLTAR PARA O EQUIPMENT SCREEN >>>
                dragConsumed = self.equipmentScreen:handleMouseRelease(x, y, buttonIdx, dragState)
            end

            -- Se o drop foi consumido (pelo EquipmentScreen ou outra futura tela)
            -- ou mesmo se não foi consumido mas estávamos arrastando,
            -- precisamos limpar o estado de drag da cena principal.
            if dragConsumed then
                print("LobbyScene: Drop consumido pelo EquipmentScreen.")
            else
                print("LobbyScene: Drop NÃO consumido (ou ocorreu fora de área válida).")
            end

            -- Limpa o estado de drag da cena principal SEMPRE que soltar o mouse após um drag
            self.isDragging = false
            self.draggedItem = nil
            self.sourceGridId = nil
            self.sourceSlotId = nil
            self.targetGridId = nil
            self.targetSlotCoords = nil
            self.isDropValid = false
            self.draggedItemOffsetX = 0
            self.draggedItemOffsetY = 0
            self.draggedItemIsRotated = false -- <<< Reseta rotação visual
            -- Não precisa retornar aqui necessariamente, o evento termina.
        end                                   -- Fim do if self.isDragging
    end                                       -- Fim do if buttonIdx == 1
end

--- NOVO: Processa pressionamento de teclas.
--- Delega para a tela ativa se necessário (ex: rotação de item no EquipmentScreen).
---@param key string A tecla pressionada (love.keyboard.keys).
---@param scancode love.Scancode O scancode da tecla.
---@param isrepeat boolean Se o evento é uma repetição.
function LobbyScene:keypressed(key, scancode, isrepeat)
    -- Ignora repetições para evitar rotações múltiplas rápidas
    if isrepeat then return end

    local activeTab = tabs[self.activeTabIndex]

    -- Verifica se estamos arrastando um item na aba de Equipamento
    if self.isDragging and activeTab and activeTab.id == TabIds.EQUIPMENT and self.equipmentScreen then
        -- Delega para a keypressed da EquipmentScreen
        local wantsToRotate = self.equipmentScreen:keypressed(key)

        if wantsToRotate and self.draggedItem then
            -- Alterna o estado de rotação VISUAL
            self.draggedItemIsRotated = not self.draggedItemIsRotated
            print(string.format("LobbyScene: Rotação visual alternada para: %s", tostring(self.draggedItemIsRotated)))
            -- NÃO modifica self.draggedItem aqui
        end
    end

    -- TODO: Adicionar delegação para outras telas/abas se necessário
end

--- Chamado quando a cena é descarregada.
-- Libera a imagem do mapa da memória e limpa referência do manager.
function LobbyScene:unload()
    print("LobbyScene:unload")
    -- Libera recursos das telas filhas
    if self.portalScreen then
        self.portalScreen:unload()
        self.portalScreen = nil
    end
    -- A EquipmentScreen não tem :unload por enquanto
    self.equipmentScreen = nil

    -- Salva estado dos managers
    if self.portalManager then self.portalManager:saveState() end
    if self.lobbyStorageManager then self.lobbyStorageManager:saveStorage() end
    if self.hunterManager then
        self.hunterManager:saveActiveHunterData(self.hunterManager:getActiveHunterId())
        self.hunterManager:saveState()
    end

    -- Limpa referências dos managers
    self.portalManager = nil
    self.itemDataManager = nil
    self.lobbyStorageManager = nil
    self.loadoutManager = nil
    self.hunterManager = nil

    -- Desregistra Mock Player Manager
    if ManagerRegistry then
        ManagerRegistry:unregister("playerManager")
        print("LobbyScene: MockPlayerManager desregistrado.")
    end
end

return LobbyScene
