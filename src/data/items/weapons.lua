--------------------------------------------------------------------------------
--- @author ReyalS
--- @release 1.0
--- @license MIT
--- @description
--- Este arquivo contém as definições de todas as armas do jogo.
--- As armas são definidas com base em um conjunto de tipos para garantir consistência
--- e facilitar a manutenção.

--------------------------------------------------------------------------------
--- TIPOS DE ARMAS (LDOC)
--------------------------------------------------------------------------------

---@class Weapon
---@field id string Identificador único da arma.
---@field name string Nome da arma.
---@field type "weapon" Tipo do item.
---@field rarity "S"|"A"|"B"|"C"|"D"|"E" Raridade da arma.
---@field rank "S"|"A"|"B"|"C"|"D"|"E" Ranking da arma (opcional).
---@field description string Descrição da arma.
---@field icon string|nil Caminho para o ícone da arma.
---@field gridWidth number Largura da arma no inventário.
---@field gridHeight number Altura da arma no inventário.
---@field stackable boolean Se a arma pode ser empilhada.
---@field maxStack number Tamanho máximo da pilha.
---@field damage number Dano base da arma.
---@field cooldown number Tempo de recarga base da arma em segundos.
---@field attackClass string Classe de ataque que a arma utiliza (e.g., "cone_slash").
---@field weaponClass string Classe da arma que a implementa (e.g., "generic_cone_slash").
---@field knockbackPower number Poder de iniciar o knockback (de Constants.KNOCKBACK_POWER).
---@field knockbackForce number Força do knockback (de Constants.KNOCKBACK_FORCE).
---@field previewColor? table Cor de visualização da arma.
---@field attackColor? table Cor de ataque da arma.
---@field sellValue? number Valor de venda da arma.
---@field criticalChance? number Chance de acerto crítico base.
---@field criticalMultiplier? number Multiplicador de dano em acerto crítico.
---@field modifiers? HunterModifier[] Lista de modificadores de atributos do caçador.

---@class HunterModifier
---@field stat string O atributo do caçador a ser modificado (e.g., "moveSpeed", "health").
---@field type "fixed"|"percentage"|"fixed_percentage_as_fraction" O tipo de modificador.
---@field value number O valor do modificador.

---@class CircularSmashWeapon : Weapon
---@field baseAreaEffectRadius number Raio base da área de efeito do ataque.

---@class ConeWeapon : Weapon
---@field range number Alcance base do cone de ataque.
---@field angle number Largura base do ângulo do cone de ataque (em radianos).

---@class FlameStreamWeapon : Weapon
---@field range number Alcance base do fluxo de chamas.
---@field angle number Largura base do ângulo do cone de dispersão (em radianos).
---@field projectileClass string Classe do projétil de partícula de fogo.
---@field baseLifetime number Tempo de vida base da partícula em segundos.
---@field particleScale number Escala base da partícula.
---@field piercing number Pontos de perfuração inerentes da arma.

---@class ProjectileWeapon : Weapon
---@field range number Alcance máximo dos projéteis.
---@field projectiles number Número de projéteis disparados por ataque.
---@field piercing number Capacidade de perfuração base dos projéteis.
---@field projectileClass string Classe do projétil a ser disparado.

---@class SpreadProjectileWeapon : ProjectileWeapon
---@field angle number Ângulo de dispersão dos projéteis (em radianos).

---@class SequentialProjectileWeapon : ProjectileWeapon
---@field cadence number Tempo entre os disparos da mesma rajada (em segundos).

---@class ChainLightningWeapon : Weapon
---@field range number Alcance inicial para encontrar o primeiro alvo.
---@field chainCount number Número de saltos para inimigos adicionais.
---@field jumpRange number Distância máxima para saltar entre inimigos.

local Constants = require("src.config.constants")

local weapons = {
    --- Ranking E
    ---@type CircularSmashWeapon
    circular_smash_e_001 = {
        id = "circular_smash_e_001",
        name = "Marreta Grande de Forja",
        type = "weapon",
        rarity = "E",
        rank = "E",
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
        weaponClass = "base_weapon",
        knockbackPower = Constants.KNOCKBACK_POWER.HIGH,
        knockbackForce = Constants.KNOCKBACK_FORCE.CIRCULAR_SMASH,
        modifiers = {
            { stat = "moveSpeed",   type = "fixed",                        value = -15 },
            { stat = "attackSpeed", type = "fixed_percentage_as_fraction", value = -0.2 },
            { stat = "defense",     type = "fixed",                        value = 10 },
            { stat = "critChance",  type = "fixed_percentage_as_fraction", value = -0.3 },
        }
    },

    ---@type ConeWeapon
    cone_slash_e_001 = {
        id = "cone_slash_e_001",
        name = "Espada de Ferro",
        type = "weapon",
        rarity = "E",
        rank = "E",
        description = "Uma espada de ferro que causa dano em área ao redor do impacto.",
        icon = "assets/items/weapons/cone_slash_e_001.png",
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 200,
        cooldown = 0.9,
        range = 180,
        angle = math.rad(60),
        baseAreaEffectRadius = 50,
        attackClass = "cone_slash",
        weaponClass = "base_weapon",
        knockbackPower = Constants.KNOCKBACK_POWER.MEDIUM,
        knockbackForce = Constants.KNOCKBACK_FORCE.SWORDS,
        modifiers = {
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.1 },
        }
    },

    ---@type ConeWeapon
    alternating_cone_strike_e_001 = {
        id = "alternating_cone_strike_e_001",
        name = "Lâminas de Açougue",
        type = "weapon",
        rarity = "E",
        rank = "E",
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
        weaponClass = "base_weapon",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,
        knockbackForce = Constants.KNOCKBACK_FORCE.ALTERNATING_DAGGERS,
        modifiers = {
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.2 },
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.5 },
            { stat = "moveSpeed",  type = "fixed",                        value = 10 },
        }
    },

    ---@type FlameStreamWeapon
    flame_stream_e_001 = {
        id = "flame_stream_e_001",
        name = "Maçarico Adaptado",
        type = "weapon",
        rarity = "E",
        rank = "E",
        description = "Um maçarico adaptado que atira chamas que causam dano em área.",
        icon = "assets/items/weapons/flame_stream_e_001.png",
        gridWidth = 4,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 50,
        cooldown = 0.7,
        range = 120,
        angle = math.rad(30),
        attackClass = "flame_stream",
        weaponClass = "base_weapon",
        projectileClass = "fire_particle",
        -- Atributos específicos do Lança-Chamas
        baseLifetime = 1.0,                              -- Tempo de vida base da partícula em segundos
        particleScale = 0.8,                             -- Escala base da partícula
        piercing = 5,                                    -- Pontos de perfuração inerentes da arma
        knockbackPower = Constants.KNOCKBACK_POWER.NONE, -- Sem knockback por partícula, pois é contínuo (mas projéteis individuais podem ter)
        knockbackForce = Constants.KNOCKBACK_FORCE.NONE,
        modifiers = {
            { stat = "critChance", type = "fixed_percentage_as_fraction", value = 0.1 },
            { stat = "critDamage", type = "fixed_percentage_as_fraction", value = 0.5 },
        }
    },

    ---@type SpreadProjectileWeapon
    arrow_projectile_e_001 = {
        id = "arrow_projectile_e_001",
        name = "Arco de Caça",
        type = "weapon",
        rarity = "E",
        rank = "E",
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
        projectileClass = "arrow",
        weaponClass = "base_weapon",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,
        knockbackForce = Constants.KNOCKBACK_FORCE.BOW,
    },

    ---@type ChainLightningWeapon
    chain_lightning_e_001 = {
        id = "chain_lightning_e_001",
        name = "Bobina Improvisada",
        type = "weapon",
        rarity = "E",
        rank = "E",
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
        weaponClass = "base_weapon",
        knockbackPower = Constants.KNOCKBACK_POWER.NONE,
        knockbackForce = Constants.KNOCKBACK_FORCE.NONE,
    },
    ---@type SpreadProjectileWeapon
    burst_projectile_e_001 = {
        id = "burst_projectile_e_001",
        name = "Escopeta de Cano Serrado",
        type = "weapon",
        rarity = "E",
        rank = "E",
        description = "Uma escopeta barulhenta que dispara múltiplos projéteis de uma vez.",
        icon = "assets/items/weapons/burst_projectile_e_001.png", -- Ícone a ser criado
        gridWidth = 4,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 15, -- Dano por projétil
        cooldown = 1.3,
        range = 200,
        angle = math.rad(25),        -- Abertura do leque de 25 graus
        -- Atributos específicos
        projectiles = 6,             -- 6 projéteis por disparo
        piercing = 0,                -- Perfuração base de cada projétil
        attackClass = "burst_projectile",
        projectileClass = "pellet",  -- O novo projétil que criamos
        weaponClass = "base_weapon", -- Usa a implementação genérica de BaseWeapon
        knockbackPower = Constants.KNOCKBACK_POWER.MEDIUM,
        knockbackForce = Constants.KNOCKBACK_FORCE.HAMMER,
    },
    ---@type SequentialProjectileWeapon
    sequential_projectile_e_001 = {
        id = "sequential_projectile_e_001",
        name = "Metralhadora de Sucata",
        type = "weapon",
        rarity = "E",
        rank = "E",
        description = "Dispara uma rápida sequência de projéteis. A mira pode ajustar durante a rajada.",
        icon = "assets/items/weapons/sequential_projectile_e_001.png", -- Ícone a ser criado
        gridWidth = 4,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 20,    -- Dano por projétil
        cooldown = 1.0, -- Tempo de espera entre as rajadas
        range = 250,
        -- Atributos específicos
        projectiles = 4, -- 4 projéteis por rajada
        cadence = 0.08,  -- Tempo entre os disparos da mesma rajada
        piercing = 1,
        attackClass = "sequential_projectile",
        projectileClass = "pellet",
        weaponClass = "base_weapon",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,
        knockbackForce = Constants.KNOCKBACK_FORCE.BOW,
    },

    ---@type CircularSmashWeapon
    hammer = {
        id = "hammer",
        name = "Martelo de Guerra",
        type = "weapon",
        rarity = "A",
        rank = "A",
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
    ---@type ConeWeapon
    wooden_sword = {
        id = "wooden_sword",
        name = "Espada de Madeira",
        type = "weapon",
        rarity = "E",
        rank = "E",
        description = "Uma espada simples feita de madeira",
        icon = "assets/items/wooden_sword.png", -- Assumido
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 80,
        cooldown = 1.4,       -- Cooldown base em segundos (AJUSTE SE NECESSÁRIO)
        range = 150,          -- Alcance do cone (AJUSTE SE NECESSÁRIO)
        angle = math.rad(60), -- Ângulo do cone (60 graus) (AJUSTE SE NECESSÁRIO)
        attackClass = "cone_slash",
        weaponClass = "generic_cone_slash",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,    -- Poder de knockback baixo
        knockbackForce = Constants.KNOCKBACK_FORCE.SWORDS, -- Força de knockback baixa
    },
    ---@type ConeWeapon
    iron_sword = {
        id = "iron_sword",
        name = "Espada de Ferro",
        type = "weapon",
        rarity = "D",
        rank = "D",
        description = "Uma espada de ferro pesada e resistente.",
        icon = "assets/items/iron_sword.png", -- Assumido
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 200,
        cooldown = 1.2,
        range = 200,
        angle = math.rad(60),
        attackClass = "cone_slash",
        weaponClass = "generic_cone_slash",
        knockbackPower = Constants.KNOCKBACK_POWER.MEDIUM, -- Poder de knockback médio
        knockbackForce = Constants.KNOCKBACK_FORCE.SWORDS, -- Força de knockback média
    },
    ---@type ConeWeapon
    dual_daggers = {
        id = "dual_daggers",
        name = "Adagas Gêmeas",
        type = "weapon",
        rarity = "C",
        rank = "C",
        description = "Adagas rápidas que golpeiam alternadamente em metades de um cone frontal.",
        icon = "assets/items/dual_daggers.png", -- Assumido
        gridWidth = 3,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 40,
        cooldown = 1,
        range = 100,
        angle = math.rad(150),
        attackClass = "alternating_cone_strike",
        weaponClass = "generic_alternating_cone_strike",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,          -- Baixo, mas rápido
        knockbackForce = Constants.KNOCKBACK_FORCE.DUAL_DAGGERS, -- Força baixa
    },
    ---@type ConeWeapon
    dual_noctilara_daggers = {
        id = "dual_noctilara_daggers",
        name = "Adagas Noctilara Gêmeas",
        type = "weapon",
        rarity = "B",
        rank = "B",
        description = "Adagas curvas que parecem absorver a luz, tiradas da temível Noctilara.",
        icon = nil, -- TODO: Definir ícone
        gridWidth = 3,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        sellValue = 500,
        -- Stats de combate (exemplo)
        damage = 45,
        cooldown = 0.4,           -- Tempo entre ataques (mais rápido)
        range = 50,               -- Curto alcance
        angle = math.rad(150),
        criticalChance = 10,      -- Chance de crítico base da arma
        criticalMultiplier = 1.8, -- Multiplicador base da arma
        -- Referência à classe de ataque (precisa existir)
        attackClass = "alternating_cone_strike",
        weaponClass = "generic_alternating_cone_strike",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW,
        knockbackForce = Constants.KNOCKBACK_FORCE.DUAL_DAGGERS,
        -- Modificadores de Atributos do Caçador
        modifiers = {
            { stat = "moveSpeed", type = "percentage", value = 5 } -- +5% de velocidade de movimento
        }
    },
    ---@type FlameStreamWeapon
    flamethrower = {
        id = "flamethrower",
        name = "Lança-Chamas",
        type = "weapon",
        rarity = "S",
        rank = "S",
        description = "Dispara um fluxo contínuo de partículas de fogo lentas.",
        icon = "assets/items/flamethrower.png", -- Assumido
        gridWidth = 4,
        gridHeight = 2,
        stackable = false,
        maxStack = 1,
        damage = 20,          -- Dano por partícula/tick?
        cooldown = 0.18,      -- Cooldown base MUITO baixo para fluxo contínuo (era attackSpeed = 5.56)
        range = 180,          -- Distância máxima das partículas
        angle = math.rad(15), -- Ângulo de DISPERSÃO do fluxo (15 graus)
        attackClass = "flame_stream",
        weaponClass = "base_weapon",
        projectileClass = "fire_particle",
        -- Atributos específicos do Lança-Chamas
        baseLifetime = 1.0,                              -- Tempo de vida base da partícula em segundos
        particleScale = 0.8,                             -- Escala base da partícula
        piercing = 5,                                    -- Pontos de perfuração inerentes da arma
        knockbackPower = Constants.KNOCKBACK_POWER.NONE, -- Sem knockback por partícula, pois é contínuo (mas projéteis individuais podem ter)
        knockbackForce = Constants.KNOCKBACK_FORCE.NONE, -- Força zero para este tipo de arma base, mas partículas podem ter
    },
    ---@type SpreadProjectileWeapon
    bow = {
        id = "bow",
        name = "Arco Curto",
        type = "weapon",
        rarity = "D",
        rank = "D",
        description = "Um arco simples que dispara três flechas.",
        icon = "assets/items/bow.png", -- Assumido
        gridWidth = 1,
        gridHeight = 3,
        stackable = false,
        maxStack = 1,
        damage = 33,
        cooldown = 1.5,       -- Cooldown base em segundos (era attackSpeed = 1.25)
        range = 150,          -- Alcance máximo das flechas
        angle = math.rad(30), -- Ângulo do cone de disparo (30 graus)
        projectiles = 1,      -- Número base de flechas
        piercing = 2,         -- NOVA PROPRIEDADE: Perfuração base da flecha
        attackClass = "arrow_projectile",
        projectileClass = "arrow",
        weaponClass = "base_weapon",
        knockbackPower = Constants.KNOCKBACK_POWER.LOW, -- Knockback leve por flecha
        knockbackForce = Constants.KNOCKBACK_FORCE.BOW, -- Força de knockback leve
    },
    ---@type ChainLightningWeapon
    chain_laser = {
        id = "chain_laser",
        name = "Laser Encadeado",
        type = "weapon",
        rarity = "B",
        rank = "B",
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
        weaponClass = "base_weapon",
        knockbackPower = Constants.KNOCKBACK_POWER.NONE,        -- Leve knockback no primeiro hit
        knockbackForce = Constants.KNOCKBACK_FORCE.CHAIN_LASER, -- Força leve
    },
}

return weapons
