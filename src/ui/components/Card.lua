-- src/ui/components/Card.lua
local Component = require("src.ui.components.Component")

---@class Card : Component Representa uma área com fundo e/ou borda, como um cartão.
---@field backgroundColor color|nil Cor de fundo (ex: colors.window_bg).
---@field borderColor color|nil Cor da borda (ex: colors.window_border).
---@field borderWidth number Largura da borda (padrão 1 se borderColor for definido).
---@field borderRadius number|nil Raio da borda para retângulos arredondados (opcional).
local Card = setmetatable({}, { __index = Component })
Card.__index = Card

function Card:new(config)
    local instance = Component:new(config) ---@type Card
    setmetatable(instance, Card)

    instance.backgroundColor = config.backgroundColor
    instance.borderColor = config.borderColor
    instance.borderWidth = config.borderWidth or (instance.borderColor and 1 or 0)
    instance.borderRadius = config.borderRadius

    instance.needsLayout = false -- Card não tem layout interno

    return instance
end

--- Desenha o card (fundo e/ou borda).
function Card:draw()
    local drawMode = "fill"
    if self.borderColor and self.borderWidth > 0 then
        drawMode = "line" -- Desenha borda se especificada
    end

    -- Desenha o fundo se definido
    if self.backgroundColor then
        love.graphics.push()
        love.graphics.setColor(self.backgroundColor)
        if self.borderRadius then
            love.graphics.rectangle("fill", self.rect.x, self.rect.y, self.rect.w, self.rect.h, self.borderRadius)
        else
            love.graphics.rectangle("fill", self.rect.x, self.rect.y, self.rect.w, self.rect.h)
        end
        love.graphics.pop()
    end

    -- Desenha a borda se definida (por cima do fundo)
    if self.borderColor and self.borderWidth > 0 then
        love.graphics.push()
        love.graphics.setColor(self.borderColor)
        love.graphics.setLineWidth(self.borderWidth)
        if self.borderRadius then
            love.graphics.rectangle("line", self.rect.x, self.rect.y, self.rect.w, self.rect.h, self.borderRadius)
        else
            love.graphics.rectangle("line", self.rect.x, self.rect.y, self.rect.w, self.rect.h)
        end
        love.graphics.pop()
    end

    -- Chama o draw da base para desenhar debug (padding/margin)
    Component.draw(self)
end

return Card
