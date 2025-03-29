--[[
    Cone Slash Ability
    A cone-shaped area of effect attack that serves as the character's primary attack method
]]

local ConeSlash = {
    -- Ability Properties
    name = "Cone Slash",
    cooldown = 3.0,  -- Base cooldown in seconds
    damage = 30,     -- Base damage
    coneAngle = math.pi / 3,  -- 60 degrees in radians
    range = 100,     -- Range in pixels
    color = {1, 1, 1, 0.1},  -- Orange with transparency
    
    -- Visual State
    visual = {
        active = false,
        angle = 0,
        targetAngle = 0,
        rotationSpeed = 60  -- Velocidade de rotação (ajuste conforme necessário)
    },
    
    -- Slash Animation
    slash = {
        active = false,
        duration = 0.3,  -- Duration in seconds
        time = 0,
        color = {1, 1, 1, 0.8}  -- White with high opacity
    }
}

--[[
    Initialize the ability
    @param owner The entity that owns this ability
]]
function ConeSlash:init(owner)
    self.owner = owner
    self.cooldownRemaining = 0
end

--[[
    Update the ability state
    @param dt Delta time
]]
function ConeSlash:update(dt)
    -- Update cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = math.max(0, self.cooldownRemaining - dt * self.owner.attackSpeed)
    end
    
    -- Update target angle to follow mouse
    local mouseX, mouseY = love.mouse.getPosition()
    -- Converte a posição do mouse para coordenadas do mundo
    local worldX = (mouseX + camera.x) / camera.scale
    local worldY = (mouseY + camera.y) / camera.scale
    local dx = worldX - self.owner.positionX
    local dy = worldY - self.owner.positionY
    
    -- Tratamento especial para alinhamentos exatos
    if math.abs(dx) < 0.1 then  -- Mouse alinhado verticalmente
        self.visual.angle = dy > 0 and math.pi/2 or -math.pi/2
    elseif math.abs(dy) < 0.1 then  -- Mouse alinhado horizontalmente
        self.visual.angle = dx > 0 and 0 or math.pi
    else
        -- Caso normal, calcula o ângulo usando math.atan
        self.visual.angle = math.atan(dy/dx)
        if dx < 0 then
            self.visual.angle = self.visual.angle + math.pi
        end
    end
    
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
    local angle = math.atan(dy/dx)
    if dx < 0 then
        angle = angle + math.pi
    end
    
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