local SceneManager = require("src.core.scene_manager")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local Formatters = require("src.utils.formatters")

--- Módulo para gerenciar a tela de Portais no Lobby.
---@class PortalScreen
---@field portalManager LobbyPortalManager
---@field hunterManager HunterManager
---@field mapImage love.Image|nil
---@field mapImagePath string
---@field mapOriginalWidth number
---@field mapOriginalHeight number
---@field fogShader love.Shader|nil
---@field fogShaderPath string
---@field noiseTime number
---@field selectedPortal PortalData|nil
---@field isZoomedIn boolean
---@field mapTargetZoom number
---@field mapCurrentZoom number
---@field mapTargetPanX number
---@field mapTargetPanY number
---@field mapCurrentPanX number
---@field mapCurrentPanY number
---@field zoomSmoothFactor number

local PortalScreen = {}
PortalScreen.__index = PortalScreen

--- Cria uma nova instância da tela de Portais.
---@param portalManager LobbyPortalManager
---@param hunterManager HunterManager -- Necessário para obter stats ao entrar no portal
---@return PortalScreen
function PortalScreen:new(portalManager, hunterManager)
    local instance = setmetatable({}, PortalScreen)
    instance.portalManager = portalManager
    instance.hunterManager = hunterManager

    -- Estado de Mapa/Zoom/Pan
    instance.mapImage = nil ---@type love.Image|nil
    instance.mapImagePath = "assets/images/map.png"
    instance.mapOriginalWidth = 0
    instance.mapOriginalHeight = 0
    instance.fogShader = nil ---@type love.Shader|nil
    instance.fogShaderPath = "assets/shaders/fog_noise.fs" ---@type string
    instance.noiseTime = 0
    instance.selectedPortal = nil ---@type PortalData|nil
    instance.isZoomedIn = false
    instance.mapTargetZoom = 3.0
    instance.mapCurrentZoom = 1.0
    instance.mapTargetPanX = 0
    instance.mapTargetPanY = 0
    instance.mapCurrentPanX = 0
    instance.mapCurrentPanY = 0
    instance.zoomSmoothFactor = 5.0

    -- Estado do Modal
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local modalW = 350
    local modalMarginX = 20
    local modalMarginY = 20
    local tabBarHeight = 50 -- TODO: Obter de tabSettings passado?
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

    return instance
end

--- Carrega os assets (imagem do mapa, shader).
function PortalScreen:_loadAssets()
    -- Carrega a imagem do mapa
    local mapSuccess, mapErr = pcall(function()
        self.mapImage = love.graphics.newImage(self.mapImagePath)
    end)
    if not mapSuccess or not self.mapImage then
        print(string.format("Erro (PortalScreen) ao carregar imagem do mapa '%s': %s", self.mapImagePath,
            tostring(mapErr or "not found")))
        self.mapImage = nil
        self.mapOriginalWidth = 0
        self.mapOriginalHeight = 0
    else
        self.mapOriginalWidth = self.mapImage:getWidth()
        self.mapOriginalHeight = self.mapImage:getHeight()
        self.mapTargetPanX = self.mapOriginalWidth / 2
        self.mapTargetPanY = self.mapOriginalHeight / 2
        self.mapCurrentPanX = self.mapTargetPanX
        self.mapCurrentPanY = self.mapTargetPanY
        -- A inicialização do portalManager é feita na LobbyScene, pois depende das dimensões carregadas aqui.
        if self.portalManager then
            -- Chamamos initialize aqui também para garantir que o manager tenha as dimensões?
            -- Ou garantimos que load da cena chame initialize DEPOIS de criar PortalScreen?
            -- Por ora, a cena chama initialize após criar a tela.
            print("(PortalScreen) Dimensões do mapa carregadas: ", self.mapOriginalWidth, self.mapOriginalHeight)
        end
    end

    -- Carrega o shader de névoa
    local shaderSuccess, shaderErr = pcall(function()
        self.fogShader = love.graphics.newShader(self.fogShaderPath)
    end)
    if not shaderSuccess or not self.fogShader then
        print(string.format("Erro (PortalScreen) ao carregar shader de névoa '%s': %s", self.fogShaderPath,
            tostring(shaderErr or "error")))
        self.fogShader = nil
    else
        print("(PortalScreen) Shader de névoa carregado.")
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

--- Função auxiliar para interpolação linear (Lerp)
local function lerp(a, b, t)
    return a + (b - a) * t
end

--- Atualiza a lógica da tela de portais.
---@param dt number Delta time.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param allowHover boolean Se o hover nos elementos da tela (portais, botões) é permitido.
function PortalScreen:update(dt, mx, my, allowHover)
    -- 1. Animação de Zoom e Pan
    local targetZoom = self.isZoomedIn and self.mapTargetZoom or 1.0
    local targetPanX = self.isZoomedIn and self.mapTargetPanX or (self.mapOriginalWidth / 2)
    local targetPanY = self.isZoomedIn and self.mapTargetPanY or (self.mapOriginalHeight / 2)
    local factor = math.min(1, dt * self.zoomSmoothFactor)

    self.mapCurrentZoom = lerp(self.mapCurrentZoom, targetZoom, factor)
    self.mapCurrentPanX = lerp(self.mapCurrentPanX, targetPanX, factor)
    self.mapCurrentPanY = lerp(self.mapCurrentPanY, targetPanY, factor)

    -- 2. Atualiza tempo da névoa
    self.noiseTime = self.noiseTime + dt

    -- 3. Lógica do Modal (se visível)
    self.modalButtonEnterHover = false
    self.modalButtonCancelHover = false
    local modalHoverHandled = false
    if self.selectedPortal then
        self.selectedPortal.timer = self.selectedPortal.timer - dt

        if self.selectedPortal.timer <= 0 then
            print(string.format("(PortalScreen) Portal selecionado '%s' expirou!", self.selectedPortal.name))
            self.selectedPortal.timer = 0
            self.selectedPortal = nil
            self.isZoomedIn = false
            return -- Sai do update
        end

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

    -- 4. Atualiza o Portal Manager
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local currentMapScale = self.mapCurrentZoom
    local currentMapDrawX = screenW / 2 - self.mapCurrentPanX * currentMapScale
    local currentMapDrawY = screenH / 2 - self.mapCurrentPanY * currentMapScale

    -- Hover nos portais só é permitido se hover geral permitido E não houver modal ativo/hover
    local allowPortalHoverInternal = allowHover and not modalHoverHandled
    if self.portalManager then
        self.portalManager:update(dt, mx, my, allowPortalHoverInternal, currentMapScale, currentMapDrawX, currentMapDrawY)
    end
end

--- Desenha a tela de portais.
---@param screenW number Largura da tela.
---@param screenH number Altura da tela.
function PortalScreen:draw(screenW, screenH)
    -- Calcula transformação atual (baseado nos valores interpolados)
    local currentMapScale = self.mapCurrentZoom
    local currentMapDrawX = screenW / 2 - self.mapCurrentPanX * currentMapScale
    local currentMapDrawY = screenH / 2 - self.mapCurrentPanY * currentMapScale

    -- 1. Desenha Mapa (se tiver imagem)
    if self.mapImage then
        love.graphics.setColor(colors.map_tint)
        love.graphics.draw(self.mapImage, currentMapDrawX, currentMapDrawY, 0, currentMapScale, currentMapScale)
        love.graphics.setColor(colors.white)

        -- 2. Desenha Névoa (se tiver shader)
        if self.fogShader then
            love.graphics.setShader(self.fogShader)
            self.fogShader:send("time", self.noiseTime * self.fogNoiseSpeed)
            self.fogShader:send("noiseScale", self.fogNoiseScale / self.mapCurrentZoom)
            self.fogShader:send("densityPower", self.fogDensityPower)
            self.fogShader:send("fogColor", self.fogBaseColor)
            love.graphics.rectangle("fill", 0, 0, screenW, screenH)
            love.graphics.setShader()
        end
        love.graphics.setColor(colors.white)

        -- 3. Desenha Portais (via manager)
        if self.portalManager then
            self.portalManager:draw(currentMapScale, currentMapDrawX, currentMapDrawY, self.selectedPortal)
        end
        love.graphics.setColor(colors.white)
    else
        -- Fallback: Desenha fundo sólido se mapa falhou
        love.graphics.setColor(colors.lobby_background)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(colors.white)
    end

    -- 4. Desenha Modal (se portal selecionado)
    if self.selectedPortal then
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
        love.graphics.printf("Tempo Restante: " .. Formatters.formatTime(portal.timer), modal.x + 15, currentY,
            modal.w - 30, "left")
        currentY = currentY + lineH * 1.5

        love.graphics.printf("Bioma: Floresta Sombria", modal.x + 15, currentY, modal.w - 30, "left")
        currentY = currentY + lineH
        love.graphics.printf("Inimigos Comuns: Goblins da Noite, Lobos Espectrais", modal.x + 15, currentY, modal.w - 30,
            "left")
        currentY = currentY + lineH
        love.graphics.printf("Chefe: Rei Goblin Ancião", modal.x + 15, currentY, modal.w - 30, "left")
        currentY = currentY + lineH * 1.5

        love.graphics.printf(
            "História: Ecos de batalhas antigas ressoam nesta floresta corrompida...", -- Resumido
            modal.x + 15, currentY, modal.w - 30, "left")

        -- Botões
        local btnFont = fonts.main_small or fonts.main
        elements.drawButton({
            rect = self.modalBtnEnterRect,
            text = "Entrar",
            isHovering = self.modalButtonEnterHover,
            font = btnFont,
            colors = { bgColor = colors.button_primary_bg, hoverColor = colors.button_primary_hover, textColor = colors.button_primary_text, borderColor = colors.button_border }
        })
        elements.drawButton({
            rect = self.modalBtnCancelRect,
            text = "Cancelar",
            isHovering = self.modalButtonCancelHover,
            font = btnFont,
            colors = { bgColor = colors.button_secondary_bg, hoverColor = colors.button_secondary_hover, textColor = colors.button_secondary_text, borderColor = colors.button_border }
        })
    end

    -- Reset final
    love.graphics.setColor(colors.white)
    love.graphics.setFont(fonts.main or love.graphics.getFont())
end

--- Processa cliques do mouse nesta tela.
---@param x number Posição X do mouse.
---@param y number Posição Y do mouse.
---@param buttonIdx number Índice do botão.
---@return boolean consumed Se o clique foi consumido.
function PortalScreen:handleMousePress(x, y, buttonIdx)
    if buttonIdx == 1 then
        -- 1. Verifica clique no Modal (se ativo)
        if self.isZoomedIn and self.selectedPortal then
            local modalClicked = false
            if self.modalButtonEnterHover then
                modalClicked = true
                print(string.format("(PortalScreen) Botão 'Entrar' clicado para portal '%s'.", self.selectedPortal.name))
                -- Obtém stats ANTES de trocar de cena
                local activeHunterStats = self.hunterManager and self.hunterManager:getActiveHunterBaseStats() or {}
                SceneManager.switchScene("game_loading_scene", {
                    portalData = self.selectedPortal,
                    characterBaseStats = activeHunterStats -- Passa os stats
                })
            elseif self.modalButtonCancelHover then
                modalClicked = true
                print("(PortalScreen) Botão 'Cancelar' clicado.")
                self.selectedPortal = nil
                self.isZoomedIn = false
            else
                local m = self.modalRect
                if not (x >= m.x and x <= m.x + m.w and y >= m.y and y <= m.y + m.h) then
                    modalClicked = true
                    print("(PortalScreen) Clique fora do modal detectado.")
                    self.selectedPortal = nil
                    self.isZoomedIn = false
                end
            end
            if modalClicked then return true end -- Consome o clique
        end

        -- 2. Verifica clique nos Portais (se não estava com zoom/modal)
        if not self.isZoomedIn and self.portalManager then
            local clickedPortalData = self.portalManager:handleMouseClick(x, y)
            if clickedPortalData then
                print(string.format("(PortalScreen) Portal '%s' selecionado!", clickedPortalData.name))
                self.selectedPortal = clickedPortalData
                self.isZoomedIn = true
                self.mapTargetPanX = clickedPortalData.mapX
                self.mapTargetPanY = clickedPortalData.mapY
                return true -- Consome o clique
            end
        end
    end
    return false -- Não consumiu
end

--- Libera recursos ao descarregar.
function PortalScreen:unload()
    print("(PortalScreen) Unload")
    if self.mapImage then
        self.mapImage:release()
        self.mapImage = nil
    end
    self.fogShader = nil -- Shader não precisa de release
end

return PortalScreen
