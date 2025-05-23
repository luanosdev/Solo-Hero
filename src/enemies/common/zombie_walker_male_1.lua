local BaseEnemy = require("src.classes.enemies.base_enemy")
local EnemyData = require("src.data.enemies")
local data = EnemyData.zombie_walker_male_1

---@class ZombieWalkerMale1
local ZombieWalkerMale1 = {
    className = "ZombieWalkerMale1",
    unitType = "zombie_walker_male_1",
    name = data.name,
    speed = data.defaultSpeed,
    maxHealth = data.health,
    damage = data.damage,
    experienceValue = data.experienceValue,
    radius = data.radius,
    dropTable = data.dropTable,
    spriteData = data.instanceDefaults,
}

setmetatable(ZombieWalkerMale1, { __index = BaseEnemy })
return ZombieWalkerMale1
