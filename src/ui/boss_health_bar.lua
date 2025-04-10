local elements = require("src.ui.ui_elements")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")

local BossHealthBar = {
    visible = false,
    boss = nil,
    width = 400,
    height = 10,
    padding = 10,
    yOffset = 120
}

function BossHealthBar:init()
    self.visible = false
    self.boss = nil

    local screenW = love.graphics.getWidth()
    self.width = screenW * 0.6
end

function BossHealthBar:show(boss)
    self.visible = true
    self.boss = boss
end

function BossHealthBar:hide()
    self.visible = false
    self.boss = nil
end

function BossHealthBar:draw()
    if not self.visible or not self.boss then return end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local x = (screenW - self.width) / 2
    local y = self.yOffset

    -- Desenha a barra de vida usando drawResourceBar
    elements.drawResourceBar(
        x,
        y,
        self.width,
        self.height,
        self.boss.currentHealth,
        self.boss.maxHealth,
        self.boss.color,
        colors.bar_bg,
        colors.bar_border
    )

    -- Desenha o nome do boss e nível de poder
    love.graphics.setFont(fonts.details_title)
    -- Cor do nome do boss de acordo com o nível de poder
    local powerLevel = self.boss.powerLevel
    local textColor = colors.enemyPowerColors[powerLevel] or colors.text_main
    -- exibe o nome do boss com sombra
    local textWidth = fonts.details_title:getWidth(self.boss.name)
    local textX = x + (self.width - textWidth) / 2
    local textY = y - 30
    
    -- Desenha a sombra do texto
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(self.boss.name, textX + 2, textY + 2)
    
    -- Desenha o texto principal
    love.graphics.setColor(textColor[1], textColor[2], textColor[3], textColor[4] or 1)
    love.graphics.print(self.boss.name, textX, textY)
end

return BossHealthBar 