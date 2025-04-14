local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local SteelSword = BaseWeapon:new({
    name = "Espada de Aço",
    description = "Uma espada resistente feita de aço temperado",
    damage = 20,
    attackSpeed = 0.9,
    range = 250,
    -- Cores do ataque (tons prateados)
    previewColor = {0.75, 0.75, 0.8, 0.2}, -- Prateado claro
    attackColor = {0.5, 0.5, 0.55, 0.6}, -- Prateado escuro
    attackType = ConeSlash
})

return SteelSword 