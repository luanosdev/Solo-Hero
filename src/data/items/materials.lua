-- src/data/items/materials.lua
local materials = {
    scrap = { -- ID usado no placeholder da UI
        id = "scrap", name="Sucata", type = "material", rarity = "E",
        description="Material básico.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1, gridHeight = 1, stackable = true, maxStack = 99,
    },
    -- Adicione outros materiais base aqui...
}
return materials 