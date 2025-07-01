function love.conf(t)
    t.console = true
end

local windowWidth, windowHeight = 1280, 720
local cameraOffset
local points = {}
local generationCoroutine
local isGenerating = false
local frameCounter = 0
local maxPoints = 1280

-- Sistema de estruturas e estradas
local structures = {}
local roads = {
    nodes = {},
    paths = {},
    segments = {}
}
local roadGenerationCoroutine
local isGeneratingRoads = false
local structureCount = 50
local minDistanceBetweenStructures = 100

-- Cores (convertidas para a escala 0-1 do LÖVE 11+)
local colors = {
    background = {11/255, 4/255, 11/255}, --#0b040b
    continent = {17/255, 33/255, 63/255},
    grid = {108/255, 154/255, 221/255, 12/255},
    -- Cores sutis para estruturas e estradas que complementam o tema
    structure = {35/255, 55/255, 85/255},
    road = {33/255, 75/255, 160/255, 0.3}, -- #214BA0
    roadOutline = {15/255, 25/255, 40/255, 0.1}
}

-- Função para verificar se um ponto está dentro do polígono do continente
function pointInPolygon(x, y, polygon)
    local n = #polygon / 2
    local inside = false
    local p1x, p1y = polygon[1], polygon[2]
    
    for i = 1, n do
        local p2x, p2y
        if i == n then
            p2x, p2y = polygon[1], polygon[2]
        else
            p2x, p2y = polygon[i * 2 + 1], polygon[i * 2 + 2]
        end
        
        if y > math.min(p1y, p2y) then
            if y <= math.max(p1y, p2y) then
                if x <= math.max(p1x, p2x) then
                    if p1y ~= p2y then
                        local xinters = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                        if p1x == p2x or x <= xinters then
                            inside = not inside
                        end
                    end
                end
            end
        end
        p1x, p1y = p2x, p2y
    end
    
    return inside
end

-- Função para verificar se um ponto está visível na tela considerando a projeção isométrica
function pointInScreen(x, y)
    local isoX, isoY = toIso(x, y)
    -- Adicionar margem para permitir estruturas próximas às bordas
    local margin = 50
    return isoX >= -margin and isoX <= windowWidth + margin and 
           isoY >= -margin and isoY <= windowHeight + margin
end

-- Converter coordenadas da tela de volta para coordenadas do mundo (inversa da projeção isométrica)
function fromIso(isoX, isoY)
    local scale = 1.5
    -- Remover o offset da câmera
    local adjustedIsoX = isoX - cameraOffset.x
    local adjustedIsoY = isoY - cameraOffset.y
    
    -- Fórmula inversa da projeção isométrica
    local cartesianX = (adjustedIsoX / (0.7 * scale) + adjustedIsoY / (0.35 * scale)) / 2
    local cartesianY = (adjustedIsoY / (0.35 * scale) - adjustedIsoX / (0.7 * scale)) / 2
    
    -- Converter de volta para coordenadas do mundo
    local worldX = cartesianX + windowWidth / 2
    local worldY = cartesianY + windowHeight / 2
    
    return worldX, worldY
end

-- Calcular área visível da tela em coordenadas do mundo
function getVisibleWorldBounds()
    -- Cantos da tela em coordenadas isométricas
    local corners = {
        {0, 0},
        {windowWidth, 0},
        {windowWidth, windowHeight},
        {0, windowHeight}
    }
    
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    
    -- Converter cada canto para coordenadas do mundo
    for _, corner in ipairs(corners) do
        local worldX, worldY = fromIso(corner[1], corner[2])
        minX = math.min(minX, worldX)
        maxX = math.max(maxX, worldX)
        minY = math.min(minY, worldY)
        maxY = math.max(maxY, worldY)
    end
    
    return minX, minY, maxX, maxY
end

-- Gerar estruturas aleatoriamente dentro do continente
function generateStructures()
    structures = {}
    local attempts = 0
    local maxAttempts = 5000
    
    -- Obter limites da área visível
    local minScreenX, minScreenY, maxScreenX, maxScreenY = getVisibleWorldBounds()
    
    while #structures < structureCount and attempts < maxAttempts do
        attempts = attempts + 1
        
        -- Gerar posição aleatória dentro da área visível
        local x = minScreenX + love.math.random() * (maxScreenX - minScreenX)
        local y = minScreenY + love.math.random() * (maxScreenY - minScreenY)
        
        -- Verificar se está dentro do continente E visível na tela
        if pointInPolygon(x, y, points) and pointInScreen(x, y) then
            -- Verificar distância mínima de outras estruturas
            local tooClose = false
            for _, existingStructure in ipairs(structures) do
                local dist = distance(x, y, existingStructure.x, existingStructure.y)
                if dist < minDistanceBetweenStructures then
                    tooClose = true
                    break
                end
            end
            
            -- Só adicionar se não estiver muito próxima de outras
            if not tooClose then
                table.insert(structures, {
                    x = x,
                    y = y,
                    type = love.math.random(1, 3), -- Tipos diferentes de estruturas
                    id = #structures + 1
                })
            end
        end
    end
    
    print("LOG: " .. #structures .. " estruturas geradas na área visível do continente (espaçamento mínimo: " .. minDistanceBetweenStructures .. ").")
end

-- Calcular distância entre dois pontos
function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Algoritmo A* simplificado para encontrar caminhos entre estruturas
function findPath(startX, startY, endX, endY)
    local path = {}
    
    -- Usar linha direta com perturbação para simular relevo
    local steps = math.floor(distance(startX, startY, endX, endY) / 15)
    steps = math.max(steps, 3)
    
    for i = 0, steps do
        local t = i / steps
        local x = startX + (endX - startX) * t
        local y = startY + (endY - startY) * t
        
        -- Adicionar perturbação para simular contorno de relevo, mas só se estiver dentro do continente
        if i > 0 and i < steps then
            local attempts = 0
            local originalX, originalY = x, y
            
            repeat
                attempts = attempts + 1
                local perturbStrength = 20
                x = originalX + (love.math.random() - 0.5) * perturbStrength
                y = originalY + (love.math.random() - 0.5) * perturbStrength
            until pointInPolygon(x, y, points) or attempts > 10
            
            -- Se não conseguiu encontrar um ponto válido no continente, usar o original
            if attempts > 10 then
                x, y = originalX, originalY
            end
        end
        
        -- Só adicionar o ponto se estiver dentro do continente
        if pointInPolygon(x, y, points) then
            table.insert(path, {x = x, y = y})
        end
    end
    
    -- Garantir que sempre temos pelo menos o ponto inicial e final se estiverem no continente
    if #path == 0 then
        if pointInPolygon(startX, startY, points) then
            table.insert(path, {x = startX, y = startY})
        end
        if pointInPolygon(endX, endY, points) then
            table.insert(path, {x = endX, y = endY})
        end
    end
    
    return path
end

-- Suavizar uma estrada usando interpolação
function smoothRoad(path)
    if #path < 3 then
        return path -- Não há o que suavizar
    end
    
    local smoothedPath = {}
    local smoothFactor = 0.3 -- Força da suavização (0-1)
    
    -- Manter o primeiro ponto
    table.insert(smoothedPath, {x = path[1].x, y = path[1].y})
    
    -- Suavizar pontos intermediários
    for i = 2, #path - 1 do
        local prevPoint = path[i - 1]
        local currentPoint = path[i]
        local nextPoint = path[i + 1]
        
        -- Calcular ponto suavizado usando média ponderada
        local smoothedX = currentPoint.x + smoothFactor * (prevPoint.x + nextPoint.x - 2 * currentPoint.x) / 2
        local smoothedY = currentPoint.y + smoothFactor * (prevPoint.y + nextPoint.y - 2 * currentPoint.y) / 2
        
        -- Verificar se o ponto suavizado ainda está no continente
        if pointInPolygon(smoothedX, smoothedY, points) then
            table.insert(smoothedPath, {x = smoothedX, y = smoothedY})
        else
            -- Se não estiver, usar o ponto original
            table.insert(smoothedPath, {x = currentPoint.x, y = currentPoint.y})
        end
    end
    
    -- Manter o último ponto
    table.insert(smoothedPath, {x = path[#path].x, y = path[#path].y})
    
    return smoothedPath
end

-- Adicionar pontos intermediários para curvas mais suaves
function addIntermediatePoints(path)
    if #path < 2 then
        return path
    end
    
    local detailedPath = {}
    
    for i = 1, #path - 1 do
        local p1 = path[i]
        local p2 = path[i + 1]
        
        -- Adicionar o ponto atual
        table.insert(detailedPath, {x = p1.x, y = p1.y})
        
        -- Calcular a distância entre pontos
        local dist = distance(p1.x, p1.y, p2.x, p2.y)
        
        -- Se a distância for grande, adicionar pontos intermediários
        if dist > 30 then
            local numIntermediatePoints = math.floor(dist / 20)
            for j = 1, numIntermediatePoints do
                local t = j / (numIntermediatePoints + 1)
                local interpX = p1.x + (p2.x - p1.x) * t
                local interpY = p1.y + (p2.y - p1.y) * t
                
                -- Adicionar pequena perturbação para naturalidade
                interpX = interpX + (love.math.random() - 0.5) * 8
                interpY = interpY + (love.math.random() - 0.5) * 8
                
                -- Só adicionar se estiver no continente
                if pointInPolygon(interpX, interpY, points) then
                    table.insert(detailedPath, {x = interpX, y = interpY})
                end
            end
        end
    end
    
    -- Adicionar o último ponto
    table.insert(detailedPath, {x = path[#path].x, y = path[#path].y})
    
    return detailedPath
end

-- Gerar estradas conectando estruturas
function generateRoads()
    print("LOG: Iniciando geração de estradas...")
    roads = {nodes = {}, paths = {}, segments = {}}
    
    -- Copiar estruturas como nós da rede de estradas
    for _, structure in ipairs(structures) do
        table.insert(roads.nodes, {
            x = structure.x,
            y = structure.y,
            id = structure.id
        })
    end
    
    local roadsGenerated = 0
    
    -- Conectar cada estrutura à sua mais próxima e a algumas outras
    for i, nodeA in ipairs(roads.nodes) do
        local connections = 0
        local maxConnections = love.math.random(2, 4)
        
        -- Encontrar estruturas próximas para conectar
        local distances = {}
        for j, nodeB in ipairs(roads.nodes) do
            if i ~= j then
                local dist = distance(nodeA.x, nodeA.y, nodeB.x, nodeB.y)
                -- Só considerar conexões que não sejam extremamente longas
                if dist < windowWidth * 0.8 then
                    table.insert(distances, {node = nodeB, distance = dist, index = j})
                end
            end
        end
        
        -- Ordenar por distância
        table.sort(distances, function(a, b) return a.distance < b.distance end)
        
        -- Conectar aos nós mais próximos
        for k = 1, math.min(maxConnections, #distances) do
            local nodeB = distances[k].node
            
            -- Verificar se já existe uma conexão
            local alreadyConnected = false
            for _, path in ipairs(roads.paths) do
                if (path.startId == nodeA.id and path.endId == nodeB.id) or
                   (path.startId == nodeB.id and path.endId == nodeA.id) then
                    alreadyConnected = true
                    break
                end
            end
            
            if not alreadyConnected then
                local path = findPath(nodeA.x, nodeA.y, nodeB.x, nodeB.y)
                -- Só adicionar se o caminho tem pontos válidos
                if #path > 1 then
                    -- Aplicar suavização à estrada
                    path = addIntermediatePoints(path)
                    path = smoothRoad(path)
                    
                    table.insert(roads.paths, {
                        startId = nodeA.id,
                        endId = nodeB.id,
                        points = path
                    })
                    connections = connections + 1
                    roadsGenerated = roadsGenerated + 1
                end
            end
        end
        
        coroutine.yield()
    end
    
    print("LOG: " .. roadsGenerated .. " estradas suavizadas geradas conectando estruturas na área visível.")
    isGeneratingRoads = false
end

function toIso(x, y)
    local scale = 1.5 -- Ajustado para a nova resolução e para ver as bordas
    local cartesianX = (x - windowWidth / 2)
    local cartesianY = (y - windowHeight / 2)
      
    local isoX = (cartesianX - cartesianY) * 0.7 * scale
    local isoY = (cartesianX + cartesianY) * 0.35 * scale
      
    return isoX + cameraOffset.x, isoY + cameraOffset.y
end

function subdivideContinent()
    print("LOG: Corrotina iniciada com segurança.")
    local lerp = function(a, b, t) return a + (b - a) * t end
    local iterations = 0

    while #points < maxPoints and iterations < 10 do -- Dupla proteção
        iterations = iterations + 1
        print("LOG: Corrotina - Iteração " .. iterations .. " - Pontos: " .. (#points/2))
        
        local npoints = {}
        local L = #points
        
        -- Verificação de segurança
        if L < 2 then
            print("LOG: ERRO - Lista de pontos muito pequena: " .. L)
            break
        end
        
        local nz = math.min(math.pow(1 / L, 0.85), 0.1) * 0.75
        
        for i = 1, L, 2 do
            -- Verificação adicional
            if i + 1 > L then
                print("LOG: ERRO - Índice fora dos limites: i=" .. i .. ", L=" .. L)
                break
            end
            
            local mx, my, disAB, disAC, disBC
            local fx, fy, gx, gy, d, int
            
            fx = points[i]
            fy = points[i + 1]
            
            local next_point_idx = i + 2
            if next_point_idx > L then
                next_point_idx = 1
            end
            
            -- Verificação de segurança adicional
            if next_point_idx + 1 > L then
                print("LOG: ERRO - Próximo ponto fora dos limites")
                break
            end
            
            gx = points[next_point_idx]
            gy = points[next_point_idx + 1]

            local attempts = 0
            repeat
                attempts = attempts + 1
                if attempts > 50 then -- Reduzido para evitar loops longos
                    break
                end
                
                int = 0.25 + love.math.random() * 0.5
                d = math.atan2(fy - gy, fx - gx)
                mx = lerp(fx, gx, int) + (-250 + love.math.random(500)) * nz - (-2250 + love.math.random(4000)) * nz * math.sin(d)
                my = lerp(fy, gy, int) + (-250 + love.math.random(500)) * nz + (-2250 + love.math.random(4000)) * nz * math.cos(d)
                
                disAB = math.sqrt((fx - mx)^2 + (fy - my)^2)
                disAC = math.sqrt((fx - gx)^2 + (fy - gy)^2)
                disBC = math.sqrt((gx - mx)^2 + (gy - my)^2)
            until (disBC <= disAC and disAB <= disAC) or attempts > 50
            
            table.insert(npoints, fx)
            table.insert(npoints, fy)
            table.insert(npoints, mx)
            table.insert(npoints, my)
        end
        
        points = npoints
        coroutine.yield() -- Pausa após cada iteração completa
    end
    
    isGenerating = false
    print("LOG: Corrotina concluída com segurança. Pontos finais: " .. (#points/2))
    
    -- AGORA que o continente está finalizado, ancorar a câmara na melhor posição
    print("LOG: Ancorando câmara com base no continente final...")
    
    -- Calcular os limites do continente FINAL para ancorar a câmara numa extremidade
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    
    for i = 1, #points, 2 do
        if points[i] < minX then minX = points[i] end
        if points[i] > maxX then maxX = points[i] end
        if points[i+1] < minY then minY = points[i+1] end
        if points[i+1] > maxY then maxY = points[i+1] end
    end
    
    -- Calcular o centro do continente final para criar o offset
    local centerX = (minX + maxX) / 2
    local centerY = (minY + maxY) / 2
    
    local offsetStrength = 0.8 -- Força do puxão para o centro (0 = sem puxão, 1 = totalmente no centro)
    -- Escolher aleatoriamente uma das 4 extremidades para ancorar a câmara
    -- Mas com offset que puxa em direção ao centro para reduzir oceano visível
    local anchorPositions = {
        { x = minX + windowWidth * offsetStrength, y = minY + windowHeight * offsetStrength }, -- Canto superior-esquerdo
        { x = maxX - windowWidth * offsetStrength, y = minY + windowHeight * offsetStrength }, -- Canto superior-direito  
        { x = minX + windowWidth * offsetStrength, y = maxY - windowHeight * offsetStrength }, -- Canto inferior-esquerdo
        { x = maxX - windowWidth * offsetStrength, y = maxY - windowHeight * offsetStrength }  -- Canto inferior-direito
    }
    
    local selectedAnchor = anchorPositions[love.math.random(1, 4)]
    
    -- Aplicar offset que puxa a câmara em direção ao centro do continente final
    local centerPullStrength = 0.3 -- Força do puxão para o centro (0 = sem puxão, 1 = totalmente no centro)
    local finalX = selectedAnchor.x + (centerX - selectedAnchor.x) * centerPullStrength
    local finalY = selectedAnchor.y + (centerY - selectedAnchor.y) * centerPullStrength
    
    cameraOffset = { x = finalX, y = finalY }
    
    print("LOG: Câmara ancorada numa extremidade do continente FINAL.")
    
    -- Após gerar o continente, gerar estruturas
    generateStructures()
    
    -- Iniciar geração de estradas
    if #structures > 1 then
        roadGenerationCoroutine = coroutine.create(generateRoads)
        isGeneratingRoads = true
        print("LOG: Iniciando geração de estradas...")
    else
        print("LOG: Poucas estruturas para gerar estradas.")
    end
end

function love.load()
    print("LOG: Versão com câmara ancorada numa extremidade...")
    love.window.setMode(windowWidth, windowHeight, { resizable = false })
    love.window.setTitle("Mapa Tático - CÂMARA ANCORADA")

    -- Gerar polígono inicial do continente
    points = {}
    local polygon = math.floor(3 + love.math.random() * 2.5)
    local na = love.math.random() * math.pi
    local radiusScale = 1.2 -- Ajustado: grande o suficiente para bordas próximas, mas visíveis
    
    for d = 0, 1, 1 / polygon do
        -- Usar a menor dimensão para garantir que cabe na tela com bordas visíveis
        local baseRadius = math.min(windowWidth, windowHeight) * radiusScale
        table.insert(points, windowWidth * 0.5 + baseRadius * math.sin(d * math.pi * 2 + na))
        table.insert(points, windowHeight * 0.5 + baseRadius * math.cos(d * math.pi * 2 + na))
    end

    print("LOG: Polígono inicial criado com " .. (#points/2) .. " pontos.")
    
    -- Câmara temporária centrada durante a geração
    cameraOffset = { x = windowWidth / 2, y = windowHeight / 2 }
    
    -- Criar corrotina para subdivisão
    generationCoroutine = coroutine.create(subdivideContinent)
    if generationCoroutine then
        isGenerating = true
        print("LOG: Corrotina criada com sucesso.")
    else
        print("LOG: ERRO - Falha ao criar corrotina.")
    end
    
    print("LOG: Inicialização concluída.")
end

function love.update(dt)
    frameCounter = frameCounter + 1
    
    -- Atualizar geração do continente
    if isGenerating and generationCoroutine then
        -- Verificar o estado da corrotina antes de prosseguir
        local status = coroutine.status(generationCoroutine)
        if status == "dead" then
            print("LOG: Corrotina morreu inesperadamente.")
            isGenerating = false
            return
        end
        
        local ok, err = coroutine.resume(generationCoroutine)
        if not ok then
            print("LOG: ERRO FATAL NA CORROTINA: " .. tostring(err))
            print("--- STACK TRACE ---")
            print(debug.traceback(generationCoroutine, err, 2))
            print("--- FIM STACK TRACE ---")
            isGenerating = false
        end
    end
    
    -- Atualizar geração de estradas
    if isGeneratingRoads and roadGenerationCoroutine then
        local status = coroutine.status(roadGenerationCoroutine)
        if status == "dead" then
            print("LOG: Corrotina de estradas concluída.")
            isGeneratingRoads = false
            return
        end
        
        local ok, err = coroutine.resume(roadGenerationCoroutine)
        if not ok then
            print("LOG: ERRO na geração de estradas: " .. tostring(err))
            isGeneratingRoads = false
        end
    end
end

function love.draw()
    love.graphics.clear(colors.background[1], colors.background[2], colors.background[3])

    -- Desenha o continente
    love.graphics.setColor(colors.continent)
    local isoPoints = {}
    for i = 1, #points, 2 do
        local isoX, isoY = toIso(points[i], points[i+1])
        table.insert(isoPoints, isoX)
        table.insert(isoPoints, isoY)
    end
    love.graphics.polygon('fill', isoPoints)

    -- Desenhar estradas suavizadas
    if #roads.paths > 0 then
        for _, path in ipairs(roads.paths) do
            if #path.points > 1 then
                -- Primeiro desenhar contorno
                love.graphics.setColor(colors.roadOutline)
                love.graphics.setLineWidth(1)
                for i = 1, #path.points - 1 do
                    local point1 = path.points[i]
                    local point2 = path.points[i+1]
                    
                    -- Verificar se ambos os pontos estão dentro do continente
                    if pointInPolygon(point1.x, point1.y, points) and pointInPolygon(point2.x, point2.y, points) then
                        local x1, y1 = toIso(point1.x, point1.y)
                        local x2, y2 = toIso(point2.x, point2.y)
                        love.graphics.line(x1, y1, x2, y2)
                    end
                end
                
                -- Depois desenhar estrada principal
                love.graphics.setColor(colors.road)
                love.graphics.setLineWidth(2)
                for i = 1, #path.points - 1 do
                    local point1 = path.points[i]
                    local point2 = path.points[i+1]
                    
                    -- Verificar se ambos os pontos estão dentro do continente
                    if pointInPolygon(point1.x, point1.y, points) and pointInPolygon(point2.x, point2.y, points) then
                        local x1, y1 = toIso(point1.x, point1.y)
                        local x2, y2 = toIso(point2.x, point2.y)
                        love.graphics.line(x1, y1, x2, y2)
                    end
                end
            end
        end
    end

    -- Desenhar estruturas
    if #structures > 0 then
        for _, structure in ipairs(structures) do
            local isoX, isoY = toIso(structure.x, structure.y)
            
            love.graphics.setColor(colors.structure)
            -- Diferentes tipos de estruturas (placeholder) - mais sutis
            if structure.type == 1 then
                -- Cidade (círculo grande)
                love.graphics.circle('fill', isoX, isoY, 6)
                love.graphics.setColor(colors.structure[1] + 0.2, colors.structure[2] + 0.2, colors.structure[3] + 0.2)
                love.graphics.circle('line', isoX, isoY, 6)
            elseif structure.type == 2 then
                -- Forte (quadrado)
                love.graphics.rectangle('fill', isoX - 4, isoY - 4, 8, 8)
                love.graphics.setColor(colors.structure[1] + 0.2, colors.structure[2] + 0.2, colors.structure[3] + 0.2)
                love.graphics.rectangle('line', isoX - 4, isoY - 4, 8, 8)
            else
                -- Vila (círculo pequeno)
                love.graphics.circle('fill', isoX, isoY, 3)
                love.graphics.setColor(colors.structure[1] + 0.2, colors.structure[2] + 0.2, colors.structure[3] + 0.2)
                love.graphics.circle('line', isoX, isoY, 3)
            end
        end
    end

    -- Desenha uma grelha tática muito densa por cima de tudo
    love.graphics.setColor(colors.grid[1], colors.grid[2], colors.grid[3], colors.grid[4])
    love.graphics.setLineWidth(1)
    
    local gridSize = 25 -- Ajustado para 1920x1080
    local range = 60 -- Maior alcance para a resolução maior
    local halfW = windowWidth / 2
    local halfH = windowHeight / 2
    
    for i = -range, range do
        local p1_h_x, p1_h_y = toIso(i * gridSize + halfW, -range * gridSize + halfH)
        local p2_h_x, p2_h_y = toIso(i * gridSize + halfW, range * gridSize + halfH)
        love.graphics.line(p1_h_x, p1_h_y, p2_h_x, p2_h_y)

        local p1_v_x, p1_v_y = toIso(-range * gridSize + halfW, i * gridSize + halfH)
        local p2_v_x, p2_v_y = toIso(range * gridSize + halfW, i * gridSize + halfH)
        love.graphics.line(p1_v_x, p1_v_y, p2_v_x, p2_v_y)
    end
    
    -- Texto de estado
    love.graphics.setColor(1, 1, 1)
    if isGenerating then
        love.graphics.print("Gerando continente com corrotinas seguras...", 10, 10)
    elseif isGeneratingRoads then
        love.graphics.print("Gerando estradas suavizadas na área visível...", 10, 10)
    else
        local statusText = "Geração concluída - " .. (#points/2) .. " pontos do continente"
        if #structures > 0 then
            statusText = statusText .. " | " .. #structures .. " estruturas visíveis | " .. #roads.paths .. " estradas suavizadas | FPS: " .. love.timer.getFPS()
        end
        love.graphics.print(statusText, 10, 10)
    end
end

function love.resize(w, h)
    -- A função love.resize está a ser chamada em loop por uma razão desconhecida
    -- e a causar problemas de performance. Desativada por completo para garantir estabilidade.
end 