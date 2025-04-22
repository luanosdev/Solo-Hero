-- src/data/items/ammo.lua
local ammo = {
    ammo_pistol = { -- ID usado no placeholder da UI
        id = "ammo_pistol", name="Munição Pistola", type = "ammo", rarity="E",
        description="Balas 9mm.", icon = nil, -- TODO: Adicionar path do ícone
        gridWidth=1, gridHeight=1, stackable=true, maxStack=99,
    },
    -- Adicione outros tipos de munição base aqui...
}
return ammo 