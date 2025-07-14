local Constants = require("src.config.constants")
local ArtefactDrops = require("src.data.artefact_drops")

local default_enemy_grids = {
    walk = { frameWidth = 128, frameHeight = 128, numAnimationFrames = 15 },
    run = { frameWidth = 128, frameHeight = 128, numAnimationFrames = 15 },
    death_die1 = { frameWidth = 128, frameHeight = 128, numAnimationFrames = 15 },
    death_die2 = { frameWidth = 128, frameHeight = 128, numAnimationFrames = 15 }
}

local default_enemy_angles = { 0, 45, 90, 135, 180, 225, 270, 315 }

---@class EnemyData
---@field unitType string
---@field name string
---@field assetPaths table<string, string>
---@field grids table<string, {frameWidth: number, frameHeight: number, numAnimationFrames: number}>
---@field angles number[]
---@field frameTimes table<string, number>
---@field defaultSpeed number
---@field movementThreshold number
---@field resetFrameOnStop boolean
---@field angleOffset number
---@field instanceDefaults table
---@field health number
---@field damage number
---@field artefactDrops ArtefactDropTable

local enemies = {
    zombie_walker_male_1 = {
        unitType = "zombie_walker_male_1",
        name = "Zombie Walker",

        speed = 50,
        health = 400,
        damage = 50,
        experienceValue = 60,
        size = Constants.ENEMY_SPRITE_SIZES.MEDIUM,

        assetPaths = {
            walk = "assets/enemies/zombie_male_1/walk.png",
            death_die1 = "assets/enemies/zombie_male_1/die.png",
            death_die2 = "assets/enemies/zombie_male_1/die2.png"
        },
        grids = default_enemy_grids,
        angles = default_enemy_angles,
        frameTimes = {
            walk = 0.08,
            death_die1 = 0.06,
            death_die2 = 0.06
        },

        instanceDefaults = {
            scale = 1.2,
            animation = {
                activeMovementType = 'walk' -- Começa andando
            }
        },
        dropTable = {},
        artefactDrops = ArtefactDrops.zombie_walker,
    },
    zombie_runner_male_1 = {
        unitType = "zombie_runner_male_1",
        name = "Zombie Runner",

        speed = 70,
        health = 100,
        damage = 30,
        experienceValue = 40,
        size = Constants.ENEMY_SPRITE_SIZES.MEDIUM,

        assetPaths = {
            run = "assets/enemies/zombie_male_1/run.png",
            death_die1 = "assets/enemies/zombie_male_1/die.png",
            death_die2 = "assets/enemies/zombie_male_1/die2.png"
        },
        grids = default_enemy_grids,
        angles = default_enemy_angles,
        frameTimes = {
            run = 0.04,
            death_die1 = 0.06,
            death_die2 = 0.06
        },

        instanceDefaults = {
            scale = 1,
            animation = {
                activeMovementType = 'run' -- Começa andando
            }
        },
        dropTable = {},
        artefactDrops = ArtefactDrops.zombie_runner,
    },
    zombie_walker_female_1 = {
        unitType = "zombie_walker_female_1",
        name = "Zombie Walker",

        speed = 50,
        health = 400,
        damage = 50,
        experienceValue = 60,
        size = Constants.ENEMY_SPRITE_SIZES.MEDIUM,

        assetPaths = {
            walk = "assets/enemies/zombie_female_1/walk.png",
            death_die1 = "assets/enemies/zombie_female_1/die.png",
            death_die2 = "assets/enemies/zombie_female_1/die2.png"
        },
        grids = default_enemy_grids,
        angles = default_enemy_angles,
        frameTimes = {
            walk = 0.08,
            death_die1 = 0.06,
            death_die2 = 0.06
        },

        instanceDefaults = {
            scale = 1.2,
            animation = {
                activeMovementType = 'walk' -- Começa andando
            }
        },
        dropTable = {},
        artefactDrops = ArtefactDrops.zombie_walker,
    },
    zombie_runner_female_1 = {
        unitType = "zombie_runner_female_1",
        name = "Zombie Runner",

        speed = 70,
        health = 100,
        damage = 30,
        experienceValue = 40,
        size = Constants.ENEMY_SPRITE_SIZES.MEDIUM,

        assetPaths = {
            run = "assets/enemies/zombie_female_1/run.png",
            death_die1 = "assets/enemies/zombie_female_1/die.png",
            death_die2 = "assets/enemies/zombie_female_1/die2.png"
        },
        grids = default_enemy_grids,
        angles = default_enemy_angles,
        frameTimes = {
            run = 0.04,
            death_die1 = 0.06,
            death_die2 = 0.06
        },

        instanceDefaults = {
            scale = 1,
            animation = {
                activeMovementType = 'run' -- Começa andando
            }
        },
        dropTable = {},
        artefactDrops = ArtefactDrops.zombie_runner,
    }
}

return enemies
