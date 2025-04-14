local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local BronzeSword = BaseWeapon:new({
    name = "Espada de Bronze",
    description = "Uma espada resistente feita de bronze",
    damage = 8, -- Menos dano que a espada de ferro
    attackSpeed = 1.2, -- Mais rápida que a espada de ferro
    range = 90, -- Alcance um pouco menor
    previewColor = {0.8, 0.5, 0.2, 0.2}, -- Tons de bronze mais claros
    attackColor = {0.7, 0.4, 0.1, 0.6}, -- Tons de bronze mais escuros
    attackType = ConeSlash,
})

return BronzeSword 