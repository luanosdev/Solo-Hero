-- CONVENÇÕES PARA VALORES DE MODIFICADORES DE ARQUÉTIPO:
-- Cada modificador DEVE ter um campo 'type' e 'value'.
--
-- type = "fixed":
--   O 'value' é um número absoluto que será somado diretamente ao stat base (pelo HunterManager)
--   ou ao fixedBonus do PlayerState (se aplicado dinamicamente).
--   Ex: { stat = "health", type = "fixed", value = 100 }
--       { stat = "healthRegenDelay", type = "fixed", value = 1.0 } (Positivo aqui REDUZ o delay no PlayerState)
--
-- type = "percentage":
--   O 'value' é um número que representa o percentual direto (ex: 10 para +10%, -5 para -5%).
--   Aplicado multiplicativamente ao stat base (pelo HunterManager, ex: stat * (1 + value/100))
--   ou somado ao 'levelBonus' do PlayerState (que depois é usado como percentual).
--   Ex: { stat = "attackSpeed", type = "percentage", value = 6 } (resulta em +6%)
--       { stat = "cooldownReduction", type = "percentage", value = 10 } (Positivo aqui AUMENTA a redução no PlayerState)
--
-- type = "fixed_percentage_as_fraction":
--   O 'value' é a fração decimal correspondente ao percentual desejado (ex: 0.05 para 5%).
--   Somado ao stat base (pelo HunterManager, se o stat for uma fração/multiplicador)
--   ou somado ao 'fixedBonus' do PlayerState.
--   Ex: { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.05 }
--
-- A lógica que aplica os arquétipos (HunterManager) deve interpretar estes tipos para modificar os stats base.
-- A lógica que aplica bônus dinâmicos (LevelUpBonusesData.ApplyBonus) usa estes tipos para chamar
-- playerState:addAttributeBonus(stat, percentageValue, fixedValue) corretamente.

local ArchetypesData = {}

-- Definição das propriedades de cada Rank
ArchetypesData.Ranks = {
    E = { id = "E", name = "Rank E", archetype_count_min = 1, archetype_count_max = 3, recruitment_weight = 40 },
    D = { id = "D", name = "Rank D", archetype_count_min = 3, archetype_count_max = 5, recruitment_weight = 30 },
    C = { id = "C", name = "Rank C", archetype_count_min = 5, archetype_count_max = 7, recruitment_weight = 15 },
    B = { id = "B", name = "Rank B", archetype_count_min = 7, archetype_count_max = 9, recruitment_weight = 10 },
    A = { id = "A", name = "Rank A", archetype_count_min = 9, archetype_count_max = 12, recruitment_weight = 4 },
    S = { id = "S", name = "Rank S", archetype_count_min = 12, archetype_count_max = 15, recruitment_weight = 1 },
    -- SS poderia ser um rank alcançado por sorte/combinação, não sorteado diretamente?
}

-- Definição dos Arquétipos
-- Modifiers: Lista de tabelas { stat="id", baseValue=num } ou { stat="id", multValue=decimal (0.05 = +5%) }
ArchetypesData.Archetypes = {
    -- Rank E
    agile = {
        id = "agile",
        name = "Ágil",
        rank = "E",
        description = "É mais rapido que outros, bom para fugir de inimigos.",
        modifiers = {
            { stat = "moveSpeed", type = "fixed", value = 20 }
        }
    },
    vigorous = {
        id = "vigorous",
        name = "Vigoroso",
        rank = "E",
        description = "Um pouco mais resistente que outros, bom para resistir aos ataques.",
        modifiers = {
            { stat = "health", type = "fixed", value = 100 }
        }
    },
    aprendiz_rapido = {
        id = "aprendiz_rapido",
        name = "Aprendiz Rápido",
        rank = "E",
        description = "Ganha experiência um pouco mais rápido.",
        modifiers = {
            { stat = "expBonus", type = "percentage", value = 5 }
        }
    },
    sortudo_pequeno = {
        id = "sortudo_pequeno",
        name = "Um pouco Sortudo",
        rank = "E",
        description = "Um leve aumento na sorte geral.",
        modifiers = {
            { stat = "luck", type = "percentage", value = 5 }
        }
    },
    bruto_pequeno = {
        id = "bruto_pequeno",
        name = "Pequeno Bruto",
        rank = "E",
        description = "Um leve aumento na Força.",
        modifiers = {
            { stat = "strength", type = "fixed", value = 3 }
        }
    },
    -- Rank D
    frenetic = {
        id = "frenetic",
        name = "Frenético",
        rank = "D",
        description = "Ataca com mais frequência.",
        modifiers = {
            { stat = "attackSpeed", type = "fixed_percentage_as_fraction", value = 0.06 }
        }
    },
    cautious = {
        id = "cautious",
        name = "Cauteloso",
        rank = "D",
        description = "Percebe itens de mais longe.",
        modifiers = {
            { stat = "pickupRadius", type = "fixed", value = 50 }
        }
    },
    barreira_magica = {
        id = "barreira_magica",
        name = "Barreira Mágica",
        rank = "D",
        description = "Concede defesa extra, mas reduz levemente a velocidade de movimento.",
        modifiers = {
            { stat = "defense",   type = "fixed",      value = 15 },
            { stat = "moveSpeed", type = "percentage", value = -5 }
        }
    },
    eco_temporal = {
        id = "eco_temporal",
        name = "Eco Temporal",
        rank = "D",
        description = "As habilidades recarregam um pouco mais rápido.",
        modifiers = {
            { stat = "cooldownReduction", type = "percentage", value = 7 }
        }
    },
    -- Rank C
    determined = {
        id = "determined",
        name = "Determinado",
        rank = "C",
        description = "Velocidade de ataque consistentemente maior.",
        modifiers = {
            { stat = "attackSpeed", type = "percentage", value = 12 }
        }
    },
    predestined = {
        id = "predestined",
        name = "Predestinado",
        rank = "C",
        description = "Aumenta a Sorte.",
        modifiers = {
            { stat = "luck", type = "fixed_percentage_as_fraction", value = 0.05 }
        }
    },
    guerreiro_nato = {
        id = "guerreiro_nato",
        name = "Guerreiro Nato",
        rank = "C",
        description = "Força e Vida aumentadas.",
        modifiers = {
            { stat = "strength", type = "fixed", value = 5 },
            { stat = "health",   type = "fixed", value = 50 }
        }
    },
    blessed = {
        id = "blessed",
        name = "Bem-Aventurado",
        rank = "C",
        description = "Aumenta a Quantidade de Slots Runa.",
        modifiers = {
            { stat = "runeSlots", type = "fixed", value = 1 }
        }
    },
    precise = {
        id = "precise",
        name = "Preciso",
        rank = "C",
        description = "Aumenta a chance de acertos críticos.",
        modifiers = {
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.05 }
        }
    },
    muralha = {
        id = "muralha",
        name = "Muralha",
        rank = "C",
        description = "Vida significativamente aumentada, mas com penalidade na velocidade de movimento.",
        modifiers = {
            { stat = "health",    type = "percentage", value = 35 },
            { stat = "moveSpeed", type = "percentage", value = -15 }
        }
    },
    explorador_avancado = {
        id = "explorador_avancado",
        name = "Explorador Avançado",
        rank = "C",
        description = "Aumenta o raio de coleta de itens e o ganho de experiência.",
        modifiers = {
            { stat = "pickupRadius", type = "fixed",      value = 75 },
            { stat = "expBonus",     type = "percentage", value = 100 }
        }
    },
    evasivo = {
        id = "evasivo",
        name = "Evasivo",
        rank = "C",
        description = "Recarrega o dash mais rápido e se move com mais agilidade.",
        modifiers = {
            { stat = "dashCooldown", type = "percentage", value = -15 }, -- Reduz o cooldown em 15%
            { stat = "moveSpeed",    type = "percentage", value = 10 }
        }
    },
    -- Rank B
    executioner = {
        id = "executioner",
        name = "Executor",
        rank = "B",
        description = "Chance crítica massiva ao custo de defesa.",
        modifiers = {
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.30 },
            { stat = "defense",    type = "percentage",                   value = -10 },
            { stat = "attackArea", type = "percentage",                   value = 30 }
        }
    },
    atirador_elite = {
        id = "atirador_elite",
        name = "Atirador de Elite",
        rank = "B",
        description = "Aumenta consideravelmente o alcance dos ataques, com uma pequena redução na velocidade de ataque.",
        modifiers = {
            { stat = "range",       type = "percentage", value = 35 },
            { stat = "attackSpeed", type = "percentage", value = -5 }
        }
    },
    vampiro_menor = {
        id = "vampiro_menor",
        name = "Vampiro Menor",
        rank = "B",
        description = "Melhora a regeneração de vida por segundo, mas diminui a vida máxima.",
        modifiers = {
            { stat = "healthPerTick", type = "fixed",      value = 2 },
            { stat = "health",        type = "percentage", value = -10 }
        }
    },
    ariete = {
        id = "ariete",
        name = "Aríete",
        rank = "B",
        description = "Avança uma distância muito maior, mas o dash demora mais para recarregar.",
        modifiers = {
            { stat = "dashDistance", type = "percentage", value = 100 },
            { stat = "dashCooldown", type = "percentage", value = 25 } -- Aumenta o cooldown em 25%
        }
    },
    -- Rank A
    assassin = {
        id = "assassin",
        name = "Assassino",
        rank = "A",
        description = "Dano crítico e velocidade de ataque aprimorados.",
        modifiers = {
            { stat = "critDamage",  type = "fixed_percentage_as_fraction", value = 0.20 },
            { stat = "critChance",  type = "fixed_percentage_as_fraction", value = 0.10 },
            { stat = "attackSpeed", type = "percentage",                   value = 10 }
        }
    },
    berserker = {
        id = "berserker",
        name = "Berserker",
        rank = "A",
        description = "Velocidade de ataque e área de ataque aumentadas, mas menos defesa.",
        modifiers = {
            { stat = "attackSpeed", type = "percentage", value = 25 },
            { stat = "attackArea",  type = "percentage", value = 20 },
            { stat = "defense",     type = "percentage", value = -10 }
        }
    },
    mestre_das_runas = {
        id = "mestre_das_runas",
        name = "Mestre das Runas",
        rank = "A",
        description = "Concede um slot de runa adicional e melhora a redução de recarga.",
        modifiers = {
            { stat = "runeSlots",         type = "fixed",      value = 1 },
            { stat = "cooldownReduction", type = "percentage", value = 15 }
        }
    },
    colosso = {
        id = "colosso",
        name = "Colosso",
        rank = "A",
        description = "Força e Defesa massivamente aumentadas, mas com grande penalidade na velocidade de ataque.",
        modifiers = {
            { stat = "strength",    type = "percentage", value = 25 },
            { stat = "defense",     type = "percentage", value = 20 },
            { stat = "attackSpeed", type = "percentage", value = -15 }
        }
    },
    -- Rank S
    immortal = {
        id = "immortal",
        name = "Imortal",
        rank = "S",
        description = "Vida drasticamente aumentada.",
        modifiers = {
            { stat = "health", type = "percentage", value = 60 }
        }
    },
    demon = {
        id = "demon",
        name = "Demônio",
        rank = "S",
        description = "Aumenta a chance de acertos críticos.",
        modifiers = {
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.20 },
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.30 },
            { stat = "health",     type = "percentage",                   value = -33 }
        }
    },
    insane = {
        id = "insane",
        name = "Insano",
        rank = "S",
        description = "Ataques múltiplos frequentes, mas muito vulnerável.",
        modifiers = {
            { stat = "multiAttackChance", type = "fixed_percentage_as_fraction", value = 0.30 },
            { stat = "defense",           type = "percentage",                   value = -50 }
        }
    },
    -- Rank E
    hardy = {
        id = "hardy",
        name = "Resistente",
        rank = "E",
        description = "Recupera vida ligeiramente mais rápido após sofrer dano.",
        modifiers = {
            { stat = "healthRegenDelay", type = "fixed", value = 1.0 }
        }
    },
    collector = {
        id = "collector",
        name = "Coletor",
        rank = "E",
        description = "Aumenta levemente o alcance para coletar itens.",
        modifiers = {
            { stat = "pickupRadius", type = "fixed", value = 20 }
        }
    },
    vigilant = {
        id = "vigilant",
        name = "Vigilante",
        rank = "E",
        description = "Detecta itens de mais longe.",
        modifiers = {
            { stat = "pickupRadius", type = "fixed", value = 30 }
        }
    },

    -- Rank D
    resilient = {
        id = "resilient",
        name = "Resiliente",
        rank = "D",
        description = "Recuperação de vida constante melhorada.",
        modifiers = {
            { stat = "healthPerTick", type = "fixed", value = 1 }
        }
    },
    focused = {
        id = "focused",
        name = "Focado",
        rank = "D",
        description = "Reduz um pouco o tempo de recarga de habilidades.",
        modifiers = {
            { stat = "cooldownReduction", type = "percentage", value = 5 }
        }
    },
    shielded = {
        id = "shielded",
        name = "Blindado",
        rank = "D",
        description = "Ganha uma pequena quantidade de defesa adicional.",
        modifiers = {
            { stat = "defense", type = "fixed", value = 10 }
        }
    },

    -- Rank C
    fortified = {
        id = "fortified",
        name = "Fortificado",
        rank = "C",
        description = "Aumenta a defesa.",
        modifiers = {
            { stat = "defense", type = "fixed", value = 20 }
        }
    },
    healer = {
        id = "healer",
        name = "Curandeiro",
        rank = "C",
        description = "Aumenta a quantidade de cura recebida.",
        modifiers = {
            { stat = "healingBonus", type = "percentage", value = 20 }
        }
    },
    swift = {
        id = "swift",
        name = "Veloz",
        rank = "C",
        description = "Movimenta-se mais rapidamente que o normal.",
        modifiers = {
            { stat = "moveSpeed", type = "percentage", value = 15 }
        }
    },
    tactical = {
        id = "tactical",
        name = "Tático",
        rank = "C",
        description = "Pequeno bônus de redução de recarga.",
        modifiers = {
            { stat = "cooldownReduction", type = "percentage", value = 10 }
        }
    },

    -- Rank B
    ranger = {
        id = "ranger",
        name = "Atirador",
        rank = "B",
        description = "Aumenta o alcance dos ataques.",
        modifiers = {
            { stat = "range", type = "percentage", value = 20 }
        }
    },
    crusher = {
        id = "crusher",
        name = "Esmagador",
        rank = "B",
        description = "Amplia a área de ataque das habilidades e armas.",
        modifiers = {
            { stat = "attackArea", type = "percentage", value = 30 }
        }
    },
    opportunist = {
        id = "opportunist",
        name = "Oportunista",
        rank = "B",
        description = "Pequeno bônus de sorte para acertos críticos e itens.",
        modifiers = {
            { stat = "luck", type = "percentage", value = 15 }
        }
    },

    -- Rank A
    berserker = {
        id = "berserker",
        name = "Berserker",
        rank = "A",
        description = "Velocidade de ataque e área de ataque aumentadas, mas menos defesa.",
        modifiers = {
            { stat = "attackSpeed", type = "percentage", value = 25 },
            { stat = "attackArea",  type = "percentage", value = 20 },
            { stat = "defense",     type = "percentage", value = -10 }
        }
    },
    guardian = {
        id = "guardian",
        name = "Guardião",
        rank = "A",
        description = "Defesa maciça, mas com velocidade reduzida.",
        modifiers = {
            { stat = "defense",   type = "percentage", value = 40 },
            { stat = "moveSpeed", type = "percentage", value = -20 }
        }
    },
    avenger = {
        id = "avenger",
        name = "Vingador",
        rank = "A",
        description = "Aumenta o dano crítico após sofrer dano.",
        modifiers = {
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.25 }
        }
    },

    -- Rank S
    reaper = {
        id = "reaper",
        name = "Ceifador",
        rank = "S",
        description = "Chance absurda de multi-ataques, mas extremamente frágil.",
        modifiers = {
            { stat = "multiAttackChance", type = "percentage", value = 100 },
            { stat = "defense",           type = "percentage", value = -70 },
            { stat = "health",            type = "percentage", value = -50 }
        }
    },
    godspeed = {
        id = "godspeed",
        name = "Velocidade Divina",
        rank = "S",
        description = "Movimentação e ataque extremamente rápidos.",
        modifiers = {
            { stat = "moveSpeed",   type = "percentage", value = 50 },
            { stat = "attackSpeed", type = "percentage", value = 50 }
        }
    },
    phoenix = {
        id = "phoenix",
        name = "Fênix",
        rank = "S",
        description = "Renasce automaticamente uma vez por partida com metade da vida.",
        modifiers = {
            { stat = "health", type = "percentage", value = 50 }
            -- Efeito especial: revive (pode ser implementado no sistema de habilidades especiais)
        }
    },
    overcharged = {
        id = "overcharged",
        name = "Sobrecarregado",
        rank = "S",
        description = "Reduz drasticamente o tempo de recarga, mas aumenta o dano recebido.",
        modifiers = {
            { stat = "cooldownReduction", type = "percentage", value = 50 },
            { stat = "defense",           type = "percentage", value = -30 }
        }
    },
    arcanista_proibido = {
        id = "arcanista_proibido",
        name = "Arcanista Proibido",
        rank = "S",
        description =
        "Poder Arcano Imenso: Dano crítico, área de ataque e redução de recarga significativamente aumentados, mas com grande sacrifício de vida.",
        modifiers = {
            { stat = "critDamage",        type = "fixed_percentage_as_fraction", value = 0.75 }, -- +75% Dano Crítico
            { stat = "attackArea",        type = "percentage",                   value = 50 },   -- +50% Área
            { stat = "cooldownReduction", type = "percentage",                   value = 30 },   -- +30% Redução Recarga
            { stat = "health",            type = "percentage",                   value = -60 }   -- -60% Vida Máxima
        }
    }
    -- Adicionar MUITOS outros arquétipos aqui para cada rank...
}

return ArchetypesData
