---@class Fonts
---@field main_small love.Font
---@field main love.Font
---@field main_bold love.Font
---@field main_large love.Font
---@field title love.Font
---@field title_large love.Font
---@field resource_value love.Font
---@field game_over love.Font
---@field hud love.Font
---@field details_title love.Font
---@field tooltip love.Font
---@field stack_count love.Font
local fonts = {}
local font_path = "assets/fonts/"
local bold_font_file -- Definido em fonts.load
local fallback_font  -- Definido em fonts.load

function fonts.load()
    local main_font_file = font_path .. "Rajdhani-Medium.ttf"
    bold_font_file = font_path .. "Rajdhani-Bold.ttf" -- Atribui à variável upvalue
    fallback_font = "verdana"

    if not love.filesystem.getInfo(main_font_file) then main_font_file = fallback_font end
    if not love.filesystem.getInfo(bold_font_file) then bold_font_file = fallback_font end

    fonts.main_small = love.graphics.newFont(main_font_file, 14)
    fonts.main = love.graphics.newFont(main_font_file, 16)
    fonts.main_bold = love.graphics.newFont(bold_font_file, 16) -- Versão bold do main
    fonts.main_large = love.graphics.newFont(main_font_file, 18)
    fonts.title = love.graphics.newFont(bold_font_file, 24)
    fonts.title_large = love.graphics.newFont(bold_font_file, 32)
    fonts.resource_value = love.graphics.newFont(bold_font_file, 30)
    fonts.game_over = love.graphics.newFont(bold_font_file, 56)
    fonts.hud = love.graphics.newFont(bold_font_file, 15)
    fonts.details_title = love.graphics.newFont(bold_font_file, 20)
    fonts.tooltip = love.graphics.newFont(main_font_file, 13)
    fonts.stack_count = love.graphics.newFont(main_font_file, 11)

    love.graphics.setFont(fonts.main)
end

--- Retorna uma fonte em negrito que caiba o texto nas dimensões especificadas.
--- Tenta tamanhos de `initialSize` até `minSize`.
--- Armazena em cache as fontes criadas.
---@param text string O texto para medir.
---@param targetWidth number Largura máxima para o texto.
---@param targetHeight number Altura máxima para o texto.
---@param initialSize integer Tamanho inicial da fonte a tentar.
---@param minSize integer Tamanho mínimo da fonte a tentar.
---@return love.Font Objeto da fonte que se encaixa, ou a fonte de tamanho mínimo se nenhuma maior couber.
function fonts.getFittingBoldFont(text, targetWidth, targetHeight, initialSize, minSize)
    initialSize = initialSize or 24
    minSize = minSize or 8

    if not bold_font_file then
        -- print("[getFittingBoldFont] AVISO: bold_font_file é nil. fonts.load() rodou? Retornando fonts.main:", fonts.main)
        return fonts.main -- Pode ser nil se fonts.load não rodou
    end

    for size = initialSize, minSize, -1 do
        local cacheKey = "bold_" .. size
        if not fonts[cacheKey] then
            -- print(string.format("[getFittingBoldFont] Cache miss para %s. Tentando criar com arquivo: '%s', tamanho: %d", cacheKey, bold_font_file, size))
            local success, font_or_error = pcall(love.graphics.newFont, bold_font_file, size)
            if success then
                fonts[cacheKey] = font_or_error
                -- print(string.format("[getFittingBoldFont] Fonte %s CRIADA e CACHEADA com sucesso.", cacheKey))
            else
                -- print(string.format("[getFittingBoldFont] ERRO ao criar fonte %s (arquivo '%s', tamanho %d): %s", cacheKey, bold_font_file, size, tostring(font_or_error)))
            end
        end

        local currentFont = fonts[cacheKey]
        if currentFont then
            local currentW = currentFont:getWidth(text or "")
            local currentH = currentFont:getHeight()
            -- print(string.format("[getFittingBoldFont] Testando %s (Tamanho Nominal: %d): textRenderW=%s (targetW=%s), fontRenderH=%s (targetH=%s)", cacheKey, size, currentW, targetWidth, currentH, targetHeight))

            if currentW <= targetWidth and currentH <= targetHeight then
                -- print(string.format("[getFittingBoldFont] FONTE ENCONTRADA no loop: %s. Retornando.", cacheKey))
                return currentFont
            end
        else
            -- print(string.format("[getFittingBoldFont] AVISO CRÍTICO: currentFont para %s é nil APÓS tentativa de criação/cache. Isso não deveria acontecer.", cacheKey))
        end
    end

    -- print(string.format("[getFittingBoldFont] Nenhuma fonte coube no loop principal. Tentando fallback para tamanho mínimo %d (cacheKey: %s).", minSize, "bold_" .. minSize))
    local minCacheKey = "bold_" .. minSize
    if not fonts[minCacheKey] then
        -- print(string.format("[getFittingBoldFont] Cache miss para fonte mínima %s. Tentando criar com arquivo: '%s', tamanho: %d", minCacheKey, bold_font_file, minSize))
        local success, font_or_error = pcall(love.graphics.newFont, bold_font_file, minSize)
        if success then
            fonts[minCacheKey] = font_or_error
            -- print(string.format("[getFittingBoldFont] Fonte mínima %s CRIADA e CACHEADA com sucesso.", minCacheKey))
        else
            -- print(string.format("[getFittingBoldFont] ERRO FATAL ao criar fonte mínima %s (arquivo '%s', tamanho %d): %s.", minCacheKey, bold_font_file, minSize, tostring(font_or_error)))
            -- print("[getFittingBoldFont] Tentando fallback absoluto para fonts.main_small ou verdana...")
            local fallbackReturn = fonts.main_small or love.graphics.newFont(fallback_font or "verdana", minSize)
            if fallbackReturn then
                local sizeStr = "N/A"
                if fallbackReturn.getHeight then -- getHeight deve existir para uma fonte válida
                    sizeStr = "Aprox " .. tostring(fallbackReturn:getHeight())
                end
                -- print(string.format("[getFittingBoldFont] Retornando fallback absoluto (tipo: %s, tamanho: %s).", type(fallbackReturn), sizeStr))
            else
                -- print("[getFittingBoldFont] FALHA TOTAL: Fallback absoluto também resultou em nil.")
            end
            return fallbackReturn
        end
    end
    -- print(string.format("[getFittingBoldFont] Retornando FONTE MÍNIMA do cache: %s.", minCacheKey))
    if not fonts[minCacheKey] then
        -- print("[getFittingBoldFont] ERRO GRAVE: Retornando nil pois fonts[minCacheKey] (" .. minCacheKey .. ") é nil mesmo após tentativa de criação/cache.")
    end
    return fonts[minCacheKey]
end

return fonts
