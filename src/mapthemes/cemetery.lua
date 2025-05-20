-- Define o tema do mapa para o cemitério.
local Constants = require("src.config.constants")

local CemeteryTheme = {}

-- Tile de chão padrão para o cemitério.
-- Substitua pelo caminho correto do seu asset.
CemeteryTheme.groundTile = "assets/tiles/cemetery/ground/default_ground.png" -- Exemplo de placeholder

-- Lista de possíveis tiles de chão com pesos para variação (opcional)
CemeteryTheme.groundTiles = {
    { path = "assets/tiles/cemetery/ground/ground_A2.png", weight = 2 },
    -- Adicione mais variações de chão aqui
}

-- Lista de assets de decoração para o cemitério
CemeteryTheme.decorations = {
    "assets/tiles/cemetery/decoration/car_N_01.png",
    "assets/tiles/cemetery/decoration/car_N_02.png",
    "assets/tiles/cemetery/decoration/tree_E_01.png", -- Exemplo, ajuste conforme seus assets
    -- Adicione mais caminhos de assets de decoração aqui
}

-- Presumimos que a base de uma decoração ocupa no máximo a largura de um tile
-- e a "profundidade" no chão também (para cálculo de margem)
local DECO_BASE_MAX_WIDTH = Constants.TILE_WIDTH
local DECO_BASE_MAX_DEPTH = Constants.TILE_HEIGHT

-- Configurações do tema do Cemitério (AJUSTE ESTES VALORES)
local CHANCE_EMPTY_CHUNK = 0.10            -- 10% de chance de um chunk ser completamente vazio
local MAX_PLACEMENT_ATTEMPTS_SCATTERED = 5 -- Tentativas para posicionar uma decoração espalhada

--- Gera decorações para um chunk específico usando lógica de clusters e espalhamento.
--- @param noiseLibInstance table|nil Instância da biblioteca de noise (não usada nesta versão, mas mantida para compatibilidade de assinatura).
--- @param chunkX number Coordenada X do chunk.
--- @param chunkY number Coordenada Y do chunk.
--- @param chunkSize number Tamanho do chunk.
--- @param globalSeed number Seed global para consistência.
--- @return table Lista de objetos de decoração.
function CemeteryTheme.generateDecorations(noiseLibInstance, chunkX, chunkY, chunkSize, globalSeed)
    local decorationsInChunk = {}
    local chunkPixelWidth = chunkSize * Constants.TILE_WIDTH
    local chunkPixelHeight = chunkSize * Constants.TILE_HEIGHT
    -- Seed específica do chunk para resultados determinísticos e variados por chunk
    local chunkSpecificSeed = (globalSeed or os.time()) + (chunkX * 73856093) + (chunkY * 19349663) +
        (chunkX * chunkY * 47)
    math.randomseed(chunkSpecificSeed)

    -- Chance de ter um chunk vazio
    if #CemeteryTheme.decorations == 0 then -- Se não houver decorações definidas, retorna vazio
        return decorationsInChunk
    end
    if math.random() < CHANCE_EMPTY_CHUNK then
        -- print(string.format("[CemeteryTheme DEBUG] Chunk Vazio (%d, %d) gerado.", chunkX, chunkY))
        return decorationsInChunk
    end

    -- Decorações aleatórias espalhadas
    local scatteredDecoCount = math.random(5, 10)
    -- Define o espaçamento mínimo dinâmico aqui, baseado em 150% do tamanho base da decoração
    local dynamicMinDistance = DECO_BASE_MAX_WIDTH * 1.5
    local dynamicMinDistanceSq = dynamicMinDistance * dynamicMinDistance

    for _ = 1, scatteredDecoCount do
        local placed = false
        for attempt = 1, MAX_PLACEMENT_ATTEMPTS_SCATTERED do
            local potentialPx = math.random(DECO_BASE_MAX_WIDTH / 2, chunkPixelWidth - DECO_BASE_MAX_WIDTH / 2)
            local potentialPy = math.random(DECO_BASE_MAX_DEPTH / 2, chunkPixelHeight - DECO_BASE_MAX_DEPTH / 2)
            local tooClose = false
            for _, existingDeco in ipairs(decorationsInChunk) do
                local distSq = (existingDeco.px - potentialPx) ^ 2 + (existingDeco.py - potentialPy) ^ 2
                -- Usa a distância dinâmica ao quadrado para a verificação
                if distSq < dynamicMinDistanceSq then
                    tooClose = true
                    break
                end
            end
            if not tooClose then
                table.insert(decorationsInChunk, {
                    asset = CemeteryTheme.decorations[math.random(#CemeteryTheme.decorations)],
                    px = potentialPx,
                    py = potentialPy,
                    -- renderScale e depthOffset podem ser adicionados aqui se necessário por tipo de asset,
                    -- ou gerenciados no AssetManager/ChunkManager ao carregar a imagem.
                })
                placed = true
                break
            end
        end
    end

    -- Adiciona clusters (ex: um grupo de túmulos, uma pequena cripta, carros abandonados)
    local numClusters = math.random(1, 2) -- Ajuste o número de clusters
    for c = 1, numClusters do
        local clusterAssetType = CemeteryTheme.decorations
            [math.random(#CemeteryTheme.decorations)] -- Pode variar o asset por cluster ou fixar
        local clusterMargin =
            DECO_BASE_MAX_WIDTH                       -- Margem para o centro do cluster
        local clusterX = math.random(clusterMargin, chunkPixelWidth - clusterMargin)
        local clusterY = math.random(clusterMargin, chunkPixelHeight - clusterMargin)
        local itemsInCluster = math.random(3, 6)                           -- Número de itens no cluster
        local clusterRadius = Constants.TILE_WIDTH * math.random(0.4, 0.8) -- Raio do cluster

        for i = 1, itemsInCluster do
            local angle = math.random() * 2 * math.pi
            local radiusFactor = math.random() -- Para variar a distância do centro
            local decoPx = math.floor(clusterX + math.cos(angle) * clusterRadius * radiusFactor)
            local decoPy = math.floor(clusterY + math.sin(angle) * clusterRadius * radiusFactor)

            -- Garante que a decoração esteja dentro das bordas do chunk (considerando sua base)
            decoPx = math.max(DECO_BASE_MAX_WIDTH / 2, math.min(decoPx, chunkPixelWidth - DECO_BASE_MAX_WIDTH / 2))
            decoPy = math.max(DECO_BASE_MAX_DEPTH / 2, math.min(decoPy, chunkPixelHeight - DECO_BASE_MAX_DEPTH / 2))

            table.insert(decorationsInChunk, {
                asset = clusterAssetType, -- Todos os itens neste cluster são do mesmo tipo (para este exemplo)
                px = decoPx,
                py = decoPy
            })
        end
    end

    -- print(string.format("[CemeteryTheme DEBUG] Decorações geradas para chunk (%d, %d): %d objetos", chunkX, chunkY, #decorationsInChunk))
    return decorationsInChunk
end

-- Função para obter um tile de chão aleatório com base nos pesos.
-- O ChunkManager pode chamar isso para cada tile de chão se quiser variação.
--- @param noiseLibInstance table|nil Instância da biblioteca de noise já inicializada.
--- @param worldX number Coordenada X global do tile.
--- @param worldY number Coordenada Y global do tile.
--- @param globalSeed number Seed global para consistência.
--- @return string Caminho do asset do tile de chão.
function CemeteryTheme.getRandomGroundTile(noiseLibInstance, worldX, worldY, globalSeed)
    if not CemeteryTheme.groundTiles or #CemeteryTheme.groundTiles == 0 then
        return CemeteryTheme.groundTile -- Retorna o tile padrão se nenhuma variação for definida
    end

    if not noiseLibInstance or not noiseLibInstance.get then
        print(
            "AVISO [CemeteryTheme.getRandomGroundTile]: Instância de NoiseLib inválida ou sem método .get(). Usando tile padrão.")
        return CemeteryTheme.groundTile
    end

    -- Usa noise para selecionar um tile, mas de forma mais simples que antes
    local noiseValueRaw = noiseLibInstance.get(worldX / 20, worldY / 20, globalSeed + 500) -- Scale e seed diferentes
    local noiseValueProb = (noiseValueRaw + 1) / 2                                         -- Normaliza para [0, 1]

    -- Distribui a probabilidade entre os tiles disponíveis
    local totalWeight = 0
    for _, tileDef in ipairs(CemeteryTheme.groundTiles) do
        totalWeight = totalWeight + (tileDef.weight or 1)
    end

    local randomChoice = noiseValueProb * totalWeight
    local cumulativeWeight = 0
    for _, tileDef in ipairs(CemeteryTheme.groundTiles) do
        cumulativeWeight = cumulativeWeight + (tileDef.weight or 1)
        if randomChoice <= cumulativeWeight then
            return tileDef.path
        end
    end

    return CemeteryTheme.groundTiles[#CemeteryTheme.groundTiles].path -- Fallback para o último em caso de erro de float
end

return CemeteryTheme
