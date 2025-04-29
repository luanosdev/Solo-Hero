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
            { stat = "moveSpeed", baseValue = 40 }
        }
    },
    vigorous = {
        id = "vigorous",
        name = "Vigoroso",
        rank = "E",
        description = "Um pouco mais resistente que outros, bom para resistir aos ataques.",
        modifiers = {
            { stat = "health", baseValue = 100 }
        }
    },
    -- Rank D
    frenetic = {
        id = "frenetic",
        name = "Frenético",
        rank = "D",
        description = "Ataca com mais frequência.",
        modifiers = {
            { stat = "attackSpeed", baseValue = 0.06 }
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
            { stat = "attackSpeed", multValue = 0.12 }
        }
    },
    predestined = {
        id = "predestined",
        name = "Predestinado",
        rank = "C",
        description = "Aumenta a Sorte.",
        modifiers = {
            { stat = "luck", baseValue = 0.05 }
        }
    },
    blessed = {
        id = "blessed",
        name = "Bem-Aventurado",
        rank = "C",
        description = "Aumenta a Quantidade de Slots Runa.",
        modifiers = {
            { stat = "runeSlots", baseValue = 1 }
        }
    },
    precise = {
        id = "precise",
        name = "Preciso",
        rank = "C",
        description = "Aumenta a chance de acertos críticos.",
        modifiers = {
            { stat = "critChance", baseValue = 0.05 }
        }
    },
    -- Rank B
    executioner = {
        id = "executioner",
        name = "Executor",
        rank = "B",
        description = "Chance crítica massiva ao custo de defesa.",
        modifiers = {
            { stat = "critChance", baseValue = 0.30 },
            { stat = "defense",    multValue = -0.10 }
        }
    },
    -- Rank A
    assassin = {
        id = "assassin",
        name = "Assassino",
        rank = "A",
        description = "Dano crítico e velocidade de ataque aprimorados.",
        modifiers = {
            { stat = "critDamage",  multValue = 0.20 },
            { stat = "critChance",  multValue = 0.40 },
            { stat = "attackSpeed", multValue = 0.20 }
        }
    },
    -- Rank S
    immortal = {
        id = "immortal",
        name = "Imortal",
        rank = "S",
        description = "Vida drasticamente aumentada.",
        modifiers = {
            { stat = "health", multValue = 0.60 }
        }
    },
    demon = {
        id = "demon",
        name = "Demônio",
        rank = "S",
        description = "Aumenta a chance de acertos críticos.",
        modifiers = {
            { stat = "critChance", multValue = 0.66 },
            { stat = "critDamage", multValue = 0.66 },
            { stat = "health",     multValue = -0.33 }
        }
    },
    insane = {
        id = "insane",
        name = "Insano",
        rank = "S",
        description = "Ataques múltiplos frequentes, mas muito vulnerável.",
        modifiers = {
            { stat = "multiAttackChance", baseValue = 0.50, multValue = 0.50 },
            { stat = "defense",           multValue = -0.50 }
        }
    },
    -- Rank E
    hardy = {
        id = "hardy",
        name = "Resistente",
        rank = "E",
        description = "Recupera vida ligeiramente mais rápido após sofrer dano.",
        modifiers = {
            { stat = "healthRegenDelay", baseValue = -1.0 }
        }
    },
    collector = {
        id = "collector",
        name = "Coletor",
        rank = "E",
        description = "Aumenta levemente o alcance para coletar itens.",
        modifiers = {
            { stat = "pickupRadius", baseValue = 20 }
        }
    },
    vigilant = {
        id = "vigilant",
        name = "Vigilante",
        rank = "E",
        description = "Detecta inimigos de mais longe.",
        modifiers = {
            { stat = "pickupRadius", baseValue = 30 }
        }
    },

    -- Rank D
    resilient = {
        id = "resilient",
        name = "Resiliente",
        rank = "D",
        description = "Recuperação de vida constante melhorada.",
        modifiers = {
            { stat = "healthPerTick", baseValue = 1 }
        }
    },
    focused = {
        id = "focused",
        name = "Focado",
        rank = "D",
        description = "Reduz um pouco o tempo de recarga de habilidades.",
        modifiers = {
            { stat = "cooldownReduction", multValue = -0.05 }
        }
    },
    shielded = {
        id = "shielded",
        name = "Blindado",
        rank = "D",
        description = "Ganha uma pequena quantidade de defesa adicional.",
        modifiers = {
            { stat = "defense", baseValue = 3 }
        }
    },

    -- Rank C
    fortified = {
        id = "fortified",
        name = "Fortificado",
        rank = "C",
        description = "Aumenta a defesa.",
        modifiers = {
            { stat = "defense", baseValue = 5 }
        }
    },
    healer = {
        id = "healer",
        name = "Curandeiro",
        rank = "C",
        description = "Aumenta a quantidade de cura recebida.",
        modifiers = {
            { stat = "healingBonus", multValue = 0.20 }
        }
    },
    swift = {
        id = "swift",
        name = "Veloz",
        rank = "C",
        description = "Movimenta-se mais rapidamente que o normal.",
        modifiers = {
            { stat = "moveSpeed", multValue = 0.15 }
        }
    },
    tactical = {
        id = "tactical",
        name = "Tático",
        rank = "C",
        description = "Pequeno bônus de redução de recarga.",
        modifiers = {
            { stat = "cooldownReduction", multValue = 0.10 }
        }
    },

    -- Rank B
    ranger = {
        id = "ranger",
        name = "Atirador",
        rank = "B",
        description = "Aumenta o alcance dos ataques.",
        modifiers = {
            { stat = "range", multValue = 0.20 }
        }
    },
    crusher = {
        id = "crusher",
        name = "Esmagador",
        rank = "B",
        description = "Amplia a área de ataque das habilidades e armas.",
        modifiers = {
            { stat = "attackArea", multValue = 0.30 }
        }
    },
    opportunist = {
        id = "opportunist",
        name = "Oportunista",
        rank = "B",
        description = "Pequeno bônus de sorte para acertos críticos e itens.",
        modifiers = {
            { stat = "luck", multValue = 0.15 }
        }
    },

    -- Rank A
    berserker = {
        id = "berserker",
        name = "Berserker",
        rank = "A",
        description = "Velocidade de ataque e área de ataque aumentadas, mas menos defesa.",
        modifiers = {
            { stat = "attackSpeed", multValue = 0.25 },
            { stat = "attackArea",  multValue = 0.20 },
            { stat = "defense",     multValue = -0.10 }
        }
    },
    guardian = {
        id = "guardian",
        name = "Guardião",
        rank = "A",
        description = "Defesa maciça, mas com velocidade reduzida.",
        modifiers = {
            { stat = "defense",   multValue = 0.40 },
            { stat = "moveSpeed", multValue = -0.20 }
        }
    },
    avenger = {
        id = "avenger",
        name = "Vingador",
        rank = "A",
        description = "Aumenta o dano crítico após sofrer dano.",
        modifiers = {
            { stat = "critDamage", multValue = 0.25 }
        }
    },

    -- Rank S
    reaper = {
        id = "reaper",
        name = "Ceifador",
        rank = "S",
        description = "Chance absurda de multi-ataques, mas extremamente frágil.",
        modifiers = {
            { stat = "multiAttackChance", multValue = 1.0 },
            { stat = "defense",           multValue = -0.70 },
            { stat = "health",            multValue = -0.50 }
        }
    },
    godspeed = {
        id = "godspeed",
        name = "Velocidade Divina",
        rank = "S",
        description = "Movimentação e ataque extremamente rápidos.",
        modifiers = {
            { stat = "moveSpeed",   multValue = 0.50 },
            { stat = "attackSpeed", multValue = 0.50 }
        }
    },
    phoenix = {
        id = "phoenix",
        name = "Fênix",
        rank = "S",
        description = "Renasce automaticamente uma vez por partida com metade da vida.",
        modifiers = {
            { stat = "health", multValue = 0.50 }
            -- Efeito especial: revive (pode ser implementado no sistema de habilidades especiais)
        }
    },
    overcharged = {
        id = "overcharged",
        name = "Sobrecarregado",
        rank = "S",
        description = "Reduz drasticamente o tempo de recarga, mas aumenta o dano recebido.",
        modifiers = {
            { stat = "cooldownReduction", multValue = 0.50 },
            { stat = "defense",           multValue = -0.30 }
        }
    }
    -- Adicionar MUITOS outros arquétipos aqui para cada rank...
}

return ArchetypesData
