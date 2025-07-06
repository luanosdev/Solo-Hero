local SceneManager = require("src.core.scene_manager")
local Camera = require("src.config.camera")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local Constants = require("src.config.constants")
local ManagerRegistry = require("src.managers.manager_registry")
local LobbyPortalManager = require("src.managers.lobby_portal_manager")
local EquipmentScreen = require("src.ui.screens.equipment_screen")
local ShoppingScreen = require("src.ui.screens.shopping_screen")
local PortalScreen = require("src.ui.screens.portal_screen")
local AgencyScreen = require("src.ui.screens.agency_screen")
local LobbyNavbar = require("src.ui.components.lobby_navbar")
local ShopManager = require("src.managers.shop_manager")
local PatrimonyManager = require("src.managers.patrimony_manager")

local TabIds = Constants.TabIds

--- Cena principal do Lobby.
---Exibe o mapa de fundo quando "Portais" está ativo e a barra de navegação inferior.
---@class LobbyScene
---@field portalScreen PortalScreen
---@field equipmentScreen EquipmentScreen
---@field shoppingScreen ShoppingScreen
---@field reputationManager ReputationManager
---@field agencyManager AgencyManager
---@field portalManager LobbyPortalManager
---@field shopManager ShopManager
---@field patrimonyManager PatrimonyManager
---@field itemDataManager ItemDataManager
---@field lobbyStorageManager LobbyStorageManager
---@field loadoutManager LoadoutManager
---@field archetypeManager ArchetypeManager
---@field hunterManager HunterManager
---@field navbar LobbyNavbar
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
LobbyScene.shoppingScreen = nil ---@type ShoppingScreen|nil Instância da tela de shopping
LobbyScene.portalScreen = nil ---@type PortalScreen|nil Instância da tela de portal
LobbyScene.agencyScreen = nil ---@type AgencyScreen|nil Instância da tela da Agência
LobbyScene.shopManager = nil ---@type ShopManager|nil Instância do gerenciador da loja
LobbyScene.patrimonyManager = nil ---@type PatrimonyManager|nil Instância do gerenciador de patrimônio
LobbyScene.reputationManager = nil ---@type ReputationManager|nil Instância do gerenciador de reputação
LobbyScene.navbar = nil ---@type LobbyNavbar|nil Instância da navbar do lobby

-- Configs da névoa
LobbyScene.fogNoiseScale = 4.0 ---@type number Escala do ruído (valores menores = "zoom maior")
LobbyScene.fogNoiseSpeed = 0.08 ---@type number Velocidade de movimento da névoa
LobbyScene.fogDensityPower = 2.5 ---@type number Expoente para controlar a densidade (maior = mais denso/opaco)
LobbyScene.fogBaseColor = { 0.3, 0.4, 0.6, 1.0 } ---@type table Cor base da névoa (para combinar com o filtro do mapa)

-- Configuração dos botões/tabs inferiores
local tabs = {
    { id = TabIds.SHOPPING,  text = "Shopping" },
    { id = TabIds.CRAFTING,  text = "Criação" },
    { id = TabIds.EQUIPMENT, text = "Equipamento" },
    { id = TabIds.PORTALS,   text = "Portais" },
    { id = TabIds.AGENCY,    text = "Agência" },
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
-- Processa dados de extração se vierem da GameplayScene.
---@param args table|nil Argumentos passados ao carregar a cena.
-- Pode incluir:
-- args.startTab: O ID da aba para abrir inicialmente.
-- args.extractionSuccessful: booleano, true se a extração foi bem-sucedida.
-- args.hunterId: string, ID do caçador que extraiu.
-- args.extractedItems: table, lista de itens da mochila extraídos.
-- args.extractedEquipment: table, mapa de equipamentos extraídos (slotId -> itemInstance).
function LobbyScene:load(args)
    print("LobbyScene:load")
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    -- Configurações básicas da cena
    self.camera = Camera:new()
    self.camera:init()
    -- Define a aba ativa. Se veio de uma extração, geralmente queremos ir para Equipamento ou Portais.
    -- Se args.startTab for definido, ele tem precedência.
    self.activeTab = args and args.startTab or TabIds.PORTALS

    -- Inicializar Gerenciadores de UI/Componentes da Cena
    print("[LobbyScene] Obtendo managers persistentes do Registry...")
    LobbyScene.itemDataManager = ManagerRegistry:get("itemDataManager")
    LobbyScene.lobbyStorageManager = ManagerRegistry:get("lobbyStorageManager")
    LobbyScene.loadoutManager = ManagerRegistry:get("loadoutManager")
    LobbyScene.archetypeManager = ManagerRegistry:get("archetypeManager")
    LobbyScene.hunterManager = ManagerRegistry:get("hunterManager")
    LobbyScene.agencyManager = ManagerRegistry:get("agencyManager")
    LobbyScene.reputationManager = ManagerRegistry:get("reputationManager")
    LobbyScene.portalManager = LobbyPortalManager:new()

    LobbyScene.patrimonyManager = PatrimonyManager:new()
    LobbyScene.patrimonyManager:initialize()

    LobbyScene.shopManager = ShopManager:new(self.itemDataManager, self.patrimonyManager)

    -- Validação básica se os managers foram carregados corretamente em main.lua
    if not self.itemDataManager or not self.lobbyStorageManager or not self.loadoutManager or not self.archetypeManager or not self.hunterManager or not self.reputationManager then
        error(
            "ERRO CRÍTICO [LobbyScene:load]: Falha ao obter um ou mais managers persistentes do Registry! Eles foram inicializados em main.lua?")
    end
    print("[LobbyScene] Managers persistentes obtidos com sucesso.")


    -- Processa os itens da extração se ela foi bem sucedida
    if args and args.extractionSuccessful and args.hunterId then
        print(string.format("[LobbyScene] Processando dados de extração bem-sucedida para o caçador: %s", args.hunterId))

        -- 0. LIMPAR o LoadoutManager antes de adicionar novos itens da extração.
        -- Isso garante que o loadout reflita EXATAMENTE o que foi extraído da mochila.
        if self.loadoutManager and self.loadoutManager.clearAllItems then
            print("[LobbyScene] Limpando o LoadoutManager antes de adicionar itens extraídos...")
            self.loadoutManager:clearAllItems()
        else
            error("[LobbyScene] AVISO: self.loadoutManager:clearAllItems() não encontrado. O loadout não será limpo.")
        end

        local itemsSuccessfullyMovedToLoadout = 0
        local itemsFailedToMoveToLoadout = 0

        -- 1. Adicionar ITENS DA MOCHILA (extractedItems) ao LoadoutManager
        if args.extractedItems and #args.extractedItems > 0 then
            print(string.format("[LobbyScene] Tentando adicionar %d itens da mochila ao LoadoutManager...",
                #args.extractedItems))
            for i, itemInstance in ipairs(args.extractedItems) do
                if itemInstance and itemInstance.itemBaseId then
                    -- Assumindo que GameplayScene fornece instâncias completas prontas para o LoadoutManager.
                    local added = self.loadoutManager:addItemInstance(itemInstance)
                    if added then
                        itemsSuccessfullyMovedToLoadout = itemsSuccessfullyMovedToLoadout + 1
                    else
                        itemsFailedToMoveToLoadout = itemsFailedToMoveToLoadout + 1
                        print(string.format(
                            "[LobbyScene] AVISO: Falha ao adicionar item da mochila (BaseID: %s, InstID: %s) ao LoadoutManager. Provavelmente está cheio.",
                            tostring(itemInstance.itemBaseId), tostring(itemInstance.instanceId)))
                    end
                else
                    print("[LobbyScene] AVISO: Item inválido encontrado em extractedItems, pulando.")
                end
            end
            print(string.format("[LobbyScene] Itens da mochila processados. Sucesso: %d, Falha (sem espaço?): %d",
                itemsSuccessfullyMovedToLoadout, itemsFailedToMoveToLoadout))
        else
            print("[LobbyScene] Nenhum item na mochila (extractedItems) para adicionar ao LoadoutManager.")
        end

        -- 2. Atualizar EQUIPAMENTOS (extractedEquipment) no HunterManager
        --    Os equipamentos extraídos NÃO são adicionados ao LoadoutManager novamente,
        --    pois o LoadoutManager agora reflete a mochila da gameplay.
        --    O HunterManager é atualizado para refletir o que está equipado.
        if args.extractedEquipment and next(args.extractedEquipment) then -- Verifica se a tabela não está vazia
            print(string.format("[LobbyScene] Tentando atualizar %d slots de equipamento para o caçador %s...",
                table.maxn(args.extractedEquipment), args.hunterId))
            local equipmentUpdatedInHunter = 0

            for slotId, itemInstanceFromGameplay in pairs(args.extractedEquipment) do
                if itemInstanceFromGameplay and itemInstanceFromGameplay.itemBaseId then
                    -- Etapa 2a: Atualizar o HunterManager para que ele saiba que este item está equipado no loadout.
                    local equippedInHunter = self.hunterManager:equipItemToLoadout(args.hunterId, slotId,
                        itemInstanceFromGameplay)
                    if equippedInHunter then
                        equipmentUpdatedInHunter = equipmentUpdatedInHunter + 1
                        print(string.format("  - Equipamento no slot '%s' (BaseID: %s) atualizado no HunterManager.",
                            slotId, itemInstanceFromGameplay.itemBaseId))
                    else
                        print(string.format(
                            "[LobbyScene] AVISO: Falha ao equipar item (BaseID: %s) no slot '%s' do HunterManager para o caçador %s.",
                            itemInstanceFromGameplay.itemBaseId, slotId, args.hunterId))
                    end
                else
                    print(string.format(
                        "[LobbyScene] AVISO: Item de equipamento inválido encontrado no slot '%s', pulando.", slotId))
                end
            end
            print(string.format(
                "[LobbyScene] Equipamentos processados. Atualizados no Hunter: %d.",
                equipmentUpdatedInHunter))
        else
            print("[LobbyScene] Nenhum equipamento (extractedEquipment) para processar.")
        end

        -- 3. SALVAR o estado dos managers após a atualização
        print("[LobbyScene] Salvando estado dos managers após extração...")
        -- Salva o LoadoutManager PRIMEIRO, pois o HunterManager pode ter referências a instanceIds dele.
        if self.loadoutManager.saveState then
            self.loadoutManager:saveState()
            print("[LobbyScene] LoadoutManager salvo.")
        else
            print("[LobbyScene] AVISO: loadoutManager:saveState() não encontrado.")
        end

        -- Salva o HunterManager DEPOIS, pois ele referencia os itens que agora estão confirmados no LoadoutManager.
        if self.hunterManager.saveState then
            self.hunterManager:saveState()
            print("[LobbyScene] HunterManager salvo.")
        else
            print("[LobbyScene] AVISO: hunterManager:saveState() não encontrado.")
        end

        -- O LobbyStorageManager não foi modificado neste fluxo, então não precisa salvar aqui.
        -- if self.lobbyStorageManager.saveStorage then ... end

        self.activeTab = TabIds.EQUIPMENT
    elseif args and args.extractionSuccessful == false then
        -- Extração falhou ou foi cancelada (ex: morte do jogador na GameplayScene que levou de volta ao Lobby)
        print("[LobbyScene] Carregado após uma tentativa de extração malsucedida ou saída da gameplay sem extração.")
        -- Neste caso, NENHUM item da partida é transferido, e NADA é salvo aqui.
        -- Os managers já carregaram seu estado persistido anteriormente.
    end
    -- <<< FIM DO PROCESSAMENTO DE DADOS DE EXTRAÇÃO >>>

    -- Inicializa as telas da UI da cena (DEPOIS de processar a extração, pois podem depender dos managers atualizados)
    self.equipmentScreen = EquipmentScreen:new(
        self.itemDataManager,
        self.hunterManager,
        self.lobbyStorageManager,
        self.loadoutManager
    )
    self.shoppingScreen = ShoppingScreen:new(
        self.itemDataManager,
        self.shopManager,
        self.lobbyStorageManager,
        self.loadoutManager,
        self.patrimonyManager
    )
    self.portalScreen = PortalScreen:new(
        self.portalManager,
        self.hunterManager
    )
    self.agencyScreen = AgencyScreen:new(
        self.hunterManager,
        self.archetypeManager,
        self.itemDataManager,
        self.loadoutManager,
        self.agencyManager
    )

    -- Inicializa a navbar
    self.navbar = LobbyNavbar:new(self.hunterManager, self.agencyManager, self.reputationManager, self.patrimonyManager)


    -- Reseta estado de zoom/seleção
    self.portalScreen.isZoomedIn = false
    self.portalScreen.selectedPortal = nil

    -- O PortalScreen agora gerencia internamente o sistema de mapa procedural
    -- Aguardar que o mapa procedural seja gerado antes de inicializar portais
    Logger.info("lobby_scene.load.map", "[LobbyScene] Sistema de mapa procedural configurado no PortalScreen")

    -- Obter dimensões do mapa procedural
    local mapW, mapH = self.portalScreen.proceduralMap:getMapDimensions()

    -- Definir a referência do mapa procedural no Portal Manager
    self.portalManager:setProceduralMap(self.portalScreen.proceduralMap)

    -- Inicializar o Portal Manager com as dimensões do mapa procedural
    self.portalManager:initialize(mapW, mapH)

    Logger.info("lobby_scene.load.portals",
        "[LobbyScene] Portal Manager inicializado com dimensões " .. mapW .. "x" .. mapH)

    local navbarHeight = self.navbar:getHeight()
    tabSettings.yPosition = screenH - tabSettings.height

    local totalTabs = #tabs
    local totalPadding = (totalTabs + 1) * tabSettings.padding
    local availableWidth = screenW - totalPadding
    local tabWidth = availableWidth / totalTabs
    local currentX = tabSettings.padding

    self.activeTabIndex = 0 -- Reset antes de encontrar a aba correta
    for i, tab in ipairs(tabs) do
        tab.x = currentX
        tab.y = tabSettings.yPosition
        tab.w = tabWidth
        tab.h = tabSettings.height
        tab.isHovering = false
        currentX = currentX + tabWidth + tabSettings.padding
        -- Define o tab ativo (pode ter sido alterado pelo processamento da extração)
        if tab.id == self.activeTab then
            self.activeTabIndex = i
        end
    end

    if self.activeTabIndex == 0 and #tabs > 0 then
        -- Fallback se a aba definida por self.activeTab não foi encontrada
        local defaultPortalTabIndex = 0
        for i, tabData in ipairs(tabs) do
            if tabData.id == TabIds.PORTALS then
                defaultPortalTabIndex = i
                break
            end
        end
        self.activeTabIndex = defaultPortalTabIndex > 0 and defaultPortalTabIndex or 1
        self.activeTab = tabs[self.activeTabIndex].id -- Atualiza self.activeTab para consistência
    end

    print("LobbyScene: Tab ativo inicial:", self.activeTabIndex, tabs[self.activeTabIndex].text)

    -- Expor manager de portais globalmente para debug
    _G.DebugPortals = self.portalManager
end

--- Atualiza a lógica da cena (verificação de hover, animação de zoom/pan).
---@param dt number
function LobbyScene:update(dt)
    -- Atualiza animações da navbar
    if self.navbar and self.navbar.update then
        self.navbar:update(dt)
    end

    -- Converte coordenadas físicas do mouse para coordenadas virtuais
    local physicalMx, physicalMy = love.mouse.getPosition()
    local mx, my = ResolutionUtils.toGame(physicalMx, physicalMy)
    if not mx or not my then
        mx, my = 0, 0 -- Fallback se o mouse estiver fora da área do jogo
    end
    local activeTab = tabs[self.activeTabIndex]
    local isPortalScreenActive = activeTab and activeTab.id == TabIds.PORTALS
    local isPortalScreenZoomed = self.portalScreen and self.portalScreen.isZoomedIn

    local tabHoverHandled = false
    if not isPortalScreenZoomed then
        for i, tab in ipairs(tabs) do
            tab.isHovering = (mx >= tab.x and mx <= tab.x + tab.w and my >= tab.y and my <= tab.y + tab.h)
            if tab.isHovering then tabHoverHandled = true end
        end
    else
        for i, tab in ipairs(tabs) do tab.isHovering = false end
    end

    if self.portalScreen and (isPortalScreenActive or isPortalScreenZoomed) then
        local allowPortalScreenHover = not tabHoverHandled
        self.portalScreen:update(dt, mx, my, allowPortalScreenHover)
    elseif activeTab and activeTab.id == TabIds.EQUIPMENT then
        local currentDragState = {
            isDragging = self.isDragging,
            draggedItem = self.draggedItem,
            draggedItemOffsetX = self.draggedItemOffsetX,
            draggedItemOffsetY = self.draggedItemOffsetY,
            sourceGridId = self.sourceGridId,
            sourceSlotId = self.sourceSlotId, -- Adicionado para consistência, pode ser nil
            draggedItemIsRotated = self.draggedItemIsRotated,
            targetGridId = self.targetGridId,
            targetSlotCoords = self.targetSlotCoords,
            isDropValid = self.isDropValid,
            equipmentSlotAreas = self.equipmentSlotAreas -- Passa as áreas de equipamento atuais
        }
        if self.equipmentScreen and self.equipmentScreen.update then
            self.equipmentScreen:update(dt, mx, my, currentDragState)
        end

        -- Lógica de atualização do drag and drop para Equipment Screen
        if self.isDragging then
            self.targetGridId = nil
            self.targetSlotCoords = nil
            self.isDropValid = false

            local visualW = self.draggedItem.gridWidth or 1
            local visualH = self.draggedItem.gridHeight or 1
            if self.draggedItemIsRotated then
                visualW = self.draggedItem.gridHeight or 1
                visualH = self.draggedItem.gridWidth or 1
            end

            local isMouseOverStorage = self.storageGridArea.x and mx >= self.storageGridArea.x and
                mx < self.storageGridArea.x + self.storageGridArea.w and my >= self.storageGridArea.y and
                my < self.storageGridArea.y + self.storageGridArea.h
            local isMouseOverLoadout = self.loadoutGridArea.x and mx >= self.loadoutGridArea.x and
                mx < self.loadoutGridArea.x + self.loadoutGridArea.w and my >= self.loadoutGridArea.y and
                my < self.loadoutGridArea.y + self.loadoutGridArea.h

            local hoverEquipmentSlot = false
            if self.equipmentSlotAreas then
                for slotId, area in pairs(self.equipmentSlotAreas) do
                    if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                        self.targetGridId = "equipment"
                        self.targetSlotCoords = slotId
                        hoverEquipmentSlot = true
                        -- Validação de drop para equipamento
                        if self.itemDataManager and self.draggedItem then
                            local baseData = self.itemDataManager:getBaseItemData(self.draggedItem.itemBaseId)
                            local itemType = baseData and baseData.type
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
                            elseif string.sub(slotId, 1, 5) == "rune_" then
                                expectedType = "rune"
                            end
                            self.isDropValid = (expectedType and expectedType == itemType)
                        else
                            self.isDropValid = false
                        end
                        break
                    end
                end
            end

            if not hoverEquipmentSlot then
                if isMouseOverStorage then
                    self.targetGridId = "storage"
                    local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
                    if storageRows and storageCols then
                        local ItemGridUI = require("src.ui.item_grid_ui")
                        self.targetSlotCoords = ItemGridUI.getSlotCoordsAtMouse(mx, my, storageRows, storageCols,
                            self.storageGridArea.x, self.storageGridArea.y, self.storageGridArea.w,
                            self.storageGridArea.h)
                        if self.targetSlotCoords then
                            self.isDropValid = self.lobbyStorageManager:canPlaceItemAt(
                                self.draggedItem, self.targetSlotCoords.row, self.targetSlotCoords.col, visualW, visualH,
                                self.draggedItem.instanceId)
                        end
                    else
                        self.isDropValid = false
                    end
                elseif isMouseOverLoadout then
                    self.targetGridId = "loadout"
                    local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
                    if loadoutRows and loadoutCols then
                        local ItemGridUI = require("src.ui.item_grid_ui")
                        self.targetSlotCoords = ItemGridUI.getSlotCoordsAtMouse(mx, my, loadoutRows, loadoutCols,
                            self.loadoutGridArea.x, self.loadoutGridArea.y, self.loadoutGridArea.w,
                            self.loadoutGridArea.h)
                        if self.targetSlotCoords then
                            self.isDropValid = self.loadoutManager:canPlaceItemAt(self.draggedItem,
                                self.targetSlotCoords.row, self.targetSlotCoords.col, visualW, visualH,
                                self.draggedItem.instanceId)
                        end
                    else
                        self.isDropValid = false
                    end
                end
            end

            if self.targetSlotCoords then
                local manager = (self.targetGridId == "storage") and self.lobbyStorageManager or self.loadoutManager
                if manager and manager.getItemInstanceAtCoords then
                    local item_at_target = manager:getItemInstanceAtCoords(self.targetSlotCoords.row,
                        self.targetSlotCoords.col)
                    print(string.format(
                        "LobbyScene:update - Target: %s[%s,%s], Dragged: %s, ValidDrop: %s, ItemAtTarget: %s",
                        self.targetGridId, self.targetSlotCoords.row, self.targetSlotCoords.col,
                        self.draggedItem and self.draggedItem.itemBaseId or "nil",
                        tostring(self.isDropValid),
                        item_at_target and item_at_target.itemBaseId or "nil"))
                end
            end
        end
    elseif activeTab and activeTab.id == TabIds.SHOPPING then
        local currentDragState = {
            isDragging = self.isDragging,
            draggedItem = self.draggedItem,
            draggedItemOffsetX = self.draggedItemOffsetX,
            draggedItemOffsetY = self.draggedItemOffsetY,
            sourceGridId = self.sourceGridId,
            draggedItemIsRotated = self.draggedItemIsRotated,
            targetGridId = self.targetGridId,
            targetSlotCoords = self.targetSlotCoords,
            isDropValid = self.isDropValid
        }
        if self.shoppingScreen and self.shoppingScreen.update then
            self.shoppingScreen:update(dt, mx, my, currentDragState)
        end

        -- A lógica de atualização do self.isDragging, self.targetGridId, etc., continua aqui por enquanto
        -- pois é a LobbyScene que gerencia o estado de drag entre as colunas do EquipmentScreen.
        if self.isDragging then
            self.targetGridId = nil
            self.targetSlotCoords = nil
            self.isDropValid = false

            local visualW = self.draggedItem.gridWidth or 1
            local visualH = self.draggedItem.gridHeight or 1
            if self.draggedItemIsRotated then
                visualW = self.draggedItem.gridHeight or 1
                visualH = self.draggedItem.gridWidth or 1
            end

            local isMouseOverStorage = self.storageGridArea.x and mx >= self.storageGridArea.x and
                mx < self.storageGridArea.x + self.storageGridArea.w and my >= self.storageGridArea.y and
                my < self.storageGridArea.y + self.storageGridArea.h
            local isMouseOverLoadout = self.loadoutGridArea.x and mx >= self.loadoutGridArea.x and
                mx < self.loadoutGridArea.x + self.loadoutGridArea.w and my >= self.loadoutGridArea.y and
                my < self.loadoutGridArea.y + self.loadoutGridArea.h

            local hoverEquipmentSlot = false
            if self.equipmentSlotAreas then
                for slotId, area in pairs(self.equipmentSlotAreas) do
                    if area and mx >= area.x and mx < area.x + area.w and my >= area.y and my < area.y + area.h then
                        self.targetGridId = "equipment"
                        self.targetSlotCoords = slotId
                        hoverEquipmentSlot = true
                        -- Validação de drop para equipamento (exemplo, precisa de itemDataManager)
                        if self.itemDataManager and self.draggedItem then
                            local baseData = self.itemDataManager:getBaseItemData(self.draggedItem.itemBaseId)
                            local itemType = baseData and baseData.type
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
                            self.isDropValid = (expectedType and expectedType == itemType)
                        else
                            self.isDropValid = false
                        end
                        break
                    end
                end
            end

            if not hoverEquipmentSlot then
                if isMouseOverStorage then
                    self.targetGridId = "storage"
                    local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
                    if storageRows and storageCols then
                        local ItemGridUI = require("src.ui.item_grid_ui")
                        self.targetSlotCoords = ItemGridUI.getSlotCoordsAtMouse(mx, my, storageRows, storageCols,
                            self.storageGridArea.x, self.storageGridArea.y, self.storageGridArea.w,
                            self.storageGridArea.h)
                        if self.targetSlotCoords then
                            self.isDropValid = self.lobbyStorageManager:canPlaceItemAt(
                                self.draggedItem, self.targetSlotCoords.row, self.targetSlotCoords.col, visualW, visualH,
                                self.draggedItem.instanceId)
                        end
                    else
                        self.isDropValid = false -- Não pode validar se não tem dimensões
                    end
                elseif isMouseOverLoadout then
                    self.targetGridId = "loadout"
                    local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
                    if loadoutRows and loadoutCols then
                        local ItemGridUI = require("src.ui.item_grid_ui")
                        self.targetSlotCoords = ItemGridUI.getSlotCoordsAtMouse(mx, my, loadoutRows, loadoutCols,
                            self.loadoutGridArea.x, self.loadoutGridArea.y, self.loadoutGridArea.w,
                            self.loadoutGridArea.h)
                        if self.targetSlotCoords then
                            self.isDropValid = self.loadoutManager:canPlaceItemAt(self.draggedItem,
                                self.targetSlotCoords.row, self.targetSlotCoords.col, visualW, visualH,
                                self.draggedItem.instanceId)
                        end
                    else
                        self.isDropValid = false -- Não pode validar se não tem dimensões
                    end
                end
            end

            if self.targetSlotCoords then
                local manager = (self.targetGridId == "storage") and self.lobbyStorageManager or self.loadoutManager
                local item_at_target = manager:getItemInstanceAtCoords(self.targetSlotCoords.row,
                    self.targetSlotCoords.col) -- Supondo que aceita nil para sectionIndex no loadout
                print(string.format(
                    "LobbyScene:update - Target: %s[%s,%s], Dragged: %s, ValidDrop: %s, ItemAtTarget: %s",
                    self.targetGridId, self.targetSlotCoords.row, self.targetSlotCoords.col,
                    self.draggedItem and self.draggedItem.itemBaseId or "nil",
                    tostring(self.isDropValid),
                    item_at_target and item_at_target.itemBaseId or "nil"))
            end
        end
    elseif activeTab and activeTab.id == TabIds.AGENCY then
        if self.agencyScreen and self.agencyScreen.update then
            local allowAgencyScreenHover = not tabHoverHandled
            self.agencyScreen:update(dt, mx, my, allowAgencyScreenHover)
        end
    end
end

--- Desenha os elementos da cena.
-- Desenha o mapa ou fundo padrão, o modal (se ativo) e a barra de tabs.
function LobbyScene:draw()
    -- Usa dimensões virtuais do jogo ao invés das dimensões físicas da janela
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    -- Converte coordenadas físicas do mouse para coordenadas virtuais
    local physicalMx, physicalMy = love.mouse.getPosition()
    local mx, my = ResolutionUtils.toGame(physicalMx, physicalMy)
    if not mx or not my then
        mx, my = 0, 0 -- Fallback se o mouse estiver fora da área do jogo
    end
    local activeTab = tabs[self.activeTabIndex]
    local isPortalScreenZoomed = self.portalScreen and self.portalScreen.isZoomedIn
    local navbarHeight = self.navbar:getHeight()

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
        love.graphics.rectangle("fill", 0, navbarHeight, screenW, screenH - navbarHeight)
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
                -- Ajusta área disponível para o EquipmentScreen considerando navbar
                local availableHeight = screenH - navbarHeight - tabSettings.height
                self.storageGridArea, self.loadoutGridArea, self.equipmentSlotAreas = self.equipmentScreen:draw(
                    screenW,
                    availableHeight + navbarHeight, -- Passa altura total mas com offset
                    tabSettings,
                    dragState,
                    mx,
                    my - navbarHeight -- Ajusta coordenadas do mouse
                )
            elseif activeTab.id == TabIds.SHOPPING then
                local dragState = {
                    isDragging = self.isDragging,
                    draggedItem = self.draggedItem,
                    draggedItemOffsetX = self.draggedItemOffsetX,
                    draggedItemOffsetY = self.draggedItemOffsetY,
                    draggedItemIsRotated = self.draggedItemIsRotated,
                    targetGridId = self.targetGridId,
                    targetSlotCoords = self.targetSlotCoords,
                    isDropValid = self.isDropValid
                }
                -- Ajusta área disponível para o ShoppingScreen considerando navbar
                local availableHeight = screenH - navbarHeight - tabSettings.height
                self.storageGridArea, self.loadoutGridArea, self.shopArea = self.shoppingScreen:draw(
                    screenW,
                    screenH,
                    tabSettings,
                    dragState,
                    mx,
                    my,
                    navbarHeight
                )
            elseif activeTab.id == TabIds.AGENCY then
                if self.agencyScreen then
                    -- Define área de desenho (área entre navbar e tabs)
                    local areaX, areaY, areaW, areaH = 0, navbarHeight, screenW,
                        screenH - navbarHeight - tabSettings.height
                    self.agencyScreen:draw(areaX, areaY, areaW, areaH, mx, my)
                else
                    love.graphics.setColor(colors.red)
                    love.graphics.printf("Erro: GuildScreen não inicializado!", screenW / 2, screenH / 2, 0, "center")
                end
            elseif activeTab.id == TabIds.VENDOR then
                -- Espaço para desenhar a UI do Vendedor
                love.graphics.printf("VENDEDOR", screenW / 2, (screenH + navbarHeight) / 2, 0, "center")
            elseif activeTab.id == TabIds.CRAFTING then
                -- Espaço para desenhar a UI de Criação
                love.graphics.printf("CRIAÇÃO", screenW / 2, (screenH + navbarHeight) / 2, 0, "center")
            elseif activeTab.id == TabIds.SETTINGS then
                -- Espaço para desenhar a UI de Configurações
                love.graphics.printf("CONFIGURAÇÕES", screenW / 2, (screenH + navbarHeight) / 2, 0, "center")
            end
        end
    end

    -- 2. Desenha Tabs (sempre por cima)
    -- Só desenha as tabs se o modal de recrutamento da tela da agência não estiver ativo.
    if not (self.agencyScreen and self.agencyScreen.recruitmentManager and self.agencyScreen.recruitmentManager.isRecruiting) then
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
    end

    -- 3. Desenha a Navbar (sempre por cima de tudo, exceto quando modal de recrutamento está ativo)
    if self.navbar and not (self.agencyScreen and self.agencyScreen.recruitmentManager and self.agencyScreen.recruitmentManager.isRecruiting) then
        self.navbar:draw(screenW, screenH)
    end

    -- Reset final
    love.graphics.setColor(1, 1, 1, 1)
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
                -- print(string.format("LobbyScene:mousepressed - Tab %s HOVERED", tab.text)) -- LOG 2
                -- print(string.format("LobbyScene: Tab '%s' clicado!", tab.text))
                if tab.id == TabIds.QUIT then
                    love.event.quit()
                else
                    if i ~= self.activeTabIndex then -- Só ignora se realmente trocou de tab
                        self.activeTabIndex = i
                        -- print("LobbyScene: Tab changed")
                        -- <<< SET GUILD SCREEN FLAG >>>
                        if tab.id == TabIds.AGENCY and self.agencyScreen then
                            self.agencyScreen.isActiveFrame = true
                        end
                    end
                    -- Se estava com zoom no portal, mudar de tab cancela
                    if isPortalScreenZoomed and self.portalScreen then
                        -- print("LobbyScene: Mudança de tab cancelando zoom do portal.")
                        self.portalScreen.isZoomedIn = false
                        self.portalScreen.selectedPortal = nil
                        -- Ocultar seções dos portais quando sai do zoom
                        if self.portalScreen.titleSection then
                            self.portalScreen.titleSection:hide()
                        end
                        if self.portalScreen.loadoutSection then
                            self.portalScreen.loadoutSection:hide()
                        end
                    end
                end
                break
            end
        end
        -- print(string.format("LobbyScene:mousepressed - tabClicked=%s. Returning?", tostring(tabClicked))) -- LOG 3
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
                    -- print(string.format("LobbyScene: Drag iniciado: Item %d (%s) from %s%s. Estava rotacionado: %s", self.draggedItem.instanceId, self.draggedItem.itemBaseId, self.sourceGridId, self.sourceSlotId and ("[" .. self.sourceSlotId .. "]") or "", tostring(self.draggedItemIsRotated)))
                    return
                elseif consumed then
                    return -- Consumiu sem iniciar drag (ex: tab storage)
                end
            end
        elseif activeTab and activeTab.id == TabIds.SHOPPING then
            -- Delega para ShoppingScreen
            if self.shoppingScreen then
                local consumed, dragStartData = self.shoppingScreen:handleMousePress(x, y, buttonIdx)
                if consumed and dragStartData then
                    self.isDragging = true
                    self.draggedItem = dragStartData.item
                    self.sourceGridId = dragStartData.sourceGridId
                    self.draggedItemOffsetX = dragStartData.offsetX
                    self.draggedItemOffsetY = dragStartData.offsetY
                    self.draggedItemIsRotated = dragStartData.isRotated or false
                    self.sourceSlotId = nil -- Shopping não tem slots específicos
                    return
                elseif consumed then
                    return -- Consumiu sem iniciar drag
                end
            end
        elseif activeTab and activeTab.id == TabIds.PORTALS then
            -- Delega para PortalScreen (funciona tanto para zoom quanto não-zoom)
            if self.portalScreen and self.portalScreen.handleMousePress then
                local consumed = self.portalScreen:handleMousePress(x, y, buttonIdx, istouch)
                if consumed then
                    Logger.debug("lobby_scene.mousepressed.portals", "[LobbyScene] Clique consumido pelo PortalScreen")
                    return
                end
            end
        elseif activeTab and activeTab.id == TabIds.AGENCY then
            if self.agencyScreen then
                Logger.debug("[LobbyScene]", "Delegando clique para AgencyScreen...")
                local consumed = self.agencyScreen:handleMousePress(x, y, buttonIdx)
                if consumed then
                    Logger.debug("[LobbyScene]", "Clique consumido pela AgencyScreen.")
                    return
                end
            end
        end

        -- DEBUG: Se chegou aqui, o clique não foi consumido por nenhuma tela delegada
        -- print(">>> LobbyScene:mousepressed - Click was not consumed by any delegated screen.")
    end
end

--- Processa o soltar do mouse, finalizando o drag-and-drop.
---@param x number
---@param y number
---@param buttonIdx number
---@param istouch boolean
---@param presses number
function LobbyScene:mousereleased(x, y, buttonIdx, istouch, presses)
    local activeTab = tabs[self.activeTabIndex]

    if buttonIdx == 1 then
        -- Primeiro, verifica se a tela da aba ativa quer tratar o release
        local screenConsumedRelease = false
        if activeTab and activeTab.id == TabIds.AGENCY then -- <<< VERIFICA ABA AGENCY
            if self.agencyScreen and self.agencyScreen.handleMouseRelease then
                screenConsumedRelease = self.agencyScreen:handleMouseRelease(x, y, buttonIdx)
            end
            -- Adicionar outros `elseif` para outras telas que tratam release (ex: EquipmentScreen se não for drag/drop)
        end

        -- Se a tela ativa consumiu o release (ex: clicou num botão dela), termina aqui
        if screenConsumedRelease then
            print("LobbyScene: Mouse release consumed by active screen.")
            return
        end

        -- Se não foi consumido pela tela e estávamos arrastando um item (lógica do EquipmentScreen)
        if self.isDragging then
            print("LobbyScene: Drag finalizado.")
            local dragConsumed = false
            -- Trata drop nas abas de equipamento e shopping
            if activeTab and activeTab.id == TabIds.EQUIPMENT then
                local dragState = {
                    isDragging = self.isDragging,
                    draggedItem = self.draggedItem,
                    sourceGridId = self.sourceGridId,
                    sourceSlotId = self.sourceSlotId,
                    draggedItemIsRotated = self.draggedItemIsRotated,
                    targetGridId = self.targetGridId,
                    targetSlotCoords = self.targetSlotCoords,
                    isDropValid = self.isDropValid,
                    equipmentSlotAreas = self.equipmentSlotAreas
                }
                dragConsumed = self.equipmentScreen:handleMouseRelease(x, y, buttonIdx, dragState)
            elseif activeTab and activeTab.id == TabIds.SHOPPING then
                local dragState = {
                    isDragging = self.isDragging,
                    draggedItem = self.draggedItem,
                    sourceGridId = self.sourceGridId,
                    draggedItemIsRotated = self.draggedItemIsRotated,
                    targetGridId = self.targetGridId,
                    targetSlotCoords = self.targetSlotCoords,
                    isDropValid = self.isDropValid
                }
                dragConsumed = self.shoppingScreen:handleMouseRelease(x, y, buttonIdx, dragState)
            end

            if dragConsumed then
                print("LobbyScene: Drop consumido pelo EquipmentScreen.")
            else
                print("LobbyScene: Drop NÃO consumido (ou ocorreu fora de área válida). Retornando item...")
                -- Idealmente, aqui você chamaria um método para retornar o item à origem
                -- Ex: self.equipmentScreen:returnDraggedItem(...) ou similar
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
            self.draggedItemIsRotated = false
        end -- Fim do if self.isDragging
    end     -- Fim do if buttonIdx == 1
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

    -- Verifica se estamos arrastando um item na aba de Equipamento ou Shopping
    if self.isDragging and activeTab and activeTab.id == TabIds.EQUIPMENT and self.equipmentScreen then
        -- Delega para a keypressed da EquipmentScreen
        local dragState = {
            isDragging = self.isDragging,
            draggedItem = self.draggedItem,
            draggedItemIsRotated = self.draggedItemIsRotated
        }
        local wantsToRotate = self.equipmentScreen:keypressed(key, dragState)

        if wantsToRotate and self.draggedItem then
            -- Alterna o estado de rotação VISUAL
            self.draggedItemIsRotated = not self.draggedItemIsRotated
            -- NÃO modifica self.draggedItem aqui
        end
    elseif self.isDragging and activeTab and activeTab.id == TabIds.SHOPPING and self.shoppingScreen then
        -- Delega para a keypressed da ShoppingScreen
        local dragState = {
            isDragging = self.isDragging,
            draggedItem = self.draggedItem,
            draggedItemIsRotated = self.draggedItemIsRotated
        }
        local wantsToRotate = self.shoppingScreen:keypressed(key, dragState)

        if wantsToRotate and self.draggedItem then
            -- Alterna o estado de rotação VISUAL
            self.draggedItemIsRotated = not self.draggedItemIsRotated
        end
    end

    if activeTab and activeTab.id == TabIds.AGENCY then
        self.agencyScreen:handleKeyPress(key)
    end

    -- Comandos de debug para o sistema de patrimônio
    if key == "f1" then
        -- F1: Adiciona 1000 de ouro
        if self.patrimonyManager then
            self.patrimonyManager:addGold(1000, "debug_f1")
            print("[DEBUG] Adicionado 1000 de ouro")
        end
    elseif key == "f2" then
        -- F2: Remove 500 de ouro
        if self.patrimonyManager then
            self.patrimonyManager:removeGold(500, "debug_f2")
            print("[DEBUG] Removido 500 de ouro")
        end
    elseif key == "f3" then
        -- F3: Mostra patrimônio atual
        if self.patrimonyManager then
            local currentGold = self.patrimonyManager:getCurrentGold()
            local formattedGold = self.patrimonyManager:formatGold()
            print("[DEBUG] Patrimônio atual: " .. currentGold .. " (" .. formattedGold .. ")")
        end
    end

    -- TODO: Adicionar delegação para outras telas/abas se necessário
end

--- NOVO: Processa scroll do mouse.
-- Delega para a tela ativa se ela tiver o handler `handleMouseScroll`.
---@param x number Posição X do mouse (relativa à janela).
---@param y number Posição Y do mouse (relativa à janela).
function LobbyScene:wheelmoved(x, y)
    local activeTab = tabs[self.activeTabIndex]
    if activeTab and activeTab.id == TabIds.AGENCY then
        if self.agencyScreen and self.agencyScreen.handleMouseScroll then
            -- Converte coordenadas físicas do mouse para coordenadas virtuais
            local physicalMx, physicalMy = love.mouse.getPosition()
            local mx, my = ResolutionUtils.toGame(physicalMx, physicalMy)
            if not mx or not my then
                mx, my = 0, 0 -- Fallback se o mouse estiver fora da área do jogo
            end
            self.agencyScreen:handleMouseScroll(x, y, mx, my)
        end
        -- Adicionar delegação para outras telas que precisem de scroll
        -- elseif activeTab.id == TabIds.EQUIPMENT then
        --     if self.equipmentScreen and self.equipmentScreen.handleMouseScroll then
        --         self.equipmentScreen:handleMouseScroll(x, y)
        --     end
    end
end

function LobbyScene:debugAddItemToPlayerInventory(itemId, quantity)
    quantity = quantity or 1
    print(string.format("[DEBUG] Tentando adicionar %d de '%s' ao inventário do jogador...", quantity, itemId))

    if not self.itemDataManager:getBaseItemData(itemId) then
        print(string.format("[DEBUG] ERRO: Item com ID base '%s' não encontrado no ItemDataManager.", itemId))
        return
    end

    local addedQuantity = self.lobbyStorageManager:addItem(itemId, quantity)
    if addedQuantity > 0 then
        print(string.format("[DEBUG] Adicionado %d de '%s' ao inventário.", addedQuantity, itemId))
    else
        print(
            string.format("[DEBUG] Não foi possível adicionar '%s' ao inventário (pode estar cheio ou item inválido)."),
            itemId)
    end
end

--- Chamado quando a cena é descarregada.
-- Libera a imagem do mapa da memória e limpa referência do manager.
function LobbyScene:unload()
    Logger.info("lobby_scene.unload", "[LobbyScene] Descarregando cena de lobby")
    -- Libera recursos das telas filhas
    if self.portalScreen then
        self.portalScreen:unload()
        self.portalScreen = nil
    end
    self.equipmentScreen = nil
    self.shoppingScreen = nil
    self.agencyScreen = nil
    self.navbar = nil

    -- Salva estado dos managers
    if self.portalManager then self.portalManager:saveState() end
    if self.shopManager then self.shopManager:saveState() end
    if self.lobbyStorageManager then self.lobbyStorageManager:saveStorage() end
    if self.loadoutManager then self.loadoutManager:saveState() end
    if self.hunterManager then
        self.hunterManager:saveState()
    end

    -- Limpa referências dos managers
    self.portalManager = nil
    self.shopManager = nil
    self.itemDataManager = nil
    self.lobbyStorageManager = nil
    self.loadoutManager = nil
    self.hunterManager = nil
end

return LobbyScene
