local AssetManager = require("src.managers.asset_manager")
local Camera = require("src.config.camera")

---@class OffscreenIndicator
---@field targetId string
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
local OffscreenIndicator = {}
OffscreenIndicator.__index = OffscreenIndicator

function OffscreenIndicator:new(config)
    local instance = setmetatable({}, OffscreenIndicator)

    instance.targetId = config.targetId -- e.g., portal instance id
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
    instance.padding = 50 -- Distance from the edge of the screen

    return instance
end

---@param targetWorldPos { x: number, y: number }
function OffscreenIndicator:update(targetWorldPos)
    local screenX, screenY = Camera:worldToScreen(targetWorldPos.x, targetWorldPos.y)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Check if target is on-screen
    if screenX > 0 and screenX < screenW and screenY > 0 and screenY < screenH then
        self.isVisible = false
        return
    end

    self.isVisible = true

    -- Calculate angle from center of screen to target
    local centerX = screenW / 2
    local centerY = screenH / 2
    local angle = math.atan2(screenY - centerY, screenX - centerX)
    self.rotation = angle

    -- Clamp position to screen edges with padding
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

    love.graphics.draw(
        self.image,
        self.screenX,
        self.screenY,
        self.rotation,
        self.scale,
        self.scale,
        self.ox,
        self.oy
    )
end

return OffscreenIndicator
