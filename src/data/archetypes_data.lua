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
-- Usaremos sufixos: _add para valores fixos, _mult para multiplicadores percentuais (1.1 = +10%, 0.9 = -10%)
ArchetypesData.Archetypes = {
    -- Rank E
    agile = {
        id = "agile",
        name = "Agile",
        rank = "E",
        description = "+2 Move Speed",
        modifiers = { moveSpeed_add = 2 }
    },
    vigorous = {
        id = "vigorous",
        name = "Vigorous",
        rank = "E",
        description = "+100 Max Health",
        modifiers = { health_add = 100 }
    },
    -- Rank D
    frenetic = {
        id = "frenetic",
        name = "Frenetic",
        rank = "D",
        description = "+0.2 Attack Speed",
        modifiers = { attackSpeed_add = 0.2 }
    },
    cautious = {
        id = "cautious",
        name = "Cautious",
        rank = "D",
        description = "+50 Pickup Radius",
        modifiers = { pickupRadius_add = 50 }
    },
    -- Rank C
    determined = {
        id = "determined",
        name = "Determined",
        rank = "C",
        description = "+8% Attack Speed",
        modifiers = { attackSpeed_mult = 1.08 } -- Multiplicador
    },
    precise = {
        id = "precise",
        name = "Precise",
        rank = "C",
        description = "+5% Crit Chance",
        modifiers = { critChance_add = 0.05 } -- Chance é aditiva geralmente
    },
    -- Rank B
    executioner = {
        id = "executioner",
        name = "Executioner",
        rank = "B",
        description = "+30% Crit Chance, -10% Defense",
        modifiers = { critChance_add = 0.30, defense_mult = 0.90 }
    },
    -- Rank A
    assassin = {
        id = "assassin",
        name = "Assassin",
        rank = "A",
        description = "+20% Crit Damage, +20% Attack Speed",
        modifiers = { critDamage_mult = 1.20, attackSpeed_mult = 1.20 }
    },
    -- Rank S
    immortal = {
        id = "immortal",
        name = "Immortal",
        rank = "S",
        description = "+60% Max Health",
        modifiers = { health_mult = 1.60 }
    },
    insane = {
        id = "insane",
        name = "Insane",
        rank = "S",
        description = "+50% Multi Attack Chance, -50% Defense",
        modifiers = { multiAttackChance_add = 0.50, defense_mult = 0.50 }
    },
    -- Adicionar MUITOS outros arquétipos aqui para cada rank...
}

return ArchetypesData
