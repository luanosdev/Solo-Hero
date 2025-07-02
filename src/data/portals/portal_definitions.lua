-- src/data/portals/portal_definitions.lua
-- Este arquivo define as configurações para os diferentes portais do jogo.
-- Cada portal tem sua própria temática, ranking, nome e configuração de hordas.

---@class MVPConfig
---@field spawnInterval number
---@field statusMultiplier number
---@field speedMultiplier number
---@field sizeMultiplier number
---@field experienceMultiplier number

---@class BossSpawn
---@field time number
---@field class any
---@field unitType string
---@field rank string

---@class BossConfig
---@field spawnTimes BossSpawn[]

---@class AllowedEnemy
---@field class any
---@field weight number
---@field unitType string

---@class MajorSpawnConfig
---@field interval number
---@field baseCount number
---@field countScalePerMin number

---@class MinorSpawnConfig
---@field baseInterval number
---@field intervalReductionPerMin number
---@field minInterval number
---@field count number

---@class HordeCycle
---@field duration number
---@field allowedEnemies AllowedEnemy[]
---@field majorSpawn MajorSpawnConfig
---@field minorSpawn MinorSpawnConfig

---@class HordeConfig
---@field mapRank string
---@field mvpConfig MVPConfig
---@field bossConfig BossConfig
---@field cycles HordeCycle[]

---@class PortalDefinition
---@field name string
---@field rank string
---@field map string
---@field requiredUnitTypes string[]
---@field hordeConfig HordeConfig
---@field randomEvents table[]
---@field assetPack any | nil

---@class PortalDefinitions
---@field [string] PortalDefinition

-- Requer as classes de inimigos e bosses que podem aparecer nos portais.
local ZombieWalkerMale1 = require("src.enemies.common.zombie_walker_male_1")
local ZombieWalkerFemale1 = require("src.enemies.common.zombie_walker_female_1")
local ZombieRunnerMale1 = require("src.enemies.common.zombie_runner_male_1")
local ZombieRunnerFemale1 = require("src.enemies.common.zombie_runner_female_1")
local TheRottenImmortal = require("src.enemies.boss.the_rotten_immortal")

---@type PortalDefinitions
local portalDefinitions = {
    -- TESTS --
    portal_teste_spawn_massivo = {
        name = "TESTE: Spawn Massivo",
        rank = "TEST",
        map = "plains",
        requiredUnitTypes = {
            "zombie_walker_male_1",
            "zombie_walker_female_1",
            "zombie_runner_male_1",
            "zombie_runner_female_1",
        },
        hordeConfig = {
            mapRank = "TEST",
            mvpConfig = {
                spawnInterval = 99999,
                statusMultiplier = 1,
                speedMultiplier = 1,
                sizeMultiplier = 1,
                experienceMultiplier = 1
            },
            bossConfig = {
                spawnTimes = {} -- Sem bosses
            },
            cycles = {
                {
                    duration = 600, -- 10 minutos
                    allowedEnemies = {
                        { class = ZombieWalkerMale1,   weight = 1, unitType = "zombie_walker_male_1" },
                        { class = ZombieWalkerFemale1, weight = 1, unitType = "zombie_walker_female_1" },
                        { class = ZombieRunnerMale1,   weight = 1, unitType = "zombie_runner_male_1" },
                        { class = ZombieRunnerFemale1, weight = 1, unitType = "zombie_runner_female_1" },
                    },
                    majorSpawn = {
                        interval = 5,
                        baseCount = 100,
                        countScalePerMin = 0
                    },
                    minorSpawn = {
                        baseInterval = 5,
                        intervalReductionPerMin = 0,
                        minInterval = 5,
                        count = 5
                    }
                }
            }
        },
        randomEvents = {},
        assetPack = nil
    },
    portal_teste_sem_spawn = {
        name = "TESTE: Sem Spawn",
        rank = "TEST",
        map = "dungeon",
        requiredUnitTypes = {},

        hordeConfig = {
            mapRank = "TEST",
            mvpConfig = {
                spawnInterval = 99999,
                statusMultiplier = 1,
                speedMultiplier = 1,
                sizeMultiplier = 1,
                experienceMultiplier = 1
            },
            bossConfig = {
                spawnTimes = {} -- Sem bosses
            },
            cycles = {
                {
                    duration = 600,      -- 10 minutos de teste
                    allowedEnemies = {}, -- NENHUM inimigo permitido
                    majorSpawn = {
                        interval = 60,
                        baseCount = 0, -- Nenhum inimigo no Major Spawn
                        countScalePerMin = 0
                    },
                    minorSpawn = {
                        baseInterval = 60,
                        intervalReductionPerMin = 0,
                        minInterval = 60,
                        count = 0 -- Nenhum inimigo no Minor Spawn
                    }
                }
            }
        },
        randomEvents = {},
        assetPack = nil
    },
    portal_teste_one_enemy = {
        name = "TESTE: Luta com o Rotten Immortal",
        rank = "TEST",
        map = "plains",
        requiredUnitTypes = { "zombie_walker_male_1", "the_rotten_immortal" },
        hordeConfig = {
            mapRank = "TEST",
            mvpConfig = { -- MVP desligado para este teste
                spawnInterval = 99999,
                statusMultiplier = 1,
                speedMultiplier = 1,
                sizeMultiplier = 1,
                experienceMultiplier = 1
            },
            bossConfig = {
                spawnTimes = {
                    { time = 10, class = TheRottenImmortal, unitType = "the_rotten_immortal", rank = "E" }
                }
            },
            cycles = {
                {
                    duration = 600, -- 10 minutos de teste
                    allowedEnemies = {
                        { class = ZombieWalkerMale1, weight = 1, unitType = "zombie_walker_male_1" }
                    },
                    majorSpawn = {
                        interval = 99999,    -- Spawna a cada 10 segundos
                        baseCount = 999,     -- Grande quantidade no Major Spawn
                        countScalePerMin = 0 -- Sem escalonamento para manter o número previsível
                    },
                    minorSpawn = {           -- Minor spawn também contribui, mas menos
                        baseInterval = 5,
                        intervalReductionPerMin = 0,
                        minInterval = 1,
                        count = 1 -- Alguns inimigos extras do minor spawn
                    }
                }
            }
        },
        randomEvents = {},
        assetPack = nil
    },
    -- END TESTS --

    portal_ranking_e_placeholder = {
        name = "[Recomendado] Mortos Vivos Rank E",
        rank = "E",
        map = math.random(1, 2) == 1 and "plains" or "dungeon",
        requiredUnitTypes = {
            "zombie_walker_male_1",
            "zombie_walker_female_1",
            "zombie_runner_male_1",
            "zombie_runner_female_1",
            "the_rotten_immortal",
        },
        hordeConfig = {
            mapRank = "E",
            mvpConfig = {
                spawnInterval = 60 * 2, -- A cada 3 min
                statusMultiplier = 30,
                speedMultiplier = 1.5,
                sizeMultiplier = 1.3,
                experienceMultiplier = 20
            },
            bossConfig = {
                spawnTimes = {
                    { time = 60 * 6, class = TheRottenImmortal, unitType = "the_rotten_immortal", rank = "E" }
                }
            },
            cycles = {
                -- 🔹 Min 0–2: Só Walkers
                {
                    duration = 120,
                    allowedEnemies = {
                        { class = ZombieWalkerMale1,   weight = 1, unitType = "zombie_walker_male_1" },
                        { class = ZombieWalkerFemale1, weight = 1, unitType = "zombie_walker_female_1" }
                    },
                    majorSpawn = {
                        interval = 15,
                        baseCount = 10,
                        countScalePerMin = 0.2
                    },
                    minorSpawn = {
                        baseInterval = 3,
                        intervalReductionPerMin = 0.2,
                        minInterval = 1.2,
                        count = 3
                    }
                },
                -- 🔹 Min 2–5: Walkers + primeiros Runners
                {
                    duration = 120,
                    allowedEnemies = {
                        { class = ZombieWalkerMale1,   weight = 3, unitType = "zombie_walker_male_1" },
                        { class = ZombieWalkerFemale1, weight = 1, unitType = "zombie_walker_female_1" },
                        { class = ZombieRunnerMale1,   weight = 1, unitType = "zombie_runner_male_1" },
                        { class = ZombieRunnerFemale1, weight = 1, unitType = "zombie_runner_female_1" }
                    },
                    majorSpawn = {
                        interval = 12,
                        baseCount = 15,
                        countScalePerMin = 0.3
                    },
                    minorSpawn = {
                        baseInterval = 2.5,
                        intervalReductionPerMin = 0.25,
                        minInterval = 0.8,
                        count = 4
                    }
                },
                -- 🔹 Min 5–8: Mais runners, densidade aumenta
                {
                    duration = 120,
                    allowedEnemies = {
                        { class = ZombieWalkerMale1,   weight = 1, unitType = "zombie_walker_male_1" },
                        { class = ZombieWalkerFemale1, weight = 1, unitType = "zombie_walker_female_1" },
                        { class = ZombieRunnerMale1,   weight = 3, unitType = "zombie_runner_male_1" },
                        { class = ZombieRunnerFemale1, weight = 3, unitType = "zombie_runner_female_1" }
                    },
                    majorSpawn = {
                        interval = 10,
                        baseCount = 20,
                        countScalePerMin = 0.4
                    },
                    minorSpawn = {
                        baseInterval = 2.2,
                        intervalReductionPerMin = 0.35,
                        minInterval = 0.6,
                        count = 5
                    }
                },
            }
        },
        randomEvents = {},
        assetPack = nil
    },

    survivor_zombie_portal = {
        name = "Survivor Zombie Portal",
        rank = "E",
        map = "plains",
        requiredUnitTypes = {
            "zombie_walker_male_1",
            "zombie_walker_female_1",
            "zombie_runner_male_1",
            "zombie_runner_female_1",
        },

        hordeConfig = {
            mapRank = "E",
            mvpConfig = {
                spawnInterval = 180, -- MVP aos 3 minutos
                statusMultiplier = 12,
                speedMultiplier = 1.15,
                sizeMultiplier = 1.2,
                experienceMultiplier = 15
            },
            bossConfig = {
                spawnTimes = {
                    { time = 600, class = SpiderBoss, unitType = "spider", rank = "E" }
                }
            },
            cycles = {
                -- 🔥 Ciclo 1: Início, só walkers (primeiros 3 minutos)
                {
                    duration = 180,
                    allowedEnemies = {
                        { class = ZombieWalkerMale1,   weight = 1, unitType = "zombie_walker_male_1" },
                        { class = ZombieWalkerFemale1, weight = 1, unitType = "zombie_walker_female_1" }
                    },
                    majorSpawn = {
                        interval = 15,
                        baseCount = 10,
                        countScalePerMin = 0.15
                    },
                    minorSpawn = {
                        baseInterval = 3,
                        intervalReductionPerMin = 0.3,
                        minInterval = 1.2,
                        count = 3
                    }
                },

                -- 🔥 Ciclo 2: Começam a aparecer runners (até 7 minutos)
                {
                    duration = 240,
                    allowedEnemies = {
                        { class = ZombieWalkerMale1,   weight = 1,   unitType = "zombie_walker_male_1" },
                        { class = ZombieWalkerFemale1, weight = 1,   unitType = "zombie_walker_female_1" },
                        { class = ZombieRunnerMale1,   weight = 0.5, unitType = "zombie_runner_male_1" },
                        { class = ZombieRunnerFemale1, weight = 0.5, unitType = "zombie_runner_female_1" }
                    },
                    majorSpawn = {
                        interval = 12,
                        baseCount = 15,
                        countScalePerMin = 0.2
                    },
                    minorSpawn = {
                        baseInterval = 2.5,
                        intervalReductionPerMin = 0.35,
                        minInterval = 0.8,
                        count = 4
                    }
                },

                -- 🔥 Ciclo 3: Crescimento total até o boss (7 min até 10 min)
                {
                    duration = 180,
                    allowedEnemies = {
                        { class = ZombieWalkerMale1,   weight = 1, unitType = "zombie_walker_male_1" },
                        { class = ZombieWalkerFemale1, weight = 1, unitType = "zombie_walker_female_1" },
                        { class = ZombieRunnerMale1,   weight = 1, unitType = "zombie_runner_male_1" },
                        { class = ZombieRunnerFemale1, weight = 1, unitType = "zombie_runner_female_1" }
                    },
                    majorSpawn = {
                        interval = 10,
                        baseCount = 20,
                        countScalePerMin = 0.25
                    },
                    minorSpawn = {
                        baseInterval = 2,
                        intervalReductionPerMin = 0.3,
                        minInterval = 0.6,
                        count = 5
                    }
                }
            }
        },

        randomEvents = {},
        assetPack = nil
    }

}

return portalDefinitions
