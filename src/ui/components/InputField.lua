local utf8 = require("utf8")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

---@class InputField
---@field rect table
---@field font love.Font
---@field text string
---@field placeholder string
---@field isActive boolean
---@field isHovering boolean
---@field cursorBlinkTimer number
---@field isCursorVisible boolean
---@field onEnter function
local InputField = {}
InputField.__index = InputField

function InputField:new(config)
    local instance = setmetatable({}, InputField)
    instance.rect = config.rect or { x = 0, y = 0, w = 200, h = 40 }
    instance.font = config.font or fonts.main
    instance.text = config.text or ""
    instance.placeholder = config.placeholder or ""
    instance.isActive = config.isActive or false
    instance.isHovering = false

    instance.cursorBlinkTimer = 0
    instance.isCursorVisible = false
    instance.onEnter = config.onEnter -- Callback for when Enter is pressed

    return instance
end

function InputField:setText(text)
    self.text = text or ""
end

function InputField:getText()
    return self.text
end

function InputField:update(dt)
    if self.isActive then
        self.cursorBlinkTimer = self.cursorBlinkTimer + dt
        if self.cursorBlinkTimer > 0.5 then
            self.cursorBlinkTimer = 0
            self.isCursorVisible = not self.isCursorVisible
        end
    else
        self.isCursorVisible = false
    end
end

function InputField:draw()
    -- Borda (agora apenas uma linha inferior)
    if self.isActive then
        love.graphics.setColor(colors.border_active)
    else
        love.graphics.setColor(colors.window_border)
    end
    love.graphics.setLineWidth(2)
    local lineY = self.rect.y + self.rect.h
    love.graphics.line(self.rect.x, lineY, self.rect.x + self.rect.w, lineY)
    love.graphics.setLineWidth(1)

    -- Prepara para desenhar o texto
    love.graphics.setFont(self.font)
    local textY = self.rect.y + (self.rect.h - self.font:getHeight()) / 2

    -- Desenha o placeholder ou o texto
    if #self.text == 0 and not self.isActive then
        love.graphics.setColor(colors.text_muted)
        love.graphics.printf(self.placeholder, self.rect.x, textY, self.rect.w, "center")
    else
        love.graphics.setColor(colors.text_main)
        love.graphics.printf(self.text, self.rect.x, textY, self.rect.w, "center")
    end

    -- Desenha o cursor
    if self.isActive and self.isCursorVisible then
        local textWidth = self.font:getWidth(self.text)
        local textStartX = self.rect.x + (self.rect.w - textWidth) / 2
        local cursorX = textStartX + textWidth
        love.graphics.setColor(colors.text_main)
        local cursorY1 = self.rect.y + (self.rect.h * 0.15)
        local cursorY2 = self.rect.y + (self.rect.h * 0.85)
        love.graphics.line(cursorX, cursorY1, cursorX, cursorY2)
    end
end

function InputField:keypressed(key)
    if not self.isActive then return end

    if key == "backspace" then
        local byteoffset = utf8.offset(self.text, -1)
        if byteoffset then
            self.text = string.sub(self.text, 1, byteoffset - 1)
        end
    elseif key == "return" or key == "kpenter" then
        if self.onEnter then
            self.onEnter(self.text)
        end
    end
end

function InputField:textinput(t)
    if not self.isActive then return end

    local textMaxWidth = self.rect.w - 10 -- Deixa uma pequena margem
    local currentWidth = self.font:getWidth(self.text)
    local charWidth = self.font:getWidth(t)

    if currentWidth + charWidth < textMaxWidth then
        self.text = self.text .. t
    end
end

function InputField:mousepressed(x, y, button)
    if button == 1 then
        if x > self.rect.x and x < self.rect.x + self.rect.w and y > self.rect.y and y < self.rect.y + self.rect.h then
            self.isActive = true
        else
            self.isActive = false
        end
    end
end

return InputField
