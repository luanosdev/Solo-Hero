--[[
    Warrior Class
    Defines base stats for the Warrior class
]]

local ConeSlash = require("src.abilities.player.attacks.cone_slash")
local LinearProjectile = require("src.abilities.player.attacks.linear_projectile")
local IronSword = require("src.items.weapons.iron_sword")

local Warrior = {
    -- Base Stats
    baseHealth = 100,
    baseDamage = 15,
    baseSpeed = 100,
    baseDefense = 10,
    attackSpeed = 0.7,  -- Attacks per second
    criticalChance = 0.2, -- 20% de chance de crítico
    criticalMultiplier = 1.8, -- 80% de dano crítico
    healthRegen = 0.2, -- 0.2 HP por segundo 
    baseMultiAttackChance = 0, -- Chance base de ataque múltiplo
    -- Class Name
    name = "Warrior",
    -- Starting Weapon
    startingWeapon = IronSword
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
        criticalMultiplier = self.criticalMultiplier,
        healthRegen = self.healthRegen,
        multiAttackChance = self.baseMultiAttackChance
    }
end

return Warrior