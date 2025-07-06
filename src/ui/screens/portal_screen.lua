local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local LobbyMapPortals = require("src.ui.components.lobby_map_portals")
local PortalTitleSection = require("src.ui.components.portal_title_section")
local PortalLoadoutSection = require("src.ui.components.portal_loadout_section")
local PortalEventsSection = require("src.ui.components.portal_events_section")
local portalDefinitions = require("src.data.portals.portal_definitions")

--- Módulo para gerenciar a tela de Portais no Lobby.
---@class PortalScreen
---@field lobbyPortalManager LobbyPortalManager
---@field hunterManager HunterManager
---@field proceduralMap LobbyMapPortals Sistema de mapa procedural (responsável por toda lógica de câmera/zoom/pan)
---@field mapImage love.Image|nil (DEPRECIADO - mantido para compatibilidade)
---@field mapImagePath string (DEPRECIADO)
---@field mapOriginalWidth number Largura virtual do mapa
---@field mapOriginalHeight number Altura virtual do mapa
---@field fogShader love.Shader|nil Shader de névoa para o mapa
---@field fogShaderPath string Caminho para o shader de névoa
---@field noiseTime number Tempo acumulado para animação da névoa
---@field selectedPortal PortalData|nil Portal atualmente selecionado
---@field titleSection PortalTitleSection Seção do título do portal
---@field loadoutSection PortalLoadoutSection Seção de loadout/informações do portal
---@field eventsSection PortalEventsSection Seção de eventos aleatórios do portal
---@field targetZoomLevel number Nível de zoom para portais selecionados
---@field loadingAnimationTime number Tempo acumulado para animação de carregamento
---@field scannerRotation number Rotação atual do scanner radar
---@field scannerPulseTime number Tempo para pulso do scanner
---@field loadingDots string Pontos animados para texto de carregamento
local PortalScreen = {}
PortalScreen.__index = PortalScreen

--- Cria uma nova instância de PortalScreen.
---@param lobbyPortalManager LobbyPortalManager Gerenciador de portais do lobby.
---@param hunterManager HunterManager Gerenciador de hunters.
---@return PortalScreen instance Nova instância do PortalScreen.
function PortalScreen:new(lobbyPortalManager, hunterManager)
    local instance = setmetatable({}, PortalScreen)

    instance.lobbyPortalManager = lobbyPortalManager
    instance.hunterManager = hunterManager

    -- Sistema de Mapa Procedural
    instance.proceduralMap = LobbyMapPortals:new()

    -- Expor globalmente para testes/debug (console)
    _G.PortalMapComponent = instance.proceduralMap
    _G.LobbyPortalManager = instance.lobbyPortalManager

    -- Estado do Mapa (DEPRECIADOS - mantidos para compatibilidade)
    instance.mapImage = nil
    instance.mapImagePath = "assets/images/map.png"
    instance.mapOriginalWidth, instance.mapOriginalHeight = instance.proceduralMap:getMapDimensions()

    -- Shader e efeitos visuais
    instance.fogShader = nil
    instance.fogShaderPath = "assets/shaders/fog_noise.fs"
    instance.noiseTime = 0

    -- Estado da interface
    instance.selectedPortal = nil
    instance.targetZoomLevel = 3.0 -- Nível de zoom para quando seleciona portais

    -- Criar seção do título do portal
    instance.titleSection = PortalTitleSection.new({
        portalName = "Portal Desconhecido",
        portalRank = "E",
        targetY = 120,
        animationSpeed = 8.0,
        shadowOffset = 4
    })

    -- Criar seção de loadout do portal
    instance.loadoutSection = PortalLoadoutSection.new({
        animationSpeed = 10.0,
        sectionWidth = 400,
        sectionHeight = 600,
        padding = 20
    })

    -- Criar seção de eventos aleatórios do portal
    instance.eventsSection = PortalEventsSection.new({
        animationSpeed = 10.0,
        sectionWidth = 400,
        sectionHeight = 600,
        padding = 20
    })

    -- Configs da Névoa
    instance.fogNoiseScale = 4.0
    instance.fogNoiseSpeed = 0.08
    instance.fogDensityPower = 2.5
    instance.fogBaseColor = { 0.3, 0.4, 0.6, 1.0 }

    -- Configs da Tela de Carregamento
    instance.loadingAnimationTime = 0
    instance.scannerRotation = 0
    instance.scannerPulseTime = 0
    instance.loadingDots = ""

    instance:_loadAssets()

    -- Configurar integração entre sistemas
    instance:_setupProceduralMapIntegration()

    -- Iniciar geração do mapa procedural
    instance.proceduralMap:generateMap()

    Logger.info("portal_screen.new", "[PortalScreen] criado com sistema de mapa procedural e tela de carregamento")

    return instance
end

--- Configura a integração entre o mapa procedural e o sistema de portais
function PortalScreen:_setupProceduralMapIntegration()
    -- Conectar o lobby portal manager com o mapa procedural
    if self.lobbyPortalManager then
        self.lobbyPortalManager:setProceduralMap(self.proceduralMap)
        Logger.info("portal_screen._setupProceduralMapIntegration",
            "[PortalScreen] Integração entre sistemas configurada")
    end

    Logger.info("portal_screen._setupProceduralMapIntegration",
        "[PortalScreen] Controle total da câmera delegado ao LobbyMapPortals")
end

--- Carrega os assets (shader de névoa).
function PortalScreen:_loadAssets()
    -- Carrega o shader de névoa
    local shaderSuccess, shaderErr = pcall(function()
        self.fogShader = love.graphics.newShader(self.fogShaderPath)
    end)
    if not shaderSuccess or not self.fogShader then
        Logger.warn("portal_screen._loadAssets.shader",
            "[PortalScreen] Erro ao carregar shader de névoa '" ..
            self.fogShaderPath .. "': " .. tostring(shaderErr or "error"))
        self.fogShader = nil
    else
        Logger.info("portal_screen._loadAssets.shader", "[PortalScreen] Shader de névoa carregado")
    end
end

--- Atualiza a lógica da tela de portais.
---@param dt number Delta time.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param allowHover boolean Se o hover nos elementos da tela (portais, botões) é permitido.
function PortalScreen:update(dt, mx, my, allowHover)
    -- 1. Atualizar geração do mapa procedural (inclui toda lógica de câmera/zoom/pan)
    if self.proceduralMap then
        local wasGenerating = not self.proceduralMap:isGenerationComplete()
        self.proceduralMap:update(dt)

        -- Log quando geração completa
        if wasGenerating and self.proceduralMap:isGenerationComplete() then
            Logger.info("portal_screen.update.generation_complete",
                "[PortalScreen] Geração do mapa e portais concluída - área de operação pronta")
        end
    end

    -- 2. Atualizar animações da tela de carregamento
    self.loadingAnimationTime = self.loadingAnimationTime + dt
    self.scannerRotation = self.scannerRotation + dt * 2 -- Rotação do scanner
    self.scannerPulseTime = self.scannerPulseTime + dt

    -- Atualizar pontos animados para texto de carregamento
    local dotCycle = math.floor(self.loadingAnimationTime * 2) % 4
    if dotCycle == 0 then
        self.loadingDots = ""
    elseif dotCycle == 1 then
        self.loadingDots = "."
    elseif dotCycle == 2 then
        self.loadingDots = ".."
    else
        self.loadingDots = "..."
    end

    -- 3. Atualizar tempo da névoa
    self.noiseTime = self.noiseTime + dt

    -- Se a geração não está completa, não processar lógica de interação
    if not self:isMapGenerationComplete() then
        return
    end

    -- 4. Atualizar seções dos portais
    if self.titleSection then
        self.titleSection:update(dt)
    end
    if self.loadoutSection then
        self.loadoutSection:update(dt)
    end
    if self.eventsSection then
        self.eventsSection:update(dt)
    end

    -- 5. Atualizar Portal Manager (obtendo informações de renderização do mapa procedural)
    local allowPortalHoverInternal = allowHover
    if self.lobbyPortalManager and self.proceduralMap then
        local mapScale, mapDrawX, mapDrawY = self.proceduralMap:getRenderInfo()
        self.lobbyPortalManager:update(dt, mx, my, allowPortalHoverInternal, mapScale, mapDrawX, mapDrawY)
    end
end

--- Desenha a tela de portais.
---@param screenW number Largura da tela.
---@param screenH number Altura da tela.
function PortalScreen:draw(screenW, screenH)
    -- Se a geração não está completa, mostrar tela de carregamento
    if not self:isMapGenerationComplete() then
        self:_drawLoadingScreen(screenW, screenH)
        return
    end

    -- 1. Desenhar Mapa Procedural (inclui toda lógica de rendering e câmera)
    if self.proceduralMap then
        self.proceduralMap:draw(screenW, screenH)
    else
        -- Fallback: Desenha fundo sólido se mapa procedural falhou
        love.graphics.setColor(colors.lobby_background)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(colors.white)
    end

    -- 2. Desenhar Névoa (se tiver shader)
    if self.fogShader and self.proceduralMap then
        local mapScale, _, _ = self.proceduralMap:getRenderInfo()
        love.graphics.setShader(self.fogShader)
        self.fogShader:send("time", self.noiseTime * self.fogNoiseSpeed)
        self.fogShader:send("noiseScale", self.fogNoiseScale / mapScale)
        self.fogShader:send("densityPower", self.fogDensityPower)
        self.fogShader:send("fogColor", self.fogBaseColor)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setShader()
    end
    love.graphics.setColor(colors.white)

    -- 3. Desenhar Portais (via manager, obtendo informações de renderização do mapa)
    if self.lobbyPortalManager and self.proceduralMap then
        local mapScale, mapDrawX, mapDrawY = self.proceduralMap:getRenderInfo()
        self.lobbyPortalManager:draw(mapScale, mapDrawX, mapDrawY, self.selectedPortal)
    end
    love.graphics.setColor(colors.white)

    -- 4. Desenhar seções dos portais
    if self.titleSection then
        self.titleSection:draw(screenW, screenH)
    end
    if self.loadoutSection then
        self.loadoutSection:draw(screenW, screenH)
    end
    if self.eventsSection then
        self.eventsSection:draw(screenW, screenH)
    end
end

--- Verifica se a geração do mapa está completa
---@return boolean isComplete Se a geração está completa
function PortalScreen:isMapGenerationComplete()
    return self.proceduralMap and self.proceduralMap:isGenerationComplete() or false
end

--- Obtém referência do mapa procedural
---@return LobbyMapPortals|nil proceduralMap Referência do mapa procedural
function PortalScreen:getProceduralMap()
    return self.proceduralMap
end

--- Handles mouse press events for portal selection and modal buttons.
---@param x number Mouse X position.
---@param y number Mouse Y position.
---@param button number Mouse button pressed (1 = left click).
---@param istouch? boolean Whether this was a touch event.
---@return boolean Whether the event was handled.
function PortalScreen:handleMousePress(x, y, button, istouch)
    if button ~= 1 then return false end -- Só processar clique esquerdo

    -- Se a geração não está completa, não processar cliques
    if not self:isMapGenerationComplete() then
        return false
    end

    -- 1. Verificar cliques em portais
    if self.lobbyPortalManager and self.proceduralMap then
        local mapScale, mapDrawX, mapDrawY = self.proceduralMap:getRenderInfo()
        local clickedPortal = self.lobbyPortalManager:handleMouseClick(x, y, mapScale, mapDrawX, mapDrawY)

        if clickedPortal then
            Logger.info("portal_screen.handleMousePress.portal_selected",
                "[PortalScreen] Portal '" .. clickedPortal.name .. "' selecionado")

            -- Configurar estado de zoom/seleção no mapa procedural
            self.proceduralMap:zoomToPosition(clickedPortal.mapX, clickedPortal.mapY, self.targetZoomLevel)
            self.selectedPortal = clickedPortal

            -- Atualizar e exibir seções dos portais
            if self.titleSection then
                self.titleSection:updatePortalInfo(clickedPortal.name, clickedPortal.rank)
                self.titleSection:show()
            end

            -- Atualizar e exibir seção de loadout
            if self.loadoutSection then
                local portalDefinition = portalDefinitions[clickedPortal.id]
                if portalDefinition then
                    self.loadoutSection:updatePortalData(portalDefinition)
                    self.loadoutSection:show()
                else
                    Logger.warn(
                        "portal_screen.handleMousePress",
                        "[PortalScreen] Definição não encontrada para portal: " .. clickedPortal.id
                    )
                end
            end

            -- Atualizar e exibir seção de eventos
            if self.eventsSection then
                local portalDefinition = portalDefinitions[clickedPortal.id]
                if portalDefinition then
                    self.eventsSection:updatePortalData(portalDefinition.name, portalDefinition.map)
                    self.eventsSection:show()
                else
                    Logger.warn(
                        "portal_screen.handleMousePress",
                        "[PortalScreen] Definição não encontrada para portal de eventos: " .. clickedPortal.id
                    )
                end
            end

            return true
        end
    end

    -- 2. Clique em área vazia - desmarcar portal se houver
    if self.selectedPortal then
        Logger.info("portal_screen.handleMousePress.deselect",
            "[PortalScreen] Portal desmarcado (clique em área vazia)")
        local portalId = self.selectedPortal.id
        self.selectedPortal = nil

        -- Ocultar seções dos portais
        if self.titleSection then
            self.titleSection:hide()
        end
        if self.loadoutSection then
            self.loadoutSection:hide()
        end
        if self.eventsSection then
            self.eventsSection:hide()
        end

        -- Limpar estado de seleção da animação
        if self.lobbyPortalManager then
            self.lobbyPortalManager:_clearPortalSelectionState(portalId)
        end
        if self.proceduralMap then
            self.proceduralMap:zoomOut()
        end
        return true
    end

    return false
end

--- Desenha a tela de carregamento com animação de scanner
---@param screenW number Largura da tela
---@param screenH number Altura da tela
function PortalScreen:_drawLoadingScreen(screenW, screenH)
    -- Fundo escuro temático
    love.graphics.setColor(0.05, 0.08, 0.12, 1.0)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Gradiente radial sutil do centro
    local centerX, centerY = screenW / 2, screenH / 2

    -- Desenhar círculos concêntricos para efeito de radar
    love.graphics.setColor(0.1, 0.3, 0.5, 0.3)
    for i = 1, 5 do
        local radius = 50 + i * 80
        local alpha = 0.3 - (i * 0.05)
        love.graphics.setColor(0.1, 0.3, 0.5, alpha)
        love.graphics.circle("line", centerX, centerY, radius)
    end

    -- Scanner rotativo
    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(self.scannerRotation)

    -- Linha do scanner
    love.graphics.setColor(0.2, 0.8, 1.0, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.line(0, 0, 250, 0)

    -- Cauda do scanner (gradiente)
    for i = 1, 10 do
        local angle = -i * 0.1
        local alpha = 0.8 - (i * 0.08)
        love.graphics.setColor(0.2, 0.8, 1.0, alpha)
        love.graphics.push()
        love.graphics.rotate(angle)
        love.graphics.line(0, 0, 250 - i * 10, 0)
        love.graphics.pop()
    end

    love.graphics.setLineWidth(1)
    love.graphics.pop()

    -- Efeito de pulso no centro
    local pulseAlpha = 0.5 + math.sin(self.scannerPulseTime * 3) * 0.3
    love.graphics.setColor(0.3, 0.9, 1.0, pulseAlpha)
    love.graphics.circle("fill", centerX, centerY, 8)

    -- Pontos de interesse simulados (portais sendo detectados)
    love.graphics.setColor(0.9, 0.5, 0.1, 0.7)
    for i = 1, 8 do
        local angle = i * (math.pi * 2 / 8) + self.loadingAnimationTime * 0.5
        local distance = 120 + math.sin(self.loadingAnimationTime * 2 + i) * 20
        local x = centerX + math.cos(angle) * distance
        local y = centerY + math.sin(angle) * distance

        local blinkAlpha = 0.7 + math.sin(self.loadingAnimationTime * 4 + i) * 0.3
        love.graphics.setColor(0.9, 0.5, 0.1, blinkAlpha)
        love.graphics.circle("fill", x, y, 4)

        -- Pequeno anel ao redor dos pontos
        love.graphics.setColor(0.9, 0.7, 0.3, blinkAlpha * 0.5)
        love.graphics.circle("line", x, y, 8)
    end

    -- Texto principal
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main_large or fonts.main)
    local mainText = "ESCANEANDO ÁREA DE OPERAÇÃO"
    love.graphics.printf(mainText, 0, centerY - 150, screenW, "center")

    -- Texto secundário com pontos animados
    love.graphics.setFont(fonts.main or fonts.main_small)
    local subText = "Detectando portais disponíveis" .. self.loadingDots
    love.graphics.printf(subText, 0, centerY - 110, screenW, "center")

    -- Indicador de progresso temático
    love.graphics.setColor(0.2, 0.8, 1.0, 0.6)
    local progressText = "AGÊNCIA SHADOW MONARCH - SISTEMA DE RECONHECIMENTO"
    love.graphics.printf(progressText, 0, centerY + 180, screenW, "center")

    -- Efeitos de canto (HUD futurístico)
    love.graphics.setColor(0.2, 0.8, 1.0, 0.4)
    love.graphics.setLineWidth(2)

    -- Cantos superiores
    love.graphics.line(20, 20, 60, 20)
    love.graphics.line(20, 20, 20, 60)
    love.graphics.line(screenW - 20, 20, screenW - 60, 20)
    love.graphics.line(screenW - 20, 20, screenW - 20, 60)

    -- Cantos inferiores
    love.graphics.line(20, screenH - 20, 60, screenH - 20)
    love.graphics.line(20, screenH - 20, 20, screenH - 60)
    love.graphics.line(screenW - 20, screenH - 20, screenW - 60, screenH - 20)
    love.graphics.line(screenW - 20, screenH - 20, screenW - 20, screenH - 60)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(colors.white)
end

--- Descarrega a tela de portais.
function PortalScreen:unload()
    Logger.info("portal_screen.unload", "[PortalScreen] Descarregando tela de portais")

    -- Limpar referências globais
    _G.PortalMapComponent = nil
    _G.LobbyPortalManager = nil

    self.proceduralMap = nil
    self.mapImage = nil
    self.mapImagePath = nil
end

return PortalScreen
