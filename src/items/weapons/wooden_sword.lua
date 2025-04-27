local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local WoodenSword = BaseWeapon:new({
    itemBaseId = "wooden_sword", -- ID para buscar dados base

    -- Propriedades específicas mantidas
    attackType = ConeSlash,
    previewColor = { 0.5, 0.3, 0.1, 0.2 },
    attackColor = { 0.3, 0.2, 0.1, 0.6 }
})

return WoodenSword
