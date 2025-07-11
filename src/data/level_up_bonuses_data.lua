---------------------------------------------------------------------------------
-- Define as possíveis melhorias que o jogador pode obter ao subir de nível.
---------------------------------------------------------------------------------

local Colors = require("src.ui.colors")

---@class BonusPerLevel
---@field stat_key string
---@field stat string
---@field type "base" | "percentage"
---@field value number

---@class LevelUpBonus
---@field id string
---@field name string
---@field description string
---@field image_path string
---@field max_level number
---@field modifiers_per_level BonusPerLevel[]
---@field is_ultimate? boolean
---@field color Color

---@class LevelUpBonusesData
---@field Bonuses LevelUpBonus[]
---@field KeywordColors table<string, table>
---@field CategoryColors table<string, table>
---@field GetBonusColor fun(bonusData: LevelUpBonus): table
local LevelUpBonusesData = {}
local tempIconPath = "assets/images/skills/attack.png"

-- Cores por categoria de melhoria

-- Cores para palavras-chave nas descrições (estilo LoL)
LevelUpBonusesData.KeywordColors = {
    -- Stats principais
    ["Vida Máxima"] = Colors.attribute_colors.max_health,
    ["Defesa"] = Colors.attribute_colors.defense,
    ["Força"] = Colors.attribute_colors.strength,
    ["Dano"] = Colors.attribute_colors.damage,
    ["Velocidade de Ataque"] = Colors.attribute_colors.attack_speed,
    ["Velocidade de Movimento"] = Colors.attribute_colors.move_speed,

    -- Stats avançados
    ["Chance de Crítico"] = Colors.attribute_colors.crit_chance,
    ["Dano Crítico"] = Colors.attribute_colors.crit_damage,
    ["Ataques Múltiplos"] = Colors.attribute_colors.multi_attack_chance,
    ["Regeneração de Vida"] = Colors.attribute_colors.health_regen,
    ["Sorte"] = Colors.attribute_colors.luck,
    ["Área"] = Colors.attribute_colors.attack_area,
    ["Alcance"] = Colors.attribute_colors.range,
    ["Bonus de Experiência"] = Colors.attribute_colors.exp_bonus,
    ["Raio de Coleta"] = Colors.attribute_colors.pickup_radius,
    ["Recarga de Habilidades"] = Colors.attribute_colors.cooldown_reduction,
    ["Bônus de Cura"] = Colors.attribute_colors.healing_bonus,

    -- Sistemas especiais
    ["Recarga do Dash"] = Colors.attribute_colors.dash_cooldown,
    ["Carga de Dash"] = Colors.attribute_colors.dash_charges,
    ["Distância do Dash"] = Colors.attribute_colors.dash_distance,
    ["Frasco de Poção"] = Colors.attribute_colors.potion_flasks,
    ["Cura da Poção"] = Colors.attribute_colors.potion_heal_amount,
    ["Velocidade de Preenchimento"] = Colors.attribute_colors.potion_fill_rate,

    -- Valores numéricos
    ["positivo"] = Colors.attribute_colors.positive,
    ["negativo"] = Colors.attribute_colors.negative,
    ["neutro"] = Colors.attribute_colors.neutral,
}

LevelUpBonusesData.Bonuses = {
    -- Bônus de Vida
    vitality_base = {
        id = "vitality_base",
        name = "Vitalidade",
        description = "Aumenta a |Vida Máxima| base em |30|.",
        image_path = "assets/images/skills/vitality.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "maxHealth", type = "base", value = 30 }
        },
        color = Colors.attribute_colors.max_health
    },
    vitality_percent = {
        id = "vitality_percent",
        name = "Fortitude",
        description = "Aumenta a |Vida Máxima| em |10%|.",
        image_path = "assets/images/skills/vitality.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "maxHealth", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.max_health
    },
    risky_vitality = {
        id = "risky_vitality",
        name = "Pacto de Sangue",
        description = "Aumenta a |Vida Máxima| base em |50|, mas reduz a |Defesa| em |-15%|.",
        image_path = "assets/images/skills/vitality.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "maxHealth", type = "base",       value = 50 },
            { stat = "defense",   type = "percentage", value = -5 }
        },
        color = Colors.attribute_colors.max_health
    },

    -- Bônus de Força
    strength_base = {
        id = "strength_base",
        name = "Musculação",
        description = "Aumenta a |Força| base em |10|.",
        image_path = "assets/images/skills/strength.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "strength", type = "base", value = 10 }
        },
        color = Colors.attribute_colors.strength
    },
    strength_percent = {
        id = "strength_percent",
        name = "Calistenia",
        description = "Aumenta a |Força| em |10%|.",
        image_path = "assets/images/skills/strength.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "strength", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.strength
    },
    strength_combo = {
        id = "strength_combo",
        name = "Explosão de Força",
        description = "Aumenta |Força| base em |5| e |Defesa| base em |5|.",
        image_path = "assets/images/skills/strength_combo.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "strength", type = "base", value = 5 },
            { stat = "defense",  type = "base", value = 5 }
        },
        color = Colors.attribute_colors.strength
    },
    -- Bônus de Dano/Ataque
    damage_percent = {
        id = "damage_percent",
        name = "Raiva",
        description = "Aumenta o |Dano| em |10%|.",
        image_path = "assets/images/skills/damage.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "damage", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.damage
    },
    damage_base = {
        id = "damage_base",
        name = "Fúria",
        description = "Aumenta o |Dano| base em |20|.",
        image_path = "assets/images/skills/damage.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "damage", type = "base", value = 20 }
        },
        color = Colors.attribute_colors.damage
    },
    attack_speed_percent = {
        id = "attack_speed_percent",
        name = "Agilidade",
        description = "Aumenta a |Velocidade de Ataque| em |3%|.",
        image_path = "assets/images/skills/attack_speed.png",
        max_level = 8,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 3 }
        },
        color = Colors.attribute_colors.attack_speed
    },
    attack_speed_base = {
        id = "attack_speed_base",
        name = "Destreza",
        description = "Aumenta a |Velocidade de Ataque| base em |0.2|.",
        image_path = "assets/images/skills/attack_speed.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "base", value = 0.2 }
        },
        color = Colors.attribute_colors.attack_speed
    },
    glass_cannon = {
        id = "glass_cannon",
        name = "Canhão de Vidro",
        description = "Aumenta |Dano| em |10%| e |Velocidade de Ataque| em |5%|, mas reduz |Vida Máxima| em |-10%|.",
        image_path = "assets/images/skills/glass_cannon.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "damage",      type = "percentage", value = 10 },
            { stat = "attackSpeed", type = "percentage", value = 5 },
            { stat = "maxHealth",   type = "percentage", value = -10 }
        },
        color = Colors.attribute_colors.damage
    },
    -- Bônus Crítico
    crit_chance_percent = {
        id = "crit_chance_percent",
        name = "Precisão Afiada",
        description = "Aumenta a |Chance de Crítico| em |10%|.",
        image_path = "assets/images/skills/crit_chance.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "critChance", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.crit_chance
    },
    crit_chance_base = {
        id = "crit_chance_base",
        name = "Precisão",
        description = "Aumenta a |Chance de Crítico| base em |0.1|.",
        image_path = "assets/images/skills/crit_chance.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "critChance", type = "base", value = 0.1 }
        },
        color = Colors.attribute_colors.crit_chance
    },
    crit_damage_base = {
        id = "crit_damage_base",
        name = "Golpe Devastador",
        description = "Aumenta o |Dano Crítico| base em |0.1|.",
        image_path = "assets/images/skills/crit_damage.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "critDamage", type = "base", value = 0.1 }
        },
        color = Colors.attribute_colors.crit_damage
    },
    gamblers_strike = {
        id = "gamblers_strike",
        name = "Aposta Arriscada",
        description =
        "Aumenta |Chance de Crítico| base em |0.2| e |Dano Crítico| base em |0.2|, mas reduz |Dano| em |-10%|.",
        image_path = "assets/images/skills/gamblers_strike.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "critChance", type = "base",       value = 0.2 },
            { stat = "critDamage", type = "base",       value = 0.2 },
            { stat = "damage",     type = "percentage", value = -10 }
        },
        color = Colors.attribute_colors.crit_damage
    },

    -- Bônus de Mobilidade
    move_speed_percent = {
        id = "move_speed_percent",
        name = "Passos Velozes",
        description = "Aumenta a |Velocidade de Movimento| em |5%|.",
        image_path = "assets/images/skills/move_speed.png",
        max_level = 8,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 5 }
        },
        color = Colors.attribute_colors.move_speed
    },
    move_speed_base = {
        id = "move_speed_base",
        name = "Ímpeto",
        description = "Aumenta a |Velocidade de Movimento| base em |0.2|m/s.",
        image_path = "assets/images/skills/move_speed.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "base", value = 0.2 }
        },
        color = Colors.attribute_colors.move_speed
    },
    unburdened = {
        id = "unburdened",
        name = "Peso Pena",
        description = "Aumenta |Velocidade de Movimento| em |10%|, mas reduz a |Defesa| em |-10%|.",
        image_path = "assets/images/skills/unburdened.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 10 },
            { stat = "defense",   type = "percentage", value = -10 }
        },
        color = Colors.attribute_colors.move_speed
    },

    -- Bônus de Defesa
    defense_base = {
        id = "defense_base",
        name = "Constituição",
        description = "Aumenta a |Defesa| base em |10|.",
        image_path = "assets/images/skills/defense.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "defense", type = "base", value = 10 }
        },
        color = Colors.attribute_colors.defense
    },
    defense_percent = {
        id = "defense_percent",
        name = "Tenacidade",
        description = "Aumenta a |Defesa| em |10%|.",
        image_path = "assets/images/skills/defense.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "defense", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.defense
    },

    -- Bônus de Regeneração e Coleta
    regeneration_fixed = {
        id = "regeneration_fixed",
        name = "Recuperação Rápida",
        description = "Aumenta |Regeneração de Vida| em |0.5| HP/s.",
        image_path = "assets/images/skills/regeneration_fixed.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "healthPerTick", type = "base", value = 0.5 }
        },
        color = Colors.attribute_colors.health_per_tick
    },
    regen_delay_reduction = {
        id = "regen_delay_reduction",
        name = "Prontidão",
        description = "Reduz o delay de |Regeneração de Vida| em |0.5| segundos.",
        image_path = "assets/images/skills/regen_delay_reduction.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "healthRegenDelay", type = "base", value = 0.5 }
        },
        color = Colors.attribute_colors.health_regen_delay
    },
    pickup_radius_base = {
        id = "pickup_radius_base",
        name = "Magnetismo",
        description = "Aumenta o |Raio de Coleta| em  |1.0|m.",
        image_path = "assets/images/skills/scavenger.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "pickupRadius", type = "base", value = 1.0 }
        },
        color = Colors.attribute_colors.pickup_radius
    },
    pickup_radius_percent = {
        id = "pickup_radius_percent",
        name = "Magnetismo",
        description = "Aumenta o |Raio de Coleta| em |10%|.",
        image_path = "assets/images/skills/scavenger.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "pickupRadius", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.pickup_radius
    },

    -- Bônus Utilitários / Avançados
    cooldown_reduction = {
        id = "cooldown_reduction",
        name = "Dobra Temporal",
        description = "Reduz a |Recarga de Habilidades| em |5%|.",
        image_path = "assets/images/skills/cooldown_reduction.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "cooldownReduction", type = "percentage", value = 5 }
        },
        color = Colors.attribute_colors.cooldown_reduction
    },
    luck_percent = {
        id = "luck_percent",
        name = "Estrela da Sorte",
        description = "Aumenta a |Sorte| em |5%|.",
        image_path = "assets/images/skills/luck.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "luck", type = "percentage", value = 5 }
        },
        color = Colors.attribute_colors.luck
    },
    exp_bonus_percent = {
        id = "exp_bonus_percent",
        name = "Busca Acadêmica",
        description = "Aumenta |Bônus de Experiência| em |10%|.",
        image_path = "assets/images/skills/exp_bonus.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "expBonus", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.exp_bonus
    },

    --- Area e alcance
    attack_area_percent = {
        id = "attack_area_percent",
        name = "Área",
        description = "Aumenta a |Área| em |10%|.",
        image_path = "assets/images/skills/area.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "attackArea", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.attack_area
    },
    attack_area_combo = {
        id = "attack_area_combo",
        name = "Área Mortal",
        description = "Aumenta |Área| em |8%| e |Dano| base em |10|.",
        image_path = "assets/images/skills/area.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "attackArea", type = "percentage", value = 8 },
            { stat = "damage",     type = "base",       value = 10 }
        },
        color = Colors.attribute_colors.attack_area
    },
    range_percent = {
        id = "range_percent",
        name = "Alcance",
        description = "Aumenta o |Alcance| em |10%|.",
        image_path = "assets/images/skills/range.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "range", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.range
    },
    range_combo = {
        id = "range_combo",
        name = "Alcance Mortal",
        description = "Aumenta |Alcance| em |8%| e |Dano| base em |10|.",
        image_path = "assets/images/skills/range.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "range",  type = "percentage", value = 8 },
            { stat = "damage", type = "base",       value = 10 }
        },
        color = Colors.attribute_colors.range
    },

    -- Bônus de Ataque Múltiplo
    multi_attack_chance_percent = {
        id = "multi_attack_chance_percent",
        name = "Golpes Ecoantes",
        description = "Aumenta a chance de |Ataques Múltiplos| em |10%|.",
        image_path = "assets/images/skills/multi_attack_chance.png",
        max_level = 10,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.multi_attack_chance
    },
    multi_attack_frenzy_percent = {
        id = "multi_attack_frenzy_percent",
        name = "Frenesi de Golpes",
        description = "Aumenta a chance de |Ataques Múltiplos| base em |0.1|.",
        image_path = "assets/images/skills/multi_attack_frenzy.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "base", value = 0.1 },
        },
        color = Colors.attribute_colors.multi_attack_chance
    },

    -- Bônus de Dash
    dash_cooldown_reduction = {
        id = "dash_cooldown_reduction",
        name = "Passo Rápido",
        description = "Reduz a |Recarga do Dash| em |8%|.",
        image_path = "assets/images/skills/dash_cooldown_reduction.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "dashCooldown", type = "percentage", value = 8 }
        },
        color = Colors.attribute_colors.dash_cooldown
    },
    dash_distance_increase = {
        id = "dash_distance_increase",
        name = "Salto Longo",
        description = "Aumenta a |Distância do Dash| em |15%|.",
        image_path = "assets/images/skills/dash_distance_increase.png",
        max_level = 5,
        modifiers_per_level = {
            { stat = "dashDistance", type = "percentage", value = 15 }
        },
        color = Colors.attribute_colors.dash_distance
    },
    dash_extra_charge = {
        id = "dash_extra_charge",
        name = "Carga Extra",
        description = "Adiciona |1| |Carga de Dash|.",
        image_path = "assets/images/skills/dash_extra_charge.png",
        max_level = 2, -- Máximo de 2 cargas extras por este bônus
        modifiers_per_level = {
            { stat = "dashCharges", type = "base", value = 1 }
        },
        color = Colors.attribute_colors.dash_charges
    },

    -- Bônus do Sistema de Poções
    potion_flasks_base = {
        id = "potion_flasks_base",
        name = "Capacidade Expandida",
        description = "Adiciona |1| |Frasco de Poção|.",
        image_path = "assets/images/skills/potion_flasks.png",
        max_level = 3,
        modifiers_per_level = {
            { stat = "potionFlasks", type = "base", value = 1 }
        },
        color = Colors.attribute_colors.potion_flasks
    },
    potion_heal_amount_base = {
        id = "potion_heal_amount_base",
        name = "Poções Concentradas",
        description = "Aumenta a |Cura da Poção| em |15| HP.",
        image_path = "assets/images/skills/potion_heal_amount.png",
        max_level = 8,
        modifiers_per_level = {
            { stat = "potionHealAmount", type = "base", value = 15 }
        },
        color = Colors.attribute_colors.potion_heal_amount
    },
    potion_speed_1 = {
        id = "potion_speed_1",
        name = "Destilação Rápida",
        description = "Aumenta a |Velocidade de Preenchimento| dos |Frasco de Poção| em |25%|.",
        image_path = "assets/images/skills/potion_speed.png",
        max_level = 8,
        modifiers_per_level = {
            { stat = "potionFillRate", type = "percentage", value = 25 }
        },
        color = Colors.attribute_colors.potion_fill_rate
    },
    -- ========================================
    -- MELHORIAS ULTIMATE - RANK S
    -- ========================================
    -- Melhorias especiais desbloqueadas quando o jogador atinge max level em uma melhoria específica (um-para-um)

    -- Ultimates de Vida
    ultimate_vitality_base = {
        id = "ultimate_vitality_base",
        name = "Vigor Supremo",
        description =
        "O domínio absoluto da vitalidade. Aumenta a |Vida Máxima| base em |100| e a |Regeneração de Vida| base em |2|.",
        image_path = "assets/images/skills/ultimate_vitality_base.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "vitality_base" },
        modifiers_per_level = {
            { stat = "maxHealth",     type = "base", value = 100 },
            { stat = "healthPerTick", type = "base", value = 2 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_vitality_percent = {
        id = "ultimate_vitality_percent",
        name = "Fortitude Eterna",
        description =
        "A resistência transcendente. Aumenta a |Vida Máxima| em |50%| e o |Bônus de Cura| em |30%|.",
        image_path = "assets/images/skills/ultimate_vitality_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "vitality_percent" },
        modifiers_per_level = {
            { stat = "maxHealth",    type = "percentage", value = 50 },
            { stat = "healingBonus", type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_risky_vitality = {
        id = "ultimate_risky_vitality",
        name = "Pacto Imortal",
        description =
        "O sangue derramado retorna como poder. Aumenta a |Vida Máxima| base em |150|, a |Defesa| em |50%| e o |Dano| em |30%|.",
        image_path = "assets/images/skills/ultimate_risky_vitality.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "risky_vitality" },
        modifiers_per_level = {
            { stat = "maxHealth", type = "base",       value = 150 },
            { stat = "defense",   type = "percentage", value = 50 },
            { stat = "damage",    type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Força
    ultimate_strength_base = {
        id = "ultimate_strength_base",
        name = "Aptidão Física",
        description =
        "O ápice do condicionamento físico. Aumenta a |Força| base em |20| e a |Velocidade de Ataque| base em |1.0|.",
        image_path = "assets/images/skills/ultimate_strength_base.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "strength_base" },
        modifiers_per_level = {
            { stat = "strength",    type = "base", value = 20 },
            { stat = "attackSpeed", type = "base", value = 1.0 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_strength_percent = {
        id = "ultimate_strength_percent",
        name = "Força Suprema",
        description = "A força sem limites. Aumenta a |Força| em |50%| e o |Dano| em |20%|.",
        image_path = "assets/images/skills/ultimate_strength_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "strength_percent" },
        modifiers_per_level = {
            { stat = "strength", type = "percentage", value = 50 },
            { stat = "damage",   type = "percentage", value = 20 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_strength_combo = {
        id = "ultimate_strength_combo",
        name = "Explosão Suprema",
        description =
        "A combinação perfeita de força e defesa. Aumenta a |Força| base em |30|, a |Defesa| base em |30| e o |Dano| em |25%|.",
        image_path = "assets/images/skills/ultimate_strength_combo.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "strength_combo" },
        modifiers_per_level = {
            { stat = "strength", type = "base",       value = 30 },
            { stat = "defense",  type = "base",       value = 30 },
            { stat = "damage",   type = "percentage", value = 25 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Dano
    ultimate_damage_percent = {
        id = "ultimate_damage_percent",
        name = "Odio Eterno",
        description = "O ódio no seu mais puro aspecto. Aumenta o |Dano| em |50%| e a |Chance de Crítico| em |30%|.",
        image_path = "assets/images/skills/ultimate_damage_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "damage_percent" },
        modifiers_per_level = {
            { stat = "damage",     type = "percentage", value = 50 },
            { stat = "critChance", type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_damage_base = {
        id = "ultimate_damage_base",
        name = "Dia de Fúria",
        description =
        "A fúria que nunca se extingue. Aumenta o |Dano| base em |50| e a |Chance de Crítico| base em |0.5|.",
        image_path = "assets/images/skills/ultimate_damage_base.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "damage_base" },
        modifiers_per_level = {
            { stat = "damage",     type = "base", value = 50 },
            { stat = "critChance", type = "base", value = 0.5 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_speed_attack_percent = {
        id = "ultimate_speed_attack_percent",
        name = "Agilidade Suprema",
        description =
        "A velocidade transcendente. Aumenta a |Velocidade de Ataque| em |20%| e a |Velocidade de Movimento| em |30%|.",
        image_path = "assets/images/skills/ultimate_speed_attack_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "attack_speed_percent" },
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 20 },
            { stat = "moveSpeed",   type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_speed_attack_base = {
        id = "ultimate_speed_attack_base",
        name = "Ataque Relâmpago",
        description =
        "Eu sou a velocidade. Aumenta a |Velocidade de Ataque| base em |2.0| e a |Velocidade de Movimento| em |30%|.",
        image_path = "assets/images/skills/ultimate_speed_attack_base.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "attack_speed_base" },
        modifiers_per_level = {
            { stat = "attackSpeed", type = "base",       value = 2.0 },
            { stat = "moveSpeed",   type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_glass_cannon = {
        id = "ultimate_glass_cannon",
        name = "Renascimento da Fênix",
        description =
        "O que não te mata, te torna mais forte. Aumenta o |Dano Crítico| em |+50%|, o |Dano| base em |100| e a |Vida Máxima| em |+200|.",
        image_path = "assets/images/skills/ultimate_glass_cannon.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "glass_cannon" },
        modifiers_per_level = {
            { stat = "critDamage", type = "percentage", value = 50 },
            { stat = "damage",     type = "base",       value = 100 },
            { stat = "maxHealth",  type = "base",       value = 200 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates Crítico
    ultimate_crit_chance_base = {
        id = "ultimate_crit_chance_base",
        name = "Visão Suprema",
        description =
        "A visão de caçador. Aumenta a |Chance de Crítico| base em |0.5| e a |Sorte| em |30%|.",
        image_path = "assets/images/skills/ultimate_crit_chance_base.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "crit_chance_base" },
        modifiers_per_level = {
            { stat = "critChance", type = "base",       value = 0.5 },
            { stat = "luck",       type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_crit_chance_percent = {
        id = "ultimate_crit_chance_percent",
        name = "Precisão Absoluta",
        description =
        "A mira perfeita. Aumenta a |Chance de Crítico| em |50%| e a |Velocidade de Ataque| em |30%|.",
        image_path = "assets/images/skills/ultimate_crit_chance_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "crit_chance_percent" },
        modifiers_per_level = {
            { stat = "critChance",  type = "percentage", value = 50 },
            { stat = "attackSpeed", type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_crit_damage_base = {
        id = "ultimate_crit_damage_base",
        name = "Golpe Mortal",
        description =
        "A forma definitiva de matar. Aumenta o |Dano Crítico| base em |0.5| e a |Chance de Crítico| base em |1.0|.",
        image_path = "assets/images/skills/ultimate_crit_damage_base.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "crit_damage_base" },
        modifiers_per_level = {
            { stat = "critDamage", type = "base", value = 0.5 },
            { stat = "critChance", type = "base", value = 1.0 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_gamblers_strike = {
        id = "ultimate_gamblers_strike",
        name = "Frio e Calculista",
        description =
        "Nunca se tratou apenas de sorte. Aumenta a |Chance de Crítico| base em |1.0|, o |Dano Crítico| base em |1.0| e o |Dano| em |50%|.",
        image_path = "assets/images/skills/ultimate_gamblers_strike.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "gamblers_strike" },
        modifiers_per_level = {
            { stat = "critChance", type = "base",       value = 1.0 },
            { stat = "critDamage", type = "base",       value = 1.0 },
            { stat = "damage",     type = "percentage", value = 50 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Mobilidade
    ultimate_move_speed_percent = {
        id = "ultimate_move_speed_percent",
        name = "Aquiles",
        description =
        "A velocidade divina. Aumenta a |Velocidade de Movimento| em |25%| e adiciona |2| |Cargas de Dash|.",
        image_path = "assets/images/skills/ultimate_move_speed_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "move_speed_percent" },
        modifiers_per_level = {
            { stat = "moveSpeed",   type = "percentage", value = 25 },
            { stat = "dashCharges", type = "base",       value = 2 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_move_speed_base = {
        id = "ultimate_move_speed_base",
        name = "Ímpeto Supremo",
        description =
        "A pressa absoluta. Aumenta a |Velocidade de Movimento| base em |5|m/s e a |Recarga do Dash| em |-30%|.",
        image_path = "assets/images/skills/ultimate_move_speed_base.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "move_speed_base" },
        modifiers_per_level = {
            { stat = "moveSpeed",    type = "base",       value = 15 },
            { stat = "dashCooldown", type = "percentage", value = -30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_unburdened = {
        id = "ultimate_unburdened",
        name = "Arcanjo do Vento",
        description =
        "Liberdade absoluta do peso. Aumenta a |Velocidade de Movimento| em |30%|, a |Defesa| base em |30| e a |Velocidade de Ataque| em |25%|.",
        image_path = "assets/images/skills/ultimate_unburdened.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "unburdened" },
        modifiers_per_level = {
            { stat = "moveSpeed",   type = "percentage", value = 30 },
            { stat = "defense",     type = "base",       value = 30 },
            { stat = "attackSpeed", type = "percentage", value = 25 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Defesa
    ultimate_defense_base = {
        id = "ultimate_defense_base",
        name = "Guarda Suprema",
        description = "A proteção absoluta. Aumenta a |Defesa| base em |50| e a |Vida Máxima| em |30%|.",
        image_path = "assets/images/skills/ultimate_defense_base.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "defense_base" },
        modifiers_per_level = {
            { stat = "defense",   type = "base",       value = 50 },
            { stat = "maxHealth", type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_defense_percent = {
        id = "ultimate_defense_percent",
        name = "Escudo Eterno",
        description =
        "A resistência infinita. Aumenta a |Defesa| em |50%| e a |Regeneração de Vida| em |50%|.",
        image_path = "assets/images/skills/ultimate_defense_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "defense_percent" },
        modifiers_per_level = {
            { stat = "defense",       type = "percentage", value = 50 },
            { stat = "healthPerTick", type = "percentage", value = 50 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Área e Alcance
    ultimate_attack_area_percent = {
        id = "ultimate_attack_area_percent",
        name = "Golpe Impactante",
        description = "Uma cratera no chão a cada golpe. Aumenta a |Área| em |50%| e o |Dano| em |25%|.",
        image_path = "assets/images/skills/ultimate_attack_area_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "attack_area_percent" },
        modifiers_per_level = {
            { stat = "attackArea", type = "percentage", value = 50 },
            { stat = "damage",     type = "percentage", value = 25 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_attack_area_combo = {
        id = "ultimate_attack_area_combo",
        name = "Campo de Morte Supremo",
        description =
        "Os destroços não são o único resultado. Aumenta a |Área| em |40%|, o |Dano| em |30%| e a |Chance de Crítico| em |20%|.",
        image_path = "assets/images/skills/ultimate_attack_area_combo.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "attack_area_combo" },
        modifiers_per_level = {
            { stat = "attackArea", type = "percentage", value = 40 },
            { stat = "damage",     type = "percentage", value = 30 },
            { stat = "critChance", type = "percentage", value = 20 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_range_percent = {
        id = "ultimate_range_percent",
        name = "Alcance Infinito",
        description = "A distância transcendente. Aumenta o |Alcance| em |50%| e o |Dano| em |25%|.",
        image_path = "assets/images/skills/ultimate_range_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "range_percent" },
        modifiers_per_level = {
            { stat = "range",  type = "percentage", value = 50 },
            { stat = "damage", type = "percentage", value = 25 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_range_combo = {
        id = "ultimate_range_combo",
        name = "Deus Atirador",
        description =
        "A precisão divina. Aumenta o |Alcance| em |40%|, o |Dano| em |30%| e a |Chance de Crítico| em |25%|.",
        image_path = "assets/images/skills/ultimate_range_combo.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "range_combo" },
        modifiers_per_level = {
            { stat = "range",      type = "percentage", value = 40 },
            { stat = "damage",     type = "percentage", value = 30 },
            { stat = "critChance", type = "percentage", value = 25 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Ataque Múltiplo
    ultimate_multi_attack_chance_percent = {
        id = "ultimate_multi_attack_chance_percent",
        name = "Ecos Supremos",
        description =
        "Os golpes se multiplicam quase que infinitamente. Aumenta a |Chance de Ataques Múltiplos| em |50%| e a |Velocidade de Ataque| em |25%|.",
        image_path = "assets/images/skills/ultimate_multi_attack_chance_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "multi_attack_chance_percent" },
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "percentage", value = 50 },
            { stat = "attackSpeed",       type = "percentage", value = 25 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_multi_attack_frenzy_percent = {
        id = "ultimate_multi_attack_frenzy_percent",
        name = "Chama Frenética",
        description =
        "O frenesi absoluto. Aumenta a |Chance de Ataques Múltiplos| base em |0.5| e o |Dano| em |30%|.",
        image_path = "assets/images/skills/ultimate_multi_attack_frenzy_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "multi_attack_frenzy_percent" },
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "base",       value = 0.5 },
            { stat = "damage",            type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Utilitários
    ultimate_cooldown_reduction_percent = {
        id = "ultimate_cooldown_reduction_percent",
        name = "Mago do Tempo",
        description =
        "Domínio temporal absoluto. Aumenta a |Recarga de Habilidades| base em |1.0|.",
        image_path = "assets/images/skills/ultimate_cooldown_reduction_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "cooldown_reduction" },
        modifiers_per_level = {
            { stat = "cooldownReduction", type = "base", value = 1.0 },
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_lucky_percent = {
        id = "ultimate_lucky_percent",
        name = "Herdeiro Rico",
        description = "A sorte absoluta. Aumenta a |Sorte| em |50%| e o |Raio de Coleta| em |50%|.",
        image_path = "assets/images/skills/ultimate_lucky_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "luck_percent" },
        modifiers_per_level = {
            { stat = "luck",         type = "percentage", value = 50 },
            { stat = "pickupRadius", type = "percentage", value = 50 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_exp_bonus_percent = {
        id = "ultimate_exp_bonus_percent",
        name = "Fruto Proibido",
        description =
        "Distinção do que é o certo e do que é errado. Aumenta o |Bônus de Experiência| base em |1.0| e o |Raio de Coleta| em |5|m.",
        image_path = "assets/images/skills/ultimate_exp_bonus_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "exp_bonus_percent" },
        modifiers_per_level = {
            { stat = "expBonus",     type = "base", value = 1.0 },
            { stat = "pickupRadius", type = "base", value = 5 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_pickup_radius_percent = {
        id = "ultimate_pickup_radius_percent",
        name = "Magnetismo Supremo",
        description = "A atração absoluta. Aumenta o |Raio de Coleta| em |50%| e o |Bônus de Experiência| em |20%|.",
        image_path = "assets/images/skills/ultimate_pickup_radius_percent.png",
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "pickup_radius_percent", "pickup_radius_base" },
        modifiers_per_level = {
            { stat = "pickupRadius", type = "percentage", value = 50 },
            { stat = "expBonus",     type = "percentage", value = 20 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Dash
    ultimate_dash_cooldown_reduction = {
        id = "ultimate_dash_cooldown_reduction",
        name = "Passo Instantâneo",
        description = "A velocidade absoluta. Aumenta a |Recarga do Dash| em |-40%| e a |Velocidade de Movimento| em |20%|. Como um raio.",
        image_path = tempIconPath,
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "dash_cooldown_reduction" },
        modifiers_per_level = {
            { stat = "dashCooldown", type = "percentage", value = -40 },
            { stat = "moveSpeed",    type = "percentage", value = 20 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_dash_distance_increase = {
        id = "ultimate_dash_distance_increase",
        name = "Salto Dimensional",
        description =
        "A distância transcendente. Aumenta a |Distância do Dash| em |75%| e a |Carga de Dash| base em |1|. Atravesse dimensões.",
        image_path = tempIconPath,
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "dash_distance_increase" },
        modifiers_per_level = {
            { stat = "dashDistance", type = "percentage", value = 75 },
            { stat = "dashCharges",  type = "base",       value = 1 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_dash_extra_charge = {
        id = "ultimate_dash_extra_charge",
        name = "Carga Infinita",
        description = "Cargas ilimitadas. Aumenta a |Cargas de Dash| base em |3| e a |Recarga do Dash| em |-20%|. A mobilidade perfeita.",
        image_path = tempIconPath,
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "dash_extra_charge" },
        modifiers_per_level = {
            { stat = "dashCharges",  type = "base",       value = 3 },
            { stat = "dashCooldown", type = "percentage", value = -20 }
        },
        color = Colors.rankDetails.S.text
    },

    -- Ultimates de Poções
    ultimate_potion_capacity_base = {
        id = "ultimate_potion_capacity_base",
        name = "Capacidade Ilimitada",
        description = "Frascos infinitos. Aumenta a |Capacidade de Poção| base em |3| e o |Bônus de Cura| em |30%|. Nunca fique sem recursos.",
        image_path = tempIconPath,
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "potion_flasks_base" },
        modifiers_per_level = {
            { stat = "potionFlasks",     type = "base",       value = 3 },
            { stat = "potionHealAmount", type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_potion_potency_base = {
        id = "ultimate_potion_potency_base",
        name = "Poções Divinas",
        description = "A cura suprema. Aumenta a |Cura da Poção| base em |75| HP e o |Bônus de Cura| em |25%|. Elixires dos deuses.",
        image_path = tempIconPath,
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "potion_heal_amount_base" },
        modifiers_per_level = {
            { stat = "potionHealAmount", type = "base",       value = 75 },
            { stat = "healingBonus",     type = "percentage", value = 25 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_potion_speed = {
        id = "ultimate_potion_speed",
        name = "Destilação Instantânea",
        description =
        "A velocidade alquímica suprema. Aumenta a |Velocidade de Preenchimento| em |125%| e a |Cura da Poção| em |20%|. Alquimia instantânea.",
        image_path = tempIconPath,
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "potion_speed" },
        modifiers_per_level = {
            { stat = "potionFillRate",   type = "percentage", value = 125 },
            { stat = "potionHealAmount", type = "percentage", value = 20 }
        },
        color = Colors.rankDetails.S.text
    },


    -- Ultimates de Regeneração
    ultimate_regeneration_base = {
        id = "ultimate_regeneration_base",
        name = "Recuperação Suprema",
        description = "A regeneração divina. Aumenta a |Regeneração de Vida| base em |2.5| e a |Vida Máxima| em |30%|. A vida eterna.",
        image_path = tempIconPath,
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "regeneration_fixed" },
        modifiers_per_level = {
            { stat = "healthPerTick", type = "base",       value = 2.5 },
            { stat = "maxHealth",     type = "percentage", value = 30 }
        },
        color = Colors.rankDetails.S.text
    },
    ultimate_regen_delay_reduction = {
        id = "ultimate_regen_delay_reduction",
        name = "Prontidão Absoluta",
        description =
        "A resposta instantânea. Aumenta o |Delay de Regeneração| em |-2.5| segundos e a |Regeneração de Vida| em |50%|. A cura imediata.",
        image_path = tempIconPath,
        max_level = 1,
        is_ultimate = true,
        base_bonuses = { "regen_delay_reduction" },
        modifiers_per_level = {
            { stat = "healthRegenDelay", type = "base",       value = -2.5 },
            { stat = "healthPerTick",    type = "percentage", value = 50 }
        },
        color = Colors.rankDetails.S.text
    },
}

--- Função auxiliar para aplicar modificadores ao PlayerStateController
--- Pode ser chamada pelo LevelUpModal após o jogador escolher uma opção.
---@param stateController PlayerStateController Instância do controlador de estado do jogador
---@param bonusId string O ID do bônus de LevelUpBonusesData.Bonuses que foi escolhido
function LevelUpBonusesData.ApplyBonus(stateController, bonusId)
    local bonusData = LevelUpBonusesData.Bonuses[bonusId]
    if not bonusData then
        error("ERRO [LevelUpBonusesData.ApplyBonus]: Bônus com ID '" .. tostring(bonusId) .. "' não encontrado.")
    end

    if not stateController then
        error("ERRO [LevelUpBonusesData.ApplyBonus]: stateController inválido ou não possui addAttributeBonus.")
    end

    if bonusData.is_ultimate then
        Logger.info(
            "level_up_bonuses_data.apply_bonus.ultimate",
            "[LevelUpBonusesData.ApplyBonus] ✦ APLICANDO MELHORIA ULTIMATE: " .. bonusData.name .. " ✦"
        )
    else
        Logger.info(
            "level_up_bonuses_data.apply_bonus.normal",
            "[LevelUpBonusesData.ApplyBonus] Aplicando bônus: " .. bonusData.name
        )
    end

    for _, modifier in ipairs(bonusData.modifiers_per_level) do
        local stat = modifier.stat
        local type = modifier.type
        local value = modifier.value

        Logger.info(
            "level_up_bonuses_data.apply_bonus.modifier",
            string.format("  - Modificador: stat=%s, type=%s, value=%s", tostring(stat), tostring(type),
                tostring(value))
        )

        if type == "base" then
            stateController:addBaseBonus(stat, value)
        elseif type == "percentage" then
            -- Este 'percentage' vai para stateController.levelBonus[stat]
            -- E levelBonus espera um valor como 5 para 5%
            stateController:addMultiplierBonus(stat, value)
        else
            error("ERRO [LevelUpBonusesData.ApplyBonus]: Tipo de modificador desconhecido ('" ..
                tostring(type) .. "') para o stat '" .. tostring(stat) .. "'.")
        end
    end
end

return LevelUpBonusesData
