local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local Component = require("src.ui.components.Component")

---@class Text : Component
---@field width number Largura máxima para o texto (usada para alinhamento/quebra).
---@field text string Texto original.
---@field size string Variante de tamanho/semântica (ex: 'h1', 'body', 'small').
---@field variant string Variante de cor (ex: 'default', 'muted', 'rarity_S').
---@field align string Alinhamento horizontal ('left', 'center', 'right').
---@field fontWeight string|nil Peso da fonte ('bold', 'thin').
---@field uppercase boolean Se o texto deve ser maiúsculo.
---@field actualFont love.Font A fonte LÖVE selecionada.
---@field actualColor table A tabela de cor selecionada.
---@field transformedText string O texto após transformações (uppercase).
---@field rect table {x, y, w, h} Retângulo do componente.
---@field needsLayout boolean Se o componente precisa de layout interno.
---@field debug boolean Se desenha borda de debug.
local Text = setmetatable({}, { __index = Component })
Text.__index = Text

-- Mapeamento de Tamanhos para Fontes (Ajuste conforme suas fontes)
local sizeFontMap = {
    h1 = fonts.title or fonts.main_large or fonts.main,
    h2 = fonts.main_large or fonts.main,
    h3 = fonts.main_bold or fonts.main, -- Exemplo: h3 usa bold
    body = fonts.main,
    label = fonts.main_small or fonts.main,
    small = fonts.main_small or fonts.main,
    caption = fonts.tooltip or fonts.main_small or fonts.main
}

-- Mapeamento de Peso (requer que as fontes existam em fonts.lua)
-- Exemplo: Se fontWeight for 'bold' e a fonte base for fonts.main, tenta usar fonts.main_bold
local fontWeightMap = {
    [fonts.main] = { bold = fonts.main_bold },
    [fonts.main_small] = { bold = fonts.main_small_bold }, -- Adicione outras se existirem
    -- ... adicione mapeamentos para outras fontes base (title, large, etc.) se tiverem variantes de peso
}

--- Cria uma nova instância de Texto.
---@param config table Configuração:
---  text (string) - Obrigatório.
---  width (number) - Obrigatório (largura máxima).
---  x (number|nil) - Opcional, padrão 0.
---  y (number|nil) - Opcional, padrão 0.
---  size (string|nil) - Opcional, padrão 'body'.
---  variant (string|nil) - Opcional, padrão 'default'.
---  align (string|nil) - Opcional, padrão 'left'.
---  fontWeight (string|nil) - Opcional ('bold', 'thin').
---  uppercase (boolean|nil) - Opcional, padrão false.
---  debug (boolean|nil) - Opcional, padrão false.
---@return Text
function Text:new(config)
    if not config or not config.text or not config.width then
        error("Text:new - Configuração inválida. 'text' e 'width' são obrigatórios.", 2)
    end
    -- Chama construtor base
    local instance = Component:new(config)
    setmetatable(instance, Text)

    -- Propriedades específicas do Texto
    instance.text = config.text
    instance.size = config.size or "body"
    instance.variant = config.variant or "default"
    instance.align = config.align or "left"
    instance.fontWeight = config.fontWeight
    instance.uppercase = config.uppercase or false
    instance.width = config.width
    instance.rect.w = instance.width
    instance.debug = config.debug or false

    -- 1. Selecionar Fonte
    local baseFont = sizeFontMap[instance.size] or fonts.main
    instance.actualFont = baseFont
    if instance.fontWeight and fontWeightMap[baseFont] and fontWeightMap[baseFont][instance.fontWeight] then
        instance.actualFont = fontWeightMap[baseFont][instance.fontWeight]
        -- print(string.format("Text: Using font weight '%s' for size '%s'", instance.fontWeight, instance.size))
    elseif instance.fontWeight then
        -- print(string.format("AVISO (Text:new): Font weight '%s' não encontrado para '%s'.", instance.fontWeight, instance.size))
    end

    -- 2. Selecionar Cor
    local colorKey = instance.variant
    if colors[colorKey] then
        instance.actualColor = colors[colorKey]
    elseif string.match(colorKey, "^rarity_") then
        local rarity = string.sub(colorKey, 8)
        instance.actualColor = colors.rarity and colors.rarity[rarity]
    elseif string.match(colorKey, "^rank_") then
        local rank = string.sub(colorKey, 6)
        instance.actualColor = colors.rank and colors.rank[rank]
    else
        instance.actualColor = colors["text_" .. colorKey]
    end
    instance.actualColor = instance.actualColor or colors.text_default or { 1, 1, 1, 1 }

    -- 3. Transformar Texto
    instance.transformedText = instance.uppercase and string.upper(instance.text) or instance.text

    -- 4. Altura inicial (pode ser 0 ou altura de 1 linha)
    instance.rect.h = instance.actualFont:getHeight() or 0

    -- Precisa calcular layout para determinar altura real
    instance.needsLayout = true

    return instance
end

--- Calcula a altura real do texto baseado na largura atual.
function Text:_updateLayout()
    -- Width (self.rect.w) deve ter sido setado pelo pai (YStack)
    -- print(string.format("Text:_updateLayout START for '%s' | w=%.1f", self.text, self.rect.w))
    if self.actualFont and self.transformedText and self.rect.w > 0 then
        local _, lines = self.actualFont:getWrap(self.transformedText, self.rect.w)
        local fontHeight = self.actualFont:getHeight()
        local linesHeight = #lines * fontHeight
        self.rect.h = math.max(fontHeight, linesHeight)
        -- print(string.format("  -> Calculated h=%.1f (%d lines * %.1f fontH)", self.rect.h, #lines, fontHeight))
    else
        -- Fallback se largura for 0 ou fonte/texto ausente
        self.rect.h = self.actualFont and self.actualFont:getHeight() or 10 -- Altura mínima para fallback
        -- print(string.format("  -> Fallback h=%.1f", self.rect.h))
    end
    self.needsLayout = false -- Layout calculado
end

--- Desenha o texto.
--- Não calcula mais a altura aqui.
function Text:draw()
    -- Desenha debug da base (margin, rect, padding) se habilitado
    Component.draw(self)

    -- Calcula a posição X do texto dentro do rect, considerando padding
    -- Delegamos o ALINHAMENTO para love.graphics.printf
    local textDrawX = self.rect.x + self.padding.left
    local innerWidth = self.rect.w - self.padding.left - self.padding.right

    -- Calcula a posição Y do texto dentro do rect, considerando padding (verticalmente sempre centralizado por printf por enquanto)
    local textDrawY = self.rect.y + self.padding.top -- O printf centraliza verticalmente se h > font:getHeight()

    -- Define a cor
    love.graphics.setColor(self.actualColor)
    love.graphics.setFont(self.actualFont) -- Garante a fonte correta

    -- *** DEBUG FINAL ***
    -- print(string.format("Text:draw FINAL COORDS for '%s': x=%.1f, y=%.1f | rect=(%.1f, %.1f, %.1f, %.1f)", self.transformedText, textDrawX, textDrawY, self.rect.x, self.rect.y, self.rect.w, self.rect.h))

    -- Desenha o texto usando printf para clipping automático pela largura do rect interno
    love.graphics.printf(self.transformedText,
        math.floor(textDrawX),
        math.floor(textDrawY),
        math.floor(innerWidth), -- Largura limite para o printf
        self.align
    )

    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

--- Atualiza o estado (atualmente não faz nada).
function Text:update(dt, mx, my, allowHover)
    -- Poderia ser usado para efeitos de texto no futuro
end

--- Manipula clique (atualmente não faz nada).
---@return boolean false Sempre retorna false.
function Text:handleMousePress(x, y, button)
    return false
end

--- Manipula soltar do mouse (atualmente não faz nada).
---@return boolean false Sempre retorna false.
function Text:handleMouseRelease(x, y, button)
    return false
end

return Text
