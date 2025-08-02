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


---@class GameplayContext
---@field level number O nível atual do jogador.
---@field kills number O número de inimigos mortos na partida.
---@field time number O tempo decorrido na partida em segundos.

---@alias BonusFunction fun(finalStats: table<StatKey, number>, context: GameplayContext):number

---@class StatModifier
---@field stat StatKey O stat a ser modificado.
---@field type "FLAT" | "PERCENTAGE" O tipo de modificação.
---@field value number | BonusFunction O valor do bônus (um número ou uma função para calcular o bônus).
---@field source string O ID da fonte do bônus (ex: "ARCHETYPE_TANK").

---@alias StatKey "damage" | "moveSpeed" | "potionFillRate" | "maxHealth" | "defense" | "attackSpeed" | "criticalChance" | "criticalDamage" | "healthRegen" | "multiAttackChance" | "runeSlots" | "strength" | "expBonus" | "healingBonus" | "pickupRadius" | "healthRegenDelay" | "range" | "luck" | "area" | "healthPerTick" | "cooldownReduction" | "healthRegenCooldown" | "dashCharges" | "dashCooldown" | "dashDistance" | "dashDuration" | "potionFlasks" | "potionHealAmount" | "potionFillRate" | "piercing" | "angle" | "fireRate" 

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
---@alias Rank "E" | "D" | "C" | "B" | "A" | "S"

---@alias ColorRGBA {[1]: number, [2]: number, [3]: number, [4]: number}

---@class RenderableItem
---@field depth number
---@field type string
---@field texture love.Texture
---@field quad love.Quad
---@field x number
---@field y number
---@field rotation number

---@class SpriteBatchDrawArgs
---@field quad love.Quad
---@field x number
---@field y number
---@field r number
---@field sx number
---@field sy number

---@alias BaseEntity { position: Vector2D }

---@class MapInfo
---@field worldTileWidth number
---@field worldTileHeight number
---@field tileWidth number
---@field tileHeight number
---@field isometricToCartesianTile fun(isoX: number, isoY: number): Vector2D
