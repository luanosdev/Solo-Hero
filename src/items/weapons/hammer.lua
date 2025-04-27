local BaseWeapon = require("src.items.weapons.base_weapon")
local CircularSmash = require("src.abilities.player.attacks.circular_smash") -- Criaremos este arquivo

local Hammer = BaseWeapon:new({
    itemBaseId = "hammer", -- ID para buscar dados base

    -- Cores para feedback visual da habilidade (usaremos para a animação)
    previewColor = { 0.6, 0.6, 0.6, 0.2 }, -- Cinza semi-transparente
    attackColor = { 0.8, 0.8, 0.7, 0.8 },  -- Cinza-claro quase opaco (para o shockwave)

    -- Define o tipo de ataque que esta arma usa
    attackType = CircularSmash
})

return Hammer
