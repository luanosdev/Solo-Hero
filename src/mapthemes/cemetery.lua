-- Define o tema do mapa para o cemitério.
local Constants = require("src.config.constants")

local CemeteryTheme = {}

-- Tile de chão padrão para o cemitério.
-- Substitua pelo caminho correto do seu asset.
CemeteryTheme.groundTile = "assets/tiles/cemetery/ground/default_ground.png" -- Exemplo de placeholder

-- Lista de possíveis tiles de chão com pesos para variação (opcional)
CemeteryTheme.groundTiles = {
    { path = "assets/tiles/cemetery/ground/ground_A2.png", weight = 10 },
    { path = "assets/tiles/cemetery/ground/ground_A3.png", weight = 5 },
    -- Adicione mais variações de chão aqui
}

-- Lista de possíveis decorações com pesos e regras de posicionamento (opcional)
CemeteryTheme.decorations = {
    { path = "assets/tiles/cemetery/decoration/car_N.png",    weight = 10, density = 0.05, variants = 2, noiseScaleXY = 20 },
    { path = "assets/tiles/cemetery/decoration/tree_E_01.png", weight = 5,  density = 0.02, variants = 1, scale = { min = 0.8, max = 1.2 }, noiseScaleXY = 15 },
    -- Adicione mais tipos de decorações aqui
}

-- Função para gerar decorações para um chunk específico.
-- Esta é uma implementação de exemplo; você precisará adaptá-la às suas necessidades.
--- @param noiseLibInstance table|nil Instância da biblioteca de noise já inicializada.
--- @param chunkX number Coordenada X do chunk.
--- @param chunkY number Coordenada Y do chunk.
--- @param chunkSize number Tamanho do chunk.
--- @param globalSeed number Seed global para consistência.
--- @return table Lista de objetos de decoração. Cada objeto deve ter {path, x, y, offsetX, offsetY, scale (opcional)}.
function CemeteryTheme.generateDecorations(noiseLibInstance, chunkX, chunkY, chunkSize, globalSeed)
    local decorationsInChunk = {}

    if not noiseLibInstance or not noiseLibInstance.get then
        print(
            "AVISO [CemeteryTheme.generateDecorations]: Instância de NoiseLib inválida ou sem método .get(). Decorações podem não ser geradas como esperado.")
        return {}
    end

    for tileY = 1, chunkSize do
        for tileX = 1, chunkSize do
            local worldTileX = (chunkX * chunkSize) + (tileX - 1)
            local worldTileY = (chunkY * chunkSize) + (tileY - 1)

            for _, decorDef in ipairs(CemeteryTheme.decorations or {}) do
                local noiseValRaw = noiseLibInstance.get(worldTileX / (decorDef.noiseScaleXY or 20),
                    worldTileY / (decorDef.noiseScaleXY or 20),
                    globalSeed + 1000) -- Seed offset para este uso
                -- Normaliza noise de [-1, 1] para [0, 1] para usar como probabilidade
                local noiseProb = (noiseValRaw + 1) / 2

                if noiseProb < (decorDef.density or 0.01) then -- Ex: density 0.05 -> noiseProb < 0.05
                    local decorPath = decorDef.path
                    if decorDef.variants and decorDef.variants > 1 then
                        local variantNoiseRaw = noiseLibInstance.get(worldTileX / 10,
                            worldTileY / 10,
                            globalSeed + 2000 + decorDef.weight)
                        local variantNoiseProb = (variantNoiseRaw + 1) / 2
                        local variantNum = math.floor(variantNoiseProb * decorDef.variants) + 1
                        variantNum = math.max(1, math.min(variantNum, decorDef.variants))
                        if string.match(decorPath, "_%d%d%.png$") then
                            decorPath = string.gsub(decorPath, "_%d%d%.png$", string.format("_%02d.png", variantNum))
                        else
                            decorPath = string.gsub(decorPath, "%.png$", string.format("_%02d.png", variantNum))
                        end
                    end

                    local scale = 1.0
                    if decorDef.scale then
                        local scaleNoiseRaw = noiseLibInstance.get(worldTileX / 5,
                            worldTileY / 5,
                            globalSeed + 3000 + decorDef.weight)
                        local scaleNoiseProb = (scaleNoiseRaw + 1) / 2
                        scale = decorDef.scale.min + (decorDef.scale.max - decorDef.scale.min) * scaleNoiseProb
                    end

                    table.insert(decorationsInChunk, {
                        asset = decorPath,                                                    -- Mudado de 'path' para 'asset' para consistência com ChunkManager:collectRenderables
                        px = (tileX - 0.5) * Constants.TILE_WIDTH + (decorDef.offsetX or 0),  -- Posição X em pixels relativa ao canto do CHUNK
                        py = (tileY - 0.5) * Constants.TILE_HEIGHT + (decorDef.offsetY or 0), -- Posição Y em pixels relativa ao canto do CHUNK
                        renderScale = scale,
                        depthOffset = decorDef.depthOffset or 0
                    })
                end
            end
        end
    end
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
        return CemeteryTheme.groundTile
    end

    if not noiseLibInstance or not noiseLibInstance.get then
        print("AVISO [CemeteryTheme.getRandomGroundTile]: Instância de NoiseLib inválida ou sem método .get().")
        return CemeteryTheme.groundTile
    end

    local noiseValueRaw = noiseLibInstance.get(worldX / 30, worldY / 30, globalSeed)
    local noiseValueProb = (noiseValueRaw + 1) / 2 -- Normaliza para [0, 1]
    local index = math.floor(noiseValueProb * #CemeteryTheme.groundTiles) + 1
    index = math.max(1, math.min(index, #CemeteryTheme.groundTiles))

    return CemeteryTheme.groundTiles[index].path
end

return CemeteryTheme
