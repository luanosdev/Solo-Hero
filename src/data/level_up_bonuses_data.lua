-- src/data/level_up_bonuses_data.lua
-- Define as possíveis melhorias que o jogador pode obter ao subir de nível.

-- CONVENÇÕES PARA VALORES DE MODIFICADORES:
-- type = "fixed":
--   O 'value' é um número absoluto que será somado diretamente ao atributo base ou ao fixedBonus existente.
--   Ex: { stat = "health", type = "fixed", value = 10 }  => Adiciona 10 HP.
--
-- type = "percentage":
--   O 'value' é um número que representa o percentual direto (ex: 5 para 5%, -2 para -2%).
--   Este valor é geralmente usado para modificar o 'levelBonus' no PlayerState, que o PlayerState
--   normalmente divide por 100 em seus cálculos (ex: 1 + levelBonus.stat / 100).
--   Ex: { stat = "health", type = "percentage", value = 5 } => Aumenta o levelBonus.health em 5 (resultando em +5% HP).
--
-- type = "fixed_percentage_as_fraction":
--   O 'value' DEVE ser a fração decimal correspondente ao percentual desejado.
--   Este valor é geralmente usado para modificar o 'fixedBonus' no PlayerState para atributos
--   que armazenam bônus percentuais como frações.
--   Ex: { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.01 } => Adiciona 0.01 (ou seja, +1%) ao fixedBonus.critChance.
--       (0.50 para 50%, 0.05 para 5%, 0.005 para 0.5%)
--
-- Ao chamar PlayerState:addAttributeBonus(attribute, percentage, fixed):
--   - Modificadores 'percentage' daqui vão para o argumento 'percentage'.
--   - Modificadores 'fixed' e 'fixed_percentage_as_fraction' daqui vão para o argumento 'fixed'.

local Colors = require("src.ui.colors")

---@class BonusPerLevel
---@field stat_key string
---@field stat string
---@field type "fixed" | "percentage" | "fixed_percentage_as_fraction"
---@field value number

---@class LevelUpBonus
---@field id string
---@field name string
---@field description string
---@field image_path string
---@field max_level number
---@field modifiers_per_level BonusPerLevel[]
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
    ["Velocidade de Preenchimento dos Frascos"] = Colors.attribute_colors.potion_fill_rate,

    -- Valores numéricos
    ["positivo"] = Colors.attribute_colors.positive,
    ["negativo"] = Colors.attribute_colors.negative,
    ["neutro"] = Colors.attribute_colors.neutral,
}

LevelUpBonusesData.Bonuses = {
    -- Bônus de Vida
    vitality_1_fixed = {
        id = "vitality_1_fixed",
        name = "Vigor",
        description = "Aumenta a |Vida Máxima| em |30| pontos.",
        image_path = tempIconPath,
        icon = "H+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "health", type = "fixed", value = 30 }
        },
        color = Colors.attribute_colors.max_health
    },
    vitality_2_percent = {
        id = "vitality_2_percent",
        name = "Fortitude",
        description = "Aumenta a |Vida Máxima| em |10%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "health", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.max_health
    },
    vitality_3_combo = {
        id = "vitality_3_combo",
        name = "Robustez",
        description = "Aumenta |Vida Máxima| em |5%| e |Defesa| em |10| pontos.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "health", type = "percentage", value = 5 },
            { stat = "defense", type = "fixed", value = 10 }
        },
        color = Colors.attribute_colors.max_health
    },
    risky_vitality_1 = {
        id = "risky_vitality_1",
        name = "Pacto de Sangue",
        description = "Aumenta a |Vida Máxima| em |50| pontos, mas reduz a |Defesa| em |-15%|.",
        image_path = tempIconPath,
        max_level = 3,
        modifiers_per_level = {
            { stat = "health", type = "fixed", value = 50 },
            { stat = "defense", type = "percentage", value = -5 }
        },
        color = Colors.attribute_colors.max_health
    },

    -- Bônus de Força
    strength_training_1_fixed = {
        id = "strength_training_1_fixed",
        name = "Treino de Força",
        description = "Aumenta a |Força| em |10| pontos.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "strength", type = "fixed", value = 10 }
        },
        color = Colors.attribute_colors.strength
    },
    strength_might_1_percent = {
        id = "strength_might_1_percent",
        name = "Poderio Crescente",
        description = "Aumenta a |Força| em |10%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "strength", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.strength
    },
    strength_burst_1_combo = {
        id = "strength_burst_1_combo",
        name = "Explosão de Força",
        description = "Aumenta |Força| em |5| e |Defesa| em |5| pontos.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "strength", type = "fixed", value = 5 },
            { stat = "defense", type = "fixed", value = 5 }
        },
        color = Colors.attribute_colors.strength
    },

    -- Bônus de Dano/Ataque
    strength_1_percent = {
        id = "strength_1_percent",
        name = "Raiva",
        description = "Aumenta o |Dano| em |10%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "damageMultiplier", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.damage
    },
    speed_attack_1_percent = {
        id = "speed_attack_1_percent",
        name = "Agilidade",
        description = "Aumenta a |Velocidade de Ataque| em |3%|.",
        image_path = tempIconPath,
        max_level = 8,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 3 }
        },
        color = Colors.attribute_colors.attack_speed
    },
    glass_cannon_1 = {
        id = "glass_cannon_1",
        name = "Canhão de Vidro",
        description = "Aumenta |Dano| em |10%| e |Velocidade de Ataque| em |5%|, mas reduz |Vida Máxima| em |-10%|.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "damageMultiplier", type = "percentage", value = 10 },
            { stat = "attackSpeed", type = "percentage", value = 5 },
            { stat = "health", type = "percentage", value = -10 }
        },
        color = Colors.attribute_colors.damage
    },

    -- Bônus Crítico
    precision_1_fixed_fraction = {
        id = "precision_1_fixed_fraction",
        name = "Precisão Afiada",
        description = "Aumenta a |Chance de Crítico| em |10%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "critChance", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.crit_chance
    },
    lethality_1_fixed_multiplier = {
        id = "lethality_1_fixed_multiplier",
        name = "Golpe Devastador",
        description = "Aumenta o |Dano Crítico| em |0.1x|.",
        image_path = "assets/imagens/skills/crit_damage.png",
        icon = "M+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.1 }
        },
        color = Colors.attribute_colors.crit_damage
    },
    gamblers_strike_1 = {
        id = "gamblers_strike_1",
        name = "Aposta Arriscada",
        description = "Aumenta |Chance de Crítico| em |10%| e |Dano Crítico| em |0.2x|, mas reduz |Dano| base em |-10%|.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.10 },
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.20 },
            { stat = "damageMultiplier", type = "percentage", value = -10 }
        },
        color = Colors.attribute_colors.crit_damage
    },

    -- Bônus de Mobilidade
    celerity_1_percent = {
        id = "celerity_1_percent",
        name = "Passos Velozes",
        description = "Aumenta a |Velocidade de Movimento| em |5%|.",
        image_path = tempIconPath,
        max_level = 8,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 5 }
        },
        color = Colors.attribute_colors.move_speed
    },
    haste_1_fixed = {
        id = "haste_1_fixed",
        name = "Ímpeto",
        description = "Aumenta a |Velocidade de Movimento| em |3| pontos.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "fixed", value = 3 }
        },
        color = Colors.attribute_colors.move_speed
    },
    unburdened_1 = {
        id = "unburdened_1",
        name = "Peso Pena",
        description = "Aumenta |Velocidade de Movimento| em |5%|, mas reduz a |Defesa| em |-5| pontos.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 5 },
            { stat = "defense", type = "fixed", value = -5 }
        },
        color = Colors.attribute_colors.move_speed
    },

    -- Bônus de Defesa
    protection_1_fixed = {
        id = "protection_1_fixed",
        name = "Guarda Menor",
        description = "Aumenta a |Defesa| em |10| pontos.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "defense", type = "fixed", value = 10 }
        },
        color = Colors.attribute_colors.defense
    },
    resilience_1_percent = {
        id = "resilience_1_percent",
        name = "Tenacidade",
        description = "Aumenta a |Defesa| em |10%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "defense", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.defense
    },

    -- Bônus de Regeneração e Coleta
    regeneration_1_fixed = {
        id = "regeneration_1_fixed",
        name = "Recuperação Rápida",
        description = "Aumenta |Regeneração de Vida| em |0.5| HP/s.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "healthPerTick", type = "fixed", value = 0.5 }
        },
        color = Colors.attribute_colors.health_per_tick
    },
    regen_delay_1_reduction = {
        id = "regen_delay_1_reduction",
        name = "Prontidão",
        description = "Reduz o delay de |Regeneração de Vida| em |0.5| segundos.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "healthRegenDelay", type = "fixed", value = 0.5 }
        },
        color = Colors.attribute_colors.health_regen_delay
    },
    scavenger_1_fixed = {
        id = "scavenger_1_fixed",
        name = "Magnetismo",
        description = "Aumenta o |Raio de Coleta| em |10| unidades.",
        image_path = tempIconPath,
        max_level = 8,
        modifiers_per_level = {
            { stat = "pickupRadius", type = "fixed", value = 10 }
        },
        color = Colors.attribute_colors.pickup_radius
    },

    -- Bônus Utilitários / Avançados
    chronomancer_1_percent = {
        id = "chronomancer_1_percent",
        name = "Dobra Temporal Menor",
        description = "Reduz a |Recarga de Habilidades| em |5%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "cooldownReduction", type = "percentage", value = 5 }
        },
        color = Colors.attribute_colors.cooldown_reduction
    },
    lucky_star_1_percent = {
        id = "lucky_star_1_percent",
        name = "Estrela da Sorte",
        description = "Aumenta a |Sorte| em |5%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "luck", type = "percentage", value = 5 }
        },
        color = Colors.attribute_colors.luck
    },
    scholarly_pursuit_1 = {
        id = "scholarly_pursuit_1",
        name = "Busca Acadêmica",
        description = "Aumenta |Bônus de Experiência| em |10%|.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "expBonus", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.exp_bonus
    },

    --- Area e alcance
    area_1_percent = {
        id = "area_1_percent",
        name = "Área",
        description = "Aumenta a |Área| em |10%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "attackArea", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.attack_area
    },
    area_3_combo = {
        id = "area_3_combo",
        name = "Área Mortal",
        description = "Aumenta |Área| em |8%| e |Dano| em |5%|.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "attackArea",       type = "percentage", value = 8 },
            { stat = "damageMultiplier", type = "percentage", value = 5 }
        },
        color = Colors.attribute_colors.attack_area
    },
    range_1_percent = {
        id = "range_1_percent",
        name = "Alcance",
        description = "Aumenta o |Alcance| em |10%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "range", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.range
    },
    range_3_combo = {
        id = "range_3_combo",
        name = "Alcance Mortal",
        description = "Aumenta |Alcance| em |8%| e |Dano| em |5%|.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "range",            type = "percentage", value = 8 },
            { stat = "damageMultiplier", type = "percentage", value = 5 }
        },
        color = Colors.attribute_colors.range
    },

    -- Bônus de Ataque Múltiplo
    multi_attack_chance_1 = {
        id = "multi_attack_chance_1",
        name = "Golpes Ecoantes",
        description = "Aumenta a chance de |Ataques Múltiplos| em |10%|.",
        image_path = tempIconPath,
        max_level = 10,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "percentage", value = 10 }
        },
        color = Colors.attribute_colors.multi_attack_chance
    },
    multi_attack_frenzy_1 = {
        id = "multi_attack_frenzy_1",
        name = "Frenesi de Golpes",
        description = "Aumenta a chance de |Ataques Múltiplos| em |0.1x|.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "fixed_percentage_as_fraction", value = 0.10 },
        },
        color = Colors.attribute_colors.multi_attack_chance
    },

    -- Bônus de Dash
    dash_cooldown_reduction_1 = {
        id = "dash_cooldown_reduction_1",
        name = "Passo Rápido",
        description = "Reduz a |Recarga do Dash| em |8%|.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "dashCooldown", type = "percentage", value = -8 }
        },
        color = Colors.attribute_colors.dash_cooldown
    },
    dash_distance_increase_1 = {
        id = "dash_distance_increase_1",
        name = "Salto Longo",
        description = "Aumenta a |Distância do Dash| em |15%|.",
        image_path = tempIconPath,
        max_level = 5,
        modifiers_per_level = {
            { stat = "dashDistance", type = "percentage", value = 15 }
        },
        color = Colors.attribute_colors.dash_distance
    },
    dash_extra_charge_1 = {
        id = "dash_extra_charge_1",
        name = "Carga Extra",
        description = "Adiciona |1| |Carga de Dash|.",
        image_path = tempIconPath,
        max_level = 2, -- Máximo de 2 cargas extras por este bônus
        modifiers_per_level = {
            { stat = "dashCharges", type = "fixed", value = 1 }
        },
        color = Colors.attribute_colors.dash_charges
    },

    -- Bônus do Sistema de Poções
    potion_capacity_1 = {
        id = "potion_capacity_1",
        name = "Capacidade Expandida",
        description = "Adiciona |1| |Frasco de Poção|.",
        image_path = tempIconPath,
        max_level = 3,
        modifiers_per_level = {
            { stat = "potionFlasks", type = "fixed", value = 1 }
        },
        color = Colors.attribute_colors.potion_flasks
    },
    potion_potency_1_fixed = {
        id = "potion_potency_1_fixed",
        name = "Poções Concentradas",
        description = "Aumenta a |Cura da Poção| em |15| HP.",
        image_path = tempIconPath,
        max_level = 8,
        modifiers_per_level = {
            { stat_key = "potion_heal", stat = "potionHealAmount", type = "fixed", value = 15 }
        },
        color = Colors.attribute_colors.potion_heal_amount
    },
    potion_speed_1 = {
        id = "potion_speed_1",
        name = "Destilação Rápida",
        description = "Aumenta a |Velocidade de Preenchimento dos Frascos| em |25%|.",
        image_path = tempIconPath,
        max_level = 8,
        modifiers_per_level = {
            { stat = "potionFillRate", type = "fixed_percentage_as_fraction", value = 0.25 }
        },
        color = Colors.attribute_colors.potion_fill_rate
    },
    potion_healing_synergy_1 = {
        id = "potion_healing_synergy_1",
        name = "Sinergia Curativa",
        description = "Aumenta a |Cura da Poção| em |10%| e a |Bônus de Cura| em |8%|.",
        image_path = tempIconPath,
        max_level = 6,
        modifiers_per_level = {
            { stat = "potionHealAmount", type = "percentage", value = 10 },
            { stat = "healingBonus",     type = "percentage", value = 8 }
        },
        color = Colors.attribute_colors.potion_heal_amount
    },
}

--- Função auxiliar para aplicar modificadores ao PlayerStateController
--- Pode ser chamada pelo LevelUpModal após o jogador escolher uma opção.
---@param stateController PlayerStateController Instância do controlador de estado do jogador
---@param bonusId string O ID do bônus de LevelUpBonusesData.Bonuses que foi escolhido
function LevelUpBonusesData.ApplyBonus(stateController, bonusId)
    local bonusData = LevelUpBonusesData.Bonuses[bonusId]
    if not bonusData then
        print("ERRO [LevelUpBonusesData.ApplyBonus]: Bônus com ID '" .. tostring(bonusId) .. "' não encontrado.")
        return
    end

    if not stateController or not stateController.addAttributeBonus then
        print("ERRO [LevelUpBonusesData.ApplyBonus]: stateController inválido ou não possui addAttributeBonus.")
        return
    end

    print("[LevelUpBonusesData.ApplyBonus] Aplicando bônus: " .. bonusData.name)

    for _, modifier in ipairs(bonusData.modifiers_per_level) do
        local stat = modifier.stat
        local type = modifier.type
        local value = modifier.value

        print(string.format("  - Modificador: stat=%s, type=%s, value=%s", tostring(stat), tostring(type),
            tostring(value)))

        if type == "fixed" then
            stateController:addAttributeBonus(stat, 0, value)
        elseif type == "percentage" then
            -- Este 'percentage' vai para stateController.levelBonus[stat]
            -- E levelBonus espera um valor como 5 para 5%
            stateController:addAttributeBonus(stat, value, 0)
        elseif type == "fixed_percentage_as_fraction" then
            -- Este 'fixed' vai para stateController.fixedBonus[stat]
            -- E fixedBonus para stats como critChance espera uma fração (ex: 0.01 para 1%)
            stateController:addAttributeBonus(stat, 0, value)
        else
            print("AVISO [LevelUpBonusesData.ApplyBonus]: Tipo de modificador desconhecido ('" ..
                tostring(type) .. "') para o stat '" .. tostring(stat) .. "'.")
        end
    end
end

return LevelUpBonusesData
