local AssetManager = require("src.managers.asset_manager")
local RenderPipeline = require("src.core.render_pipeline")

---@class ExtractionPortal
---@field position { x: number, y: number }
---@field image love.Image
---@field width number
---@field height number
---@field quads table
---@field animTimer number
---@field currentFrame number
---@field state "idle" | "activating" | "activated"
---@field activationTimer number
---@field activationDuration number
local ExtractionPortal = {}
ExtractionPortal.__index = ExtractionPortal

---@param x number
---@param y number
---@return ExtractionPortal
function ExtractionPortal:new(x, y)
    local instance = setmetatable({}, ExtractionPortal)
    instance.position = { x = x, y = y }

    local image = AssetManager:getImage("assets/tilesets/entities/teleport.png")

    if not image then
        error("ExtractionPortal image not found")
    end

    instance.image = image
    instance.width = instance.image:getWidth()
    instance.height = instance.image:getHeight()
    instance.quads = {}
    local frameHeight = instance.height / 5
    for i = 0, 4 do
        instance.quads[i + 1] = love.graphics.newQuad(
            0,
            i * frameHeight,
            instance.width,
            frameHeight,
            instance.width,
            instance.height
        )
    end

    instance.animTimer = 0
    instance.currentFrame = 1        -- Start with the "off" frame
    instance.state = "idle"          -- can be 'idle', 'activating', 'activated'
    instance.activationTimer = 0
    instance.activationDuration = 10 -- seconds

    return instance
end

---@param dt number Delta time.
function ExtractionPortal:update(dt)
    if self.state == "activating" or self.state == "activated" then
        self.animTimer = self.animTimer + dt
        if self.animTimer > 0.15 then -- animation speed
            self.animTimer = 0
            -- frames 2 to 5 are the animation
            self.currentFrame = self.currentFrame + 1
            if self.currentFrame > 5 then
                self.currentFrame = 2
            end
        end
    else
        self.currentFrame = 1 -- idle is frame 1
    end
end

function ExtractionPortal:startActivation()
    if self.state == "idle" then
        self.state = "activating"
        self.activationTimer = 0
        self.currentFrame = 2 -- start animation
    end
end

function ExtractionPortal:stopActivation()
    if self.state == "activating" then
        self.state = "idle"
        self.activationTimer = 0
    end
end

---@param renderPipeline RenderPipeline
function ExtractionPortal:collectRenderables(renderPipeline)
    local ySort = self.position.y
    local item = {
        depth = RenderPipeline.DEPTH_DROPS,
        type = "extraction_portal",
        sortY = ySort,
        drawFunction = function() self:draw() end
    }
    renderPipeline:add(item)
end

function ExtractionPortal:draw()
    love.graphics.draw(
        self.image,
        self.quads[self.currentFrame],
        self.position.x - self.width / 2,
        self.position.y - self.height / 5 / 2
    )
end

return ExtractionPortal
