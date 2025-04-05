--[[
    Base Character
    Defines base stats for all characters
]]

local BaseCharacter = {
    -- Base Stats
    baseHealth = 0,
    baseDamage = 0,
    baseSpeed = 0,
    baseDefense = 0,
    baseBlock = 0,
    baseAttackSpeed = 0,
    baseCriticalChance = 0,
    baseCriticalMultiplier = 0,
    baseHealthRegen = 0,

    -- Class Name
    name = "",

    -- Initial Ability
    initialAbility = nil,

}

function BaseCharacter:getBaseStats()
    return {
        baseHealth = self.baseHealth,
        baseDamage = self.baseDamage,
        baseSpeed = self.baseSpeed,
        baseDefense = self.baseDefense,
        baseBlock = self.baseBlock,
        baseAttackSpeed = self.baseAttackSpeed,
        baseCriticalChance = self.baseCriticalChance,
        baseCriticalMultiplier = self.baseCriticalMultiplier,
        baseHealthRegen = self.baseHealthRegen,
    }
end

function BaseCharacter:getInitialAbility()
    return self.initialAbility
end

return BaseCharacter;