local BaseEnemy = require("src.enemies.base_enemy")
local EnemyData = require("src.data.enemies")
local data = EnemyData.zombie_runner_male_1

---@class ZombieRunnerMale1
local ZombieRunnerMale1 = {}
ZombieRunnerMale1.unitType = "zombie_runner_male_1"
ZombieRunnerMale1.className = "ZombieRunnerMale1"
ZombieRunnerMale1.nameType = "zombie_male"

ZombieRunnerMale1.name = data.name
ZombieRunnerMale1.speed = data.speed
ZombieRunnerMale1.maxHealth = data.health
ZombieRunnerMale1.damage = data.damage
ZombieRunnerMale1.experienceValue = data.experienceValue

ZombieRunnerMale1.size = data.size
ZombieRunnerMale1.dropTable = data.dropTable
ZombieRunnerMale1.spriteData = data.instanceDefaults

setmetatable(ZombieRunnerMale1, { __index = BaseEnemy })
return ZombieRunnerMale1
