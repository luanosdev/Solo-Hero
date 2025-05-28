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
        name = "Vigor Menor (Fixo)",
        description_template = "Aumenta a Vida Máxima em {value} pontos.",
        icon = "H+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "health", type = "fixed", value = 30 } -- +15 HP fixo por nível
        },
        tags = { "defensivo", "vida", "fixo" }
    },
    vitality_2_percent = {
        id = "vitality_2_percent",
        name = "Fortitude Menor (%)",
        description_template = "Aumenta a Vida Máxima em {value}%.",
        icon = "H%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "health", type = "percentage", value = 3 } -- +3% HP por nível (para levelBonus)
        },
        tags = { "defensivo", "vida", "percentual" }
    },
    vitality_3_combo = {
        id = "vitality_3_combo",
        name = "Robustez Híbrida",
        description_template = "Aumenta Vida Máx. em {value1}% e Defesa em {value2} pts.",
        icon = "H*",
        max_level = 5,
        modifiers_per_level = {
            { stat = "health",  type = "percentage", value = 2 },
            { stat = "defense", type = "fixed",      value = 3 }
        },
        tags = { "defensivo", "vida", "defesa", "combo" }
    },
    risky_vitality_1 = {
        id = "risky_vitality_1",
        name = "Pacto de Sangue Frágil",
        description_template = "Aumenta MUITO a Vida Máx. em {value1} pts, mas reduz Defesa em -{value2}%.",
        icon = "H!",
        max_level = 3,
        modifiers_per_level = {
            { stat = "health",  type = "fixed",      value = 100 },
            { stat = "defense", type = "percentage", value = -5 } -- -5% Defesa por nível (para levelBonus)
        },
        tags = { "defensivo", "vida", "risco", "negativo" }
    },

    -- Bônus de Força (NOVA SEÇÃO)
    strength_training_1_fixed = {
        id = "strength_training_1_fixed",
        name = "Treino de Força (Fixo)",
        description_template = "Aumenta a Força em {value} pontos.",
        icon = "STR+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "strength", type = "fixed", value = 2 } -- +2 Força fixa por nível
        },
        tags = { "ofensivo", "forca", "fixo" }
    },
    strength_might_1_percent = {
        id = "strength_might_1_percent",
        name = "Poderio Crescente (%)",
        description_template = "Aumenta a Força em 5%.",
        icon = "STR%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "strength", type = "percentage", value = 5 } -- +5% Força por nível (para levelBonus)
        },
        tags = { "ofensivo", "forca", "percentual" }
    },
    strength_burst_1_combo = {
        id = "strength_burst_1_combo",
        name = "Explosão de Força",
        description_template = "Aumenta Força em 3.",
        icon = "STR*",
        max_level = 5,
        modifiers_per_level = {
            { stat = "strength", type = "fixed", value = 3 },
        },
        tags = { "ofensivo", "forca", "dano", "combo" }
    },

    -- Bônus de Dano/Ataque
    strength_1_percent = {
        id = "strength_1_percent",
        name = "Força Crescente (%)",
        description_template = "Aumenta o Dano em {value}%.", -- Assumindo que dano é percentual em levelBonus
        icon = "D%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "damageMultiplier", type = "percentage", value = 2 } -- +2% para levelBonus.damageMultiplier
        },
        tags = { "ofensivo", "dano", "percentual" }
    },
    speed_attack_1_percent = {
        id = "speed_attack_1_percent",
        name = "Presteza Menor (%)",
        description_template = "Aumenta a Velocidade de Ataque em {value}%.",
        icon = "A%",
        max_level = 8,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 2 } -- +2% para levelBonus.attackSpeed
        },
        tags = { "ofensivo", "velocidade_ataque", "percentual" }
    },
    glass_cannon_1 = {
        id = "glass_cannon_1",
        name = "Canhão de Vidro",
        description_template = "Aumenta Dano em {value1}% e Vel. Ataque em {value2}%, mas reduz Vida Máx. em -{value3}%.",
        icon = "D!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "damageMultiplier", type = "percentage", value = 5 },
            { stat = "attackSpeed",      type = "percentage", value = 3 },
            { stat = "health",           type = "percentage", value = -4 }
        },
        tags = { "ofensivo", "dano", "velocidade_ataque", "vida", "risco", "negativo" }
    },

    -- Bônus Crítico
    precision_1_fixed_fraction = {
        id = "precision_1_fixed_fraction",
        name = "Precisão Afiada (Fixa)",
        description_template = "Aumenta a Chance de Crítico em {value}%.", -- {value} será value*100 na UI
        icon = "C+",
        max_level = 10,
        modifiers_per_level = {
            -- Intenção: +0.5% de chance crítica fixa por nível.
            -- PlayerState.fixedBonus.critChance armazena isso como a fração 0.005.
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.005 }
        },
        tags = { "ofensivo", "critico", "chance_critica", "fixo" }
    },
    lethality_1_fixed_multiplier = {
        id = "lethality_1_fixed_multiplier",
        name = "Golpe Devastador (Fixo)",
        description_template = "Aumenta o Dano Crítico em +{value}x.",
        icon = "M+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.05 } -- +0.05x Dano Crítico por nível (para fixedBonus)
        },
        tags = { "ofensivo", "critico", "dano_critico", "fixo" }
    },
    gamblers_strike_1 = {
        id = "gamblers_strike_1",
        name = "Aposta Arriscada",
        description_template =
        "Aumenta Chance ({value1}%) e Dano Crítico (+{value2}x), mas reduz Dano base em -{value3}%.",
        icon = "C!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "critChance",       type = "fixed_percentage_as_fraction", value = 0.02 },
            { stat = "critDamage",       type = "fixed_percentage_as_fraction", value = 0.10 },
            { stat = "damageMultiplier", type = "percentage",                   value = -3 }
        },
        tags = { "ofensivo", "critico", "risco", "negativo" }
    },

    -- Bônus de Mobilidade
    celerity_1_percent = {
        id = "celerity_1_percent",
        name = "Passos Velozes (%)",
        description_template = "Aumenta a Velocidade de Movimento em {value}%.",
        icon = "S%",
        max_level = 8,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 2.5 } -- +2.5% Vel. Mov. por nível (para levelBonus)
        },
        tags = { "mobilidade", "velocidade", "percentual" }
    },
    haste_1_fixed = {
        id = "haste_1_fixed",
        name = "Ímpeto (Fixo)",
        description_template = "Aumenta a Velocidade de Movimento em {value} unidades.",
        icon = "S+",
        max_level = 5,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "fixed", value = 3 }
        },
        tags = { "mobilidade", "velocidade", "fixo" }
    },
    unburdened_1 = {
        id = "unburdened_1",
        name = "Peso Pena",
        description_template = "Aumenta Vel. Movimento em {value1}%, mas reduz Levemente Defesa em -{value2} pts.",
        icon = "S!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 4 },
            { stat = "defense",   type = "fixed",      value = -2 }
        },
        tags = { "mobilidade", "velocidade", "defesa", "risco", "negativo" }
    },

    -- Bônus de Defesa
    protection_1_fixed = {
        id = "protection_1_fixed",
        name = "Guarda Menor (Fixa)",
        description_template = "Aumenta a Defesa em {value} pontos.",
        icon = "DEF+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "defense", type = "fixed", value = 2 }
        },
        tags = { "defensivo", "defesa", "fixo" }
    },
    resilience_1_percent = {
        id = "resilience_1_percent",
        name = "Tenacidade Menor (%)",
        description_template = "Aumenta a Defesa em {value}%.",
        icon = "DEF%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "defense", type = "percentage", value = 3 } -- +3% Defesa por nível (para levelBonus)
        },
        tags = { "defensivo", "defesa", "percentual" }
    },

    -- Bônus de Regeneração e Coleta
    regeneration_1_fixed = {
        id = "regeneration_1_fixed",
        name = "Recuperação Rápida (HP/s)",
        description_template = "Aumenta Regeneração de Vida em +{value} HP/s.",
        icon = "R+",
        max_level = 5,
        modifiers_per_level = {
            { stat = "healthPerTick", type = "fixed", value = 0.2 } -- Para fixedBonus.healthPerTick
        },
        tags = { "defensivo", "regeneracao", "fixo" }
    },
    regen_delay_1_reduction = {
        id = "regen_delay_1_reduction",
        name = "Prontidão (Delay)",
        description_template = "Reduz o Delay de Regeneração de Vida em {value}s.",
        icon = "RD-",
        max_level = 5,
        modifiers_per_level = {
            -- PlayerState.fixedBonus.healthRegenDelay é um valor que é SUBTRAÍDO.
            { stat = "healthRegenDelay", type = "fixed", value = 0.3 } -- Reduz em 0.3s (PlayerState aplica como subtração)
        },
        tags = { "defensivo", "regeneracao", "delay", "fixo" }
    },
    scavenger_1_fixed = {
        id = "scavenger_1_fixed",
        name = "Magnetismo Menor (Raio)",
        description_template = "Aumenta o Raio de Coleta em {value} unidades.",
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
        name = "Dobra Temporal Menor (%)",
        description_template = "Reduz a Recarga de Habilidades em {value}%.",
        icon = "CD%",
        max_level = 10,
        modifiers_per_level = {
            -- PlayerState.levelBonus.cooldownReduction é um percentual de REDUÇÃO.
            { stat = "cooldownReduction", type = "percentage", value = 1.5 } -- +1.5% de REDUÇÃO por nível (para levelBonus)
        },
        tags = { "utilidade", "cooldown", "percentual" }
    },
    lucky_star_1_percent = {
        id = "lucky_star_1_percent",
        name = "Estrela da Sorte (%)",
        description_template = "Aumenta a Sorte em {value}%.",
        icon = "L%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "luck", type = "percentage", value = 3 } -- +3% Sorte por nível (para levelBonus)
        },
        tags = { "utilidade", "sorte", "percentual" }
    },
    scholarly_pursuit_1 = {
        id = "scholarly_pursuit_1",
        name = "Busca Acadêmica",
        description_template = "Aumenta Bônus de Exp. em {value1}% mas reduz Vel. Ataque em -{value2}%.",
        icon = "XP!",
        max_level = 5,
        modifiers_per_level = {
            { stat = "expBonus",    type = "percentage", value = 5 },
            { stat = "attackSpeed", type = "percentage", value = -1.5 }
        },
        tags = { "utilidade", "experiencia", "risco", "negativo" }
    },

    --- Area e alcance
    area_1_percent = {
        id = "area_1_percent",
        name = "Área Menor (%)",
        description_template = "Aumenta a Área de Ataque em {value}%.",
        icon = "A%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "attackArea", type = "percentage", value = 10 }
        },
        tags = { "utilidade", "alcance", "percentual" }
    },
    area_2_fixed = {
        id = "area_2_fixed",
        name = "Área Menor (Fixa)",
        description_template = "Aumenta a Área de Ataque em {value} unidades.",
        icon = "A+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "attackArea", type = "fixed_percentage_as_fraction", value = 0.10 }
        },
        tags = { "utilidade", "alcance", "fixo" }
    },
    area_3_combo = {
        id = "area_3_combo",
        name = "Área Híbrida",
        description_template = "Aumenta Alcance em {value1}% e Dano em {value2}%.",
        icon = "A*",
        max_level = 5,
        modifiers_per_level = {
            { stat = "attackArea",       type = "percentage", value = 10 },
            { stat = "damageMultiplier", type = "percentage", value = 5 }
        },
        tags = { "utilidade", "alcance", "dano", "combo" }
    },
    range_1_percent = {
        id = "range_1_percent",
        name = "Alcance Menor (%)",
        description_template = "Aumenta o Alcance em {value}%.",
        icon = "A%",
        max_level = 10,
        modifiers_per_level = {
            { stat = "range", type = "percentage", value = 10 }
        },
        tags = { "utilidade", "alcance", "percentual" }
    },
    range_2_fixed = {
        id = "range_2_fixed",
        name = "Alcance Menor (Fixa)",
        description_template = "Aumenta o Alcance em {value} unidades.",
        icon = "A+",
        max_level = 10,
        modifiers_per_level = {
            { stat = "range", type = "fixed_percentage_as_fraction", value = 0.10 }
        },
        tags = { "utilidade", "alcance", "fixo" }
    },
    range_3_combo = {
        id = "range_3_combo",
        name = "Alcance Híbrido",
        description_template = "Aumenta Alcance em {value1}% e Dano em {value2}%.",
        icon = "A*",
        max_level = 5,
        modifiers_per_level = {
            { stat = "range",            type = "percentage", value = 10 },
            { stat = "damageMultiplier", type = "percentage", value = 5 }
        },
        tags = { "utilidade", "alcance", "dano", "combo" }
    },
}


-- Função auxiliar para aplicar modificadores ao PlayerState
-- Pode ser chamada pelo LevelUpModal após o jogador escolher uma opção.
-- playerState: Instância do estado do jogador (playerManager.state)
-- bonusId: O ID do bônus de LevelUpBonusesData.Bonuses que foi escolhido
function LevelUpBonusesData.ApplyBonus(playerState, bonusId)
    local bonusData = LevelUpBonusesData.Bonuses[bonusId]
    if not bonusData then
        print("ERRO [LevelUpBonusesData.ApplyBonus]: Bônus com ID '" .. tostring(bonusId) .. "' não encontrado.")
        return
    end

    if not playerState or not playerState.addAttributeBonus then
        print("ERRO [LevelUpBonusesData.ApplyBonus]: playerState inválido ou não possui addAttributeBonus.")
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
            playerState:addAttributeBonus(stat, 0, value)
        elseif type == "percentage" then
            -- Este 'percentage' vai para playerState.levelBonus[stat]
            -- E PlayerState.levelBonus espera um valor como 5 para 5%
            playerState:addAttributeBonus(stat, value, 0)
        elseif type == "fixed_percentage_as_fraction" then
            -- Este 'fixed' vai para playerState.fixedBonus[stat]
            -- E PlayerState.fixedBonus para stats como critChance espera uma fração (ex: 0.01 para 1%)
            playerState:addAttributeBonus(stat, 0, value)
        else
            print("AVISO [LevelUpBonusesData.ApplyBonus]: Tipo de modificador desconhecido ('" ..
                tostring(type) .. "') para o stat '" .. tostring(stat) .. "'.")
        end
    end
end

return LevelUpBonusesData
