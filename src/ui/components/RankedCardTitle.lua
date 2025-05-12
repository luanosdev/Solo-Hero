local Component = require("src.ui.components.Component")
local elements = require("src.ui.ui_elements")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

---@class RankedCardTitle : Component
---@field text string Texto a ser exibido
---@field rank string Letra do rank (ex: "S", "A", "E")
---@field config table Configuração extra para o card
---@field dynamicFont Font|nil Fonte calculada dinamicamente
---@field configuredHeight number Altura com a qual o card foi configurado
local RankedCardTitle = {}
RankedCardTitle.__index = RankedCardTitle
setmetatable(RankedCardTitle, { __index = Component })

local function table_extend_force(t1, t2)
    local result = {}
    for k, v in pairs(t1) do result[k] = v end
    for k, v in pairs(t2) do result[k] = v end
    return result
end

--- Cria uma nova instância de RankedCardTitle
--- O card terá uma altura fixa, e o texto se ajustará dentro dela.
---@param config table { text, rank, width, height, ... }
---@return RankedCardTitle
function RankedCardTitle:new(config)
    assert(config and config.text, "RankedCardTitle:new requer 'text'")
    assert(config and config.rank, "RankedCardTitle:new requer 'rank'")
    assert(config and config.width, "RankedCardTitle:new requer 'width' para cálculo inicial do layout")

    config.height = config.height or 40

    local instance = Component:new(config)
    setmetatable(instance, RankedCardTitle)
    instance.text = config.text
    instance.rank = config.rank
    instance.configuredHeight = config.height
    instance.rect.h = instance.configuredHeight
    instance.config = config.config or {}
    instance.dynamicFont = nil
    instance.needsLayout = true
    return instance
end

function RankedCardTitle:_getDrawConfig()
    local baseConfig = {
        rankLetterForStyle = self.rank,
        font = self.dynamicFont or fonts.hud,
        h_align = "center",
        v_align = "middle",
        padding = self.config.padding or 10
    }
    return table_extend_force(baseConfig, self.config or {})
end

function RankedCardTitle:_updateLayout()
    if not self.needsLayout then return end

    local textRenderWidth, textRenderHeight

    local effectiveCardHeight = self.rect.h
    if effectiveCardHeight == 0 and self.configuredHeight > 0 then
        effectiveCardHeight = self.configuredHeight
    elseif self.rect.h == 0 and self.configuredHeight == 0 then
        effectiveCardHeight = 1
    end

    local tempDrawConfig = self:_getDrawConfig()
    local padding = tempDrawConfig.padding

    textRenderWidth = (self.rect.w or 0) - (padding * 2)
    textRenderHeight = effectiveCardHeight - (padding * 2)

    if textRenderWidth > 0 and textRenderHeight > 0 then
        local initialFontSize = math.floor(textRenderHeight * 0.8)
        initialFontSize = math.max(8, initialFontSize)
        local minFontSize = 8
        self.dynamicFont = fonts.getFittingBoldFont(self.text, textRenderWidth, textRenderHeight, initialFontSize,
            minFontSize)
    else
        self.dynamicFont = fonts.getFittingBoldFont("", 1, 1, 8, 8)
    end

    if self.dynamicFont then
    else
        self.dynamicFont = fonts.main_small or fonts.main or love.graphics.newFont("verdana", 8)
    end
    self.needsLayout = false
end

function RankedCardTitle:draw()
    if self.needsLayout then
        self:_updateLayout()
    end

    local drawW = self.rect.w
    local drawH = self.rect.h
    if drawH == 0 and self.configuredHeight > 0 then
        drawH = self.configuredHeight
    elseif drawH == 0 and self.configuredHeight == 0 then
        drawH = 1
    end

    elements.drawTextCard(
        self.rect.x,
        self.rect.y,
        drawW,
        drawH,
        self.text,
        self:_getDrawConfig()
    )
end

return RankedCardTitle
