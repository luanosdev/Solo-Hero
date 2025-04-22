-- src/data/items/jewels.lua
local jewels = {
    jewel_E = {
        id = "jewel_E", name = "Fragmento Gasto", type = "jewel", rank = "E", rarity = "E",
        description = "Um fragmento de joia quase sem poder.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1, gridHeight = 1, stackable = true, maxStack = 99, color = {0.5, 0.5, 0.5}
    },
    jewel_D = {
        id = "jewel_D", name = "Fragmento Comum", type = "jewel", rank = "D", rarity = "D",
        description = "Um fragmento de joia comum.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1, gridHeight = 1, stackable = true, maxStack = 99, color = {0.8, 0.8, 0.8}
    },
    jewel_C = {
        id = "jewel_C", name = "Joia Menor", type = "jewel", rank = "C", rarity = "C",
        description = "Uma joia com um pouco de poder.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1, gridHeight = 1, stackable = true, maxStack = 50, color = {0.2, 0.8, 0.2}
    },
    jewel_B = {
        id = "jewel_B", name = "Joia", type = "jewel", rank = "B", rarity = "B",
        description = "Uma joia padrão.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1, gridHeight = 1, stackable = true, maxStack = 50, color = {0.2, 0.2, 0.9}
    },
    jewel_A = {
        id = "jewel_A", name = "Joia Maior", type = "jewel", rank = "A", rarity = "A",
        description = "Uma joia de poder considerável.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1, gridHeight = 1, stackable = true, maxStack = 25, color = {0.9, 0.2, 0.9}
    },
    jewel_S = { -- Assumindo que rank S existe baseado nos drops do boss
        id = "jewel_S", name = "Joia Superior", type = "jewel", rank = "S", rarity = "S",
        description = "Uma joia de grande poder.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1, gridHeight = 1, stackable = true, maxStack = 10, color = {1, 0.84, 0} -- Gold-ish
    },
}
return jewels 