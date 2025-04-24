local BaseWeapon = require("src.items.weapons.base_weapon")
local CircularSmash = require("src.abilities.player.attacks.circular_smash") -- Criaremos este arquivo

local Hammer = BaseWeapon:new({
    name = "Martelo de Guerra",
    description = "Um martelo pesado que causa dano em área ao redor do impacto.",
    rarity = "rare", 
    
    -- Stats base da arma
    damage = 180,        -- Dano base alto
    cooldown = 1.2,     -- Cooldown mais longo
    range = 80,         -- Raio da área de efeito do impacto
    angle = 0,          -- Não relevante para ataque circular, mas pode ser necessário para BaseWeapon
    
    -- Cores para feedback visual da habilidade (usaremos para a animação)
    previewColor = {0.6, 0.6, 0.6, 0.2}, -- Cinza semi-transparente
    attackColor = {0.8, 0.8, 0.7, 0.8},  -- Cinza-claro quase opaco (para o shockwave)

    -- Define o tipo de ataque que esta arma usa
    attackType = CircularSmash 
})

return Hammer 