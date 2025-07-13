---------------------------------------------------------------------------------
-- Weapon Traits Data (Class Traits)
-- Sistema de traits por arma similar ao Halls of Torment
-- Cada arma tem 2 caminhos, cada caminho tem 2 variações
-- Cada variação tem 5 níveis + 1 ultimate
---------------------------------------------------------------------------------

local Colors = require("src.ui.colors")

---@class WeaponTraitModifier
---@field stat string
---@field type "base"|"percentage"
---@field value number

---@class WeaponTrait
---@field id string
---@field name string
---@field description string
---@field image_path string
---@field max_level number
---@field attack_class string Tipo de ataque que este trait afeta
---@field path_id string ID do caminho (path1, path2)
---@field variation_id string ID da variação (variation1, variation2)
---@field is_ultimate boolean Se é o nível ultimate
---@field modifiers_per_level WeaponTraitModifier[]
---@field color table

---@class WeaponTraitsData
---@field Traits WeaponTrait[]
---@field GetTraitsByAttackClass fun(attackClass: string): WeaponTrait[]
---@field GetAvailableTraits fun(attackClass: string, learnedTraits: table): WeaponTrait[]
---@field ApplyWeaponTrait fun(stateController: PlayerStateController, traitId: string)
local WeaponTraitsData = {}

-- Cores para os caminhos
local PATH_COLORS = {
    path1 = Colors.attribute_colors.damage,
    path2 = Colors.attribute_colors.range,
    path3 = Colors.attribute_colors.attack_area,
    ultimate = Colors.rankDetails.S.text
}

-- Ícones temporários
local tempIconPath = "assets/images/skills/attack.png"

-- Todos os weapon traits organizados por tipo de ataque
WeaponTraitsData.Traits = {
    ---------------------------------------------------------------------------------
    -- CONE SLASH (Espadas)
    ---------------------------------------------------------------------------------
    -- Caminho 1: Proeficiência
    -- Variação 1: Cobertura
    cone_slash_path1_var1 = {
        id = "cone_slash_path1_var1",
        name = "Proeficiência - Cobertura",
        description = "Aumenta a |Área de Ataque| em |15%| e o |Alcance| em |15%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "cone_slash",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "area",  type = "percentage", value = 15 },
            { stat = "range", type = "percentage", value = 15 }
        },
        color = PATH_COLORS.path1
    },
    cone_slash_path1_var1_ultimate = {
        id = "cone_slash_path1_var1_ultimate",
        name = "Proeficiência - Força Bruta",
        description =
        "Cada golpe parece ser o último. Aumenta o |Dano| base em |100| mas reduz o |Chance de Crítico| base em |-0.3|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "cone_slash",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage",     type = "base", value = 100 },
            { stat = "critChance", type = "base", value = -0.3 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 1: Proeficiência
    -- Variação 2: Técnica
    cone_slash_path1_var2 = {
        id = "cone_slash_path1_var2",
        name = "Proeficiência - Técnica",
        description = "Aumenta o |Dano| em |30%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "cone_slash",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "damage", type = "percentage", value = 30 }
        },
        color = PATH_COLORS.path1
    },
    cone_slash_path1_var2_ultimate = {
        id = "cone_slash_path1_var2_ultimate",
        name = "Proeficiência - Técnica Impecável",
        description =
        "Ninguém consegue está a salvo. Aumenta o |Área| base em |45°|, mas reduz a |Velocidade de Ataque| em |-0.3|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "cone_slash",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "attackArea",  type = "base", value = math.rad(45) },
            { stat = "attackSpeed", type = "base", value = -0.3 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Habilidade
    -- Variação 1: Destreza
    cone_slash_path2_var1 = {
        id = "cone_slash_path2_var1",
        name = "Habilidade - Destreza",
        description = "Aumenta a |Velocidade de Ataque| em |5%| e aumenta a |Chance de Crítico| em |10%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "cone_slash",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 5 },
            { stat = "critChance",  type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path2
    },
    cone_slash_path2_var1_ultimate = {
        id = "cone_slash_path2_var1_ultimate",
        name = "Habilidade - Corte",
        description = "A repetição tras a perfeição. Aumenta o |Dano| em |50%| e reduz o |Alcance| em |-30%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "cone_slash",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage", type = "percentage", value = 50 },
            { stat = "range",  type = "percentage", value = -0.3 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Habilidade
    -- Variação 2: Balanço
    cone_slash_path2_var2 = {
        id = "cone_slash_path2_var2",
        name = "Habilidade - Balanço",
        description = "Aumenta o |Alcance| em |20%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "cone_slash",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "range", type = "percentage", value = 20 },
        },
        color = PATH_COLORS.path2
    },
    cone_slash_path2_var2_ultimate = {
        id = "cone_slash_path2_var2_ultimate",
        name = "Habilidade - Dança das Mil Lâminas",
        description =
        "A velocidade extrema. Aumenta o |Alcance| em |30%| e reduz o |Dano| em |-60%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "cone_slash",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "range",  type = "percentage", value = 30 },
            { stat = "damage", type = "percentage", value = -60 }
        },
        color = PATH_COLORS.ultimate
    },
    ---------------------------------------------------------------------------------
    -- ALTERNATING CONE STRIKE (Adagas)
    ---------------------------------------------------------------------------------
    -- Caminho 1: Proeficiência
    -- Variação 1: Destreza
    alternating_cone_strike_path1_var1 = {
        id = "alternating_cone_strike_path1_var1",
        name = "Proeficiência - Destreza",
        description = "Aumenta a chance de |Ataques Múltiplos| em |8%| e aumenta a |Área| em |8%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "alternating_cone_strike",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "percentage", value = 8 },
            { stat = "attackArea",        type = "percentage", value = 8 }
        },
        color = PATH_COLORS.path1
    },
    alternating_cone_strike_path1_var1_ultimate = {
        id = "alternating_cone_strike_path1_var1_ultimate",
        name = "Proeficiência - Força Bruta",
        description =
        "A velocidade absoluta. Aumenta o |Dano| base em |40| e reduz a |Velocidade de Ataque| base em |-0.2|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "alternating_cone_strike",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage",      type = "base", value = 40 },
            { stat = "attackSpeed", type = "base", value = -0.2 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 1: Proeficiência
    -- Variação 2: Habilidade
    alternating_cone_strike_path1_var2 = {
        id = "alternating_cone_strike_path1_var2",
        name = "Proeficiência - Habilidade",
        description = "Aumenta o |Alcance| em |15%| e aumenta a |Velocidade de Ataque| em |8%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "alternating_cone_strike",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "range",       type = "percentage", value = 15 },
            { stat = "attackSpeed", type = "percentage", value = 8 }
        },
        color = PATH_COLORS.path1
    },
    alternating_cone_strike_path1_var2_ultimate = {
        id = "alternating_cone_strike_path1_var2_ultimate",
        name = "Proeficiência - Acerto Vital",
        description = "Aumenta o |Dano| base em |40| e reduz o |Alcance| base em |-2.0|m.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "alternating_cone_strike",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage", type = "base", value = 40 },
            { stat = "range",  type = "base", value = -2.0 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Treino
    -- Variação 1: Performance
    alternating_cone_strike_path2_var1 = {
        id = "alternating_cone_strike_path2_var1",
        name = "Treino - Performance",
        description = "Aumenta a |Velocidade de Movimento| em |5%| e aumenta a |Velocidade de Ataque| em |5%|.",
        image_path = tempIconPath,
        max_level = 5,
        attack_class = "alternating_cone_strike",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "moveSpeed",   type = "percentage", value = 5 },
            { stat = "attackSpeed", type = "percentage", value = 5 }
        },
        color = PATH_COLORS.path2
    },
    alternating_cone_strike_path2_var1_ultimate = {
        id = "alternating_cone_strike_path2_var1_ultimate",
        name = "Treino - Laceração",
        description =
        "A mobilidade suprema. Aumenta a |Chance de Crítico| em |30%| e aumenta o |Dano Crítico| em |60%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "alternating_cone_strike",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "critDamage", type = "percentage", value = 60 },
            { stat = "critChance", type = "base",       value = 30 },
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Treino
    -- Variação 2: Resistência
    alternating_cone_strike_path2_var2 = {
        id = "alternating_cone_strike_path2_var2",
        name = "Treino - Resistência",
        description = "Aumenta a |Regeneração de Vida| em |10%| e aumenta a |Defesa| em |10%|.",
        image_path = tempIconPath,
        max_level = 5,
        attack_class = "alternating_cone_strike",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "healthRegen", type = "percentage", value = 10 },
            { stat = "defense",     type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path2
    },
    alternating_cone_strike_path2_var2_ultimate = {
        id = "alternating_cone_strike_path2_var2_ultimate",
        name = "Treino - Resiliência",
        description = "A resistência absoluta. Aumenta a |Vida Máxima| base em |150| e a |Defesa| base em |20|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "alternating_cone_strike",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "maxHealth", type = "base", value = 150 },
            { stat = "defense",   type = "base", value = 20 }
        },
        color = PATH_COLORS.ultimate
    },
    ---------------------------------------------------------------------------------
    -- CIRCULAR SMASH (Martelos)
    ---------------------------------------------------------------------------------
    -- Caminho 1: Proeficiência
    -- Variação 1: Destreza
    circular_smash_path1_var1 = {
        id = "circular_smash_path1_var1",
        name = "Proeficiência - Destreza",
        description = "Aumenta a |Velocidade de Ataque| em |10%| e aumenta o |Dano| em |10%|.",
        image_path = tempIconPath,
        max_level = 5,
        attack_class = "circular_smash",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 10 },
            { stat = "damage",      type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path1
    },
    circular_smash_path1_var1_ultimate = {
        id = "circular_smash_path1_var1_ultimate",
        name = "Proeficiência - Pancada",
        description = "A força absoluta. Aumenta o |Dano Crítico| em |30%| e reduz a |Chance de Crítico| em |-30%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "circular_smash",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "critDamage", type = "percentage", value = 30 },
            { stat = "critChance", type = "percentage", value = -30 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 1: Proeficiência
    -- Variação 2: Contra ataque
    circular_smash_path1_var2 = {
        id = "circular_smash_path1_var2",
        name = "Proeficiência - Contra Ataque",
        description = "Aumenta a |Defesa| base em |5| e aumenta o |Dano| em |10%|.",
        image_path = tempIconPath,
        max_level = 5,
        attack_class = "circular_smash",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "defense", type = "base",       value = 5 },
            { stat = "damage",  type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path1
    },
    circular_smash_path1_var2_ultimate = {
        id = "circular_smash_path1_var2_ultimate",
        name = "Proeficiência - Parry",
        description =
        "O terremoto supremo. Aumenta a |Área de Ataque| em |200%| e aumenta a |Defesa| em |80%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "circular_smash",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage", type = "base", value = 50 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Habilidade
    -- Variação 1: Resistência
    circular_smash_path2_var1 = {
        id = "circular_smash_path2_var1",
        name = "Habilidade - Resistência",
        description = "Aumenta a |Regeneração de Vida| em |10%| e aumenta a |Defesa| em |10%|.",
        image_path = tempIconPath,
        max_level = 5,
        attack_class = "circular_smash",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "healthRegen", type = "percentage", value = 10 },
            { stat = "defense",     type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path2
    },
    circular_smash_path2_var1_ultimate = {
        id = "circular_smash_path2_var1_ultimate",
        name = "Habilidade - Resiliência",
        description = "A resistência absoluta. Aumenta a |Vida Máxima| base em |200|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "circular_smash",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "maxHealth", type = "base", value = 200 },
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Habilidade
    -- Variação 2: Agilidade
    circular_smash_path2_var2 = {
        id = "circular_smash_path2_var2",
        name = "Habilidade - Agilidade",
        description = "Aumenta o |Dano| em |10%| e a |Velocidade de Movimento| em |5%|.",
        image_path = tempIconPath,
        max_level = 5,
        attack_class = "circular_smash",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "damage",    type = "percentage", value = 10 },
            { stat = "moveSpeed", type = "percentage", value = 5 }
        },
        color = PATH_COLORS.path2
    },
    -- Caminho 2: Habilidade
    -- Variação 2: Impacto
    circular_smash_path2_var2_ultimate = {
        id = "circular_smash_path2_var2_ultimate",
        name = "Habilidade - Impacto",
        description =
        "A recuperação suprema. Aumenta a chance de |Ataques Múltiplos| base em |1.0| e a |Área de Ataque| em |20%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "circular_smash",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "base",       value = 1.0 },
            { stat = "attackArea",        type = "percentage", value = 20 }
        },
        color = PATH_COLORS.ultimate
    },
    ---------------------------------------------------------------------------------
    -- ARROW PROJECTILE (Arcos)
    ---------------------------------------------------------------------------------
    -- Caminho 1: Precisão
    -- Variação 1: Penetração
    arrow_projectile_path1_var1 = {
        id = "arrow_projectile_path1_var1",
        name = "Precisão - Penetração",
        description = "Aumenta o |Dano| em |20%| e aumenta a |Força| em |10%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "arrow_projectile",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "damage",   type = "percentage", value = 20 },
            { stat = "strength", type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path1
    },
    arrow_projectile_path1_var1_ultimate = {
        id = "arrow_projectile_path1_var1_ultimate",
        name = "Precisão - Mira",
        description =
        "Aumenta a |Penetração| base em |1|, aumenta a |Chance de Crítico| base em |33%| e reduz a |Velocidade de Ataque| base em |33%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "arrow_projectile",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "piercing",    type = "base", value = 1 },
            { stat = "critChance",  type = "base", value = 0.33 },
            { stat = "attackSpeed", type = "base", value = -0.33 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 1: Precisão
    -- Variação 2: Percepção
    arrow_projectile_path1_var2 = {
        id = "arrow_projectile_path1_var2",
        name = "Precisão - Percepção",
        description = "Aumenta a |Chance de Crítico| em |10%| e aumenta o |Dano Crítico| em |20%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "arrow_projectile",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "critChance", type = "percentage", value = 10 },
            { stat = "critDamage", type = "percentage", value = 20 }
        },
        color = PATH_COLORS.path1
    },
    arrow_projectile_path1_var2_ultimate = {
        id = "arrow_projectile_path1_var2_ultimate",
        name = "Precisão - Dispersão",
        description =
        "Aumenta a quantidade de |Projetéis| base em |2| e aumenta a |Área de Ataque| base em |50%| e reduz a |Velocidade de Ataque| em |-33%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "arrow_projectile",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "projectiles", type = "base", value = 2 },
            { stat = "attackArea",  type = "base", value = math.rad(50) },
            { stat = "attackSpeed", type = "base", value = -0.33 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Técnica
    -- Variação 1: Manuseiro
    arrow_projectile_path2_var1 = {
        id = "arrow_projectile_path2_var1",
        name = "Técnica - Manuseiro",
        description = "Aumenta a |Chance de Ataque Múltiplo| em |15%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "arrow_projectile",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "multiAttackChance", type = "percentage", value = 15 }
        },
        color = PATH_COLORS.path2
    },
    arrow_projectile_path2_var1_ultimate = {
        id = "arrow_projectile_path2_var1_ultimate",
        name = "Técnica - Manuseiro",
        description = "A rajada suprema. Aumenta a |Dano| em |90%| e reduz a |Chance de Crítico| em |-30%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "arrow_projectile",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage",     type = "percentage", value = 90 },
            { stat = "critChance", type = "percentage", value = -30 },
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Técnica
    -- Variação 2: Saque Rápido
    arrow_projectile_path2_var2 = {
        id = "arrow_projectile_path2_var2",
        name = "Técnica - Saque Rápido",
        description = "Aumenta a |Velocidade de Ataque| em |10%| e aumenta a |Velocidade de Movimento| em |5%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "arrow_projectile",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 10 },
            { stat = "moveSpeed",   type = "percentage", value = 5 }
        },
        color = PATH_COLORS.path2
    },
    arrow_projectile_path2_var2_ultimate = {
        id = "arrow_projectile_path2_var2_ultimate",
        name = "Técnica - Tiro Certeiro",
        description = "Aumenta a |Chance de Crítico| em |30%| e reduz o |Dano| em |-90%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "arrow_projectile",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "critChance", type = "percentage", value = 30 },
            { stat = "damage",     type = "percentage", value = -90 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 3: Disposição
    -- Variação 1: Agilidade
    arrow_projectile_path3_var1 = {
        id = "arrow_projectile_path3_var1",
        name = "Disposição - Agilidade",
        description = "Aumenta a |Velocidade de Movimento| base em |0.5|m/s.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "arrow_projectile",
        path_id = "path3",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "base", value = 0.5 }
        },
        color = PATH_COLORS.path3
    },
    arrow_projectile_path3_var1_ultimate = {
        id = "arrow_projectile_path3_var1_ultimate",
        name = "Disposição - Agilidade",
        description = "Aumenta a |Velocidade de Movimento| base em |1|m/s.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "arrow_projectile",
        path_id = "path3",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "base", value = 1.0 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 3: Disposição
    -- Variação 2: Sobreviente
    arrow_projectile_path3_var2 = {
        id = "arrow_projectile_path3_var2",
        name = "Disposição - Sobreviente",
        description = "Aumenta a |Vida Máxima| em |10%| e a |Regeneração de Vida| em |10%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "arrow_projectile",
        path_id = "path3",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "maxHealth",   type = "percentage", value = 10 },
            { stat = "healthRegen", type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path3
    },
    arrow_projectile_path3_var2_ultimate = {
        id = "arrow_projectile_path3_var2_ultimate",
        name = "Disposição - Sobreviente",
        description = "Aumenta a |Vida Máxima| em |10%| e a |Regeneração de Vida| em |10%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "arrow_projectile",
        path_id = "path3",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 20 },
        },
        color = PATH_COLORS.ultimate
    },
    ---------------------------------------------------------------------------------
    -- CHAIN LIGHTNING (Raios)
    ---------------------------------------------------------------------------------
    -- Caminho 1: Poder
    -- Variação 1: Voltagem
    chain_lightning_path1_var1 = {
        id = "chain_lightning_path1_var1",
        name = "Poder - Voltagem",
        description = "Aumenta o |Dano| em |30%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "chain_lightning",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "damage", type = "percentage", value = 30 },
        },
        color = PATH_COLORS.path1
    },
    chain_lightning_path1_var1_ultimate = {
        id = "chain_lightning_path1_var1_ultimate",
        name = "Poder - Condutividade",
        description =
        "Aumenta a quantidade de |Cadeias| base em |1|, aumenta o |Alcance de Pulo| base em |100|m e reduz a |Velocidade de Ataque| base em |-25%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "chain_lightning",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "chainCount",  type = "base", value = 1 },
            { stat = "jumpRange",   type = "base", value = 100 },
            { stat = "attackSpeed", type = "base", value = -0.25 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 1: Poder
    -- Variação 2: Carga
    chain_lightning_path1_var2 = {
        id = "chain_lightning_path1_var2",
        name = "Poder - Carga",
        description =
        "Aumenta a |Dano| em |10%|, aumenta a |Velocidade de Ataque| em |6%| e aumenta a |Chance de Ataque Múltiplo| em |10%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "chain_lightning",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "damage",            type = "percentage", value = 10 },
            { stat = "attackSpeed",       type = "percentage", value = 6 },
            { stat = "multiAttackChance", type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path1
    },
    chain_lightning_path1_var2_ultimate = {
        id = "chain_lightning_path1_var2_ultimate",
        name = "Poder - Trovão",
        description =
        "Aumenta o |Dano| base em |50|, aumenta a |Chance de Crítico| base em |33%| e reduz a quantidade de |Cadeias| base em |1| e o |Alcance de Pulo| base em |100|m.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "chain_lightning",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage",     type = "base", value = 50 },
            { stat = "critChance", type = "base", value = 0.33 },
            { stat = "chainCount", type = "base", value = -1 },
            { stat = "jumpRange",  type = "base", value = -100 }
        },
        color = PATH_COLORS.path2
    },
    -- Caminho 2: Fisico
    -- Variação 1: Velocidade
    chain_lightning_path2_var1 = {
        id = "chain_lightning_path2_var1_ultimate",
        name = "Fisico - Velocidade",
        description = "Aumenta a |Velocidade de Movimento| em |10%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "chain_lightning",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "moveSpeed", type = "percentage", value = 10 },
        },
        color = PATH_COLORS.path2
    },
    chain_lightning_path2_var1_ultimate = {
        id = "chain_lightning_path2_var1_ultimate",
        name = "Fisico - Explosão",
        description = "Aumenta a |Dano| em |50%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "chain_lightning",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage", type = "percentage", value = 50 },
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Fisico
    -- Variação 2: Resistência
    chain_lightning_path2_var2 = {
        id = "chain_lightning_path2_var2",
        name = "Fisico - Resistência",
        description = "Aumenta a |Vida Máxima| em |10%| e a |Defesa| base em |10|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "chain_lightning",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "maxHealth", type = "percentage", value = 10 },
            { stat = "defense",   type = "base",       value = 10 }
        },
        color = PATH_COLORS.path2
    },
    chain_lightning_path2_var2_ultimate = {
        id = "chain_lightning_path2_var2_ultimate",
        name = "Fisico - Explosão",
        description = "Aumenta o |Dano| base em |100|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "chain_lightning",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage", type = "percentage", value = 100 }
        },
        color = PATH_COLORS.ultimate
    },
    ---------------------------------------------------------------------------------
    -- FLAME STREAM (Lança-chamas)
    ---------------------------------------------------------------------------------
    -- Caminho 1: Manipulação
    -- Variação 1: Destreza
    flame_stream_path1_var1 = {
        id = "flame_stream_path1_var1",
        name = "Manipulação - Destreza",
        description = "Aumenta o |Dano| em |20%| e aumenta a |Força| em |10%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "flame_stream",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "damage",   type = "percentage", value = 20 },
            { stat = "strength", type = "percentage", value = 10 },
        },
        color = PATH_COLORS.path1
    },
    flame_stream_path1_var1_ultimate = {
        id = "flame_stream_path1_var1_ultimate",
        name = "Manipulação - Super Aquecimento",
        description = "Aumenta a |Velocidade de Ataque| base em |3.0| e a |Área| base em |35|°.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "flame_stream",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "base", value = 3.0 },
            { stat = "attackArea",  type = "base", value = math.rad(35) },
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 1: Manipulação
    -- Variação 2: Agilidade
    flame_stream_path1_var2 = {
        id = "flame_stream_path1_var2",
        name = "Manipulação - Agilidade",
        description = "Aumenta a |Velocidade de Ataque| em |15%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "flame_stream",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "attackSpeed", type = "percentage", value = 15 },
        },
        color = PATH_COLORS.path1
    },
    flame_stream_path1_var2_ultimate = {
        id = "flame_stream_path1_var2_ultimate",
        name = "Manipulação - Incêndio",
        description = "Aumenta o |Dano| base em |50| e reduz a |Velocidade de Ataque| base em |1|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "flame_stream",
        path_id = "path1",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage",      type = "base", value = 50 },
            { stat = "attackSpeed", type = "base", value = -1 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Preparação
    -- Variação 1: Recuperação
    flame_stream_path2_var1 = {
        id = "flame_stream_path2_var1",
        name = "Preparação - Recuperação",
        description = "Aumenta a |Regeneração de Vida| em |10%| e a |Velocidade de Movimento| em |5%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "flame_stream",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "healthRegen", type = "percentage", value = 10 },
            { stat = "moveSpeed",   type = "percentage", value = 5 }
        },
        color = PATH_COLORS.path2
    },
    flame_stream_path2_var1_ultimate = {
        id = "flame_stream_path2_var1_ultimate",
        name = "Preparação - Queimadura",
        description = "Aumenta o |Dano| em |30%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "flame_stream",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage", type = "percentage", value = 30 }
        },
        color = PATH_COLORS.ultimate
    },
    -- Caminho 2: Preparação
    -- Variação 2: Recuperação
    flame_stream_path2_var2 = {
        id = "flame_stream_path2_var2",
        name = "Preparação - Recuperação",
        description = "Aumenta a |Vida Máxima| em |10%| e aumenta a |Defesa| em |10%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "flame_stream",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "maxHealth", type = "percentage", value = 10 },
            { stat = "defense",   type = "percentage", value = 10 },
        },
        color = PATH_COLORS.path2
    },
    flame_stream_path2_var2_ultimate = {
        id = "flame_stream_path2_var2_ultimate",
        name = "Preparação - Explosão",
        description = "Aumenta o |Dano| base em |100|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "flame_stream",
        path_id = "path2",
        variation_id = "variation2",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage", type = "percentage", value = 100 }
        },
        color = PATH_COLORS.ultimate,
    },
    --------------------------------- Atualizar Futuramente ---------------------------------
    ---------------------------------------------------------------------------------
    -- BURST PROJECTILE (Shotguns)
    ---------------------------------------------------------------------------------
    -- Caminho 1: Dispersão
    -- Variação 1: Cobertura
    burst_projectile_path1_var1 = {
        id = "burst_projectile_path1_var1",
        name = "Dispersão - Alcance",
        description = "Aumenta o |Alcance| em |10%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "burst_projectile",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "range", type = "percentage", value = 10 }
        },
        color = PATH_COLORS.path1
    },
    burst_projectile_path1_var1_ultimate = {
        id = "burst_projectile_path1_var1_ultimate",
        name = "Dispersão - Explosão",
        description = "Aumenta a |Área| base em |40|° e aumenta os |Projéteis| base em |10|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "burst_projectile",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "attackArea",  type = "base", value = math.rad(40) },
            { stat = "projectiles", type = "base", value = 10 }
        },
        color = PATH_COLORS.ultimate
    },

    -- Caminho 2: Velocidade
    -- Variação 1: Cadência
    burst_projectile_path2_var1 = {
        id = "burst_projectile_path2_var1",
        name = "Velocidade - Cadência",
        description = "Aumenta a |Velocidade de Ataque| em |10%| e a |Chance de Ataque Múltiplo| em |6%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "burst_projectile",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "attackSpeed",       type = "percentage", value = 10 },
            { stat = "multiAttackChance", type = "percentage", value = 6 }
        },
        color = PATH_COLORS.path2
    },
    burst_projectile_path2_var1_ultimate = {
        id = "burst_projectile_path2_var1_ultimate",
        name = "Velocidade - Explosão",
        description = "Aumenta o |Dano| base em |100| e a |Chance de Ataque Múltiplo| base em |80%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "burst_projectile",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "damage",            type = "base", value = 100 },
            { stat = "multiAttackChance", type = "base", value = 80 }
        },
        color = PATH_COLORS.ultimate
    },

    ---------------------------------------------------------------------------------
    -- SEQUENTIAL PROJECTILE (Metralhadoras)
    ---------------------------------------------------------------------------------
    -- Caminho 1: Supressão
    -- Variação 1: Volume de Fogo
    sequential_projectile_path1_var1 = {
        id = "sequential_projectile_path1_var1",
        name = "Supressão",
        description = "Aumenta a |Velocidade de Ataque| em |25%| e a |Chance de Ataque Múltiplo| em |8%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "sequential_projectile",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "attackSpeed",       type = "percentage", value = 25 },
            { stat = "multiAttackChance", type = "percentage", value = 8 }
        },
        color = PATH_COLORS.path1
    },
    sequential_projectile_path1_var1_ultimate = {
        id = "sequential_projectile_path1_var1_ultimate",
        name = "Metralhadora Infernal",
        description =
        "A supressão suprema. |Velocidade de Ataque| |+300%| e |Chance de Ataque Múltiplo| |+150%|, mas |Dano| |-60%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "sequential_projectile",
        path_id = "path1",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "attackSpeed",       type = "percentage", value = 300 },
            { stat = "multiAttackChance", type = "percentage", value = 150 },
            { stat = "damage",            type = "percentage", value = -60 }
        },
        color = PATH_COLORS.ultimate
    },

    -- Caminho 2: Precisão
    -- Variação 1: Controle
    sequential_projectile_path2_var1 = {
        id = "sequential_projectile_path2_var1",
        name = "Controle de Recuo",
        description = "Aumenta a |Chance Crítica| em |6%| e o |Dano Crítico| em |8%|.",
        image_path = tempIconPath,
        max_level = 4,
        attack_class = "sequential_projectile",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = false,
        modifiers_per_level = {
            { stat = "critChance", type = "percentage", value = 6 },
            { stat = "critDamage", type = "percentage", value = 8 }
        },
        color = PATH_COLORS.path2
    },
    sequential_projectile_path2_var1_ultimate = {
        id = "sequential_projectile_path2_var1_ultimate",
        name = "Atirador de Elite",
        description =
        "A precisão suprema. |Chance Crítica| |+80%| e |Dano Crítico| |+100%|, mas |Velocidade de Ataque| |-30%|.",
        image_path = tempIconPath,
        max_level = 1,
        attack_class = "sequential_projectile",
        path_id = "path2",
        variation_id = "variation1",
        is_ultimate = true,
        modifiers_per_level = {
            { stat = "critChance",  type = "percentage", value = 80 },
            { stat = "critDamage",  type = "percentage", value = 100 },
            { stat = "attackSpeed", type = "percentage", value = -30 }
        },
        color = PATH_COLORS.ultimate
    },
}

-- Função para obter traits por classe de ataque
function WeaponTraitsData.GetTraitsByAttackClass(attackClass)
    local traits = {}
    for _, trait in pairs(WeaponTraitsData.Traits) do
        if trait.attack_class == attackClass then
            table.insert(traits, trait)
        end
    end
    return traits
end

-- Função para obter traits disponíveis baseado no progresso atual
function WeaponTraitsData.GetAvailableTraits(attackClass, learnedTraits)
    local availableTraits = {}
    local traitsForClass = WeaponTraitsData.GetTraitsByAttackClass(attackClass)

    for _, trait in pairs(traitsForClass) do
        local canLearn = false

        if trait.is_ultimate then
            -- Ultimates podem aparecer quando qualquer variação do mesmo caminho atingir nível 4
            local currentLevel = learnedTraits[trait.id] or 0
            if currentLevel < trait.max_level then
                canLearn = WeaponTraitsData.CanLearnUltimate(trait, learnedTraits)
            end
        else
            -- Traits normais
            local currentLevel = learnedTraits[trait.id] or 0
            if currentLevel < trait.max_level then
                -- Verifica se pode aprender este trait baseado nas regras de progressão
                canLearn = WeaponTraitsData.CanLearnTrait(trait, learnedTraits)
            end
        end

        if canLearn then
            table.insert(availableTraits, trait)
        end
    end

    return availableTraits
end

-- Função para verificar se pode aprender um trait (aplicar regras de progressão)
function WeaponTraitsData.CanLearnTrait(trait, learnedTraits)
    -- Regra: Não pode misturar variações no mesmo nível
    -- Se já aprendeu uma variação em um nível, deve continuar com ela ou escolher a outra no mesmo nível

    local currentLevel = learnedTraits[trait.id] or 0
    local nextLevel = currentLevel + 1

    -- Verifica se existe outra variação no mesmo caminho e nível
    local otherVariationId = trait.variation_id == "variation1" and "variation2" or "variation1"
    local otherTraitId = trait.attack_class .. "_" .. trait.path_id .. "_" .. otherVariationId .. "_" .. nextLevel

    -- Se a outra variação foi aprendida em um nível superior, não pode aprender esta
    if learnedTraits[otherTraitId] and learnedTraits[otherTraitId] > nextLevel then
        return false
    end

    return true
end

-- Função para verificar se pode aprender um ultimate
function WeaponTraitsData.CanLearnUltimate(trait, learnedTraits)
    -- Verifica se qualquer variação do mesmo caminho atingiu nível 4
    local attackClass = trait.attack_class
    local pathId = trait.path_id

    -- Verifica se qualquer variação do mesmo caminho atingiu nível 4
    local var1TraitId = attackClass .. "_" .. pathId .. "_var1"
    local var2TraitId = attackClass .. "_" .. pathId .. "_var2"

    local var1Level = learnedTraits[var1TraitId] or 0
    local var2Level = learnedTraits[var2TraitId] or 0

    return var1Level >= 4 or var2Level >= 4
end

-- Função para aplicar weapon trait
function WeaponTraitsData.ApplyWeaponTrait(stateController, traitId)
    local trait = WeaponTraitsData.Traits[traitId]
    if not trait then
        error("ERRO [WeaponTraitsData.ApplyWeaponTrait]: Trait com ID '" .. tostring(traitId) .. "' não encontrado.")
    end

    if not stateController then
        error("ERRO [WeaponTraitsData.ApplyWeaponTrait]: stateController inválido.")
    end

    if trait.is_ultimate then
        Logger.info(
            "weapon_traits_data.apply_trait.ultimate",
            "[WeaponTraitsData.ApplyWeaponTrait] ✦ APLICANDO TRAIT ULTIMATE: " .. trait.name .. " ✦"
        )
    else
        Logger.info(
            "weapon_traits_data.apply_trait.normal",
            "[WeaponTraitsData.ApplyWeaponTrait] Aplicando weapon trait: " .. trait.name
        )
    end

    for _, modifier in ipairs(trait.modifiers_per_level) do
        local stat = modifier.stat
        local type = modifier.type
        local value = modifier.value

        Logger.info(
            "weapon_traits_data.apply_trait.modifier",
            string.format("  - Modificador: stat=%s, type=%s, value=%s", tostring(stat), tostring(type), tostring(value))
        )

        if type == "base" then
            stateController:addBaseBonus(stat, value)
        elseif type == "percentage" then
            stateController:addMultiplierBonus(stat, value)
        else
            error("ERRO [WeaponTraitsData.ApplyWeaponTrait]: Tipo de modificador desconhecido ('" ..
                tostring(type) .. "') para o stat '" .. tostring(stat) .. "'.")
        end
    end
end

return WeaponTraitsData
