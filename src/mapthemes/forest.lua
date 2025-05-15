local Constants = require("src.config.constants")

local ForestTheme = {}

ForestTheme.groundTile = "assets/tiles/basic_forest/ground/ground_base.png"
ForestTheme.decorations = {
    "assets/tiles/basic_forest/decoration/tree1.png",
    "assets/tiles/basic_forest/decoration/tree2.png",
    -- Adicione mais assets de árvores aqui se desejar
}

-- Presumimos que a base de uma decoração ocupa no máximo a largura de um tile
-- e a "profundidade" no chão também (para cálculo de margem)
local DECO_BASE_MAX_WIDTH = Constants.TILE_WIDTH
local DECO_BASE_MAX_DEPTH = Constants.TILE_HEIGHT -- Usando TILE_HEIGHT como proxy para a profundidade da base no chão

-- Configurações do tema
local CHANCE_EMPTY_CHUNK = 0.15            -- 15% de chance de um chunk ser completamente vazio
local MIN_DISTANCE_BETWEEN_SCATTERED_TREES_SQ = (Constants.TILE_WIDTH * 3) ^
    2                                      -- Distância mínima ao quadrado (aumentado multiplicador para maior espaçamento)
local MAX_PLACEMENT_ATTEMPTS_SCATTERED = 5 -- Tentativas para posicionar uma árvore espalhada

--- Gera decorações determinísticas para um chunk
function ForestTheme.generateDecorations(chunkX, chunkY, chunkSize, globalSeed)
    local decorations = {}
    local chunkPixelWidth = chunkSize * Constants.TILE_WIDTH
    local chunkPixelHeight = chunkSize * Constants.TILE_HEIGHT
    local chunkSpecificSeed = (globalSeed or os.time()) + (chunkX * 73856093) + (chunkY * 19349663) +
        (chunkX * chunkY * 47)
    math.randomseed(chunkSpecificSeed)

    -- Chance de ter um chunk vazio
    if math.random() < CHANCE_EMPTY_CHUNK then
        print(string.format("[DEBUG] Chunk Vazio (%d, %d) gerado.", chunkX, chunkY))
        return decorations -- Retorna lista vazia
    end

    -- Decorações aleatórias espalhadas (com margem e distância mínima)
    local scatteredDecoCount = math.random(10, 15) -- Reduzido um pouco para compensar clusters e distância
    for _ = 1, scatteredDecoCount do
        local placed = false
        for attempt = 1, MAX_PLACEMENT_ATTEMPTS_SCATTERED do
            local potentialPx = math.random(DECO_BASE_MAX_WIDTH / 2, chunkPixelWidth - DECO_BASE_MAX_WIDTH / 2)
            local potentialPy = math.random(DECO_BASE_MAX_DEPTH / 2, chunkPixelHeight - DECO_BASE_MAX_DEPTH / 2)
            local tooClose = false
            for _, existingDeco in ipairs(decorations) do
                local distSq = (existingDeco.px - potentialPx) ^ 2 + (existingDeco.py - potentialPy) ^ 2
                if distSq < MIN_DISTANCE_BETWEEN_SCATTERED_TREES_SQ then
                    tooClose = true
                    break
                end
            end
            if not tooClose then
                table.insert(decorations, {
                    asset = ForestTheme.decorations[math.random(#ForestTheme.decorations)],
                    px = potentialPx,
                    py = potentialPy
                })
                placed = true
                break
            end
        end
        -- if not placed then print(string.format("[DEBUG] Não foi possível posicionar árvore espalhada no chunk (%d,%d) após %d tentativas", chunkX, chunkY, MAX_PLACEMENT_ATTEMPTS_SCATTERED)) end
    end

    -- Adiciona clusters de árvores (aglomerados, com margem)
    local numClusters = math.random(1, 3) -- Ajustado número de clusters
    for c = 1, numClusters do
        local clusterAssetType = ForestTheme.decorations[math.random(#ForestTheme.decorations)]
        local clusterMargin = DECO_BASE_MAX_WIDTH
        local clusterX = math.random(clusterMargin, chunkPixelWidth - clusterMargin)
        local clusterY = math.random(clusterMargin, chunkPixelHeight - clusterMargin)
        local treesInCluster = math.random(6, 12) -- Ajustado tamanho do cluster
        local clusterRadius = Constants.TILE_WIDTH * 0.6

        for i = 1, treesInCluster do
            local angle = math.random() * 2 * math.pi
            local radius = math.random(0, clusterRadius)
            local decoPx = math.floor(clusterX + math.cos(angle) * radius)
            local decoPy = math.floor(clusterY + math.sin(angle) * radius)
            decoPx = math.max(DECO_BASE_MAX_WIDTH / 2, math.min(decoPx, chunkPixelWidth - DECO_BASE_MAX_WIDTH / 2))
            decoPy = math.max(DECO_BASE_MAX_DEPTH / 2, math.min(decoPy, chunkPixelHeight - DECO_BASE_MAX_DEPTH / 2))
            table.insert(decorations, {
                asset = clusterAssetType,
                px = decoPx,
                py = decoPy
            })
        end
    end

    print(string.format("[DEBUG] Decorações geradas para chunk (%d, %d): %d objetos", chunkX, chunkY, #decorations))
    return decorations
end

return ForestTheme
