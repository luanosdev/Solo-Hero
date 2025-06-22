-- Gerencia a criação dinâmica de Texture Atlases usando Canvas.

---@class TextureAtlasManager
---@field atlases table Cache para os atlases gerados.
local TextureAtlasManager = {}
TextureAtlasManager.__index = TextureAtlasManager

function TextureAtlasManager:new()
    local instance = setmetatable({}, TextureAtlasManager)
    instance.atlases = {}
    Logger.info("TextureAtlasManager.new", "TextureAtlasManager criado.")
    return instance
end

--- Cria ou recupera um atlas de textura para as decorações de um mapa.
--- @param mapData table Os dados do mapa contendo as definições de decoração.
--- @return table { canvas: love.Canvas, quads: table<string, love.Quad> }
function TextureAtlasManager:createAtlasForDecorations(mapData)
    local mapName = mapData.name
    if self.atlases[mapName] then
        return self.atlases[mapName]
    end

    Logger.info("TextureAtlasManager.createAtlasForDecorations", "Iniciando criação de atlas para o mapa: " .. mapName)

    -- 1. Coleta todas as imagens de decoração únicas.
    local uniqueImages = {}
    local imageObjects = {}
    if mapData.decorations and mapData.decorations.layers then
        for _, layer in ipairs(mapData.decorations.layers) do
            for _, decoType in ipairs(layer.types) do
                for _, variant in ipairs(decoType.variants) do
                    if not uniqueImages[variant.path] then
                        uniqueImages[variant.path] = true
                        local img = love.graphics.newImage(variant.path)
                        table.insert(imageObjects, { path = variant.path, image = img })
                    end
                end
            end
        end
    end

    if #imageObjects == 0 then
        Logger.warn("TextureAtlasManager", "Nenhuma imagem de decoração encontrada para o mapa: " .. mapName)
        return nil
    end

    -- 2. Organiza as imagens em uma grade (algoritmo de packing simples).
    local PADDING = 2 -- Espaçamento para evitar sangramento de texturas.
    local items = {}
    local totalWidth = 0
    local totalHeight = 0
    local currentX = PADDING
    local currentY = PADDING
    local rowHeight = 0

    for _, data in ipairs(imageObjects) do
        local w, h = data.image:getDimensions()
        if currentX + w + PADDING > 2048 then -- Largura máxima do atlas
            currentX = PADDING
            currentY = currentY + rowHeight + PADDING
            rowHeight = 0
        end

        table.insert(items, {
            path = data.path,
            image = data.image,
            x = currentX,
            y = currentY,
            w = w,
            h = h
        })

        currentX = currentX + w + PADDING
        if h > rowHeight then
            rowHeight = h
        end
        if currentX > totalWidth then
            totalWidth = currentX
        end
    end
    totalHeight = currentY + rowHeight + PADDING

    -- 3. Cria o Canvas e desenha as imagens nele.
    local canvas = love.graphics.newCanvas(totalWidth, totalHeight)
    love.graphics.setCanvas({ canvas, stencil = false })
    love.graphics.clear()

    local quads = {}
    for _, item in ipairs(items) do
        love.graphics.draw(item.image, item.x, item.y)
        quads[item.path] = love.graphics.newQuad(item.x, item.y, item.w, item.h, totalWidth, totalHeight)
    end

    love.graphics.setCanvas() -- Volta a desenhar na tela.

    Logger.info("TextureAtlasManager.createAtlasForDecorations",
        "Atlas criado para o mapa '" .. mapName .. "' com tamanho: " .. totalWidth .. "x" .. totalHeight)

    local atlas = { canvas = canvas, quads = quads }
    self.atlases[mapName] = atlas

    return atlas
end

return TextureAtlasManager
