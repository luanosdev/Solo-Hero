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

--- Default Base Stats for New Hunters (Before Archetypes)
Constants.HUNTER_DEFAULT_STATS = {
    health = 300,
    attackSpeed = 1.0,         -- Attacks per second
    moveSpeed = 40,
    critChance = 0.10,         -- 10%
    critDamage = 1.5,          -- 150% Multiplier
    multiAttackChance = 0.0,   -- 0%
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
}

Constants.DEFENSE_DAMAGE_REDUCTION_K = 52
Constants.MAX_DAMAGE_REDUCTION = 0.8

-- <<< ADICIONADO: Dimensões Padrão da Grade >>>
Constants.GRID_ROWS = 6
Constants.GRID_COLS = 7
-- <<< FIM ADIÇÃO >>>

return Constants
