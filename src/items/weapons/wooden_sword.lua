local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local WoodenSword = BaseWeapon:new({
    name = "Espada de Madeira",
    description = "Uma espada simples feita de madeira",
    damage = 5,
    cooldown = 0.8,
    range = 80,
    attackType = ConeSlash,
    previewColor = {0.5, 0.3, 0.1, 0.2},
    attackColor = {0.3, 0.2, 0.1, 0.6}
})

return WoodenSword 