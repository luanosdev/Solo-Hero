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
---@field mapData table
---@field tiles table<number, love.Image>
---@field layerCanvases table<string, love.Canvas>
---@field canvasRenderData table
---@field isLoading boolean
---@field loadingProgress number
---@field buildCoroutine coroutine
local IsometricSimulator = {}
local Events = {} -- Nosso sistema de eventos

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

-- Inicialização do simulador
function love.load()
    love.window.setTitle("🎮 Simulador Isométrico - Sistema de Eventos")
    love.window.setMode(1920, 1080, { resizable = true, vsync = false })
    love.window.setFullscreen(true, "desktop")
    love.graphics.setDefaultFilter("nearest", "nearest") -- Garante a nitidez dos tiles

    -- Carrega os dados do mapa Tiled
    pcall(function()
        -- Adiciona o diretório `src` ao path para permitir o require
        package.path = package.path .. ';./src/?.lua'
    end)
    IsometricSimulator.mapData = require("data.maps.jungle")

    -- Configurações do tile isométrico baseadas no mapa
    IsometricSimulator.tileWidth = IsometricSimulator.mapData.tilewidth
    IsometricSimulator.tileHeight = IsometricSimulator.mapData.tileheight
    IsometricSimulator.patchSize = IsometricSimulator.mapData.width / IsometricSimulator.mapData.properties.grid_width
    IsometricSimulator.tilesPerPatch = IsometricSimulator.mapData.properties.grid_width

    -- Carrega as imagens dos tiles e as mantém individualmente
    IsometricSimulator.tiles = {}
    for _, tile in ipairs(IsometricSimulator.mapData.tilesets[1].tiles) do
        local gid = tile.id + IsometricSimulator.mapData.tilesets[1].firstgid
        IsometricSimulator.tiles[gid] = love.graphics.newImage(tile.image)
    end

    -- Posição do jogador (em tiles)
    IsometricSimulator.player = {
        patchX = 0,
        patchY = 0,
        tileX = 12.0, -- Centro do patch
        tileY = 12.0,
        size = 6
    }

    -- Sistema de controles
    IsometricSimulator.keys = {}
    IsometricSimulator.moveSpeed = 7 -- tiles por segundo

    -- Fontes
    IsometricSimulator.font = love.graphics.newFont(16)
    IsometricSimulator.smallFont = love.graphics.newFont(12)

    -- Inicializa o novo sistema de renderização por Canvas
    IsometricSimulator:initializeCanvasSystem()

    -- Inicia o processo de construção assíncrona dos canvases
    IsometricSimulator.isLoading = true
    IsometricSimulator.loadingProgress = 0
    IsometricSimulator.buildCoroutine = coroutine.create(function()
        IsometricSimulator:buildCanvasesAsyncTask(true)
    end)

    -- Inicializa o sistema de eventos
    Events:initialize()

    -- Registra um ouvinte para o evento de wrap para fins de log
    Events:on('player_wrapped', function(direction, oldPatchX, oldPatchY, newPatchX, newPatchY)
        print(string.format(
            "EVENTO: Jogador fez 'wrap' para %s. Patch anterior: (%d, %d), Novo patch: (%d, %d)",
            direction, oldPatchX, oldPatchY, newPatchX, newPatchY
        ))
    end)
end

-- Atualização do jogo
---@param dt number
function love.update(dt)
    if IsometricSimulator.isLoading then
        -- Continua o processo de construção dos canvases
        local status, err = coroutine.resume(IsometricSimulator.buildCoroutine)
        if not status then
            print("Erro na corrotina de construção:", err)
            IsometricSimulator.isLoading = false
        end
        if coroutine.status(IsometricSimulator.buildCoroutine) == "dead" then
            if IsometricSimulator.isLoading then -- Executa apenas uma vez
                IsometricSimulator.isLoading = false
                print("Construção dos canvases concluída!")
                -- FORÇA UMA RECONSTRUÇÃO FINAL SÍNCRONA:
                -- Isso garante que o estado do canvas esteja perfeito no primeiro quadro
                -- após o carregamento, simulando a recarga que ocorre ao se mover.
                IsometricSimulator:updateAllCanvases(true)
            end
        end
    else
        -- Lógica normal do jogo após o carregamento
        IsometricSimulator:updateMovement(dt)
        -- Verifica se é necessário redesenhar os canvases (agora de forma síncrona ou assíncrona)
        IsometricSimulator:updateAllCanvases()
    end
end

-- Renderização do jogo
function love.draw()
    if IsometricSimulator.isLoading then
        IsometricSimulator:drawLoadingScreen()
    else
        IsometricSimulator:render()
        IsometricSimulator:drawUI()
    end
end

-- Controles de teclado
---@param key string
function love.keypressed(key)
    IsometricSimulator.keys[key] = true
    if key == 'f11' then
        local isFullscreen, _ = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen)
    end

    -- Adiciona a funcionalidade de salvar o atlas para depuração
    if key == 'p' then
        if IsometricSimulator.atlas then
            IsometricSimulator.atlas:newImageData():encode("png", "atlas_debug.png")
            print("Atlas de textura salvo como 'atlas_debug.png'")
        end
    end
end

---@param key string
function love.keyreleased(key)
    IsometricSimulator.keys[key] = false
end

-- Atualiza a lógica de movimento do jogador
---@param dt number
function IsometricSimulator:updateMovement(dt)
    local dx, dy = 0, 0

    -- Mapeamento de WASD para direções na grade (igual ao InputManager)
    if self.keys['w'] or self.keys['up'] then dy = dy - 1 end
    if self.keys['s'] or self.keys['down'] then dy = dy + 1 end
    if self.keys['a'] or self.keys['left'] then dx = dx - 1 end
    if self.keys['d'] or self.keys['right'] then dx = dx + 1 end

    if dx ~= 0 or dy ~= 0 then
        -- Normaliza o vetor para evitar velocidade maior na diagonal
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length
        dy = dy / length

        -- Aplica movimento contínuo baseado em dt
        self.player.tileX = self.player.tileX + dx * self.moveSpeed * dt
        self.player.tileY = self.player.tileY + dy * self.moveSpeed * dt

        -- Verifica wrapping entre patches
        self:handleWrapping()
    end
end

-- Gerencia wrapping infinito entre patches
function IsometricSimulator:handleWrapping()
    local wrapped = false
    local direction = ''
    local oldPatchX = self.player.patchX
    local oldPatchY = self.player.patchY

    -- Wrapping horizontal
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

    -- Wrapping vertical
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

-- NOVO: Percorre todos os tiles para encontrar a maior dimensão de tile
function IsometricSimulator:getMaximumTileDimensions()
    local maxW, maxH = 0, 0
    if not self.tiles or not next(self.tiles) then return self.tileWidth, self.tileHeight * 2 end -- Fallback
    for _, img in pairs(self.tiles) do
        local w, h = img:getDimensions()
        if w > maxW then maxW = w end
        if h > maxH then maxH = h end
    end
    return maxW, maxH
end

-- ATUALIZADO: Inicializa o sistema de renderização por canvas
function IsometricSimulator:initializeCanvasSystem()
    self.layerCanvases = {}
    self.canvasRenderData = {
        renderGridDiameter = 3, -- Renderiza um grid de 3x3 patches
        lastRenderedPatchX = nil,
        lastRenderedPatchY = nil
    }

    local renderData = self.canvasRenderData
    local gridSizeInTiles = renderData.renderGridDiameter * self.tilesPerPatch

    -- CORREÇÃO PRECISA: Calcular as dimensões exatas do canvas para evitar cortes.
    -- Primeiro, encontramos o maior tile para garantir que ele caiba.
    local maxTileW, maxTileH = self:getMaximumTileDimensions()
    local N = gridSizeInTiles

    -- A largura total do losango isométrico é (N-1)*tileWidth. Adicionamos maxTileW como margem.
    local canvasWidth = (N - 1) * self.tileWidth + maxTileW
    -- A altura total é (N-1)*tileHeight. Adicionamos maxTileH como margem.
    local canvasHeight = (N - 1) * self.tileHeight + maxTileH

    renderData.width = canvasWidth
    renderData.height = canvasHeight

    -- O offset X deve transladar la coordenada X mais negativa para zero.
    -- isoX_min é -(N-1)*tileWidth/2. O tile se estende por maxTileW/2 para a esquerda.
    renderData.offsetX = (N - 1) * self.tileWidth / 2 + (maxTileW / 2)
    -- O offset Y deve transladar a coordenada Y mais alta para zero.
    -- isoY_min é 0. O tile se estende para cima por (maxTileH - tileHeight/2).
    renderData.offsetY = maxTileH - (self.tileHeight / 2)

    -- Cria um canvas para cada camada de tiles visível
    for _, layer in ipairs(self.mapData.layers) do
        if layer.type == "tilelayer" and layer.visible then
            -- Usamos pcall para o caso de o canvas ser grande demais para a GPU
            local ok, canvas = pcall(love.graphics.newCanvas, canvasWidth, canvasHeight)
            if ok then
                canvas:setFilter("nearest", "nearest")
                self.layerCanvases[layer.name] = canvas
            else
                print(string.format(
                    "ERRO: Falha ao criar canvas de %dx%d para a camada '%s'. A GPU pode não suportar esta dimensão.",
                    canvasWidth, canvasHeight, layer.name))
            end
        end
    end
end

-- ATUALIZADO: Verifica se os canvases precisam ser redesenhados e o faz
---@param force boolean
function IsometricSimulator:updateAllCanvases(force)
    local playerPatchX = math.floor(self.player.patchX)
    local playerPatchY = math.floor(self.player.patchY)
    local renderData = self.canvasRenderData

    -- Redesenha apenas se o jogador mudou de patch ou se for forçado
    if force or playerPatchX ~= renderData.lastRenderedPatchX or playerPatchY ~= renderData.lastRenderedPatchY then
        -- ATENÇÃO: Por simplicidade, a recarga após o loading inicial ainda é síncrona.
        -- Poderíamos reutilizar a corrotina aqui se a recarga causar travamentos.
        self:buildCanvasesAsyncTask(false) -- Executa a tarefa de forma bloqueante
    end
end

-- ATUALIZADO: Tarefa que constrói os canvases, agora pode ser assíncrona
---@param isAsyncTask boolean Se deve pausar (yield) durante a execução
function IsometricSimulator:buildCanvasesAsyncTask(isAsyncTask)
    local renderData = self.canvasRenderData
    local playerPatchX = math.floor(self.player.patchX)
    local playerPatchY = math.floor(self.player.patchY)

    -- Atualiza qual patch está sendo renderizado
    renderData.lastRenderedPatchX = playerPatchX
    renderData.lastRenderedPatchY = playerPatchY

    local totalLayers = 0
    for _ in pairs(self.layerCanvases) do totalLayers = totalLayers + 1 end
    local layersProcessed = 0

    -- Redesenha cada camada em seu respectivo canvas
    for name, canvas in pairs(self.layerCanvases) do
        self:renderLayerToCanvas(name, canvas, isAsyncTask)
        layersProcessed = layersProcessed + 1
        self.loadingProgress = layersProcessed / totalLayers
        if isAsyncTask then coroutine.yield() end
    end
end

-- ATUALIZADO: Desenha uma camada de mapa usando love.graphics.draw individual
---@param layerName string
---@param canvas love.Canvas
---@param isAsyncTask boolean
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

    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0) -- Limpa o canvas com transparência

    local mapTotalWidth = self.mapData.width

    local gridOriginTileX = (centerPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (centerPatchY - renderRadius) * self.tilesPerPatch

    local tilesDrawnInFrame = 0
    local TILES_PER_YIELD = 100 -- Ajuste este valor para balancear velocidade e responsividade

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

                    -- USA DIRETAMENTE A IMAGEM DO TILE, SEM ATLAS/QUAD
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

                        -- USA O DRAW INDIVIDUAL: A fonte da nossa confiança!
                        love.graphics.draw(tileImage, math.floor(screenX), math.floor(screenY), 0, 1, 1, ox, oy)

                        tilesDrawnInFrame = tilesDrawnInFrame + 1
                        if isAsyncTask and tilesDrawnInFrame >= TILES_PER_YIELD then
                            coroutine.yield()
                            tilesDrawnInFrame = 0
                        end
                    end
                end
            end
        end
    end

    love.graphics.setCanvas() -- Volta a desenhar na tela
end

-- Atualiza posição da câmera
function IsometricSimulator:updateCamera()
    -- Esta função não é mais necessária, pois a câmera é gerenciada na renderização do canvas
end

-- Converte coordenadas cartesianas para isométricas
---@param x number
---@param y number
---@return IsometricPosition
function IsometricSimulator:cartesianToIsometric(x, y)
    local isoX = (x - y) * (self.tileWidth / 2)
    local isoY = (x + y) * (self.tileHeight / 2)
    return { x = isoX, y = isoY }
end

-- Renderização principal
function IsometricSimulator:render()
    love.graphics.clear(0, 0, 0, 1)

    local renderData = self.canvasRenderData

    -- Posição global exata do jogador em tiles
    local playerGlobalTileX = self.player.patchX * self.tilesPerPatch + self.player.tileX
    local playerGlobalTileY = self.player.patchY * self.tilesPerPatch + self.player.tileY

    -- Ponto de origem (tile 0,0) do grid que foi renderizado no canvas
    local renderRadius = math.floor(renderData.renderGridDiameter / 2)
    local gridOriginTileX = (renderData.lastRenderedPatchX - renderRadius) * self.tilesPerPatch
    local gridOriginTileY = (renderData.lastRenderedPatchY - renderRadius) * self.tilesPerPatch

    -- Posição do jogador relativa ao ponto de origem do canvas
    local playerRelativeTileX = playerGlobalTileX - gridOriginTileX
    local playerRelativeTileY = playerGlobalTileY - gridOriginTileY

    -- Converte a posição relativa do jogador para coordenadas isométricas
    local playerIso = self:cartesianToIsometric(playerRelativeTileX, playerRelativeTileY)

    -- Para centralizar o jogador na tela, o canvas deve ser desenhado em uma posição que
    -- mova o ponto isométrico do jogador para o centro da tela.
    local canvasDrawX = love.graphics.getWidth() / 2 - playerIso.x - renderData.offsetX
    local canvasDrawY = love.graphics.getHeight() / 2 - playerIso.y - renderData.offsetY

    -- Desenha os canvases na ordem correta, verificando se eles existem
    if self.layerCanvases["ground"] then
        love.graphics.draw(self.layerCanvases["ground"], canvasDrawX, canvasDrawY)
    end
    if self.layerCanvases["ground_decoration"] then
        love.graphics.draw(self.layerCanvases["ground_decoration"], canvasDrawX, canvasDrawY)
    end

    -- Renderiza marcadores de patch (ajustados para a nova lógica)
    self:drawPatchMarkers()

    -- Renderiza o jogador
    self:drawPlayer()

    -- Renderiza camadas acima do jogador
    if self.layerCanvases["decoration"] then
        love.graphics.draw(self.layerCanvases["decoration"], canvasDrawX, canvasDrawY)
    end
    if self.layerCanvases["collision"] then
        love.graphics.draw(self.layerCanvases["collision"], canvasDrawX, canvasDrawY)
    end
end

-- Desenha marcadores dos patches
function IsometricSimulator:drawPatchMarkers()
    local renderRadius = 2
    local playerPatchX = math.floor(self.player.patchX)
    local playerPatchY = math.floor(self.player.patchY)

    for px = playerPatchX - renderRadius, playerPatchX + renderRadius do
        for py = playerPatchY - renderRadius, playerPatchY + renderRadius do
            local wrappedPx = ((px % self.patchSize) + self.patchSize) % self.patchSize
            local wrappedPy = ((py % self.patchSize) + self.patchSize) % self.patchSize

            -- Centro do patch em tiles globais
            local centerX = px * self.tilesPerPatch + math.floor(self.tilesPerPatch / 2)
            local centerY = py * self.tilesPerPatch + math.floor(self.tilesPerPatch / 2)

            -- A posição do marcador agora precisa ser calculada em relação à tela
            -- Posição global do jogador
            local playerGlobalTileX = self.player.patchX * self.tilesPerPatch + self.player.tileX
            local playerGlobalTileY = self.player.patchY * self.tilesPerPatch + self.player.tileY

            -- Posição do centro do patch relativa ao jogador
            local deltaX = centerX - playerGlobalTileX
            local deltaY = centerY - playerGlobalTileY
            local iso = self:cartesianToIsometric(deltaX, deltaY)

            -- A posição do jogador está sempre no centro da tela
            local screenX = love.graphics.getWidth() / 2 + iso.x
            local screenY = love.graphics.getHeight() / 2 + iso.y

            -- Círculo de fundo
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.circle('fill', screenX, screenY - 2, 18)

            -- Texto do marcador
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(self.smallFont)
            local text = string.format("P%d,%d", wrappedPx, wrappedPy)
            local textWidth = self.smallFont:getWidth(text)
            love.graphics.print(text, screenX - textWidth / 2, screenY - 6)
        end
    end
end

-- Desenha o jogador
function IsometricSimulator:drawPlayer()
    -- O jogador agora é sempre desenhado no centro da tela
    local screenX = love.graphics.getWidth() / 2
    local screenY = love.graphics.getHeight() / 2

    -- Sombra do jogador
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.ellipse('fill', screenX, screenY + 3, (self.player.size + 2) * 2, self.player.size)

    -- Corpo do jogador
    love.graphics.setColor(1, 0.42, 0.42, 1) -- #ff6b6b
    love.graphics.circle('fill', screenX, screenY - 8, self.player.size)

    -- Contorno do jogador
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle('line', screenX, screenY - 8, self.player.size)

    -- Indicador de direção
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle('fill', screenX, screenY - 10, 2)
end

-- NOVO: Desenha a tela de carregamento
function IsometricSimulator:drawLoadingScreen()
    -- Garante que estamos desenhando na tela principal, e não em um canvas que a corrotina possa ter deixado ativo.
    love.graphics.setCanvas()
    love.graphics.clear(0.1, 0.1, 0.13, 1) -- Fundo escuro

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.font)

    local text = "Construindo o mundo..."
    local textWidth = self.font:getWidth(text)
    love.graphics.print(text, (love.graphics.getWidth() - textWidth) / 2, love.graphics.getHeight() / 2 - 50)

    -- Barra de progresso
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

-- Desenha a interface do usuário
function IsometricSimulator:drawUI()
    -- Título
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.font)
    local title = "🎮 Simulador Isométrico - Mapa Tiled (`jungle.lua`)"
    local titleWidth = self.font:getWidth(title)
    love.graphics.print(title, (love.graphics.getWidth() - titleWidth) / 2, 10)

    -- Controles
    love.graphics.setFont(self.smallFont)
    local controls = "Controles: WASD para mover | F11 Tela Cheia | 'P' para salvar Atlas"
    local controlsWidth = self.smallFont:getWidth(controls)
    love.graphics.print(controls, (love.graphics.getWidth() - controlsWidth) / 2, 40)

    local info = "Renderização por Canvas | Grid 3x3 | Mapa 2x2 infinito"
    local infoWidth = self.smallFont:getWidth(info)
    love.graphics.print(info, (love.graphics.getWidth() - infoWidth) / 2, 55)

    -- Informações do patch (canto inferior esquerdo)
    local y = love.graphics.getHeight() - 80

    -- Fundo para as informações
    love.graphics.setColor(0, 0, 0, 0.5) -- Fundo preto semi-transparente
    love.graphics.rectangle('fill', 10, y - 5, 300, 70, 10, 10)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', 10, y - 5, 300, 70, 10, 10)

    -- Textos das informações
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(self.smallFont)

    local currentPatchX = math.floor(self.player.patchX)
    local currentPatchY = math.floor(self.player.patchY)
    local patchText = string.format("Patch: %d, %d (Renderizado: %d, %d)", currentPatchX, currentPatchY,
        self.canvasRenderData.lastRenderedPatchX, self.canvasRenderData.lastRenderedPatchY)
    love.graphics.print(patchText, 20, y)

    local tileText = string.format("Tile: %d, %d", math.floor(self.player.tileX), math.floor(self.player.tileY))
    love.graphics.print(tileText, 20, y + 20)

    local globalTileX = currentPatchX * self.tilesPerPatch + self.player.tileX
    local globalTileY = currentPatchY * self.tilesPerPatch + self.player.tileY
    local globalText = string.format("Posição Global: %d, %d", math.floor(globalTileX), math.floor(globalTileY))
    love.graphics.print(globalText, 20, y + 40)

    -- Draw FPS
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, y + 60)
end

--- Biblioteca de eventos 'tiny-events' adaptada para nosso arquivo
-- Adiciona um ouvinte de evento
function Events:on(name, callback)
    self.listeners = self.listeners or {}
    self.listeners[name] = self.listeners[name] or {}
    table.insert(self.listeners[name], callback)
end

-- Emite um evento, chamando todos os seus ouvintes
function Events:emit(name, ...)
    if self.listeners and self.listeners[name] then
        for _, callback in ipairs(self.listeners[name]) do
            callback(...)
        end
    end
end

-- Remove um ouvinte de evento específico
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

-- Inicializa/reseta o sistema de eventos
function Events:initialize()
    self.listeners = {}
end
