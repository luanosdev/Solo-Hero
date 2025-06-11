local BaseEnemy = require("src.enemies.base_enemy")
local EnemyData = require("src.data.enemies")
local data = EnemyData.zombie_walker_male_1

---@class ZombieWalkerMale1
local ZombieWalkerMale1 = {}
ZombieWalkerMale1.unitType = "zombie_walker_male_1"
ZombieWalkerMale1.className = "ZombieWalkerMale1"
ZombieWalkerMale1.nameType = "zombie_male"

ZombieWalkerMale1.name = data.name
ZombieWalkerMale1.speed = data.speed
ZombieWalkerMale1.maxHealth = data.health
ZombieWalkerMale1.damage = data.damage
ZombieWalkerMale1.experienceValue = data.experienceValue

ZombieWalkerMale1.size = data.size
ZombieWalkerMale1.dropTable = data.dropTable
ZombieWalkerMale1.spriteData = data.instanceDefaults

setmetatable(ZombieWalkerMale1, { __index = BaseEnemy })
return ZombieWalkerMale1
