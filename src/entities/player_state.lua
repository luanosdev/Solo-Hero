--[[
    Player State
    Manages player's current state and status
]]

local PlayerState = {
    currentHealth = 0,
    maxHealth = 0,
    isAlive = true,
    
    -- Atributos de Jogo
    level = 1,
    experience = 0,
    experienceToNextLevel = 50, -- Valor inicial, pode ser ajustado
    experienceMultiplier = 1.10, -- Multiplicador para o próximo nível
    kills = 0,
    gold = 0,
    
    -- Atributos base
    baseHealth = 0,
    baseDamage = 0,
    baseDefense = 0,
    baseSpeed = 0,
    baseAttackSpeed = 0,
    baseCriticalChance = 0,
    baseCriticalMultiplier = 0,
    baseHealthRegen = 0, -- Nova propriedade: regeneração de vida base
    baseMultiAttackChance = 0, -- Nova propriedade: chance de ataque múltiplo base
    baseArea = 0, -- Nova propriedade: área base
    baseRange = 0, -- Nova propriedade: alcance base
    
    -- Bônus por nível (em porcentagem)
    levelBonus = {
        health = 0,
        damage = 0,
        defense = 0,
        speed = 0,
        attackSpeed = 0,
        criticalChance = 0,
        criticalMultiplier = 0,
        healthRegen = 0, -- Novo bônus: regeneração de vida
        multiAttackChance = 0, -- Novo bônus: chance de ataque múltiplo
        area = 0, -- Novo bônus: área
        range = 0 -- Novo bônus: alcance
    },

    -- Bônus fixos
    fixedBonus = {
        speed = 0, -- Bônus fixo de velocidade em m/s
        health = 0, -- Bônus fixo de vida
        defense = 0, -- Bônus fixo de defesa
        healthRegen = 0,
        multiAttackChance = 0, -- Bônus fixo de chance de ataque múltiplo
        criticalChance = 0, -- Bônus fixo de chance de crítico
        criticalMultiplier = 0 -- Bônus fixo de multiplicador de crítico
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
    self.baseMultiAttackChance = baseStats.multiAttackChance or 0 -- Inicializa chance de ataque múltiplo base
    self.baseArea = baseStats.area or 0 -- Inicializa área base
    self.baseRange = baseStats.range or 0 -- Inicializa alcance base
    
    -- Reinicializa atributos de jogo para o estado inicial
    self.level = 1
    self.experience = 0
    self.experienceToNextLevel = 50 -- Ou um valor base configurável
    self.experienceMultiplier = 1.10 -- Ou um valor base configurável
    self.kills = 0
    self.gold = 0
    
    -- Inicializa bônus de nível
    self.levelBonus = {
        health = 0,
        damage = 0,
        defense = 0,
        speed = 0,
        attackSpeed = 0,
        criticalChance = 0,
        criticalMultiplier = 0,
        healthRegen = 0, -- Inicializa bônus de regeneração de vida
        multiAttackChance = 0, -- Inicializa bônus de chance de ataque múltiplo
        area = 0, -- Inicializa bônus de área
        range = 0 -- Inicializa bônus de alcance
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
    @param baseDamage Valor base do dano
    @return number Total damage
]]
function PlayerState:getTotalDamage(baseDamage)
    local totalDamage = math.floor(baseDamage * (1 + self.levelBonus.damage / 100))
    return totalDamage
end

--[[
    Get total defense (base + bonus)
    @return number Total defense
]]
function PlayerState:getTotalDefense()
    return math.floor(self.baseDefense * (1 + self.levelBonus.defense / 100) + self.fixedBonus.defense)
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
    return self.baseSpeed * (1 + self.levelBonus.speed / 100) + self.fixedBonus.speed
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
    return self.baseCriticalChance * (1 + self.levelBonus.criticalChance / 100) + self.fixedBonus.criticalChance
end

--[[
    Get total critical multiplier (base + bonus)
    @return number Total critical multiplier
]]
function PlayerState:getTotalCriticalMultiplier()
    return self.baseCriticalMultiplier * (1 + self.levelBonus.criticalMultiplier / 100) + self.fixedBonus.criticalMultiplier
end

--[[
    Get total health regeneration (base + bonus)
    @return number Quantidade de HP recuperado por segundo
]]
function PlayerState:getTotalHealthRegen()
    return self.baseHealthRegen * (1 + self.levelBonus.healthRegen / 100) + self.fixedBonus.healthRegen
end

--[[
    Get total multi attack chance (base + bonus)
    @return number Total multi attack chance
]]
function PlayerState:getTotalMultiAttackChance()
    return self.baseMultiAttackChance * (1 + self.levelBonus.multiAttackChance / 100)
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
    @param fixed Fixed percentage of bonus to add (for defense)
]]
function PlayerState:addAttributeBonus(attribute, percentage, fixed)
    if self.levelBonus[attribute] then
        -- Adiciona o bônus
        local oldBonus = self.levelBonus[attribute]
        self.levelBonus[attribute] = self.levelBonus[attribute] + percentage
        
        -- Debug: Mostra o bônus adicionado
        print(string.format(
            "[PlayerState] Bônus de %s adicionado: +%.1f%% (Antigo: %.1f%%, Novo: %.1f%%)", 
            attribute, 
            percentage,
            oldBonus,
            self.levelBonus[attribute]
        ))
        
        -- Atualiza os valores totais baseado no atributo
        if attribute == "health" then
            self.maxHealth = self:getTotalHealth()
            self.currentHealth = self.maxHealth
            print(string.format("[PlayerState] Vida atualizada: %.1f/%.1f", self.currentHealth, self.maxHealth))
        elseif attribute == "damage" then
            print(string.format("[PlayerState] Dano total: %.1f", self:getTotalDamage(self.baseDamage)))
        elseif attribute == "defense" then
            self.fixedBonus.defense = self.fixedBonus.defense + fixed
            print(string.format("[PlayerState] Defesa total: %.1f (Base: %.1f, Bônus: %.1f%%, Fixo: %.1f)", 
                self:getTotalDefense(), 
                self.baseDefense, 
                self.levelBonus.defense,
                self.fixedBonus.defense))
        elseif attribute == "speed" then
            print(string.format("[PlayerState] Velocidade total: %.1f", self:getTotalSpeed()))
        elseif attribute == "attackSpeed" then
            print(string.format("[PlayerState] Velocidade de ataque total: %.1f", self:getTotalAttackSpeed()))
        elseif attribute == "criticalChance" then
            print(string.format("[PlayerState] Chance de crítico total: %.1f%%", self:getTotalCriticalChance()))
        elseif attribute == "criticalMultiplier" then
            print(string.format("[PlayerState] Multiplicador de crítico total: %.1fx", self:getTotalCriticalMultiplier()))
        elseif attribute == "healthRegen" then
            self.fixedBonus.healthRegen = self.fixedBonus.healthRegen + fixed
            print(string.format("[PlayerState] Regeneração de vida total: %.1f/s (Base: %.1f, Bônus: %.1f%%, Fixo: %.1f)", 
                self:getTotalHealthRegen(),
                self.baseHealthRegen,
                self.levelBonus.healthRegen,
                self.fixedBonus.healthRegen))
        elseif attribute == "multiAttackChance" then
            print(string.format("[PlayerState] Chance de ataque múltiplo total: %.1f%%", self:getTotalMultiAttackChance()))
        elseif attribute == "area" then
            print(string.format("[PlayerState] Área total: %.1f", self:getTotalArea()))
        elseif attribute == "range" then
            print(string.format("[PlayerState] Alcance total: %.1f", self:getTotalRange()))
        end
    elseif attribute == "fixed_speed" then
        -- Adiciona bônus fixo de velocidade
        self.fixedBonus.speed = self.fixedBonus.speed + percentage
        print(string.format("[PlayerState] Velocidade fixa adicionada: +%.1f m/s (Total: %.1f m/s)", percentage, self.fixedBonus.speed))
    elseif attribute == "fixed_health" then
        -- Adiciona bônus fixo de vida
        self.fixedBonus.health = self.fixedBonus.health + percentage
        self.maxHealth = self:getTotalHealth()
        self.currentHealth = self.maxHealth
        print(string.format("[PlayerState] Vida fixa adicionada: +%.1f (Total: %.1f)", percentage, self.fixedBonus.health))
    elseif attribute == "fixed_defense" then
        -- Adiciona bônus fixo de defesa
        self.fixedBonus.defense = self.fixedBonus.defense + percentage
        print(string.format("[PlayerState] Defesa fixa adicionada: +%.1f (Total: %.1f)", percentage, self.fixedBonus.defense))
    elseif attribute == "fixed_health_regen" then
        -- Adiciona bônus fixo de regeneração de vida
        self.fixedBonus.healthRegen = self.fixedBonus.healthRegen + percentage
        print(string.format("[PlayerState] Regeneração de vida fixa adicionada: +%.1f HP/s (Total: %.1f HP/s)", percentage, self.fixedBonus.healthRegen))
    elseif attribute == "fixed_multi_attack" then
        -- Adiciona bônus fixo de chance de ataque múltiplo
        self.fixedBonus.multiAttackChance = self.fixedBonus.multiAttackChance + percentage
        print(string.format("[PlayerState] Chance de ataque múltiplo fixa adicionada: +%.1f%% (Total: %.1f%%)", percentage, self.fixedBonus.multiAttackChance))
    elseif attribute == "fixed_critical_chance" then
        -- Adiciona bônus fixo de chance de crítico
        self.fixedBonus.criticalChance = self.fixedBonus.criticalChance + percentage
        print(string.format("[PlayerState] Chance de crítico fixa adicionada: +%.1f%% (Total: %.1f%%)", percentage, self.fixedBonus.criticalChance))
    elseif attribute == "fixed_critical_multiplier" then
        -- Adiciona bônus fixo de multiplicador de crítico
        self.fixedBonus.criticalMultiplier = self.fixedBonus.criticalMultiplier + percentage
        print(string.format("[PlayerState] Multiplicador de crítico fixo adicionado: +%.1fx (Total: %.1fx)", percentage, self.fixedBonus.criticalMultiplier))
    else
        print(string.format("[PlayerState] ERRO: Atributo '%s' não encontrado", attribute))
    end
end

--[[
    Atualiza os atributos base quando uma nova arma é equipada
    @param weapon A nova arma equipada
]]
function PlayerState:updateWeaponStats(weapon)
    if not weapon then return end
    
    -- Atualiza apenas o dano base da arma
    self.baseDamage = weapon.damage
end

--[[
    Get total area (base + bonus)
    @return number Total area
]]
function PlayerState:getTotalArea()
    return self.baseArea * (1 + self.levelBonus.area / 100)
end

--[[
    Get total range (base + bonus)
    @return number Total range
]]
function PlayerState:getTotalRange()
    return self.baseRange * (1 + self.levelBonus.range / 100)
end

--[[
    Adiciona experiência ao jogador e verifica se houve level up.
    @param amount Quantidade de experiência a adicionar.
    @return boolean True se o jogador subiu de nível, false caso contrário.
]]
function PlayerState:addExperience(amount)
    if not self.isAlive then return false end

    self.experience = self.experience + amount
    local leveledUp = false
    while self.experience >= self.experienceToNextLevel do
        self.level = self.level + 1
        local previousRequired = self.experienceToNextLevel
        -- Mantém o excesso de XP para o próximo nível
        self.experience = self.experience - previousRequired
        self.experienceToNextLevel = previousRequired + math.floor(previousRequired * self.experienceMultiplier)
        leveledUp = true
        -- TODO: Considerar adicionar lógica de recompensa de level up aqui (cura, bônus, etc.)
        -- Ex: self:heal(self:getTotalHealth() * 0.25) -- Cura 25% da vida ao subir de nível
    end
    return leveledUp
end

--[[
    Adiciona ouro ao jogador.
    @param amount Quantidade de ouro a adicionar.
]]
function PlayerState:addGold(amount)
    if not self.isAlive then return end
    self.gold = self.gold + amount
end

--[[
    Incrementa a contagem de abates do jogador.
]]
function PlayerState:addKill()
    if not self.isAlive then return end
    self.kills = self.kills + 1
end

return PlayerState 