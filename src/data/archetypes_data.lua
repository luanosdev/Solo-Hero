local ArchetypesData = {}

-- Definição das propriedades de cada Rank
ArchetypesData.Ranks = {
    E = { id = "E", name = "Rank E", archetype_count_min = 1, archetype_count_max = 2, recruitment_weight = 40 },
    D = { id = "D", name = "Rank D", archetype_count_min = 2, archetype_count_max = 2, recruitment_weight = 30 },
    C = { id = "C", name = "Rank C", archetype_count_min = 3, archetype_count_max = 4, recruitment_weight = 15 },
    B = { id = "B", name = "Rank B", archetype_count_min = 3, archetype_count_max = 5, recruitment_weight = 10 },
    A = { id = "A", name = "Rank A", archetype_count_min = 5, archetype_count_max = 7, recruitment_weight = 4 },
    S = { id = "S", name = "Rank S", archetype_count_min = 7, archetype_count_max = 12, recruitment_weight = 1 },
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
            { stat = "movement_speed", baseValue = 40 }
        }
    },
    vigorous = {
        id = "vigorous",
        name = "Vigoroso",
        rank = "E",
        description = "Um pouco mais resistente que outros, bom para resistir aos ataques.",
        modifiers = {
            { stat = "max_hp", baseValue = 100 }
        }
    },
    -- Rank D
    frenetic = {
        id = "frenetic",
        name = "Frenético",
        rank = "D",
        description = "Ataca com mais frequência.",
        modifiers = {
            { stat = "attack_speed", baseValue = 0.06 }
        }
    },
    cautious = {
        id = "cautious",
        name = "Cauteloso",
        rank = "D",
        description = "Percebe itens de mais longe.",
        modifiers = {
            { stat = "pickupRadius", baseValue = 50 }
        }
    },
    -- Rank C
    determined = {
        id = "determined",
        name = "Determinado",
        rank = "C",
        description = "Velocidade de ataque consistentemente maior.",
        modifiers = {
            { stat = "attack_speed", multValue = 0.12 } -- +12%
        }
    },
    precise = {
        id = "precise",
        name = "Preciso",
        rank = "C",
        description = "Aumenta a chance de acertos críticos.",
        modifiers = {
            { stat = "critical_chance", baseValue = 0.05 } -- +5% chance (chance geralmente é aditiva)
        }
    },
    -- Rank B
    executioner = {
        id = "executioner",
        name = "Executor",
        rank = "B",
        description = "Chance crítica massiva ao custo de defesa.",
        modifiers = {
            { stat = "critical_chance", baseValue = 0.30 }, -- +30% chance
            { stat = "defense",         multValue = -0.10 } -- -10% defesa
        }
    },
    -- Rank A
    assassin = {
        id = "assassin",
        name = "Assassino",
        rank = "A",
        description = "Dano crítico e velocidade de ataque aprimorados.",
        modifiers = {
            { stat = "critical_multiplier", multValue = 0.20 }, -- +20% dano crit
            { stat = "attack_speed",        multValue = 0.20 }  -- +20% vel atq
        }
    },
    -- Rank S
    immortal = {
        id = "immortal",
        name = "Imortal",
        rank = "S",
        description = "Vida drasticamente aumentada.",
        modifiers = {
            { stat = "max_hp", multValue = 0.60 } -- +60% vida
        }
    },
    insane = {
        id = "insane",
        name = "Insano",
        rank = "S",
        description = "Ataques múltiplos frequentes, mas muito vulnerável.",
        modifiers = {
            { stat = "multiAttackChance", baseValue = 0.50, multValue = 0.50 }, -- +50% chance multi-ataque
            { stat = "defense",           multValue = -0.50 }                   -- -50% defesa
        }
    },
    -- Adicionar MUITOS outros arquétipos aqui para cada rank...
}

return ArchetypesData
