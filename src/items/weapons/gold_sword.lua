local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local GoldSword = BaseWeapon:new({
    name = "Espada de Ouro",
    description = "Uma espada luxuosa feita de ouro puro",
    damage = 15,
    attackSpeed = 1.2,
    range = 100,
    -- Cores do ataque (tons dourados)
    previewColor = {1, 0.84, 0, 0.2}, -- Dourado claro
    attackColor = {0.85, 0.6, 0, 0.6}, -- Dourado escuro
    attackType = ConeSlash
})

return GoldSword 