---
-- Este arquivo contém as definições de dados para todos os bosses do jogo.
--

local Constants = require("src.config.constants")

-- Tipagem para habilidades de Boss
---@class BossAbility
---@field name string Nome identificador da habilidade.
---@field classPath string Caminho para o arquivo da classe da habilidade.
---@field weight number Peso para a seleção aleatória da habilidade.
---@field lowHealthOnly boolean|nil Se verdadeiro, só usa a habilidade quando vida < 50%.
---@field params DashAttackParams|AreaExplosionParams|ChargingRunParams Parâmetros específicos para a configuração da habilidade.

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
---@field damage number
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
    death_die2 = { frameWidth = 192, frameHeight = 192, numAnimationFrames = 15 },
    attack = { frameWidth = 192, frameHeight = 192, numAnimationFrames = 15 }
}

local default_boss_angles = { 0, 45, 90, 135, 180, 225, 270, 315 }

---@type table<string, BossData>
local bosses = {
    the_rotten_immortal = {
        className = "TheRottenImmortal",
        unitType = "the_rotten_immortal",
        name = "O Imortal Apodrecido",

        -- Stats
        maxHealth = 30000,
        experienceValue = 1000,
        damage = 200,
        speed = 60,
        size = Constants.ENEMY_SPRITE_SIZES.LARGE,
        knockbackResistance = Constants.KNOCKBACK_RESISTANCE.IMMUNE, -- Imune a knockback

        assetPaths = {
            walk = "assets/bosses/zombie_monster_1/walk.png",
            taunt = "assets/bosses/zombie_monster_1/taunt.png",
            run = "assets/bosses/zombie_monster_1/run.png",
            idle = "assets/bosses/zombie_monster_1/idle.png",
            death_die1 = "assets/bosses/zombie_monster_1/die.png",
            death_die2 = "assets/bosses/zombie_monster_1/die2.png",
            attack = "assets/bosses/zombie_monster_1/attack.png"
        },
        grids = default_boss_grids,
        angles = default_boss_angles,
        frameTimes = {
            walk = 0.06, -- Segundos por frame
            run = 0.06,  -- Segundos por frame
            taunt = 0.1, -- Segundos por frame
            idle = 0.06, -- Segundos por frame
            death_die1 = 0.12,
            death_die2 = 0.12,
            attack = 0.08
        },
        instanceDefaults = {
            scale = 1.2,
            animation = {
                activeMovementType = 'walk' -- Começa andando
            }
        },
        dropTable = {},

        -- Habilidades
        abilityCooldown = 1, -- Tempo mínimo entre o fim de uma habilidade e o início de outra
        abilities = {
            {
                name = "DashAttack",
                classPath = "src.entities.attacks.bosses.dash_attack", -- Caminho para a classe da habilidade
                weight = 80,                                           -- Chance de seleção (de 1 a 100)
                params = {
                    damageMultiplier = 2,
                    telegraphDuration = 0.5, -- Duração da animação "taunt" e do aviso
                    dashSpeedMultiplier = 5, -- Multiplicador de velocidade durante o avanço
                    stunDuration = 1,        -- Duração do "stun" após o avanço
                    range = 500,
                    followUpChances = { 0.7, 0.6, 0.2, 0.1 },
                    followUpRangeIncrease = 1.2,
                    followUpStunIncrease = 0.5
                }
            },
            {
                name = "AreaExplosionAttack",
                classPath = "src.entities.attacks.bosses.area_explosion_attack",
                weight = 60,
                params = {
                    damageMultiplier = 1.25,
                    range = 250,
                    explosionRadius = 300,
                    telegraphDuration = 2,
                    stunDuration = 2,
                    followUpChances = { 0.5, 0.3, 0.1, 0.05 },
                    followUpRadiusIncrease = 1.2,
                    followUpStunIncrease = 0.5
                }
            },
            {
                name = "ChargingRunAttack",
                classPath = "src.entities.attacks.bosses.charging_run_attack",
                weight = 20,
                lowHealthOnly = true, -- Só usa quando vida < 50%
                params = {
                    damageMultiplier = 1.8,
                    telegraphDuration = 1.5,
                    initialSpeedMultiplier = 2,
                    maxSpeedMultiplier = 8,
                    accelerationRate = 3,       -- Acelera 3x por segundo
                    maxTurnAngle = math.pi / 3, -- 60 graus por segundo
                    stunDuration = 2,
                    maxChargeDuration = 10,     -- Máximo 10 segundos correndo
                    followUpChance = 0.4,       -- 40% de chance de follow-up
                    followUpDistance = 400,     -- Ativa follow-up se jogador > 400px de distância
                    followUpTurnMultiplier = 2, -- Pode virar 2x mais rápido no follow-up
                    playerDetectionRadius = 80, -- Raio para detectar colisão
                    range = 800                 -- Alcance máximo para ativar a habilidade
                }
            }
        },
    }
}

return bosses
