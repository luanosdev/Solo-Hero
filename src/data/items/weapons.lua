local Constants = require("src.config.constants")

local weapons = {
    hammer = {
        id = "hammer",
        name = "Martelo de Guerra",
        type = "weapon",
        rarity = "A", -- "rare"
        description = "Um martelo pesado que causa dano em área ao redor do impacto.",
        icon = "assets/items/hammer.png",
        gridWidth = 2,
        gridHeight = 4,
        stackable = false,
        maxStack = 1,
        damage = 180,
        cooldown = 1.2,                                              -- Cooldown base em segundos (era attackSpeed = 0.83)
        baseAreaEffectRadius = 30,                                   -- Raio da área de impacto
        attackClass = "src.abilities.player.attacks.circular_smash", -- Classe de ataque
        knockbackPower = Constants.KNOCKBACK_POWER.HIGH,             -- Alto poder de iniciar knockback
        knockbackForce = Constants.KNOCKBACK_FORCE.HAMMER,           -- Força de knockback alta
    },
    wooden_sword = {
        id = "wooden_sword",
        name = "Espada de Madeira",
        type = "weapon",
        rarity = "E",                           -- Default
        description = "Uma espada simples feita de madeira",
        icon = "assets/items/wooden_sword.png", -- Assumido
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 100,
        cooldown = 1.4,                                          -- Cooldown base em segundos (AJUSTE SE NECESSÁRIO)
        range = 150,                                             -- Alcance do cone (AJUSTE SE NECESSÁRIO)
        angle = math.pi / 10,                                    -- Ângulo do cone (60 graus) (AJUSTE SE NECESSÁRIO)
        attackClass = "src.abilities.player.attacks.cone_slash", -- Classe de ataque associada
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,          -- Poder de knockback baixo
        knockbackForce = Constants.KNOCKBACK_FORCE.SWORDS,       -- Força de knockback baixa
    },
    iron_sword = {
        id = "iron_sword",
        name = "Espada de Ferro",
        type = "weapon",
        rarity = "D",                         -- "uncommon"
        description = "Uma espada de ferro pesada e resistente.",
        icon = "assets/items/iron_sword.png", -- Assumido
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 200,
        cooldown = 1.2,
        range = 200,
        angle = math.pi / 8,
        attackClass = "src.abilities.player.attacks.cone_slash",
        knockbackPower = Constants.KNOCKBACK_POWER.MEDIUM, -- Poder de knockback médio
        knockbackForce = Constants.KNOCKBACK_FORCE.SWORDS, -- Força de knockback média
    },
    dual_daggers = {
        id = "dual_daggers",
        name = "Adagas Gêmeas",
        type = "weapon",
        rarity = "C",                           -- "uncommon"
        description = "Adagas rápidas que golpeiam alternadamente em metades de um cone frontal.",
        icon = "assets/items/dual_daggers.png", -- Assumido
        gridWidth = 3,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 40,
        cooldown = 1,
        range = 100,
        angle = math.pi / 3,
        attackClass = "src.abilities.player.attacks.alternating_cone_strike",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,          -- Baixo, mas rápido
        knockbackForce = Constants.KNOCKBACK_FORCE.DUAL_DAGGERS, -- Força baixa
    },
    dual_noctilara_daggers = {
        id = "dual_noctilara_daggers",
        name = "Adagas Noctilara Gêmeas",
        type = "weapon",
        rarity = "B", -- Raro/Épico? Coloquei B (Epic)
        description = "Adagas curvas que parecem absorver a luz, tiradas da temível Noctilara.",
        icon = nil,   -- TODO: Definir ícone
        gridWidth = 3,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        sellValue = 500,
        -- Stats de combate (exemplo)
        damage = 45,
        attackSpeed = 0.4,                                     -- Tempo entre ataques (mais rápido)
        range = 50,                                            -- Curto alcance
        criticalChance = 10,                                   -- Chance de crítico base da arma
        criticalMultiplier = 1.8,                              -- Multiplicador base da arma
        -- Referência à classe de ataque (precisa existir)
        attackClass = "src.items.weapons.dual_daggers_attack", -- Assumindo uma classe específica ou a dual_daggers_attack
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,
        knockbackForce = Constants.KNOCKBACK_FORCE.DUAL_DAGGERS,
    },
    flamethrower = {
        id = "flamethrower",
        name = "Lança-Chamas",
        type = "weapon",
        rarity = "S",                           -- "rare"
        description = "Dispara um fluxo contínuo de partículas de fogo lentas.",
        icon = "assets/items/flamethrower.png", -- Assumido
        gridWidth = 4,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 20,                                               -- Dano por partícula/tick?
        cooldown = 0.18,                                           -- Cooldown base MUITO baixo para fluxo contínuo (era attackSpeed = 5.56)
        range = 180,                                               -- Distância máxima das partículas
        angle = math.pi / 12,                                      -- Ângulo de DISPERSÃO do fluxo (15 graus)
        attackClass = "src.abilities.player.attacks.flame_stream", -- Classe de ataque
        -- Atributos específicos do Lança-Chamas
        baseLifetime = 1.0,                                        -- Tempo de vida base da partícula em segundos
        particleScale = 0.8,                                       -- Escala base da partícula
        piercing = 5,                                              -- Pontos de perfuração inerentes da arma
        knockbackPower = Constants.KNOCKBACK_POWER.NONE,           -- Sem knockback por partícula, pois é contínuo (mas projéteis individuais podem ter)
        knockbackForce = Constants.KNOCKBACK_FORCE.NONE,           -- Força zero para este tipo de arma base, mas partículas podem ter
    },
    bow = {
        id = "bow",
        name = "Arco Curto",
        type = "weapon",
        rarity = "D",                  -- "common"
        description = "Um arco simples que dispara três flechas.",
        icon = "assets/items/bow.png", -- Assumido
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 33,
        cooldown = 1.5,                                                -- Cooldown base em segundos (era attackSpeed = 1.25)
        range = 150,                                                   -- Alcance máximo das flechas
        angle = math.pi / 4,                                           -- Ângulo do cone de disparo (30 graus)
        projectiles = 1,                                               -- Número base de flechas
        piercing = 2,                                                  -- NOVA PROPRIEDADE: Perfuração base da flecha
        attackClass = "src.abilities.player.attacks.arrow_projectile", -- Classe de ataque
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,                -- Knockback leve por flecha
        knockbackForce = Constants.KNOCKBACK_FORCE.BOW,                -- Força de knockback leve
    },
    chain_laser = {
        id = "chain_laser",
        name = "Laser Encadeado",
        type = "weapon",
        rarity = "B", -- "epic"
        description = "Dispara um raio que salta entre inimigos próximos.",
        icon = "assets/items/chain_laser.png",
        gridWidth = 4,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 35,
        cooldown = 0.7,                                               -- Cooldown base em segundos (era attackSpeed = 1.43)
        range = 100,                                                  -- Alcance inicial para encontrar o primeiro alvo
        chainCount = 3,                                               -- Número de saltos para inimigos adicionais (total 4 alvos)
        jumpRange = 100,                                              -- Distância máxima para saltar entre inimigos
        attackClass = "src.abilities.player.attacks.chain_lightning", -- Classe de ataque
        knockbackPower = 1,                                           -- Leve knockback no primeiro hit
        knockbackForce = 5,                                           -- Força leve
    },
}

return weapons
