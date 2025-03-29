--[[
    Player State
    Manages player's current state and status
]]

local PlayerState = {
    currentHealth = 0,
    maxHealth = 0,
    isAlive = true
}

--[[
    Initialize player state
    @param maxHealth Maximum health value
]]
function PlayerState:init(maxHealth)
    self.currentHealth = maxHealth
    self.maxHealth = maxHealth
    self.isAlive = true
end

--[[
    Take damage
    @param damage Amount of damage to take
    @param defense Player's defense value
    @return boolean Whether the player died from this damage
]]
function PlayerState:takeDamage(damage, defense)
    if not self.isAlive then return false end
    
    local actualDamage = math.max(1, damage - defense)
    self.currentHealth = math.max(0, self.currentHealth - actualDamage)
    
    if self.currentHealth <= 0 then
        self.isAlive = false
        return true
    end
    
    return false
end

--[[
    Heal player
    @param amount Amount of health to restore
]]
function PlayerState:heal(amount)
    if not self.isAlive then return end
    self.currentHealth = math.min(self.currentHealth + amount, self.maxHealth)
end

--[[
    Get current health percentage
    @return number Health percentage (0 to 1)
]]
function PlayerState:getHealthPercentage()
    return self.currentHealth / self.maxHealth
end

--[[
    Increase max health
    @param amount Amount of health to increase
]]
function PlayerState:increaseMaxHealth(amount)
    self.maxHealth = self.maxHealth + amount
    self.currentHealth = math.min(self.currentHealth, self.maxHealth)
end

return PlayerState 