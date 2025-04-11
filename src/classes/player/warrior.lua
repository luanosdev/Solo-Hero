--[[
    Warrior Class
    Defines base stats for the Warrior class
]]

local ConeSlash = require("src.abilities.player.attacks.cone_slash")
local LinearProjectile = require("src.abilities.player.attacks.linear_projectile")

local Warrior = {
    -- Base Stats
    baseHealth = 100,
    baseDamage = 20,
    baseSpeed = 200,
    baseDefense = 10,
    attackSpeed = 0.7,  -- Attacks per second
    criticalChance = 0.2, -- 20% de chance de crítico
    criticalMultiplier = 1.8, -- 80% de dano crítico
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
        attackSpeed = self.attackSpeed,
        criticalChance = self.criticalChance,
        criticalMultiplier = self.criticalMultiplier
    }
end

--[[
    Get initial ability
    @return table Initial ability data
]]
function Warrior:getInitialAbility()
    return LinearProjectile
end

return Warrior