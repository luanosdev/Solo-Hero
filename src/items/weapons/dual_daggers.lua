local BaseWeapon = require("src.items.weapons.base_weapon")
local AlternatingConeStrike = require("src.abilities.player.attacks.alternating_cone_strike") -- Criaremos este arquivo

local DualDaggers = BaseWeapon:new({
    itemBaseId = "dual_daggers", -- ID para buscar dados base

    -- Cores para feedback visual da habilidade (usaremos para a animação)
    previewColor = { 0.8, 0.1, 0.8, 0.2 }, -- Roxo semi-transparente
    attackColor = { 0.8, 0.1, 0.8, 0.7 },  -- Roxo mais opaco

    -- Define o tipo de ataque que esta arma usa
    attackType = AlternatingConeStrike
})

return DualDaggers
