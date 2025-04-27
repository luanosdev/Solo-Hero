local BaseWeapon = require("src.items.weapons.base_weapon")
local FlameStream = require("src.abilities.player.attacks.flame_stream") -- Criaremos este arquivo

local Flamethrower = BaseWeapon:new({
    itemBaseId = "flamethrower", -- ID para buscar dados base

    -- Cores para feedback visual (partículas de fogo)
    previewColor = { 1, 0.5, 0, 0.2 }, -- Laranja semi-transparente
    attackColor = { 1, 0.3, 0, 0.7 },  -- Laranja/Vermelho mais opaco

    -- Define o tipo de ataque que esta arma usa
    attackType = FlameStream
})

return Flamethrower
