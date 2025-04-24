-- src/data/items/consumables.lua
local consumables = {
    potion_heal = { -- ID usado no placeholder da UI
        id = "potion_heal", name="Poção Cura", type = "consumable", rarity = "C",
        description="Restaura vida.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1, gridHeight = 1, stackable = true, maxStack = 20,
        -- effect = ...
    },
    medkit = { -- ID usado no placeholder da UI
        id = "medkit", name="Kit Médico", type = "consumable", rarity = "B",
        description="Recupera bastante vida.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 2, gridHeight = 1, stackable = true, maxStack = 5,
        -- effect = ...
    },
    -- Adicione outros consumíveis base aqui...
}
return consumables 