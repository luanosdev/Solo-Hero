local config = require("src.runes.orbital")

local animation = {
    frames = config.animation.frames,
    currentFrame = config.animation.currentFrame,
    timer = config.animation.timer,
    frameTimes = {} -- Tabela para armazenar o tempo de cada frame
}

-- Função de easing para criar uma curva suave
local function easeInOutQuad(t)
    return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2)^2 / 2
end

-- Calcula os tempos de frame com easing
local totalFrames = #animation.frames
local baseTime = config.animation.frameTime
for i = 1, totalFrames do
    -- Primeiros frames mais lentos, últimos frames mais rápidos
    local progress = (i - 1) / (totalFrames - 1)
    local easedProgress = easeInOutQuad(progress)
    animation.frameTimes[i] = baseTime * (1 + (1 - easedProgress) * 0.5) -- Primeiros frames 50% mais lentos
end

function animation:update(dt)
    self.timer = self.timer + dt
    local currentFrameTime = self.frameTimes[self.currentFrame]
    
    if self.timer >= currentFrameTime then
        self.timer = self.timer - currentFrameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #self.frames then
            self.currentFrame = 1
        end
    end
end

function animation:draw(x, y)
    love.graphics.setColor(config.color)
    love.graphics.draw(
        self.frames[self.currentFrame],
        x,
        y,
        0,
        config.animation.scale,
        config.animation.scale,
        config.animation.width/2,
        config.animation.height/2
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return animation 