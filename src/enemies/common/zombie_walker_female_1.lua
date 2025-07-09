local BaseEnemy = require("src.enemies.base_enemy")
local EnemyData = require("src.data.enemies")
local data = EnemyData.zombie_walker_female_1

---@class ZombieWalkerFemale1
local ZombieWalkerFemale1 = {}
ZombieWalkerFemale1.unitType = "zombie_walker_female_1"
ZombieWalkerFemale1.className = "ZombieWalkerFemale1"
ZombieWalkerFemale1.nameType = "zombie_female"

ZombieWalkerFemale1.name = data.name
ZombieWalkerFemale1.speed = data.speed
ZombieWalkerFemale1.maxHealth = data.health
ZombieWalkerFemale1.damage = data.damage
ZombieWalkerFemale1.experienceValue = data.experienceValue

ZombieWalkerFemale1.size = data.size
ZombieWalkerFemale1.dropTable = data.dropTable
ZombieWalkerFemale1.spriteData = data.instanceDefaults
ZombieWalkerFemale1.artefactDrops = data.artefactDrops

setmetatable(ZombieWalkerFemale1, { __index = BaseEnemy })
return ZombieWalkerFemale1
