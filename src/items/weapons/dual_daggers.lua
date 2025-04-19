local BaseWeapon = require("src.items.weapons.base_weapon")
local AlternatingConeStrike = require("src.abilities.player.attacks.alternating_cone_strike") -- Criaremos este arquivo

local DualDaggers = BaseWeapon:new({
    name = "Adagas Gêmeas",
    description = "Adagas rápidas que golpeiam alternadamente em metades de um cone frontal.",
    rarity = "uncommon", 
    
    -- Stats base da arma
    damage = 20,         -- Dano base por golpe (baixo, mas rápido)
    cooldown = 0.3,     -- Cooldown MUITO baixo para velocidade
    range = 150,         -- Alcance curto, típico de adagas
    angle = math.rad(70), -- Largura total do cone (dividiremos pela metade no ataque)
    
    -- Cores para feedback visual da habilidade (usaremos para a animação)
    previewColor = {0.8, 0.1, 0.8, 0.2}, -- Roxo semi-transparente
    attackColor = {0.8, 0.1, 0.8, 0.7},  -- Roxo mais opaco

    -- Define o tipo de ataque que esta arma usa
    attackType = AlternatingConeStrike 
})

return DualDaggers 