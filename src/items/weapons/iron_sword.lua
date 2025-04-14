local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local IronSword = BaseWeapon:new({
    name = "Espada de Ferro",
    description = "Uma espada básica de ferro",
    damage = 10,
    attackSpeed = 1.0,
    range = 150,
    attackType = ConeSlash
})

return IronSword 