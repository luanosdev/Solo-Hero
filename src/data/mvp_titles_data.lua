local MVPTitlesData = {}

-- Definição dos Títulos para MVPs
-- A estrutura é similar aos arquétipos, com ranks e modificadores de status.
MVPTitlesData.Titles = {
    -- Rank E
    the_resistent = {
        id = "the_resistent",
        name = "O Resistente",
        rank = "E",
        description = "Um pouco mais difícil de derrubar.",
        modifiers = {
            { stat = "health",  type = "percentage", value = 10 },
            { stat = "defense", type = "fixed",      value = 5 }
        }
    },
    the_fast = {
        id = "the_fast",
        name = "O Rápido",
        rank = "E",
        description = "Move-se com uma rapidez surpreendente.",
        modifiers = {
            { stat = "moveSpeed", type = "percentage", value = 15 }
        }
    },

    -- Rank D
    the_brutal = {
        id = "the_brutal",
        name = "O Brutal",
        rank = "D",
        description = "Seus ataques são mais fortes que o comum.",
        modifiers = {
            { stat = "damage",   type = "percentage", value = 15 },
            { stat = "strength", type = "fixed",      value = 5 }
        }
    },
    the_hunter = {
        id = "the_hunter",
        name = "O Caçador",
        rank = "D",
        description = "Persegue seus alvos implacavelmente.",
        modifiers = {
            { stat = "moveSpeed", type = "percentage", value = 20 },
            { stat = "range",     type = "percentage", value = 10 }
        }
    },

    -- Rank C
    the_voracious = {
        id = "the_voracious",
        name = "O Voraz",
        rank = "C",
        description = "Velocidade e dano aumentados, uma combinação perigosa.",
        modifiers = {
            { stat = "moveSpeed", type = "percentage", value = 20 },
            { stat = "damage",    type = "percentage", value = 10 }
        }
    },
    the_guardian = {
        id = "the_guardian",
        name = "O Guardião",
        rank = "C",
        description = "Defesa sólida e vitalidade extra.",
        modifiers = {
            { stat = "health",  type = "percentage", value = 30 },
            { stat = "defense", type = "fixed",      value = 25 }
        }
    },

    -- Rank B
    the_tirano = {
        id = "the_tirano",
        name = "O Tirano",
        rank = "B",
        description = "Uma presença opressora no campo de batalha.",
        modifiers = {
            { stat = "damage",     type = "percentage", value = 25 },
            { stat = "health",     type = "percentage", value = 25 },
            { stat = "attackArea", type = "percentage", value = 15 }
        }
    },
    the_spectre = {
        id = "the_spectre",
        name = "O Espectro",
        rank = "B",
        description = "Rápido e difícil de acertar, some e reaparece.",
        modifiers = {
            { stat = "moveSpeed", type = "percentage", value = 30 },
            -- Futuramente, poderia ter um stat de "evasion"
        }
    },

    -- Rank A
    the_devastator = {
        id = "the_devastator",
        name = "O Devastador",
        rank = "A",
        description = "Capaz de destruir tudo em seu caminho.",
        modifiers = {
            { stat = "damage",     type = "percentage",                   value = 40 },
            { stat = "attackArea", type = "percentage",                   value = 25 },
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.10 }
        }
    },
    the_imortal = {
        id = "the_imortal",
        name = "O Imortal",
        rank = "A",
        description = "Uma muralha de carne e osso, quase impossível de matar.",
        modifiers = {
            { stat = "health",          type = "percentage", value = 100 },
            { stat = "knockbackResist", type = "percentage", value = 100 }
        }
    },


    -- Rank S
    the_lich_king = {
        id = "the_lich_king",
        name = "O Rei Lich",
        rank = "S",
        description = "Um ser de poder imenso, comanda a morte.",
        modifiers = {
            { stat = "health",  type = "percentage", value = 150 },
            { stat = "damage",  type = "percentage", value = 50 },
            { stat = "defense", type = "percentage", value = 30 }
            -- Futuramente, poderia invocar outros inimigos
        }
    },
    the_avatar_of_destruction = {
        id = "the_avatar_of_destruction",
        name = "O Avatar da Destruição",
        rank = "S",
        description = "A personificação do caos e da aniquilação.",
        modifiers = {
            { stat = "damage",     type = "percentage",                   value = 100 },
            { stat = "attackArea", type = "percentage",                   value = 50 },
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.50 },
            { stat = "health",     type = "percentage",                   value = -25 }
        }
    }
}

return MVPTitlesData
