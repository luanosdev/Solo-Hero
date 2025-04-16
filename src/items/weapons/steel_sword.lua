local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local SteelSword = BaseWeapon:new({
    name = "Espada de Aço",
    description = "Uma espada resistente feita de aço",
    damage = 15,
    cooldown = 0.8,
    range = 100,
    -- Cores do ataque (tons prateados)
    previewColor = {0.5, 0.5, 0.5, 0.2}, -- Prateado claro
    attackColor = {0.4, 0.4, 0.4, 0.6}, -- Prateado escuro
    attackType = ConeSlash
})

return SteelSword 