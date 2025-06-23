local AssetManager = require("src.managers.asset_manager")
local TablePool = require("src.utils.table_pool")
local RenderPipeline = require("src.core.render_pipeline")

---@class TeleportEffect
---@field position { x: number, y: number }
---@field image love.Image
---@field width number
---@field height number
---@field grid { columns: number, rows: number }
---@field frameWidth number
---@field frameHeight number
---@field quads table
---@field animTimer number
---@field frameDuration number
---@field currentFrame number
---@field isFinished boolean
local TeleportEffect = {}
TeleportEffect.__index = TeleportEffect

---@param config { x: number, y: number }
function TeleportEffect:new(config)
    local instance = setmetatable({}, TeleportEffect)
    local currentPortalHeight = 252
    instance.position = { x = config.x, y = config.y - currentPortalHeight / 2 }

    local image = AssetManager:getImage("assets/effects/teleporter-effect.png")
    if not image then
        error("TeleportEffect image not found")
    end

    instance.image = image
    instance.width = instance.image:getWidth()
    instance.height = instance.image:getHeight()

    instance.grid = { columns = 10, rows = 10 }
    instance.frameWidth = instance.width / instance.grid.columns
    instance.frameHeight = instance.height / instance.grid.rows

    instance.quads = {}
    for r = 0, instance.grid.rows - 1 do
        for c = 0, instance.grid.columns - 1 do
            local quad = love.graphics.newQuad(c * instance.frameWidth, r * instance.frameHeight, instance.frameWidth,
                instance.frameHeight, instance.width, instance.height)
            table.insert(instance.quads, quad)
        end
    end

    instance.animTimer = 0
    instance.frameDuration = 0.03
    instance.currentFrame = 1
    instance.isFinished = false

    return instance
end

function TeleportEffect:update(dt)
    if self.isFinished then return end

    self.animTimer = self.animTimer + dt
    if self.animTimer >= self.frameDuration then
        self.animTimer = self.animTimer - self.frameDuration
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > #self.quads then
            self.isFinished = true
        end
    end
end

function TeleportEffect:collectRenderables(renderPipeline)
    if self.isFinished then return end

    local item = TablePool.get()
    item.depth = RenderPipeline.DEPTH_EFFECTS_WORLD_UI
    item.type = "teleport_effect"
    item.sortY = self.position.y + 200 -- Draw on top
    item.drawFunction = function() self:draw() end
    renderPipeline:add(item)
end

function TeleportEffect:draw()
    if self.isFinished then return end

    love.graphics.setColor(1, 1, 1, 1)
    local quad = self.quads[self.currentFrame]
    local drawX = self.position.x - (self.frameWidth / 2)
    local drawY = self.position.y - (self.frameHeight / 2)
    love.graphics.draw(self.image, quad, drawX, drawY)
end

return TeleportEffect
