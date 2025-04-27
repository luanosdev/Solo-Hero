-- src/data/items/runes.lua

-- Definições básicas para runas como itens

local runes = {
    -- Runa Orbital
    rune_orbital = {
        itemBaseId = "rune_orbital",
        type = "rune", -- Tipo específico para runas
        name = "Runa Orbital",
        description = "Invoca esferas de energia que orbitam o herói.",
        icon = "assets/items/rune_placeholder.png", -- Ícone temporário
        rarity = 'C',                               -- Exemplo: Comum
        gridWidth = 1,
        gridHeight = 1,
        stackable = false,
        -- Atributos específicos da runa (podemos adicionar mais tarde)
        effect = "orbital",
        num_projectiles = 3,
        damage = 5,
        duration = 10
    },

    -- Runa de Trovão
    rune_thunder = {
        itemBaseId = "rune_thunder",
        type = "rune",
        name = "Runa do Trovão",
        description = "Invoca raios periodicamente em inimigos próximos.",
        icon = "assets/items/rune_placeholder.png", -- Ícone temporário
        rarity = 'R',                               -- Exemplo: Rara
        gridWidth = 1,
        gridHeight = 1,
        stackable = false,
        effect = "thunder",
        interval = 2.0,
        damage = 15,
        radius = 150
    },

    -- Runa de Aura
    rune_aura = {
        itemBaseId = "rune_aura",
        type = "rune",
        name = "Runa de Aura",
        description = "Cria uma aura que causa dano contínuo a inimigos dentro dela.",
        icon = "assets/items/rune_placeholder.png", -- Ícone temporário
        rarity = 'E',                               -- Exemplo: Épica
        gridWidth = 1,
        gridHeight = 1,
        stackable = false,
        effect = "aura",
        damage_per_tick = 2,
        tick_interval = 0.5,
        radius = 100
    }
    -- Adicione outras runas aqui...
}

return runes
