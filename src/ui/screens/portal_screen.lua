local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local LobbyMapPortals = require("src.ui.components.lobby_map_portals")
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
---@field selectedPortal PortalData|nil Portal atualmente selecionado (para modal)
---@field modalRect table Retângulo do modal de portal
---@field modalBtnEnterRect table Retângulo do botão "Entrar" do modal
---@field modalBtnCancelRect table Retângulo do botão "Cancelar" do modal
---@field modalButtonEnterHover boolean Se o botão "Entrar" está em hover
---@field modalButtonCancelHover boolean Se o botão "Cancelar" está em hover
---@field targetZoomLevel number Nível de zoom para portais selecionados
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

    -- Estado da interface (modal de portais)
    instance.selectedPortal = nil
    instance.targetZoomLevel = 3.0 -- Nível de zoom para quando seleciona portais

    -- Estado do Modal
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()
    local modalW = 350
    local modalMarginX = 20
    local modalMarginY = 20
    local tabBarHeight = 50
    local modalH = screenH - (modalMarginY * 2) - tabBarHeight
    instance.modalRect = { x = screenW - modalW - modalMarginX, y = modalMarginY, w = modalW, h = modalH }
    instance.modalBtnEnterRect = { x = 0, y = 0, w = 120, h = 40 }
    instance.modalBtnCancelRect = { x = 0, y = 0, w = 120, h = 40 }
    instance.modalButtonEnterHover = false
    instance.modalButtonCancelHover = false

    -- Configs da Névoa
    instance.fogNoiseScale = 4.0
    instance.fogNoiseSpeed = 0.08
    instance.fogDensityPower = 2.5
    instance.fogBaseColor = { 0.3, 0.4, 0.6, 1.0 }

    instance:_loadAssets()
    instance:_calculateModalLayout()

    -- Configurar integração entre sistemas
    instance:_setupProceduralMapIntegration()

    -- Iniciar geração do mapa procedural
    instance.proceduralMap:generateMap()

    Logger.info("portal_screen.new", "[PortalScreen] criado com sistema de mapa procedural")

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

--- Calcula o layout dos botões do modal.
function PortalScreen:_calculateModalLayout()
    local modal = self.modalRect
    local btnW, btnH = self.modalBtnEnterRect.w, self.modalBtnEnterRect.h
    local btnPadding = 20
    self.modalBtnEnterRect.x = modal.x + (modal.w / 2) - btnW - (btnPadding / 2)
    self.modalBtnEnterRect.y = modal.y + modal.h - btnH - btnPadding
    self.modalBtnCancelRect.x = modal.x + (modal.w / 2) + (btnPadding / 2)
    self.modalBtnCancelRect.y = modal.y + modal.h - btnH - btnPadding
end

--- Atualiza a lógica da tela de portais.
---@param dt number Delta time.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param allowHover boolean Se o hover nos elementos da tela (portais, botões) é permitido.
function PortalScreen:update(dt, mx, my, allowHover)
    -- 1. Atualizar geração do mapa procedural (inclui toda lógica de câmera/zoom/pan)
    if self.proceduralMap then
        self.proceduralMap:update(dt)
    end

    -- 2. Atualizar tempo da névoa
    self.noiseTime = self.noiseTime + dt

    -- 3. Lógica do Modal (se visível)
    self.modalButtonEnterHover = false
    self.modalButtonCancelHover = false
    local modalHoverHandled = false
    if self.selectedPortal then
        -- Verifica hover nos botões do modal (só se hover geral for permitido)
        if allowHover then
            local mrE = self.modalBtnEnterRect
            local mrC = self.modalBtnCancelRect
            self.modalButtonEnterHover = (mx >= mrE.x and mx <= mrE.x + mrE.w and my >= mrE.y and my <= mrE.y + mrE.h)
            self.modalButtonCancelHover = (mx >= mrC.x and mx <= mrC.x + mrC.w and my >= mrC.y and my <= mrC.y + mrC.h)

            -- Verifica hover sobre a área do modal
            local m = self.modalRect
            if (mx >= m.x and mx <= m.x + m.w and my >= m.y and my <= m.y + m.h) or self.modalButtonEnterHover or self.modalButtonCancelHover then
                modalHoverHandled = true
            end
        end
    end

    -- 4. Atualizar Portal Manager (obtendo informações de renderização do mapa procedural)
    local allowPortalHoverInternal = allowHover and not modalHoverHandled
    if self.lobbyPortalManager and self.proceduralMap then
        local mapScale, mapDrawX, mapDrawY = self.proceduralMap:getRenderInfo()
        self.lobbyPortalManager:update(dt, mx, my, allowPortalHoverInternal, mapScale, mapDrawX, mapDrawY)
    end
end

--- Desenha a tela de portais.
---@param screenW number Largura da tela.
---@param screenH number Altura da tela.
function PortalScreen:draw(screenW, screenH)
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

    -- 4. Desenhar Modal (se portal selecionado)
    if self.selectedPortal then
        self:_drawPortalModal(screenW, screenH)
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

    -- 1. Verificar cliques nos botões do modal primeiro (prioridade)
    if self.selectedPortal then
        if self.modalButtonEnterHover then
            local portalId = self.selectedPortal.id
            local fullDefinition = portalDefinitions[portalId]


            if not fullDefinition then
                self.selectedPortal = nil -- Cancela seleção
                self.isZoomedIn = false
                return true               -- Consome clique, mas não avança
            end
            if fullDefinition then
                print("Horde Config found in definition:", fullDefinition.hordeConfig ~= nil)
                if fullDefinition.hordeConfig then
                    -- Tenta imprimir alguns campos chave para verificar estrutura
                    print("  - mvpConfig exists:", fullDefinition.hordeConfig.mvpConfig ~= nil)
                    print("  - cycles exists:", fullDefinition.hordeConfig.cycles ~= nil)
                    if fullDefinition.hordeConfig.cycles then
                        print("  - cycles count:", #fullDefinition.hordeConfig.cycles)
                        if #fullDefinition.hordeConfig.cycles > 0 then
                            print("    - cycle[1].majorSpawn exists:",
                                fullDefinition.hordeConfig.cycles[1].majorSpawn ~= nil)
                            print("    - cycle[1].minorSpawn exists:",
                                fullDefinition.hordeConfig.cycles[1].minorSpawn ~= nil)
                        end
                    end
                end
            end
            print("-------------------------------------------------")

            local hordeConfig = fullDefinition.hordeConfig
            local activeHunterId = self.hunterManager:getActiveHunterId()
            local activeHunterFinalStats = self.hunterManager:getActiveHunterFinalStats()

            if not activeHunterId then
                print("Erro: Nenhum caçador ativo selecionado.")
            elseif not hordeConfig then
                print(string.format("Erro: Portal '%s' (Definição) não possui hordeConfig definida!", portalId))
            else
                -- Inicia a cena de combate passando a hordeConfig correta
                SceneManager.switchScene("game_loading_scene", {
                    portalId = portalId,
                    hordeConfig = hordeConfig,
                    hunterId = activeHunterId,
                    hunterFinalStats = activeHunterFinalStats
                })
            end
            return true
        elseif self.modalButtonCancelHover then
            Logger.info("portal_screen.handleMousePress.cancel", "[PortalScreen] Portal desmarcado")
            local portalId = self.selectedPortal.id
            self.selectedPortal = nil
            -- Limpar estado de seleção da animação
            if self.lobbyPortalManager then
                self.lobbyPortalManager:_clearPortalSelectionState(portalId)
            end
            if self.proceduralMap then
                self.proceduralMap:zoomOut()
            end
            return true
        end
    end

    -- 2. Verificar cliques em portais (só se não há modal ou clique fora dele)
    if self.lobbyPortalManager and self.proceduralMap then
        local mapScale, mapDrawX, mapDrawY = self.proceduralMap:getRenderInfo()
        local clickedPortal = self.lobbyPortalManager:handleMouseClick(x, y, mapScale, mapDrawX, mapDrawY)

        if clickedPortal then
            Logger.info("portal_screen.handleMousePress.portal_selected",
                "[PortalScreen] Portal '" .. clickedPortal.name .. "' selecionado")

            -- Configurar estado de zoom/seleção no mapa procedural
            self.proceduralMap:zoomToPosition(clickedPortal.mapX, clickedPortal.mapY, self.targetZoomLevel)
            self.selectedPortal = clickedPortal
            return true
        end
    end

    -- 3. Clique em área vazia - desmarcar portal se houver
    if self.selectedPortal then
        Logger.info("portal_screen.handleMousePress.deselect",
            "[PortalScreen] Portal desmarcado (clique em área vazia)")
        local portalId = self.selectedPortal.id
        self.selectedPortal = nil
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

--- Desenha o modal de portal
---@param screenW number Largura da tela
---@param screenH number Altura da tela
function PortalScreen:_drawPortalModal(screenW, screenH)
    local modal = self.modalRect
    local portal = self.selectedPortal
    local modalFont = fonts.main_small or fonts.main
    local modalFontLarge = fonts.main or fonts.main

    -- Fundo
    love.graphics.setColor(colors.modal_bg[1], colors.modal_bg[2], colors.modal_bg[3], 0.9)
    love.graphics.rectangle("fill", modal.x, modal.y, modal.w, modal.h)
    love.graphics.setColor(colors.modal_border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", modal.x, modal.y, modal.w, modal.h)
    love.graphics.setLineWidth(1)

    -- Conteúdo
    love.graphics.setFont(modalFontLarge)
    love.graphics.setColor(portal.color or colors.white)
    love.graphics.printf(portal.name, modal.x + 10, modal.y + 15, modal.w - 20, "center")
    love.graphics.setFont(modalFont)
    love.graphics.setColor(colors.white)

    local lineH = modalFont:getHeight() * 1.3
    local currentY = modal.y + 55
    love.graphics.printf("Rank: " .. portal.rank, modal.x + 15, currentY, modal.w - 30, "left")
    currentY = currentY + lineH
    love.graphics.printf("Tema: " .. (portal.theme or "Desconhecido"), modal.x + 15, currentY, modal.w - 30, "left")
    currentY = currentY + lineH * 1.5

    love.graphics.printf("Bioma: Floresta Sombria", modal.x + 15, currentY, modal.w - 30, "left")
    currentY = currentY + lineH
    love.graphics.printf("Inimigos Comuns: Goblins da Noite, Lobos Espectrais", modal.x + 15, currentY, modal.w - 30,
        "left")
    currentY = currentY + lineH
    love.graphics.printf("Chefe: Rei Goblin Ancião", modal.x + 15, currentY, modal.w - 30, "left")
    currentY = currentY + lineH * 1.5

    love.graphics.printf("Recompensas:", modal.x + 15, currentY, modal.w - 30, "left")
    currentY = currentY + lineH
    love.graphics.printf("• Gold: 500-1200", modal.x + 25, currentY, modal.w - 40, "left")
    currentY = currentY + lineH
    love.graphics.printf("• EXP: 300-800", modal.x + 25, currentY, modal.w - 40, "left")
    currentY = currentY + lineH
    love.graphics.printf("• Itens Únicos: 15%", modal.x + 25, currentY, modal.w - 40, "left")
    currentY = currentY + lineH * 1.5

    -- Botões do Modal
    local enterColor = self.modalButtonEnterHover and colors.button_primary.hoverColor or colors.button_primary.bgColor
    local cancelColor = self.modalButtonCancelHover and colors.button_secondary.hoverColor or
        colors.button_secondary.bgColor

    -- Botão Entrar
    love.graphics.setColor(enterColor)
    love.graphics.rectangle("fill", self.modalBtnEnterRect.x, self.modalBtnEnterRect.y, self.modalBtnEnterRect.w,
        self.modalBtnEnterRect.h)
    love.graphics.setColor(colors.button_primary_text)
    love.graphics.setFont(modalFont)
    love.graphics.printf("Entrar", self.modalBtnEnterRect.x, self.modalBtnEnterRect.y + 10, self.modalBtnEnterRect.w,
        "center")

    -- Botão Cancelar
    love.graphics.setColor(cancelColor)
    love.graphics.rectangle("fill", self.modalBtnCancelRect.x, self.modalBtnCancelRect.y, self.modalBtnCancelRect.w,
        self.modalBtnCancelRect.h)
    love.graphics.setColor(colors.button_primary_text)
    love.graphics.printf("Cancelar", self.modalBtnCancelRect.x, self.modalBtnCancelRect.y + 10,
        self.modalBtnCancelRect.w, "center")

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
