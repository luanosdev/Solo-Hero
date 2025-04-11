--[[
    Player State
    Manages player's current state and status
]]

local PlayerState = {
    currentHealth = 0,
    maxHealth = 0,
    isAlive = true,
    
    -- Atributos base
    baseHealth = 0,
    baseDamage = 0,
    baseDefense = 0,
    baseSpeed = 0,
    baseAttackSpeed = 0,
    baseCriticalChance = 0,
    baseCriticalMultiplier = 0,
    baseHealthRegen = 0, -- Nova propriedade: regeneração de vida base
    
    -- Bônus por nível (em porcentagem)
    levelBonus = {
        health = 0,
        damage = 0,
        defense = 0,
        speed = 0,
        attackSpeed = 0,
        criticalChance = 0,
        criticalMultiplier = 0,
        healthRegen = 0 -- Novo bônus: regeneração de vida
    }
}

--[[
    Initialize player state
    @param baseStats Table containing base stats
]]
function PlayerState:init(baseStats)
    -- Inicializa atributos base
    self.baseHealth = baseStats.health
    self.baseDamage = baseStats.damage
    self.baseDefense = baseStats.defense
    self.baseSpeed = baseStats.speed
    self.baseAttackSpeed = baseStats.attackSpeed
    self.baseCriticalChance = baseStats.criticalChance or 20
    self.baseCriticalMultiplier = baseStats.criticalMultiplier or 1.5
    self.baseHealthRegen = baseStats.healthRegen or 0 -- Inicializa regeneração de vida base
    
    -- Inicializa bônus de nível
    self.levelBonus = {
        health = 0,
        damage = 0,
        defense = 0,
        speed = 0,
        attackSpeed = 0,
        criticalChance = 0,
        criticalMultiplier = 0,
        healthRegen = 0 -- Inicializa bônus de regeneração de vida
    }
    
    -- Inicializa vida atual e máxima
    self.maxHealth = self:getTotalHealth()
    self.currentHealth = self.maxHealth
    self.isAlive = true
end

--[[
    Get total health (base + bonus)
    @return number Total health
]]
function PlayerState:getTotalHealth()
    return self.baseHealth * (1 + self.levelBonus.health / 100)
end

--[[
    Get total damage (base + bonus)
    @return number Total damage
]]
function PlayerState:getTotalDamage()
    return math.floor(self.baseDamage * (1 + self.levelBonus.damage / 100))
end

--[[
    Get total defense (base + bonus)
    @return number Total defense
]]
function PlayerState:getTotalDefense()
    return math.floor(self.baseDefense * (1 + self.levelBonus.defense / 100))
end

--[[
    Get damage reduction percentage
    @return number Damage reduction percentage (0 to 0.8)
]]
function PlayerState:getDamageReduction()
    local defense = self:getTotalDefense()
    local K = 52
    local reduction = defense / (defense + K)
    return math.min(0.8, reduction) -- Limita a redução em 80%
end

--[[
    Get total speed (base + bonus)
    @return number Total speed
]]
function PlayerState:getTotalSpeed()
    return self.baseSpeed * (1 + self.levelBonus.speed / 100)
end

--[[
    Get total attack speed (base + bonus)
    @return number Total attack speed
]]
function PlayerState:getTotalAttackSpeed()
    return self.baseAttackSpeed * (1 + self.levelBonus.attackSpeed / 100)
end

--[[
    Get total critical chance (base + bonus)
    @return number Total critical chance
]]
function PlayerState:getTotalCriticalChance()
    return self.baseCriticalChance * (1 + self.levelBonus.criticalChance / 100)
end

--[[
    Get total critical multiplier (base + bonus)
    @return number Total critical multiplier
]]
function PlayerState:getTotalCriticalMultiplier()
    return self.baseCriticalMultiplier * (1 + self.levelBonus.criticalMultiplier / 100)
end

--[[
    Get total health regeneration (base + bonus)
    @return number Quantidade de HP recuperado por segundo
]]
function PlayerState:getTotalHealthRegen()
    return self.baseHealthRegen * (1 + self.levelBonus.healthRegen / 100)
end

--[[
    Take damage
    @param damage Amount of damage to take
    @return boolean Whether the player died from this damage
]]
function PlayerState:takeDamage(damage)
    if not self.isAlive then return false end
    
    -- Calcula a redução de dano
    local reduction = self:getDamageReduction()
    local actualDamage = math.max(1, math.floor(damage * (1 - reduction)))
    
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
    self.currentHealth = math.min(self.currentHealth + amount, self:getTotalHealth())
end

--[[
    Get current health percentage
    @return number Health percentage (0 to 1)
]]
function PlayerState:getHealthPercentage()
    return self.currentHealth / self:getTotalHealth()
end

--[[
    Add bonus to an attribute
    @param attribute Name of the attribute to add bonus
    @param percentage Percentage of bonus to add
]]
function PlayerState:addAttributeBonus(attribute, percentage)
    if self.levelBonus[attribute] then
        self.levelBonus[attribute] = self.levelBonus[attribute] + percentage
        
        -- Se for vida, atualiza a vida máxima e restaura a vida atual
        if attribute == "health" then
            self.maxHealth = self:getTotalHealth()
            self.currentHealth = self.maxHealth
        end
    end
end

return PlayerState 