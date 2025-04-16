local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local BronzeSword = BaseWeapon:new({
    name = "Espada de Bronze",
    description = "Uma espada elegante feita de bronze",
    damage = 10,
    cooldown = 0.9,
    range = 100,
    attackType = ConeSlash,
    previewColor = {0.8, 0.5, 0.2, 0.2},
    attackColor = {0.6, 0.4, 0.1, 0.6}
})

return BronzeSword 