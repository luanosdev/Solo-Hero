-------------------------------------------------------------------------
--- Gerencia o mapa procedural para a tela de portais
-------------------------------------------------------------------------

local colors = require("src.ui.colors")

---@class Structure
---@field x number Coordenada X central da estrutura
---@field y number Coordenada Y central da estrutura
---@field imageId number ID da imagem da estrutura (índice em structureImages)
---@field id number ID único da estrutura

---@class RoadPoint
---@field x number
---@field y number

---@class RoadPath
---@field startId number
---@field endId number
---@field points RoadPoint[] Lista de pontos da estrada

---@class RoadData
---@field nodes Structure[] Lista de nós da estrada
---@field paths RoadPath[] Lista de caminhos da estrada
---@field segments table Lista de segmentos da estrada


--- Componente responsável por gerar e renderizar o mapa procedural para a tela de portais
---@class LobbyMapPortals
---@field continentPoints number[] Lista de pontos do polígono do continente (x,y alternados)
---@field structures Structure[] Lista de estruturas geradas no continente
---@field roads RoadData[] Lista de estradas conectando estruturas
---@field isGenerating boolean Se o mapa está sendo gerado
---@field isGeneratingRoads boolean Se as estradas estão sendo geradas
---@field continentReadyForProcessing boolean Se o continente está pronto para processamento
---@field structuresGenerated boolean Garante que estruturas sejam geradas apenas uma vez
---@field generationCoroutine thread|nil Corrotina para geração do continente
---@field roadGenerationCoroutine thread|nil Corrotina para geração de estradas
---@field cameraOffset Vector2D Offset da câmera isométrica
---@field originalCameraOffset Vector2D Offset original da câmera (antes do zoom)
---@field frameCounter number Contador de frames para controle de performance
---@field maxPoints number Número máximo de pontos do continente
---@field currentZoom number Zoom atual da câmera
---@field targetZoom number Zoom alvo da câmera
---@field originalZoom number Zoom original da câmera (antes do zoom)
---@field zoomSmoothFactor number Fator de suavização do zoom
---@field isZoomedIn boolean Se está em modo zoom
---@field zoomTarget Vector2D|nil Posição de zoom alvo (para portal selecionado)
---@field structureImages love.Image[]
local LobbyMapPortals = {}
LobbyMapPortals.__index = LobbyMapPortals

-- Configurações do mapa
local CONFIG = {
    VIRTUAL_MAP_WIDTH = 3000,     -- Largura virtual do mapa gerado
    VIRTUAL_MAP_HEIGHT = 2000,    -- Altura virtual do mapa gerado
    MAX_POINTS = 1280,            -- Máximo de pontos do continente
    STRUCTURE_COUNT = 30,         -- Número de estruturas
    MIN_STRUCTURE_DISTANCE = 200, -- Distância mínima entre estruturas
    STRUCTURE_SCALE = 0.5,        -- Escala das estruturas desenhadas
    GRID_SIZE = 25,               -- Tamanho da grade tática
    ISO_SCALE = 1.5,              -- Escala da projeção isométrica (igual ao map.lua)
    GRID_RANGE = 60,              -- Alcance da grade tática (igual ao map.lua)

    -- === CONFIGURAÇÕES DA CÂMERA ===
    -- Valores de 0.1 a 1.0: câmera mais próxima às bordas (mostra mais costa)
    -- Valores próximos de 0: câmera bem nas bordas (máxima visibilidade da costa)
    -- Valores próximos de 1: câmera mais centralizada
    CAMERA_BORDER_DISTANCE = 0.3, -- Distância das bordas (0.1 = muito nas bordas, 0.8 = mais centralizado)
    CAMERA_CENTER_PULL = 0.2,     -- Pull para o centro (0 = sem pull, 0.5 = pull forte)

    -- === ANÁLISE DE NATURALIDADE ===
    FOCUS_NATURAL_SIDES = 3,    -- Quantos lados naturais focar (1-4, 2 é recomendado)
    NATURAL_SIDE_THRESHOLD = 3, -- Complexidade mínima para considerar "natural"

    -- === OTIMIZAÇÕES FUTURAS ===
    -- TODO: Implementar geração seletiva de deformações
    -- Ideia: aplicar subdivisão apenas nos lados que serão mostrados pela câmera
    -- Benefícios: melhor performance + foco na qualidade visual onde importa
    -- Implementação: modificar _subdivideContinent para processar apenas lados específicos

    -- FORÇA POSIÇÃO ESPECÍFICA (para testes):
    -- nil = posição aleatória baseada em lados naturais, 1-X = posição específica da lista
    FORCE_CAMERA_POSITION = nil,

    STRUCTURE_GENERATION_ATTEMPTS_MULTIPLIER = 800 -- Multiplicador para tentativas de geração (STRUCTURE_COUNT * X)
}


--- Cria nova instância do LobbyMapPortals
---@return LobbyMapPortals
function LobbyMapPortals:new()
    local instance = setmetatable({}, LobbyMapPortals)

    -- Estado da geração
    instance.continentPoints = {}
    instance.structures = {}
    instance.roads = {
        nodes = {},
        paths = {}
    }
    instance.isGenerating = false
    instance.isGeneratingRoads = false
    instance.continentReadyForProcessing = false -- NOVO: Estado para controlar o fluxo
    instance.structuresGenerated = false         -- NOVO: Garante que estruturas sejam geradas apenas uma vez
    instance.generationCoroutine = nil
    instance.roadGenerationCoroutine = nil
    instance.frameCounter = 0
    instance.maxPoints = CONFIG.MAX_POINTS
    instance._debugPrinted = false

    -- Carregar imagens das estruturas
    instance.structureImages = {}
    for i = 1, 11 do
        local path = string.format("assets/images/buildings/build-%d.png", i)
        local ok, img = pcall(love.graphics.newImage, path)
        if ok then
            table.insert(instance.structureImages, img)
        else
            Logger.error("LobbyMapPortals:new", "Falha ao carregar imagem da estrutura: " .. path)
        end
    end

    -- Configuração inicial da câmera (será ajustada após geração, usando dimensões reais como no map.lua)
    local windowWidth = ResolutionUtils.getGameWidth()
    local windowHeight = ResolutionUtils.getGameHeight()
    instance.cameraOffset = {
        x = windowWidth / 2,
        y = windowHeight / 2
    }

    -- Salvar posição original da câmera (será atualizada após _anchorCamera)
    instance.originalCameraOffset = {
        x = windowWidth / 2,
        y = windowHeight / 2
    }

    -- Estado de zoom/pan
    instance.currentZoom = 1.0
    instance.targetZoom = 1.0
    instance.originalZoom = 1.0
    instance.zoomSmoothFactor = 5.0
    instance.isZoomedIn = false
    instance.zoomTarget = nil
    instance.targetCameraOffset = nil

    -- Canvas para renderização estática
    instance.staticMapCanvas = nil ---@type love.Canvas|nil
    instance.isMapRenderedToCanvas = false ---@type boolean

    return instance
end

--- Inicia a geração do mapa procedural
function LobbyMapPortals:generateMap()
    if self.isGenerating then
        return
    end

    -- Gerar polígono inicial do continente
    self.continentPoints = {}
    local polygon = math.floor(3 + love.math.random() * 2.5)
    local na = love.math.random() * math.pi
    local radiusScale = 1.2

    -- Calcular baseRadius usando as dimensões reais da tela como no map.lua,
    -- mas adaptado para as dimensões virtuais para manter a mesma proporção visual
    local windowWidth = ResolutionUtils.getGameWidth()
    local windowHeight = ResolutionUtils.getGameHeight()
    local baseRadius = math.min(windowWidth, windowHeight) * radiusScale

    for d = 0, 1, 1 / polygon do
        table.insert(self.continentPoints, CONFIG.VIRTUAL_MAP_WIDTH * 0.5 + baseRadius * math.sin(d * math.pi * 2 + na))
        table.insert(self.continentPoints, CONFIG.VIRTUAL_MAP_HEIGHT * 0.5 + baseRadius * math.cos(d * math.pi * 2 + na))
    end

    Logger.info("lobby_map_portals.generateMap.initial",
        "[LobbyMapPortals] Polígono inicial criado com " .. (#self.continentPoints / 2) .. " pontos")

    -- Criar corrotina para subdivisão
    self.generationCoroutine = coroutine.create(function() self:_subdivideContinent() end)
    if self.generationCoroutine then
        self.isGenerating = true
        Logger.info("lobby_map_portals.generateMap.coroutine", "[LobbyMapPortals] Corrotina de geração criada")
    else
        Logger.error("lobby_map_portals.generateMap.error", "[LobbyMapPortals] Falha ao criar corrotina de geração")
    end
end

--- Subdivide o continente usando corrotinas para melhor performance
function LobbyMapPortals:_subdivideContinent()
    Logger.info("lobby_map_portals._subdivideContinent", "[LobbyMapPortals] Iniciando subdivisão do continente")

    local lerp = function(a, b, t) return a + (b - a) * t end
    local iterations = 0

    while #self.continentPoints < self.maxPoints and iterations < 10 do
        iterations = iterations + 1
        Logger.info("lobby_map_portals._subdivideContinent.iteration",
            "[LobbyMapPortals] Iteração " .. iterations .. " - Pontos: " .. (#self.continentPoints / 2))

        local npoints = {}
        local L = #self.continentPoints

        if L < 2 then
            Logger.error("lobby_map_portals._subdivideContinent.error",
                "[LobbyMapPortals] Lista de pontos muito pequena: " .. L)
            break
        end

        local nz = math.min(math.pow(1 / L, 0.85), 0.1) * 0.75

        for i = 1, L, 2 do
            if i + 1 > L then
                Logger.error("lobby_map_portals._subdivideContinent.index_error",
                    "[LobbyMapPortals] Índice fora dos limites: i=" .. i .. ", L=" .. L)
                break
            end

            local fx, fy = self.continentPoints[i], self.continentPoints[i + 1]
            local next_point_idx = i + 2
            if next_point_idx > L then
                next_point_idx = 1
            end

            if next_point_idx + 1 > L then
                Logger.error("lobby_map_portals._subdivideContinent.next_error",
                    "[LobbyMapPortals] Próximo ponto fora dos limites")
                break
            end

            local gx, gy = self.continentPoints[next_point_idx], self.continentPoints[next_point_idx + 1]

            local mx, my
            local attempts = 0
            repeat
                attempts = attempts + 1
                if attempts > 50 then break end

                local int = 0.25 + love.math.random() * 0.5
                local d = math.atan2(fy - gy, fx - gx)
                mx = lerp(fx, gx, int) + (-250 + love.math.random(500)) * nz -
                    (-2250 + love.math.random(4000)) * nz * math.sin(d)
                my = lerp(fy, gy, int) + (-250 + love.math.random(500)) * nz +
                    (-2250 + love.math.random(4000)) * nz * math.cos(d)

                local disAB = math.sqrt((fx - mx) ^ 2 + (fy - my) ^ 2)
                local disAC = math.sqrt((fx - gx) ^ 2 + (fy - gy) ^ 2)
                local disBC = math.sqrt((gx - mx) ^ 2 + (gy - my) ^ 2)
            until (disBC <= disAC and disAB <= disAC) or attempts > 50

            table.insert(npoints, fx)
            table.insert(npoints, fy)
            table.insert(npoints, mx)
            table.insert(npoints, my)
        end

        self.continentPoints = npoints
        coroutine.yield()
    end

    self.isGenerating = false
    Logger.info("lobby_map_portals._subdivideContinent.complete",
        "[LobbyMapPortals] Subdivisão concluída. Pontos finais: " .. (#self.continentPoints / 2))

    -- A corrotina agora apenas sinaliza que terminou. A função update()
    -- será responsável por chamar os próximos passos na ordem correta.
    self.continentReadyForProcessing = true
end

--- Ancora a câmera numa posição otimizada do continente
function LobbyMapPortals:_anchorCamera()
    Logger.info("lobby_map_portals._anchorCamera",
        "[LobbyMapPortals] Ancorando câmera com base no continente final")

    -- Analisar complexidade dos lados do continente
    local sideComplexity = self:_analyzeContinentSides()
    local naturalSides = self:_identifyNaturalSides(sideComplexity)

    -- Calcular limites do continente
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge

    for i = 1, #self.continentPoints, 2 do
        if self.continentPoints[i] < minX then minX = self.continentPoints[i] end
        if self.continentPoints[i] > maxX then maxX = self.continentPoints[i] end
        if self.continentPoints[i + 1] < minY then minY = self.continentPoints[i + 1] end
        if self.continentPoints[i + 1] > maxY then maxY = self.continentPoints[i + 1] end
    end

    -- Calcular centro e dimensões do continente
    local centerX = (minX + maxX) / 2
    local centerY = (minY + maxY) / 2
    local continentWidth = maxX - minX
    local continentHeight = maxY - minY

    print("DEBUG: Dados do continente:")
    print("  Center: (" .. math.floor(centerX) .. ", " .. math.floor(centerY) .. ")")
    print("  Size: " .. math.floor(continentWidth) .. " x " .. math.floor(continentHeight))
    print("  Bounds: (" ..
        math.floor(minX) .. ", " .. math.floor(minY) .. ") to (" .. math.floor(maxX) .. ", " .. math.floor(maxY) .. ")")

    -- Margem baseada no tamanho do continente para melhor adaptação
    local offsetStrength = math.abs(CONFIG.CAMERA_BORDER_DISTANCE)
    local margin = math.min(continentWidth, continentHeight) * offsetStrength

    -- Criar posições de âncora APENAS para os lados mais naturais (2 melhores)
    local anchorPositions = {}
    local maxNaturalSides = CONFIG.FOCUS_NATURAL_SIDES -- Usar configuração

    -- Filtrar apenas lados que atendem o threshold mínimo
    local validNaturalSides = {}
    for i = 1, #naturalSides do
        if naturalSides[i].complexity >= CONFIG.NATURAL_SIDE_THRESHOLD then
            table.insert(validNaturalSides, naturalSides[i])
        end
    end

    print("DEBUG: " ..
        #validNaturalSides .. " lados atendem o threshold de naturalidade (" .. CONFIG.NATURAL_SIDE_THRESHOLD .. ")")

    -- Se não há lados naturais suficientes, usar todos os disponíveis
    local sidesToUse = #validNaturalSides > 0 and validNaturalSides or naturalSides

    for i = 1, math.min(maxNaturalSides, #sidesToUse) do
        local sideName = sidesToUse[i].name

        if sideName == "north" then
            table.insert(anchorPositions, { x = centerX, y = maxY - margin, name = "centro-superior (lado natural)" })
            table.insert(anchorPositions,
                { x = minX + margin, y = maxY - margin, name = "canto superior-esquerdo (lado natural)" })
            table.insert(anchorPositions,
                { x = maxX - margin, y = maxY - margin, name = "canto superior-direito (lado natural)" })
        elseif sideName == "south" then
            table.insert(anchorPositions, { x = centerX, y = minY + margin, name = "centro-inferior (lado natural)" })
            table.insert(anchorPositions,
                { x = minX + margin, y = minY + margin, name = "canto inferior-esquerdo (lado natural)" })
            table.insert(anchorPositions,
                { x = maxX - margin, y = minY + margin, name = "canto inferior-direito (lado natural)" })
        elseif sideName == "east" then
            table.insert(anchorPositions, { x = maxX - margin, y = centerY, name = "centro-direito (lado natural)" })
            table.insert(anchorPositions,
                { x = maxX - margin, y = minY + margin, name = "canto inferior-direito (lado natural)" })
            table.insert(anchorPositions,
                { x = maxX - margin, y = maxY - margin, name = "canto superior-direito (lado natural)" })
        elseif sideName == "west" then
            table.insert(anchorPositions, { x = minX + margin, y = centerY, name = "centro-esquerdo (lado natural)" })
            table.insert(anchorPositions,
                { x = minX + margin, y = minY + margin, name = "canto inferior-esquerdo (lado natural)" })
            table.insert(anchorPositions,
                { x = minX + margin, y = maxY - margin, name = "canto superior-esquerdo (lado natural)" })
        end
    end

    -- Fallback: se não temos posições naturais suficientes, adicionar algumas genéricas
    if #anchorPositions == 0 then
        print("DEBUG: Nenhum lado natural detectado, usando posições padrão")
        anchorPositions = {
            { x = minX + margin, y = minY + margin, name = "canto inferior-esquerdo (padrão)" },
            { x = maxX - margin, y = minY + margin, name = "canto inferior-direito (padrão)" },
            { x = centerX,       y = minY + margin, name = "centro-inferior (padrão)" }
        }
    end

    -- Escolher uma posição aleatória ou forçada
    local selectedAnchor
    if CONFIG.FORCE_CAMERA_POSITION and CONFIG.FORCE_CAMERA_POSITION >= 1 and CONFIG.FORCE_CAMERA_POSITION <= #anchorPositions then
        selectedAnchor = anchorPositions[CONFIG.FORCE_CAMERA_POSITION]
        print("DEBUG: Usando posição forçada: " .. CONFIG.FORCE_CAMERA_POSITION)
    else
        selectedAnchor = anchorPositions[love.math.random(1, #anchorPositions)]
        print("DEBUG: Usando posição aleatória dos lados naturais")
    end

    -- Aplicar pull em direção ao centro se necessário (para evitar oceano demais)
    -- VALORES NEGATIVOS: empurram para LONGE do centro (para mostrar costas)
    -- VALORES POSITIVOS: puxam para PERTO do centro (para evitar oceano)
    local centerPullStrength = CONFIG.CAMERA_CENTER_PULL
    local finalX = selectedAnchor.x + (centerX - selectedAnchor.x) * centerPullStrength
    local finalY = selectedAnchor.y + (centerY - selectedAnchor.y) * centerPullStrength

    -- === DIAGNÓSTICO DETALHADO DA CÂMERA ===
    print("=== DIAGNÓSTICO COMPLETO DA CÂMERA ===")
    print("DADOS DO CONTINENTE:")
    print("  Bounds: (" ..
        math.floor(minX) .. ", " .. math.floor(minY) .. ") to (" .. math.floor(maxX) .. ", " .. math.floor(maxY) .. ")")
    print("  Centro: (" .. math.floor(centerX) .. ", " .. math.floor(centerY) .. ")")
    print("  Tamanho: " .. math.floor(continentWidth) .. " x " .. math.floor(continentHeight))
    print("")
    print("CONFIGURAÇÕES DA CÂMERA:")
    print("  CAMERA_BORDER_DISTANCE: " .. CONFIG.CAMERA_BORDER_DISTANCE)
    print("  CAMERA_CENTER_PULL: " .. CONFIG.CAMERA_CENTER_PULL)
    print("  Margem calculada: " .. math.floor(margin))
    print("")
    print("POSICIONAMENTO:")
    print("  Âncora original: (" .. math.floor(selectedAnchor.x) .. ", " .. math.floor(selectedAnchor.y) .. ")")
    print("  Vetor anchor->center: (" ..
        math.floor(centerX - selectedAnchor.x) .. ", " .. math.floor(centerY - selectedAnchor.y) .. ")")
    print("  Pull aplicado: (" ..
        math.floor((centerX - selectedAnchor.x) * centerPullStrength) ..
        ", " .. math.floor((centerY - selectedAnchor.y) * centerPullStrength) .. ")")
    print("  Posição final: (" .. math.floor(finalX) .. ", " .. math.floor(finalY) .. ")")
    print("")

    -- Calcular distâncias da câmera às bordas do continente
    local distToBorders = {
        north = maxY - finalY,
        south = finalY - minY,
        east = maxX - finalX,
        west = finalX - minX
    }

    print("DISTÂNCIAS DA CÂMERA ÀS BORDAS:")
    for direction, dist in pairs(distToBorders) do
        print("  " .. direction .. ": " .. math.floor(dist) .. " unidades")
    end

    local closestBorder = math.min(distToBorders.north, distToBorders.south, distToBorders.east, distToBorders.west)
    print("  Borda mais próxima: " .. math.floor(closestBorder) .. " unidades")

    -- Estimativa de visibilidade (assumindo viewport ~1920x1080 e escala isométrica)
    local estimatedViewRange = 600 -- aproximação do alcance visual
    print("")
    print("ESTIMATIVA DE VISIBILIDADE:")
    print("  Alcance visual estimado: ~" .. estimatedViewRange .. " unidades")
    print("  Costa visível? " .. (closestBorder < estimatedViewRange and "SIM" or "NÃO"))
    if closestBorder >= estimatedViewRange then
        print("  PROBLEMA: Câmera muito longe das bordas!")
        print("  Sugestão: Reduzir CAMERA_BORDER_DISTANCE ou usar CAMERA_CENTER_PULL mais negativo")
    end

    -- CORREÇÃO: Converter coordenadas do mundo para coordenadas de tela
    -- finalX e finalY são coordenadas do mundo, mas agora cameraOffset precisa ser coordenadas de tela
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    -- Converter posição do mundo para posição na tela usando projeção isométrica
    local cartesianX = (finalX - CONFIG.VIRTUAL_MAP_WIDTH / 2)
    local cartesianY = (finalY - CONFIG.VIRTUAL_MAP_HEIGHT / 2)
    local isoX = (cartesianX - cartesianY) * 0.7 * CONFIG.ISO_SCALE
    local isoY = (cartesianX + cartesianY) * 0.35 * CONFIG.ISO_SCALE

    -- O cameraOffset agora representa onde na tela o centro do mapa (0,0 isométrico) deve aparecer
    -- Para mover a câmera para uma posição específica do mundo, precisamos inverter o offset
    self.cameraOffset = { x = screenW / 2 - isoX, y = screenH / 2 - isoY }

    -- Salvar posição original da câmera para poder voltar depois do zoom
    self.originalCameraOffset = { x = self.cameraOffset.x, y = self.cameraOffset.y }

    -- Debug detalhado da posição da câmera
    print("DEBUG: Posicionamento da câmera:")
    print("  Âncora selecionada: " .. selectedAnchor.name)
    print("  Posição inicial: (" .. math.floor(selectedAnchor.x) .. ", " .. math.floor(selectedAnchor.y) .. ")")
    print("  Posição final: (" .. math.floor(finalX) .. ", " .. math.floor(finalY) .. ")")
    print("  Offset strength: " .. CONFIG.CAMERA_BORDER_DISTANCE)
    print("  Margem aplicada: " .. math.floor(margin))
    print("  Posições disponíveis: " .. #anchorPositions .. " (focadas nos lados naturais)")
    print("")
    print("SISTEMA CORRIGIDO:")
    print("  ✓ Centralização automática removida - CONFIG agora funciona!")
    print("  ✓ Dupla aplicação do cameraOffset corrigida")
    print("  ✓ cameraOffset convertido corretamente para coordenadas de tela")
    print("  ✓ Configurações CONFIG agora afetam verdadeiramente a câmera")

    -- Mostrar quais lados estão sendo priorizados
    local prioritizedSides = {}
    for i = 1, math.min(maxNaturalSides, #sidesToUse) do
        table.insert(prioritizedSides, sidesToUse[i].name)
    end
    print("  Lados priorizados: " .. table.concat(prioritizedSides, ", "))

    print("")
    print("=== SOLUÇÕES PARA MOSTRAR COSTAS ===")
    print("PROBLEMA: Só vejo oceano azul, nenhuma costa visível")
    print("")
    print("SOLUÇÕES RÁPIDAS (use no console quando estiver na tela de portais):")
    print("  PortalMapComponent:applyBestSuggestion()    -- MELHOR OPÇÃO: Aplica configuração inteligente")
    print("  PortalMapComponent:suggestBestCamera()      -- Ver sugestões baseadas no continente")
    print("  PortalMapComponent:applyCamera(0.01, -1.0)  -- Aplicar configuração específica")
    print("  PortalMapComponent:findCoast()              -- Testar múltiplas configurações")
    print("  PortalMapComponent:getSideInfo()            -- Ver análise completa dos lados")
    print("")
    print("SISTEMA CORRIGIDO:")
    print("  ✓ Portal Screen não sobrescreve mais a câmera")
    print("  ✓ Configurações aplicadas são verdadeiramente PERMANENTES")
    print("  ✓ Sincronização automática entre sistemas funcionando")
    print("")
    print("SIGNIFICADO DOS VALORES:")
    print("  CAMERA_BORDER_DISTANCE: Quão próximo das bordas (menor = mais próximo)")
    print("    0.1 = próximo, 0.01 = muito próximo, 0.001 = na borda")
    print("  CAMERA_CENTER_PULL: Push para longe do centro (mais negativo = mais longe)")
    print("    -0.5 = longe, -1.0 = muito longe, -2.0 = extremamente longe")
    print("")
    print("Para aplicar permanentemente: altere CONFIG no início do arquivo")
    print("O sistema prioriza automaticamente lados com mais deformações!")

    Logger.info("lobby_map_portals._anchorCamera.complete",
        "[LobbyMapPortals] Câmera ancorada em: " .. selectedAnchor.name ..
        " (priorizando: " .. table.concat(prioritizedSides, ", ") .. ")")
end

--- Testa diferentes configurações de câmera rapidamente (TEMPORÁRIO - reverte após teste)
---@param borderDistance number Valor para CAMERA_BORDER_DISTANCE (ex: 0.05, 0.01, 0.005)
---@param centerPull number Valor para CAMERA_CENTER_PULL (ex: -1.0, -2.0, -0.5)
function LobbyMapPortals:testCamera(borderDistance, centerPull)
    if not self.continentPoints or #self.continentPoints == 0 then
        print("ERRO: Continente não foi gerado ainda!")
        return
    end

    print("\n>>> TESTANDO CÂMERA (TEMPORÁRIO): borderDistance=" ..
        borderDistance .. ", centerPull=" .. centerPull .. " <<<")

    -- Salvar configurações originais
    local originalBorderDistance = CONFIG.CAMERA_BORDER_DISTANCE
    local originalCenterPull = CONFIG.CAMERA_CENTER_PULL

    -- Aplicar configurações de teste
    CONFIG.CAMERA_BORDER_DISTANCE = borderDistance
    CONFIG.CAMERA_CENTER_PULL = centerPull

    -- Reposicionar câmera
    self:_anchorCamera()

    -- Restaurar configurações originais
    CONFIG.CAMERA_BORDER_DISTANCE = originalBorderDistance
    CONFIG.CAMERA_CENTER_PULL = originalCenterPull

    print(">>> TESTE TEMPORÁRIO CONCLUÍDO - CÂMERA VOLTARÁ À POSIÇÃO ORIGINAL <<<")
    print(">>> Para aplicar PERMANENTEMENTE, use: applyCamera(" .. borderDistance .. ", " .. centerPull .. ") <<<\n")
end

--- Aplica configurações de câmera PERMANENTEMENTE (não reverte)
---@param borderDistance number Valor para CAMERA_BORDER_DISTANCE
---@param centerPull number Valor para CAMERA_CENTER_PULL
function LobbyMapPortals:applyCamera(borderDistance, centerPull)
    if not self.continentPoints or #self.continentPoints == 0 then
        print("ERRO: Continente não foi gerado ainda!")
        return
    end

    print("\n>>> APLICANDO CÂMERA PERMANENTEMENTE: borderDistance=" ..
        borderDistance .. ", centerPull=" .. centerPull .. " <<<")

    -- Aplicar configurações PERMANENTEMENTE
    CONFIG.CAMERA_BORDER_DISTANCE = borderDistance
    CONFIG.CAMERA_CENTER_PULL = centerPull

    -- Reposicionar câmera
    self:_anchorCamera()

    print(">>> CÂMERA APLICADA PERMANENTEMENTE! <<<")
    print(">>> Para salvar no arquivo, altere CONFIG no início do arquivo <<<\n")
end

--- Sugere configurações baseadas na análise do continente atual
function LobbyMapPortals:suggestBestCamera()
    if not self.continentPoints or #self.continentPoints == 0 then
        print("ERRO: Continente não foi gerado ainda!")
        return
    end

    print("\n=== SUGESTÕES INTELIGENTES DE CÂMERA ===")

    -- Analisar continente atual
    local sideComplexity = self:_analyzeContinentSides()
    local naturalSides = self:_identifyNaturalSides(sideComplexity)

    -- Calcular limites do continente
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    for i = 1, #self.continentPoints, 2 do
        if self.continentPoints[i] < minX then minX = self.continentPoints[i] end
        if self.continentPoints[i] > maxX then maxX = self.continentPoints[i] end
        if self.continentPoints[i + 1] < minY then minY = self.continentPoints[i + 1] end
        if self.continentPoints[i + 1] > maxY then maxY = self.continentPoints[i + 1] end
    end

    local continentSize = math.min(maxX - minX, maxY - minY)

    print("ANÁLISE DO CONTINENTE ATUAL:")
    print("  Lado mais natural: " .. naturalSides[1].name .. " (complexidade: " .. naturalSides[1].complexity .. ")")
    print("  Tamanho do continente: " .. math.floor(continentSize) .. " unidades")
    print("")

    -- Sugestões baseadas no tamanho do continente
    local suggestions = {}

    -- Para continentes grandes (>2000), usar configurações mais extremas
    if continentSize > 2000 then
        table.insert(suggestions, {
            border = 0.005,
            pull = -2.0,
            reason = "Continente grande - câmera extremamente próxima às bordas"
        })
        table.insert(suggestions, {
            border = 0.001,
            pull = -3.0,
            reason = "Continente grande - configuração máxima para costas"
        })
    else
        -- Para continentes menores, configurações mais moderadas
        table.insert(suggestions, {
            border = 0.02,
            pull = -1.0,
            reason = "Continente médio - configuração balanceada"
        })
        table.insert(suggestions, {
            border = 0.01,
            pull = -1.5,
            reason = "Continente médio - mais próximo às costas"
        })
    end

    print("CONFIGURAÇÕES RECOMENDADAS:")
    for i, suggestion in ipairs(suggestions) do
        print(string.format("  %d. borderDistance=%.3f, centerPull=%.1f", i, suggestion.border, suggestion.pull))
        print("     Motivo: " .. suggestion.reason)
        print("     Comando: PortalMapComponent:applyCamera(" .. suggestion.border .. ", " .. suggestion.pull .. ")")
        print("")
    end

    -- Aplicar automaticamente a primeira sugestão se solicitado
    local bestSuggestion = suggestions[1]
    print("APLICAR MELHOR SUGESTÃO AUTOMATICAMENTE:")
    print("  PortalMapComponent:applyBestSuggestion()  -- Aplica: " ..
        bestSuggestion.border .. ", " .. bestSuggestion.pull)
    print("")
end

--- Aplica automaticamente a melhor sugestão baseada no continente atual
function LobbyMapPortals:applyBestSuggestion()
    if not self.continentPoints or #self.continentPoints == 0 then
        print("ERRO: Continente não foi gerado ainda!")
        return
    end

    -- Calcular tamanho do continente
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    for i = 1, #self.continentPoints, 2 do
        if self.continentPoints[i] < minX then minX = self.continentPoints[i] end
        if self.continentPoints[i] > maxX then maxX = self.continentPoints[i] end
        if self.continentPoints[i + 1] < minY then minY = self.continentPoints[i + 1] end
        if self.continentPoints[i + 1] > maxY then maxY = self.continentPoints[i + 1] end
    end

    local continentSize = math.min(maxX - minX, maxY - minY)

    -- Escolher configuração baseada no tamanho
    local borderDistance, centerPull
    if continentSize > 2000 then
        borderDistance = 0.005
        centerPull = -2.0
        print(">>> APLICANDO SUGESTÃO PARA CONTINENTE GRANDE <<<")
    else
        borderDistance = 0.02
        centerPull = -1.0
        print(">>> APLICANDO SUGESTÃO PARA CONTINENTE MÉDIO <<<")
    end

    -- Aplicar configuração
    self:applyCamera(borderDistance, centerPull)
end

--- Testa uma série de configurações extremas para encontrar costas
function LobbyMapPortals:findCoast()
    if not self.continentPoints or #self.continentPoints == 0 then
        print("ERRO: Continente não foi gerado ainda!")
        return
    end

    print("\n=== BUSCA AUTOMÁTICA POR COSTAS ===")
    print("IMPORTANTE: Estes são testes temporários. Para aplicar permanentemente,")
    print("use: PortalMapComponent:applyCamera(borderDistance, centerPull)")
    print("")

    local testConfigs = {
        { border = 0.01,  pull = -1.0, desc = "Muito próximo, pull forte" },
        { border = 0.005, pull = -2.0, desc = "Extremamente próximo, pull muito forte" },
        { border = 0.02,  pull = -0.8, desc = "Próximo, pull moderado" },
        { border = 0.001, pull = -3.0, desc = "Na borda absoluta, pull extremo" },
    }

    for i, config in ipairs(testConfigs) do
        print("\n--- TESTE " .. i .. ": " .. config.desc .. " ---")
        self:testCamera(config.border, config.pull)
        print("Para aplicar este teste PERMANENTEMENTE:")
        print("  PortalMapComponent:applyCamera(" .. config.border .. ", " .. config.pull .. ")")
    end

    print("\n=== BUSCA CONCLUÍDA ===")
    print("Os testes são temporários para comparação.")
    print("Para aplicar uma configuração PERMANENTEMENTE, use applyCamera()!")
    print("Exemplo: PortalMapComponent:applyCamera(0.005, -2.0)")
end

--- Gera estruturas aleatoriamente dentro do continente
function LobbyMapPortals:_generateStructures()
    self.structures = {}
    local attempts = 0
    -- Aumentar tentativas pois a área é menor e pode haver mais colisões
    local maxAttempts = CONFIG.STRUCTURE_COUNT * CONFIG.STRUCTURE_GENERATION_ATTEMPTS_MULTIPLIER

    -- Obter os limites do CONTINENTE para garantir que as estruturas fiquem nele
    local continentMinX, continentMaxX = math.huge, -math.huge
    local continentMinY, continentMaxY = math.huge, -math.huge
    if #self.continentPoints > 0 then
        for i = 1, #self.continentPoints, 2 do
            if self.continentPoints[i] < continentMinX then continentMinX = self.continentPoints[i] end
            if self.continentPoints[i] > continentMaxX then continentMaxX = self.continentPoints[i] end
            if self.continentPoints[i + 1] < continentMinY then continentMinY = self.continentPoints[i + 1] end
            if self.continentPoints[i + 1] > continentMaxY then continentMaxY = self.continentPoints[i + 1] end
        end
    else
        Logger.warn("lobby_map_portals._generateStructures.no_continent",
            "[LobbyMapPortals] Continente sem pontos, não é possível gerar estruturas.")
        return
    end

    local structuresValidated = 0

    while #self.structures < CONFIG.STRUCTURE_COUNT and attempts < maxAttempts do
        attempts = attempts + 1

        -- 1. PRIMEIRO: Escolher uma imagem da estrutura
        local imageId = love.math.random(1, #self.structureImages)
        local img = self.structureImages[imageId]

        if not img then
            Logger.warn("lobby_map_portals._generateStructures.missing_image",
                "[LobbyMapPortals] Imagem não encontrada para imageId: " .. imageId)
            goto continue
        end

        -- 2. SEGUNDO: Obter dimensões da imagem escolhida
        local imgWidth, imgHeight = img:getDimensions()
        local scaledWidth = imgWidth * CONFIG.STRUCTURE_SCALE
        local scaledHeight = imgHeight * CONFIG.STRUCTURE_SCALE

        -- 3. TERCEIRO: Gerar uma posição GARANTIDA DENTRO DO CONTINENTE
        local centerX, centerY
        local positionAttempts = 0
        repeat
            positionAttempts = positionAttempts + 1
            -- Gerar posição dentro do bounding box do continente
            local candidateX = continentMinX + love.math.random() * (continentMaxX - continentMinX)
            local candidateY = continentMinY + love.math.random() * (continentMaxY - continentMinY)

            -- Validar se o centro está no continente
            if self:_pointInPolygon(candidateX, candidateY, self.continentPoints) then
                centerX = candidateX
                centerY = candidateY
            end
        until centerX or positionAttempts > 200 -- Tentar até 200 vezes encontrar um ponto

        if not centerX then
            goto continue -- Não foi possível encontrar um ponto válido no continente
        end

        -- 4. QUARTO: Verificar se a ÁREA COMPLETA da estrutura está dentro do continente
        local structureValid = self:_validateStructureArea(centerX, centerY, scaledWidth, scaledHeight)

        if structureValid then
            -- 5. QUINTO: Verificar distância mínima de outras estruturas (considerando dimensões)
            local tooClose = false
            for _, existingStructure in ipairs(self.structures) do
                -- Calcular distância considerando as áreas das estruturas
                local existingImg = self.structureImages[existingStructure.imageId]
                local existingWidth, existingHeight = 0, 0
                if existingImg then
                    existingWidth, existingHeight = existingImg:getDimensions()
                    existingWidth = existingWidth * CONFIG.STRUCTURE_SCALE
                    existingHeight = existingHeight * CONFIG.STRUCTURE_SCALE
                end

                local dist = self:_distance(centerX, centerY, existingStructure.x, existingStructure.y)
                local minRequiredDistance = CONFIG.MIN_STRUCTURE_DISTANCE +
                    (math.max(scaledWidth, scaledHeight) + math.max(existingWidth, existingHeight)) / 4

                if dist < minRequiredDistance then
                    tooClose = true
                    break
                end
            end

            -- 6. SEXTO: Se passou em todas as validações, adicionar estrutura
            if not tooClose then
                table.insert(self.structures, {
                    x = centerX,
                    y = centerY,
                    imageId = imageId, -- Imagem já escolhida no início
                    id = #self.structures + 1
                })
                structuresValidated = structuresValidated + 1

                Logger.debug("lobby_map_portals._generateStructures.structure_placed",
                    "[LobbyMapPortals] Estrutura " .. #self.structures .. " posicionada em (" ..
                    math.floor(centerX) .. ", " .. math.floor(centerY) .. ") com imagem " .. imageId ..
                    " (dimensões: " .. math.floor(scaledWidth) .. "x" .. math.floor(scaledHeight) .. ")")
            end
        end

        ::continue::
    end

    -- Debug aprimorado
    print("DEBUG: Geração de estruturas finalizada:")
    print("  Total tentativas: " .. attempts)
    print("  Estruturas validadas e posicionadas: " .. structuresValidated)

    if #self.structures < CONFIG.STRUCTURE_COUNT then
        print("AVISO: Não foi possível gerar todas as " ..
            CONFIG.STRUCTURE_COUNT .. " estruturas. Possíveis causas:")
        print("  - Continente muito pequeno ou com formato complexo")
        print("  - Distância mínima muito alta (" .. CONFIG.MIN_STRUCTURE_DISTANCE .. ")")
        print("  - Estruturas muito grandes para a área disponível")
    end

    Logger.info("lobby_map_portals._generateStructures.complete",
        "[LobbyMapPortals] " .. #self.structures .. " estruturas geradas respeitando dimensões das imagens")
end

--- Gera estradas conectando estruturas
function LobbyMapPortals:_generateRoads()
    Logger.info("lobby_map_portals._generateRoads",
        "[LobbyMapPortals] Iniciando geração de estradas")

    self.roads = {
        nodes = {},
        paths = {}
    }

    -- Copiar estruturas como nós
    for _, structure in ipairs(self.structures) do
        table.insert(self.roads.nodes, {
            x = structure.x,
            y = structure.y,
            id = structure.id
        })
    end

    local roadsGenerated = 0

    -- Conectar estruturas
    for i, nodeA in ipairs(self.roads.nodes) do
        local connections = 0
        local maxConnections = love.math.random(2, 4)

        -- Encontrar estruturas próximas
        local distances = {}
        for j, nodeB in ipairs(self.roads.nodes) do
            if i ~= j then
                local dist = self:_distance(nodeA.x, nodeA.y, nodeB.x, nodeB.y)
                if dist < CONFIG.VIRTUAL_MAP_WIDTH * 0.8 then
                    table.insert(distances, { node = nodeB, distance = dist, index = j })
                end
            end
        end

        -- Ordenar por distância
        table.sort(distances, function(a, b) return a.distance < b.distance end)

        -- Conectar aos nós mais próximos
        for k = 1, math.min(maxConnections, #distances) do
            local nodeB = distances[k].node

            -- Verificar se já existe conexão
            local alreadyConnected = false
            for _, path in ipairs(self.roads.paths) do
                if (path.startId == nodeA.id and path.endId == nodeB.id) or
                    (path.startId == nodeB.id and path.endId == nodeA.id) then
                    alreadyConnected = true
                    break
                end
            end

            if not alreadyConnected then
                local path = self:_findPath(nodeA.x, nodeA.y, nodeB.x, nodeB.y)
                if #path > 1 then
                    path = self:_addIntermediatePoints(path)
                    path = self:_smoothRoad(path)

                    table.insert(self.roads.paths, {
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

    self.isGeneratingRoads = false
    Logger.info("lobby_map_portals._generateRoads.complete",
        "[LobbyMapPortals] " .. roadsGenerated .. " estradas geradas")

    -- Processar estradas para criar cruzamentos e remover paralelas
    self:_processRoads()
end

--- Atualiza a geração do mapa e lógica de câmera/zoom
---@param dt number Delta time
function LobbyMapPortals:update(dt)
    self.frameCounter = self.frameCounter + 1

    -- Atualizar geração do continente
    if self.isGenerating and self.generationCoroutine then
        local status = coroutine.status(self.generationCoroutine)
        if status == "dead" then
            Logger.warn("lobby_map_portals.update.continent",
                "[LobbyMapPortals] Corrotina de continente morreu inesperadamente")
            self.isGenerating = false
            self.continentReadyForProcessing = true -- Garantir que o processo continue
            return
        end

        local ok, err = coroutine.resume(self.generationCoroutine)
        if not ok then
            Logger.error("lobby_map_portals.update.continent_error",
                "[LobbyMapPortals] Erro na corrotina de continente: " .. tostring(err))
            self.isGenerating = false
        end
    end

    -- NOVO: Fluxo de geração controlado pelo update
    -- Uma vez que o continente está pronto, executa os próximos passos em ordem.
    if self.continentReadyForProcessing and not self.structuresGenerated then
        Logger.info("lobby_map_portals.update.processing_continent",
            "[LobbyMapPortals] Continente finalizado. Iniciando pós-processamento...")

        -- 1. Ancorar câmera com base no continente final
        self:_anchorCamera()

        -- 2. Gerar estruturas
        self:_generateStructures()
        self.structuresGenerated = true -- Marcar como concluído

        -- 3. Iniciar geração de estradas (se houver estruturas)
        if #self.structures > 1 then
            self.roadGenerationCoroutine = coroutine.create(function() self:_generateRoads() end)
            self.isGeneratingRoads = true
            Logger.info("lobby_map_portals.update.starting_roads", "[LobbyMapPortals] Iniciando geração de estradas")
        else
            -- Se não há estradas para gerar, o mapa está pronto para ser renderizado
            self:_renderStaticMapToCanvas()
        end
    end

    -- Atualizar geração de estradas
    if self.isGeneratingRoads and self.roadGenerationCoroutine then
        local status = coroutine.status(self.roadGenerationCoroutine)
        if status == "dead" then
            Logger.info("lobby_map_portals.update.roads",
                "[LobbyMapPortals] Geração de estradas concluída")
            self.isGeneratingRoads = false
            -- Estradas concluídas, renderizar para o canvas
            self:_renderStaticMapToCanvas()
            return
        end

        local ok, err = coroutine.resume(self.roadGenerationCoroutine)
        if not ok then
            Logger.error("lobby_map_portals.update.roads_error",
                "[LobbyMapPortals] Erro na geração de estradas: " .. tostring(err))
            self.isGeneratingRoads = false
            -- Mesmo com erro, tentar renderizar o que temos
            self:_renderStaticMapToCanvas()
        end
    end

    -- Atualizar lógica de zoom/pan (interpolação suave)
    local factor = math.min(1, dt * self.zoomSmoothFactor)

    self.currentZoom = self.currentZoom + (self.targetZoom - self.currentZoom) * factor

    -- Atualizar posição da câmera de forma mais direta
    if self.targetCameraOffset then
        self.cameraOffset.x = self.cameraOffset.x + (self.targetCameraOffset.x - self.cameraOffset.x) * factor
        self.cameraOffset.y = self.cameraOffset.y + (self.targetCameraOffset.y - self.cameraOffset.y) * factor

        -- Debug durante zoom
        if self.zoomTarget and math.abs(self.currentZoom - self.targetZoom) > 0.01 then
            local currentScreenX, currentScreenY = self:getScreenPositionFromWorld(self.zoomTarget.x, self.zoomTarget.y)
            local screenW = ResolutionUtils.getGameWidth()
            local screenH = ResolutionUtils.getGameHeight()
            local centerX, centerY = screenW / 2, screenH / 2

            if love.timer.getTime() % 0.5 < dt then -- Log a cada 0.5 segundos
                print("=== ZOOM UPDATE ===")
                print("Target portal: (" .. math.floor(self.zoomTarget.x) .. ", " .. math.floor(self.zoomTarget.y) .. ")")
                print("Current zoom: " ..
                    string.format("%.2f", self.currentZoom) .. " -> " .. string.format("%.2f", self.targetZoom))
                print("Camera offset: (" ..
                    math.floor(self.cameraOffset.x) .. ", " .. math.floor(self.cameraOffset.y) .. ")")
                print("Portal na tela: (" .. math.floor(currentScreenX) .. ", " .. math.floor(currentScreenY) .. ")")
                print("Centro da tela: (" .. math.floor(centerX) .. ", " .. math.floor(centerY) .. ")")
                print("Distância do centro: " ..
                    math.floor(math.sqrt((currentScreenX - centerX) ^ 2 + (currentScreenY - centerY) ^ 2)))
                print("===================")
            end
        end
    end
end

--- Renderiza o mapa procedural para um canvas estático para otimização
function LobbyMapPortals:_renderStaticMapToCanvas()
    if self.isMapRenderedToCanvas then return end

    Logger.info("lobby_map_portals.renderStaticMap", "[LobbyMapPortals] Renderizando mapa estático para o Canvas...")

    local mapW, mapH = self:getMapDimensions()

    -- Criar canvas se não existir
    if not self.staticMapCanvas then
        self.staticMapCanvas = love.graphics.newCanvas(mapW, mapH)
    end

    -- Cores do tema (convertidas para LÖVE 0-1)
    local mapColors = {
        background = { 11 / 255, 4 / 255, 11 / 255 },
        continent = { 17 / 255, 33 / 255, 63 / 255 },
        grid = { 108 / 255, 154 / 255, 221 / 255, 12 / 255 },
        structure = { 35 / 255, 55 / 255, 85 / 255 },
        road = { 33 / 255, 75 / 255, 160 / 255, 0.3 },
        roadOutline = { 15 / 255, 25 / 255, 40 / 255, 0.1 },
        structureConnection = { 45 / 255, 85 / 255, 140 / 255, 0.4 },
        structureConnectionOutline = { 20 / 255, 35 / 255, 50 / 255, 0.15 }
    }

    love.graphics.setCanvas(self.staticMapCanvas)
    love.graphics.clear()

    -- ATENÇÃO: A partir daqui, todas as coordenadas são relativas ao canvas (mapa virtual)
    -- Para centralizar o desenho no canvas, o offset de desenho deve ser o centro do canvas.
    local canvasDrawX = mapW / 2
    local canvasDrawY = mapH / 2

    -- 1. Desenhar fundo (não precisa, o clear já pode fazer isso, mas por segurança)
    love.graphics.setColor(mapColors.background)
    love.graphics.rectangle('fill', 0, 0, mapW, mapH)

    -- 2. Desenhar continente
    if #self.continentPoints > 0 then
        love.graphics.setColor(mapColors.continent)
        local isoPoints = {}
        for i = 1, #self.continentPoints, 2 do
            local isoX, isoY = self:_toIso(self.continentPoints[i], self.continentPoints[i + 1], 1.0, canvasDrawX,
                canvasDrawY)
            table.insert(isoPoints, isoX)
            table.insert(isoPoints, isoY)
        end
        if #isoPoints >= 6 then
            love.graphics.polygon('fill', isoPoints)
        end
    end

    -- 3. Desenhar estradas
    if #self.roads.paths > 0 then
        for _, path in ipairs(self.roads.paths) do
            if #path.points > 1 then
                local roadColor = path.isStructureConnection and mapColors.structureConnection or mapColors.road
                local outlineColor = path.isStructureConnection and mapColors.structureConnectionOutline or
                    mapColors.roadOutline

                love.graphics.setColor(outlineColor)
                love.graphics.setLineWidth(path.isStructureConnection and 1 or 1)
                for i = 1, #path.points - 1 do
                    local p1, p2 = path.points[i], path.points[i + 1]
                    if self:_pointInPolygon(p1.x, p1.y, self.continentPoints) and self:_pointInPolygon(p2.x, p2.y, self.continentPoints) then
                        local x1, y1 = self:_toIso(p1.x, p1.y, 1.0, canvasDrawX, canvasDrawY)
                        local x2, y2 = self:_toIso(p2.x, p2.y, 1.0, canvasDrawX, canvasDrawY)
                        love.graphics.line(x1, y1, x2, y2)
                    end
                end

                love.graphics.setColor(roadColor)
                love.graphics.setLineWidth(path.isStructureConnection and 1.5 or 2)
                for i = 1, #path.points - 1 do
                    local p1, p2 = path.points[i], path.points[i + 1]
                    if self:_pointInPolygon(p1.x, p1.y, self.continentPoints) and self:_pointInPolygon(p2.x, p2.y, self.continentPoints) then
                        local x1, y1 = self:_toIso(p1.x, p1.y, 1.0, canvasDrawX, canvasDrawY)
                        local x2, y2 = self:_toIso(p2.x, p2.y, 1.0, canvasDrawX, canvasDrawY)
                        love.graphics.line(x1, y1, x2, y2)
                    end
                end
            end
        end
    end

    -- 4. Desenhar estruturas
    if #self.structures > 0 then
        for _, structure in ipairs(self.structures) do
            local isoX, isoY = self:_toIso(structure.x, structure.y, 1.0, canvasDrawX, canvasDrawY)
            local img = self.structureImages[structure.imageId]
            if img then
                love.graphics.setColor(mapColors.structure)
                local w, h = img:getDimensions()
                local scale = CONFIG.STRUCTURE_SCALE
                love.graphics.draw(img, isoX, isoY, 0, scale, scale, w / 2, h / 2)
            end
        end
    end

    -- 5. Desenhar grade tática
    love.graphics.setColor(mapColors.grid)
    love.graphics.setLineWidth(1)
    local gridSize = CONFIG.GRID_SIZE
    local range = CONFIG.GRID_RANGE
    for i = -range, range do
        local p1_h_x, p1_h_y = self:_toIso(i * gridSize + mapW / 2, -range * gridSize + mapH / 2, 1.0, canvasDrawX,
            canvasDrawY)
        local p2_h_x, p2_h_y = self:_toIso(i * gridSize + mapW / 2, range * gridSize + mapH / 2, 1.0, canvasDrawX,
            canvasDrawY)
        love.graphics.line(p1_h_x, p1_h_y, p2_h_x, p2_h_y)

        local p1_v_x, p1_v_y = self:_toIso(-range * gridSize + mapW / 2, i * gridSize + mapH / 2, 1.0, canvasDrawX,
            canvasDrawY)
        local p2_v_x, p2_v_y = self:_toIso(range * gridSize + mapW / 2, i * gridSize + mapH / 2, 1.0, canvasDrawX,
            canvasDrawY)
        love.graphics.line(p1_v_x, p1_v_y, p2_v_x, p2_v_y)
    end

    -- Finalizar renderização no canvas
    love.graphics.setCanvas()
    self.isMapRenderedToCanvas = true
    Logger.info("lobby_map_portals.renderStaticMap",
        "[LobbyMapPortals] Mapa estático renderizado com sucesso para o Canvas.")
end

--- Renderiza o mapa procedural
---@param screenW number Largura da tela
---@param screenH number Altura da tela
function LobbyMapPortals:draw(screenW, screenH)
    -- Cores de fundo (usado antes do canvas estar pronto)
    local mapColors = {
        background = { 11 / 255, 4 / 255, 11 / 255 },
    }

    -- 1. Desenhar fundo
    love.graphics.setColor(mapColors.background)
    love.graphics.rectangle('fill', 0, 0, screenW, screenH)

    if self.isMapRenderedToCanvas and self.staticMapCanvas then
        -- OTIMIZADO: Desenha o canvas pré-renderizado
        love.graphics.setColor(1, 1, 1, 1)

        -- O centro do canvas (mapa) deve ser alinhado com o centro do mundo (0,0) na projeção isométrica.
        -- O cameraOffset já contém o deslocamento necessário da tela.
        -- A escala (zoom) é aplicada no desenho do canvas.
        local mapW, mapH = self:getMapDimensions()
        love.graphics.draw(self.staticMapCanvas, self.cameraOffset.x, self.cameraOffset.y, 0, self.currentZoom,
            self.currentZoom, mapW / 2, mapH / 2)
    elseif self.isGenerating or self.isGeneratingRoads then
        -- Opcional: Mostrar texto de carregamento enquanto o canvas não está pronto
        love.graphics.setColor(colors.white)
        love.graphics.printf("Gerando mapa...", 0, screenH / 2, screenW, "center")
    end


    -- 2. Debug de FPS (pode ser mantido aqui)
    if DEV then
        love.graphics.setColor(1, 1, 1)
        local statusText = "FPS: " .. love.timer.getFPS()
        if not self.isMapRenderedToCanvas then
            statusText = "Gerando... | " .. statusText
        else
            statusText = "Canvas | " .. statusText
        end
        love.graphics.print(statusText, 10, 90)
    end

    love.graphics.setColor(colors.white)
    love.graphics.setLineWidth(1)
end

--- Retorna as dimensões virtuais do mapa
---@return number width Largura do mapa
---@return number height Altura do mapa
function LobbyMapPortals:getMapDimensions()
    return CONFIG.VIRTUAL_MAP_WIDTH, CONFIG.VIRTUAL_MAP_HEIGHT
end

--- Verifica se um ponto está dentro do continente (para posicionamento de portais)
---@param x number Coordenada X
---@param y number Coordenada Y
---@return boolean isInside Se o ponto está dentro do continente
function LobbyMapPortals:isPointInContinent(x, y)
    return self:_pointInPolygon(x, y, self.continentPoints)
end

--- Obtém o offset da câmera para sincronização
---@return Vector2D cameraOffset Offset atual da câmera
function LobbyMapPortals:getCameraOffset()
    return self.cameraOffset
end

--- Verifica se a geração está completa
---@return boolean isComplete Se a geração está completa
function LobbyMapPortals:isGenerationComplete()
    return not self.isGenerating and not self.isGeneratingRoads
end

--- Debug das posições das estruturas na tela
function LobbyMapPortals:_debugStructurePositions()
    if self._debugPrinted or not self.structures or #self.structures == 0 then
        return
    end

    self._debugPrinted = true

    print("DEBUG: Posições das estruturas (renderização real):")

    -- Usar as configurações de desenho atuais ou valores default
    local mapScale = self.mapScale or 1.0
    local mapDrawX = self.mapDrawX or 0
    local mapDrawY = self.mapDrawY or 0

    print("DEBUG: Parâmetros de desenho - Scale: " .. mapScale .. ", DrawX: " .. mapDrawX .. ", DrawY: " .. mapDrawY)

    local visibleCount = 0
    local maxDebugCount = math.min(10, #self.structures)

    for i = 1, maxDebugCount do
        local structure = self.structures[i]

        -- Usar a MESMA conversão que é usada na renderização real
        local isoX, isoY = self:_toIso(structure.x, structure.y, mapScale, mapDrawX, mapDrawY)

        -- Verificar visibilidade usando as dimensões reais da tela com margem
        local margin = 50
        local isVisible = (isoX >= -margin and isoX <= love.graphics.getWidth() + margin and
            isoY >= -margin and isoY <= love.graphics.getHeight() + margin)

        if isVisible then visibleCount = visibleCount + 1 end

        print("  Estrutura " .. i .. ": mundo(" .. math.floor(structure.x) .. "," .. math.floor(structure.y) ..
            ") -> tela(" .. math.floor(isoX) .. "," .. math.floor(isoY) .. ") " ..
            (isVisible and "VISÍVEL" or "FORA DA TELA"))
    end

    -- Contar total de estruturas visíveis
    local totalVisible = 0
    local margin = 50
    for i = 1, #self.structures do
        local structure = self.structures[i]
        local isoX, isoY = self:_toIso(structure.x, structure.y, mapScale, mapDrawX, mapDrawY)

        if isoX >= -margin and isoX <= love.graphics.getWidth() + margin and
            isoY >= -margin and isoY <= love.graphics.getHeight() + margin then
            totalVisible = totalVisible + 1
        end
    end

    print("DEBUG: " .. totalVisible .. "/" .. #self.structures .. " estruturas estão visíveis na renderização real")
end

-- === FUNÇÕES AUXILIARES PRIVADAS ===

--- Converte coordenadas do mundo para projeção isométrica
---@param x number Coordenada X do mundo
---@param y number Coordenada Y do mundo
---@param mapScale number Escala atual do mapa
---@param mapDrawX number Posição X de desenho do mapa
---@param mapDrawY number Posição Y de desenho do mapa
---@return number isoX Coordenada X isométrica
---@return number isoY Coordenada Y isométrica
function LobbyMapPortals:_toIso(x, y, mapScale, mapDrawX, mapDrawY)
    local cartesianX = (x - CONFIG.VIRTUAL_MAP_WIDTH / 2)
    local cartesianY = (y - CONFIG.VIRTUAL_MAP_HEIGHT / 2)

    local isoX = (cartesianX - cartesianY) * 0.7 * CONFIG.ISO_SCALE
    local isoY = (cartesianX + cartesianY) * 0.35 * CONFIG.ISO_SCALE

    return (isoX * mapScale) + mapDrawX, (isoY * mapScale) + mapDrawY
end

--- Converte coordenadas isométricas da tela para coordenadas do mundo
---@param isoX number Coordenada X isométrica na tela
---@param isoY number Coordenada Y isométrica na tela
---@param mapScale number Escala atual do mapa
---@param mapDrawX number Posição X de desenho do mapa
---@param mapDrawY number Posição Y de desenho do mapa
---@return number worldX Coordenada X do mundo
---@return number worldY Coordenada Y do mundo
function LobbyMapPortals:_fromIso(isoX, isoY, mapScale, mapDrawX, mapDrawY)
    -- Remover offset e escala da tela
    local scaledIsoX = (isoX - mapDrawX) / mapScale
    local scaledIsoY = (isoY - mapDrawY) / mapScale

    -- Inverter a projeção para encontrar coordenadas cartesianas relativas ao centro do mapa
    local A = 0.7 * CONFIG.ISO_SCALE
    local B = 0.35 * CONFIG.ISO_SCALE

    local cartX = (scaledIsoX / A + scaledIsoY / B) / 2
    local cartY = (scaledIsoY / B - scaledIsoX / A) / 2

    -- Reverter para coordenadas do mundo
    local worldX = cartX + CONFIG.VIRTUAL_MAP_WIDTH / 2
    local worldY = cartY + CONFIG.VIRTUAL_MAP_HEIGHT / 2

    return worldX, worldY
end

--- Verifica se um ponto está dentro de um polígono
---@param x number Coordenada X
---@param y number Coordenada Y
---@param polygon number[] Lista de pontos do polígono (x,y alternados)
---@return boolean inside Se o ponto está dentro
function LobbyMapPortals:_pointInPolygon(x, y, polygon)
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

--- Calcula a distância entre dois pontos
---@param x1 number Coordenada X do primeiro ponto
---@param y1 number Coordenada Y do primeiro ponto
---@param x2 number Coordenada X do segundo ponto
---@param y2 number Coordenada Y do segundo ponto
---@return number distance Distância entre os pontos
function LobbyMapPortals:_distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

--- Valida se toda a área de uma estrutura está dentro do continente
---@param centerX number Coordenada X central da estrutura
---@param centerY number Coordenada Y central da estrutura
---@param width number Largura da estrutura (já escalada)
---@param height number Altura da estrutura (já escalada)
---@return boolean isValid Se toda a área da estrutura está dentro do continente
function LobbyMapPortals:_validateStructureArea(centerX, centerY, width, height)
    local halfWidth = width / 2
    local halfHeight = height / 2

    local topLeft = { x = centerX - halfWidth, y = centerY - halfHeight }
    local topRight = { x = centerX + halfWidth, y = centerY - halfHeight }
    local bottomLeft = { x = centerX - halfWidth, y = centerY + halfHeight }
    local bottomRight = { x = centerX + halfWidth, y = centerY + halfHeight }

    -- 1. Verificação rápida dos 4 cantos. Se algum estiver fora, já falha.
    local corners = { topLeft, topRight, bottomLeft, bottomRight }
    for _, corner in ipairs(corners) do
        if not self:_pointInPolygon(corner.x, corner.y, self.continentPoints) then
            return false
        end
    end

    -- 2. Verificação rigorosa do perímetro para garantir que nenhuma parte "vaze".
    local step = 10 -- Verificar a cada 10 pixels ao longo da borda
    local perimeterPoints = {}

    -- Borda superior (da esquerda para a direita)
    for x = topLeft.x, topRight.x, step do
        table.insert(perimeterPoints, { x = x, y = topLeft.y })
    end
    -- Borda inferior (da esquerda para a direita)
    for x = bottomLeft.x, bottomRight.x, step do
        table.insert(perimeterPoints, { x = x, y = bottomLeft.y })
    end
    -- Borda esquerda (de cima para baixo)
    for y = topLeft.y, bottomLeft.y, step do
        table.insert(perimeterPoints, { x = topLeft.x, y = y })
    end
    -- Borda direita (de cima para baixo)
    for y = topRight.y, bottomRight.y, step do
        table.insert(perimeterPoints, { x = topRight.x, y = y })
    end

    -- Verificar se TODOS os pontos do perímetro estão dentro do continente
    for _, point in ipairs(perimeterPoints) do
        if not self:_pointInPolygon(point.x, point.y, self.continentPoints) then
            return false -- Se qualquer ponto do perímetro estiver fora, a estrutura não é válida
        end
    end

    -- Se todos os cantos e o perímetro passaram, a estrutura é válida
    return true
end

--- Encontra caminho entre dois pontos com perturbação de relevo
---@param startX number Coordenada X inicial
---@param startY number Coordenada Y inicial
---@param endX number Coordenada X final
---@param endY number Coordenada Y final
---@return RoadPoint[] path Lista de pontos do caminho
function LobbyMapPortals:_findPath(startX, startY, endX, endY)
    local path = {}
    local steps = math.floor(self:_distance(startX, startY, endX, endY) / 15)
    steps = math.max(steps, 3)

    for i = 0, steps do
        local t = i / steps
        local x = startX + (endX - startX) * t
        local y = startY + (endY - startY) * t

        -- Adicionar perturbação para simular contorno de relevo
        if i > 0 and i < steps then
            local attempts = 0
            local originalX, originalY = x, y

            repeat
                attempts = attempts + 1
                local perturbStrength = 20
                x = originalX + (love.math.random() - 0.5) * perturbStrength
                y = originalY + (love.math.random() - 0.5) * perturbStrength
            until self:_pointInPolygon(x, y, self.continentPoints) or attempts > 10

            -- Se não conseguiu encontrar um ponto válido no continente, usar o original
            if attempts > 10 then
                x, y = originalX, originalY
            end
        end

        -- Só adicionar o ponto se estiver dentro do continente
        if self:_pointInPolygon(x, y, self.continentPoints) then
            table.insert(path, { x = x, y = y })
        end
    end

    -- Garantir que sempre temos pelo menos pontos inicial e final se estiverem no continente
    if #path == 0 then
        if self:_pointInPolygon(startX, startY, self.continentPoints) then
            table.insert(path, { x = startX, y = startY })
        end
        if self:_pointInPolygon(endX, endY, self.continentPoints) then
            table.insert(path, { x = endX, y = endY })
        end
    end

    return path
end

--- Suaviza uma estrada usando interpolação
---@param path RoadPoint[] Caminho original
---@return RoadPoint[] smoothedPath Caminho suavizado
function LobbyMapPortals:_smoothRoad(path)
    if #path < 3 then return path end

    local smoothedPath = {}
    local smoothFactor = 0.3

    -- Manter primeiro ponto
    table.insert(smoothedPath, { x = path[1].x, y = path[1].y })

    -- Suavizar pontos intermediários
    for i = 2, #path - 1 do
        local prevPoint = path[i - 1]
        local currentPoint = path[i]
        local nextPoint = path[i + 1]

        -- Calcular ponto suavizado usando média ponderada
        local smoothedX = currentPoint.x + smoothFactor * (prevPoint.x + nextPoint.x - 2 * currentPoint.x) / 2
        local smoothedY = currentPoint.y + smoothFactor * (prevPoint.y + nextPoint.y - 2 * currentPoint.y) / 2

        -- Verificar se o ponto suavizado ainda está no continente
        if self:_pointInPolygon(smoothedX, smoothedY, self.continentPoints) then
            table.insert(smoothedPath, { x = smoothedX, y = smoothedY })
        else
            -- Se não estiver, usar o ponto original
            table.insert(smoothedPath, { x = currentPoint.x, y = currentPoint.y })
        end
    end

    -- Manter último ponto
    table.insert(smoothedPath, { x = path[#path].x, y = path[#path].y })

    return smoothedPath
end

--- Adiciona pontos intermediários para curvas mais suaves
---@param path RoadPoint[] Caminho original
---@return RoadPoint[] detailedPath Caminho com pontos intermediários
function LobbyMapPortals:_addIntermediatePoints(path)
    if #path < 2 then return path end

    local detailedPath = {}

    for i = 1, #path - 1 do
        local p1 = path[i]
        local p2 = path[i + 1]

        -- Adicionar o ponto atual
        table.insert(detailedPath, { x = p1.x, y = p1.y })

        -- Calcular a distância entre pontos
        local dist = self:_distance(p1.x, p1.y, p2.x, p2.y)

        -- Se a distância for grande, adicionar pontos intermediários (mesmos valores do map.lua)
        if dist > 30 then
            local numIntermediatePoints = math.floor(dist / 20)
            for j = 1, numIntermediatePoints do
                local t = j / (numIntermediatePoints + 1)
                local interpX = p1.x + (p2.x - p1.x) * t
                local interpY = p1.y + (p2.y - p1.y) * t

                -- Adicionar pequena perturbação para naturalidade (mesmo valor do map.lua)
                interpX = interpX + (love.math.random() - 0.5) * 8
                interpY = interpY + (love.math.random() - 0.5) * 8

                -- Só adicionar se estiver no continente
                if self:_pointInPolygon(interpX, interpY, self.continentPoints) then
                    table.insert(detailedPath, { x = interpX, y = interpY })
                end
            end
        end
    end

    -- Adicionar o último ponto
    table.insert(detailedPath, { x = path[#path].x, y = path[#path].y })

    return detailedPath
end

--- Detecta se duas linhas se interceptam
---@param line1Start RoadPoint Ponto inicial da primeira linha
---@param line1End RoadPoint Ponto final da primeira linha
---@param line2Start RoadPoint Ponto inicial da segunda linha
---@param line2End RoadPoint Ponto final da segunda linha
---@return boolean intercepta Se as linhas se interceptam
---@return RoadPoint|nil intersectionPoint Ponto de intersecção (se houver)
function LobbyMapPortals:_detectLineIntersection(line1Start, line1End, line2Start, line2End)
    local x1, y1 = line1Start.x, line1Start.y
    local x2, y2 = line1End.x, line1End.y
    local x3, y3 = line2Start.x, line2Start.y
    local x4, y4 = line2End.x, line2End.y

    local denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

    -- Linhas paralelas
    if math.abs(denom) < 1e-10 then
        return false, nil
    end

    local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
    local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom

    -- Verificar se a intersecção está dentro dos segmentos
    if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
        local intersectionX = x1 + t * (x2 - x1)
        local intersectionY = y1 + t * (y2 - y1)

        return true, { x = intersectionX, y = intersectionY }
    end

    return false, nil
end

--- Verifica se duas estradas são paralelas
---@param path1 RoadPoint[] Primeira estrada
---@param path2 RoadPoint[] Segunda estrada
---@return boolean isParallel Se as estradas são paralelas
---@return number distance Distância média entre as estradas
function LobbyMapPortals:_detectParallelRoads(path1, path2)
    if #path1 < 2 or #path2 < 2 then
        return false, math.huge
    end

    -- Verificar se as estradas têm comprimento significativo
    local length1 = self:_calculatePathLength(path1)
    local length2 = self:_calculatePathLength(path2)
    local minLength = 50 -- Comprimento mínimo para considerar

    if length1 < minLength or length2 < minLength then
        return false, math.huge
    end

    local parallelThreshold = 25 -- Distância máxima para considerar paralelas (aumentado)
    local angleThreshold = 0.3   -- Tolerância angular (radianos) - mais permissivo

    local totalDistance = 0
    local validComparisons = 0
    local parallelSegments = 0

    -- Comparar segmentos de cada estrada
    for i = 1, #path1 - 1 do
        local seg1Start, seg1End = path1[i], path1[i + 1]
        local angle1 = math.atan2(seg1End.y - seg1Start.y, seg1End.x - seg1Start.x)

        for j = 1, #path2 - 1 do
            local seg2Start, seg2End = path2[j], path2[j + 1]
            local angle2 = math.atan2(seg2End.y - seg2Start.y, seg2End.x - seg2Start.x)

            -- Verificar se os ângulos são similares (paralelos)
            local angleDiff = math.abs(angle1 - angle2)
            if angleDiff > math.pi then angleDiff = 2 * math.pi - angleDiff end

            if angleDiff < angleThreshold or math.abs(angleDiff - math.pi) < angleThreshold then
                -- Calcular distância entre segmentos
                local midPoint1 = { x = (seg1Start.x + seg1End.x) / 2, y = (seg1Start.y + seg1End.y) / 2 }
                local midPoint2 = { x = (seg2Start.x + seg2End.x) / 2, y = (seg2Start.y + seg2End.y) / 2 }
                local dist = self:_distance(midPoint1.x, midPoint1.y, midPoint2.x, midPoint2.y)

                if dist < parallelThreshold then
                    totalDistance = totalDistance + dist
                    validComparisons = validComparisons + 1
                    parallelSegments = parallelSegments + 1
                end
            end
        end
    end

    -- Exigir que pelo menos 70% dos segmentos sejam paralelos
    local minParallelRatio = 0.7
    local requiredParallelSegments = math.min(#path1 - 1, #path2 - 1) * minParallelRatio

    if validComparisons > 0 and parallelSegments >= requiredParallelSegments then
        return true, totalDistance / validComparisons
    end

    return false, math.huge
end

--- Encontra intersecções entre duas estradas
---@param path1 RoadPoint[] Primeira estrada
---@param path2 RoadPoint[] Segunda estrada
---@return table[] intersections Lista de intersecções encontradas
function LobbyMapPortals:_findRoadIntersections(path1, path2)
    local intersections = {}

    for i = 1, #path1 - 1 do
        for j = 1, #path2 - 1 do
            local intersects, point = self:_detectLineIntersection(
                path1[i], path1[i + 1],
                path2[j], path2[j + 1]
            )

            if intersects and point then
                table.insert(intersections, {
                    point = point,
                    path1SegmentIndex = i,
                    path2SegmentIndex = j
                })
            end
        end
    end

    return intersections
end

--- Processa as estradas para criar cruzamentos e remover paralelas
function LobbyMapPortals:_processRoads()
    if #self.roads.paths < 2 then
        return
    end

    Logger.info("lobby_map_portals._processRoads.start",
        "[LobbyMapPortals] Iniciando processamento de " .. #self.roads.paths .. " estradas...")

    -- 1. Detectar e remover estradas paralelas
    local toRemove = {}
    local removedCount = 0
    local parallelPairsFound = 0

    for i = 1, #self.roads.paths - 1 do
        if not toRemove[i] then -- Só processar se não foi marcado para remoção
            local path1 = self.roads.paths[i]

            for j = i + 1, #self.roads.paths do
                if not toRemove[j] then -- Só processar se não foi marcado para remoção
                    local path2 = self.roads.paths[j]
                    local isParallel, distance = self:_detectParallelRoads(path1.points, path2.points)

                    if isParallel then
                        parallelPairsFound = parallelPairsFound + 1
                        -- Manter a estrada mais longa
                        local length1 = self:_calculatePathLength(path1.points)
                        local length2 = self:_calculatePathLength(path2.points)

                        print("DEBUG: Estradas paralelas encontradas - " ..
                            "Estrada " .. i .. " (comprimento: " .. math.floor(length1) .. ") vs " ..
                            "Estrada " ..
                            j .. " (comprimento: " .. math.floor(length2) .. "), distância: " .. math.floor(distance))

                        if length1 < length2 then
                            toRemove[i] = true
                            removedCount = removedCount + 1
                            print("DEBUG: Removendo estrada " .. i .. " (mais curta)")
                            break -- Parar de processar esta estrada
                        else
                            toRemove[j] = true
                            removedCount = removedCount + 1
                            print("DEBUG: Removendo estrada " .. j .. " (mais curta)")
                        end
                    end
                end
            end
        end
    end

    -- Remover estradas marcadas (em ordem reversa para manter índices válidos)
    for i = #self.roads.paths, 1, -1 do
        if toRemove[i] then
            table.remove(self.roads.paths, i)
        end
    end

    Logger.info("lobby_map_portals._processRoads.parallel_removed",
        "[LobbyMapPortals] " ..
        parallelPairsFound .. " pares paralelos detectados, " .. removedCount .. " estradas removidas")

    -- 2. Detectar intersecções e criar cruzamentos
    local intersectionCount = 0
    local processedPairs = {}
    local totalIntersectionsFound = 0

    for i = 1, #self.roads.paths - 1 do
        for j = i + 1, #self.roads.paths do
            local pairKey = i .. "-" .. j
            if not processedPairs[pairKey] then
                processedPairs[pairKey] = true

                local path1 = self.roads.paths[i]
                local path2 = self.roads.paths[j]

                local intersections = self:_findRoadIntersections(path1.points, path2.points)
                totalIntersectionsFound = totalIntersectionsFound + #intersections

                -- Processar apenas a primeira intersecção encontrada para evitar complicações
                if #intersections > 0 then
                    print("DEBUG: Intersecção encontrada entre estradas " .. i .. " e " .. j ..
                        " - " .. #intersections .. " pontos de intersecção")
                    self:_createCrossroad(i, j, intersections[1])
                    intersectionCount = intersectionCount + 1
                end
            end
        end
    end

    Logger.info("lobby_map_portals._processRoads.complete",
        "[LobbyMapPortals] Processamento concluído: " .. totalIntersectionsFound .. " intersecções detectadas, " ..
        intersectionCount .. " cruzamentos criados")

    -- 3. Conectar estruturas próximas às estradas
    self:_connectStructuresToRoads()
end

--- Calcula o comprimento total de uma estrada
---@param path RoadPoint[] Estrada
---@return number length Comprimento total
function LobbyMapPortals:_calculatePathLength(path)
    local length = 0
    for i = 1, #path - 1 do
        length = length + self:_distance(path[i].x, path[i].y, path[i + 1].x, path[i + 1].y)
    end
    return length
end

--- Cria um cruzamento entre duas estradas
---@param pathIndex1 number Índice da primeira estrada
---@param pathIndex2 number Índice da segunda estrada
---@param intersection table Dados da intersecção
function LobbyMapPortals:_createCrossroad(pathIndex1, pathIndex2, intersection)
    local path1 = self.roads.paths[pathIndex1]
    local path2 = self.roads.paths[pathIndex2]
    local intersectionPoint = intersection.point

    -- Armazenar pontos originais antes de modificar
    local originalPath1Points = {}
    local originalPath2Points = {}

    for i = 1, #path1.points do
        table.insert(originalPath1Points, { x = path1.points[i].x, y = path1.points[i].y })
    end

    for i = 1, #path2.points do
        table.insert(originalPath2Points, { x = path2.points[i].x, y = path2.points[i].y })
    end

    -- Interromper path1 no ponto de intersecção
    local newPath1Points = {}
    for i = 1, intersection.path1SegmentIndex do
        table.insert(newPath1Points, originalPath1Points[i])
    end
    table.insert(newPath1Points, intersectionPoint)

    -- Interromper path2 no ponto de intersecção
    local newPath2Points = {}
    for i = 1, intersection.path2SegmentIndex do
        table.insert(newPath2Points, originalPath2Points[i])
    end
    table.insert(newPath2Points, intersectionPoint)

    -- Atualizar as estradas
    path1.points = newPath1Points
    path2.points = newPath2Points

    -- Criar continuações das estradas após o cruzamento
    if intersection.path1SegmentIndex < #originalPath1Points - 1 then
        local continuationPath1 = {
            startId = -1, -- ID especial para continuação
            endId = path1.endId,
            points = { intersectionPoint }
        }

        for i = intersection.path1SegmentIndex + 2, #originalPath1Points do
            table.insert(continuationPath1.points, originalPath1Points[i])
        end

        table.insert(self.roads.paths, continuationPath1)
    end

    if intersection.path2SegmentIndex < #originalPath2Points - 1 then
        local continuationPath2 = {
            startId = -1, -- ID especial para continuação
            endId = path2.endId,
            points = { intersectionPoint }
        }

        for i = intersection.path2SegmentIndex + 2, #originalPath2Points do
            table.insert(continuationPath2.points, originalPath2Points[i])
        end

        table.insert(self.roads.paths, continuationPath2)
    end
end

--- Encontra o ponto mais próximo numa estrada para uma estrutura
---@param structure table Estrutura a conectar
---@param path RoadPoint[] Estrada
---@return RoadPoint|nil closestPoint Ponto mais próximo na estrada
---@return number distance Distância mínima encontrada
---@return number segmentIndex Índice do segmento mais próximo
function LobbyMapPortals:_findClosestPointOnRoad(structure, path)
    if #path < 2 then
        return nil, math.huge, 0
    end

    local minDistance = math.huge
    local closestPoint = nil
    local closestSegmentIndex = 0

    -- Verificar cada segmento da estrada
    for i = 1, #path - 1 do
        local segStart = path[i]
        local segEnd = path[i + 1]

        -- Calcular o ponto mais próximo no segmento
        local segmentPoint = self:_closestPointOnSegment(structure, segStart, segEnd)
        local distance = self:_distance(structure.x, structure.y, segmentPoint.x, segmentPoint.y)

        if distance < minDistance then
            minDistance = distance
            closestPoint = segmentPoint
            closestSegmentIndex = i
        end
    end

    return closestPoint, minDistance, closestSegmentIndex
end

--- Calcula o ponto mais próximo num segmento de linha
---@param point table Ponto de referência
---@param segStart RoadPoint Início do segmento
---@param segEnd RoadPoint Fim do segmento
---@return RoadPoint closestPoint Ponto mais próximo no segmento
function LobbyMapPortals:_closestPointOnSegment(point, segStart, segEnd)
    local dx = segEnd.x - segStart.x
    local dy = segEnd.y - segStart.y

    if dx == 0 and dy == 0 then
        -- Segmento é um ponto
        return { x = segStart.x, y = segStart.y }
    end

    -- Calcular a projeção do ponto no segmento
    local t = ((point.x - segStart.x) * dx + (point.y - segStart.y) * dy) / (dx * dx + dy * dy)

    -- Limitar t entre 0 e 1 para manter dentro do segmento
    t = math.max(0, math.min(1, t))

    return {
        x = segStart.x + t * dx,
        y = segStart.y + t * dy
    }
end

--- Conecta estruturas próximas às estradas principais
function LobbyMapPortals:_connectStructuresToRoads()
    if #self.structures == 0 or #self.roads.paths == 0 then
        return
    end

    Logger.info("lobby_map_portals._connectStructuresToRoads.start",
        "[LobbyMapPortals] Iniciando conexão de estruturas às estradas...")

    local maxConnectionDistance = 80         -- Distância máxima para conectar estruturas
    local minDistanceBetweenConnections = 40 -- Distância mínima entre conexões
    local connectionsCreated = 0
    local structuresConnected = 0
    local existingConnections = {}
    local connectionsToIntegrate = {} -- Lista de conexões para integrar depois

    for _, structure in ipairs(self.structures) do
        local minDistance = math.huge
        local bestConnection = nil

        -- Verificar se há uma conexão próxima (evitar sobrecarga)
        local tooCloseToExisting = false
        for _, existingConn in ipairs(existingConnections) do
            local distToExisting = self:_distance(structure.x, structure.y, existingConn.x, existingConn.y)
            if distToExisting < minDistanceBetweenConnections then
                tooCloseToExisting = true
                break
            end
        end

        if not tooCloseToExisting then
            -- Encontrar a estrada mais próxima (apenas estradas principais, não conexões)
            for roadIndex, road in ipairs(self.roads.paths) do
                if not road.isStructureConnection then -- Só conectar às estradas principais
                    local closestPoint, distance, segmentIndex = self:_findClosestPointOnRoad(structure, road.points)

                    if distance < minDistance and distance <= maxConnectionDistance then
                        minDistance = distance
                        bestConnection = {
                            roadIndex = roadIndex,
                            connectionPoint = closestPoint,
                            distance = distance,
                            segmentIndex = segmentIndex
                        }
                    end
                end
            end

            -- Criar conexão se uma estrada próxima foi encontrada
            if bestConnection then
                local connectionPath = self:_createConnectionPath(structure, bestConnection.connectionPoint)

                if connectionPath and #connectionPath > 1 then
                    -- Adicionar como nova estrada
                    table.insert(self.roads.paths, {
                        startId = structure.id,
                        endId = -2, -- ID especial para conexão de estrutura
                        points = connectionPath,
                        isStructureConnection = true
                    })

                    -- Armazenar integração para depois
                    table.insert(connectionsToIntegrate, {
                        roadIndex = bestConnection.roadIndex,
                        connectionPoint = bestConnection.connectionPoint,
                        segmentIndex = bestConnection.segmentIndex
                    })

                    -- Registrar esta conexão
                    table.insert(existingConnections, { x = structure.x, y = structure.y })

                    connectionsCreated = connectionsCreated + 1
                    structuresConnected = structuresConnected + 1

                    print("DEBUG: Estrutura " .. structure.id .. " (" .. structure.type .. ") conectada à estrada " ..
                        bestConnection.roadIndex .. " (distância: " .. math.floor(bestConnection.distance) .. ")")
                end
            end
        else
            print("DEBUG: Estrutura " .. structure.id .. " muito próxima de outra conexão, ignorada")
        end
    end

    -- Integrar todas as conexões nas estradas principais (em ordem reversa para manter índices válidos)
    table.sort(connectionsToIntegrate, function(a, b) return a.roadIndex > b.roadIndex end)
    for _, connectionData in ipairs(connectionsToIntegrate) do
        if connectionData.roadIndex <= #self.roads.paths then
            self:_integrateConnectionPoint(connectionData.roadIndex, connectionData.connectionPoint,
                connectionData.segmentIndex)
        end
    end

    Logger.info("lobby_map_portals._connectStructuresToRoads.complete",
        "[LobbyMapPortals] " .. connectionsCreated .. " conexões criadas para " ..
        structuresConnected .. " estruturas (" .. (#self.structures - structuresConnected) .. " ignoradas)")
end

--- Cria um caminho de conexão entre estrutura e estrada
---@param structure table Estrutura origem
---@param connectionPoint RoadPoint Ponto de conexão na estrada
---@return RoadPoint[]|nil path Caminho de conexão
function LobbyMapPortals:_createConnectionPath(structure, connectionPoint)
    -- Verificar se ambos os pontos estão no continente
    local structureInContinent = self:_pointInPolygon(structure.x, structure.y, self.continentPoints)
    local connectionInContinent = self:_pointInPolygon(connectionPoint.x, connectionPoint.y, self.continentPoints)

    if not (structureInContinent and connectionInContinent) then
        return nil -- Não criar conexão se não estiver no continente
    end

    local distance = self:_distance(structure.x, structure.y, connectionPoint.x, connectionPoint.y)

    -- Para conexões curtas, usar caminho direto
    if distance < 30 then
        return {
            { x = structure.x,       y = structure.y },
            { x = connectionPoint.x, y = connectionPoint.y }
        }
    end

    -- Para conexões médias, adicionar um ponto intermediário
    if distance < 60 then
        local midX = (structure.x + connectionPoint.x) / 2
        local midY = (structure.y + connectionPoint.y) / 2

        -- Adicionar perturbação sutil
        midX = midX + (love.math.random() - 0.5) * 15
        midY = midY + (love.math.random() - 0.5) * 15

        if self:_pointInPolygon(midX, midY, self.continentPoints) then
            return {
                { x = structure.x,       y = structure.y },
                { x = midX,              y = midY },
                { x = connectionPoint.x, y = connectionPoint.y }
            }
        end
    end

    -- Para conexões longas, criar caminho com mais pontos
    local numIntermediatePoints = math.floor(distance / 25)
    numIntermediatePoints = math.min(numIntermediatePoints, 3) -- Máximo 3 pontos intermediários

    if numIntermediatePoints > 0 then
        local path = { { x = structure.x, y = structure.y } }

        for i = 1, numIntermediatePoints do
            local t = i / (numIntermediatePoints + 1)
            local interpX = structure.x + (connectionPoint.x - structure.x) * t
            local interpY = structure.y + (connectionPoint.y - structure.y) * t

            -- Adicionar curvatura natural
            interpX = interpX + (love.math.random() - 0.5) * 20
            interpY = interpY + (love.math.random() - 0.5) * 20

            if self:_pointInPolygon(interpX, interpY, self.continentPoints) then
                table.insert(path, { x = interpX, y = interpY })
            end
        end

        table.insert(path, { x = connectionPoint.x, y = connectionPoint.y })

        -- Retornar apenas se temos pelo menos 2 pontos válidos
        if #path >= 2 then
            return path
        end
    end

    -- Fallback: caminho direto
    return {
        { x = structure.x,       y = structure.y },
        { x = connectionPoint.x, y = connectionPoint.y }
    }
end

--- Integra o ponto de conexão na estrada principal
---@param roadIndex number Índice da estrada principal
---@param connectionPoint RoadPoint Ponto de conexão
---@param segmentIndex number Índice do segmento da estrada
function LobbyMapPortals:_integrateConnectionPoint(roadIndex, connectionPoint, segmentIndex)
    local path = self.roads.paths[roadIndex]
    if not path or segmentIndex >= #path.points then
        return -- Índice inválido
    end

    -- Verificar se o ponto de conexão está muito próximo dos pontos existentes
    local minDistanceToExisting = 15 -- Distância mínima para considerar adicionar o ponto
    local segStart = path.points[segmentIndex]
    local segEnd = path.points[segmentIndex + 1]

    if not segEnd then
        return -- Segmento inválido
    end

    local distToStart = self:_distance(connectionPoint.x, connectionPoint.y, segStart.x, segStart.y)
    local distToEnd = self:_distance(connectionPoint.x, connectionPoint.y, segEnd.x, segEnd.y)

    -- Se o ponto de conexão está muito próximo de um ponto existente, não modificar a estrada
    if distToStart < minDistanceToExisting or distToEnd < minDistanceToExisting then
        print("DEBUG: Ponto de conexão muito próximo de ponto existente, não integrando")
        return
    end

    local originalPathPoints = {}
    for i = 1, #path.points do
        table.insert(originalPathPoints, { x = path.points[i].x, y = path.points[i].y })
    end

    -- Interromper path no ponto de conexão
    local newPathPoints = {}
    for i = 1, segmentIndex do
        table.insert(newPathPoints, originalPathPoints[i])
    end
    table.insert(newPathPoints, connectionPoint)

    -- Atualizar a estrada
    path.points = newPathPoints

    -- Criar continuação da estrada após o cruzamento
    if segmentIndex + 1 < #originalPathPoints then
        local continuationPath = {
            startId = -1, -- ID especial para continuação
            endId = path.endId,
            points = { connectionPoint }
        }

        for i = segmentIndex + 1, #originalPathPoints do
            table.insert(continuationPath.points, originalPathPoints[i])
        end

        table.insert(self.roads.paths, continuationPath)

        print("DEBUG: Estrada " .. roadIndex .. " dividida no ponto de conexão, continuação criada")
    end
end

--- Reposiciona a câmera para testes (função pública)
---@param position number|nil Posição específica (1-8) ou nil para aleatória
function LobbyMapPortals:repositionCamera(position)
    if position then
        -- Validar posição
        if position < 1 or position > 8 then
            print("ERRO: Posição deve estar entre 1 e 8")
            return
        end

        local positionNames = {
            "canto inferior-esquerdo", "canto inferior-direito",
            "canto superior-esquerdo", "canto superior-direito",
            "centro-inferior", "centro-superior",
            "centro-esquerdo", "centro-direito"
        }

        print("TESTE: Reposicionando câmera para: " .. positionNames[position])

        -- Temporariamente forçar a posição
        local originalForcePosition = CONFIG.FORCE_CAMERA_POSITION
        CONFIG.FORCE_CAMERA_POSITION = position

        -- Reanclar câmera
        self:_anchorCamera()

        -- Restaurar configuração original
        CONFIG.FORCE_CAMERA_POSITION = originalForcePosition
    else
        print("TESTE: Reposicionando câmera aleatoriamente")
        CONFIG.FORCE_CAMERA_POSITION = nil
        self:_anchorCamera()
    end
end

--- Analisa a complexidade dos lados do continente
---@return table sideComplexity Complexidade de cada lado do continente
function LobbyMapPortals:_analyzeContinentSides()
    if #self.continentPoints < 8 then
        return { north = 0, south = 0, east = 0, west = 0 }
    end

    -- Calcular bounds do continente
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge

    for i = 1, #self.continentPoints, 2 do
        if self.continentPoints[i] < minX then minX = self.continentPoints[i] end
        if self.continentPoints[i] > maxX then maxX = self.continentPoints[i] end
        if self.continentPoints[i + 1] < minY then minY = self.continentPoints[i + 1] end
        if self.continentPoints[i + 1] > maxY then maxY = self.continentPoints[i + 1] end
    end

    local centerX = (minX + maxX) / 2
    local centerY = (minY + maxY) / 2
    local width = maxX - minX
    local height = maxY - minY

    -- Separar pontos por lado usando margens
    local margin = math.min(width, height) * 0.15 -- 15% de margem
    local sides = {
        north = {},                               -- Y alto (superior)
        south = {},                               -- Y baixo (inferior)
        east = {},                                -- X alto (direita)
        west = {}                                 -- X baixo (esquerda)
    }

    -- Classificar pontos por lado
    for i = 1, #self.continentPoints, 2 do
        local x = self.continentPoints[i]
        local y = self.continentPoints[i + 1]

        -- Determinar o lado principal baseado na posição relativa
        local distToNorth = math.abs(y - maxY)
        local distToSouth = math.abs(y - minY)
        local distToEast = math.abs(x - maxX)
        local distToWest = math.abs(x - minX)

        local minDist = math.min(distToNorth, distToSouth, distToEast, distToWest)

        if minDist == distToNorth and distToNorth < margin then
            table.insert(sides.north, { x = x, y = y })
        elseif minDist == distToSouth and distToSouth < margin then
            table.insert(sides.south, { x = x, y = y })
        elseif minDist == distToEast and distToEast < margin then
            table.insert(sides.east, { x = x, y = y })
        elseif minDist == distToWest and distToWest < margin then
            table.insert(sides.west, { x = x, y = y })
        end
    end

    -- Calcular complexidade de cada lado
    local complexity = {}
    for sideName, points in pairs(sides) do
        complexity[sideName] = self:_calculateSideComplexity(points, sideName)
    end

    return complexity
end

--- Calcula a complexidade de um lado do continente
---@param points table[] Lista de pontos do lado
---@param sideName string Nome do lado (para debug)
---@return number complexity Valor de complexidade (maior = mais natural)
function LobbyMapPortals:_calculateSideComplexity(points, sideName)
    if #points < 3 then
        return 0 -- Lado muito simples
    end

    -- Ordenar pontos por coordenada relevante
    if sideName == "north" or sideName == "south" then
        table.sort(points, function(a, b) return a.x < b.x end)
    else
        table.sort(points, function(a, b) return a.y < b.y end)
    end

    local complexity = 0

    -- 1. Fator densidade: mais pontos = mais complexo
    local densityFactor = #points

    -- 2. Fator variação: quanto os pontos variam da linha reta
    local variationFactor = 0
    if #points >= 3 then
        local startPoint = points[1]
        local endPoint = points[#points]

        for i = 2, #points - 1 do
            local point = points[i]
            local expectedX, expectedY

            -- Calcular posição esperada numa linha reta
            local t = (i - 1) / (#points - 1)
            expectedX = startPoint.x + t * (endPoint.x - startPoint.x)
            expectedY = startPoint.y + t * (endPoint.y - startPoint.y)

            -- Calcular desvio da linha reta
            local deviation = self:_distance(point.x, point.y, expectedX, expectedY)
            variationFactor = variationFactor + deviation
        end

        variationFactor = variationFactor / math.max(1, #points - 2)
    end

    -- 3. Fator direção: mudanças de direção indicam mais naturalidade
    local directionChanges = 0
    if #points >= 3 then
        for i = 2, #points - 1 do
            local prev = points[i - 1]
            local curr = points[i]
            local next = points[i + 1]

            local angle1 = math.atan2(curr.y - prev.y, curr.x - prev.x)
            local angle2 = math.atan2(next.y - curr.y, next.x - curr.x)

            local angleDiff = math.abs(angle1 - angle2)
            if angleDiff > math.pi then angleDiff = 2 * math.pi - angleDiff end

            if angleDiff > 0.3 then -- Mudança significativa de direção
                directionChanges = directionChanges + 1
            end
        end
    end

    -- Combinar fatores para calcular complexidade total
    complexity = densityFactor * 0.3 + variationFactor * 0.5 + directionChanges * 0.2

    print("DEBUG: Lado " .. sideName .. " - Pontos: " .. #points ..
        ", Variação: " .. math.floor(variationFactor) ..
        ", Mudanças de direção: " .. directionChanges ..
        ", Complexidade: " .. math.floor(complexity))

    return complexity
end

--- Identifica os lados mais naturais do continente
---@param sideComplexity table Complexidade dos lados
---@return table naturalSides Lista de lados ordenados por naturalidade
function LobbyMapPortals:_identifyNaturalSides(sideComplexity)
    local sides = {}
    for sideName, complexity in pairs(sideComplexity) do
        table.insert(sides, { name = sideName, complexity = complexity })
    end

    -- Ordenar por complexidade (maior primeiro)
    table.sort(sides, function(a, b) return a.complexity > b.complexity end)

    print("DEBUG: Lados ordenados por naturalidade:")
    for i, side in ipairs(sides) do
        local status = i <= 2 and "NATURAL" or "ARTIFICIAL"
        print("  " .. i .. ". " .. side.name .. " (complexidade: " .. math.floor(side.complexity) .. ") - " .. status)
    end

    return sides
end

--- Obtém informações detalhadas sobre os lados naturais (função pública)
---@return table sideInfo Informações detalhadas sobre cada lado
function LobbyMapPortals:getSideInfo()
    if #self.continentPoints < 8 then
        print("ERRO: Continente não foi gerado ainda ou tem poucos pontos")
        return {}
    end

    print("=== ANÁLISE DOS LADOS DO CONTINENTE ===")
    local sideComplexity = self:_analyzeContinentSides()
    local naturalSides = self:_identifyNaturalSides(sideComplexity)

    print("\nRESUMO:")
    print("Configuração atual:")
    print("  - Focar em " .. CONFIG.FOCUS_NATURAL_SIDES .. " lados mais naturais")
    print("  - Threshold mínimo: " .. CONFIG.NATURAL_SIDE_THRESHOLD)
    print("  - Distância da borda: " .. CONFIG.CAMERA_BORDER_DISTANCE)

    local validCount = 0
    for _, side in ipairs(naturalSides) do
        if side.complexity >= CONFIG.NATURAL_SIDE_THRESHOLD then
            validCount = validCount + 1
        end
    end

    print("\nResultado:")
    print("  - " .. validCount .. " lados atendem o threshold")
    print("  - Câmera será posicionada nos " .. math.min(CONFIG.FOCUS_NATURAL_SIDES, validCount) .. " melhores lados")

    return {
        complexity = sideComplexity,
        naturalSides = naturalSides,
        validCount = validCount,
        config = {
            focusCount = CONFIG.FOCUS_NATURAL_SIDES,
            threshold = CONFIG.NATURAL_SIDE_THRESHOLD,
            borderDistance = CONFIG.CAMERA_BORDER_DISTANCE
        }
    }
end

-- === MÉTODOS PARA INTERFACE COM PORTAL_SCREEN ===

--- Retorna informações de renderização para componentes externos
---@return number mapScale Escala atual do mapa
---@return number mapDrawX Posição X de desenho
---@return number mapDrawY Posição Y de desenho
function LobbyMapPortals:getRenderInfo()
    -- Retornar valores consistentes com getScreenPositionFromWorld
    -- Para que _fromIso seja o inverso correto de getScreenPositionFromWorld
    local mapScale = self.currentZoom
    local mapDrawX = self.cameraOffset.x
    local mapDrawY = self.cameraOffset.y

    return mapScale, mapDrawX, mapDrawY
end

--- Faz zoom em uma posição específica (para seleção de portais)
---@param x number Coordenada X do mundo para zoom
---@param y number Coordenada Y do mundo para zoom
---@param zoomLevel number|nil Nível de zoom (padrão: 3.0)
function LobbyMapPortals:zoomToPosition(x, y, zoomLevel)
    self.isZoomedIn = true
    self.targetZoom = zoomLevel or 3.0
    self.zoomTarget = { x = x, y = y }

    -- Calcular posição final da câmera considerando que o canvas é desenhado com origem no centro
    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()

    -- Onde queremos que o portal apareça (centro da tela)
    local desiredScreenX = screenW / 2
    local desiredScreenY = screenH / 2

    -- Converter coordenadas do mundo para coordenadas do canvas (relativas ao centro do canvas)
    local cartesianX = (x - CONFIG.VIRTUAL_MAP_WIDTH / 2)
    local cartesianY = (y - CONFIG.VIRTUAL_MAP_HEIGHT / 2)
    local isoX = (cartesianX - cartesianY) * 0.7 * CONFIG.ISO_SCALE
    local isoY = (cartesianX + cartesianY) * 0.35 * CONFIG.ISO_SCALE

    -- Como o canvas é desenhado com love.graphics.draw(canvas, cameraOffset.x, cameraOffset.y, 0, zoom, zoom, mapW/2, mapH/2)
    -- O ponto (cameraOffset.x, cameraOffset.y) representa onde o CENTRO do canvas aparece na tela
    -- Para centralizar um ponto específico, o centro do canvas deve ser deslocado pela diferença entre
    -- o ponto que queremos centralizar e o centro do canvas, multiplicado pelo zoom
    self.targetCameraOffset = {
        x = desiredScreenX - isoX * self.targetZoom,
        y = desiredScreenY - isoY * self.targetZoom
    }

    Logger.info("lobby_map_portals.zoomToPosition",
        "[LobbyMapPortals] Zoom para posição (" .. math.floor(x) .. ", " .. math.floor(y) ..
        ") com nível " .. self.targetZoom)
end

--- Sai do modo zoom (volta ao zoom out)
function LobbyMapPortals:zoomOut()
    self.isZoomedIn = false
    self.targetZoom = self.originalZoom
    self.zoomTarget = nil
    self.targetCameraOffset = {
        x = self.originalCameraOffset.x,
        y = self.originalCameraOffset.y
    }

    Logger.info("lobby_map_portals.zoomOut", "[LobbyMapPortals] Voltando ao zoom out")
end

--- Verifica se está em modo zoom
---@return boolean isZoomedIn Se está em modo zoom
function LobbyMapPortals:isInZoomMode()
    return self.isZoomedIn
end

--- Converte coordenadas do mundo para a projeção isométrica e aplica a transformação da câmera
-- Esta função é para obter a posição final na tela, considerando zoom e pan.
---@param worldX number
---@param worldY number
---@return number screenX
---@return number screenY
function LobbyMapPortals:getScreenPositionFromWorld(worldX, worldY)
    -- Converter coordenadas do mundo para coordenadas isométricas relativas ao centro do canvas
    local cartesianX = (worldX - CONFIG.VIRTUAL_MAP_WIDTH / 2)
    local cartesianY = (worldY - CONFIG.VIRTUAL_MAP_HEIGHT / 2)
    local isoX = (cartesianX - cartesianY) * 0.7 * CONFIG.ISO_SCALE
    local isoY = (cartesianX + cartesianY) * 0.35 * CONFIG.ISO_SCALE

    -- Como o canvas é desenhado com love.graphics.draw(canvas, cameraOffset.x, cameraOffset.y, 0, zoom, zoom, mapW/2, mapH/2)
    -- A posição na tela é: cameraOffset + (coordenada_no_canvas - centro_do_canvas) * zoom
    -- Mas como já convertemos para coordenadas relativas ao centro, aplicamos apenas zoom e offset da câmera
    local screenX = self.cameraOffset.x + isoX * self.currentZoom
    local screenY = self.cameraOffset.y + isoY * self.currentZoom

    return screenX, screenY
end

return LobbyMapPortals
