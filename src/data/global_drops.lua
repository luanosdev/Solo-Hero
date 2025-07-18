---@class GlobalDrop
---@field itemId string
---@field chance number

---@type GlobalDrop[]
local global_drops = {
    {
        itemId = "teleport_stone_d",
        chance = 0.01, -- 1% de chance base
    },
    {
        itemId = "teleport_stone_b",
        chance = 0.008, -- 0.8% de chance base
    },
    {
        itemId = "teleport_stone_a",
        chance = 0.005, -- 0.5% de chance base
    },
    {
        itemId = "teleport_stone_s",
        chance = 0.003, -- 0.3% de chance base
    },
}

return global_drops
