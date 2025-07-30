local ZombieWalkerMale1 = require("src.enemies.common.zombie_walker_male_1")
local ZombieWalkerFemale1 = require("src.enemies.common.zombie_walker_female_1")
local ZombieRunnerMale1 = require("src.enemies.common.zombie_runner_male_1")
local ZombieRunnerFemale1 = require("src.enemies.common.zombie_runner_female_1")
local TheRottenImmortal = require("src.enemies.boss.the_rotten_immortal")

---@type PortalData
local portalData = {
    id = "rank_e_001",
    name = "Undead Plains",
    rank = "E",
    mapId = "jungle",
    requiredUnitTypes = {
        "zombie_walker_male_1",
        "zombie_walker_female_1",
        "zombie_runner_male_1",
        "zombie_runner_female_1",
        "the_rotten_immortal"
    },
    hordeConfig = {
        bossEvents = {
            { time = 360, bossClass = TheRottenImmortal, rank = "E" }
        },
        phases = {
            -- Fase 1: Apenas Walkers (0-2 minutos)
            {
                duration = 120,
                spawnPatterns = {
                    { type = "Wave", enemyClass = ZombieRunnerMale1,   interval = 8, count = 5, maxConcurrent = 50, strategy = "offscreen" },
                    { type = "Wave", enemyClass = ZombieRunnerFemale1, interval = 8, count = 5, maxConcurrent = 50, strategy = "offscreen" },
                }
            },
            -- Fase 2: Introduzindo Runners (2-5 minutos)
            {
                duration = 180,
                spawnPatterns = {
                    { type = "Wave", enemyClass = ZombieWalkerMale1,   interval = 8, count = 8, maxConcurrent = 100, strategy = "offscreen" },
                    { type = "Wave", enemyClass = ZombieWalkerFemale1, interval = 8, count = 8, maxConcurrent = 100, strategy = "offscreen" },
                }
            },
            -- Fase 3: Horda Mista (5-Fim)
            {
                duration = 999, -- Dura até o fim da partida
                spawnPatterns = {
                    { type = "Wave", enemyClass = ZombieWalkerMale1,   interval = 12, count = 10, maxConcurrent = 150, strategy = "offscreen", maxSpawnsPerFrame = 10 },
                    { type = "Wave", enemyClass = ZombieWalkerFemale1, interval = 12, count = 10, maxConcurrent = 150, strategy = "offscreen", maxSpawnsPerFrame = 10 },
                    { type = "Wave", enemyClass = ZombieRunnerMale1,   interval = 8,  count = 4,  maxConcurrent = 50,  strategy = "offscreen" },
                    { type = "Wave", enemyClass = ZombieRunnerFemale1, interval = 8,  count = 4,  maxConcurrent = 50,  strategy = "offscreen" },
                }
            }
        }
    },
    randomEvents = {},
    assetPack = nil
}

return portalData
