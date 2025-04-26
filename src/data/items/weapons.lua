-- src/data/items/weapons.lua
local weapons = {
    rifle = { -- ID usado no placeholder da UI
        id = "rifle",
        name = "Rifle",
        type = "weapon",
        rarity = "A",
        description = "Arma de longo alcance.",
        icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        -- weapon stats...
    },
    -- Adicione outras armas base aqui...
    skull_staff = {
        id = "skull_staff",
        name = "Cajado da Caveira",
        type = "weapon",
        rarity = "B",
        description = "Um cajado com poderes sombrios.",
        icon = "assets/items/skull_staff.png",
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        -- Stats placeholder:
        damage = 15,
        attackSpeed = 1.1,
        range = 150,
    },
    -- Exemplo:
    -- wooden_sword = {
    --    id = "wooden_sword", name = "Espada de Madeira", type = "weapon", rarity = "E",
    --    description = "Melhor que nada.", icon = nil,
    --    gridWidth = 1, gridHeight = 2, stackable = false, maxStack = 1,
    --    damage = { min = 3, max = 5 }, attackSpeed = 1.2, range = 50,
    -- },
}
return weapons
