-- Define o tema do mapa para o cemitério.
local Constants = require("src.config.constants")

local CemeteryTheme = {}

-- Tile de chão padrão para o cemitério.
CemeteryTheme.groundTile = "assets/tiles/cemetery/ground/default_ground.png"

-- Lista de possíveis tiles de chão com pesos para variação (REMOVIDO PARA SIMPLICIDADE)
-- CemeteryTheme.groundTiles = {
--     { path = "assets/tiles/cemetery/ground/ground_A2.png", weight = 2 },
-- }

-- Lista de assets de decoração para o cemitério (REMOVIDO)
-- CemeteryTheme.decorations = {
--     "assets/tiles/cemetery/decoration/car_N_01.png",
--     "assets/tiles/cemetery/decoration/car_N_02.png",
--     "assets/tiles/cemetery/decoration/tree_E_01.png",
-- }

-- Constantes de decoração (REMOVIDAS)

--- Gera decorações para um chunk específico.
--- Como as decorações foram removidas, esta função agora retorna uma tabela vazia.
--- @param chunkX number Coordenada X do chunk.
--- @param chunkY number Coordenada Y do chunk.
--- @param chunkSize number Tamanho do chunk.
--- @param globalSeed number Seed global para consistência (não usada).
--- @return table Lista vazia de objetos de decoração.
function CemeteryTheme.generateDecorations(chunkX, chunkY, chunkSize, globalSeed)
    return {} -- Retorna uma tabela vazia, pois não há mais decorações
end

-- Função para obter o tile de chão.
-- Como a variação foi removida, sempre retorna o groundTile padrão.
--- @param worldX number Coordenada X global do tile.
--- @param worldY number Coordenada Y global do tile.
--- @param globalSeed number Seed global para consistência (não usada).
--- @return string Caminho do asset do tile de chão padrão.
function CemeteryTheme.getRandomGroundTile(worldX, worldY, globalSeed)
    return CemeteryTheme.groundTile -- Retorna sempre o tile de chão padrão
end

return CemeteryTheme
