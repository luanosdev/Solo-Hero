---@class IsometricSimulator
---@field tileWidth number
---@field tileHeight number
---@field patchSize number
---@field tilesPerPatch number
---@field player PlayerData
---@field camera CameraData
---@field keys table<string, boolean>
---@field moveSpeed number
---@field font love.Font
---@field smallFont love.Font
---@field debugFont love.Font
---@field mapData table
---@field tiles table<number, love.Image>
---@field layerCanvases table<string, love.Canvas>
---@field canvasRenderData table
---@field isLoading boolean
---@field loadingProgress number
---@field buildCoroutine coroutine
---@field cullingSystem CullingSystem
local IsometricSimulator = {}
local Events = {} -- Sistema de eventos

---@class PlayerData
---@field patchX number
---@field patchY number
---@field tileX number
---@field tileY number
---@field size number

---@class CameraData
---@field x number
---@field y number

---@class IsometricPosition
---@field x number
---@field y number

---@class CullingSystem
---@field enabled boolean
---@field debugMode boolean
---@field cullingType string
---@field cullingRadius number
---@field screenBuffer number
---@field visibleObjects table
---@field fadingInObjects table
---@field fadingOutObjects table
---@field fadeTime number
---@field stats table
local CullingSystem = {}

-- Inicialização do simulador
function love.load()
    love.window.setTitle("🎮 Simulador Isométrico - Sistema de Culling Avançado")
    love.window.setMode(1920, 1080, { resizable = false, vsync = false })
    love.window.setFullscreen(false, "desktop")
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Carrega os dados do mapa Tiled
    pcall(function()
        package.path = package.path .. ';./src/?.lua'
    end)

    local success, mapData = pcall(require, "src.data.maps.jungle")
    if not success then
        print("ERRO ao carregar mapa:", mapData)
        error("Falha ao carregar mapa: " .. tostring(mapData))
    end
    IsometricSimulator.mapData = mapData

    -- Configurações do tile isométrico
    IsometricSimulator.tileWidth = IsometricSimulator.mapData.tilewidth
    IsometricSimulator.tileHeight = IsometricSimulator.mapData.tileheight
    IsometricSimulator.patchSize = IsometricSimulator.mapData.width / IsometricSimulator.mapData.properties.grid_width
    IsometricSimulator.tilesPerPatch = IsometricSimulator.mapData.properties.grid_width

    -- Carrega as imagens dos tiles
    IsometricSimulator.tiles = {}
    for _, tile in ipairs(IsometricSimulator.mapData.tilesets[1].tiles) do
        local gid = tile.id + IsometricSimulator.mapData.tilesets[1].firstgid
        local success, image = pcall(love.graphics.newImage, tile.image)
        if success then
            IsometricSimulator.tiles[gid] = image
        else
            print("ERRO: Falha ao carregar imagem:", tile.image, "-", image)
        end
    end

    -- Posição do jogador
    IsometricSimulator.player = {
        patchX = 0,
        patchY = 0,
        tileX = 12.0,
        tileY = 12.0,
        size = 6
    }

    -- Sistema de controles
    IsometricSimulator.keys = {}
    IsometricSimulator.moveSpeed = 7

    -- Fontes
    IsometricSimulator.font = love.graphics.newFont(16)
    IsometricSimulator.smallFont = love.graphics.newFont(12)
    IsometricSimulator.debugFont = love.graphics.newFont(10)

    -- Inicializa sistemas
    local success, err = pcall(function()
        IsometricSimulator:initializeCanvasSystem()
        IsometricSimulator:initializeCullingSystem()
    end)

    if not success then
        print("ERRO na inicialização dos sistemas:", err)
        error("Falha na inicialização: " .. tostring(err))
    end

    -- Processo de construção assíncrona
    IsometricSimulator.isLoading = true
    IsometricSimulator.loadingProgress = 0

    -- Garante que não há canvas ativo antes de criar a corrotina
    love.graphics.setCanvas()

    IsometricSimulator.buildCoroutine = coroutine.create(function()
        IsometricSimulator:buildCanvasesAsyncTask(true)
    end)

    -- Sistema de eventos
    Events:initialize()
    Events:on('player_wrapped', function(direction, oldPatchX, oldPatchY, newPatchX, newPatchY)
        print(string.format(
            "EVENTO: Jogador fez 'wrap' para %s. Patch anterior: (%d, %d), Novo patch: (%d, %d)",
            direction, oldPatchX, oldPatchY, newPatchX, newPatchY
        ))
    end)
end

-- Inicializa o sistema de culling
function IsometricSimulator:initializeCullingSystem()
    self.cullingSystem = {
        enabled = true,
        debugMode = true,
        cullingType = "circular", -- "circular", "rectangular", "frustum", "adaptive"
        cullingRadius = 400,      -- pixels (menor que a tela 1920x1080)
        screenBuffer = 50,        -- buffer adicional para suavizar transições
        visibleObjects = {},
        fadingInObjects = {},
        fadingOutObjects = {},
        fadeTime = 0.3, -- tempo de fade em segundos

        -- Estatísticas
        stats = {
            totalObjects = 0,
            visibleObjects = 0,
            culledObjects = 0,
            fadingIn = 0,
            fadingOut = 0
        },

        -- Configurações por tipo de culling
        configs = {
            circular = { radius = 400 },
            rectangular = { width = 800, height = 600 },
            frustum = { fov = 90, near = 100, far = 600 },
            adaptive = { baseRadius = 300, maxRadius = 500, speedFactor = 2.0 }
        }
    }
end

-- Atualização do jogo
function love.update(dt)
    -- Garante que não há canvas ativo durante a atualização
    love.graphics.setCanvas()

    if IsometricSimulator.isLoading then
        local status, err = coroutine.resume(IsometricSimulator.buildCoroutine)
        if not status then
            print("Erro na corrotina de construção:", err)
            IsometricSimulator.isLoading = false
        end
        if coroutine.status(IsometricSimulator.buildCoroutine) == "dead" then
            if IsometricSimulator.isLoading then
                IsometricSimulator.isLoading = false
                print("Construção dos canvases concluída!")
                IsometricSimulator:updateAllCanvases(true)
            end
        end
    else
        IsometricSimulator:updateMovement(dt)
        IsometricSimulator:updateCullingSystem(dt)
        IsometricSimulator:updateAllCanvases()
    end
end

-- Renderização principal
function love.draw()
    if IsometricSimulator.isLoading then
        IsometricSimulator:drawLoadingScreen()
    else
        IsometricSimulator:render()
        IsometricSimulator:drawUI()
    end
end

-- Atualiza o sistema de culling
function IsometricSimulator:updateCullingSystem(dt)
    if not self.cullingSystem.enabled then return end

    local culling = self.cullingSystem
    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() / 2

    -- Reseta estatísticas
    culling.stats.totalObjects = 0
    culling.stats.visibleObjects = 0
    culling.stats.culledObjects = 0
    culling.stats.fadingIn = 0
    culling.stats.fadingOut = 0

    -- Coleta todos os objetos renderizáveis (tiles visíveis)
    local allObjects = self:getAllRenderableObjects()
    culling.stats.totalObjects = #allObjects

    -- Aplica o algoritmo de culling selecionado
    local newVisibleObjects = {}

    for _, obj in ipairs(allObjects) do
        local isVisible = false

        if culling.cullingType == "circular" then
            isVisible = self:circularCulling(obj, centerX, centerY)
        elseif culling.cullingType == "rectangular" then
            isVisible = self:rectangularCulling(obj, centerX, centerY)
        elseif culling.cullingType == "frustum" then
            isVisible = self:frustumCulling(obj, centerX, centerY)
        elseif culling.cullingType == "adaptive" then
            isVisible = self:adaptiveCulling(obj, centerX, centerY)
        end

        if isVisible then
            newVisibleObjects[obj.id] = obj
        end
    end

    -- Gerencia transições de fade
    self:updateFadeTransitions(dt, newVisibleObjects)

    -- Atualiza estatísticas finais
    culling.stats.visibleObjects = self:countTable(culling.visibleObjects)
    culling.stats.fadingIn = self:countTable(culling.fadingInObjects)
    culling.stats.fadingOut = self:countTable(culling.fadingOutObjects)
    culling.stats.culledObjects = culling.stats.totalObjects - culling.stats.visibleObjects - culling.stats.fadingIn -
        culling.stats.fadingOut
end

-- Culling circular
function IsometricSimulator:circularCulling(obj, centerX, centerY)
    local config = self.cullingSystem.configs.circular
    local dx = obj.screenX - centerX
    local dy = obj.screenY - centerY
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance <= config.radius + self.cullingSystem.screenBuffer
end

-- Culling retangular
function IsometricSimulator:rectangularCulling(obj, centerX, centerY)
    local config = self.cullingSystem.configs.rectangular
    local halfWidth = config.width / 2 + self.cullingSystem.screenBuffer
    local halfHeight = config.height / 2 + self.cullingSystem.screenBuffer

    return obj.screenX >= centerX - halfWidth and obj.screenX <= centerX + halfWidth and
        obj.screenY >= centerY - halfHeight and obj.screenY <= centerY + halfHeight
end

-- Culling por frustum (simulado)
function IsometricSimulator:frustumCulling(obj, centerX, centerY)
    local config = self.cullingSystem.configs.frustum
    local dx = obj.screenX - centerX
    local dy = obj.screenY - centerY
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Simula um frustum cônico
    if distance < config.near or distance > config.far then
        return false
    end

    local angle = math.atan2(dy, dx)
    local fovRad = math.rad(config.fov / 2)
    local playerAngle = 0 -- Assumindo que o jogador olha para frente

    local angleDiff = math.abs(angle - playerAngle)
    if angleDiff > math.pi then
        angleDiff = 2 * math.pi - angleDiff
    end

    return angleDiff <= fovRad
end

-- Culling adaptativo (baseado na velocidade)
function IsometricSimulator:adaptiveCulling(obj, centerX, centerY)
    local config = self.cullingSystem.configs.adaptive

    -- Calcula velocidade do jogador
    local speed = math.sqrt((self.keys['w'] and 1 or 0) + (self.keys['s'] and 1 or 0) +
        (self.keys['a'] and 1 or 0) + (self.keys['d'] and 1 or 0))

    -- Ajusta o raio baseado na velocidade
    local adaptiveRadius = config.baseRadius + (speed * config.speedFactor * 50)
    adaptiveRadius = math.min(adaptiveRadius, config.maxRadius)

    local dx = obj.screenX - centerX
    local dy = obj.screenY - centerY
    local distance = math.sqrt(dx * dx + dy * dy)

    return distance <= adaptiveRadius + self.cullingSystem.screenBuffer
end

-- Atualiza transições de fade
function IsometricSimulator:updateFadeTransitions(dt, newVisibleObjects)
    local culling = self.cullingSystem

    -- Objetos que acabaram de ficar visíveis (fade in)
    for id, obj in pairs(newVisibleObjects) do
        if not culling.visibleObjects[id] and not culling.fadingInObjects[id] then
            culling.fadingInObjects[id] = { obj = obj, time = 0 }
        end
    end

    -- Objetos que não são mais visíveis (fade out)
    for id, obj in pairs(culling.visibleObjects) do
        if not newVisibleObjects[id] and not culling.fadingOutObjects[id] then
            culling.fadingOutObjects[id] = { obj = obj.obj or obj, time = 0 }
        end
    end

    -- Atualiza fade in
    for id, fadeObj in pairs(culling.fadingInObjects) do
        fadeObj.time = fadeObj.time + dt
        if fadeObj.time >= culling.fadeTime then
            culling.visibleObjects[id] = fadeObj
            culling.fadingInObjects[id] = nil
        end
    end

    -- Atualiza fade out
    for id, fadeObj in pairs(culling.fadingOutObjects) do
        fadeObj.time = fadeObj.time + dt
        if fadeObj.time >= culling.fadeTime then
            culling.fadingOutObjects[id] = nil
        end
    end

    -- Remove objetos que não são mais visíveis
    for id, obj in pairs(culling.visibleObjects) do
        if not newVisibleObjects[id] and not culling.fadingOutObjects[id] then
            culling.visibleObjects[id] = nil
        end
    end
end

-- Coleta todos os objetos renderizáveis
function IsometricSimulator:getAllRenderableObjects()
    local objects = {}
    local renderData = self.canvasRenderData
    local playerPatchX = math.floor(self.player.patchX)
    local playerPatchY = math.floor(self.player.patchY)
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)

    -- Posição global do jogador
    local playerGlobalTileX = self.player.patchX * self.tilesPerPatch + self.player.tileX
    local playerGlobalTileY = self.player.patchY * self.tilesPerPatch + self.player.tileY

    -- Origem do grid renderizado
    local gridOriginTileX = (playerPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (playerPatchY - renderRadius) * self.tilesPerPatch

    local objectId = 1

    -- Percorre todos os patches visíveis
    for py = playerPatchY - renderRadius, playerPatchY + renderRadius do
        for px = playerPatchX - renderRadius, playerPatchX + renderRadius do
            for y = 0, self.tilesPerPatch - 1 do
                for x = 0, self.tilesPerPatch - 1 do
                    local destTileX = (px * self.tilesPerPatch + x) - gridOriginTileX
                    local destTileY = (py * self.tilesPerPatch + y) - gridOriginTileY

                    -- Posição relativa ao jogador
                    local deltaX = destTileX - (playerGlobalTileX - gridOriginTileX)
                    local deltaY = destTileY - (playerGlobalTileY - gridOriginTileY)
                    local iso = self:cartesianToIsometric(deltaX, deltaY)

                    local screenX = love.graphics.getWidth() / 2 + iso.x
                    local screenY = love.graphics.getHeight() / 2 + iso.y

                    table.insert(objects, {
                        id = objectId,
                        tileX = destTileX,
                        tileY = destTileY,
                        screenX = screenX,
                        screenY = screenY,
                        patchX = px,
                        patchY = py,
                        localX = x,
                        localY = y
                    })

                    objectId = objectId + 1
                end
            end
        end
    end

    return objects
end

-- Coleta todos os pontos do mapa (para debug visual)
function IsometricSimulator:getAllMapPoints()
    local points = {}
    local playerGlobalTileX = self.player.patchX * self.tilesPerPatch + self.player.tileX
    local playerGlobalTileY = self.player.patchY * self.tilesPerPatch + self.player.tileY

    -- Define uma área maior para mostrar pontos em todo o mapa visível
    local mapRadius = 15 -- Patches em todas as direções (reduzido para performance)
    local playerPatchX = math.floor(self.player.patchX)
    local playerPatchY = math.floor(self.player.patchY)

    local pointId = 1

    -- Percorre uma área maior do mapa, mas com espaçamento para reduzir quantidade de pontos
    local spacing = 2 -- Mostra apenas 1 a cada 2 tiles para melhor performance

    for py = playerPatchY - mapRadius, playerPatchY + mapRadius do
        for px = playerPatchX - mapRadius, playerPatchX + mapRadius do
            for y = 0, self.tilesPerPatch - 1, spacing do
                for x = 0, self.tilesPerPatch - 1, spacing do
                    -- Posição global do tile
                    local globalTileX = px * self.tilesPerPatch + x
                    local globalTileY = py * self.tilesPerPatch + y

                    -- Posição relativa ao jogador
                    local deltaX = globalTileX - playerGlobalTileX
                    local deltaY = globalTileY - playerGlobalTileY
                    local iso = self:cartesianToIsometric(deltaX, deltaY)

                    local screenX = love.graphics.getWidth() / 2 + iso.x
                    local screenY = love.graphics.getHeight() / 2 + iso.y

                    -- Verifica se o ponto está na tela (com margem maior)
                    if screenX >= -100 and screenX <= love.graphics.getWidth() + 100 and
                        screenY >= -100 and screenY <= love.graphics.getHeight() + 100 then
                        table.insert(points, {
                            id = pointId,
                            tileX = globalTileX,
                            tileY = globalTileY,
                            screenX = screenX,
                            screenY = screenY,
                            patchX = px,
                            patchY = py,
                            localX = x,
                            localY = y
                        })

                        pointId = pointId + 1
                    end
                end
            end
        end
    end

    return points
end

-- Conta elementos em uma tabela
function IsometricSimulator:countTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Renderização principal (modificada para incluir culling)
function IsometricSimulator:render()
    love.graphics.clear(0, 0, 0, 1)

    local renderData = self.canvasRenderData
    local playerGlobalTileX = self.player.patchX * self.tilesPerPatch + self.player.tileX
    local playerGlobalTileY = self.player.patchY * self.tilesPerPatch + self.player.tileY
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)
    local gridOriginTileX = (renderData.lastRenderedPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (renderData.lastRenderedPatchY - renderRadius) * self.tilesPerPatch
    local playerRelativeTileX = playerGlobalTileX - gridOriginTileX
    local playerRelativeTileY = playerGlobalTileY - gridOriginTileY
    local playerIso = self:cartesianToIsometric(playerRelativeTileX, playerRelativeTileY)
    local canvasDrawX = love.graphics.getWidth() / 2 - playerIso.x - renderData.offsetX
    local canvasDrawY = love.graphics.getHeight() / 2 - playerIso.y - renderData.offsetY

    -- Desenha canvases com culling aplicado
    if self.cullingSystem.enabled then
        self:drawCanvasesWithCulling(canvasDrawX, canvasDrawY)
    else
        -- Desenho normal sem culling
        if self.layerCanvases["ground"] then
            love.graphics.draw(self.layerCanvases["ground"], canvasDrawX, canvasDrawY)
        end
        if self.layerCanvases["ground_decoration"] then
            love.graphics.draw(self.layerCanvases["ground_decoration"], canvasDrawX, canvasDrawY)
        end
    end

    -- Debug visual do culling
    if self.cullingSystem.debugMode then
        self:drawCullingDebug()
    end

    self:drawPatchMarkers()
    self:drawPlayer()

    if self.cullingSystem.enabled then
        -- Camadas acima do jogador com culling
        if self.layerCanvases["decoration"] then
            love.graphics.draw(self.layerCanvases["decoration"], canvasDrawX, canvasDrawY)
        end
        if self.layerCanvases["collision"] then
            love.graphics.draw(self.layerCanvases["collision"], canvasDrawX, canvasDrawY)
        end
    else
        -- Sem culling
        if self.layerCanvases["decoration"] then
            love.graphics.draw(self.layerCanvases["decoration"], canvasDrawX, canvasDrawY)
        end
        if self.layerCanvases["collision"] then
            love.graphics.draw(self.layerCanvases["collision"], canvasDrawX, canvasDrawY)
        end
    end
end

-- Desenha canvases com culling aplicado
function IsometricSimulator:drawCanvasesWithCulling(canvasDrawX, canvasDrawY)
    -- Por simplicidade, ainda desenha os canvases inteiros mas aplica efeitos visuais
    -- Em uma implementação real, você subdividiria os canvases ou desenharia tile por tile

    local culling = self.cullingSystem
    local alpha = 1.0

    -- Reduz ligeiramente a opacidade se houver objetos sendo cortados
    if culling.stats.culledObjects > 0 then
        alpha = 0.9
    end

    love.graphics.setColor(1, 1, 1, alpha)

    if self.layerCanvases["ground"] then
        love.graphics.draw(self.layerCanvases["ground"], canvasDrawX, canvasDrawY)
    end
    if self.layerCanvases["ground_decoration"] then
        love.graphics.draw(self.layerCanvases["ground_decoration"], canvasDrawX, canvasDrawY)
    end

    love.graphics.setColor(1, 1, 1, 1) -- Restaura cor
end

-- Desenha debug visual do culling
function IsometricSimulator:drawCullingDebug()
    local culling = self.cullingSystem
    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() / 2

    -- Desenha área de culling
    love.graphics.setLineWidth(2)

    if culling.cullingType == "circular" then
        local config = culling.configs.circular

        -- Círculo principal
        love.graphics.setColor(0, 1, 0, 0.3) -- Verde translúcido
        love.graphics.circle("fill", centerX, centerY, config.radius)

        love.graphics.setColor(0, 1, 0, 0.8) -- Verde sólido
        love.graphics.circle("line", centerX, centerY, config.radius)

        -- Buffer adicional
        love.graphics.setColor(1, 1, 0, 0.5) -- Amarelo
        love.graphics.circle("line", centerX, centerY, config.radius + culling.screenBuffer)
    elseif culling.cullingType == "rectangular" then
        local config = culling.configs.rectangular
        local halfW = config.width / 2
        local halfH = config.height / 2

        -- Retângulo principal
        love.graphics.setColor(0, 1, 0, 0.3)
        love.graphics.rectangle("fill", centerX - halfW, centerY - halfH, config.width, config.height)

        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.rectangle("line", centerX - halfW, centerY - halfH, config.width, config.height)

        -- Buffer
        love.graphics.setColor(1, 1, 0, 0.5)
        local bufferW = config.width + culling.screenBuffer * 2
        local bufferH = config.height + culling.screenBuffer * 2
        love.graphics.rectangle("line", centerX - bufferW / 2, centerY - bufferH / 2, bufferW, bufferH)
    elseif culling.cullingType == "frustum" then
        local config = culling.configs.frustum

        -- Desenha círculos de near e far
        love.graphics.setColor(1, 0, 0, 0.5) -- Vermelho para near
        love.graphics.circle("line", centerX, centerY, config.near)

        love.graphics.setColor(0, 0, 1, 0.5) -- Azul para far
        love.graphics.circle("line", centerX, centerY, config.far)

        -- Desenha setor do FOV
        love.graphics.setColor(0, 1, 0, 0.3)
        local fovRad = math.rad(config.fov / 2)
        love.graphics.arc("fill", centerX, centerY, config.far, -fovRad, fovRad)
    elseif culling.cullingType == "adaptive" then
        local config = culling.configs.adaptive

        -- Calcula raio atual baseado na velocidade
        local speed = math.sqrt((self.keys['w'] and 1 or 0) + (self.keys['s'] and 1 or 0) +
            (self.keys['a'] and 1 or 0) + (self.keys['d'] and 1 or 0))
        local adaptiveRadius = config.baseRadius + (speed * config.speedFactor * 50)
        adaptiveRadius = math.min(adaptiveRadius, config.maxRadius)

        -- Círculo base
        love.graphics.setColor(0, 1, 1, 0.3) -- Ciano
        love.graphics.circle("fill", centerX, centerY, config.baseRadius)

        love.graphics.setColor(0, 1, 1, 0.8)
        love.graphics.circle("line", centerX, centerY, config.baseRadius)

        -- Círculo adaptativo atual
        love.graphics.setColor(1, 0, 1, 0.5) -- Magenta
        love.graphics.circle("line", centerX, centerY, adaptiveRadius)

        -- Círculo máximo
        love.graphics.setColor(1, 0, 0, 0.3) -- Vermelho
        love.graphics.circle("line", centerX, centerY, config.maxRadius)
    end

    -- Desenha objetos sendo cortados
    self:drawCulledObjectsDebug()

    -- Grid de referência
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.setLineWidth(1)
    for i = -10, 10 do
        local x = centerX + i * 50
        local y = centerY + i * 50
        if x >= 0 and x <= love.graphics.getWidth() then
            love.graphics.line(x, 0, x, love.graphics.getHeight())
        end
        if y >= 0 and y <= love.graphics.getHeight() then
            love.graphics.line(0, y, love.graphics.getWidth(), y)
        end
    end

    love.graphics.setColor(1, 1, 1, 1) -- Restaura cor
end

-- Desenha debug de objetos cortados
function IsometricSimulator:drawCulledObjectsDebug()
    local culling = self.cullingSystem
    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() / 2

    -- Coleta todos os pontos do mapa
    local allPoints = self:getAllMapPoints()

    -- Cria um set para objetos visíveis para busca rápida
    local visibleObjectsSet = {}
    for id, obj in pairs(culling.visibleObjects) do
        local objData = obj.obj or obj
        visibleObjectsSet[objData.id] = true
    end

    -- Cria sets para objetos em fade
    local fadingInSet = {}
    for id, fadeObj in pairs(culling.fadingInObjects) do
        fadingInSet[fadeObj.obj.id] = fadeObj
    end

    local fadingOutSet = {}
    for id, fadeObj in pairs(culling.fadingOutObjects) do
        fadingOutSet[fadeObj.obj.id] = true
    end

    -- Desenha todos os pontos do mapa
    for _, point in ipairs(allPoints) do
        local isInCullingArea = false

        -- Verifica se o ponto está na área de culling
        if culling.cullingType == "circular" then
            local config = culling.configs.circular
            local dx = point.screenX - centerX
            local dy = point.screenY - centerY
            local distance = math.sqrt(dx * dx + dy * dy)
            isInCullingArea = distance <= config.radius + culling.screenBuffer
        elseif culling.cullingType == "rectangular" then
            local config = culling.configs.rectangular
            local halfWidth = config.width / 2 + culling.screenBuffer
            local halfHeight = config.height / 2 + culling.screenBuffer
            isInCullingArea = point.screenX >= centerX - halfWidth and point.screenX <= centerX + halfWidth and
                point.screenY >= centerY - halfHeight and point.screenY <= centerY + halfHeight
        elseif culling.cullingType == "frustum" then
            local config = culling.configs.frustum
            local dx = point.screenX - centerX
            local dy = point.screenY - centerY
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance >= config.near and distance <= config.far then
                local angle = math.atan2(dy, dx)
                local fovRad = math.rad(config.fov / 2)
                local playerAngle = 0
                local angleDiff = math.abs(angle - playerAngle)
                if angleDiff > math.pi then
                    angleDiff = 2 * math.pi - angleDiff
                end
                isInCullingArea = angleDiff <= fovRad
            end
        elseif culling.cullingType == "adaptive" then
            local config = culling.configs.adaptive
            local speed = math.sqrt((self.keys['w'] and 1 or 0) + (self.keys['s'] and 1 or 0) +
                (self.keys['a'] and 1 or 0) + (self.keys['d'] and 1 or 0))
            local adaptiveRadius = config.baseRadius + (speed * config.speedFactor * 50)
            adaptiveRadius = math.min(adaptiveRadius, config.maxRadius)

            local dx = point.screenX - centerX
            local dy = point.screenY - centerY
            local distance = math.sqrt(dx * dx + dy * dy)
            isInCullingArea = distance <= adaptiveRadius + culling.screenBuffer
        end

        -- Define a cor baseada no estado do ponto
        if fadingInSet[point.id] then
            -- Ponto fadendo in (ciano)
            local fadeObj = fadingInSet[point.id]
            local alpha = fadeObj.time / culling.fadeTime
            love.graphics.setColor(0, 1, 1, alpha)
            love.graphics.circle("fill", point.screenX, point.screenY, 3)
        elseif fadingOutSet[point.id] then
            -- Ponto fadendo out (amarelo)
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.circle("fill", point.screenX, point.screenY, 3)
        elseif visibleObjectsSet[point.id] then
            -- Ponto visível (verde)
            love.graphics.setColor(0, 1, 0, 0.8)
            love.graphics.circle("fill", point.screenX, point.screenY, 2)
        elseif isInCullingArea then
            -- Ponto na área de culling mas não processado (azul)
            love.graphics.setColor(0, 0, 1, 0.6)
            love.graphics.circle("fill", point.screenX, point.screenY, 2)
        else
            -- Ponto fora da área de culling (vermelho)
            love.graphics.setColor(1, 0, 0, 0.4)
            love.graphics.circle("fill", point.screenX, point.screenY, 1)
        end
    end
end

-- Controles de teclado modificados
function love.keypressed(key)
    IsometricSimulator.keys[key] = true

    if key == 'f11' then
        local isFullscreen, _ = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen)
    elseif key == 'c' then
        -- Alterna tipo de culling
        local types = { "circular", "rectangular", "frustum", "adaptive" }
        local current = IsometricSimulator.cullingSystem.cullingType
        local index = 1
        for i, t in ipairs(types) do
            if t == current then
                index = i
                break
            end
        end
        index = (index % #types) + 1
        IsometricSimulator.cullingSystem.cullingType = types[index]
        print("Tipo de culling alterado para:", types[index])
    elseif key == 'v' then
        -- Alterna debug visual
        IsometricSimulator.cullingSystem.debugMode = not IsometricSimulator.cullingSystem.debugMode
        print("Debug visual:", IsometricSimulator.cullingSystem.debugMode and "ATIVADO" or "DESATIVADO")
    elseif key == 'b' then
        -- Alterna culling on/off
        IsometricSimulator.cullingSystem.enabled = not IsometricSimulator.cullingSystem.enabled
        print("Culling:", IsometricSimulator.cullingSystem.enabled and "ATIVADO" or "DESATIVADO")
    elseif key == 'n' then
        -- Aumenta raio de culling
        local culling = IsometricSimulator.cullingSystem
        if culling.cullingType == "circular" then
            culling.configs.circular.radius = math.min(culling.configs.circular.radius + 50, 800)
        elseif culling.cullingType == "rectangular" then
            culling.configs.rectangular.width = math.min(culling.configs.rectangular.width + 100, 1600)
            culling.configs.rectangular.height = math.min(culling.configs.rectangular.height + 100, 1200)
        end
        print("Área de culling aumentada")
    elseif key == 'm' then
        -- Diminui raio de culling
        local culling = IsometricSimulator.cullingSystem
        if culling.cullingType == "circular" then
            culling.configs.circular.radius = math.max(culling.configs.circular.radius - 50, 100)
        elseif culling.cullingType == "rectangular" then
            culling.configs.rectangular.width = math.max(culling.configs.rectangular.width - 100, 200)
            culling.configs.rectangular.height = math.max(culling.configs.rectangular.height - 100, 200)
        end
        print("Área de culling diminuída")
    end
end

function love.keyreleased(key)
    IsometricSimulator.keys[key] = false
end

-- [O resto das funções permanecem iguais, incluindo updateMovement, handleWrapping, etc.]
-- Aqui estão as funções essenciais que não mudaram:

function IsometricSimulator:updateMovement(dt)
    local dx, dy = 0, 0
    if self.keys['w'] or self.keys['up'] then dy = dy - 1 end
    if self.keys['s'] or self.keys['down'] then dy = dy + 1 end
    if self.keys['a'] or self.keys['left'] then dx = dx - 1 end
    if self.keys['d'] or self.keys['right'] then dx = dx + 1 end

    if dx ~= 0 or dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length
        self.player.tileX = self.player.tileX + dx * self.moveSpeed * dt
        self.player.tileY = self.player.tileY + dy * self.moveSpeed * dt
        self:handleWrapping()
    end
end

function IsometricSimulator:handleWrapping()
    local wrapped = false
    local direction = ''
    local oldPatchX = self.player.patchX
    local oldPatchY = self.player.patchY

    if self.player.tileX < 0 then
        self.player.tileX = self.player.tileX + self.tilesPerPatch
        self.player.patchX = (self.player.patchX - 1 + self.patchSize) % self.patchSize
        wrapped = true
        direction = 'left'
    elseif self.player.tileX >= self.tilesPerPatch then
        self.player.tileX = self.player.tileX - self.tilesPerPatch
        self.player.patchX = (self.player.patchX + 1) % self.patchSize
        wrapped = true
        direction = 'right'
    end

    if self.player.tileY < 0 then
        self.player.tileY = self.player.tileY + self.tilesPerPatch
        self.player.patchY = (self.player.patchY - 1 + self.patchSize) % self.patchSize
        wrapped = true
        direction = direction == '' and 'up' or direction .. '-up'
    elseif self.player.tileY >= self.tilesPerPatch then
        self.player.tileY = self.player.tileY - self.tilesPerPatch
        self.player.patchY = (self.player.patchY + 1) % self.patchSize
        wrapped = true
        direction = direction == '' and 'down' or direction .. '-down'
    end

    if wrapped then
        Events:emit('player_wrapped', direction, oldPatchX, oldPatchY, self.player.patchX, self.player.patchY)
    end
end

function IsometricSimulator:getMaximumTileDimensions()
    local maxW, maxH = 0, 0
    if not self.tiles or not next(self.tiles) then return self.tileWidth, self.tileHeight * 2 end
    for _, img in pairs(self.tiles) do
        local w, h = img:getDimensions()
        if w > maxW then maxW = w end
        if h > maxH then maxH = h end
    end
    return maxW, maxH
end

function IsometricSimulator:initializeCanvasSystem()
    self.layerCanvases = {}
    self.canvasRenderData = {
        renderGridDiameter = 3,
        lastRenderedPatchX = nil,
        lastRenderedPatchY = nil
    }

    local renderData = self.canvasRenderData
    local gridSizeInTiles = renderData.renderGridDiameter * self.tilesPerPatch
    local maxTileW, maxTileH = self:getMaximumTileDimensions()
    local N = gridSizeInTiles

    local canvasWidth = (N - 1) * self.tileWidth + maxTileW
    local canvasHeight = (N - 1) * self.tileHeight + maxTileH

    -- Limita o tamanho dos canvases para evitar problemas de memória
    local maxCanvasSize = 4096
    if canvasWidth > maxCanvasSize or canvasHeight > maxCanvasSize then
        print(string.format("AVISO: Canvas muito grande (%dx%d), limitando para %dx%d",
            canvasWidth, canvasHeight, maxCanvasSize, maxCanvasSize))
        canvasWidth = math.min(canvasWidth, maxCanvasSize)
        canvasHeight = math.min(canvasHeight, maxCanvasSize)
    end

    renderData.width = canvasWidth
    renderData.height = canvasHeight
    renderData.offsetX = (N - 1) * self.tileWidth / 2 + (maxTileW / 2)
    renderData.offsetY = maxTileH - (self.tileHeight / 2)

    for _, layer in ipairs(self.mapData.layers) do
        if layer.type == "tilelayer" and layer.visible then
            local ok, canvas = pcall(love.graphics.newCanvas, canvasWidth, canvasHeight)
            if ok then
                canvas:setFilter("nearest", "nearest")
                self.layerCanvases[layer.name] = canvas
            else
                print(string.format(
                    "ERRO: Falha ao criar canvas de %dx%d para a camada '%s'.",
                    canvasWidth, canvasHeight, layer.name))
            end
        end
    end
end

function IsometricSimulator:updateAllCanvases(force)
    local playerPatchX = math.floor(self.player.patchX)
    local playerPatchY = math.floor(self.player.patchY)
    local renderData = self.canvasRenderData

    if force or playerPatchX ~= renderData.lastRenderedPatchX or playerPatchY ~= renderData.lastRenderedPatchY then
        self:buildCanvasesAsyncTask(false)
    end
end

function IsometricSimulator:buildCanvasesAsyncTask(isAsyncTask)
    local renderData = self.canvasRenderData
    local playerPatchX = math.floor(self.player.patchX)
    local playerPatchY = math.floor(self.player.patchY)

    renderData.lastRenderedPatchX = playerPatchX
    renderData.lastRenderedPatchY = playerPatchY

    local totalLayers = 0
    for _ in pairs(self.layerCanvases) do totalLayers = totalLayers + 1 end
    local layersProcessed = 0

    for name, canvas in pairs(self.layerCanvases) do
        self:renderLayerToCanvas(name, canvas, isAsyncTask)
        layersProcessed = layersProcessed + 1
        self.loadingProgress = layersProcessed / totalLayers
        if isAsyncTask then
            -- Garante que não há canvas ativo antes do yield
            love.graphics.setCanvas()
            coroutine.yield()
        end
    end
end

function IsometricSimulator:renderLayerToCanvas(layerName, canvas, isAsyncTask)
    local layer
    for _, l in ipairs(self.mapData.layers) do
        if l.name == layerName then
            layer = l
            break
        end
    end
    if not layer then return end

    local renderData = self.canvasRenderData
    local centerPatchX = renderData.lastRenderedPatchX
    local centerPatchY = renderData.lastRenderedPatchY
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)

    -- Garante que não há canvas ativo antes de começar
    love.graphics.setCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)

    local mapTotalWidth = self.mapData.width
    local gridOriginTileX = (centerPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (centerPatchY - renderRadius) * self.tilesPerPatch
    local tilesDrawnInFrame = 0
    local TILES_PER_YIELD = 100

    for py = centerPatchY - renderRadius, centerPatchY + renderRadius do
        for px = centerPatchX - renderRadius, centerPatchX + renderRadius do
            local sourcePatchX = ((px % self.patchSize) + self.patchSize) % self.patchSize
            local sourcePatchY = ((py % self.patchSize) + self.patchSize) % self.patchSize
            local sourceTileStartX = sourcePatchX * self.tilesPerPatch
            local sourceTileStartY = sourcePatchY * self.tilesPerPatch

            for y = 0, self.tilesPerPatch - 1 do
                for x = 0, self.tilesPerPatch - 1 do
                    local sourceMapX = sourceTileStartX + x
                    local sourceMapY = sourceTileStartY + y
                    local index = sourceMapY * mapTotalWidth + sourceMapX + 1
                    local gid = layer.data[index]

                    if gid and gid > 0 and self.tiles[gid] then
                        local tileImage = self.tiles[gid]
                        local quadW, quadH = tileImage:getDimensions()
                        local destTileX = (px * self.tilesPerPatch + x) - gridOriginTileX
                        local destTileY = (py * self.tilesPerPatch + y) - gridOriginTileY
                        local iso = self:cartesianToIsometric(destTileX, destTileY)
                        local screenX = iso.x + renderData.offsetX
                        local screenY = iso.y + renderData.offsetY
                        local ox = quadW / 2
                        local oy = quadH - self.tileHeight / 2

                        love.graphics.draw(tileImage, math.floor(screenX), math.floor(screenY), 0, 1, 1, ox, oy)

                        tilesDrawnInFrame = tilesDrawnInFrame + 1
                        if isAsyncTask and tilesDrawnInFrame >= TILES_PER_YIELD then
                            love.graphics.setCanvas()       -- Libera o canvas antes do yield
                            coroutine.yield()
                            love.graphics.setCanvas(canvas) -- Restaura o canvas após o yield
                            tilesDrawnInFrame = 0
                        end
                    end
                end
            end
        end
    end

    -- Garante que o canvas seja liberado mesmo em caso de erro
    love.graphics.setCanvas()
end

function IsometricSimulator:cartesianToIsometric(x, y)
    local isoX = (x - y) * (self.tileWidth / 2)
    local isoY = (x + y) * (self.tileHeight / 2)
    return { x = isoX, y = isoY }
end

function IsometricSimulator:drawPatchMarkers()
    local renderRadius = 2
    local playerPatchX = math.floor(self.player.patchX)
    local playerPatchY = math.floor(self.player.patchY)

    for px = playerPatchX - renderRadius, playerPatchX + renderRadius do
        for py = playerPatchY - renderRadius, playerPatchY + renderRadius do
            local wrappedPx = ((px % self.patchSize) + self.patchSize) % self.patchSize
            local wrappedPy = ((py % self.patchSize) + self.patchSize) % self.patchSize

            local centerX = px * self.tilesPerPatch + math.floor(self.tilesPerPatch / 2)
            local centerY = py * self.tilesPerPatch + math.floor(self.tilesPerPatch / 2)

            local playerGlobalTileX = self.player.patchX * self.tilesPerPatch + self.player.tileX
            local playerGlobalTileY = self.player.patchY * self.tilesPerPatch + self.player.tileY

            local deltaX = centerX - playerGlobalTileX
            local deltaY = centerY - playerGlobalTileY
            local iso = self:cartesianToIsometric(deltaX, deltaY)

            local screenX = love.graphics.getWidth() / 2 + iso.x
            local screenY = love.graphics.getHeight() / 2 + iso.y

            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.circle('fill', screenX, screenY - 2, 18)

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(self.smallFont)
            local text = string.format("P%d,%d", wrappedPx, wrappedPy)
            local textWidth = self.smallFont:getWidth(text)
            love.graphics.print(text, screenX - textWidth / 2, screenY - 6)
        end
    end
end

function IsometricSimulator:drawPlayer()
    local screenX = love.graphics.getWidth() / 2
    local screenY = love.graphics.getHeight() / 2

    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.ellipse('fill', screenX, screenY + 3, (self.player.size + 2) * 2, self.player.size)

    love.graphics.setColor(1, 0.42, 0.42, 1)
    love.graphics.circle('fill', screenX, screenY - 8, self.player.size)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle('line', screenX, screenY - 8, self.player.size)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle('fill', screenX, screenY - 10, 2)
end

function IsometricSimulator:drawLoadingScreen()
    love.graphics.setCanvas()
    love.graphics.clear(0.1, 0.1, 0.13, 1)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.font)

    local text = "Construindo o mundo..."
    local textWidth = self.font:getWidth(text)
    love.graphics.print(text, (love.graphics.getWidth() - textWidth) / 2, love.graphics.getHeight() / 2 - 50)

    local barWidth = 400
    local barHeight = 30
    local barX = (love.graphics.getWidth() - barWidth) / 2
    local barY = love.graphics.getHeight() / 2

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle('fill', barX, barY, barWidth, barHeight, 5)

    love.graphics.setColor(0.2, 0.6, 1, 1)
    love.graphics.rectangle('fill', barX, barY, barWidth * self.loadingProgress, barHeight, 5)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', barX, barY, barWidth, barHeight, 5)
end

function IsometricSimulator:drawUI()
    -- Título
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.font)
    local title = "🎮 Simulador Isométrico - Sistema de Culling Avançado"
    local titleWidth = self.font:getWidth(title)
    love.graphics.print(title, (love.graphics.getWidth() - titleWidth) / 2, 10)

    -- Controles
    love.graphics.setFont(self.smallFont)
    local controls = "WASD: Mover | C: Tipo Culling | V: Debug | B: On/Off Culling | N/M: +/- Área | F11: Tela Cheia"
    local controlsWidth = self.smallFont:getWidth(controls)
    love.graphics.print(controls, (love.graphics.getWidth() - controlsWidth) / 2, 40)

    -- Legenda dos pontos coloridos
    if self.cullingSystem.debugMode then
        love.graphics.setColor(1, 1, 1, 0.8)
        local legend = "PONTOS: Vermelho (fora) | Azul (dentro) | Verde (visível) | Ciano/Amarelo (fade)"
        local legendWidth = self.smallFont:getWidth(legend)
        love.graphics.print(legend, (love.graphics.getWidth() - legendWidth) / 2, 80)
    end

    -- Status do culling
    local culling = self.cullingSystem
    local statusText = string.format("Culling: %s | Tipo: %s | Debug: %s",
        culling.enabled and "ON" or "OFF",
        culling.cullingType:upper(),
        culling.debugMode and "ON" or "OFF"
    )
    local statusWidth = self.smallFont:getWidth(statusText)
    love.graphics.print(statusText, (love.graphics.getWidth() - statusWidth) / 2, 100)

    -- Informações do patch (canto inferior esquerdo)
    local y = love.graphics.getHeight() - 160

    -- Fundo para as informações
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 10, y - 5, 400, 150, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', 10, y - 5, 400, 150, 10, 10)

    -- Informações do jogador
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.smallFont)

    local currentPatchX = math.floor(self.player.patchX)
    local currentPatchY = math.floor(self.player.patchY)
    local patchText = string.format("Patch: %d, %d", currentPatchX, currentPatchY)
    love.graphics.print(patchText, 20, y)

    local tileText = string.format("Tile: %.1f, %.1f", self.player.tileX, self.player.tileY)
    love.graphics.print(tileText, 20, y + 20)

    local globalTileX = currentPatchX * self.tilesPerPatch + self.player.tileX
    local globalTileY = currentPatchY * self.tilesPerPatch + self.player.tileY
    local globalText = string.format("Global: %.1f, %.1f", globalTileX, globalTileY)
    love.graphics.print(globalText, 20, y + 40)

    -- Estatísticas de culling
    if culling.enabled then
        love.graphics.setColor(0.8, 1, 0.8, 1) -- Verde claro
        love.graphics.print("=== ESTATÍSTICAS DE CULLING ===", 20, y + 70)
        love.graphics.print(string.format("Total de Objetos: %d", culling.stats.totalObjects), 20, y + 90)
        love.graphics.print(string.format("Visíveis: %d", culling.stats.visibleObjects), 20, y + 105)
        love.graphics.print(string.format("Cortados: %d", culling.stats.culledObjects), 20, y + 120)
        love.graphics.print(string.format("Fade In: %d | Fade Out: %d", culling.stats.fadingIn, culling.stats.fadingOut),
            20, y + 135)
    end

    -- FPS no canto inferior direito
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.debugFont)
    local fpsText = "FPS: " .. love.timer.getFPS()
    local fpsWidth = self.debugFont:getWidth(fpsText)
    love.graphics.print(fpsText, love.graphics.getWidth() - fpsWidth - 20, love.graphics.getHeight() - 25)

    -- Configurações atuais do culling (canto superior direito)
    if culling.enabled and culling.debugMode then
        love.graphics.setColor(1, 1, 0.8, 0.9)
        love.graphics.setFont(self.debugFont)
        local configX = love.graphics.getWidth() - 300
        local configY = 80

        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', configX - 10, configY - 5, 290, 100, 5)

        love.graphics.setColor(1, 1, 0.8, 1)
        love.graphics.print("=== CONFIGURAÇÕES ===", configX, configY)

        if culling.cullingType == "circular" then
            love.graphics.print(string.format("Raio: %d px", culling.configs.circular.radius), configX, configY + 15)
        elseif culling.cullingType == "rectangular" then
            love.graphics.print(
                string.format("Dimensões: %dx%d", culling.configs.rectangular.width, culling.configs.rectangular.height),
                configX, configY + 15)
        elseif culling.cullingType == "frustum" then
            local config = culling.configs.frustum
            love.graphics.print(string.format("FOV: %d° | Near: %d | Far: %d", config.fov, config.near, config.far),
                configX, configY + 15)
        elseif culling.cullingType == "adaptive" then
            local config = culling.configs.adaptive
            local speed = math.sqrt((self.keys['w'] and 1 or 0) + (self.keys['s'] and 1 or 0) +
                (self.keys['a'] and 1 or 0) + (self.keys['d'] and 1 or 0))
            local adaptiveRadius = config.baseRadius + (speed * config.speedFactor * 50)
            adaptiveRadius = math.min(adaptiveRadius, config.maxRadius)
            love.graphics.print(
                string.format("Base: %d | Atual: %d | Max: %d", config.baseRadius, math.floor(adaptiveRadius),
                    config.maxRadius), configX, configY + 15)
        end

        love.graphics.print(string.format("Buffer: %d px", culling.screenBuffer), configX, configY + 30)
        love.graphics.print(string.format("Fade Time: %.1fs", culling.fadeTime), configX, configY + 45)

        -- Taxa de culling
        local cullRate = culling.stats.totalObjects > 0 and
            (culling.stats.culledObjects / culling.stats.totalObjects * 100) or 0
        love.graphics.print(string.format("Taxa de Culling: %.1f%%", cullRate), configX, configY + 60)
    end
end

-- Sistema de eventos
function Events:on(name, callback)
    self.listeners = self.listeners or {}
    self.listeners[name] = self.listeners[name] or {}
    table.insert(self.listeners[name], callback)
end

function Events:emit(name, ...)
    if self.listeners and self.listeners[name] then
        for _, callback in ipairs(self.listeners[name]) do
            callback(...)
        end
    end
end

function Events:off(name, callback)
    if not (self.listeners and self.listeners[name]) then
        return
    end
    for i, v in ipairs(self.listeners[name]) do
        if v == callback then
            table.remove(self.listeners[name], i)
            return
        end
    end
end

function Events:initialize()
    self.listeners = {}
end
