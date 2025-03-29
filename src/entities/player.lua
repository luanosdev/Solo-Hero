--[[
    Player entity
    Handles player movement and properties
]]

local PlayerState = require("src.entities.player_state")
local Warrior = require("src.classes.warrior")

local Player = {
    -- Position
    positionX = 200,
    positionY = 150,
    
    -- Movement
    currentSpeed = 0,
    radius = 10,
    
    -- Class
    class = nil,
    
    -- Base Stats (will be set by class)
    maxHealth = 0,
    damage = 0,
    defense = 0,
    baseSpeed = 0,
    attackSpeed = 0,
    
    -- State
    state = nil,
    
    -- Abilities
    attackAbility = nil,
    
    -- Auto Attack
    autoAttack = false
}

--[[
    Initialize player with a class
    @param playerClass Class to initialize the player with
]]
function Player:init(playerClass)
    -- Set class and base stats
    self.class = playerClass
    local baseStats = self.class:getBaseStats()
    
    -- Apply base stats
    self.maxHealth = baseStats.health
    self.damage = baseStats.damage
    self.defense = baseStats.defense
    self.baseSpeed = baseStats.speed
    self.attackSpeed = baseStats.attackSpeed
    
    -- Initialize ability
    local AbilityClass = self.class:getInitialAbility()
    self.attackAbility = AbilityClass
    self.attackAbility:init(self)
    
    -- Initialize state
    self.state = PlayerState
    self.state:init(self.maxHealth)
end

--[[
    Update player movement and speed
    @param dt Delta time (time between frames)
]]
function Player:update(dt)
    if not self.state.isAlive then return end
    
    -- Update ability
    self.attackAbility:update(dt)
    
    -- Auto Attack logic
    if self.autoAttack then
        local cooldown = self.attackAbility:getCooldownRemaining()
        if cooldown <= 0 then
            -- Get mouse position for attack direction
            local mouseX, mouseY = love.mouse.getPosition()
            self:castAbility(mouseX, mouseY)
        end
    end
    
    -- Movement vectors
    local moveX, moveY = 0, 0
    
    -- WASD movement control
    if love.keyboard.isDown("w") then
        moveY = moveY - 1
    end
    if love.keyboard.isDown("s") then
        moveY = moveY + 1
    end
    if love.keyboard.isDown("a") then
        moveX = moveX - 1
    end
    if love.keyboard.isDown("d") then
        moveX = moveX + 1
    end
    
    -- Normalize diagonal movement to maintain consistent speed
    if moveX ~= 0 and moveY ~= 0 then
        local vectorLength = math.sqrt(moveX * moveX + moveY * moveY)
        moveX = moveX / vectorLength
        moveY = moveY / vectorLength
    end
    
    -- Update player position
    self.positionX = self.positionX + moveX * self.baseSpeed * dt
    self.positionY = self.positionY + moveY * self.baseSpeed * dt
    
    -- Calculate current player speed
    self.currentSpeed = math.sqrt(moveX * moveX + moveY * moveY) * self.baseSpeed
end

--[[
    Draw the player on screen
]]
function Player:draw()
    -- Draw ability visual
    self.attackAbility:draw()
    
    -- Draw player body
    love.graphics.setColor(0.918, 0.059, 0.573)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius)
    
    -- Draw health bar
    local baseWidth = 40
    local maxWidth = 60
    local healthBarHeight = 5
    local healthPercentage = self.state:getHealthPercentage()
    
    -- Calculate dynamic width based on max health
    local healthBarWidth = baseWidth + (maxWidth - baseWidth) * (self.state.maxHealth / 200)
    
    -- Health bar background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 10,
        healthBarWidth, 
        healthBarHeight
    )
    
    -- Health bar fill
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 10,
        healthBarWidth * healthPercentage, 
        healthBarHeight
    )
    
    -- Draw health bar segments
    love.graphics.setColor(0, 0, 0, 0.3)
    local segmentCount = 5
    local segmentWidth = healthBarWidth / segmentCount
    
    for i = 1, segmentCount - 1 do
        local x = self.positionX - healthBarWidth/2 + segmentWidth * i
        love.graphics.line(
            x,
            self.positionY - self.radius - 10,
            x,
            self.positionY - self.radius - 5
        )
    end
    
    -- Draw health bar border
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("line", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 10,
        healthBarWidth, 
        healthBarHeight
    )
    
    -- Draw cooldown bar
    local cooldown = self.attackAbility:getCooldownRemaining()
    if cooldown > 0 then
        local cooldownPercentage = cooldown / self.attackAbility.cooldown
        
        -- Cooldown bar background
        love.graphics.setColor(0.2, 0, 0, 0.3)
        love.graphics.rectangle("fill", 
            self.positionX - healthBarWidth/2, 
            self.positionY - self.radius - 5,
            healthBarWidth, 
            2
        )
        
        -- Cooldown bar fill
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.rectangle("fill", 
            self.positionX - healthBarWidth/2, 
            self.positionY - self.radius - 5,
            healthBarWidth * cooldownPercentage, 
            2
        )
    end
    
    -- Draw class name
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.class.name, 
        self.positionX - 20, 
        self.positionY - self.radius - 25, 
        0, 0.8)
end

--[[
    Take damage
    @param damage Amount of damage to take
    @return boolean Whether the player died from this damage
]]
function Player:takeDamage(damage)
    return self.state:takeDamage(damage, self.defense)
end

--[[
    Heal player
    @param amount Amount of health to restore
]]
function Player:heal(amount)
    self.state:heal(amount)
end

--[[
    Increase max health
    @param amount Amount of health to increase
]]
function Player:increaseMaxHealth(amount)
    self.state:increaseMaxHealth(amount)
end

--[[
    Cast ability
    @param x Mouse X position
    @param y Mouse Y position
    @return boolean Whether the ability was cast successfully
]]
function Player:castAbility(x, y)
    return self.attackAbility:cast(x, y)
end

--[[
    Toggle ability auto-cast
]]
function Player:toggleAbilityAutoCast()
    self.autoAttack = not self.autoAttack
end

--[[
    Toggle ability visual
]]
function Player:toggleAbilityVisual()
    self.attackAbility:toggleVisual()
end

--[[
    Handle key press
    @param key Key that was pressed
]]
function Player:keypressed(key)
    -- Test functions
    if key == "h" then
        self:heal(20)  -- Heal 20 HP when pressing H
    elseif key == "q" then
        self:increaseMaxHealth(10) -- Increase max health by 10
    elseif key == "g" then
        self:takeDamage(30)  -- Take 30 damage when pressing D
    elseif key == "x" then
        self:toggleAbilityAutoCast() -- Toggle ability auto-cast
    elseif key == "v" then
        self:toggleAbilityVisual() -- Toggle ability visual
    end
end

--[[
    Handle mouse press
    @param x Mouse X position
    @param y Mouse Y position
    @param button Mouse button pressed
]]
function Player:mousepressed(x, y, button)
    if button == 1 then -- Left click
        self:castAbility(x, y)
    end
end

return Player