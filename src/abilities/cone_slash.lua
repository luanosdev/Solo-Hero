--[[
    Cone Slash Ability
    A cone-shaped area of effect attack that serves as the character's primary attack method
]]

local BaseAbility = require("src.abilities.base_ability")

local ConeSlash = setmetatable({}, { __index = BaseAbility })

ConeSlash.name = "Cone Slash"
ConeSlash.cooldown = 1.0
ConeSlash.damage = 30
ConeSlash.damageType = "physical"
ConeSlash.color = {1, 1, 1, 0.1}

ConeSlash.coneAngle = math.pi / 3
ConeSlash.range = 100

-- Animação de ataque
ConeSlash.slash = {
    active = false,
    duration = 0.3,
    time = 0,
    color = {1, 1, 1, 0.8}
}

function ConeSlash:init(owner)
    BaseAbility.init(self, owner)
end

--[[
    Update the ability state
    @param dt Delta time
]]
function ConeSlash:update(dt)
    BaseAbility.update(self, dt)

    -- Update slash animation
    if self.slash.active then
        self.slash.time = self.slash.time + dt
        if self.slash.time >= self.slash.duration then
            self.slash.active = false
        end
    end
end

--[[
    Draw the ability visual
]]
function ConeSlash:draw()
    -- Draw preview cone if active
    if self.visual.active then
        love.graphics.setColor(self.color)
        love.graphics.arc("fill", 
            self.owner.positionX, 
            self.owner.positionY, 
            self.range,
            self.visual.angle - self.coneAngle/2,
            self.visual.angle + self.coneAngle/2
        )
    end
    
    -- Draw slash animation if active
    if self.slash.active then
        local progress = self.slash.time / self.slash.duration
        local alpha = 1 - progress  -- Fade out over time
        
        -- Draw the slash cone
        love.graphics.setColor(self.slash.color[1], self.slash.color[2], self.slash.color[3], self.slash.color[4] * alpha)
        love.graphics.arc("fill", 
            self.owner.positionX, 
            self.owner.positionY, 
            self.range,
            self.visual.angle - self.coneAngle/2,
            self.visual.angle + self.coneAngle/2
        )
    end
end

--[[
    Check if a point is inside the cone
    @param x Point X position
    @param y Point Y position
    @return boolean Whether the point is inside the cone
]]
function ConeSlash:isPointInArea(x, y)
    -- Calculate distance to point
    local dx = x - self.owner.positionX
    local dy = y - self.owner.positionY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Check if point is within range
    if distance > self.range then return false end
    
    -- Calculate angle to point
    local pointAngle = math.atan2(dy, dx)
    
    -- Normalize angles to 0-2π range
    local normalizedPointAngle = pointAngle
    if normalizedPointAngle < 0 then
        normalizedPointAngle = normalizedPointAngle + 2 * math.pi
    end
    
    local normalizedConeAngle = self.visual.angle
    if normalizedConeAngle < 0 then
        normalizedConeAngle = normalizedConeAngle + 2 * math.pi
    end
    
    -- Calculate angle difference
    local angleDiff = math.abs(normalizedPointAngle - normalizedConeAngle)
    if angleDiff > math.pi then
        angleDiff = 2 * math.pi - angleDiff
    end
    
    -- Check if point is within cone angle
    return angleDiff <= self.coneAngle / 2
end

--[[
    Cast the ability
    @param x Target X position
    @param y Target Y position
    @return boolean Whether the ability was cast successfully
]]
function ConeSlash:cast(x, y)
    if self.cooldownRemaining > 0 then return false end
    
    -- Calculate angle to target
    local worldX = (x + camera.x) / camera.scale
    local worldY = (y + camera.y) / camera.scale
    local dx = worldX - self.owner.positionX
    local dy = worldY - self.owner.positionY
    local angle = math.atan2(dy, dx)
    
    -- Update visual angle
    self.visual.angle = angle
    
    -- Start slash animation
    self.slash.active = true
    self.slash.time = 0
    
    -- Set cooldown
    self.cooldownRemaining = self.cooldown
    
    return true
end

--[[
    Toggle ability visual
]]
function ConeSlash:toggleVisual()
    self.visual.active = not self.visual.active
end

--[[
    Get remaining cooldown
    @return number Remaining cooldown time
]]
function ConeSlash:getCooldownRemaining()
    return self.cooldownRemaining
end

return ConeSlash