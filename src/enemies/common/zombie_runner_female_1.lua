local BaseEnemy = require("src.enemies.base_enemy")
local EnemyData = require("src.data.enemies")
local data = EnemyData.zombie_runner_female_1

---@class ZombieRunnerFemale1
local ZombieRunnerFemale1 = {}
ZombieRunnerFemale1.unitType = "zombie_runner_female_1"
ZombieRunnerFemale1.className = "ZombieRunnerFemale1"
ZombieRunnerFemale1.nameType = "zombie_female"

ZombieRunnerFemale1.name = data.name
ZombieRunnerFemale1.speed = data.speed
ZombieRunnerFemale1.maxHealth = data.health
ZombieRunnerFemale1.damage = data.damage
ZombieRunnerFemale1.experienceValue = data.experienceValue

ZombieRunnerFemale1.size = data.size
ZombieRunnerFemale1.dropTable = data.dropTable
ZombieRunnerFemale1.spriteData = data.instanceDefaults

setmetatable(ZombieRunnerFemale1, { __index = BaseEnemy })
return ZombieRunnerFemale1
