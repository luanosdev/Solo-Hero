---
-- Este arquivo contém as definições de dados para todos os bosses do jogo.
--

local Constants = require("src.config.constants")

-- Tipagem para habilidades de Boss
---@class BossAbility
---@field name string Nome identificador da habilidade.
---@field classPath string Caminho para o arquivo da classe da habilidade.
---@field weight number Peso para a seleção aleatória da habilidade.
---@field params DashAttackParams Parâmetros específicos para a configuração da habilidade.

-- Tipagem para dados de animação de Boss
---@class AnimationGrid
---@field frameWidth number
---@field frameHeight number
---@field numAnimationFrames number

---@class InstanceAnimationDefaults
---@field activeMovementType string

---@class InstanceDefaults
---@field scale number
---@field animation InstanceAnimationDefaults

-- Tipagem principal para a configuração de um Boss
---@class BossData
---@field className string Nome da classe que implementa o boss.
---@field unitType string Identificador único para o sistema de animação.
---@field name string Nome de exibição do boss.
---@field maxHealth number
---@field experienceValue number
---@field speed number
---@field size number
---@field knockbackResistance number
---@field assetPaths table<string, string> Mapeia tipo de animação para o caminho do asset.
---@field grids table<string, AnimationGrid> Mapeia tipo de animação para sua configuração de grid.
---@field angles number[] Lista de ângulos suportados pela spritesheet.
---@field frameTimes table<string, number> Mapeia tipo de animação para o tempo de cada frame.
---@field instanceDefaults InstanceDefaults Padrões para a instância da animação.
---@field dropTable table Tabela de drops do boss.
---@field abilityCooldown number Tempo de espera entre o fim de uma habilidade e o início da próxima.
---@field abilities BossAbility[] Lista de habilidades do boss.

local default_boss_grids = {
    walk = { frameWidth = 192, frameHeight = 192, numAnimationFrames = 15 },
    run = { frameWidth = 192, frameHeight = 192, numAnimationFrames = 15 },
    taunt = { frameWidth = 192, frameHeight = 192, numAnimationFrames = 15 },
    idle = { frameWidth = 192, frameHeight = 192, numAnimationFrames = 15 },
    death_die1 = { frameWidth = 192, frameHeight = 192, numAnimationFrames = 15 },
    death_die2 = { frameWidth = 192, frameHeight = 192, numAnimationFrames = 15 }
}

local default_boss_angles = { 0, 45, 90, 135, 180, 225, 270, 315 }

---@type table<string, BossData>
local bosses = {
    the_rotten_immortal = {
        className = "TheRottenImmortal",
        unitType = "the_rotten_immortal",
        name = "O Imortal Apodrecido",

        -- Stats
        maxHealth = 5000,
        experienceValue = 1000,
        speed = 60,
        size = Constants.ENEMY_SPRITE_SIZES.LARGE,
        knockbackResistance = 0, -- Imune a knockback

        assetPaths = {
            walk = "assets/bosses/zombie_monster_1/walk.png",
            taunt = "assets/bosses/zombie_monster_1/taunt.png",
            run = "assets/bosses/zombie_monster_1/run.png",
            idle = "assets/bosses/zombie_monster_1/idle.png",
            death_die1 = "assets/bosses/zombie_monster_1/die.png",
            death_die2 = "assets/bosses/zombie_monster_1/die2.png"
        },
        grids = default_boss_grids,
        angles = default_boss_angles,
        frameTimes = {
            walk = 0.06,  -- Segundos por frame
            run = 0.06,   -- Segundos por frame
            taunt = 0.06, -- Segundos por frame
            idle = 0.06,  -- Segundos por frame
            death_die1 = 0.12,
            death_die2 = 0.12
        },
        instanceDefaults = {
            scale = 1.2,
            animation = {
                activeMovementType = 'walk' -- Começa andando
            }
        },
        dropTable = {},

        -- Habilidades
        abilityCooldown = 3, -- Tempo mínimo entre o fim de uma habilidade e o início de outra
        abilities = {
            {
                name = "DashAttack",
                classPath = "src.entities.attacks.bosses.dash_attack", -- Caminho para a classe da habilidade
                weight = 100,                                          -- Chance de seleção (de 1 a 100)
                params = {
                    damage = 150,
                    telegraphDuration = 1,   -- Duração da animação "taunt" e do aviso
                    dashSpeedMultiplier = 5, -- Multiplicador de velocidade durante o avanço
                    stunDuration = 2,        -- Duração do "stun" após o avanço
                    range = 500,         -- Alcance fixo do avanço
                }
            }
        },
    }
}

return bosses
