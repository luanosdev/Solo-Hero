local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local StoneSword = BaseWeapon:new({
    name = "Espada de Pedra",
    description = "Uma espada pesada feita de pedra",
    damage = 8,
    cooldown = 1.2,
    range = 100,
    attackType = ConeSlash,
    previewColor = {0.3, 0.3, 0.3, 0.2},
    attackColor = {0.2, 0.2, 0.2, 0.6}
})

return StoneSword 