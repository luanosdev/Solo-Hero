---@class ArchetypeManager
local ArchetypeManager = {}
ArchetypeManager.__index = ArchetypeManager

-- Loads archetype and rank data
local ArchetypesData = require("src.data.archetypes_data")

--- Creates a new instance of the ArchetypeManager.
---@return ArchetypeManager
function ArchetypeManager:new()
    print("[ArchetypeManager] Creating new instance...")
    local instance = setmetatable({}, ArchetypeManager)
    instance.ranks = ArchetypesData.Ranks
    instance.archetypes = ArchetypesData.Archetypes

    if not instance.ranks or not instance.archetypes then
        error("[ArchetypeManager] ERROR: Failed to load Rank or Archetype data.")
    end

    local rankCount = 0; for _ in pairs(instance.ranks) do rankCount = rankCount + 1 end
    local archetypeCount = 0; for _ in pairs(instance.archetypes) do archetypeCount = archetypeCount + 1 end
    print(string.format("[ArchetypeManager] Ready. %d Ranks and %d Archetypes loaded.", rankCount, archetypeCount))
    return instance
end

--- Returns all Rank data.
---@return table
function ArchetypeManager:getAllRankData()
    return self.ranks
end

--- Returns data for a specific Rank by ID.
---@param rankId string (e.g., "E", "S")
---@return table|nil
function ArchetypeManager:getRankData(rankId)
    return self.ranks[rankId]
end

--- Returns all Archetype data.
---@return table
function ArchetypeManager:getAllArchetypeData()
    return self.archetypes
end

--- Returns data for a specific Archetype by ID.
---@param archetypeId string (e.g., "agile", "immortal")
---@return table|nil
function ArchetypeManager:getArchetypeData(archetypeId)
    return self.archetypes[archetypeId]
end

--- Returns a specified number of random, unique archetype IDs.
---@param count number The number of unique random archetype IDs to return.
---@return table<string> A list of unique archetype IDs.
function ArchetypeManager:getRandomArchetypeIds(count)
    local allIds = {}
    for id, _ in pairs(self.archetypes) do
        table.insert(allIds, id)
    end

    local numAvailable = #allIds
    count = math.min(count, numAvailable) -- Cannot return more IDs than available
    local selectedIds = {}

    if count <= 0 then return selectedIds end

    -- Simple shuffle and pick first 'count'
    for i = numAvailable, 2, -1 do
        local j = love.math.random(i)
        allIds[i], allIds[j] = allIds[j], allIds[i]
    end

    for i = 1, count do
        table.insert(selectedIds, allIds[i])
    end

    return selectedIds
end

-- TODO: Add functions for rolling ranks and archetypes based on weights/pools

return ArchetypeManager
