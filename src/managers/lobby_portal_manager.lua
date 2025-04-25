local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts") -- Pode ser necessário para desenhar info

--- Gerencia a criação, atualização e desenho dos portais no Lobby.
---@class LobbyPortalManager
local LobbyPortalManager = {}
LobbyPortalManager.__index = LobbyPortalManager

-- Configurações
LobbyPortalManager.DEFAULT_NUM_PORTALS = 5
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

--- Formata o tempo em segundos para MM:SS.
---@param seconds number
---@return string
local function formatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    local min = math.floor(seconds / 60)
    local sec = seconds % 60
    return string.format("%02d:%02d", min, sec)
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

    -- 1. Tenta carregar e atualizar portais salvos
    local loadedPortals = self:loadAndUpdatePortals()
    self.activePortals = loadedPortals -- Define os portais ativos como os que foram carregados
    print(string.format("Após carregamento, existem %d portais ativos.", #self.activePortals))

    -- 2. Gera portais que faltam para atingir o número desejado
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
        -- Situação inesperada: mais portais carregados que o alvo. Apenas loga.
        print(string.format("Aviso: Foram carregados %d portais, que é mais que o alvo de %d.", #self.activePortals,
            self.numPortals))
    end

    print(string.format("LobbyPortalManager inicializado com %d portais ativos.", #self.activePortals))
end

--- Atualiza os timers e estado de hover dos portais.
---@param dt number Delta time.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@param isMapActive boolean Indica se a visualização do mapa está ativa.
---@param mapScale number Escala atual de desenho do mapa.
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado.
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado.
function LobbyPortalManager:update(dt, mx, my, isMapActive, mapScale, mapDrawX, mapDrawY)
    local portalsToRemove = {}

    if isMapActive and self.mapW > 0 then
        for i, portal in ipairs(self.activePortals) do
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
        -- Garante que não haja hover se o mapa não estiver ativo
        for _, portal in ipairs(self.activePortals) do portal.isHovering = false end
    end

    -- Remove portais expirados
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
function LobbyPortalManager:draw(mapScale, mapDrawX, mapDrawY)
    local portalFont = fonts.main_small or fonts.main
    local portalFontHeight = portalFont:getHeight()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    -- Assume que a cor já foi resetada para branco antes de chamar esta função

    love.graphics.setFont(portalFont)
    love.graphics.setLineWidth(2)

    local ellipseYFactor = 0.6 -- <<< NOVO: Fator para achatar a elipse verticalmente (simula perspectiva)

    for i, portal in ipairs(self.activePortals) do
        -- Recalcula/Usa screen coords
        portal.screenX = mapDrawX + portal.mapX * mapScale
        portal.screenY = mapDrawY + portal.mapY * mapScale

        -- Otimização: Só desenha se estiver perto da tela visível (aproximado com raio X)
        if portal.screenX >= -portal.radius and portal.screenX <= screenW + portal.radius and
            portal.screenY >= -portal.radius * ellipseYFactor and portal.screenY <= screenH + portal.radius * ellipseYFactor then
            local r, g, b, a = portal.color[1], portal.color[2], portal.color[3], portal.color[4]

            -- Efeito de hover simples (aumenta o raio)
            local baseRadiusX = portal.radius
            local hoverScale = portal.isHovering and 1.2 or 1.0
            local drawRadiusX = baseRadiusX * hoverScale
            local drawRadiusY = baseRadiusX * ellipseYFactor * hoverScale -- <<< USA FATOR Y

            -- Desenha a elipse do portal com mais transparência
            love.graphics.setColor(r, g, b, 0.5)                                                    -- <<< ALFA REDUZIDO para preenchimento
            love.graphics.ellipse("fill", portal.screenX, portal.screenY, drawRadiusX, drawRadiusY) -- <<< USA ELLIPSE
            love.graphics.setColor(r * 1.2, g * 1.2, b * 1.2, 0.8)                                  -- <<< ALFA REDUZIDO para linha
            love.graphics.ellipse("line", portal.screenX, portal.screenY, drawRadiusX, drawRadiusY) -- <<< USA ELLIPSE

            -- <<< NOVO: Desenha MÚLTIPLOS feixes de luz VERTICAIS aleatórios >>>
            local numBeams = 50           -- Número de feixes a desenhar
            local baseBeamHeight = 20     -- Altura média dos feixes
            local baseBeamAlpha = 0.3     -- Alpha médio dos feixes
            love.graphics.setLineWidth(1) -- Linhas finas para os feixes

            for i = 1, numBeams do
                local angle = math.random() * 2 * math.pi -- Ângulo aleatório na elipse (mantido para posição)
                local startX = portal.screenX + drawRadiusX * math.cos(angle)
                local startY = portal.screenY + drawRadiusY * math.sin(angle)

                -- <<< MODIFICADO: Variação de altura e alpha baseada no tempo >>>
                local time = love.timer.getTime()
                local speed = LobbyPortalManager.beamAnimationSpeed

                -- Fator de altura varia suavemente com sin (entre 0.6 e 1.4)
                local heightFactor = 1.0 + 0.4 * math.sin(time * speed + angle * 2)
                -- Fator de alpha varia suavemente com cos (entre 0.5 e 1.5, será limitado)
                local alphaFactor = 1.0 + 0.5 * math.cos(time * speed * 0.7 + angle)

                local currentBeamHeight = baseBeamHeight * heightFactor
                local currentBeamAlpha = baseBeamAlpha * alphaFactor
                currentBeamAlpha = math.min(0.8, math.max(0.05, currentBeamAlpha)) -- Garante alpha entre 0.05 e 0.8

                love.graphics.setColor(r, g, b, currentBeamAlpha)
                love.graphics.line(startX, startY, startX, startY - currentBeamHeight)
            end

            love.graphics.setLineWidth(2) -- Restaura largura para a linha da próxima elipse (se houver outra)
            -- <<< FIM NOVO >>>

            -- Desenha informações acima do portal (ajusta Y baseado no raio Y da elipse)
            local textY = portal.screenY - drawRadiusY - portalFontHeight * 2 - 5 -- <<< USA drawRadiusY
            local infoText = string.format("[%s] %s", portal.rank, portal.name)
            local timerText = formatTime(portal.timer)
            local infoWidth = portalFont:getWidth(infoText)
            local timerWidth = portalFont:getWidth(timerText)
            local infoTextX = portal.screenX - infoWidth / 2   -- <<< NOVO: X centralizado para info
            local timerTextX = portal.screenX - timerWidth / 2 -- <<< NOVO: X centralizado para timer

            -- Sombra do texto
            love.graphics.setColor(colors.black[1], colors.black[2], colors.black[3], 0.7)
            love.graphics.print(infoText, infoTextX + 1, textY + 1)                      -- <<< USA infoTextX
            love.graphics.print(timerText, timerTextX + 1, textY + portalFontHeight + 1) -- <<< USA timerTextX

            -- Texto principal
            love.graphics.setColor(portal.color)
            love.graphics.print(infoText, infoTextX, textY)                      -- <<< USA infoTextX
            love.graphics.setColor(colors.white)
            love.graphics.print(timerText, timerTextX, textY + portalFontHeight) -- <<< USA timerTextX
        end
    end
    love.graphics.setLineWidth(1) -- Reseta largura da linha
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
  Funções Auxiliares de Serialização/Deserialização Simples
---------------------------------------------------------------------------]]

--- Converte um valor Lua simples para sua representação em string Lua.
--- Suporta nil, boolean, number, string e tabelas (recursivamente, sem ciclos).
---@param value any Valor a ser serializado.
---@return string String representando o valor em código Lua.
local function serializeValue(value)
    local t = type(value)
    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return tostring(value)
    elseif t == "number" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value) -- Usa aspas e escapa caracteres
    elseif t == "table" then
        local parts = {}
        -- Verifica se é array ou tabela chave-valor (simplificado)
        local is_array = true
        local count = 0
        for k, _ in pairs(value) do
            count = count + 1
            if type(k) ~= "number" or k < 1 or k > #value then
                is_array = false
            end
        end
        if #value ~= count then is_array = false end

        if is_array then
            for i = 1, #value do
                table.insert(parts, serializeValue(value[i]))
            end
        else
            for k, v in pairs(value) do
                -- Assume que chaves são strings ou números válidos como identificadores se possível
                local keyStr
                if type(k) == "string" and k:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. serializeValue(k) .. "]"
                end
                table.insert(parts, keyStr .. " = " .. serializeValue(v))
            end
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        error("Tipo não suportado para serialização: " .. t)
    end
end

--- Tenta deserializar uma string Lua em um valor Lua.
--- ATENÇÃO: Usa loadstring, que pode ser inseguro se a string vier de fontes não confiáveis.
---@param str string String Lua a ser deserializada (espera-se que retorne um valor).
---@return any Valor deserializado ou nil em caso de erro.
local function deserializeString(str)
    local func, err = loadstring("return " .. str) -- Adiciona 'return' para obter o valor
    if not func then
        print("Erro ao carregar string para deserialização: ", err)
        return nil
    end
    local success, valueOrErr = pcall(func)
    if not success then
        print("Erro ao executar string para deserialização: ", valueOrErr)
        return nil
    end
    return valueOrErr
end

--[[---------------------------------------------------------------------------
  Funções de Salvamento e Carregamento de Portais
---------------------------------------------------------------------------]]
LobbyPortalManager.saveFilePath = "portals_save.dat"

--- Salva o estado atual dos portais e o timestamp.
function LobbyPortalManager:savePortals()
    print("LobbyPortalManager: savePortals() - Iniciando salvamento...")
    local saveData = {
        timestamp = os.time(),
        portals = self.activePortals
    }

    print("LobbyPortalManager: savePortals() - Tentando serializar dados...")
    local serializeSuccess, resultOrError = pcall(serializeValue, saveData)

    if not serializeSuccess then
        print(string.format("LobbyPortalManager: savePortals() - ERRO ao serializar: %s", tostring(resultOrError)))
        return -- Aborta o salvamento
    end

    -- Se chegou aqui, serializeSuccess é true e resultOrError contém a string serializada
    local actualSerializedData = resultOrError
    print(string.format("LobbyPortalManager: savePortals() - Serialização bem-sucedida (tamanho: %d bytes).",
        #actualSerializedData))

    print(string.format("LobbyPortalManager: savePortals() - Tentando escrever em '%s'...", self.saveFilePath))
    local writeSuccess, w_err = love.filesystem.write(self.saveFilePath, actualSerializedData) -- <<< Usa a string correta
    if writeSuccess then
        print(string.format("LobbyPortalManager: savePortals() - Arquivo '%s' escrito com SUCESSO.", self.saveFilePath))
    else
        print(string.format("LobbyPortalManager: savePortals() - ERRO ao escrever arquivo '%s': %s", self.saveFilePath,
            tostring(w_err)))
    end
end

--- Carrega portais salvos e atualiza seus timers.
---@return PortalData[] Lista de portais carregados e ainda válidos.
function LobbyPortalManager:loadAndUpdatePortals()
    print("LobbyPortalManager: Tentando carregar portais salvos...")
    local loadedValidPortals = {} -- Começa com lista vazia

    local fileInfo = love.filesystem.getInfo(self.saveFilePath)

    if fileInfo and fileInfo.type == "file" and fileInfo.size > 0 then
        print(string.format("Arquivo de save '%s' encontrado.", self.saveFilePath))
        local content, read_err = love.filesystem.read(self.saveFilePath)
        if not content then
            print(string.format("ERRO ao ler arquivo de save '%s': %s. Nenhum portal carregado.", self.saveFilePath,
                tostring(read_err)))
            return loadedValidPortals -- Retorna lista vazia
        end

        print("Deserializando dados...")
        local savedData = deserializeString(content)

        if savedData and type(savedData) == "table" and savedData.timestamp and savedData.portals then
            local currentTime = os.time()
            local savedTimestamp = savedData.timestamp
            local elapsedTime = math.max(0, currentTime - savedTimestamp)
            print(string.format("Tempo desde último save: %d segundos.", elapsedTime))

            local loadedCount = 0
            local expiredCount = 0
            for _, portalData in ipairs(savedData.portals) do
                portalData.timer = portalData.timer - elapsedTime
                -- Importante: Resetar estado volátil
                portalData.isHovering = false
                portalData.screenX = 0
                portalData.screenY = 0
                if portalData.timer > 0 then
                    table.insert(loadedValidPortals, portalData) -- Adiciona à lista de retorno
                    loadedCount = loadedCount + 1
                else
                    expiredCount = expiredCount + 1
                end
            end
            print(string.format("Processados %d portais salvos. %d válidos, %d expiraram.", loadedCount + expiredCount,
                loadedCount, expiredCount))
        else
            print("ERRO: Formato de dados inválido no arquivo de save. Ignorando save.")
            -- Não retorna nada, resultando em lista vazia
        end
    else
        print(string.format("Arquivo de save '%s' não encontrado ou vazio.", self.saveFilePath))
        -- Não retorna nada, resultando em lista vazia
    end

    return loadedValidPortals -- Retorna a lista de portais carregados válidos
end

return LobbyPortalManager
