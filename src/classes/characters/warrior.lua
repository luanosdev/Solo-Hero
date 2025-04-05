--[[
    Warrior Class
    Defines base stats for the Warrior class
]]
local BaseCharacter = require("src.classes.characters.base_character")
local ConeSlash = require("src.abilities.cone_slash")

local Warrior = setmetatable({}, { __index = BaseCharacter });

Warrior.name = "Warrior"
Warrior.baseHealth = 100
Warrior.baseDamage = 20
Warrior.baseSpeed = 100
Warrior.baseDefense = 10
Warrior.baseBlock = 0.1
Warrior.baseAttackSpeed = 0.7
Warrior.baseCriticalChance = 0.2
Warrior.baseCriticalMultiplier = 1.8
Warrior.baseHealthRegen = 0.2



local Warrior = {
    -- Base Stats
    baseHealth = 100,
    baseDamage = 20,
    baseSpeed = 100,
    baseDefense = 10,
    attackSpeed = 0.7,  -- Attacks per second
    criticalChance = 0.2, -- 20% de chance de crítico
    criticalMultiplier = 1.8, -- 80% de dano crítico
    -- Class Name
    name = "Warrior",

    -- Initial Ability
    initialAbility = ConeSlash,
}

return Warrior;