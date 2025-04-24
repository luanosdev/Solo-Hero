local BaseWeapon = require("src.items.weapons.base_weapon")
local ArrowProjectile = require("src.abilities.player.attacks.arrow_projectile") -- Vamos criar este arquivo a seguir

local Bow = BaseWeapon:new({
    name = "Arco Curto",
    description = "Um arco simples que dispara três flechas.",
    rarity = "common",
    
    -- Stats base da arma
    damage = 33,         -- Dano base por flecha
    cooldown = 0.8,     -- Tempo base entre ataques
    range = 250,        -- Alcance das flechas (ou da habilidade, a definir)
    angle = math.rad(30), -- Ângulo do cone de disparo das flechas
    baseProjectiles = 3, -- Número base de flechas
    
    -- Cores para feedback visual da habilidade
    previewColor = {0.2, 0.8, 0.2, 0.2}, -- Verde semi-transparente para preview
    attackColor = {0.2, 0.8, 0.2, 0.7},  -- Verde mais opaco para ataque

    -- Define o tipo de ataque que esta arma usa
    attackType = ArrowProjectile 
})

return Bow 