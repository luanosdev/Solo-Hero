local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")                              -- Pode ser necessário para desenhar info
local PersistenceManager = require("src.core.persistence_manager") -- <<< NOVO REQUIRE
local Formatters = require("src.utils.formatters")                 -- <<< NOVO REQUIRE

--- Gerencia a criação, atualização e desenho dos portais no Lobby.
---@class LobbyPortalManager
local LobbyPortalManager = {}
LobbyPortalManager.__index = LobbyPortalManager

-- Configurações
LobbyPortalManager.DEFAULT_NUM_PORTALS = 7
LobbyPortalManager.PORTAL_INTERACT_RADIUS = 10

-- <<< NOVO: Configuração da animação dos feixes >>>
LobbyPortalManager.beamAnimationSpeed = 0.5

-- Tabela de pesos para a raridade dos ranks
local portalRankWeights = {
    { rank = "E",  weight = 50 },
    { rank = "D",  weight = 25 },
    { rank = "C",  weight = 15 },
    { rank = "B",  weight = 7 },
    { rank = "A",  weight = 2 },
    { rank = "S",  weight = 0.8 },
    { rank = "SS", weight = 0.2 },
}

--- Seleciona um rank aleatório baseado nos pesos definidos.
---@return string Rank selecionado (ex: "E", "S")
local function getRandomWeightedRank()
    local totalWeight = 0
    for _, data in ipairs(portalRankWeights) do
        totalWeight = totalWeight + data.weight
    end

    local randomNum = math.random() * totalWeight
    for _, data in ipairs(portalRankWeights) do
        if randomNum < data.weight then
            return data.rank
        end
        randomNum = randomNum - data.weight
    end
    return portalRankWeights[#portalRankWeights].rank
end

--- Gera dados para um novo portal aleatório.
---@param mapW number Largura do mapa (imagem original).
---@param mapH number Altura do mapa (imagem original).
---@return PortalData
local function generateRandomPortal(mapW, mapH)
    local portal = {}
    portal.mapX = math.random(50, mapW - 50)
    portal.mapY = math.random(50, mapH - 50)
    portal.screenX = 0
    portal.screenY = 0
    portal.rank = getRandomWeightedRank()
    portal.name = string.format("Portal %s-%d", portal.rank, math.random(100, 999))
    portal.color = colors.rank[portal.rank] or colors.white
    portal.timer = math.random(120, 400)
    portal.radius = LobbyPortalManager.PORTAL_INTERACT_RADIUS
    portal.isHovering = false
    return portal
end

--- Cria uma nova instância do gerenciador de portais.
---@return LobbyPortalManager
function LobbyPortalManager:new()
    local instance = setmetatable({}, LobbyPortalManager)
    instance.activePortals = {} ---@type PortalData[] Lista de portais ativos.
    instance.mapW = 0 ---@type number Largura da imagem do mapa.
    instance.mapH = 0 ---@type number Altura da imagem do mapa.
    instance.numPortals = LobbyPortalManager.DEFAULT_NUM_PORTALS
    print("LobbyPortalManager: Instância criada.")
    return instance
end

--- Inicializa o gerenciador com as dimensões do mapa e CARREGA/GERA portais.
---@param mapW number Largura da imagem do mapa.
---@param mapH number Altura da imagem do mapa.
---@param numPortals? integer Número de portais a gerar (opcional).
function LobbyPortalManager:initialize(mapW, mapH, numPortals)
    self.mapW = mapW or 0
    self.mapH = mapH or 0
    self.numPortals = numPortals or self.DEFAULT_NUM_PORTALS
    print(string.format("LobbyPortalManager: Inicializando com mapa %dx%d, alvo de %d portais.", self.mapW, self.mapH,
        self.numPortals))

    self.activePortals = {} -- Começa com a lista vazia
    local loadedData = PersistenceManager.loadData("portals_save.dat")

    if loadedData and type(loadedData) == "table" and loadedData.timestamp and loadedData.portals then
        local currentTime = os.time()
        local savedTimestamp = loadedData.timestamp
        local elapsedTime = math.max(0, currentTime - savedTimestamp)
        print(string.format("LobbyPortalManager: Dados carregados. Tempo desde último save: %d segundos.", elapsedTime))

        local loadedCount = 0
        local expiredCount = 0
        for _, portalData in ipairs(loadedData.portals) do
            portalData.timer = portalData.timer - elapsedTime
            portalData.isHovering = false
            portalData.screenX = 0
            portalData.screenY = 0
            if portalData.timer > 0 then
                table.insert(self.activePortals, portalData) -- Adiciona portal válido à lista
                loadedCount = loadedCount + 1
            else
                expiredCount = expiredCount + 1
            end
        end
        print(string.format("LobbyPortalManager: Processados %d portais salvos. %d válidos, %d expiraram.",
            loadedCount + expiredCount, loadedCount, expiredCount))
    else
        print("LobbyPortalManager: Nenhum dado válido carregado. Iniciando com portais vazios.")
        -- activePortals já está vazio
    end

    print(string.format("Após carregamento/processamento, existem %d portais ativos.", #self.activePortals))

    -- Gera portais que faltam para atingir o número desejado
    local numMissing = self.numPortals - #self.activePortals
    if numMissing > 0 then
        print(string.format("Gerando %d portais novos para atingir o total de %d.", numMissing, self.numPortals))
        if self.mapW > 0 and self.mapH > 0 then
            for i = 1, numMissing do
                table.insert(self.activePortals, generateRandomPortal(self.mapW, self.mapH))
            end
        else
            print("Aviso: Dimensões do mapa inválidas ou não informadas. Não foi possível gerar portais faltantes.")
        end
    elseif numMissing < 0 then
        print(string.format("Aviso: Foram carregados %d portais, que é mais que o alvo de %d.", #self.activePortals,
            self.numPortals))
    end

    print(string.format("LobbyPortalManager inicializado com %d portais ativos.", #self.activePortals))
end

--- Atualiza os timers e estado de hover dos portais.
---@param dt number Delta time.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param allowPortalHover boolean Indica se é permitido atualizar os timers e hover dos portais.
---@param mapScale number Escala atual de desenho do mapa.
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado.
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado.
function LobbyPortalManager:update(dt, mx, my, allowPortalHover, mapScale, mapDrawX, mapDrawY)
    local portalsToRemove = {}

    -- Só atualiza timers e hover se permitido pela cena
    if allowPortalHover then
        for i, portal in ipairs(self.activePortals) do
            -- Decrementa o timer
            portal.timer = portal.timer - dt
            if portal.timer <= 0 then
                table.insert(portalsToRemove, i)
            else
                -- Calcula posição na tela
                portal.screenX = mapDrawX + portal.mapX * mapScale
                portal.screenY = mapDrawY + portal.mapY * mapScale

                -- Verifica hover
                local distSq = (mx - portal.screenX) ^ 2 + (my - portal.screenY) ^ 2
                portal.isHovering = distSq <= (portal.radius * portal.radius)
            end
        end
    else
        -- Garante que não haja hover e NÃO atualiza timers se não permitido
        for _, portal in ipairs(self.activePortals) do
            portal.isHovering = false
            -- Timer não é decrementado aqui
        end
    end

    -- Remove portais expirados (isso pode acontecer mesmo se o timer parou de ser decrementado neste frame)
    for i = #portalsToRemove, 1, -1 do
        local indexToRemove = portalsToRemove[i]
        print(string.format("LobbyPortalManager: Removendo portal expirado: %s", self.activePortals[indexToRemove].name))
        table.remove(self.activePortals, indexToRemove)
        -- TODO: Gerar novo portal para substituir
        -- if self.mapW > 0 then
        --    table.insert(self.activePortals, generateRandomPortal(self.mapW, self.mapH))
        -- end
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
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    love.graphics.setFont(portalFont)
    love.graphics.setLineWidth(2)

    local ellipseYFactor = 0.6 -- Fator para achatar a elipse verticalmente

    for i, portal in ipairs(self.activePortals) do
        portal.screenX = mapDrawX + portal.mapX * mapScale
        portal.screenY = mapDrawY + portal.mapY * mapScale

        -- Define se este portal é o selecionado
        local isSelected = selectedPortalData and
            (portal.name == selectedPortalData.name) -- Compara por nome (ou outro ID único)

        -- Otimização: Só desenha se estiver perto da tela visível
        local checkRadius = isSelected and portal.radius * mapScale or
            portal
            .radius -- Raio de verificação maior se selecionado e com zoom
        if portal.screenX >= -checkRadius and portal.screenX <= screenW + checkRadius and
            portal.screenY >= -checkRadius * ellipseYFactor and portal.screenY <= screenH + checkRadius * ellipseYFactor then
            local r, g, b, a = portal.color[1], portal.color[2], portal.color[3], portal.color[4]

            -- Calcula raios base e escala de hover
            local baseRadiusX = portal.radius
            local hoverScale = portal.isHovering and 1.2 or 1.0

            -- <<< NOVO: Aplica escala adicional se for o portal selecionado >>>
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
            for i = 1, numBeams do
                local angle = math.random() * 2 * math.pi
                -- <<< MODIFICADO: Usa drawRadiusX/Y finais para posicionar feixes >>>
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
                local timerText = Formatters.formatTime(portal.timer)
                local infoWidth = portalFont:getWidth(infoText)
                local timerWidth = portalFont:getWidth(timerText)
                local infoTextX = portal.screenX - infoWidth / 2
                local timerTextX = portal.screenX - timerWidth / 2
                -- Sombra
                love.graphics.setColor(colors.black[1], colors.black[2], colors.black[3], 0.7)
                love.graphics.print(infoText, infoTextX + 1, textY + 1)
                love.graphics.print(timerText, timerTextX + 1, textY + portalFontHeight + 1)
                -- Texto
                love.graphics.setColor(portal.color)
                love.graphics.print(infoText, infoTextX, textY)
                love.graphics.setColor(colors.white)
                love.graphics.print(timerText, timerTextX, textY + portalFontHeight)
            end
        end
    end
    love.graphics.setLineWidth(1) -- Reseta largura da linha final
end

--- Verifica se o clique foi em algum portal e retorna os dados do portal se houver.
---@param clickX number Posição X do clique.
---@param clickY number Posição Y do clique.
---@return PortalData|nil Retorna a tabela de dados do portal clicado ou nil.
function LobbyPortalManager:handleMouseClick(clickX, clickY)
    for i, portal in ipairs(self.activePortals) do
        -- Usa o estado de hover calculado no update
        if portal.isHovering then
            print(string.format("LobbyPortalManager: Portal '%s' (Rank %s) clicado!", portal.name, portal.rank))
            return portal -- Retorna os dados do portal clicado
        end
    end
    return nil -- Nenhum portal clicado
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
