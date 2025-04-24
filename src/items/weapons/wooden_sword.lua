local BaseWeapon = require("src.items.weapons.base_weapon")
local ConeSlash = require("src.abilities.player.attacks.cone_slash")

local WoodenSword = BaseWeapon:new({
    name = "Espada de Madeira",
    description = "Uma espada simples feita de madeira",

    -- Dano base da arma por ataque
    damage = 100,

    -- Cooldown base entre ataques (em segundos). Menor valor = mais rápido
    cooldown = 0.8,

    -- Alcance do ataque (em pixels)
    range = 200,

    -- Largura do ângulo do ataque (em radianos)
    -- Exemplos:
    -- math.pi / 6  = 30 graus
    -- math.pi / 4  = 45 graus
    -- math.pi / 3  = 60 graus
    -- math.pi / 2  = 90 graus
    -- math.pi      = 180 graus
    angle = math.pi / 6, -- Ângulo atual: 45 graus

    -- Habilidade usada para o ataque (geralmente ConeSlash para armas melee)
    attackType = ConeSlash,

    -- Cor da pré-visualização do ataque (RGBA, valores de 0 a 1)
    previewColor = {0.5, 0.3, 0.1, 0.2},

    -- Cor do efeito visual do ataque (RGBA, valores de 0 a 1)
    attackColor = {0.3, 0.2, 0.1, 0.6}
})

return WoodenSword 