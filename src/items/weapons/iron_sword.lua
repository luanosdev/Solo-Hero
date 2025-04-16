local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local IronSword = BaseWeapon:new({
    name = "Espada de Ferro",
    description = "Uma espada afiada feita de ferro",
    damage = 12,
    cooldown = 1.0,
    range = 100,
    -- Cores do ataque (tons de cinza metálico)
    previewColor = {0.4, 0.4, 0.4, 0.2}, -- Cinza azulado claro
    attackColor = {0.3, 0.3, 0.3, 0.6}, -- Cinza azulado escuro
    attackType = ConeSlash
})

return IronSword 