local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local LobbyPortalManager = require("src.managers.lobby_portal_manager")
local Formatters = require("src.utils.formatters")
local ItemDataManager = require("src.managers.item_data_manager")
local ItemGridUI = require("src.ui.item_grid_ui")
local LobbyStorageManager = require("src.managers.lobby_storage_manager")
local LoadoutManager = require("src.managers.loadout_manager")

--- Cena principal do Lobby.
-- Exibe o mapa de fundo quando "Portais" está ativo e a barra de navegação inferior.
local LobbyScene = {}

-- Estado da cena
LobbyScene.mapImage = nil ---@type love.Image|nil
LobbyScene.mapImagePath = "assets/images/map.png"
LobbyScene.mapOriginalWidth = 0  -- Largura original da imagem do mapa
LobbyScene.mapOriginalHeight = 0 -- Altura original da imagem do mapa
LobbyScene.fogShader = nil ---@type love.Shader|nil
LobbyScene.fogShaderPath = "assets/shaders/fog_noise.fs"
LobbyScene.noiseTime = 0 ---@type number Contador de tempo para animar o ruído
LobbyScene.activeTabIndex = 0 ---@type integer
LobbyScene.portalManager = nil ---@type LobbyPortalManager|nil Instância do gerenciador de portais
LobbyScene.itemDataManager = nil ---@type ItemDataManager|nil Instância do gerenciador de dados de itens
LobbyScene.lobbyStorageManager = nil ---@type LobbyStorageManager|nil Instância do gerenciador de armazenamento do lobby
LobbyScene.loadoutManager = nil ---@type LoadoutManager|nil Instância do gerenciador de loadout

-- Estado de Zoom/Pan e Seleção de Portal
LobbyScene.selectedPortal = nil ---@type PortalData|nil Portal atualmente selecionado.
LobbyScene.isZoomedIn = false     -- Estamos no modo de detalhe/zoom?
LobbyScene.mapTargetZoom = 3.0    -- Nível de zoom ao selecionar um portal
LobbyScene.mapCurrentZoom = 1.0   -- Nível de zoom atual (para animação)
LobbyScene.mapTargetPanX = 0      -- Coordenada X do MAPA para centralizar
LobbyScene.mapTargetPanY = 0      -- Coordenada Y do MAPA para centralizar
LobbyScene.mapCurrentPanX = 0     -- Coordenada X do MAPA no centro atual da tela
LobbyScene.mapCurrentPanY = 0     -- Coordenada Y do MAPA no centro atual da tela
LobbyScene.zoomSmoothFactor = 5.0 -- Fator de suavização para animação de zoom/pan

-- Estado do Modal de Detalhes
local screenW = love.graphics.getWidth() -- Obtém largura para cálculo
local screenH = love.graphics.getHeight()
local modalW = 350                       -- Largura do modal
local modalMarginX = 20
local modalMarginY = 20
local tabBarHeight = 50                                                                                  -- Altura da barra de tabs inferior (ajustar se mudar)
local modalH = screenH - (modalMarginY * 2) - tabBarHeight
LobbyScene.modalRect = { x = screenW - modalW - modalMarginX, y = modalMarginY, w = modalW, h = modalH } -- Posição DIREITA e altura ajustada
LobbyScene.modalBtnEnterRect = { x = 0, y = 0, w = 120, h = 40 }
LobbyScene.modalBtnCancelRect = { x = 0, y = 0, w = 120, h = 40 }
LobbyScene.modalButtonEnterHover = false
LobbyScene.modalButtonCancelHover = false

-- Configs da névoa
LobbyScene.fogNoiseScale = 4.0 ---@type number Escala do ruído (valores menores = "zoom maior")
LobbyScene.fogNoiseSpeed = 0.08 ---@type number Velocidade de movimento da névoa
LobbyScene.fogDensityPower = 2.5 ---@type number Expoente para controlar a densidade (maior = mais denso/opaco)
LobbyScene.fogBaseColor = { 0.3, 0.4, 0.6, 1.0 } ---@type table Cor base da névoa (para combinar com o filtro do mapa)

-- <<< NOVO: IDs constantes para as abas >>>
local TabIds = {
    VENDOR = 1,
    CRAFTING = 2,
    EQUIPMENT = 3,
    PORTALS = 4,
    HEROES = 5,
    SETTINGS = 6,
    QUIT = 7,
}

-- Configuração dos botões/tabs inferiores
local tabs = {
    { id = TabIds.VENDOR,    text = "Vendedor" }, -- ID em Inglês, Texto em Português
    { id = TabIds.CRAFTING,  text = "Criação" },
    { id = TabIds.EQUIPMENT, text = "Equipamento" },
    { id = TabIds.PORTALS,   text = "Portais" }, -- Será definido como ativo no :load
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

--- Chamado quando a cena é carregada.
-- Calcula layout dos tabs, carrega imagem do mapa e define tab inicial.
---@param args table|nil
function LobbyScene:load(args)
    print("LobbyScene:load")
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    self.noiseTime = 0                                                       -- Reseta o tempo do ruído
    self.portalManager = LobbyPortalManager:new()                            -- <<< CRIA INSTÂNCIA PORTAL
    self.itemDataManager = ItemDataManager:new()                             -- <<< CRIA INSTÂNCIA ITEM DATA
    self.lobbyStorageManager = LobbyStorageManager:new(self.itemDataManager) -- <<< ADICIONADO
    self.loadoutManager = LoadoutManager:new(self.itemDataManager)           -- <<< ADICIONADO

    -- Reseta estado de zoom/seleção
    self.selectedPortal = nil
    self.isZoomedIn = false
    self.mapCurrentZoom = 1.0
    self.modalButtonEnterHover = false
    self.modalButtonCancelHover = false

    -- Carrega a imagem do mapa
    local mapSuccess, mapErr = pcall(function()
        self.mapImage = love.graphics.newImage(self.mapImagePath)
    end)
    if not mapSuccess or not self.mapImage then
        print(string.format("Erro ao carregar imagem do mapa '%s': %s", self.mapImagePath,
            tostring(mapErr or "not found")))
        self.mapImage = nil
        self.mapOriginalWidth = 0
        self.mapOriginalHeight = 0
    else
        -- Armazena dimensões originais e inicializa pan/zoom
        self.mapOriginalWidth = self.mapImage:getWidth()
        self.mapOriginalHeight = self.mapImage:getHeight()
        self.mapTargetPanX = self.mapOriginalWidth / 2 -- Começa centrado
        self.mapTargetPanY = self.mapOriginalHeight / 2
        self.mapCurrentPanX = self.mapTargetPanX
        self.mapCurrentPanY = self.mapTargetPanY
        self.portalManager:initialize(self.mapOriginalWidth, self.mapOriginalHeight) -- <<< INICIALIZA PORTAIS
    end

    -- Carrega o shader de névoa
    local shaderSuccess, shaderErr = pcall(function()
        self.fogShader = love.graphics.newShader(self.fogShaderPath)
    end)
    if not shaderSuccess or not self.fogShader then
        print(string.format("Erro ao carregar shader de névoa '%s': %s - EFEITO DESABILITADO", self.fogShaderPath,
            tostring(shaderErr or "error")))
        self.fogShader = nil
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

    -- Calcula posições dos botões do modal
    local modal = self.modalRect
    local btnW, btnH = self.modalBtnEnterRect.w, self.modalBtnEnterRect.h
    local btnPadding = 20
    self.modalBtnEnterRect.x = modal.x + (modal.w / 2) - btnW - (btnPadding / 2)
    self.modalBtnEnterRect.y = modal.y + modal.h - btnH - btnPadding
    self.modalBtnCancelRect.x = modal.x + (modal.w / 2) + (btnPadding / 2)
    self.modalBtnCancelRect.y = modal.y + modal.h - btnH - btnPadding

    print("LobbyScene: Tab ativo inicial:", self.activeTabIndex, tabs[self.activeTabIndex].text)
end

--- Função auxiliar para interpolação linear (Lerp)
local function lerp(a, b, t)
    return a + (b - a) * t
end

--- Atualiza a lógica da cena (verificação de hover, animação de zoom/pan).
---@param dt number
function LobbyScene:update(dt)
    local mx, my = love.mouse.getPosition()

    -- 1. Animação de Zoom e Pan
    local targetZoom = self.isZoomedIn and self.mapTargetZoom or 1.0
    local targetPanX = self.isZoomedIn and self.mapTargetPanX or (self.mapOriginalWidth / 2)
    local targetPanY = self.isZoomedIn and self.mapTargetPanY or (self.mapOriginalHeight / 2)
    local factor = math.min(1, dt * self.zoomSmoothFactor) -- Limita o fator para não ultrapassar o alvo

    self.mapCurrentZoom = lerp(self.mapCurrentZoom, targetZoom, factor)
    self.mapCurrentPanX = lerp(self.mapCurrentPanX, targetPanX, factor)
    self.mapCurrentPanY = lerp(self.mapCurrentPanY, targetPanY, factor)

    -- 2. Hover dos botões das Tabs inferiores
    local tabHoverHandled = false
    if not self.isZoomedIn then -- Só verifica hover das tabs se não estiver com zoom/modal
        for i, tab in ipairs(tabs) do
            tab.isHovering = (mx >= tab.x and mx <= tab.x + tab.w and my >= tab.y and my <= tab.y + tab.h)
            if tab.isHovering then tabHoverHandled = true end -- Marca se o mouse está sobre alguma tab
        end
    else
        for i, tab in ipairs(tabs) do tab.isHovering = false end -- Garante que não haja hover nas tabs se zoom ativo
    end

    -- 3. Hover dos botões do Modal (se visível)
    self.modalButtonEnterHover = false
    self.modalButtonCancelHover = false
    local modalHoverHandled = false
    if self.selectedPortal then -- Modal está visível
        -- Decrementa o timer do portal selecionado
        self.selectedPortal.timer = self.selectedPortal.timer - dt

        -- <<< NOVO: Verifica se o portal expirou enquanto selecionado >>>
        if self.selectedPortal.timer <= 0 then
            print(string.format("LobbyScene: Portal selecionado '%s' expirou! Cancelando seleção.",
                self.selectedPortal.name))
            self.selectedPortal.timer = 0 -- Garante que não fique negativo
            self.selectedPortal = nil
            self.isZoomedIn = false
            -- A animação de zoom out começará no próximo frame devido ao reset do isZoomedIn
            -- Não precisa mais processar hover dos botões deste modal
            return -- Sai do bloco de update para o modal
        end

        -- Garante que o timer não fique negativo (apenas para exibição) - Movido para após a verificação de expiração
        -- if self.selectedPortal.timer < 0 then self.selectedPortal.timer = 0 end

        local mrE = self.modalBtnEnterRect
        local mrC = self.modalBtnCancelRect
        self.modalButtonEnterHover = (mx >= mrE.x and mx <= mrE.x + mrE.w and my >= mrE.y and my <= mrE.y + mrE.h)
        self.modalButtonCancelHover = (mx >= mrC.x and mx <= mrC.x + mrC.w and my >= mrC.y and my <= mrC.y + mrC.h)
        -- Marca se o mouse está sobre o modal ou seus botões
        local m = self.modalRect
        if (mx >= m.x and mx <= m.x + m.w and my >= m.y and my <= m.y + m.h) or self.modalButtonEnterHover or self.modalButtonCancelHover then
            modalHoverHandled = true
        end
    end

    -- Atualiza o tempo para animar o ruído do shader
    self.noiseTime = self.noiseTime + dt

    -- 4. Atualiza o Portal Manager
    local activeTab = tabs[self.activeTabIndex]                      -- Pega a aba ativa pelo índice
    local isMapActive = activeTab and activeTab.id == TabIds.PORTALS -- <<< Já usa ID correto
    -- Calcula transformação ATUAL do mapa para passar ao manager
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local currentMapScale = self.mapCurrentZoom -- Escala é o zoom atual
    local currentMapDrawX = screenW / 2 - self.mapCurrentPanX * currentMapScale
    local currentMapDrawY = screenH / 2 - self.mapCurrentPanY * currentMapScale

    -- Só permite hover nos portais se a tab Portais estiver ativa E não houver zoom/modal ativo
    local allowPortalHover = isMapActive and not self.isZoomedIn and not tabHoverHandled and not modalHoverHandled
    self.portalManager:update(dt, mx, my, allowPortalHover, currentMapScale, currentMapDrawX, currentMapDrawY)
end

--- Desenha os elementos da cena.
-- Desenha o mapa ou fundo padrão, o modal (se ativo) e a barra de tabs.
function LobbyScene:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Calcula a transformação atual do mapa (baseado nos valores interpolados de update)
    local currentMapScale = self.mapCurrentZoom
    local currentMapDrawX = screenW / 2 - self.mapCurrentPanX * currentMapScale
    local currentMapDrawY = screenH / 2 - self.mapCurrentPanY * currentMapScale

    -- Desenha o fundo (mapa ou cor sólida)
    local activeTab = tabs[self.activeTabIndex]

    local drawMapCondition = (activeTab and activeTab.id == TabIds.PORTALS) or
        self
        .isZoomedIn -- Desenha mapa se tab Portais OU se zoom ativo

    if drawMapCondition and self.mapImage then
        -- Desenha o mapa tingido com a transformação atual
        love.graphics.setColor(colors.map_tint)
        love.graphics.draw(self.mapImage, currentMapDrawX, currentMapDrawY, 0, currentMapScale, currentMapScale)
        love.graphics.setColor(colors.white) -- Reseta cor

        -- Desenha a névoa com shader POR CIMA do mapa
        if self.fogShader then
            love.graphics.setShader(self.fogShader)
            self.fogShader:send("time", self.noiseTime * self.fogNoiseSpeed)
            self.fogShader:send("noiseScale", self.fogNoiseScale / self.mapCurrentZoom) -- Ajusta escala da névoa com zoom
            self.fogShader:send("densityPower", self.fogDensityPower)
            self.fogShader:send("fogColor", self.fogBaseColor)
            love.graphics.rectangle("fill", 0, 0, screenW, screenH)
            love.graphics.setShader()
        end
        love.graphics.setColor(colors.white)

        -- Desenha os portais usando o manager com a transformação atual
        self.portalManager:draw(currentMapScale, currentMapDrawX, currentMapDrawY, self.selectedPortal)
        love.graphics.setColor(colors.white)

        --[[ -- REMOVIDO BLOCO DE DESENHO DAS OUTRAS ABAS DE DENTRO DO IF DO MAPA
        -- <<< NOVO: Desenha conteúdo específico da aba ativa >>>
        if activeTab then
           ... (código das outras abas estava aqui erroneamente)
        end
        --]]
    else
        -- Desenha fundo padrão se não for para desenhar o mapa
        love.graphics.setColor(colors.lobby_background)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(colors.white)

        -- <<< CORREÇÃO: Bloco de desenho das outras abas movido para cá >>>
        if activeTab then
            if activeTab.id == TabIds.EQUIPMENT then
                -- Define as áreas para as grades (ex: Storage à esquerda, Loadout à direita)
                local padding = 20
                local availableW = screenW - padding * 3                 -- Espaço total menos paddings
                local storageW = math.floor(availableW * 0.65)           -- Storage ocupa 65%
                local loadoutW = math.floor(availableW * 0.35)           -- Loadout ocupa 35%
                local gridH = screenH - tabSettings.height - padding * 2 -- Altura disponível acima das tabs

                local storageArea = { x = padding, y = padding, w = storageW, h = gridH }
                local loadoutArea = { x = padding * 2 + storageW, y = padding, w = loadoutW, h = gridH }

                -- Desenha Grade do Armazenamento (Storage)
                if self.lobbyStorageManager and self.itemDataManager then
                    local storageItems = self.lobbyStorageManager:getItems() -- Itens da seção ativa
                    local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
                    local sectionInfo = {
                        total = self.lobbyStorageManager:getTotalSections(),
                        active = self.lobbyStorageManager:getActiveSectionIndex()
                    }
                    ItemGridUI.drawItemGrid(storageItems, storageRows, storageCols,
                        storageArea.x, storageArea.y, storageArea.w, storageArea.h,
                        self.itemDataManager, sectionInfo)
                else
                    love.graphics.setColor(colors.red)
                    love.graphics.printf("Erro: Storage Manager não inicializado!",
                        storageArea.x + storageArea.w / 2, storageArea.y + storageArea.h / 2, 0, "center")
                    love.graphics.setColor(colors.white)
                end

                -- Desenha Grade do Loadout
                if self.loadoutManager and self.itemDataManager then
                    local loadoutItems = self.loadoutManager:getItems()
                    local loadoutRows, loadoutCols = self.loadoutManager:getDimensions()
                    ItemGridUI.drawItemGrid(loadoutItems, loadoutRows, loadoutCols,
                        loadoutArea.x, loadoutArea.y, loadoutArea.w, loadoutArea.h,
                        self.itemDataManager, nil) -- nil para sectionInfo
                else
                    love.graphics.setColor(colors.red)
                    love.graphics.printf("Erro: Loadout Manager não inicializado!",
                        loadoutArea.x + loadoutArea.w / 2, loadoutArea.y + loadoutArea.h / 2, 0, "center")
                    love.graphics.setColor(colors.white)
                end
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
                -- (Aba "Portais" é tratada acima com o mapa)
                -- (Aba "Sair"/QUIT não tem conteúdo visual próprio)
            end
        end -- Fim do if activeTab (dentro do else)
    end     -- Fim do if drawMapCondition / else

    -- Desenha o Modal de Detalhes (se um portal estiver selecionado)
    if self.selectedPortal then
        local modal = self.modalRect
        local portal = self.selectedPortal
        local modalFont = fonts.main_small or fonts.main
        local modalFontLarge = fonts.main or fonts.main

        -- Fundo do modal
        love.graphics.setColor(colors.modal_bg[1], colors.modal_bg[2], colors.modal_bg[3], 0.9)
        love.graphics.rectangle("fill", modal.x, modal.y, modal.w, modal.h)
        love.graphics.setColor(colors.modal_border)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", modal.x, modal.y, modal.w, modal.h)
        love.graphics.setLineWidth(1)

        -- Conteúdo do modal
        love.graphics.setFont(modalFontLarge)
        love.graphics.setColor(portal.color or colors.white) -- Cor do rank/nome
        love.graphics.printf(portal.name, modal.x + 10, modal.y + 15, modal.w - 20, "center")
        love.graphics.setFont(modalFont)
        love.graphics.setColor(colors.white)

        -- Informações
        local lineH = modalFont:getHeight() * 1.3 -- Espaçamento entre linhas
        local currentY = modal.y + 55
        love.graphics.printf("Rank: " .. portal.rank, modal.x + 15, currentY, modal.w - 30, "left")
        currentY = currentY + lineH
        love.graphics.printf("Tempo Restante: " .. Formatters.formatTime(portal.timer), modal.x + 15, currentY,
            modal.w - 30, "left")
        currentY = currentY + lineH * 1.5 -- Espaço maior antes da descrição

        -- Descrição Mockada
        love.graphics.printf("Bioma: Floresta Sombria", modal.x + 15, currentY, modal.w - 30, "left")
        currentY = currentY + lineH
        love.graphics.printf("Inimigos Comuns: Goblins da Noite, Lobos Espectrais", modal.x + 15, currentY, modal.w - 30,
            "left")
        currentY = currentY + lineH
        love.graphics.printf("Chefe: Rei Goblin Ancião", modal.x + 15, currentY, modal.w - 30, "left")
        currentY = currentY + lineH * 1.5

        love.graphics.printf(
            "História: Ecos de batalhas antigas ressoam nesta floresta corrompida. Dizem que o Rei Goblin detém um fragmento de poder capaz de distorcer a própria realidade. Apenas os mais bravos se atrevem a entrar...",
            modal.x + 15, currentY, modal.w - 30, "left")
        -- Adicionar mais detalhes mockados aqui...

        -- Botões do Modal (posição é calculada em load)
        local btnFont = fonts.main_small or fonts.main
        -- Botão Entrar
        elements.drawButton({
            rect = self.modalBtnEnterRect,
            text = "Entrar",
            isHovering = self.modalButtonEnterHover,
            font = btnFont,
            colors = { -- Cores podem ser customizadas
                bgColor = colors.button_primary_bg,
                hoverColor = colors.button_primary_hover,
                textColor = colors.button_primary_text,
                borderColor = colors.button_border
            }
        })
        -- Botão Cancelar
        elements.drawButton({
            rect = self.modalBtnCancelRect,
            text = "Cancelar",
            isHovering = self.modalButtonCancelHover,
            font = btnFont,
            colors = { -- Cores podem ser customizadas
                bgColor = colors.button_secondary_bg,
                hoverColor = colors.button_secondary_hover,
                textColor = colors.button_secondary_text,
                borderColor = colors.button_border
            }
        })
    end

    -- Define a fonte para os tabs
    local tabFont = fonts.main or love.graphics.getFont()

    -- Desenha cada tab por cima de tudo
    for i, tab in ipairs(tabs) do
        elements.drawTabButton({
            x = tab.x,
            y = tab.y,
            w = tab.w,
            h = tab.h,
            text = tab.text,
            isHovering = tab.isHovering,
            highlighted = (i == self.activeTabIndex), -- Destaque baseado no índice ativo
            font = tabFont,
            colors = tabSettings.colors
        })
    end

    -- Reset color e fonte final (garantia extra)
    love.graphics.setColor(colors.white)
    if fonts.main then
        love.graphics.setFont(fonts.main)
    end
end

--- Processa cliques do mouse.
-- Atualiza o tab ativo, lida com cliques no modal ou seleciona um portal.
---@param x number
---@param y number
---@param buttonIdx number
---@param istouch boolean
---@param presses number
function LobbyScene:mousepressed(x, y, buttonIdx, istouch, presses)
    if buttonIdx == 1 then -- Botão esquerdo
        -- 1. Se JÁ ESTÁ com zoom/modal ativo
        if self.isZoomedIn and self.selectedPortal then
            local modalClicked = false
            -- Verifica clique no botão Entrar
            if self.modalButtonEnterHover then
                modalClicked = true
                print(string.format(
                    "LobbyScene: Botão 'Entrar' clicado para portal '%s'. Trocando para GameLoadingScene...",
                    self.selectedPortal.name))
                -- TODO: Trocar para cena de loading <<< REMOVER TODO
                -- SceneManager.switchScene("loading_scene", { portalData = self.selectedPortal })
                -- print("-> Transição para loading (simulada)...") -- <<< REMOVER PRINT SIMULADO
                SceneManager.switchScene("game_loading_scene", { portalData = self.selectedPortal }) -- <<< CHAMADA REAL
                -- Resetar estado para voltar ao normal (não é mais necessário aqui, a cena será descarregada)
                -- self.selectedPortal = nil
                -- self.isZoomedIn = false
            elseif self.modalButtonCancelHover then
                modalClicked = true
                print("LobbyScene: Botão 'Cancelar' clicado.")
                -- Resetar estado para voltar ao normal
                self.selectedPortal = nil
                self.isZoomedIn = false
                -- Verifica clique FORA do modal (também cancela)
            else
                local m = self.modalRect
                if not (x >= m.x and x <= m.x + m.w and y >= m.y and y <= m.y + m.h) then
                    modalClicked = true -- Considera clique fora como ação no modal (cancelar)
                    print("LobbyScene: Clique fora do modal detectado, cancelando zoom.")
                    self.selectedPortal = nil
                    self.isZoomedIn = false
                end
            end
            -- Se clicou em algo relacionado ao modal, não processa mais nada
            if modalClicked then return end
        end

        -- 2. Se NÃO está com zoom/modal ativo
        -- Verifica clique nos TABS inferiores PRIMEIRO
        local tabClicked = false
        for i, tab in ipairs(tabs) do
            if tab.isHovering then -- O estado de hover é atualizado no :update
                tabClicked = true
                print(string.format("LobbyScene: Tab '%s' clicado!", tab.text))
                if tab.id == TabIds.QUIT then  -- <<< MUDANÇA AQUI
                    print("LobbyScene: Solicitando encerramento do jogo via SceneManager...")
                    SceneManager.requestQuit() -- Pede ao manager para encerrar
                else
                    self.activeTabIndex =
                        i -- Define o tab clicado como ativo
                    -- Garante que o zoom seja cancelado se mudar de tab
                    if self.isZoomedIn then
                        print("LobbyScene: Mudança de tab cancelando zoom.")
                        self.selectedPortal = nil
                        self.isZoomedIn = false
                    end
                end
                break -- Sai do loop de tabs
            end
        end
        -- Se clicou em uma tab, não processa mais nada
        if tabClicked then return end

        -- 3. Se não clicou em tab E a tab "Portais" está ativa
        local isMapActive = tabs[self.activeTabIndex] and tabs[self.activeTabIndex].id == TabIds.PORTALS
        if isMapActive then
            -- Verifica clique nos PORTAIS via Manager
            local clickedPortalData = self.portalManager:handleMouseClick(x, y)
            if clickedPortalData then
                print(string.format("LobbyScene: Portal '%s' selecionado! Ativando zoom.", clickedPortalData.name))
                -- Define o portal selecionado e ativa o modo de zoom
                self.selectedPortal = clickedPortalData
                self.isZoomedIn = true
                -- Define o alvo do pan para as coordenadas do portal no MAPA
                self.mapTargetPanX = clickedPortalData.mapX
                self.mapTargetPanY = clickedPortalData.mapY
                -- A animação de zoom/pan começará no próximo update
            end
            -- <<< NOVO: Se não clicou em tab E a tab "Equipamento" está ativa >>>
        elseif tabs[self.activeTabIndex] and tabs[self.activeTabIndex].id == TabIds.EQUIPMENT then -- <<< Já usa ID correto
            -- Verifica clique nas abas do Storage
            if self.lobbyStorageManager then
                -- Define as áreas novamente (poderia ser armazenado em self se performance for problema)
                local padding = 20
                local availableW = love.graphics.getWidth() - padding * 3
                local storageW = math.floor(availableW * 0.65)
                local screenH = love.graphics.getHeight()
                local gridH = screenH - tabSettings.height - padding * 2
                local storageArea = { x = padding, y = padding, w = storageW, h = gridH }

                local storageRows, storageCols = self.lobbyStorageManager:getActiveSectionDimensions()
                local sectionInfo = {
                    total = self.lobbyStorageManager:getTotalSections(),
                    active = self.lobbyStorageManager:getActiveSectionIndex()
                }

                local clickedTabIndex = ItemGridUI.handleMouseClick(x, y, sectionInfo,
                    storageArea.x, storageArea.y, storageArea.w, storageArea.h,
                    storageRows, storageCols)

                if clickedTabIndex then
                    self.lobbyStorageManager:setActiveSection(clickedTabIndex)
                    -- Não faz mais nada neste clique
                    return
                end
            end
            -- TODO: Verificar clique para iniciar drag-and-drop (próximo passo)
        end
    end
end

--- Chamado quando a cena é descarregada.
-- Libera a imagem do mapa da memória e limpa referência do manager.
function LobbyScene:unload()
    print("LobbyScene:unload")
    if self.mapImage then
        self.mapImage:release() -- Libera a memória da imagem
        self.mapImage = nil
    end
    -- Shader não precisa de release explícito
    self.fogShader = nil

    -- <<< NOVO: Salva os portais E o inventário ao descarregar a cena >>>
    if self.portalManager then
        self.portalManager:saveState()
    end
    if self.lobbyStorageManager then -- <<< ADICIONADO
        self.lobbyStorageManager:saveStorage()
    end
    if self.loadoutManager then -- <<< ADICIONADO
        self.loadoutManager:saveLoadout()
    end

    -- Não precisamos chamar cleanup nos managers, eles serão coletados pelo GC
    self.portalManager = nil
    self.itemDataManager = nil     -- Limpa referência <<< ADICIONADO
    self.lobbyStorageManager = nil -- Limpa referência <<< ADICIONADO
    self.loadoutManager = nil      -- Limpa referência <<< ADICIONADO
end

return LobbyScene
