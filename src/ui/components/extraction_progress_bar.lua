local fonts = require("src.ui.fonts")

---@class ExtractionProgressBar
---@field isVisible boolean
---@field progress number
---@field duration number
---@field text string
---@field x number
---@field y number
---@field width number
---@field height number
---@field font love.Font
---@field subFont love.Font
---@field colors { background: { r: number, g: number, b: number, a: number }, fill: { r: number, g: number, b: number, a: number }, border: { r: number, g: number, b: number, a: number }, text: { r: number, g: number, b: number, a: number }, timerText: { r: number, g: number, b: number, a: number }, progressBarBase: { r: number, g: number, b: number, a: number } }
---@field padding { vertical: number, horizontal: number }
---@field internalLayout { mainText: string, mainTextHeight: number, timerText: string, timerTextWidth: number, timerTextHeight: number, mainTextX: number, mainTextY: number, timerTextX: number, timerTextY: number, fillBarHeight: number, emptyBarHeight: number, progressBarY: number, progressBarX: number, progressBarW: number, totalHeight: number }
local ExtractionProgressBar = {}
ExtractionProgressBar.__index = ExtractionProgressBar

---@param config { w: number, h: number }
---@return ExtractionProgressBar
function ExtractionProgressBar:new(config)
    local instance = setmetatable({}, ExtractionProgressBar)

    instance.width = config.w or 400
    instance.x = ResolutionUtils.getGameWidth() / 2 - instance.width / 2
    instance.y = ResolutionUtils.getGameHeight() - (config.h or 60) - 100 -- Positioned at the bottom-center

    instance.isVisible = false
    instance.progress = 0
    instance.duration = 0
    instance.text = ""
    instance.font = fonts.main_large or love.graphics.getFont()
    instance.subFont = fonts.main or love.graphics.getFont()

    instance.colors = {
        background = { 0, 0, 0, 150 },
        fill = { 50, 205, 50, 255 }, -- Green
        border = { 200, 200, 200, 255 },
        text = { 255, 255, 255, 255 },
        timerText = { 200, 200, 200, 255 },
        progressBarBase = { 50, 205, 50, 255 }, -- Green
    }

    instance.padding = { vertical = 8, horizontal = 12 }
    instance.internalLayout = {}
    instance:_updateLayout()
    instance.height = instance.internalLayout.totalHeight

    return instance
end

function ExtractionProgressBar:_updateLayout()
    local layout = self.internalLayout
    local contentX = self.x + self.padding.horizontal
    local contentY = self.y + self.padding.vertical
    local contentWidth = self.width - (self.padding.horizontal * 2)
    local lineSpacing = 5

    -- Text line
    love.graphics.setFont(self.font)
    layout.mainText = self.text
    layout.mainTextHeight = self.font:getHeight()

    love.graphics.setFont(self.subFont)
    local timeLeft = math.max(0, self.duration - self.progress)
    layout.timerText = string.format("%.1fs", timeLeft)
    layout.timerTextWidth = self.subFont:getWidth(layout.timerText)
    layout.timerTextHeight = self.subFont:getHeight()

    local textLineHeight = math.max(layout.mainTextHeight, layout.timerTextHeight)

    layout.mainTextX = contentX
    layout.mainTextY = contentY + (textLineHeight - layout.mainTextHeight) / 2

    layout.timerTextX = contentX + contentWidth - layout.timerTextWidth
    layout.timerTextY = contentY + (textLineHeight - layout.timerTextHeight) / 2

    -- Progress bar line
    layout.fillBarHeight = 10
    layout.emptyBarHeight = layout.fillBarHeight * 0.2
    layout.progressBarY = contentY + textLineHeight + lineSpacing
    layout.progressBarX = contentX
    layout.progressBarW = contentWidth

    layout.totalHeight = (layout.progressBarY - self.y) + layout.fillBarHeight + self.padding.vertical
end

---@param duration number
---@param text? string
function ExtractionProgressBar:start(duration, text)
    self.duration = duration
    self.text = text or "Extraindo..."
    self.progress = 0
    self.isVisible = true
    self:_updateLayout()
end

function ExtractionProgressBar:stop()
    self.isVisible = false
    self.progress = 0
end

function ExtractionProgressBar:isFinished()
    return self.progress >= self.duration
end

---@param dt number
function ExtractionProgressBar:update(dt)
    if not self.isVisible then return end

    self.progress = self.progress + dt
    self:_updateLayout() -- Update layout every frame to update timer text

    if self:isFinished() then
        -- The manager that started it is responsible for stopping it
    end
end

function ExtractionProgressBar:draw()
    if not self.isVisible then return end

    local layout = self.internalLayout

    -- Draw background
    local r, g, b, a = unpack(self.colors.background)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    -- Draw Texts
    love.graphics.setFont(self.font)
    r, g, b, a = unpack(self.colors.text)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.print(layout.mainText, layout.mainTextX, layout.mainTextY)

    love.graphics.setFont(self.subFont)
    r, g, b, a = unpack(self.colors.timerText)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.print(layout.timerText, layout.timerTextX, layout.timerTextY)

    -- Draw Progress Bar
    local fillAmount = self.progress / self.duration
    fillAmount = math.min(1, math.max(0, fillAmount))
    local fillWidth = layout.progressBarW * fillAmount

    -- Draw base (empty part)
    r, g, b, a = unpack(self.colors.progressBarBase)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    local emptyPartY = layout.progressBarY + (layout.fillBarHeight - layout.emptyBarHeight)
    love.graphics.rectangle("fill", layout.progressBarX, emptyPartY, layout.progressBarW, layout.emptyBarHeight)

    -- Draw fill
    if fillWidth > 0 then
        r, g, b, a = unpack(self.colors.fill)
        love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
        love.graphics.rectangle("fill", layout.progressBarX, layout.progressBarY, fillWidth, layout.fillBarHeight)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return ExtractionProgressBar
