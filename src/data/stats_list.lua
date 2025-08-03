--- Lista de todas as chaves de stats válidas no jogo.
-- Utilizado pelo PlayerStateController para construir o grafo de dependências.
---@type StatKey[]
local ALL_STATS = {
    --- Player Stats
    "damage",
    "moveSpeed",
    "maxHealth",
    "defense",
    "attackSpeed",
    "criticalChance",
    "criticalDamage",
    "healthRegen",
    "multiAttackChance",
    "runeSlots",
    "strength",
    "expBonus",
    "healingBonus",
    "pickupRadius",
    "luck",
    "area",
    "range",
    "dashCharges",
    "dashCooldown",
    "dashDistance",
    "dashDuration",
    "potionFlasks",
    "potionHealAmount",
    "potionFillRate",
    --- Weapon Stats
    "piercing",
    "angle",
    "fireRate"
}

return ALL_STATS
