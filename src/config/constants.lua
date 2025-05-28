local Constants = {}

--- IDs constantes para as abas do Lobby.
Constants.TabIds = {
    VENDOR = 1,
    CRAFTING = 2,
    EQUIPMENT = 3,
    PORTALS = 4,
    GUILD = 5,
    SETTINGS = 6,
    QUIT = 7,
}

--- IDs constantes para os slots de equipamento.
Constants.SLOT_IDS = {
    WEAPON = "weapon",
    HELMET = "helmet",
    CHEST = "chest",
    GLOVES = "gloves",
    BOOTS = "boots",
    LEGS = "legs",
    RUNE = "rune_"
    -- Adicionar outros slots conforme necessário (amuletos, anéis etc.)
}

--- Ordem de exibição para os slots de equipamento na UI.
Constants.EQUIPMENT_SLOTS_ORDER = {
    Constants.SLOT_IDS.WEAPON,
    Constants.SLOT_IDS.HELMET,
    Constants.SLOT_IDS.CHEST,
    Constants.SLOT_IDS.LEGS,
    Constants.SLOT_IDS.GLOVES,
    Constants.SLOT_IDS.BOOTS,
    -- Adicionar outros slots na ordem desejada, ex: anéis, amuletos
}

--- Default Base Stats for New Hunters (Before Archetypes)
Constants.HUNTER_DEFAULT_STATS = {
    health = 300,
    attackSpeed = 1.0,         -- Attacks per second
    moveSpeed = 40,
    critChance = 0.10,         -- 10%
    critDamage = 1.5,          -- 150% Multiplier
    multiAttackChance = 1.7,   -- 0%
    expBonus = 1.0,            -- 100%
    defense = 10,
    healthRegenCooldown = 1.0, -- Seconds
    healthPerTick = 1,
    healthRegenDelay = 8.0,    -- Seconds after taking damage
    cooldownReduction = 1.0,   -- Multiplier (1.0 = no reduction)
    range = 1.0,               -- Multiplier (1.0 = base weapon/skill)
    attackArea = 1.0,          -- Multiplier (1.0 = base weapon/skill)
    pickupRadius = 100,        -- Radius
    healingBonus = 1.0,        -- Multiplier (1.0 = 100% healing received)
    runeSlots = 3,             -- Number of rune slots
    luck = 1.0,                -- Multiplier (1.0 = 100% luck)
    strength = 1.0,            -- Multiplier (1.0 = 100% strength)
}

Constants.ENEMY_SPRITE_SIZES = {
    SMALL = 64,
    MEDIUM = 128,
    LARGE = 192,
}

Constants.DEFENSE_DAMAGE_REDUCTION_K = 52
Constants.MAX_DAMAGE_REDUCTION = 0.8

-- <<< ADICIONADO: Dimensões Padrão da Grade >>>
Constants.GRID_ROWS = 4
Constants.GRID_COLS = 4
-- <<< FIM ADIÇÃO >>>

--- Tamanho lógico do tile (em pixels) para o grid do mapa isométrico
--- Este valor define o "tamanho do mundo" de cada tile, não a resolução da imagem do asset
--- Exemplo: 1 tile = 1 metro no mundo do jogo
Constants.TILE_SIZE = 64

--- Tamanho lógico do tile isométrico (em pixels)
--- Use proporção clássica: largura = 2x altura
Constants.TILE_WIDTH = 128
Constants.TILE_HEIGHT = 64

Constants.PLAYER_DAMAGE_COOLDOWN = 0.5

return Constants
