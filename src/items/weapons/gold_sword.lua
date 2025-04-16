local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local GoldSword = BaseWeapon:new({
    name = "Espada de Ouro",
    description = "Uma espada feita de ouro puro",
    damage = 15,
    cooldown = 1.2,
    range = 120,
    -- Cores do ataque (tons dourados)
    previewColor = {1, 0.843, 0, 0.2}, -- Dourado claro
    attackColor = {1, 0.843, 0, 0.6}, -- Dourado escuro
    attackType = ConeSlash
})

return GoldSword 