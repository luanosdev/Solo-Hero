local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local WoodenSword = BaseWeapon:new({
    name = "Espada de Madeira",
    description = "Uma espada simples feita de madeira",
    damage = 100,
    cooldown = 0.8,
    range = 150,
    angle = math.pi / 3, -- 60 graus
    attackType = ConeSlash,
    previewColor = {0.5, 0.3, 0.1, 0.2},
    attackColor = {0.3, 0.2, 0.1, 0.6}
})

return WoodenSword 