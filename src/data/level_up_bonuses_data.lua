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

local LevelUpBonusesData = {}

LevelUpBonusesData.Bonuses = {
    -- Bônus de Vida
    vitality_1_fixed = {
        id = "vitality_1_fixed",
        name = "Vigor",
        description_template = "Aumenta a Vida Máxima em 30.",
        icon = "H+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "health", type = "fixed", value = 30 } -- +15 HP fixo por nível
        },
        tags = { "defensivo", "vida", "fixo" }
    },
    vitality_2_percent = {
        id = "vitality_2_percent",
        name = "Fortitude",
        description_template = "Aumenta a Vida Máxima em 10%.",
        icon = "H%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "health", type = "percentage", value = 10 } -- +10% HP por nível (para levelBonus)
        },
        tags = { "defensivo", "vida", "percentual" }
    },
    vitality_3_combo = {
        id = "vitality_3_combo",
        name = "Robustez",
        description_template = "Aumenta Vida Máx. em 5% e Defesa em 10.",
        icon = "H*",
        max_level = 5,
        modifiers_per_level = {
            { stat = "health",  type = "percentage", value = 5 },
            { stat = "defense", type = "fixed",      value = 10 }
        },
        tags = { "defensivo", "vida", "defesa", "combo" }
    },
    risky_vitality_1 = {
        id = "risky_vitality_1",
        name = "Pacto de Sangue",
        description_template = "Aumenta a Vida Máxima em 50 e reduz a Defesa em -5%.",
        icon = "H!",
        max_level = 3,
        modifiers_per_level = {
            { stat = "health",  type = "fixed",      value = 50 },
            { stat = "defense", type = "percentage", value = -5 } -- -5% Defesa por nível (para levelBonus)
        },
        tags = { "defensivo", "vida", "risco", "negativo" }
    },

    -- Bônus de Força (NOVA SEÇÃO)
    strength_training_1_fixed = {
        id = "strength_training_1_fixed",
        name = "Treino de Força",
        description_template = "Aumenta a Força em 10.",
        icon = "STR+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "strength", type = "fixed", value = 10 } -- +2 Força fixa por nível
        },
        tags = { "ofensivo", "forca", "fixo" }
    },
    strength_might_1_percent = {
        id = "strength_might_1_percent",
        name = "Poderio Crescente",
        description_template = "Aumenta a Força em 10%.",
        icon = "STR%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "strength", type = "percentage", value = 10 } -- +10% Força por nível (para levelBonus)
        },
        tags = { "ofensivo", "forca", "percentual" }
    },
    strength_burst_1_combo = {
        id = "strength_burst_1_combo",
        name = "Explosão de Força",
        description_template = "Aumenta Força em 5 e a Defesa em 5.",
        icon = "STR*",
        max_level = 5,
        modifiers_per_level = {
            { stat = "strength", type = "fixed", value = 5 },
            { stat = "defense",  type = "fixed", value = 5 }
        },
        tags = { "ofensivo", "forca", "dano", "combo" }
    },

    -- Bônus de Dano/Ataque
    strength_1_percent = {
        id = "strength_1_percent",
        name = "Raiva",
        description_template = "Aumenta o Dano em 10%.", -- Assumindo que dano é percentual em levelBonus
        icon = "D%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "damageMultiplier", type = "percentage", value = 10 } -- +10% para levelBonus.damageMultiplier
        },
        tags = { "ofensivo", "dano", "percentual" }
    },
    speed_attack_1_percent = {
        id = "speed_attack_1_percent",
        name = "Agilidade",
        description_template = "Aumenta a Velocidade de Ataque em 5%.",
        icon = "A%",
        max_level = 8,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 5 } -- +5% para levelBonus.attackSpeed
        },
        tags = { "ofensivo", "velocidade_ataque", "percentual" }
    },
    glass_cannon_1 = {
        id = "glass_cannon_1",
        name = "Canhão de Vidro",
        description_template = "Aumenta Dano em 10% e Vel. Ataque em 10%, mas reduz Vida Máx. em -10%.",
        icon = "D!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "damageMultiplier", type = "percentage", value = 10 },
            { stat = "attackSpeed",      type = "percentage", value = 10 },
            { stat = "health",           type = "percentage", value = -10 }
        },
        tags = { "ofensivo", "dano", "velocidade_ataque", "vida", "risco", "negativo" }
    },

    -- Bônus Crítico
    precision_1_fixed_fraction = {
        id = "precision_1_fixed_fraction",
        name = "Precisão Afiada",
        description_template = "Aumenta a Chance de Crítico em 10%.", -- {value} será value*100 na UI
        icon = "C+",
        max_level = 10,
        modifiers_per_level = {
            -- Intenção: +0.5% de chance crítica fixa por nível.
            -- PlayerState.fixedBonus.critChance armazena isso como a fração 0.005.
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.010 }
        },
        tags = { "ofensivo", "critico", "chance_critica", "fixo" }
    },
    lethality_1_fixed_multiplier = {
        id = "lethality_1_fixed_multiplier",
        name = "Golpe Devastador",
        description_template = "Aumenta o Dano Crítico em 0.10.",
        icon = "M+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.1 } -- +0.05x Dano Crítico por nível (para fixedBonus)
        },
        tags = { "ofensivo", "critico", "dano_critico", "fixo" }
    },
    gamblers_strike_1 = {
        id = "gamblers_strike_1",
        name = "Aposta Arriscada",
        description_template =
        "Aumenta Chance (0.10) e Dano Crítico (+0.20x), mas reduz Dano base em -10%.",
        icon = "C!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "critChance",       type = "fixed_percentage_as_fraction", value = 0.10 },
            { stat = "critDamage",       type = "fixed_percentage_as_fraction", value = 0.20 },
            { stat = "damageMultiplier", type = "percentage",                   value = -10 }
        },
        tags = { "ofensivo", "critico", "risco", "negativo" }
    },

    -- Bônus de Mobilidade
    celerity_1_percent = {
        id = "celerity_1_percent",
        name = "Passos Velozes",
        description_template = "Aumenta a Velocidade de Movimento em 5%.",
        icon = "S%",
        max_level = 8,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 5 } -- +5% Vel. Mov. por nível (para levelBonus)
        },
        tags = { "mobilidade", "velocidade", "percentual" }
    },
    haste_1_fixed = {
        id = "haste_1_fixed",
        name = "Ímpeto",
        description_template = "Aumenta a Velocidade de Movimento em 10.",
        icon = "S+",
        max_level = 5,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "fixed", value = 10 }
        },
        tags = { "mobilidade", "velocidade", "fixo" }
    },
    unburdened_1 = {
        id = "unburdened_1",
        name = "Peso Pena",
        description_template = "Aumenta Vel. Movimento em 5%, mas reduz a Defesa em -5 pts.",
        icon = "S!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 5 },
            { stat = "defense",   type = "fixed",      value = -5 }
        },
        tags = { "mobilidade", "velocidade", "defesa", "risco", "negativo" }
    },

    -- Bônus de Defesa
    protection_1_fixed = {
        id = "protection_1_fixed",
        name = "Guarda Menor",
        description_template = "Aumenta a Defesa em 10 pontos.",
        icon = "DEF+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "defense", type = "fixed", value = 10 }
        },
        tags = { "defensivo", "defesa", "fixo" }
    },
    resilience_1_percent = {
        id = "resilience_1_percent",
        name = "Tenacidade",
        description_template = "Aumenta a Defesa em 10%.",
        icon = "DEF%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "defense", type = "percentage", value = 10 } -- +10% Defesa por nível (para levelBonus)
        },
        tags = { "defensivo", "defesa", "percentual" }
    },

    -- Bônus de Regeneração e Coleta
    regeneration_1_fixed = {
        id = "regeneration_1_fixed",
        name = "Recuperação Rápida",
        description_template = "Aumenta Regeneração de Vida em +0.5 HP/s.",
        icon = "R+",
        max_level = 5,
        modifiers_per_level = {
            { stat = "healthPerTick", type = "fixed", value = 0.5 } -- Para fixedBonus.healthPerTick
        },
        tags = { "defensivo", "regeneracao", "fixo" }
    },
    regen_delay_1_reduction = {
        id = "regen_delay_1_reduction",
        name = "Prontidão",
        description_template = "Reduz o Delay de Regeneração de Vida em 0.5s.",
        icon = "RD-",
        max_level = 5,
        modifiers_per_level = {
            -- PlayerState.fixedBonus.healthRegenDelay é um valor que é SUBTRAÍDO.
            { stat = "healthRegenDelay", type = "fixed", value = 0.5 } -- Reduz em 0.5s (PlayerState aplica como subtração)
        },
        tags = { "defensivo", "regeneracao", "delay", "fixo" }
    },
    scavenger_1_fixed = {
        id = "scavenger_1_fixed",
        name = "Magnetismo",
        description_template = "Aumenta o Raio de Coleta em 10 unidades.",
        icon = "P+",
        max_level = 8,
        modifiers_per_level = {
            { stat = "pickupRadius", type = "fixed", value = 10 }
        },
        tags = { "utilidade", "coleta", "fixo" }
    },

    -- Bônus Utilitários / Avançados
    chronomancer_1_percent = {
        id = "chronomancer_1_percent",
        name = "Dobra Temporal Menor",
        description_template = "Reduz a Recarga de Habilidades em 5%.",
        icon = "CD%",
        max_level = 10,
        modifiers_per_level = {
            -- PlayerState.levelBonus.cooldownReduction é um percentual de REDUÇÃO.
            { stat = "cooldownReduction", type = "percentage", value = 5 } -- +5% de REDUÇÃO por nível (para levelBonus)
        },
        tags = { "utilidade", "cooldown", "percentual" }
    },
    lucky_star_1_percent = {
        id = "lucky_star_1_percent",
        name = "Estrela da Sorte",
        description_template = "Aumenta a Sorte em 5%.",
        icon = "L%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "luck", type = "percentage", value = 5 } -- +3% Sorte por nível (para levelBonus)
        },
        tags = { "utilidade", "sorte", "percentual" }
    },
    scholarly_pursuit_1 = {
        id = "scholarly_pursuit_1",
        name = "Busca Acadêmica",
        description_template = "Aumenta Bônus de Exp. em 20% mas e Vel. Ataque em -5%.",
        icon = "XP!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "expBonus",    type = "percentage", value = 20 },
            { stat = "attackSpeed", type = "percentage", value = -5 }
        },
        tags = { "utilidade", "experiencia", "risco", "negativo" }
    },

    --- Area e alcance
    area_1_percent = {
        id = "area_1_percent",
        name = "Área",
        description_template = "Aumenta a Área de Ataque em 10%.",
        icon = "A%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "attackArea", type = "percentage", value = 10 }
        },
        tags = { "utilidade", "alcance", "percentual" }
    },
    area_3_combo = {
        id = "area_3_combo",
        name = "Área Mortal",
        description_template = "Aumenta Área em 8% e Dano em 8%.",
        icon = "A*",
        max_level = 5,
        modifiers_per_level = {
            { stat = "attackArea",       type = "percentage", value = 8 },
            { stat = "damageMultiplier", type = "percentage", value = 8 }
        },
        tags = { "utilidade", "alcance", "dano", "combo" }
    },
    range_1_percent = {
        id = "range_1_percent",
        name = "Alcance",
        description_template = "Aumenta o Alcance em 10%.",
        icon = "A%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "range", type = "percentage", value = 10 }
        },
        tags = { "utilidade", "alcance", "percentual" }
    },
    range_3_combo = {
        id = "range_3_combo",
        name = "Alcance Mortal",
        description_template = "Aumenta Alcance em 8% e Dano em 8%.",
        icon = "A*",
        max_level = 5,
        modifiers_per_level = {
            { stat = "range",            type = "percentage", value = 8 },
            { stat = "damageMultiplier", type = "percentage", value = 8 }
        },
        tags = { "utilidade", "alcance", "dano", "combo" }
    },

    -- Bônus de Ataque Múltiplo
    multi_attack_chance_1 = {
        id = "multi_attack_chance_1",
        name = "Golpes Ecoantes",
        description_template = "Aumenta a Chance de Ataque Múltiplo em 10%.",
        icon = "MA+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "fixed_percentage_as_fraction", value = 0.10 }
        },
        tags = { "ofensivo", "multi_ataque", "chance" }
    },
    multi_attack_frenzy_1 = {
        id = "multi_attack_frenzy_1",
        name = "Frenesi de Golpes",
        description_template = "Aumenta a Chance de Ataque Múltiplo em 10%, mas reduz a Chance de Crítico em 5%.",
        icon = "MA!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "fixed_percentage_as_fraction", value = 0.10 },
            { stat = "critChance",        type = "fixed_percentage_as_fraction", value = -0.05 }
        },
        tags = { "ofensivo", "multi_ataque", "chance", "risco", "negativo" }
    },

    -- Bônus de Dash
    dash_cooldown_reduction_1 = {
        id = "dash_cooldown_reduction_1",
        name = "Passo Rápido",
        description_template = "Reduz a Recarga do Dash em 8%.",
        icon = "DSH-",
        max_level = 5,
        modifiers_per_level = {
            { stat = "dashCooldown", type = "percentage", value = -8 }
        },
        tags = { "mobilidade", "dash", "cooldown" }
    },
    dash_distance_increase_1 = {
        id = "dash_distance_increase_1",
        name = "Salto Longo",
        description_template = "Aumenta a Distância do Dash em 15%.",
        icon = "DSH+",
        max_level = 5,
        modifiers_per_level = {
            { stat = "dashDistance", type = "percentage", value = 15 }
        },
        tags = { "mobilidade", "dash", "distancia" }
    },
    dash_extra_charge_1 = {
        id = "dash_extra_charge_1",
        name = "Carga Extra",
        description_template = "Adiciona +1 Carga de Dash.",
        icon = "DSH*",
        max_level = 2, -- Máximo de 2 cargas extras por este bônus
        modifiers_per_level = {
            { stat = "dashCharges", type = "fixed", value = 1 }
        },
        tags = { "mobilidade", "dash", "cargas" }
    },

    -- Bônus do Sistema de Poções
    potion_capacity_1 = {
        id = "potion_capacity_1",
        name = "Capacidade Expandida",
        description_template = "Adiciona +1 Frasco de Poção.",
        icon = "POT+",
        max_level = 3, -- Máximo de 3 frascos extras
        modifiers_per_level = {
            { stat = "potionFlasks", type = "fixed", value = 1 }
        },
        tags = { "defensivo", "pocoes", "capacidade" }
    },
    potion_potency_1_fixed = {
        id = "potion_potency_1_fixed",
        name = "Poções Concentradas",
        description_template = "Aumenta a cura das poções em +15 HP.",
        icon = "POT*",
        max_level = 8,
        modifiers_per_level = {
            { stat = "potionHealAmount", type = "fixed", value = 15 }
        },
        tags = { "defensivo", "pocoes", "cura", "fixo" }
    },
    potion_speed_1 = {
        id = "potion_speed_1",
        name = "Destilação Rápida",
        description_template = "Frascos enchem 25% mais rápido.",
        icon = "POT>",
        max_level = 8,
        modifiers_per_level = {
            { stat = "potionFillRate", type = "fixed_percentage_as_fraction", value = 0.25 }
        },
        tags = { "defensivo", "pocoes", "velocidade" }
    },
    potion_combo_1 = {
        id = "potion_combo_1",
        name = "Mestre Alquimista",
        description_template = "Poções curam 15% mais e enchem 15% mais rápido.",
        icon = "POT&",
        max_level = 5,
        modifiers_per_level = {
            { stat = "potionHealAmount", type = "percentage",                   value = 15 },
            { stat = "potionFillRate",   type = "fixed_percentage_as_fraction", value = 0.15 }
        },
        tags = { "defensivo", "pocoes", "cura", "velocidade", "combo" }
    },
    potion_healing_synergy_1 = {
        id = "potion_healing_synergy_1",
        name = "Sinergia Curativa",
        description_template = "Poções curam 10% mais e aumenta Bônus de Cura em 8%.",
        icon = "POT+",
        max_level = 6,
        modifiers_per_level = {
            { stat = "potionHealAmount", type = "percentage", value = 10 },
            { stat = "healingBonus",     type = "percentage", value = 8 }
        },
        tags = { "defensivo", "pocoes", "cura", "healing_bonus", "combo" }
    },
    potion_risk_reward_1 = {
        id = "potion_risk_reward_1",
        name = "Elixir Instável",
        description_template = "Poções curam 40% mais, mas frascos enchem 20% mais devagar.",
        icon = "POT!",
        max_level = 4,
        modifiers_per_level = {
            { stat = "potionHealAmount", type = "percentage",                   value = 40 },
            { stat = "potionFillRate",   type = "fixed_percentage_as_fraction", value = -0.20 }
        },
        tags = { "defensivo", "pocoes", "cura", "velocidade", "risco", "negativo" }
    },
    potion_quantity_over_quality_1 = {
        id = "potion_quantity_over_quality_1",
        name = "Quantidade sobre Qualidade",
        description_template = "Ganha +1 Frasco, mas cada poção cura 25% menos.",
        icon = "POT#",
        max_level = 2,
        modifiers_per_level = {
            { stat = "potionFlasks",     type = "fixed",      value = 1 },
            { stat = "potionHealAmount", type = "percentage", value = -25 }
        },
        tags = { "defensivo", "pocoes", "capacidade", "cura", "risco", "negativo" }
    }
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
