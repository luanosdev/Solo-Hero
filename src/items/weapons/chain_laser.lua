local BaseWeapon = require("src.items.weapons.base_weapon")
local ChainLightning = require("src.abilities.player.attacks.chain_lightning") -- Criaremos este arquivo

local ChainLaser = BaseWeapon:new({
    itemBaseId = "chain_laser", -- ID para buscar dados base

    -- Cores para feedback visual
    previewColor = { 0.2, 0.8, 1, 0.2 }, -- Azul claro semi-transparente
    attackColor = { 0.5, 1, 1, 0.9 },    -- Ciano brilhante quase opaco

    -- Define o tipo de ataque que esta arma usa
    attackType = ChainLightning
})

return ChainLaser
