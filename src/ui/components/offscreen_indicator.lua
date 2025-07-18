local AssetManager = require("src.managers.asset_manager")
local ResolutionUtils = require("src.utils.resolution_utils")
local Fonts = require("src.ui.fonts")
local Constants = require("src.config.constants")

---@class OffscreenIndicator
---@field targetId any
---@field image love.Image
---@field width number
---@field height number
---@field ox number
---@field oy number
---@field scale number
---@field isVisible boolean
---@field screenX number
---@field screenY number
---@field rotation number
---@field padding number
---@field distance number
---@field color Color
local OffscreenIndicator = {}
OffscreenIndicator.__index = OffscreenIndicator

function OffscreenIndicator:new(config)
    local instance = setmetatable({}, OffscreenIndicator)

    instance.targetId = config.targetId
    instance.color = config.color or { 1, 1, 1, 0.5 } -- Branco semi-transparente como padrão
    local image = AssetManager:getImage("assets/images/arrow.png")
    if not image then
        error("OffscreenIndicator arrow asset not found!")
    end

    instance.image = image
    instance.width = instance.image:getWidth()
    instance.height = instance.image:getHeight()
    instance.ox = instance.width / 2
    instance.oy = instance.height / 2
    instance.scale = 0.05

    instance.isVisible = false
    instance.screenX = 0
    instance.screenY = 0
    instance.rotation = 0
    instance.padding = 50 -- Distância da borda da tela
    instance.distance = 0

    return instance
end

---@param targetWorldPos { x: number, y: number }
---@param playerWorldPos { x: number, y: number }
function OffscreenIndicator:update(targetWorldPos, playerWorldPos)
    local dx = targetWorldPos.x - playerWorldPos.x
    local dy = targetWorldPos.y - playerWorldPos.y
    self.distance = math.sqrt(dx * dx + dy * dy)

    local screenW = ResolutionUtils.getGameWidth()
    local screenH = ResolutionUtils.getGameHeight()
    local screenCenterX = screenW / 2
    local screenCenterY = screenH / 2

    -- Converte a posição de mundo do alvo para a tela, relativo ao jogador
    local screenX = targetWorldPos.x - playerWorldPos.x + screenCenterX
    local screenY = targetWorldPos.y - playerWorldPos.y + screenCenterY

    -- Verifica se o alvo está na tela (com uma margem)
    if screenX > self.padding and screenX < screenW - self.padding and screenY > self.padding and screenY < screenH - self.padding then
        self.isVisible = false
        return
    end

    self.isVisible = true

    -- Calcula o ângulo do centro da tela para o alvo
    local centerX = screenW / 2
    local centerY = screenH / 2
    local angle = math.atan2(screenY - centerY, screenX - centerX)
    self.rotation = angle

    -- Prende a posição nas bordas da tela com o preenchimento
    local cosAngle = math.cos(angle)
    local sinAngle = math.sin(angle)

    local m = sinAngle / cosAngle
    local w, h = screenW / 2 - self.padding, screenH / 2 - self.padding

    if cosAngle > 0 then
        self.screenX = w
    else
        self.screenX = -w
    end
    self.screenY = m * self.screenX

    if self.screenY > h then
        self.screenY = h
        self.screenX = self.screenY / m
    elseif self.screenY < -h then
        self.screenY = -h
        self.screenX = self.screenY / m
    end

    self.screenX = self.screenX + centerX
    self.screenY = self.screenY + centerY
end

function OffscreenIndicator:draw()
    if not self.isVisible then return end

    -- Desenha o círculo colorido de fundo
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.screenX, self.screenY, 10)

    -- Adiciona um brilho ao círculo
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.5)
    love.graphics.circle("fill", self.screenX, self.screenY, 14)

    -- Desenha o texto da distância
    love.graphics.setColor(1, 1, 1, 1)
    local font = Fonts.main_small
    love.graphics.setFont(font)
    local distanceText = string.format("%dm", Constants.pixelsToMeters(self.distance))
    local textWidth = font:getWidth(distanceText)

    -- Desenha o texto abaixo do indicador com uma pequena sombra para legibilidade
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(distanceText, self.screenX - textWidth / 2 + 1, self.screenY + 16)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(distanceText, self.screenX - textWidth / 2, self.screenY + 15)
end

return OffscreenIndicator
