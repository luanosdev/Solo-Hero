local materials = {
    scrap = { -- ID usado no placeholder da UI
        id = "scrap",
        name = "Sucata",
        type = "material",
        rarity = "E",
        description = "Material básico.",
        icon = nil, -- TODO: Adicionar path do ícone
        gridWidth = 1,
        gridHeight = 1,
        stackable = true,
        maxStack = 99,
    },
    -- Adicione outros materiais base aqui...
    bone_fragment = {
        id = "bone_fragment",
        name = "Fragmento de Osso",
        type = "material",
        rarity = "E",
        description = "Um pequeno pedaço de osso. Pode ser vendido.",
        icon = "assets/items/materials/bone_fragment.png",
        grid = { w = 1, h = 1 },
        stackable = true,
        maxStack = 99,
        sellValue = 1
    },
    tattered_cloth = {
        id = "tattered_cloth",
        name = "Pano Rasgado",
        type = "material",
        rarity = "E",
        description = "Restos de tecido velho. Pode ser vendido.",
        icon = nil,
        grid = { w = 1, h = 1 },
        stackable = true,
        maxStack = 99,
        sellValue = 1
    },
    intact_skull = {
        id = "intact_skull",
        name = "Crânio Intacto",
        type = "material",
        rarity = "D",
        description = "Um crânio bem preservado. Pode valer um bom dinheiro.",
        icon = nil,
        grid = { w = 2, h = 2 },
        stackable = true,
        maxStack = 20, -- Stack menor para item maior/raro
        sellValue = 10
    },
    spider_silk = {
        id = "spider_silk",
        name = "Seda de Aranha",
        type = "material",
        rarity = "D",
        description = "Fios de seda resistentes e pegajosos. Valiosos.",
        icon = nil,
        grid = { w = 1, h = 2 },
        stackable = true,
        maxStack = 50,
        sellValue = 5
    },
    spider_venom_sac = {
        id = "spider_venom_sac",
        name = "Bolsa de Veneno",
        type = "material",
        rarity = "C",
        description = "Uma bolsa pulsante cheia de veneno potente.",
        icon = nil,
        grid = { w = 1, h = 1 },
        stackable = true,
        maxStack = 30,
        sellValue = 25
    },
}
return materials
