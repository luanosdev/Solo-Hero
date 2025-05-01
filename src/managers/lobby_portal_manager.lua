local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")                              -- Pode ser necessário para desenhar info
local PersistenceManager = require("src.core.persistence_manager") -- <<< REMOVER? Ou manter para salvar posições?
local Formatters = require("src.utils.formatters")
local portalDefinitions = require("src.data.portals.portal_definitions")

--- Gerencia a criação, atualização e desenho dos portais no Lobby.
---@class LobbyPortalManager
local LobbyPortalManager = {}
LobbyPortalManager.__index = LobbyPortalManager

-- Configurações
LobbyPortalManager.DEFAULT_NUM_PORTALS = 7
LobbyPortalManager.PORTAL_INTERACT_RADIUS = 10

-- <<< NOVO: Configuração da animação dos feixes >>>
LobbyPortalManager.beamAnimationSpeed = 0.5

-- <<< NOVO: Constantes para área de spawn NA TELA (inicialmente) >>>
local SCREEN_SPAWN_MARGIN_TOP = 100
local SCREEN_SPAWN_MARGIN_BOTTOM = 100 -- Evitar área das tabs
local SCREEN_SPAWN_MARGIN_RIGHT = 50
local SCREEN_SPAWN_MARGIN_LEFT = 50
-- Removidas constantes antigas baseadas no mapa

-- Tabela de pesos para a raridade dos ranks
-- local portalRankWeights = {
--     { rank = "E",  weight = 50 },
--     { rank = "D",  weight = 25 },
--     { rank = "C",  weight = 15 },
--     { rank = "B",  weight = 7 },
--     { rank = "A",  weight = 2 },
--     { rank = "S",  weight = 0.8 },
--     { rank = "SS", weight = 0.2 },
-- }

-- <<< REMOVER FUNÇÕES ANTIGAS >>> --
-- local function getRandomWeightedRank() ... end
-- local function generateRandomPortal(mapW, mapH) ... end

--- Seleciona um rank aleatório baseado nos pesos definidos.
---@return string Rank selecionado (ex: "E", "S")
-- local function getRandomWeightedRank()
--     local totalWeight = 0
--     for _, data in ipairs(portalRankWeights) do
--         totalWeight = totalWeight + data.weight
--     end
--
--     local randomNum = math.random() * totalWeight
--     for _, data in ipairs(portalRankWeights) do
--         if randomNum < data.weight then
--             return data.rank
--         end
--         randomNum = randomNum - data.weight
--     end
--     return portalRankWeights[#portalRankWeights].rank
-- end

---@alias PortalInstanceData { id:string, name:string, rank:string, theme:string, mapX:number, mapY:number, screenX:number, screenY:number, color: {number}, radius:number, isHovering:boolean }

-- Cria uma nova instância
function LobbyPortalManager:new()
    local instance = setmetatable({}, LobbyPortalManager)
    instance.activePortals = {} ---@type PortalInstanceData[]
    instance.mapW = 0
    instance.mapH = 0
    -- numPortals não é mais necessário, será baseado nas definições
    print("LobbyPortalManager: Instância criada.")
    return instance
end

-- Inicializa o gerenciador com as dimensões do mapa e CRIA portais com base nas DEFINIÇÕES
function LobbyPortalManager:initialize(mapW, mapH)
    self.mapW = mapW or 0
    self.mapH = mapH or 0
    self.activePortals = {} -- Limpa portais antigos
    print(string.format("LobbyPortalManager: Inicializando com mapa %dx%d.", self.mapW, self.mapH))

    if not portalDefinitions or next(portalDefinitions) == nil then
        print("ERRO: portalDefinitions não carregadas ou vazias!")
        return
    end

    -- >>> OBTÉM DIMENSÕES DA TELA <<<
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- >>> FUNÇÃO AUXILIAR PARA CONVERTER TELA -> MAPA (CÂMERA INICIAL NO CENTRO, ZOOM 1.0) <<<
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

    -- Cria instâncias para cada portal definido
    local portalCount = 0
    for portalId, definition in pairs(portalDefinitions) do
        portalCount = portalCount + 1

        -- 1. Calcula posição aleatória NA TELA dentro das margens
        local targetScreenX, targetScreenY
        local minScreenX = SCREEN_SPAWN_MARGIN_LEFT
        local maxScreenX = screenW - SCREEN_SPAWN_MARGIN_RIGHT
        local minScreenY = SCREEN_SPAWN_MARGIN_TOP
        local maxScreenY = screenH - SCREEN_SPAWN_MARGIN_BOTTOM - 50 -- Subtrai altura estimada das tabs

        if minScreenX < maxScreenX and minScreenY < maxScreenY then
            targetScreenX = math.random(minScreenX, maxScreenX)
            targetScreenY = math.random(minScreenY, maxScreenY)
        else
            print(string.format("AVISO: Margens de TELA inválidas para portal '%s'. Spawning no centro da tela.",
                portalId))
            targetScreenX = screenW / 2
            targetScreenY = screenH / 2
        end

        -- 2. Converte a posição da tela para coordenadas do MAPA
        local finalMapX, finalMapY = screenToMapCoords(targetScreenX, targetScreenY, self.mapW, self.mapH)

        -- Garante que as coordenadas do mapa não saiam dos limites (caso a conversão resulte fora)
        finalMapX = math.max(0, math.min(self.mapW, finalMapX))
        finalMapY = math.max(0, math.min(self.mapH, finalMapY))

        ---@type PortalInstanceData
        local portalInstance = {
            id = portalId,
            name = definition.name,
            rank = definition.rank,
            theme = definition.theme,
            mapX = finalMapX, -- <<< USA COORDENADAS DO MAPA CONVERTIDAS
            mapY = finalMapY, -- <<< USA COORDENADAS DO MAPA CONVERTIDAS
            screenX = 0,      -- Será calculado no update/draw
            screenY = 0,      -- Será calculado no update/draw
            color = colors.rank[definition.rank] or colors.white,
            radius = LobbyPortalManager.PORTAL_INTERACT_RADIUS,
            isHovering = false,
            -- timer = math.huge -- Timer removido/desnecessário por enquanto
        }

        table.insert(self.activePortals, portalInstance)
        print(string.format("  - Portal '%s' (%s) criado em MAPA(%.0f, %.0f) [originado da TELA(%.0f, %.0f)]",
            portalInstance.name, portalInstance.rank, portalInstance.mapX, portalInstance.mapY,
            targetScreenX, targetScreenY)) -- Log Atualizado
    end

    print(string.format("LobbyPortalManager inicializado com %d portais definidos.", portalCount))
end

-- Atualiza o estado de hover dos portais (remove lógica de timer expirado)
function LobbyPortalManager:update(dt, mx, my, allowPortalHover, mapScale, mapDrawX, mapDrawY)
    if allowPortalHover then
        for i, portal in ipairs(self.activePortals) do
            -- Calcula posição na tela
            portal.screenX = mapDrawX + portal.mapX * mapScale
            portal.screenY = mapDrawY + portal.mapY * mapScale

            -- Verifica hover
            local distSq = (mx - portal.screenX) ^ 2 + (my - portal.screenY) ^ 2
            portal.isHovering = distSq <= (portal.radius * portal.radius)
        end
    else
        for _, portal in ipairs(self.activePortals) do
            portal.isHovering = false
        end
    end
    -- Lógica de remover portais expirados foi removida
end

--- Desenha os portais ativos no mapa.
---@param mapScale number Escala atual de desenho do mapa.
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado.
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado.
---@param selectedPortalData PortalData|nil Dados do portal atualmente selecionado na cena (para destaque/escala).
function LobbyPortalManager:draw(mapScale, mapDrawX, mapDrawY, selectedPortalData)
    local portalFont = fonts.main_small or fonts.main
    local portalFontHeight = portalFont:getHeight()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    love.graphics.setFont(portalFont)
    love.graphics.setLineWidth(2)

    local ellipseYFactor = 0.6 -- Fator para achatar a elipse verticalmente

    for i, portal in ipairs(self.activePortals) do
        -- >>> RESTAURANDO LÓGICA ORIGINAL <<<
        local isSelected = selectedPortalData and
            (portal.id == selectedPortalData.id) -- Comparar por ID único

        local checkRadius = isSelected and portal.radius * mapScale * 1.5 or
            portal.radius *
            mapScale -- Usa mapScale para checkRadius

        -- Otimização: Só desenha se estiver perto da tela visível (usando portal.screenX/Y calculados no UPDATE)
        if portal.screenX >= -checkRadius and portal.screenX <= screenW + checkRadius and
            portal.screenY >= -checkRadius * ellipseYFactor and portal.screenY <= screenH + checkRadius * ellipseYFactor then
            local r, g, b, a = portal.color[1], portal.color[2], portal.color[3], portal.color[4]

            -- Calcula raios base e escala de hover
            local baseRadiusX = portal.radius
            local hoverScale = portal.isHovering and 1.2 or 1.0

            -- <<< Aplica escala adicional se for o portal selecionado >>>
            local selectionScale = isSelected and mapScale or 1.0 -- Escala com o zoom do mapa se selecionado
            selectionScale = math.max(1.0, selectionScale * 0.8)  -- Garante escala mínima e suaviza um pouco

            -- Aplica todas as escalas
            local finalScale = hoverScale * selectionScale
            local drawRadiusX = baseRadiusX * finalScale
            local drawRadiusY = baseRadiusX * ellipseYFactor * finalScale

            -- Desenha a elipse do portal com mais transparência
            love.graphics.setColor(r, g, b, 0.5)
            love.graphics.ellipse("fill", portal.screenX, portal.screenY, drawRadiusX, drawRadiusY)
            love.graphics.setColor(r * 1.2, g * 1.2, b * 1.2, 0.8)
            love.graphics.ellipse("line", portal.screenX, portal.screenY, drawRadiusX, drawRadiusY)

            -- Desenha feixes de luz (não escalam com o zoom para não ficarem enormes)
            local numBeams = 15
            local baseBeamHeight = isSelected and 70 * mapScale or 70 -- Feixes mais altos se selecionado e com zoom
            local baseBeamAlpha = 0.3
            love.graphics.setLineWidth(1)
            for j = 1, numBeams do -- <<< Use j para evitar conflito com loop externo
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
            love.graphics.setLineWidth(2) -- Restaura largura

            -- Desenha informações acima do portal (somente se NÃO selecionado, para não colidir com modal)
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
    love.graphics.setLineWidth(1) -- Reseta largura da linha final
end

-- Retorna dados do portal clicado, se houver
function LobbyPortalManager:handleMouseClick(x, y)
    for _, portal in ipairs(self.activePortals) do
        if portal.isHovering then
            return portal -- Retorna a instância completa do portal, incluindo hordeConfig
        end
    end
    return nil
end

-- Função para limpar recursos se necessário (não muito útil aqui)
-- function LobbyPortalManager:cleanup()
--     self.activePortals = {}
-- end

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

return LobbyPortalManager
