local BaseWeapon = require("src.items.weapons.base_weapon")
local FlameStream = require("src.abilities.player.attacks.flame_stream") -- Criaremos este arquivo

local Flamethrower = BaseWeapon:new({
    name = "Lança-Chamas",
    description = "Dispara um fluxo contínuo de partículas de fogo lentas.",
    rarity = "rare", 
    
    -- Stats base da arma
    damage = 20,         -- Dano baixo por partícula
    cooldown = 0.18,    -- Cooldown MAIOR para diminuir cadência
    range = 180,        -- Distância que as partículas viajam
    angle = math.rad(15), -- Ângulo/Largura do cone de dispersão das partículas
    
    -- Cores para feedback visual (partículas de fogo)
    previewColor = {1, 0.5, 0, 0.2}, -- Laranja semi-transparente
    attackColor = {1, 0.3, 0, 0.7},  -- Laranja/Vermelho mais opaco

    -- Define o tipo de ataque que esta arma usa
    attackType = FlameStream 
})

return Flamethrower 