local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local PersistenceManager = require("src.core.persistence_manager")
local portalDefinitions = require("src.data.portals.portal_definitions")
local LobbyPortal = require("src.animations.lobby_portal")

--- Gerencia a criação, atualização e desenho dos portais no Lobby.
---@class LobbyPortalManager
---@field activePortals PortalInstanceData[]
---@field portalAnimations table<string, PortalAnimationConfig> Animações dos portais (indexadas por ID)
---@field mapW number Largura do mapa
---@field mapH number Altura do mapa
---@field proceduralMap LobbyMapPortals|nil Referência para o mapa procedural
local LobbyPortalManager = {}
LobbyPortalManager.__index = LobbyPortalManager

-- Configurações
LobbyPortalManager.DEFAULT_NUM_PORTALS = 7
LobbyPortalManager.PORTAL_INTERACT_RADIUS = 10

local CONTINENT_SPAWN_MARGIN = 200
local MIN_PORTAL_DISTANCE = 300

local MIN_STRUCTURE_DISTANCE = 150 -- Distância mínima dos portais das estruturas

---@alias PortalInstanceData { id:string, name:string, rank:string, theme:string, mapX:number, mapY:number, screenX:number, screenY:number, color: {number}, radius:number, isHovering:boolean }

-- Cria uma nova instância
function LobbyPortalManager:new()
    local instance = setmetatable({}, LobbyPortalManager)
    instance.activePortals = {}
    instance.portalAnimations = {}
    instance.mapW = 0
    instance.mapH = 0
    instance.proceduralMap = nil

    -- Carregar assets das animações de portal
    local assetsLoaded = LobbyPortal.loadAssets()
    if assetsLoaded then
        Logger.info("lobby_portal_manager.new", "[LobbyPortalManager] Assets de portais carregados com sucesso")
    else
        Logger.error("lobby_portal_manager.new", "[LobbyPortalManager] Falha ao carregar assets de portais")
    end

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

    -- Verificar se mapa procedural está pronto, senão usar fallback
    if self.proceduralMap and not self.proceduralMap:isGenerationComplete() then
        Logger.info("lobby_portal_manager.initialize.waiting",
            "[LobbyPortalManager] Mapa procedural não pronto, usando posicionamento de tela como fallback")
        self:_generatePortalsScreenBased()
        return
    end

    self:_generatePortalPositions()
end

--- Gera as posições dos portais dentro do continente procedural
function LobbyPortalManager:_generatePortalPositions()
    Logger.info("lobby_portal_manager._generatePortalPositions.start",
        "[LobbyPortalManager] Iniciando geração de posições de portais")

    if not self.proceduralMap then
        Logger.warn("lobby_portal_manager._generatePortalPositions",
            "[LobbyPortalManager] Mapa procedural não disponível, usando posicionamento de tela")
        self:_generatePortalsScreenBased()
        return
    end

    Logger.info("lobby_portal_manager._generatePortalPositions",
        "[LobbyPortalManager] Gerando portais dentro do continente procedural")

    -- Debug: verificar quantas definições de portais existem
    local portalDefCount = 0
    for _ in pairs(portalDefinitions) do
        portalDefCount = portalDefCount + 1
    end
    Logger.info("lobby_portal_manager._generatePortalPositions.definitions",
        "[LobbyPortalManager] Encontradas " .. portalDefCount .. " definições de portais")

    local portalCount = 0
    local maxAttempts = 10000

    for portalId, definition in pairs(portalDefinitions) do
        Logger.info("lobby_portal_manager._generatePortalPositions.processing",
            "[LobbyPortalManager] Processando portal: " .. portalId .. " (" .. definition.name .. ")")

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
                        -- Verificar distância mínima das estruturas
                        if self:_isValidStructureDistance(x, y) then
                            local portalInstance = {
                                id = portalId,
                                name = definition.name,
                                rank = definition.rank,
                                theme = definition.theme or "default",
                                mapX = x,
                                mapY = y,
                                screenX = 0, -- Será calculado no update/draw
                                screenY = 0, -- Será calculado no update/draw
                                color = colors.rankDetails[definition.rank] and colors.rankDetails[definition.rank].text or
                                    colors.white,
                                radius = LobbyPortalManager.PORTAL_INTERACT_RADIUS,
                                isHovering = false,
                            }

                            table.insert(self.activePortals, portalInstance)

                            -- Criar animação para o portal
                            self:_createPortalAnimation(portalInstance)

                            portalPlaced = true
                            portalCount = portalCount + 1

                            Logger.info("lobby_portal_manager._generatePortalPositions.portal",
                                string.format(
                                    "[LobbyPortalManager] Portal '%s' (%s) posicionado em (%.0f, %.0f) após %d tentativas",
                                    portalInstance.name, portalInstance.rank, x, y, attempts))
                        end
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

--- Verifica se a distância das estruturas é válida
---@param x number Coordenada X
---@param y number Coordenada Y
---@return boolean isValid Se a distância é válida
function LobbyPortalManager:_isValidStructureDistance(x, y)
    if not self.proceduralMap or not self.proceduralMap.structures then
        return true -- Se não há estruturas, a posição é válida
    end

    for _, structure in ipairs(self.proceduralMap.structures) do
        local dist = math.sqrt((x - structure.x) ^ 2 + (y - structure.y) ^ 2)
        if dist < MIN_STRUCTURE_DISTANCE then
            return false
        end
    end
    return true
end

--- Cria animação para um portal
---@param portalInstance PortalInstanceData Dados do portal
function LobbyPortalManager:_createPortalAnimation(portalInstance)
    Logger.info("lobby_portal_manager._createPortalAnimation.start",
        string.format("[LobbyPortalManager] Tentando criar animação para portal '%s'", portalInstance.id))

    if not LobbyPortal.areAssetsLoaded() then
        Logger.warn("lobby_portal_manager._createPortalAnimation",
            "[LobbyPortalManager] Assets não carregados, não é possível criar animação para portal '" ..
            portalInstance.id .. "'")
        return
    end

    -- Criar configuração da animação com cor baseada no rank
    local success, animConfig = pcall(LobbyPortal.createInstance, {
        position = { x = portalInstance.mapX, y = portalInstance.mapY },
        scale = 0.8, -- Escala um pouco menor que o padrão
        color = {
            portalInstance.color[1] or 1,
            portalInstance.color[2] or 1,
            portalInstance.color[3] or 1
        },
        alpha = 0.9
    })

    if not success then
        Logger.error("lobby_portal_manager._createPortalAnimation.error",
            string.format("[LobbyPortalManager] Erro ao criar instância de animação para portal '%s': %s",
                portalInstance.id, tostring(animConfig)))
        return
    end

    -- Armazenar a animação indexada pelo ID do portal
    self.portalAnimations[portalInstance.id] = animConfig

    Logger.info("lobby_portal_manager._createPortalAnimation.success",
        string.format("[LobbyPortalManager] Animação criada com sucesso para portal '%s'. Total de animações: %d",
            portalInstance.id, self:_countAnimations()))
end

--- Fallback para posicionamento baseado em tela (quando mapa procedural não está disponível)
function LobbyPortalManager:_generatePortalsScreenBased()
    Logger.info("lobby_portal_manager._generatePortalsScreenBased",
        "[LobbyPortalManager] Usando posicionamento fixo na TELA como fallback")
    self.activePortals = {} -- Limpar para garantir
    self.portalAnimations = {}

    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    -- Posições fixas na tela para garantir visibilidade
    local screenPositions = {
        { x = screenW * 0.25, y = screenH * 0.35 },
        { x = screenW * 0.75, y = screenH * 0.35 },
        { x = screenW * 0.50, y = screenH * 0.50 },
        { x = screenW * 0.35, y = screenH * 0.70 },
        { x = screenW * 0.65, y = screenH * 0.70 },
    }

    local portalCount = 0
    for portalId, definition in pairs(portalDefinitions) do
        portalCount = portalCount + 1
        if portalCount > #screenPositions then break end -- Não criar mais do que temos posições

        local screenPos = screenPositions[portalCount]

        local portalInstance = {
            id = portalId,
            name = definition.name,
            rank = definition.rank,
            theme = definition.theme or "default",
            mapX = 0,
            mapY = 0,
            screenX = screenPos.x,
            screenY = screenPos.y,
            isScreenSpace = true, -- Flag para ignorar transformações do mapa
            color = (colors.rankDetails[definition.rank] and colors.rankDetails[definition.rank].text) or colors.white,
            radius = 50,          -- Raio de interação fixo para portais de tela
            isHovering = false,
        }
        table.insert(self.activePortals, portalInstance)
        self:_createPortalAnimation(portalInstance)

        Logger.info("lobby_portal_manager._generatePortalsScreenBased.portal",
            string.format("[LobbyPortalManager] Portal '%s' (%s) criado em TELA(%.0f, %.0f)",
                portalInstance.name, portalInstance.rank, screenPos.x, screenPos.y))
    end

    Logger.info("lobby_portal_manager._generatePortalsScreenBased.complete",
        string.format("[LobbyPortalManager] %d portais criados com posicionamento de tela.", #self.activePortals))
end

--- Tenta reposicionar portais quando o mapa procedural fica disponível
function LobbyPortalManager:tryRepositionPortals()
    if not self.proceduralMap or not self.proceduralMap:isGenerationComplete() then
        return false
    end

    if #self.activePortals > 0 then
        Logger.info("lobby_portal_manager.tryRepositionPortals",
            "[LobbyPortalManager] Reposicionando portais para o continente procedural")

        -- Limpar animações antigas antes de reposicionar
        self.portalAnimations = {}

        self:_generatePortalPositions()
        return true
    end

    return false
end

-- Atualiza o estado de hover dos portais e animações
function LobbyPortalManager:update(dt, mx, my, allowPortalHover, mapScale, mapDrawX, mapDrawY)
    -- Garantir que sempre haja portais criados
    if #self.activePortals == 0 then
        Logger.info("lobby_portal_manager.update.no_portals",
            "[LobbyPortalManager] Nenhum portal ativo, forçando criação...")
        if self.proceduralMap and self.proceduralMap:isGenerationComplete() then
            Logger.info("lobby_portal_manager.update.repositioning",
                "[LobbyPortalManager] Tentando reposicionar portais...")
            self:tryRepositionPortals()
        else
            Logger.info("lobby_portal_manager.update.fallback",
                "[LobbyPortalManager] Usando fallback para criar portais...")
            self:_generatePortalsScreenBased()
        end
    end

    -- Atualizar animações dos portais
    local animCount = 0
    for portalId, animConfig in pairs(self.portalAnimations) do
        animCount = animCount + 1
        LobbyPortal.update(animConfig, dt)
    end

    -- Log periódico das animações
    if love.timer.getTime() % 3 < 0.016 and animCount > 0 then -- A cada 3 segundos
        Logger.info("lobby_portal_manager.update.animations",
            string.format("[LobbyPortalManager] Atualizando %d animações de portais", animCount))
    end

    if allowPortalHover then
        for i, portal in ipairs(self.activePortals) do
            -- Apenas recalcular posição de tela para portais do MAPA
            if not portal.isScreenSpace then
                portal.screenX = mapDrawX + portal.mapX * mapScale
                portal.screenY = mapDrawY + portal.mapY * mapScale
            end

            -- Atualizar posição da animação correspondente
            local animConfig = self.portalAnimations[portal.id]
            if animConfig then
                animConfig.position.x = portal.screenX
                animConfig.position.y = portal.screenY

                -- Escala da animação depende se é tela ou mapa
                if portal.isScreenSpace then
                    animConfig.scale = 0.8
                else
                    animConfig.scale = 0.8 * mapScale
                end
            end

            -- Raio de hover também precisa ser ajustado
            local hoverScale = portal.isScreenSpace and 1.0 or mapScale
            local effectiveRadius = 30 * hoverScale
            local distSq = (mx - portal.screenX) ^ 2 + (my - portal.screenY) ^ 2
            portal.isHovering = distSq <= (effectiveRadius * effectiveRadius)
        end
    else
        for _, portal in ipairs(self.activePortals) do
            portal.isHovering = false
        end
    end
end

--- Desenha os portais ativos no mapa usando as animações.
---@param mapScale number Escala atual de desenho do mapa.
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado.
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado.
---@param selectedPortalData PortalData|nil Dados do portal atualmente selecionado na cena (para destaque/escala).
function LobbyPortalManager:draw(mapScale, mapDrawX, mapDrawY, selectedPortalData)
    -- PORTAL DE TESTE PARA DEBUG (sempre visível)
    self:drawTestPortal()

    if not LobbyPortal.areAssetsLoaded() then
        Logger.warn("lobby_portal_manager.draw", "[LobbyPortalManager] Assets não carregados, usando desenho placeholder")
        self:_drawPortalsPlaceholder(mapScale, mapDrawX, mapDrawY, selectedPortalData)
        return
    end

    local portalFont = fonts.main_small or fonts.main
    local portalFontHeight = portalFont:getHeight()
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    love.graphics.setFont(portalFont)

    local portalsDrawn = 0
    local portalsSkipped = 0

    for i, portal in ipairs(self.activePortals) do
        local isSelected = selectedPortalData and (portal.id == selectedPortalData.id)
        local animConfig = self.portalAnimations[portal.id]

        if animConfig then
            -- Log detalhado das coordenadas para debug
            if love.timer.getTime() % 1 < 0.016 then -- Log a cada 1 segundo
                Logger.info("lobby_portal_manager.draw.coords_debug",
                    string.format(
                        "[LobbyPortalManager] Portal '%s': mapX=%.0f, mapY=%.0f, screenX=%.0f, screenY=%.0f, mapScale=%.3f, drawX=%.0f, drawY=%.0f",
                        portal.id, portal.mapX, portal.mapY, portal.screenX, portal.screenY, mapScale, mapDrawX, mapDrawY))
            end

            -- Otimização: verificar se está visível na tela
            local checkRadius = (portal.isScreenSpace and 50) or (60 * mapScale) -- Raio estimado da animação
            local isVisible = portal.screenX >= -checkRadius and portal.screenX <= screenW + checkRadius and
                portal.screenY >= -checkRadius and portal.screenY <= screenH + checkRadius

            if isVisible then
                -- Ajustar transparência e escala se selecionado
                local baseScale = portal.isScreenSpace and 0.8 or (0.8 * mapScale)
                if isSelected then
                    animConfig.alpha = 1.0
                    animConfig.scale = baseScale * 1.2
                else
                    animConfig.alpha = 0.9
                    animConfig.scale = baseScale
                end

                -- Desenhar animação do portal
                local success, error = pcall(LobbyPortal.draw, animConfig)
                if success then
                    portalsDrawn = portalsDrawn + 1
                else
                    Logger.error("lobby_portal_manager.draw.portal_error",
                        string.format("[LobbyPortalManager] Erro ao desenhar portal '%s': %s",
                            portal.id, tostring(error)))
                end

                -- Desenhar texto "Portal Ranking X" acima do portal (somente se NÃO selecionado)
                if not isSelected then
                    local textY = portal.screenY - checkRadius - portalFontHeight - 5
                    local portalText = string.format("Portal %s", portal.rank)
                    local textWidth = portalFont:getWidth(portalText)
                    local textX = portal.screenX - textWidth / 2

                    -- Sombra do texto
                    love.graphics.setColor(colors.black[1], colors.black[2], colors.black[3], 0.8)
                    love.graphics.print(portalText, textX + 2, textY + 2)

                    -- Texto principal com cor do ranking
                    local rankColor = colors.rankDetails[portal.rank] and colors.rankDetails[portal.rank].text or
                        colors.white
                    love.graphics.setColor(rankColor[1], rankColor[2], rankColor[3], rankColor[4] or 1.0)
                    love.graphics.print(portalText, textX, textY)
                end
            else
                portalsSkipped = portalsSkipped + 1
            end
        else
            Logger.warn("lobby_portal_manager.draw.no_animation",
                string.format("[LobbyPortalManager] Portal '%s' não tem animação configurada", portal.id))
        end
    end

    -- Log ocasional dos resultados apenas se interessante
    if love.timer.getTime() % 5 < 0.016 and (portalsDrawn > 0 or portalsSkipped ~= #self.activePortals) then
        Logger.info("lobby_portal_manager.draw.results",
            string.format("[LobbyPortalManager] Renderização: %d portais desenhados, %d fora da tela",
                portalsDrawn, portalsSkipped))
    end

    -- Resetar cor
    love.graphics.setColor(colors.white)
end

--- Desenha portais usando sistema antigo como fallback
---@param mapScale number Escala atual de desenho do mapa
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado
---@param selectedPortalData PortalData|nil Dados do portal atualmente selecionado
function LobbyPortalManager:_drawPortalsPlaceholder(mapScale, mapDrawX, mapDrawY, selectedPortalData)
    local portalFont = fonts.main_small or fonts.main
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    love.graphics.setFont(portalFont)

    for i, portal in ipairs(self.activePortals) do
        local isSelected = selectedPortalData and (portal.id == selectedPortalData.id)
        local baseRadius = isSelected and 25 or 20
        local checkRadius = baseRadius * mapScale

        -- Só desenha se visível
        if portal.screenX >= -checkRadius and portal.screenX <= screenW + checkRadius and
            portal.screenY >= -checkRadius and portal.screenY <= screenH + checkRadius then
            local r, g, b = portal.color[1], portal.color[2], portal.color[3]

            -- Círculo placeholder
            love.graphics.setColor(r, g, b, 0.7)
            love.graphics.circle("fill", portal.screenX, portal.screenY, baseRadius * mapScale)
            love.graphics.setColor(r * 1.2, g * 1.2, b * 1.2, 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", portal.screenX, portal.screenY, baseRadius * mapScale)

            -- Texto
            if not isSelected then
                local portalText = string.format("Portal %s", portal.rank)
                local textWidth = portalFont:getWidth(portalText)
                local textX = portal.screenX - textWidth / 2
                local textY = portal.screenY - checkRadius - portalFont:getHeight() - 5

                -- Sombra
                love.graphics.setColor(colors.black[1], colors.black[2], colors.black[3], 0.8)
                love.graphics.print(portalText, textX + 2, textY + 2)

                -- Texto
                love.graphics.setColor(r, g, b, 1.0)
                love.graphics.print(portalText, textX, textY)
            end
        end
    end

    love.graphics.setColor(colors.white)
    love.graphics.setLineWidth(1)
end

-- Retorna dados do portal clicado, se houver (baseado na área da animação)
---@param x number Posição X do mouse na tela.
---@param y number Posição Y do mouse na tela.
---@param mapScale number Escala atual de desenho do mapa.
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado.
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado.
---@return PortalInstanceData|nil Retorna a instância do portal clicado ou nil.
function LobbyPortalManager:handleMouseClick(x, y, mapScale, mapDrawX, mapDrawY)
    for _, portal in ipairs(self.activePortals) do
        local currentScreenX, currentScreenY
        if portal.isScreenSpace then
            currentScreenX = portal.screenX
            currentScreenY = portal.screenY
        else
            -- Calcula a posição do portal na tela AGORA
            currentScreenX = mapDrawX + portal.mapX * mapScale
            currentScreenY = mapDrawY + portal.mapY * mapScale
        end

        -- Verifica clique usando raio da animação completa
        local clickScale = portal.isScreenSpace and 1.0 or mapScale
        local animationRadius = 50 * clickScale
        local distSq = (x - currentScreenX) ^ 2 + (y - currentScreenY) ^ 2

        if distSq <= (animationRadius * animationRadius) then
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

--- Função helper para contar animações
---@return number Número de animações carregadas
function LobbyPortalManager:_countAnimations()
    local count = 0
    for _ in pairs(self.portalAnimations) do
        count = count + 1
    end
    return count
end

--- Força a criação de portais (função de debug/teste)
function LobbyPortalManager:forceCreatePortals()
    Logger.info("lobby_portal_manager.forceCreatePortals", "[LobbyPortalManager] Forçando criação de portais...")

    self.activePortals = {}    -- Limpar portais existentes
    self.portalAnimations = {} -- Limpar animações existentes

    -- Sempre usar o sistema de fallback para garantir que funcione
    self:_generatePortalsScreenBased()

    Logger.info("lobby_portal_manager.forceCreatePortals.complete",
        string.format("[LobbyPortalManager] Criação forçada completa. Portais criados: %d, Animações: %d",
            #self.activePortals, self:_countAnimations()))
end

--- Força portais em posições bem visíveis (função de debug extremo)
function LobbyPortalManager:forceVisiblePortals()
    Logger.info("lobby_portal_manager.forceVisiblePortals",
        "[LobbyPortalManager] Forçando portais em posições bem visíveis...")

    self.activePortals = {}    -- Limpar portais existentes
    self.portalAnimations = {} -- Limpar animações existentes

    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()
    local centerMapX = self.mapW / 2
    local centerMapY = self.mapH / 2

    -- Posições fixas bem visíveis ao redor do centro
    local positions = {
        { x = centerMapX,       y = centerMapY - 200 }, -- Norte
        { x = centerMapX + 200, y = centerMapY },       -- Leste
        { x = centerMapX,       y = centerMapY + 200 }, -- Sul
        { x = centerMapX - 200, y = centerMapY },       -- Oeste
        { x = centerMapX,       y = centerMapY }        -- Centro
    }

    local posIndex = 1
    for portalId, definition in pairs(portalDefinitions) do
        local pos = positions[posIndex] or positions[1]
        posIndex = posIndex + 1

        local portalInstance = {
            id = portalId,
            name = definition.name,
            rank = definition.rank,
            theme = definition.theme or "default",
            mapX = pos.x,
            mapY = pos.y,
            screenX = 0,
            screenY = 0,
            color = colors.rankDetails[definition.rank] and colors.rankDetails[definition.rank].text or colors.white,
            radius = LobbyPortalManager.PORTAL_INTERACT_RADIUS,
            isHovering = false,
        }

        table.insert(self.activePortals, portalInstance)
        self:_createPortalAnimation(portalInstance)

        Logger.info("lobby_portal_manager.forceVisiblePortals.portal",
            string.format("[LobbyPortalManager] Portal '%s' (%s) forçado em MAPA(%.0f, %.0f)",
                portalInstance.name, portalInstance.rank, pos.x, pos.y))
    end

    Logger.info("lobby_portal_manager.forceVisiblePortals.complete",
        string.format("[LobbyPortalManager] %d portais forçados em posições visíveis. Animações: %d",
            #self.activePortals, self:_countAnimations()))
end

--- Força portais diretamente em coordenadas de tela (bypass do sistema de mapa)
function LobbyPortalManager:forceScreenPortals()
    Logger.info("lobby_portal_manager.forceScreenPortals",
        "[LobbyPortalManager] Forçando portais diretamente em coordenadas de tela...")

    self.activePortals = {}    -- Limpar portais existentes
    self.portalAnimations = {} -- Limpar animações existentes

    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    -- Posições DIRETAS na tela (visíveis garantidamente)
    local screenPositions = {
        { x = screenW * 0.2, y = screenH * 0.3 }, -- Esquerda-superior
        { x = screenW * 0.8, y = screenH * 0.3 }, -- Direita-superior
        { x = screenW * 0.5, y = screenH * 0.5 }, -- Centro
        { x = screenW * 0.3, y = screenH * 0.7 }, -- Esquerda-inferior
        { x = screenW * 0.7, y = screenH * 0.7 }  -- Direita-inferior
    }

    local posIndex = 1
    local createdCount = 0

    for portalId, definition in pairs(portalDefinitions) do
        Logger.info("lobby_portal_manager.forceScreenPortals.processing",
            string.format("[LobbyPortalManager] Processando portal %d: '%s' (%s)",
                posIndex, portalId, definition.name))

        local screenPos = screenPositions[posIndex] or screenPositions[1]
        posIndex = posIndex + 1

        local success, result = pcall(function()
            local portalInstance = {
                id = portalId,
                name = definition.name,
                rank = definition.rank,
                theme = definition.theme or "default",
                mapX = screenPos.x,    -- Usar coordenadas de tela como se fossem mapa
                mapY = screenPos.y,
                screenX = screenPos.x, -- Definir diretamente as coordenadas de tela
                screenY = screenPos.y,
                color = (colors.rankDetails[definition.rank] and colors.rankDetails[definition.rank].text) or
                    colors.white,
                radius = LobbyPortalManager.PORTAL_INTERACT_RADIUS,
                isHovering = false,
            }

            table.insert(self.activePortals, portalInstance)

            -- Criar animação com proteção
            local animSuccess, animError = pcall(self._createPortalAnimation, self, portalInstance)
            if not animSuccess then
                Logger.error("lobby_portal_manager.forceScreenPortals.animation_error",
                    string.format("[LobbyPortalManager] Erro ao criar animação: %s", tostring(animError)))
            end

            Logger.info("lobby_portal_manager.forceScreenPortals.portal",
                string.format("[LobbyPortalManager] Portal '%s' (%s) forçado em TELA(%.0f, %.0f)",
                    portalInstance.name, portalInstance.rank, screenPos.x, screenPos.y))

            createdCount = createdCount + 1
            return true
        end)

        if not success then
            Logger.error("lobby_portal_manager.forceScreenPortals.error",
                string.format("[LobbyPortalManager] ERRO ao criar portal '%s': %s", portalId, tostring(result)))
        end
    end

    Logger.info("lobby_portal_manager.forceScreenPortals.complete",
        string.format("[LobbyPortalManager] %d/%d portais criados com sucesso. Animações: %d",
            createdCount, posIndex - 1, self:_countAnimations()))
end

--- Desenha um portal de teste diretamente na tela (para debug)
function LobbyPortalManager:drawTestPortal()
    if not LobbyPortal.areAssetsLoaded() then
        -- Desenhar círculo simples se assets não carregados
        love.graphics.setColor(1, 0, 1, 1) -- Magenta
        love.graphics.circle("fill", 400, 300, 50)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("PORTAL TEST (NO ASSETS)", 300, 250)
        return
    end

    -- Usar configuração persistente para manter a animação entre frames
    if not self.testPortalConfig then
        self.testPortalConfig = LobbyPortal.createInstance({
            position = { x = 400, y = 300 },
            scale = 1.0,
            color = { 1, 0, 1 }, -- Magenta
            alpha = 1.0
        })
        Logger.info("lobby_portal_manager.drawTestPortal.init",
            "[LobbyPortalManager] Portal de teste criado com frame inicial: " ..
            self.testPortalConfig.animation.currentFrame)
    end

    -- Atualizar a animação
    LobbyPortal.update(self.testPortalConfig, love.timer.getDelta())

    -- Desenhar
    local success, error = pcall(LobbyPortal.draw, self.testPortalConfig)
    if not success then
        Logger.error("lobby_portal_manager.drawTestPortal",
            "[LobbyPortalManager] Erro ao desenhar portal de teste: " .. tostring(error))

        -- Fallback: círculo simples
        love.graphics.setColor(1, 0, 1, 1)
        love.graphics.circle("fill", 400, 300, 50)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("FALLBACK TEST", 350, 250)
    else
        -- Texto de confirmação com frame atual
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(string.format("ANIMATION TEST - Frame: %d/10",
            self.testPortalConfig.animation.currentFrame), 300, 250)

        -- Log periódico do frame
        if love.timer.getTime() % 1 < 0.016 then -- A cada 1 segundo
            Logger.info("lobby_portal_manager.drawTestPortal.frame",
                string.format("[LobbyPortalManager] Portal de teste - Frame: %d, Timer: %.3f",
                    self.testPortalConfig.animation.currentFrame, self.testPortalConfig.animation.timer))
        end
    end
end

-- Expor funções de debug globalmente
_G.LobbyPortalManagerClass = LobbyPortalManager

-- Função global para fácil acesso via console
_G.DebugPortalsScreen = function()
    -- Tentar diferentes formas de acessar o portal manager
    local manager = nil

    if LobbyScene and LobbyScene.portalManager then
        manager = LobbyScene.portalManager
    elseif _G.LobbyScene and _G.LobbyScene.portalManager then
        manager = _G.LobbyScene.portalManager
    end

    if manager then
        Logger.info("debug.forceScreenPortals", "[DEBUG] Forçando portais diretamente na tela...")
        manager:forceScreenPortals()
    else
        Logger.error("debug.forceScreenPortals", "[DEBUG] LobbyScene ou portalManager não disponível")
        Logger.info("debug.forceScreenPortals.fallback", "[DEBUG] Tentando acessar via SceneManager...")

        -- Tentar via SceneManager
        if SceneManager and SceneManager.currentScene and SceneManager.currentScene.portalManager then
            Logger.info("debug.forceScreenPortals.scene_manager", "[DEBUG] Encontrado via SceneManager!")
            SceneManager.currentScene.portalManager:forceScreenPortals()
        end
    end
end

_G.DebugPortalsVisible = function()
    if LobbyScene and LobbyScene.portalManager then
        Logger.info("debug.forceVisiblePortals", "[DEBUG] Forçando portais em posições visíveis...")
        LobbyScene.portalManager:forceVisiblePortals()
    else
        Logger.error("debug.forceVisiblePortals", "[DEBUG] LobbyScene ou portalManager não disponível")
    end
end

_G.DebugPortalsInfo = function()
    if LobbyScene and LobbyScene.portalManager then
        local manager = LobbyScene.portalManager
        Logger.info("debug.portalsInfo", string.format(
            "[DEBUG] Portais ativos: %d, Animações: %d",
            #manager.activePortals, manager:_countAnimations()))

        for i, portal in ipairs(manager.activePortals) do
            Logger.info("debug.portalInfo", string.format(
                "[DEBUG] Portal %d: '%s' (%s) - MAPA(%.0f, %.0f) TELA(%.0f, %.0f)",
                i, portal.name, portal.rank, portal.mapX, portal.mapY, portal.screenX, portal.screenY))
        end

        for portalId, animConfig in pairs(manager.portalAnimations) do
            Logger.info("debug.animationInfo", string.format(
                "[DEBUG] Animação '%s': pos(%.0f, %.0f) scale(%.2f) alpha(%.2f) frame(%d)",
                portalId, animConfig.position.x, animConfig.position.y, animConfig.scale, animConfig.alpha,
                animConfig.animation.currentFrame))
        end
    else
        Logger.error("debug.portalsInfo", "[DEBUG] LobbyScene ou portalManager não disponível")
    end
end

_G.DebugPortalsManual = function()
    local portalDefinitions = require("src.data.portals.portal_definitions")

    if LobbyScene and LobbyScene.portalManager then
        local manager = LobbyScene.portalManager
        Logger.info("debug.createManual", "[DEBUG] Criando portais manualmente um por um...")

        -- Limpar tudo
        manager.activePortals = {}
        manager.portalAnimations = {}

        local positions = {
            { x = 300,  y = 200 },
            { x = 700,  y = 200 },
            { x = 1100, y = 200 },
            { x = 500,  y = 400 },
            { x = 900,  y = 400 }
        }

        local count = 0
        for portalId, definition in pairs(portalDefinitions) do
            count = count + 1
            if count > 5 then break end

            local pos = positions[count]
            Logger.info("debug.createManual.portal", string.format(
                "[DEBUG] Criando portal %d: '%s' em (%.0f, %.0f)", count, portalId, pos.x, pos.y))

            local portal = {
                id = portalId,
                name = definition.name,
                rank = definition.rank,
                theme = definition.theme or "default",
                mapX = pos.x,
                mapY = pos.y,
                screenX = pos.x,
                screenY = pos.y,
                color = { 1, 1, 1 },
                radius = 50,
                isHovering = false,
            }

            table.insert(manager.activePortals, portal)

            -- Criar animação
            local success, result = pcall(manager._createPortalAnimation, manager, portal)
            if success then
                Logger.info("debug.createManual.success", string.format(
                    "[DEBUG] Portal %d criado com sucesso", count))
            else
                Logger.error("debug.createManual.error", string.format(
                    "[DEBUG] Erro ao criar portal %d: %s", count, tostring(result)))
            end
        end

        Logger.info("debug.createManual.complete", string.format(
            "[DEBUG] Criação manual completa. Portais: %d, Animações: %d",
            #manager.activePortals, manager:_countAnimations()))
    else
        Logger.error("debug.createManual", "[DEBUG] LobbyScene ou portalManager não disponível")
    end
end

return LobbyPortalManager
