local BaseWeapon = require("src.items.weapons.base_weapon")
local ChainLightning = require("src.abilities.player.attacks.chain_lightning") -- Criaremos este arquivo

local ChainLaser = BaseWeapon:new({
    name = "Laser Encadeado",
    description = "Dispara um raio que salta entre inimigos próximos.",
    rarity = "epic", 
    
    -- Stats base da arma
    damage = 35,        -- Dano por acerto
    cooldown = 0.7,     -- Cooldown entre disparos
    range = 3,          -- Número BASE de saltos (alvos = 1 + range)
    angle = 4,          -- Largura BASE do laser em pixels
    
    -- Cores para feedback visual
    previewColor = {0.2, 0.8, 1, 0.2}, -- Azul claro semi-transparente
    attackColor = {0.5, 1, 1, 0.9},  -- Ciano brilhante quase opaco

    -- Define o tipo de ataque que esta arma usa
    attackType = ChainLightning 
})

return ChainLaser 