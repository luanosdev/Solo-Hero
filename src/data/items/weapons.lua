local Constants = require("src.config.constants")

local weapons = {
    --- Ranking E
    circular_smash_e_001 = {
        id = "circular_smash_e_001",
        name = "Marreta Grande de Forja",
        type = "weapon",
        rarity = "E",
        ranking = "E",
        description = "Uma marreta grande de forja que causa dano em área ao redor do impacto.",
        icon = "assets/items/weapons/circular_smash_e_001.png",
        gridWidth = 2,
        gridHeight = 4,
        stackable = false,
        maxStack = 1,
        damage = 300,
        cooldown = 1.6,
        baseAreaEffectRadius = 80,
        attackClass = "circular_smash",
        weaponClass = "generic_circular_smash",
        knockbackPower = Constants.KNOCKBACK_POWER.HIGH,
        knockbackForce = Constants.KNOCKBACK_FORCE.CIRCULAR_SMASH,
    },

    cone_slash_e_001 = {
        id = "cone_slash_e_001",
        name = "Espada de Ferro",
        type = "weapon",
        rarity = "E",
        ranking = "E",
        description = "Uma espada de ferro que causa dano em área ao redor do impacto.",
        icon = "assets/items/weapons/cone_slash_e_001.png",
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 200,
        cooldown = 0.9,
        range = 180,
        angle = math.pi / 7,
        baseAreaEffectRadius = 50,
        attackClass = "cone_slash",
        weaponClass = "generic_cone_slash",
        knockbackPower = Constants.KNOCKBACK_POWER.MEDIUM,
        knockbackForce = Constants.KNOCKBACK_FORCE.SWORDS,
    },

    alternating_cone_strike_e_001 = {
        id = "alternating_cone_strike_e_001",
        name = "Lâminas de Açougue",
        type = "weapon",
        rarity = "E",
        ranking = "E",
        description = "Lâminas de açougue que causam dano alternado.",
        icon = "assets/items/weapons/alternating_cone_strike_e_001.png",
        gridWidth = 3,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 100,
        cooldown = 0.7,
        range = 120,
        angle = math.pi / 2,
        attackClass = "alternating_cone_strike",
        weaponClass = "generic_alternating_cone_strike",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,
        knockbackForce = Constants.KNOCKBACK_FORCE.ALTERNATING_DAGGERS,
    },

    flame_stream_e_001 = {
        id = "flame_stream_e_001",
        name = "Maçarico Adaptado",
        type = "weapon",
        rarity = "E",
        ranking = "E",
        description = "Um maçarico adaptado que atira chamas que causam dano em área.",
        icon = "assets/items/weapons/flame_stream_e_001.png",
        gridWidth = 4,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 50,
        cooldown = 0.7,
        range = 120,
        angle = math.pi / 12,
        attackClass = "flame_stream",
        weaponClass = "generic_flame_stream",
        -- Atributos específicos do Lança-Chamas
        baseLifetime = 1.0,                              -- Tempo de vida base da partícula em segundos
        particleScale = 0.8,                             -- Escala base da partícula
        piercing = 5,                                    -- Pontos de perfuração inerentes da arma
        knockbackPower = Constants.KNOCKBACK_POWER.NONE, -- Sem knockback por partícula, pois é contínuo (mas projéteis individuais podem ter)
        knockbackForce = Constants.KNOCKBACK_FORCE.NONE,
    },

    arrow_projectile_e_001 = {
        id = "arrow_projectile_e_001",
        name = "Arco de Caça",
        type = "weapon",
        rarity = "E",
        ranking = "E",
        description = "Um arco de caça usado por caçadores de longa distância.",
        icon = "assets/items/weapons/arrow_projectile_e_001.png",
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 200,
        cooldown = 0.9,
        range = 170,
        angle = math.pi / 4,
        -- Atributos específicos do Arco
        projectiles = 1,
        piercing = 2,
        attackClass = "arrow_projectile",
        weaponClass = "generic_arrow_projectile",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,
        knockbackForce = Constants.KNOCKBACK_FORCE.BOW,
    },

    chain_lightning_e_001 = {
        id = "chain_lightning_e_001",
        name = "Bobina Improvisada",
        type = "weapon",
        rarity = "E",
        ranking = "E",
        description = "Uma bobina improvisada que causa dano em área ao redor do impacto.",
        icon = "assets/items/weapons/chain_lightning_e_001.png",
        gridWidth = 4,
        gridHeight = 1,
        stackable = false,
        maxStack = 1,
        damage = 150,
        cooldown = 1.1,
        range = 100,
        -- Atributos específicos da Bobina
        chainCount = 3,
        jumpRange = 100,
        attackClass = "chain_lightning",
        weaponClass = "generic_chain_lightning",
        knockbackPower = Constants.KNOCKBACK_POWER.NONE,
        knockbackForce = Constants.KNOCKBACK_FORCE.NONE,
    },

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
        damage = 120,
        cooldown = 1.2,            -- Cooldown base em segundos (era attackSpeed = 0.83)
        baseAreaEffectRadius = 30, -- Raio da área de impacto
        attackClass = "circular_smash",
        weaponClass = "generic_circular_smash",
        knockbackPower = Constants.KNOCKBACK_POWER.HIGH,   -- Alto poder de iniciar knockback
        knockbackForce = Constants.KNOCKBACK_FORCE.HAMMER, -- Força de knockback alta
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
        damage = 80,
        cooldown = 1.4,       -- Cooldown base em segundos (AJUSTE SE NECESSÁRIO)
        range = 150,          -- Alcance do cone (AJUSTE SE NECESSÁRIO)
        angle = math.pi / 10, -- Ângulo do cone (60 graus) (AJUSTE SE NECESSÁRIO)
        attackClass = "cone_slash",
        weaponClass = "generic_cone_slash",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,    -- Poder de knockback baixo
        knockbackForce = Constants.KNOCKBACK_FORCE.SWORDS, -- Força de knockback baixa
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
        attackClass = "cone_slash",
        weaponClass = "generic_cone_slash",
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
        attackClass = "alternating_cone_strike",
        weaponClass = "generic_alternating_cone_strike",
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
        attackSpeed = 0.4,        -- Tempo entre ataques (mais rápido)
        range = 50,               -- Curto alcance
        criticalChance = 10,      -- Chance de crítico base da arma
        criticalMultiplier = 1.8, -- Multiplicador base da arma
        -- Referência à classe de ataque (precisa existir)
        attackClass = "dual_daggers",
        weaponClass = "generic_dual_daggers",
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
        damage = 20,          -- Dano por partícula/tick?
        cooldown = 0.18,      -- Cooldown base MUITO baixo para fluxo contínuo (era attackSpeed = 5.56)
        range = 180,          -- Distância máxima das partículas
        angle = math.pi / 12, -- Ângulo de DISPERSÃO do fluxo (15 graus)
        attackClass = "flame_stream",
        weaponClass = "generic_flame_stream",
        -- Atributos específicos do Lança-Chamas
        baseLifetime = 1.0,                              -- Tempo de vida base da partícula em segundos
        particleScale = 0.8,                             -- Escala base da partícula
        piercing = 5,                                    -- Pontos de perfuração inerentes da arma
        knockbackPower = Constants.KNOCKBACK_POWER.NONE, -- Sem knockback por partícula, pois é contínuo (mas projéteis individuais podem ter)
        knockbackForce = Constants.KNOCKBACK_FORCE.NONE, -- Força zero para este tipo de arma base, mas partículas podem ter
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
        cooldown = 1.5,      -- Cooldown base em segundos (era attackSpeed = 1.25)
        range = 150,         -- Alcance máximo das flechas
        angle = math.pi / 4, -- Ângulo do cone de disparo (30 graus)
        projectiles = 1,     -- Número base de flechas
        piercing = 2,        -- NOVA PROPRIEDADE: Perfuração base da flecha
        attackClass = "arrow_projectile",
        weaponClass = "generic_arrow_projectile",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW, -- Knockback leve por flecha
        knockbackForce = Constants.KNOCKBACK_FORCE.BOW, -- Força de knockback leve
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
        cooldown = 0.7,  -- Cooldown base em segundos (era attackSpeed = 1.43)
        range = 100,     -- Alcance inicial para encontrar o primeiro alvo
        chainCount = 3,  -- Número de saltos para inimigos adicionais (total 4 alvos)
        jumpRange = 100, -- Distância máxima para saltar entre inimigos
        attackClass = "chain_lightning",
        weaponClass = "generic_chain_lightning",
        knockbackPower = Constants.KNOCKBACK_POWER.NONE,        -- Leve knockback no primeiro hit
        knockbackForce = Constants.KNOCKBACK_FORCE.CHAIN_LASER, -- Força leve
    },
}

return weapons
