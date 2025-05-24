-- src/data/portals/portal_definitions.lua
-- Este arquivo define as configurações para os diferentes portais do jogo.
-- Cada portal tem sua própria temática, ranking, nome e configuração de hordas.

-- Requer as classes de inimigos e bosses que podem aparecer nos portais.
local ZombieWalkerMale1 = require("src.enemies.common.zombie_walker_male_1")
local ZombieWalkerFemale1 = require("src.enemies.common.zombie_walker_female_1")
local ZombieRunnerMale1 = require("src.enemies.common.zombie_runner_male_1")
local ZombieRunnerFemale1 = require("src.enemies.common.zombie_runner_female_1")


local portalDefinitions = {
    -- Exemplo de um portal inicial: Floresta Assombrada
    floresta_assombrada = {
        name = "Basic Forest", -- ATUALIZADO
        theme = "BasicForest", -- ATUALIZADO
        rank = "E",            -- Ranking de dificuldade base do portal
        map = "forest",        -- NOVO CAMPO

        -- Configuração específica das hordas para este portal
        hordeConfig = {
            mapRank = "E", -- Rank base do mapa para cálculo de drops e dificuldade (pode ser o mesmo do portal)

            -- Configurações de MVPs neste portal
            mvpConfig = {
                spawnInterval = 120, -- MVPs aparecem a cada 2 minutos
                statusMultiplier = 15,
                speedMultiplier = 1.1,
                sizeMultiplier = 1.2,
                experienceMultiplier = 15
            },

            -- Configurações de Bosses neste portal
            bossConfig = {
                spawnTimes = {
                    -- SpiderBoss aparece aos 3 minutos
                    { time = 60 * 3, class = SpiderBoss, unitType = "spider" }
                }
            },

            -- Ciclos de spawn para este portal
            cycles = {
                -- Ciclo 1: Apenas Skeletons (Primeiros 60 segundos)
                {
                    duration = 60,
                    allowedEnemies = {
                        { class = ZombieWalkerMale1, weight = 1, unitType = "zombie_walker_male_1" },
                    },
                    majorSpawn = {
                        interval = 15,
                        baseCount = 15,
                        countScalePerMin = 0.15
                    },
                    minorSpawn = {
                        baseInterval = 2.5,
                        intervalReductionPerMin = 0.30,
                        minInterval = 1.0,
                        count = 5
                    }
                },
                -- Ciclo 2: Skeletons e Zombies (Próximos 120 segundos)
                {
                    duration = 120,
                    allowedEnemies = {
                        { class = Skeleton, weight = 2, unitType = "skeleton" },
                        { class = Zombie,   weight = 1, unitType = "zombie" }
                    },
                    majorSpawn = {
                        interval = 12,
                        baseCount = 20,
                        countScalePerMin = 0.20,
                    },
                    minorSpawn = {
                        baseInterval = 2.0,
                        intervalReductionPerMin = 0.40,
                        minInterval = 0.75,
                        count = 1
                    }
                },
                -- Ciclo 3: Continuado com ambos (Restante do tempo)
                {
                    duration = 600, -- Dura 10 minutos ou até o fim
                    allowedEnemies = {
                        { class = Skeleton, weight = 1, unitType = "skeleton" },
                        { class = Zombie,   weight = 1, unitType = "zombie" }
                    },
                    majorSpawn = {
                        interval = 10,
                        baseCount = 25,
                        countScalePerMin = 0.25,
                    },
                    minorSpawn = {
                        baseInterval = 1.5,
                        intervalReductionPerMin = 0.20, -- Escalonamento mais lento agora
                        minInterval = 0.5,
                        count = 1
                    }
                }
                -- Adicione mais ciclos conforme necessário para este portal...
            }
        },

        -- NOVA SEÇÃO mapDefinition
        mapDefinition = {
            theme = "forest",
            objectSpawnRules = {},
            eventSpawnRules = {}
        },

        -- Futuras configurações (placeholder)
        randomEvents = {}, -- Tabela para definir eventos aleatórios que podem ocorrer
        assetPack = nil    -- Referência para assets específicos do tema (sprites, sons)
    },

    UrbanCemetery = {
        name = "Cemitério Urbano",
        theme = "CementeryTheme",                       -- O tema real do mapa precisará ser criado
        rank = "D",
        map = "forest",                                 -- NOVO CAMPO
        requiredUnitTypes = { "zombie_walker_male_1" }, -- Apenas este inimigo por enquanto

        hordeConfig = {
            mapRank = "D",
            mvpConfig = { -- Configuração MVP básica
                spawnInterval = 180,
                statusMultiplier = 10,
                speedMultiplier = 1.1,
                sizeMultiplier = 1.15,
                experienceMultiplier = 10
            },
            bossConfig = {
                spawnTimes = {} -- Sem bosses por enquanto
            },
            cycles = {
                -- Ciclo único com ZombieWalkerMale1
                {
                    duration = 1200, -- 20 minutos
                    allowedEnemies = {
                        { class = ZombieWalkerMale1, weight = 1, unitType = "zombie_walker_male_1" }
                    },
                    majorSpawn = {
                        interval = 20,
                        baseCount = 10,
                        countScalePerMin = 0.10
                    },
                    minorSpawn = {
                        baseInterval = 3.0,
                        intervalReductionPerMin = 0.25,
                        minInterval = 1.2,
                        count = 3
                    }
                }
            }
        },
        mapDefinition = {
            theme = "cemetery", -- O nome do tema para o ChunkManager
            -- chunkSize = 32, -- Opcional, pode ser herdado ou definido aqui
            objectSpawnRules = {},
            eventSpawnRules = {}
        },
        randomEvents = {},
        assetPack = nil
    },

    -- Adicione outras definições de portais aqui...
    -- exemplo_portal_2 = { ... }

    portal_teste_spawn_massivo = {
        name = "TESTE: Spawn Massivo",
        theme = "CementeryTheme", -- Usando um tema existente para simplicidade
        rank = "TEST",
        map = "forest",           -- NOVO CAMPO
        requiredUnitTypes = { "zombie_walker_male_1" },

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
                spawnTimes = {} -- Sem bosses
            },
            cycles = {
                {
                    duration = 600, -- 10 minutos de teste
                    allowedEnemies = {
                        { class = ZombieWalkerMale1, weight = 1, unitType = "zombie_walker_male_1" }
                    },
                    majorSpawn = {
                        interval = 5,        -- Spawna a cada 10 segundos
                        baseCount = 100,     -- Grande quantidade no Major Spawn
                        countScalePerMin = 0 -- Sem escalonamento para manter o número previsível
                    },
                    minorSpawn = {           -- Minor spawn também contribui, mas menos
                        baseInterval = 5,
                        intervalReductionPerMin = 0,
                        minInterval = 5,
                        count = 5 -- Alguns inimigos extras do minor spawn
                    }
                }
            }
        },
        mapDefinition = {
            theme = "cemetery",
            objectSpawnRules = {},
            eventSpawnRules = {}
        },
        randomEvents = {},
        assetPack = nil
    },

    portal_teste_sem_spawn = {
        name = "TESTE: Sem Spawn",
        theme = "CementeryTheme", -- Usando um tema existente para simplicidade
        rank = "TEST",
        map = "forest",           -- NOVO CAMPO
        requiredUnitTypes = {},   -- Nenhum tipo de unidade requerido

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
        mapDefinition = {
            theme = "cemetery",
            objectSpawnRules = {},
            eventSpawnRules = {}
        },
        randomEvents = {},
        assetPack = nil
    },
    portal_teste_one_enemy = {
        name = "TESTE: Um Inimigo",
        theme = "CementeryTheme",
        rank = "TEST",
        map = "forest",
        requiredUnitTypes = { "zombie_walker_male_1" },
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
                spawnTimes = {} -- Sem bosses
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
        mapDefinition = {
            theme = "cemetery",
            objectSpawnRules = {},
            eventSpawnRules = {}
        },
        randomEvents = {},
        assetPack = nil
    }
}

return portalDefinitions
