local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")                              -- Pode ser necessário para desenhar info
local PersistenceManager = require("src.core.persistence_manager") -- <<< REMOVER? Ou manter para salvar posições?
local Formatters = require("src.utils.formatters")
local portalDefinitions = require("src.data.portals.portal_definitions")

--- Gerencia a criação, atualização e desenho dos portais no Lobby.
---@class LobbyPortalManager
---@field activePortals PortalInstanceData[]
---@field mapW number Largura do mapa
---@field mapH number Altura do mapa
---@field proceduralMap LobbyMapPortals|nil Referência para o mapa procedural
local LobbyPortalManager = {}
LobbyPortalManager.__index = LobbyPortalManager

-- Configurações
LobbyPortalManager.DEFAULT_NUM_PORTALS = 7
LobbyPortalManager.PORTAL_INTERACT_RADIUS = 10

-- <<< NOVO: Configuração da animação dos feixes >>>
LobbyPortalManager.beamAnimationSpeed = 0.5

-- <<< NOVO: Constantes para área de spawn segura (margem do continente) >>>
local CONTINENT_SPAWN_MARGIN = 200
local MIN_PORTAL_DISTANCE = 300

---@alias PortalInstanceData { id:string, name:string, rank:string, theme:string, mapX:number, mapY:number, screenX:number, screenY:number, color: {number}, radius:number, isHovering:boolean }

-- Cria uma nova instância
function LobbyPortalManager:new()
    local instance = setmetatable({}, LobbyPortalManager)
    instance.activePortals = {}
    instance.mapW = 0
    instance.mapH = 0
    instance.proceduralMap = nil

    return instance
end

--- Define a referência do mapa procedural
---@param proceduralMap LobbyMapPortals Instância do mapa procedural
function LobbyPortalManager:setProceduralMap(proceduralMap)
    self.proceduralMap = proceduralMap
    Logger.info("lobby_portal_manager.setProceduralMap", "[LobbyPortalManager] Referência do mapa procedural definida")
end

-- Inicializa o gerenciador com as dimensões do mapa e CRIA portais com base nas DEFINIÇÕES
function LobbyPortalManager:initialize(mapW, mapH)
    self.mapW = mapW or 0
    self.mapH = mapH or 0
    self.activePortals = {} -- Limpa portais antigos
    Logger.info("lobby_portal_manager.initialize",
        "[LobbyPortalManager] Inicializando com mapa " .. self.mapW .. "x" .. self.mapH)

    if not portalDefinitions or next(portalDefinitions) == nil then
        Logger.error("lobby_portal_manager.initialize.error",
            "[LobbyPortalManager] portalDefinitions não carregadas ou vazias!")
        return
    end

    -- Aguardar geração do mapa procedural antes de posicionar portais
    if self.proceduralMap and not self.proceduralMap:isGenerationComplete() then
        Logger.info("lobby_portal_manager.initialize.waiting",
            "[LobbyPortalManager] Aguardando geração do mapa procedural...")
        return
    end

    self:_generatePortalPositions()
end

--- Gera as posições dos portais dentro do continente procedural
function LobbyPortalManager:_generatePortalPositions()
    if not self.proceduralMap then
        Logger.warn("lobby_portal_manager._generatePortalPositions",
            "[LobbyPortalManager] Mapa procedural não disponível, usando posicionamento de tela")
        self:_generatePortalsScreenBased()
        return
    end

    Logger.info("lobby_portal_manager._generatePortalPositions",
        "[LobbyPortalManager] Gerando portais dentro do continente procedural")

    local portalCount = 0
    local maxAttempts = 10000

    for portalId, definition in pairs(portalDefinitions) do
        local portalPlaced = false
        local attempts = 0

        while not portalPlaced and attempts < maxAttempts do
            attempts = attempts + 1

            -- Gerar posição aleatória dentro dos limites do mapa virtual
            local x = love.math.random() * self.mapW
            local y = love.math.random() * self.mapH

            -- Verificar se está dentro do continente
            if self.proceduralMap:isPointInContinent(x, y) then
                -- Verificar margem de segurança das bordas do continente
                if self:_isPositionSafeFromEdges(x, y) then
                    -- Verificar distância mínima de outros portais
                    if self:_isValidPortalDistance(x, y) then
                        local portalInstance = {
                            id = portalId,
                            name = definition.name,
                            rank = definition.rank,
                            theme = definition.theme or "default",
                            mapX = x,
                            mapY = y,
                            screenX = 0, -- Será calculado no update/draw
                            screenY = 0, -- Será calculado no update/draw
                            color = colors.rankDetails[definition.rank].text,
                            radius = LobbyPortalManager.PORTAL_INTERACT_RADIUS,
                            isHovering = false,
                        }

                        table.insert(self.activePortals, portalInstance)
                        portalPlaced = true
                        portalCount = portalCount + 1

                        Logger.info("lobby_portal_manager._generatePortalPositions.portal",
                            "[LobbyPortalManager] Portal '" .. portalInstance.name .. "' (" .. portalInstance.rank ..
                            ") posicionado em (%.0f, %.0f)", x, y)
                    end
                end
            end
        end

        if not portalPlaced then
            Logger.warn("lobby_portal_manager._generatePortalPositions.failed",
                "[LobbyPortalManager] Falha ao posicionar portal '" ..
                portalId .. "' após " .. maxAttempts .. " tentativas")
        end
    end

    Logger.info("lobby_portal_manager._generatePortalPositions.complete",
        "[LobbyPortalManager] " .. portalCount .. " portais posicionados no continente procedural")
end

--- Verifica se a posição está segura das bordas do continente
---@param x number Coordenada X
---@param y number Coordenada Y
---@return boolean isSafe Se a posição está segura
function LobbyPortalManager:_isPositionSafeFromEdges(x, y)
    if not self.proceduralMap then return true end

    -- Verificar pontos ao redor da posição para garantir margem de segurança
    local checkPoints = {
        { x + CONTINENT_SPAWN_MARGIN,       y },
        { x - CONTINENT_SPAWN_MARGIN,       y },
        { x,                                y + CONTINENT_SPAWN_MARGIN },
        { x,                                y - CONTINENT_SPAWN_MARGIN },
        { x + CONTINENT_SPAWN_MARGIN * 0.7, y + CONTINENT_SPAWN_MARGIN * 0.7 },
        { x - CONTINENT_SPAWN_MARGIN * 0.7, y - CONTINENT_SPAWN_MARGIN * 0.7 },
        { x + CONTINENT_SPAWN_MARGIN * 0.7, y - CONTINENT_SPAWN_MARGIN * 0.7 },
        { x - CONTINENT_SPAWN_MARGIN * 0.7, y + CONTINENT_SPAWN_MARGIN * 0.7 }
    }

    for _, point in ipairs(checkPoints) do
        if not self.proceduralMap:isPointInContinent(point[1], point[2]) then
            return false -- Muito perto da borda
        end
    end

    return true
end

--- Verifica se a distância de outros portais é válida
---@param x number Coordenada X
---@param y number Coordenada Y
---@return boolean isValid Se a distância é válida
function LobbyPortalManager:_isValidPortalDistance(x, y)
    for _, existingPortal in ipairs(self.activePortals) do
        local dist = math.sqrt((x - existingPortal.mapX) ^ 2 + (y - existingPortal.mapY) ^ 2)
        if dist < MIN_PORTAL_DISTANCE then
            return false
        end
    end
    return true
end

--- Fallback para posicionamento baseado em tela (quando mapa procedural não está disponível)
function LobbyPortalManager:_generatePortalsScreenBased()
    Logger.info("lobby_portal_manager._generatePortalsScreenBased",
        "[LobbyPortalManager] Usando posicionamento baseado em tela como fallback")

    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    -- Margens de tela
    local SCREEN_SPAWN_MARGIN_TOP = 100
    local SCREEN_SPAWN_MARGIN_BOTTOM = 150
    local SCREEN_SPAWN_MARGIN_RIGHT = 50
    local SCREEN_SPAWN_MARGIN_LEFT = 50

    local function screenToMapCoords(sx, sy, currentMapW, currentMapH)
        local initialCamX = currentMapW / 2
        local initialCamY = currentMapH / 2
        local initialZoom = 1.0
        local initialDrawX = screenW / 2 - initialCamX * initialZoom
        local initialDrawY = screenH / 2 - initialCamY * initialZoom

        local mx = (sx - initialDrawX) / initialZoom
        local my = (sy - initialDrawY) / initialZoom
        return mx, my
    end

    local portalCount = 0
    for portalId, definition in pairs(portalDefinitions) do
        portalCount = portalCount + 1

        -- Calcular posição aleatória na tela dentro das margens
        local targetScreenX, targetScreenY
        local minScreenX = SCREEN_SPAWN_MARGIN_LEFT
        local maxScreenX = screenW - SCREEN_SPAWN_MARGIN_RIGHT
        local minScreenY = SCREEN_SPAWN_MARGIN_TOP
        local maxScreenY = screenH - SCREEN_SPAWN_MARGIN_BOTTOM

        if minScreenX < maxScreenX and minScreenY < maxScreenY then
            targetScreenX = math.random(minScreenX, maxScreenX)
            targetScreenY = math.random(minScreenY, maxScreenY)
        else
            Logger.warn("lobby_portal_manager._generatePortalsScreenBased.margin",
                "[LobbyPortalManager] Margens de tela inválidas para portal '" .. portalId .. "'")
            targetScreenX = screenW / 2
            targetScreenY = screenH / 2
        end

        -- Converter posição da tela para coordenadas do mapa
        local finalMapX, finalMapY = screenToMapCoords(targetScreenX, targetScreenY, self.mapW, self.mapH)

        -- Garantir que não saia dos limites do mapa
        finalMapX = math.max(0, math.min(self.mapW, finalMapX))
        finalMapY = math.max(0, math.min(self.mapH, finalMapY))

        local portalInstance = {
            id = portalId,
            name = definition.name,
            rank = definition.rank,
            theme = definition.theme or "default",
            mapX = finalMapX,
            mapY = finalMapY,
            screenX = 0,
            screenY = 0,
            color = colors.rankDetails[definition.rank].text or colors.white,
            radius = LobbyPortalManager.PORTAL_INTERACT_RADIUS,
            isHovering = false,
        }

        table.insert(self.activePortals, portalInstance)

        Logger.info("lobby_portal_manager._generatePortalsScreenBased.portal",
            "[LobbyPortalManager] Portal '" .. portalInstance.name .. "' (" .. portalInstance.rank ..
            ") criado em MAPA(%.0f, %.0f) [tela(%.0f, %.0f)]", finalMapX, finalMapY, targetScreenX, targetScreenY)
    end

    Logger.info("lobby_portal_manager._generatePortalsScreenBased.complete",
        "[LobbyPortalManager] " .. portalCount .. " portais criados com posicionamento de tela")
end

--- Tenta reposicionar portais quando o mapa procedural fica disponível
function LobbyPortalManager:tryRepositionPortals()
    if not self.proceduralMap or not self.proceduralMap:isGenerationComplete() then
        return false
    end

    if #self.activePortals > 0 then
        Logger.info("lobby_portal_manager.tryRepositionPortals",
            "[LobbyPortalManager] Reposicionando portais para o continente procedural")
        self:_generatePortalPositions()
        return true
    end

    return false
end

-- Atualiza o estado de hover dos portais (remove lógica de timer expirado)
function LobbyPortalManager:update(dt, mx, my, allowPortalHover, mapScale, mapDrawX, mapDrawY)
    -- Tentar reposicionar portais se mapa procedural estiver disponível
    if self.proceduralMap and self.proceduralMap:isGenerationComplete() then
        if #self.activePortals == 0 or (self.activePortals[1] and self.activePortals[1].mapX == 0) then
            self:tryRepositionPortals()
        end
    end

    if allowPortalHover then
        for i, portal in ipairs(self.activePortals) do
            -- Calcula posição na tela
            portal.screenX = mapDrawX + portal.mapX * mapScale
            portal.screenY = mapDrawY + portal.mapY * mapScale

            -- Verifica hover usando raio escalado
            local scaledRadius = portal.radius * mapScale
            local distSq = (mx - portal.screenX) ^ 2 + (my - portal.screenY) ^ 2
            portal.isHovering = distSq <= (scaledRadius * scaledRadius)
        end
    else
        for _, portal in ipairs(self.activePortals) do
            portal.isHovering = false
        end
    end
end

--- Desenha os portais ativos no mapa.
---@param mapScale number Escala atual de desenho do mapa.
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado.
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado.
---@param selectedPortalData PortalData|nil Dados do portal atualmente selecionado na cena (para destaque/escala).
function LobbyPortalManager:draw(mapScale, mapDrawX, mapDrawY, selectedPortalData)
    local portalFont = fonts.main_small or fonts.main
    local portalFontHeight = portalFont:getHeight()
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    love.graphics.setFont(portalFont)
    love.graphics.setLineWidth(2)

    local ellipseYFactor = 0.6

    for i, portal in ipairs(self.activePortals) do
        local isSelected = selectedPortalData and (portal.id == selectedPortalData.id)
        local checkRadius = isSelected and portal.radius * mapScale * 1.5 or portal.radius * mapScale

        -- Otimização: Só desenha se estiver perto da tela visível
        if portal.screenX >= -checkRadius and portal.screenX <= screenW + checkRadius and
            portal.screenY >= -checkRadius * ellipseYFactor and portal.screenY <= screenH + checkRadius * ellipseYFactor then
            local r, g, b, a = portal.color[1], portal.color[2], portal.color[3], portal.color[4]

            -- Calcula raios base e escala de hover
            local baseRadiusX = portal.radius
            local hoverScale = portal.isHovering and 1.2 or 1.0

            -- Aplica escala adicional se for o portal selecionado
            local selectionScale = isSelected and mapScale or 1.0
            selectionScale = math.max(1.0, selectionScale * 0.8)

            -- Aplica todas as escalas
            local finalScale = hoverScale * selectionScale
            local drawRadiusX = baseRadiusX * finalScale
            local drawRadiusY = baseRadiusX * ellipseYFactor * finalScale

            -- Desenha a elipse do portal com mais transparência
            love.graphics.setColor(r, g, b, 0.5)
            love.graphics.ellipse("fill", portal.screenX, portal.screenY, drawRadiusX, drawRadiusY)
            love.graphics.setColor(r * 1.2, g * 1.2, b * 1.2, 0.8)
            love.graphics.ellipse("line", portal.screenX, portal.screenY, drawRadiusX, drawRadiusY)

            -- Desenha feixes de luz
            local numBeams = 15
            local baseBeamHeight = isSelected and 70 * mapScale or 70
            local baseBeamAlpha = 0.3
            love.graphics.setLineWidth(1)
            for j = 1, numBeams do
                local angle = math.random() * 2 * math.pi
                local beamStartX = portal.screenX + drawRadiusX * math.cos(angle)
                local beamStartY = portal.screenY + drawRadiusY * math.sin(angle)
                local time = love.timer.getTime()
                local speed = LobbyPortalManager.beamAnimationSpeed
                local heightFactor = 1.0 + 0.4 * math.sin(time * speed + angle * 2)
                local alphaFactor = 1.0 + 0.5 * math.cos(time * speed * 0.7 + angle)
                local currentBeamHeight = baseBeamHeight * heightFactor
                local currentBeamAlpha = baseBeamAlpha * alphaFactor
                currentBeamAlpha = math.min(0.8, math.max(0.05, currentBeamAlpha))
                love.graphics.setColor(r, g, b, currentBeamAlpha)
                love.graphics.line(beamStartX, beamStartY, beamStartX, beamStartY - currentBeamHeight)
            end
            love.graphics.setLineWidth(2)

            -- Desenha informações acima do portal (somente se NÃO selecionado)
            if not isSelected then
                local textY = portal.screenY - drawRadiusY - portalFontHeight * 2 - 5
                local infoText = string.format("[%s] %s", portal.rank, portal.name)
                local infoWidth = portalFont:getWidth(infoText)
                local infoTextX = portal.screenX - infoWidth / 2
                -- Sombra
                love.graphics.setColor(colors.black[1], colors.black[2], colors.black[3], 0.7)
                love.graphics.print(infoText, infoTextX + 1, textY + 1)
                -- Texto
                love.graphics.setColor(portal.color)
                love.graphics.print(infoText, infoTextX, textY)
            end
        end
    end
    love.graphics.setLineWidth(1)
end

-- Retorna dados do portal clicado, se houver
---@param x number Posição X do mouse na tela.
---@param y number Posição Y do mouse na tela.
---@param mapScale number Escala atual de desenho do mapa.
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado.
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado.
---@return PortalInstanceData|nil Retorna a instância do portal clicado ou nil.
function LobbyPortalManager:handleMouseClick(x, y, mapScale, mapDrawX, mapDrawY)
    for _, portal in ipairs(self.activePortals) do
        -- Calcula a posição do portal na tela AGORA
        local currentScreenX = mapDrawX + portal.mapX * mapScale
        local currentScreenY = mapDrawY + portal.mapY * mapScale

        -- Verifica clique usando raio escalado
        local scaledRadius = portal.radius * mapScale
        local distSq = (x - currentScreenX) ^ 2 + (y - currentScreenY) ^ 2

        if distSq <= (scaledRadius * scaledRadius) then
            Logger.info("lobby_portal_manager.handleMouseClick.portal_clicked",
                "[LobbyPortalManager] Portal '" .. portal.name .. "' clicado")
            return portal
        end
    end

    return nil
end

--- Retorna todos os portais ativos
---@return PortalInstanceData[] Lista de portais ativos
function LobbyPortalManager:getActivePortals()
    return self.activePortals
end

--- Retorna o número de portais ativos
---@return number Número de portais ativos
function LobbyPortalManager:getPortalCount()
    return #self.activePortals
end

--[[---------------------------------------------------------------------------
    Funções de Salvamento e Carregamento de Portais
---------------------------------------------------------------------------]]

--- Salva o estado atual dos portais usando o PersistenceManager.
function LobbyPortalManager:saveState()
    print("LobbyPortalManager: Solicitando salvamento de estado...")
    local dataToSave = {
        timestamp = os.time(),
        portals = self.activePortals
    }
    local success = PersistenceManager.saveData("portals_save.dat", dataToSave)
    if not success then
        print("LobbyPortalManager: Falha ao solicitar salvamento de estado ao PersistenceManager.")
        -- Pode adicionar tratamento de erro adicional aqui se necessário
    end
end

--- MÉTODO DE TESTE SIMPLES ---
function LobbyPortalManager:testCall()
    -- print(">>> LPM:testCall - EXECUTADO COM SUCESSO!") -- DEBUG
end

return LobbyPortalManager
