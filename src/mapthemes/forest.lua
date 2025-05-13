local Constants = require("src.config.constants")

local ForestTheme = {}

ForestTheme.groundTile = "assets/tiles/basic_forest/ground/ground_base.png"
ForestTheme.decorations = {
    "assets/tiles/basic_forest/decoration/tree1.png",
    "assets/tiles/basic_forest/decoration/tree2.png",
}

--- Gera decorações aleatórias para um chunk
---@param chunkX number
---@param chunkY number
---@param chunkSize number
---@return table
function ForestTheme.generateDecorations(chunkX, chunkY, chunkSize)
    local decorations = {}
    local chunkPixelWidth = chunkSize * Constants.TILE_WIDTH
    local chunkPixelHeight = chunkSize * Constants.TILE_HEIGHT
    for i = 1, math.random(2, 5) do
        table.insert(decorations, {
            asset = ForestTheme.decorations[math.random(#ForestTheme.decorations)],
            -- Posição aleatória em pixels dentro do chunk
            px = math.random(0, chunkPixelWidth - 1),
            py = math.random(0, chunkPixelHeight - 1)
        })
    end
    print(string.format("[DEBUG] Decorações geradas para chunk (%d, %d): %d objetos", chunkX, chunkY, #decorations))
    return decorations
end

return ForestTheme
