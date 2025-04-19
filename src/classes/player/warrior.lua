--[[
    Warrior Class
    Defines base stats for the Warrior class
]]

local WoodenSword = require("src.items.weapons.wooden_sword")

local Warrior = {
    -- Base Stats
    baseHealth = 400,
    baseDamage = 0,
    baseSpeed = 60,
    baseDefense = 10,
    attackSpeed = 0.7,  -- Attacks per second
    criticalChance = 0.2, -- 20% de chance de crítico
    criticalMultiplier = 1.8, -- 80% de dano crítico
    healthRegen = 0.2, -- 0.2 HP por segundo 
    baseMultiAttackChance = 0, -- Chance base de ataque múltiplo
    -- Class Name
    name = "Warrior",
    -- Starting Weapon
    startingWeapon = WoodenSword
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