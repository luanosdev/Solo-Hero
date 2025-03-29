--[[
    Warrior Class
    Defines base stats for the Warrior class
]]

local ConeSlash = require("src.abilities.cone_slash")

local Warrior = {
    -- Base Stats
    baseHealth = 100,
    baseDamage = 20,
    baseSpeed = 200,
    baseDefense = 10,
    attackSpeed = 1.0,  -- Attacks per second
    
    -- Class Name
    name = "Warrior"
}

--[[
    Get class base stats
    @return table Base stats of the class
]]
function Warrior:getBaseStats()
    return {
        health = self.baseHealth,
        damage = self.baseDamage,
        speed = self.baseSpeed,
        defense = self.baseDefense,
        attackSpeed = self.attackSpeed
    }
end

--[[
    Get initial ability
    @return table Initial ability data
]]
function Warrior:getInitialAbility()
    return ConeSlash
end

return Warrior 