local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")                                   -- Adiciona a dependência das fontes
local elements = require("src.ui.ui_elements")                          -- Adiciona a dependência dos elementos UI
local colors = require("src.ui.colors")                                 -- Adiciona a dependência das cores
local LobbyPortalManager = require("src.managers.lobby_portal_manager") -- <<< NOVO REQUIRE

--- Cena principal do Lobby.
-- Exibe o mapa de fundo quando "Portais" está ativo e a barra de navegação inferior.
local LobbyScene = {}

-- Estado da cena
LobbyScene.mapImage = nil ---@type love.Image|nil
LobbyScene.mapImagePath = "assets/images/map.png"
LobbyScene.fogShader = nil ---@type love.Shader|nil
LobbyScene.fogShaderPath = "assets/shaders/fog_noise.fs"
LobbyScene.noiseTime = 0 ---@type number Contador de tempo para animar o ruído
LobbyScene.activeTabIndex = 0 ---@type integer
LobbyScene.portalManager = nil ---@type LobbyPortalManager|nil Instância do gerenciador de portais

-- Configs da névoa
LobbyScene.fogNoiseScale = 4.0 ---@type number Escala do ruído (valores menores = "zoom maior")
LobbyScene.fogNoiseSpeed = 0.08 ---@type number Velocidade de movimento da névoa
LobbyScene.fogDensityPower = 2.5 ---@type number Expoente para controlar a densidade (maior = mais denso/opaco)
LobbyScene.fogBaseColor = { 0.3, 0.4, 0.6, 1.0 } ---@type table Cor base da névoa (para combinar com o filtro do mapa)

-- Configuração dos botões/tabs inferiores
local tabs = {
    { text = "Vendedor" },
    { text = "Criação" },
    { text = "Equipamento" },
    { text = "Portais" }, -- Será definido como ativo no :load
    { text = "Personagens" },
    { text = "Configurações" },
    { text = "Sair" },
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
    self.noiseTime = 0                            -- Reseta o tempo do ruído
    self.portalManager = LobbyPortalManager:new() -- <<< CRIA INSTÂNCIA

    -- Carrega a imagem do mapa
    local mapSuccess, mapErr = pcall(function()
        self.mapImage = love.graphics.newImage(self.mapImagePath)
    end)
    if not mapSuccess or not self.mapImage then
        print(string.format("Erro ao carregar imagem do mapa '%s': %s", self.mapImagePath,
            tostring(mapErr or "not found")))
        self.mapImage = nil
    else
        -- Inicializa o portal manager (passando dimensões do mapa, se carregado)
        local mapW = self.mapImage:getWidth()
        local mapH = self.mapImage:getHeight()
        self.portalManager:initialize(mapW, mapH) -- <<< INICIALIZA PORTAIS
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
        -- Define o tab "Portais" como ativo inicialmente
        if tab.text == "Portais" then
            self.activeTabIndex = i
        end
    end

    -- Garante que haja um tab ativo se "Portais" não for encontrado (fallback)
    if self.activeTabIndex == 0 and #tabs > 0 then
        self.activeTabIndex = 1
    end
    print("LobbyScene: Tab ativo inicial:", self.activeTabIndex, tabs[self.activeTabIndex].text)
end

--- Atualiza a lógica da cena (verificação de hover).
---@param dt number
function LobbyScene:update(dt)
    local mx, my = love.mouse.getPosition()
    for i, tab in ipairs(tabs) do
        tab.isHovering = (mx >= tab.x and mx <= tab.x + tab.w and my >= tab.y and my <= tab.y + tab.h)
    end

    -- Atualiza o tempo para animar o ruído do shader
    self.noiseTime = self.noiseTime + dt

    -- Atualiza o Portal Manager
    local isMapActive = tabs[self.activeTabIndex] and tabs[self.activeTabIndex].text == "Portais"
    local mapScale, mapDrawX, mapDrawY = 1, 0, 0
    if isMapActive and self.mapImage then
        -- Calcula transformação do mapa para passar ao manager
        local mapW = self.mapImage:getWidth()
        local mapH = self.mapImage:getHeight()
        mapScale = math.max(love.graphics.getWidth() / mapW, love.graphics.getHeight() / mapH)
        mapDrawX = (love.graphics.getWidth() - mapW * mapScale) / 2
        mapDrawY = (love.graphics.getHeight() - mapH * mapScale) / 2
    end
    self.portalManager:update(dt, mx, my, isMapActive, mapScale, mapDrawX, mapDrawY) -- <<< DELEGA UPDATE
end

--- Desenha os elementos da cena.
-- Desenha o mapa ou fundo padrão e a barra de tabs.
function LobbyScene:draw()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Desenha o fundo (mapa ou cor sólida)
    local activeTab = tabs[self.activeTabIndex]
    local isMapActive = activeTab and activeTab.text == "Portais" and self.mapImage
    local mapScale, mapDrawX, mapDrawY = 1, 0, 0

    if isMapActive then
        -- Desenha o mapa tingido
        local mapTint = { 0.3, 0.4, 0.6, 1.0 }
        love.graphics.setColor(mapTint)
        local mapW = self.mapImage:getWidth()
        local mapH = self.mapImage:getHeight()
        mapScale = math.max(screenW / mapW, screenH / mapH)
        mapDrawX = (screenW - mapW * mapScale) / 2
        mapDrawY = (screenH - mapH * mapScale) / 2
        love.graphics.draw(self.mapImage, mapDrawX, mapDrawY, 0, mapScale, mapScale)
        love.graphics.setColor(colors.white) -- Reseta cor após mapa

        -- Desenha a névoa com shader POR CIMA do mapa
        if self.fogShader then
            love.graphics.setShader(self.fogShader) -- Ativa o shader
            -- Envia as variáveis (uniforms) para o shader
            self.fogShader:send("time", self.noiseTime * self.fogNoiseSpeed)
            self.fogShader:send("noiseScale", self.fogNoiseScale)
            self.fogShader:send("densityPower", self.fogDensityPower)
            self.fogShader:send("fogColor",
                { self.fogBaseColor[1], self.fogBaseColor[2], self.fogBaseColor[3], self.fogBaseColor[4] })
            -- Desenha um retângulo cobrindo a tela para aplicar o shader
            love.graphics.rectangle("fill", 0, 0, screenW, screenH)
            love.graphics.setShader()        -- Desativa o shader
        end
        love.graphics.setColor(colors.white) -- Garante reset da cor

        -- Desenha os portais usando o manager
        self.portalManager:draw(mapScale, mapDrawX, mapDrawY) -- <<< DELEGA DRAW
        love.graphics.setColor(colors.white)
    else
        -- Desenha fundo padrão se não for Portais ou mapa não carregou
        love.graphics.setColor(colors.lobby_background)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(colors.white) -- Garante branco para os tabs
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
-- Atualiza o tab ativo ou executa ação específica (Sair).
---@param x number
---@param y number
---@param buttonIdx number
-- Os parâmetros istouch e presses não são usados atualmente, mas mantemos para compatibilidade com love.mousepressed
---@param istouch boolean
---@param presses number
function LobbyScene:mousepressed(x, y, buttonIdx, istouch, presses)
    if buttonIdx == 1 then
        -- Verifica clique nos TABS PRIMEIRO (eles estão por cima)
        local tabClicked = false
        for i, tab in ipairs(tabs) do
            if tab.isHovering then -- O estado de hover é atualizado no :update
                tabClicked = true
                print(string.format("LobbyScene: Tab '%s' clicado!", tab.text))
                if tab.text == "Sair" then
                    print("LobbyScene: Solicitando encerramento do jogo via SceneManager...")
                    SceneManager.requestQuit() -- <<< NOVO: Pede ao manager para encerrar
                else
                    -- Define o tab clicado como ativo
                    self.activeTabIndex = i
                    -- O portal manager lida com o hover dele no update
                end
                break
            end
        end

        -- Se NENHUM tab foi clicado E o mapa está ativo, verifica clique nos PORTAIS via Manager
        local isMapActive = tabs[self.activeTabIndex] and tabs[self.activeTabIndex].text == "Portais"
        if not tabClicked and isMapActive then
            local clickedPortalData = self.portalManager:handleMouseClick(x, y) -- <<< DELEGA CLIQUE
            if clickedPortalData then
                print("LobbyScene: Portal clicado (via manager):", clickedPortalData.name)
                -- TODO: Implementar a lógica para entrar no portal
                -- Ex: SceneManager.switchScene("game_loading_scene", { portalData = clickedPortalData })
                print("-> Entrando no portal (simulado)...")
            end
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

    -- <<< NOVO: Salva os portais ao descarregar a cena >>>
    if self.portalManager then
        self.portalManager:saveState() -- <<< NOVO
    end

    -- Não precisamos chamar cleanup no manager, ele será coletado pelo GC
    self.portalManager = nil
end

return LobbyScene
