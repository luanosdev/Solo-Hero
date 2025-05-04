--[[
    Drop Entity
    Representa um item dropado no mundo que pode ser coletado pelo jogador
]]

local runeAnimation = require("src.animations.rune_animation")

local DropEntity = {
    position = {
        x = 0,
        y = 0
    },
    initialPosition = {
        x = 0,
        y = 0
    },
    radius = 10,
    config = nil,
    collected = false,
    collectionProgress = 0,
    collectionSpeed = 3,
    initialY = 0,
    beamColor = { 1, 1, 1 },
    beamHeight = 50,
    glowScale = 1.0,
    glowEffect = true,
    glowTimer = 0,
    animation = nil
}

function DropEntity:new(position, config, beamColor, beamHeight, glowScale)
    local drop = setmetatable({}, { __index = self })
    drop.initialPosition = { x = position.x, y = position.y }
    drop.position = { x = position.x, y = position.y }
    drop.config = config
    drop.collected = false
    drop.collectionProgress = 0
    drop.glowTimer = love.math.random() * 10

    drop.beamColor = beamColor or { 1, 1, 1 }
    drop.beamHeight = beamHeight or 50
    drop.glowScale = glowScale or 1.0

    if config.type == "rune" then
        drop.animation = runeAnimation
    end

    return drop
end

function DropEntity:update(dt, playerManager)
    if self.collected then return true end

    self.glowTimer = self.glowTimer + dt

    if self.animation then
        self.animation:update(dt)
    end

    local dx = playerManager.player.position.x - self.position.x
    local dy = playerManager.player.position.y - self.position.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance <= playerManager.collectionRadius then
        self.collectionProgress = self.collectionProgress + dt * self.collectionSpeed

        local t = math.min(self.collectionProgress, 1)
        local easeOutQuad = 1 - (1 - t) * (1 - t)

        self.position.x = self.initialPosition.x +
            (playerManager.player.position.x - self.initialPosition.x) * easeOutQuad
        self.position.y = self.initialPosition.y +
            (playerManager.player.position.y - self.initialPosition.y) * easeOutQuad

        if self.collectionProgress >= 1 then
            self.collected = true
            return true
        end
    end

    return false
end

function DropEntity:draw()
    if self.collected then return end

    local x, y = self.position.x, self.position.y
    local r, g, b = self.beamColor[1], self.beamColor[2], self.beamColor[3]
    local beamWidth = 4

    love.graphics.push()

    love.graphics.translate(x, y)
    love.graphics.scale(1, 0.5)

    local segments = 5
    local heightStep = self.beamHeight / segments
    local alphaBase = 0.8
    local alphaStep = alphaBase / segments

    love.graphics.setLineWidth(beamWidth)
    for i = 0, segments - 1 do
        local startY = -(i * heightStep)
        local endY = -((i + 1) * heightStep)

        local startX = 0
        local endX = 0

        local currentAlpha = alphaBase - (i * alphaStep)
        love.graphics.setColor(r, g, b, currentAlpha)

        love.graphics.line(startX, startY, endX, endY)
    end
    love.graphics.setLineWidth(1)

    if self.glowEffect then
        local glowAlpha = (0.4 + math.sin(self.glowTimer * 2) * 0.2) * self.glowScale
        glowAlpha = math.max(0, math.min(1, glowAlpha))
        love.graphics.setColor(r, g, b, glowAlpha)
        love.graphics.circle("fill", 0, 0, self.radius * (1.5 + (self.glowScale - 1) * 0.5))
    end

    if self.animation then
        self.animation:draw(0, 0, self.config.rarity)
    else
        love.graphics.setColor(r, g, b, 1)
        love.graphics.circle("fill", 0, 0, self.radius)

        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.circle("fill", 0, 0, self.radius * 0.6)
    end

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
end

return DropEntity
