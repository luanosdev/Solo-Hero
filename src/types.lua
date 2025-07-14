---@class Vector2D
---@field x number
---@field y number

---@class KnockbackData
---@field power number
---@field force number
---@field attackerPosition Vector2D

---@class ItemSlotId
---@field rune string
---@field weapon string
---@field armor string
---@field accessory string
---@field rune_1 string
---@field rune_2 string
---@field rune_3 string
---@field rune_4 string
---@field rune_5 string
---@field rune_6 string
---@field rune_7 string
---@field rune_8 string
---@field rune_9 string
---@field rune_10 string

---@class ArchetypeId

---@alias StatKey "moveSpeed" | "potionFillRate" | "health" | "defense" | "attackSpeed" | "critChance" | "critDamage" | "healthRegen" | "multiAttackChance" | "runeSlots" | "strength" | "expBonus" | "healingBonus" | "pickupRadius" | "healthRegenDelay" | "range" | "luck" | "attackArea" | "healthPerTick" | "cooldownReduction" | "healthRegenCooldown" | "dashCharges" | "dashCooldown" | "dashDistance" | "dashDuration" | "potionFlasks" | "potionHealAmount" | "potionFillRate"

---@alias Color table<number, number>

---@class ItemInstance
---@field id string ID da instância (único)
---@field itemBaseId string ID do item base (ex: "rune_orbital_e")
---@field name string Nome do item
---@field rarity Rarity
---@field description string Descrição do item
---@field type ItemType
---@field icon string Caminho para o ícone
---@field equipped boolean

---@class RuneItemInstance : ItemInstance
---@field runeFamilyId string
---@field damage number|nil
---@field tick_interval number|nil
---@field radius number|nil
---@field rotationSpeed number|nil
---@field orbitRadius number|nil
---@field orbSize number|nil
---@field orbCount number|nil
---@field range number|nil
---@field num_targets number|nil
---@field chain_chance number|nil
---@field chain_damage_reduction number|nil
---@field chain_max_jumps number|nil
---@field pulseDuration number|nil

---@alias ItemType "weapon" | "rune" | "artefact" | "material" | "consumable" | "sellable"

---@alias Rarity "E" | "D" | "C" | "B" | "A" | "S"

---@alias ColorRGBA {[1]: number, [2]: number, [3]: number, [4]: number}
