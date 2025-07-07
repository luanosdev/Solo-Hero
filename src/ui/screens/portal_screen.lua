local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local LobbyMapPortals = require("src.ui.components.lobby_map_portals")
local PortalTitleSection = require("src.ui.components.portal_title_section")
local PortalLoadoutSection = require("src.ui.components.portal_loadout_section")
local PortalEventsSection = require("src.ui.components.portal_events_section")
local PortalActionSection = require("src.ui.components.portal_action_section")
local portalDefinitions = require("src.data.portals.portal_definitions")
local DashCooldownIndicator = require("src.ui.components.dash_cooldown_indicator")

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
---@field actionSection PortalActionSection Seção de ação/botão do portal
---@field targetZoomLevel number Nível de zoom para portais selecionados
---@field loadingAnimationTime number Tempo acumulado para animação de carregamento
---@field scannerRotation number Rotação atual do scanner radar
---@field scannerPulseTime number Tempo para pulso do scanner
---@field loadingDots string Pontos animados para texto de carregamento
---@field isTransitioning boolean Se a tela está em transição
---@field transitionTimer number Tempo de transição
---@field transitionDuration number Duração da transição
---@field transitionAlpha number Alpha da transição
---@field pendingSceneArgs table|nil Argumentos da cena de transição
---@field loadingAnimator DashCooldownIndicator Animador de animação de carregamento
---@field loadingAnimationTimer number Tempo acumulado para animação de carregamento
---@field loadingAnimationSpeed number Velocidade da animação (frames por segundo)
---@field currentLoadingFrame number Frame atual da animação de carregamento
---@field maxLoadingFrames number Máximo de frames disponíveis para animação de carregamento
local PortalScreen = {}
PortalScreen.__index = PortalScreen

-- === CONFIGURAÇÕES DE PERFORMANCE ===
local PERFORMANCE_CONFIG = {
    TIME_BUDGET_PER_FRAME = 2,          -- Voltando para 2ms (rápido)
    MAX_PROCESSING_ITERATIONS = 50,     -- Voltando para 50 (mais processamento)
    MEMORY_CLEANUP_FREQUENCY = 5,       -- Limpeza de memória a cada 5 frames
    USE_DASH_INDICATOR_ANIMATION = true -- Usar animação do DashCooldownIndicator
}

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
    instance.targetZoomLevel = 2.5  -- Zoom quando portal é selecionado
    instance.defaultZoomLevel = 1.0 -- Zoom padrão

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

    -- Criar seção de ação do portal
    instance.actionSection = PortalActionSection.new({
        animationSpeed = 12.0,
        sectionWidth = 500,
        sectionHeight = 120,
        padding = 20,
        buttonWidth = 300,
        buttonHeight = 60
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

    -- === CONFIGURAÇÕES DE TRANSIÇÃO ===
    instance.isTransitioning = false
    instance.transitionTimer = 0
    instance.transitionDuration = 1.2
    instance.transitionAlpha = 0
    instance.pendingSceneArgs = nil

    -- === ANIMAÇÃO DE LOADING ===
    instance.loadingAnimator = DashCooldownIndicator:new()
    instance.loadingAnimationTimer = 0
    instance.loadingAnimationSpeed = 0.3 -- MUITO mais lento para ser visível (era 2.0)
    instance.currentLoadingFrame = 1
    instance.maxLoadingFrames = 7        -- Usar todos os 7 frames disponíveis

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
    -- === GERENCIAR TRANSIÇÃO SUAVE ===
    if self.isTransitioning then
        self.transitionTimer = self.transitionTimer + dt
        local progress = math.min(1.0, self.transitionTimer / self.transitionDuration)

        -- Curva de transição suave (ease-in-out)
        local easeProgress = progress * progress * (3.0 - 2.0 * progress)
        self.transitionAlpha = easeProgress

        -- Quando a transição estiver quase completa, fazer a mudança de cena
        if progress >= 0.7 and self.pendingSceneArgs then
            Logger.info("portal_screen.transition_complete",
                "[PortalScreen] Transição 70% completa, mudando para game_loading_scene")
            SceneManager.switchScene("game_loading_scene", self.pendingSceneArgs)
            return
        end

        -- Se algo der errado e a transição não completar, forçar mudança
        if self.transitionTimer >= self.transitionDuration + 0.5 then
            Logger.warn("portal_screen.transition_timeout",
                "[PortalScreen] Timeout na transição, forçando mudança de cena")
            if self.pendingSceneArgs then
                SceneManager.switchScene("game_loading_scene", self.pendingSceneArgs)
            end
            return
        end
    end

    -- === ANIMAÇÕES REGULARES (continuar durante transição) ===
    -- Atualizar animações do scanner
    self.scannerRotation = self.scannerRotation + dt * 2
    self.scannerPulseTime = self.scannerPulseTime + dt
    self.loadingAnimationTime = self.loadingAnimationTime + dt

    -- Atualizar pontos de carregamento
    local dotCount = math.floor(self.loadingAnimationTime * 2) % 4
    self.loadingDots = string.rep(".", dotCount)

    -- === ATUALIZAR MAPA PROCEDURAL (se não estiver em transição) ===
    if not self.isTransitioning and self.proceduralMap then
        self.proceduralMap:update(dt)
    end

    -- 2. Atualizar tempo da névoa
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
    if self.actionSection then
        self.actionSection:update(dt, mx, my)
    end

    -- 5. Atualizar Portal Manager (obtendo informações de renderização do mapa procedural)
    local allowPortalHoverInternal = allowHover
    if self.lobbyPortalManager and self.proceduralMap then
        local mapScale, mapDrawX, mapDrawY = self.proceduralMap:getRenderInfo()
        self.lobbyPortalManager:update(dt, mx, my, allowPortalHoverInternal, mapScale, mapDrawX, mapDrawY)
    end

    -- === ANIMAÇÃO DE LOADING ===
    if not self:isMapGenerationComplete() then
        self.loadingAnimationTimer = self.loadingAnimationTimer + dt

        -- Avança para o próximo frame baseado na velocidade
        if self.loadingAnimationTimer >= (1 / self.loadingAnimationSpeed) then
            self.currentLoadingFrame = self.currentLoadingFrame + 1
            if self.currentLoadingFrame > self.maxLoadingFrames then
                self.currentLoadingFrame = 1 -- Volta ao início para loop infinito
            end
            self.loadingAnimationTimer = 0
        end
    end
end

--- Desenha a tela de portais.
---@param screenW number Largura da tela.
---@param screenH number Altura da tela.
function PortalScreen:draw(screenW, screenH)
    -- Se a geração não está completa, mostrar tela de carregamento
    if not self:isMapGenerationComplete() then
        local scanningPortal = self.selectedPortal and self.selectedPortal.name or "Área Desconhecida"
        self:_drawLoadingScreen(scanningPortal)
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
    if self.actionSection then
        self.actionSection:draw(screenW, screenH)
    end

    -- === EFEITO DE TRANSIÇÃO SUAVE ===
    if self.isTransitioning and self.transitionAlpha > 0 then
        -- Overlay de transição com gradiente
        love.graphics.setColor(0.08, 0.12, 0.18, self.transitionAlpha)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        -- Efeito de scanner de transição
        if self.transitionAlpha > 0.3 then
            local centerX, centerY = screenW / 2, screenH / 2
            local scanRadius = (self.transitionAlpha - 0.3) * 600

            -- Pulso de energia da transição
            love.graphics.setColor(0.3, 0.7, 1.0, (self.transitionAlpha - 0.3) * 2)
            love.graphics.circle("line", centerX, centerY, scanRadius)
            love.graphics.circle("line", centerX, centerY, scanRadius * 0.7)

            -- Texto de transição
            if self.transitionAlpha > 0.5 then
                love.graphics.setColor(1, 1, 1, (self.transitionAlpha - 0.5) * 2)
                local transitionFont = fonts.main_large or fonts.main or love.graphics.getFont()
                love.graphics.setFont(transitionFont)
                love.graphics.printf("ABRINDO PORTAL...", 0, centerY - 20, screenW, "center")

                -- Subtexto temático
                love.graphics.setColor(0.8, 0.9, 1.0, (self.transitionAlpha - 0.5) * 1.5)
                local detailFont = fonts.main or fonts.main_small or love.graphics.getFont()
                love.graphics.setFont(detailFont)
                if self.pendingSceneArgs then
                    local portalText = string.format("Conectando à %s",
                        self.pendingSceneArgs.portalId or "zona desconhecida")
                    love.graphics.printf(portalText, 0, centerY + 20, screenW, "center")
                end
            end
        end
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

    -- 1. Verificar clique no botão de ação
    if self.actionSection and self.actionSection:isButtonClicked(x, y) then
        local portalData = self.actionSection:getPortalData()
        Logger.info(
            "portal_screen.handleMousePress.action_button",
            "[PortalScreen] Botão 'Entrar no Portal' clicado - " ..
            portalData.name .. " (Rank " .. portalData.rank .. ")"
        )

        -- Implementar lógica para iniciar o portal/mapa
        if self.selectedPortal and self.hunterManager then
            local hunterId = self.hunterManager:getActiveHunterId()
            local portalId = self.selectedPortal.id

            if hunterId and portalId then
                -- Verificar se o portal existe em portalDefinitions
                local portalDefinition = portalDefinitions[portalId]
                if portalDefinition then
                    local sceneArgs = {
                        portalId = portalId,
                        hunterId = hunterId,
                        hordeConfig = portalDefinition.hordeConfig -- Opcional, será usado o do portal se não fornecido
                    }

                    Logger.info(
                        "portal_screen.handleMousePress.start_mission",
                        string.format(
                            "[PortalScreen] Iniciando missão - Portal: %s, Hunter: %s",
                            portalId, hunterId
                        )
                    )

                    -- Iniciar transição suave ao invés de mudança direta
                    self:_startTransition(sceneArgs)
                else
                    Logger.warn(
                        "portal_screen.handleMousePress.invalid_portal",
                        "[PortalScreen] Portal ID '" .. portalId .. "' não encontrado em portalDefinitions"
                    )
                end
            else
                Logger.warn(
                    "portal_screen.handleMousePress.missing_data",
                    "[PortalScreen] Dados incompletos - hunterId: " ..
                    tostring(hunterId) .. ", portalId: " .. tostring(portalId)
                )
            end
        else
            Logger.warn(
                "portal_screen.handleMousePress.no_selection",
                "[PortalScreen] Nenhum portal selecionado ou hunterManager indisponível"
            )
        end

        return true
    end

    -- 2. Verificar cliques em portais
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

            -- Atualizar e exibir seção de ação
            if self.actionSection then
                self.actionSection:updatePortalData(clickedPortal.name, clickedPortal.rank)
                self.actionSection:show()
            end

            return true
        end
    end

    -- 3. Clique em área vazia - desmarcar portal se houver
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
        if self.actionSection then
            self.actionSection:hide()
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

--- Desenha a tela de loading durante a geração de portais.
---@param portalName string Nome do portal sendo processado
function PortalScreen:_drawLoadingScreen(portalName)
    local w = ResolutionUtils.getGameWidth()
    local h = ResolutionUtils.getGameHeight()

    -- Fundo temático escuro
    love.graphics.setColor(0.08, 0.1, 0.14, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- === ANIMAÇÃO DE LOADING COM DASH_COOLDOWN_INDICATOR ===
    local centerX, centerY = w / 2, h / 2 - 100

    -- Desenha apenas o indicador central - SEM elementos extras
    if self.loadingAnimator and self.loadingAnimator.quads then
        local quad = self.loadingAnimator.quads[self.currentLoadingFrame]
        if quad then
            -- Escala média para ser bem visível
            local scale = 0.6

            -- Desenha com cor temática azul simples
            love.graphics.setColor(0.3, 0.7, 1.0, 1.0)
            love.graphics.draw(
                self.loadingAnimator.image,
                quad,
                centerX - (self.loadingAnimator.frameWidth * scale) / 2,
                centerY - (self.loadingAnimator.frameHeight * scale) / 2,
                0,
                scale,
                scale
            )
        end
    end

    -- === TEXTOS PRINCIPAIS ===
    local textCenterX = w / 2
    local titleY = h / 2 - 200

    -- Título principal
    love.graphics.setColor(1, 1, 1, 1)
    local titleFont = fonts.title_large or fonts.title or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    love.graphics.printf("ESCANEANDO ZONA", 0, titleY, w, "center")

    -- Estado atual do scan
    if self.currentGenerationState then
        local stateConfig = self.SCAN_STATE_CONFIG[self.currentGenerationState]
        if stateConfig then
            -- Título do estado
            love.graphics.setColor(0.8, 0.9, 1.0, 1)
            local mainFont = fonts.main_large or fonts.main or love.graphics.getFont()
            love.graphics.setFont(mainFont)
            love.graphics.printf(stateConfig.title, 0, titleY + 60, w, "center")

            -- Descrição
            love.graphics.setColor(0.6, 0.7, 0.9, 1)
            local detailFont = fonts.main or fonts.main_small or love.graphics.getFont()
            love.graphics.setFont(detailFont)
            love.graphics.printf(stateConfig.description, 0, titleY + 95, w, "center")
        end
    end

    -- Nome do portal
    love.graphics.setColor(0.7, 0.8, 0.9, 0.9)
    love.graphics.setFont(fonts.main or love.graphics.getFont())
    local portalText = string.format("Alvo: %s", portalName or "Zona Desconhecida")
    love.graphics.printf(portalText, 0, h / 2 + 60, w, "center")

    -- === BARRA DE PROGRESSO SIMPLIFICADA ===
    local barW = 400
    local barH = 6
    local barX = textCenterX - barW / 2
    local barY = h / 2 + 100

    -- Fundo da barra
    love.graphics.setColor(0.2, 0.25, 0.3, 0.8)
    love.graphics.rectangle("fill", barX, barY, barW, barH)

    -- Progresso real
    local progress = 0
    if self.stateProgress then
        progress = self.stateProgress / 100
    end

    love.graphics.setColor(0.3, 0.7, 1.0, 0.8)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH)

    -- **BRILHO MÍNIMO** (sem cálculos complexos)
    if progress > 0 then
        love.graphics.setColor(0.5, 0.8, 1.0, 0.3)
        love.graphics.rectangle("fill", barX + (barW * progress) - 8, barY, 8, barH)
    end

    -- Borda
    love.graphics.setColor(0.4, 0.5, 0.6, 1)
    love.graphics.rectangle("line", barX, barY, barW, barH)

    -- Percentual
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.setFont(fonts.main_small or love.graphics.getFont())
    local percentText = string.format("%d%% COMPLETO", math.floor(progress * 100))
    love.graphics.printf(percentText, 0, barY + 20, w, "center")

    -- === ELEMENTOS MINIMALISTAS ===
    -- **APENAS 2 CANTOS** (ao invés de 8 linhas)
    love.graphics.setColor(0.3, 0.6, 0.9, 0.4)
    love.graphics.setLineWidth(2)

    love.graphics.line(25, 25, 50, 25)
    love.graphics.line(25, 25, 25, 50)

    -- Status
    love.graphics.setColor(0.4, 0.6, 0.8, 0.6)
    love.graphics.setFont(fonts.debug or fonts.main_small or love.graphics.getFont())
    love.graphics.printf("SISTEMA DE RECONHECIMENTO ATIVO", 0, 30, w, "center")

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
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

--- Inicia transição suave para a tela de loading
---@param sceneArgs table Argumentos para a próxima cena
function PortalScreen:_startTransition(sceneArgs)
    if self.isTransitioning then
        return -- Já está em transição
    end

    self.isTransitioning = true
    self.transitionTimer = 0
    self.transitionAlpha = 0
    self.pendingSceneArgs = sceneArgs

    Logger.info("portal_screen.transition_start",
        "[PortalScreen] Iniciando transição suave para portal: " .. (sceneArgs.portalId or "desconhecido"))
end

return PortalScreen
