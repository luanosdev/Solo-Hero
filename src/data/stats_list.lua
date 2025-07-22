--- Lista de todas as chaves de stats válidas no jogo.
-- Utilizado pelo PlayerStateController para construir o grafo de dependências.
---@type StatKey[]
local ALL_STATS = {
    "moveSpeed",
    "health",
    "defense",
    "attackSpeed",
    "critChance",
    "critDamage",
    "healthRegen",
    "multiAttackChance",
    "runeSlots",
    "strength",
    "expBonus",
    "healingBonus",
    "pickupRadius",
    "healthRegenDelay",
    "range",
    "luck",
    "attackArea",
    "healthPerTick",
    "cooldownReduction",
    "healthRegenCooldown",
    "dashCharges",
    "dashCooldown",
    "dashDistance",
    "dashDuration",
    "potionFlasks",
    "potionHealAmount",
    "potionFillRate"
}

return ALL_STATS
