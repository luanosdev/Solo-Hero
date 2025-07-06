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
        local debugAttempts = {}

        while not portalPlaced and attempts < maxAttempts do
            attempts = attempts + 1

            -- Gerar posição aleatória dentro dos limites do mapa virtual
            -- Priorizar área visível da câmera para garantir que portais sejam visíveis
            local x, y
            if attempts <= maxAttempts * 0.95 then -- 95% das tentativas na área visível
                x, y = self:_generateVisiblePosition()
            else
                x = love.math.random() * self.mapW
                y = love.math.random() * self.mapH
            end

            local reason = "unknown"

            -- Verificar se está dentro do continente
            if self.proceduralMap:isPointInContinent(x, y) then
                -- Verificar margem de segurança das bordas do continente
                if self:_isPositionSafeFromEdges(x, y) then
                    -- Verificar distância mínima de outros portais
                    if self:_isValidPortalDistance(x, y) then
                        -- Verificar distância mínima das estruturas
                        if self:_isValidStructureDistance(x, y) then
                            -- Verificar se realmente estará visível na tela
                            if self:_isPositionVisibleOnScreen(x, y) then
                                local portalInstance = {
                                    id = portalId,
                                    name = definition.name,
                                    rank = definition.rank,
                                    theme = definition.theme or "default",
                                    mapX = x,
                                    mapY = y,
                                    screenX = 0, -- Será calculado antes da criação da animação
                                    screenY = 0, -- Será calculado antes da criação da animação
                                    color = colors.rankDetails[definition.rank] and
                                        colors.rankDetails[definition.rank].text or
                                        colors.white,
                                    radius = LobbyPortalManager.PORTAL_INTERACT_RADIUS,
                                    isHovering = false,
                                    isScreenSpace = false, -- Marcar como portal do mapa
                                }

                                -- Calcular posição de tela ANTES de criar a animação
                                if self.proceduralMap then
                                    portalInstance.screenX, portalInstance.screenY = self.proceduralMap
                                        :getScreenPositionFromWorld(x, y)
                                else
                                    portalInstance.screenX = x
                                    portalInstance.screenY = y
                                end

                                table.insert(self.activePortals, portalInstance)

                                -- Criar animação para o portal com posição de tela correta
                                self:_createPortalAnimation(portalInstance)

                                portalPlaced = true
                                portalCount = portalCount + 1

                                Logger.info("lobby_portal_manager._generatePortalPositions.portal",
                                    string.format(
                                        "[LobbyPortalManager] Portal '%s' (%s) posicionado em (%.0f, %.0f) após %d tentativas",
                                        portalInstance.name, portalInstance.rank, x, y, attempts))
                            else
                                reason = "muito próximo de estrutura"
                            end
                        else
                            reason = "fora da área visível"
                        end
                    else
                        reason = "muito próximo de outro portal"
                    end
                else
                    reason = "muito próximo da borda do continente"
                end
            else
                reason = "fora do continente"
            end

            -- Coletar estatísticas de debug
            if attempts <= 10 then
                table.insert(debugAttempts, { x = x, y = y, reason = reason })
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

--- Gera uma posição dentro da área visível da câmera
---@return number x Coordenada X
---@return number y Coordenada Y
function LobbyPortalManager:_generateVisiblePosition()
    if not self.proceduralMap then
        -- Fallback para posição aleatória se não há mapa procedural
        return love.math.random() * self.mapW, love.math.random() * self.mapH
    end

    -- Calcular área visível baseada na câmera ATUAL
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    -- Usar método do mapa procedural para converter coordenadas de tela para mundo
    -- Calcular os cantos da tela visível em coordenadas do mundo
    local corners = {
        topLeft = self:_screenToWorldPosition(0, 0),
        topRight = self:_screenToWorldPosition(screenW, 0),
        bottomLeft = self:_screenToWorldPosition(0, screenH),
        bottomRight = self:_screenToWorldPosition(screenW, screenH)
    }

    -- Calcular a área delimitadora (bounding box) da área visível
    local minX = math.min(corners.topLeft.x, corners.topRight.x, corners.bottomLeft.x, corners.bottomRight.x)
    local maxX = math.max(corners.topLeft.x, corners.topRight.x, corners.bottomLeft.x, corners.bottomRight.x)
    local minY = math.min(corners.topLeft.y, corners.topRight.y, corners.bottomLeft.y, corners.bottomRight.y)
    local maxY = math.max(corners.topLeft.y, corners.topRight.y, corners.bottomLeft.y, corners.bottomRight.y)

    -- Adicionar margem robusta para garantir visibilidade total
    local margin = 200 -- Margem maior para garantir visibilidade
    minX = math.max(0, minX + margin)
    maxX = math.min(self.mapW, maxX - margin)
    minY = math.max(0, minY + margin)
    maxY = math.min(self.mapH, maxY - margin)

    -- Verificar se a área visível é válida
    if minX >= maxX or minY >= maxY then
        -- Fallback: usar posição aleatória no mapa inteiro
        Logger.warn("lobby_portal_manager._generateVisiblePosition.fallback",
            "[LobbyPortalManager] Área visível inválida, usando posição aleatória")
        return love.math.random() * self.mapW, love.math.random() * self.mapH
    end

    -- Priorizar área central da tela (80% das vezes gera no centro, 20% nas bordas)
    local x, y
    if love.math.random() <= 0.8 then
        -- Gerar no terço central da área visível
        local centerMargin = (maxX - minX) * 0.25 -- 25% de margem de cada lado
        local centerMinX = minX + centerMargin
        local centerMaxX = maxX - centerMargin
        local centerMinY = minY + centerMargin
        local centerMaxY = maxY - centerMargin

        x = centerMinX + love.math.random() * (centerMaxX - centerMinX)
        y = centerMinY + love.math.random() * (centerMaxY - centerMinY)
    else
        -- Gerar na área visível completa
        x = minX + love.math.random() * (maxX - minX)
        y = minY + love.math.random() * (maxY - minY)
    end

    -- Garantir que está dentro dos limites do mapa
    x = math.max(0, math.min(self.mapW, x))
    y = math.max(0, math.min(self.mapH, y))

    return x, y
end

--- Converte coordenadas de tela para coordenadas do mundo usando o método do mapa procedural
---@param screenX number Coordenada X da tela
---@param screenY number Coordenada Y da tela
---@return table worldPos {x, y} Coordenadas do mundo
function LobbyPortalManager:_screenToWorldPosition(screenX, screenY)
    if not self.proceduralMap then
        return { x = screenX, y = screenY }
    end

    -- Obter informações de renderização do mapa procedural
    local mapScale, mapDrawX, mapDrawY = self.proceduralMap:getRenderInfo()

    -- Usar o método existente do mapa procedural para conversão
    local worldX, worldY = self.proceduralMap:_fromIso(screenX, screenY, mapScale, mapDrawX, mapDrawY)

    return { x = worldX, y = worldY }
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

--- Verifica se uma posição será realmente visível na tela com margem de segurança
---@param x number Coordenada X do mundo
---@param y number Coordenada Y do mundo
---@return boolean isVisible Se a posição está visível na tela
function LobbyPortalManager:_isPositionVisibleOnScreen(x, y)
    if not self.proceduralMap then
        return true -- Se não há mapa procedural, aceitar
    end

    -- Converter para coordenadas de tela
    local screenX, screenY = self.proceduralMap:getScreenPositionFromWorld(x, y)

    -- Obter dimensões da tela
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    -- Margem de segurança para garantir que está bem visível
    local safetyMargin = 100

    -- Verificar se está dentro da área segura da tela
    local isVisible = (screenX >= safetyMargin and
        screenX <= screenW - safetyMargin and
        screenY >= safetyMargin and
        screenY <= screenH - safetyMargin)

    return isVisible
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



    ---@type PortalAnimationConfig
    local portalAnimationConfig = {
        position = { x = portalInstance.screenX, y = portalInstance.screenY },
        color = {
            portalInstance.color[1] or 1,
            portalInstance.color[2] or 1,
            portalInstance.color[3] or 1,
        }
    }

    -- Criar configuração da animação com cor baseada no rank
    self.portalAnimations[portalInstance.id] = LobbyPortal.createInstance(portalAnimationConfig)

    -- Resetar valores originais salvos para garantir estado limpo
    portalInstance.originalAnimationValues = nil
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
            mapX = 0, -- TEMPORÁRIO: Será reposicionado quando mapa estiver pronto
            mapY = 0, -- TEMPORÁRIO: Será reposicionado quando mapa estiver pronto
            screenX = screenPos.x,
            screenY = screenPos.y,
            isScreenSpace = true, -- TEMPORÁRIO: Flag para marcar como portal de fallback
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

        -- Salvar IDs dos portais existentes para preservar as definições
        local existingPortalIds = {}
        for _, portal in ipairs(self.activePortals) do
            table.insert(existingPortalIds, portal.id)
        end

        -- Limpar portais e animações antigas
        self.activePortals = {}
        self.portalAnimations = {}

        -- Regenerar portais usando as definições salvas e posicionamento no continente
        Logger.info(
            "lobby_portal_manager.tryRepositionPortals.regenerating",
            "[LobbyPortalManager] Regenerando " .. #existingPortalIds .. " portais no continente"
        )

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

    -- Verificar se portais de fallback precisam ser reposicionados para o continente
    if self.proceduralMap and self.proceduralMap:isGenerationComplete() then
        local needsRepositioning = false
        for _, portal in ipairs(self.activePortals) do
            if portal.isScreenSpace or (portal.mapX == 0 and portal.mapY == 0) then
                needsRepositioning = true
                break
            end
        end

        if needsRepositioning then
            Logger.info("lobby_portal_manager.update.auto_reposition",
                "[LobbyPortalManager] Mapa procedural pronto, reposicionando portais de fallback...")
            self:tryRepositionPortals()
        end
    end

    -- Atualizar animações dos portais
    local animCount = 0
    local currentZoom = self.proceduralMap and self.proceduralMap.currentZoom or 1.0

    for portalId, animConfig in pairs(self.portalAnimations) do
        animCount = animCount + 1
        LobbyPortal.update(animConfig, dt)

        -- Aplicar escala baseada no zoom da câmera
        local baseScale = 0.5
        local zoomScale = math.max(0.5, math.min(2.0, currentZoom)) -- Limitar escala entre 0.5x e 2.0x
        animConfig.scale = baseScale * zoomScale
    end

    -- SEMPRE atualizar coordenadas de tela dos portais (independente do hover)
    for i, portal in ipairs(self.activePortals) do
        -- Recalcular posição de tela para portais do MAPA usando o sistema de coordenadas correto
        if not portal.isScreenSpace then
            if self.proceduralMap then
                -- Usar método do mapa procedural que aplica transformação isométrica correta
                portal.screenX, portal.screenY = self.proceduralMap:getScreenPositionFromWorld(portal.mapX,
                    portal.mapY)
            else
                -- Fallback para o sistema antigo se não há mapa procedural
                portal.screenX = mapDrawX + portal.mapX * mapScale
                portal.screenY = mapDrawY + portal.mapY * mapScale
            end
        end

        -- Atualizar posição da animação correspondente
        local animConfig = self.portalAnimations[portal.id]
        if animConfig then
            animConfig.position.x = portal.screenX
            animConfig.position.y = portal.screenY
        end
    end

    -- Atualizar hover apenas se permitido
    if allowPortalHover then
        for i, portal in ipairs(self.activePortals) do
            -- Raio de hover também precisa ser ajustado com escala dinâmica
            local hoverScale = portal.isScreenSpace and 1.0 or mapScale
            local zoomScale = math.max(0.5, math.min(2.0, currentZoom))
            local effectiveRadius = 30 * hoverScale * zoomScale
            local distSq = (mx - portal.screenX) ^ 2 + (my - portal.screenY) ^ 2
            portal.isHovering = distSq <= (effectiveRadius * effectiveRadius)
        end
    else
        for _, portal in ipairs(self.activePortals) do
            portal.isHovering = false
        end
    end
end

--- Calcula o buffer de visibilidade baseado no estado de zoom
---@return number visibilityBuffer Buffer de visibilidade em pixels
function LobbyPortalManager:_calculateVisibilityBuffer()
    if not self.proceduralMap then
        return 200 -- Buffer padrão
    end

    -- Verificar se está em transição de zoom
    local currentZoom = self.proceduralMap.currentZoom or 1.0
    local targetZoom = self.proceduralMap.targetZoom or 1.0
    local isZoomTransition = math.abs(currentZoom - targetZoom) > 0.01

    if isZoomTransition then
        -- Durante transições de zoom, usar buffer maior
        return 400
    elseif self.proceduralMap.isZoomedIn then
        -- Durante zoom, usar buffer médio
        return 300
    else
        -- Vista normal, buffer menor
        return 200
    end
end

--- Desenha os portais ativos no mapa usando as animações.
---@param mapScale number Escala atual de desenho do mapa.
---@param mapDrawX number Coordenada X do canto superior esquerdo do mapa desenhado.
---@param mapDrawY number Coordenada Y do canto superior esquerdo do mapa desenhado.
---@param selectedPortalData PortalData|nil Dados do portal atualmente selecionado na cena (para destaque/escala).
function LobbyPortalManager:draw(mapScale, mapDrawX, mapDrawY, selectedPortalData)
    if not LobbyPortal.areAssetsLoaded() then
        Logger.warn("lobby_portal_manager.draw", "[LobbyPortalManager] Assets não carregados, usando desenho placeholder")
        self:_drawPortalsPlaceholder(mapScale, mapDrawX, mapDrawY, selectedPortalData)
        return
    end

    local portalFont = fonts.main_bold
    local portalFontHeight = portalFont:getHeight()
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    love.graphics.setFont(portalFont)

    local portalsDrawn = 0
    local portalsSkipped = 0

    for i, portal in ipairs(self.activePortals) do
        local isSelected = selectedPortalData and (portal.id == selectedPortalData.id)
        local animConfig = self.portalAnimations[portal.id]

        -- Verificar e recriar animação se ausente
        if not animConfig then
            Logger.warn("lobby_portal_manager.draw.missing_animation",
                string.format("[LobbyPortalManager] Animação ausente para portal '%s', recriando...", portal.id))
            self:_createPortalAnimation(portal)
            animConfig = self.portalAnimations[portal.id]
        end

        if animConfig then
            -- Otimização: verificar se está visível na tela
            -- Durante zoom, expandir área de visibilidade para evitar portais desaparecendo
            local checkRadius = (portal.isScreenSpace and 50) or (60 * mapScale) -- Raio estimado da animação
            local visibilityBuffer = self:_calculateVisibilityBuffer()           -- Buffer dinâmico baseado no estado de zoom
            local isVisible = portal.screenX >= -checkRadius - visibilityBuffer and
                portal.screenX <= screenW + checkRadius + visibilityBuffer and
                portal.screenY >= -checkRadius - visibilityBuffer and
                portal.screenY <= screenH + checkRadius + visibilityBuffer

            if isVisible then
                -- Salvar valores originais da animação se ainda não foram salvos (apenas alpha, scale é dinâmica)
                if not portal.originalAnimationValues then
                    portal.originalAnimationValues = {
                        alpha = animConfig.alpha or 1.0
                    }
                end

                -- Ajustar transparência e escala se selecionado (sem modificar permanentemente)
                local drawAlpha = portal.originalAnimationValues.alpha
                local drawScale = animConfig.scale -- Usar escala atual (que já inclui zoom)

                if isSelected then
                    drawAlpha = 1.0
                    drawScale = animConfig.scale * 1.2 -- Amplificar escala atual (que já inclui zoom)
                end

                -- Aplicar temporariamente os valores para desenho
                local originalAlpha = animConfig.alpha
                local originalScale = animConfig.scale
                animConfig.alpha = drawAlpha
                animConfig.scale = drawScale



                -- Desenhar animação do portal
                local success, error = pcall(LobbyPortal.draw, animConfig)

                -- Restaurar valores originais imediatamente após desenho
                animConfig.alpha = originalAlpha
                animConfig.scale = originalScale

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
                    local portalText = portal.name
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

        -- Aplicar escala baseada no zoom da câmera
        local currentZoom = self.proceduralMap and self.proceduralMap.currentZoom or 1.0
        local zoomScale = math.max(0.5, math.min(2.0, currentZoom))
        local finalRadius = baseRadius * zoomScale
        local checkRadius = finalRadius * mapScale

        -- Só desenha se visível (com buffer para transições)
        local visibilityBuffer = self:_calculateVisibilityBuffer() -- Buffer dinâmico baseado no estado de zoom
        if portal.screenX >= -checkRadius - visibilityBuffer and portal.screenX <= screenW + checkRadius + visibilityBuffer and
            portal.screenY >= -checkRadius - visibilityBuffer and portal.screenY <= screenH + checkRadius + visibilityBuffer then
            local r, g, b = portal.color[1], portal.color[2], portal.color[3]



            -- Círculo placeholder
            love.graphics.setColor(r, g, b, 0.7)
            love.graphics.circle("fill", portal.screenX, portal.screenY, finalRadius * mapScale)
            love.graphics.setColor(r * 1.2, g * 1.2, b * 1.2, 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", portal.screenX, portal.screenY, finalRadius * mapScale)

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
            -- Calcula a posição do portal na tela usando o sistema de coordenadas correto
            if self.proceduralMap then
                -- Usar método do mapa procedural que aplica transformação isométrica correta
                currentScreenX, currentScreenY = self.proceduralMap:getScreenPositionFromWorld(portal.mapX, portal.mapY)
            else
                -- Fallback para o sistema antigo se não há mapa procedural
                currentScreenX = mapDrawX + portal.mapX * mapScale
                currentScreenY = mapDrawY + portal.mapY * mapScale
            end
        end

        -- Verifica clique usando raio da animação completa com escala dinâmica
        local clickScale = portal.isScreenSpace and 1.0 or mapScale
        local currentZoom = self.proceduralMap and self.proceduralMap.currentZoom or 1.0
        local zoomScale = math.max(0.5, math.min(2.0, currentZoom))
        local animationRadius = 50 * clickScale * zoomScale
        local distSq = (x - currentScreenX) ^ 2 + (y - currentScreenY) ^ 2

        if distSq <= (animationRadius * animationRadius) then
            -- Verificar se a animação do portal está intacta
            local animConfig = self.portalAnimations[portal.id]
            if not animConfig then
                Logger.warn("lobby_portal_manager.handleMouseClick.missing_animation",
                    "[LobbyPortalManager] Animação ausente para portal '" .. portal.name .. "', recriando...")
                self:_createPortalAnimation(portal)
            end

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

--- Limpa os valores originais salvos de um portal específico
---@param portalId string ID do portal
function LobbyPortalManager:_clearPortalSelectionState(portalId)
    for _, portal in ipairs(self.activePortals) do
        if portal.id == portalId then
            portal.originalAnimationValues = nil
            break
        end
    end
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

return LobbyPortalManager
