---@class HunterManager
local HunterManager = {
    loadoutManager = nil, ---@type LoadoutManager
    itemDataManager = nil, ---@type ItemDataManager
    archetypeManager = nil, ---@type ArchetypeManager
    activeHunterId = nil, ---@type string | nil Unique ID of the active hunter
    hunters = {}, ---@type table<string, table> Stores data for all recruited hunters { [hunterId] = hunterData }
    nextHunterId = 1 ---@type number Counter for generating unique IDs
}
HunterManager.__index = HunterManager

local PersistenceManager = require("src.core.persistence_manager")
local Constants = require("src.config.constants")
local ArchetypesData = require("src.data.archetypes_data")
local ManagerRegistry = require("src.managers.manager_registry")

local SAVE_FILE = "hunters.dat"

-- Equipment slot IDs (static definition - APENAS EQUIPAMENTO BASE)
HunterManager.EQUIPMENT_SLOTS_BASE = {
    "weapon",
    "helmet",
    "chest",
    "gloves",
    "boots",
    "legs",
    -- Outros slots fixos (amuleto, anéis) podem ser adicionados aqui
}

--- Creates a new instance of the hunter manager.
--- @param loadoutManager LoadoutManager
--- @param itemDataManager ItemDataManager
--- @param archetypeManager ArchetypeManager
--- @return HunterManager
function HunterManager:new(loadoutManager, itemDataManager, archetypeManager)
    print("[HunterManager] Creating new instance...")
    local instance = setmetatable({}, HunterManager)
    instance.loadoutManager = loadoutManager
    instance.itemDataManager = itemDataManager
    instance.archetypeManager = archetypeManager
    instance.activeHunterId = nil
    instance.hunters = {}
    instance.nextHunterId = 1

    if not instance.loadoutManager or not instance.itemDataManager or not instance.archetypeManager then
        error("[HunterManager] CRITICAL ERROR: loadoutManager, itemDataManager, or archetypeManager not injected!")
    end

    instance:loadState() -- Loads state (saved hunters, activeHunterId, nextHunterId)

    if not next(instance.hunters) then
        print("[HunterManager] No hunters found. Recruiting initial hunter...")
        instance:_recruitInitialHunter()
    end

    if not instance.activeHunterId or not instance.hunters[instance.activeHunterId] then
        local firstId = next(instance.hunters)
        if firstId then
            print("[HunterManager] Setting first hunter in list as active:", firstId)
            instance.activeHunterId = firstId
        else
            error("[HunterManager] CRITICAL ERROR: Failed to load or recruit initial hunter.")
        end
    end

    print(string.format("[HunterManager] Ready. Active hunter: %s", instance.activeHunterId))
    return instance
end

--- Helper INTERNO para criar o primeiro caçador se nenhum for carregado.
function HunterManager:_recruitInitialHunter()
    print("  [HunterManager] Recruting initial default hunter...")
    local hunterId = "hunter_" .. self.nextHunterId
    self.nextHunterId = self.nextHunterId + 1

    local initialHunterData = {
        id = hunterId,
        name = "Recruta",
        baseRankId = "E",
        finalRankId = "E",
        archetypeIds = { "agile" },
    }

    self.hunters[hunterId] = initialHunterData
    self:_initializeEquippedItems(hunterId)
    self.activeHunterId = hunterId

    print(string.format("  [HunterManager] Initial hunter recruited: ID=%s, Name=%s, Rank=%s, Archetypes=%s",
        hunterId, initialHunterData.name, initialHunterData.finalRankId,
        table.concat(initialHunterData.archetypeIds, ", ")))
end

--- Internal helper to calculate final hunter stats based on archetypes.
---@param hunterId string Hunter ID.
---@return table Table with calculated final stats.
function HunterManager:_calculateFinalStats(hunterId)
    local hunterData = self.hunters[hunterId]
    if not hunterData then return {} end

    local finalStats = {}
    for key, value in pairs(Constants.HUNTER_DEFAULT_STATS) do
        finalStats[key] = value
    end

    local hunterArchetypeIds = hunterData.archetypeIds or {}
    if type(hunterArchetypeIds) == "string" then
        hunterArchetypeIds = { hunterArchetypeIds }
    end

    -- 1. Agrega TODOS os bônus de arquétipo por tipo
    local fixedBonuses = {}
    local fixedFractionBonuses = {}
    local percentageBonuses = {}

    for _, archIdInfo in ipairs(hunterArchetypeIds or {}) do
        local finalArchId = type(archIdInfo) == 'table' and archIdInfo.id or archIdInfo
        local archetypeData = self.archetypeManager:getArchetypeData(finalArchId)
        if archetypeData and archetypeData.modifiers then
            for _, mod in ipairs(archetypeData.modifiers) do
                local statName = mod.stat
                local modValue = mod.value or 0
                if mod.type == "fixed" then
                    fixedBonuses[statName] = (fixedBonuses[statName] or 0) + modValue
                elseif mod.type == "fixed_percentage_as_fraction" then
                    fixedFractionBonuses[statName] = (fixedFractionBonuses[statName] or 0) + modValue
                elseif mod.type == "percentage" then
                    percentageBonuses[statName] = (percentageBonuses[statName] or 0) + modValue
                end
            end
        end
    end

    -- 2. Aplica bônus na NOVA ORDEM para cada stat (exceto weaponDamage por enquanto)
    for statKey, baseValue in pairs(finalStats) do
        if statKey ~= "weaponDamage" then -- Calcula weaponDamage separadamente
            local currentValue = baseValue

            -- Aplica Fixed
            currentValue = currentValue + (fixedBonuses[statKey] or 0)

            -- Aplica Fixed Fraction (Aditivo)
            currentValue = currentValue + (fixedFractionBonuses[statKey] or 0)

            -- Aplica Percentage
            currentValue = currentValue * (1 + (percentageBonuses[statKey] or 0) / 100)

            finalStats[statKey] = currentValue
        end
    end

    -- 3. Calcula weaponDamage separadamente
    local baseWeaponDamage = 0
    local weaponInstance = nil
    local weaponData = nil
    if hunterData.equippedItems and hunterData.equippedItems[Constants.SLOT_IDS.WEAPON] then
        weaponInstance = hunterData.equippedItems[Constants.SLOT_IDS.WEAPON]
        if weaponInstance and weaponInstance.itemBaseId and self.itemDataManager then
            weaponData = self.itemDataManager:getBaseItemData(weaponInstance.itemBaseId)
            if weaponData then
                -- Lógica de leitura do dano base (mantida da correção anterior)
                baseWeaponDamage = weaponData.damage
            end
        end
    end
    finalStats._baseWeaponDamage = baseWeaponDamage -- Salva para tooltip

    -- Calcula o multiplicador de dano aplicando os bônus na nova ordem
    local damageMultiplierBase = 1.0 -- Dano base não tem multiplicador, o multiplicador é aplicado ao dano
    local damageMultiplierFixed = fixedBonuses["damageMultiplier"] or
        0                            -- Bônus fixo para multiplicador (geralmente não usado)
    local damageMultiplierFixedFraction = fixedFractionBonuses["damageMultiplier"] or 0
    local damageMultiplierPercentage = percentageBonuses["damageMultiplier"] or 0

    local finalDamageMultiplier = (damageMultiplierBase + damageMultiplierFixed + damageMultiplierFixedFraction) *
        (1 + damageMultiplierPercentage / 100)
    finalStats._playerDamageMultiplier = finalDamageMultiplier -- Salva para tooltip

    -- Calcula dano final
    finalStats.weaponDamage = math.floor(baseWeaponDamage * finalDamageMultiplier)

    -- 4. Finaliza: Garante valores mínimos/máximos, formata IDs de itens equipados
    finalStats.runeSlots = math.max(0, math.floor(finalStats.runeSlots or 0))
    finalStats.luck = math.max(0, finalStats.luck or 0) -- Sorte não deve ser negativa?
    -- Adicionar clamps para outros stats se necessário (ex: CDR, critChance)

    finalStats.equippedItems = {}
    if hunterData.equippedItems then
        for slot, itemInst in pairs(hunterData.equippedItems) do
            if itemInst and itemInst.instanceId then
                finalStats.equippedItems[slot] = itemInst.instanceId
            end
        end
    end
    finalStats.archetypeIds = hunterArchetypeIds

    return finalStats
end

--- Returns the CALCULATED FINAL stats of the active hunter.
--- @return table Final stats or {} if not found.
function HunterManager:getActiveHunterFinalStats()
    if not self.activeHunterId then return {} end
    return self:_calculateFinalStats(self.activeHunterId)
end

--- Returns the CALCULATED FINAL stats of a specific hunter.
--- @param hunterId string The ID of the hunter.
--- @return table Final stats or {} if not found.
function HunterManager:getHunterFinalStats(hunterId)
    return self:_calculateFinalStats(hunterId)
end

--- NOVO: Returns the MAXIMUM number of rune slots for the active hunter.
-- Reads from the final calculated stats.
--- @return number Number of rune slots (defaults to 0).
function HunterManager:getActiveHunterMaxRuneSlots()
    if not self.activeHunterId then return 0 end
    local finalStats = self:getActiveHunterFinalStats()
    return finalStats and finalStats.runeSlots or 0
end

--- Returns the table of equipped items for a specific hunter.
--- @param hunterId string The ID of the hunter.
--- @return table | nil The equipped items table ({ [slotId] = itemInstance | nil }) or nil if hunter not found.
function HunterManager:getEquippedItems(hunterId)
    local hunterData = self.hunters[hunterId]
    if not hunterData then
        print(string.format("WARNING [getEquippedItems]: Hunter %s not found.", hunterId))
        return nil
    end
    return hunterData.equippedItems or {}
end

--- Internal helper to initialize the equipment table for a hunter.
--- NOW DYNAMIC based on base stats.
--- @param hunterId string
function HunterManager:_initializeEquippedItems(hunterId)
    local hunterData = self.hunters[hunterId]
    if not hunterData then return end

    hunterData.equippedItems = hunterData.equippedItems or {}

    for _, slotId in ipairs(HunterManager.EQUIPMENT_SLOTS_BASE) do
        hunterData.equippedItems[slotId] = hunterData.equippedItems[slotId]
    end

    local finalStats = self:_calculateFinalStats(hunterId) -- Usa os stats calculados para os slots de runa
    local numRuneSlots = finalStats and finalStats.runeSlots or 0
    for i = 1, numRuneSlots do
        local slotId = Constants.SLOT_IDS.RUNE .. i
        hunterData.equippedItems[slotId] = hunterData.equippedItems[slotId]
    end
end

--- Returns the ID of the currently active hunter.
--- @return string | nil
function HunterManager:getActiveHunterId()
    return self.activeHunterId
end

--- Sets the active hunter.
-- Saves previous hunter's data (loadout) and loads the new one.
--- @param hunterId string ID of the new active hunter.
--- @return boolean True if switched successfully, false otherwise.
function HunterManager:setActiveHunter(hunterId)
    if not self.hunters[hunterId] then
        print(string.format("ERROR [HunterManager]: Attempt to activate invalid/unknown hunter ID: %s", hunterId))
        return false
    end

    if hunterId ~= self.activeHunterId then
        local previousHunterId = self.activeHunterId
        print(string.format("[HunterManager] Switching active hunter from %s to %s", previousHunterId or "none", hunterId))
        self.activeHunterId = hunterId
        self:saveState()
        print(string.format("[HunterManager] Active hunter changed to %s.", hunterId))
        return true
    end
    return false
end

--- Returns the equipment table for the active hunter.
--- @return table<string, table|nil> Table { [slotId] = itemInstance | nil } or nil.
function HunterManager:getActiveEquippedItems()
    if not self.activeHunterId then return nil end
    local hunterData = self.hunters[self.activeHunterId]
    return hunterData and hunterData.equippedItems
end

--- Checks if a given slot ID is valid for the ACTIVE hunter.
-- Considers base slots and the DYNAMIC number of rune slots.
---@param slotId string The slot ID to check (e.g., "weapon", "rune_3").
---@return boolean True if the slot is valid for the active hunter.
function HunterManager:_isSlotValidForActiveHunter(slotId)
    if not self.activeHunterId then return false end

    for _, baseSlotId in ipairs(self.EQUIPMENT_SLOTS_BASE) do
        if slotId == baseSlotId then
            return true
        end
    end

    local prefix, numStr = slotId:match("^(rune_)(%d+)$")
    if prefix and numStr then
        local slotNum = tonumber(numStr)
        local maxSlots = self:getActiveHunterMaxRuneSlots()
        if slotNum > 0 and slotNum <= maxSlots then
            return true
        end
    end
    return false
end

--- Tries to equip an item in a specific slot for the active hunter.
--- @param itemInstance table Full item instance (from loadout/storage).
--- @param slotId string Slot ID to equip into (e.g., "weapon", "rune_1").
--- @return boolean, table|nil Returns true and the old item instance (if any), or false and nil.
function HunterManager:equipItem(itemInstance, slotId)
    if not self.activeHunterId or not itemInstance or not slotId then
        print("ERROR [HunterManager:equipItem]: Invalid arguments.")
        return false, nil
    end

    if not self:_isSlotValidForActiveHunter(slotId) then
        print(string.format("ERROR [HunterManager:equipItem]: Invalid or inactive equipment slot for hunter %s: %s",
            self.activeHunterId, slotId))
        return false, nil
    end

    local baseData = self.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
    if not baseData then
        print(string.format("ERROR [HunterManager:equipItem]: Could not get base data for %s", itemInstance.itemBaseId))
        return false, nil
    end

    local expectedType = "unknown"
    if slotId == "weapon" then expectedType = "weapon" end
    if slotId == "helmet" then expectedType = "helmet" end
    if slotId == "chest" then expectedType = "chest" end
    if slotId == "gloves" then expectedType = "gloves" end
    if slotId == "boots" then expectedType = "boots" end
    if slotId == "legs" then expectedType = "legs" end
    if string.sub(slotId, 1, 5) == "rune_" then expectedType = "rune" end

    if expectedType ~= "unknown" and baseData.type ~= expectedType then
        print(string.format(
            "WARNING [HunterManager:equipItem]: Item type '%s' incompatible with slot '%s' (expects '%s'). Denying equip.",
            baseData.type, slotId, expectedType))
        return false, nil
    end

    local hunterData = self.hunters[self.activeHunterId]
    if not hunterData or not hunterData.equippedItems then
        print("ERROR [HunterManager:equipItem]: Equipment structure not found for active hunter.")
        return false, nil
    end

    local hunterEquipment = hunterData.equippedItems
    local oldItemInstance = hunterEquipment[slotId]

    if oldItemInstance then
        print(string.format("  [HunterManager] Unequipping previous item (%s, ID: %s) from slot %s",
            oldItemInstance.itemBaseId, oldItemInstance.instanceId or -1, slotId))
    end

    hunterEquipment[slotId] = itemInstance
    print(string.format("[HunterManager] Item %s (%s) equipped in slot %s for %s",
        tostring(itemInstance.instanceId), itemInstance.itemBaseId, slotId, self.activeHunterId))

    if slotId == Constants.SLOT_IDS.WEAPON then
        local playerManager = ManagerRegistry:tryGet("playerManager")
        if playerManager then
            playerManager:setActiveWeapon(itemInstance)
            print("  -> Notified PlayerManager to set new active weapon.")
        else
            print("  -> WARNING: Could not get PlayerManager to set new weapon!")
        end
    end
    return true, oldItemInstance
end

--- Unequips the item from a specific slot for the active hunter.
--- @param slotId string Slot ID to unequip from.
--- @return table|nil Returns the instance of the unequipped item, or nil.
function HunterManager:unequipItem(slotId)
    if not self.activeHunterId or not slotId then return nil end

    local hunterData = self.hunters[self.activeHunterId]
    if not hunterData or not hunterData.equippedItems then return nil end

    local hunterEquipment = hunterData.equippedItems
    local itemToUnequip = hunterEquipment[slotId]

    if itemToUnequip then
        print(string.format("[HunterManager] Unequipping item (%s, ID: %s) from slot %s for %s",
            itemToUnequip.itemBaseId, itemToUnequip.instanceId or -1, slotId, self.activeHunterId))
        hunterEquipment[slotId] = nil
        if slotId == Constants.SLOT_IDS.WEAPON then
            local playerManager = ManagerRegistry:tryGet("playerManager")
            if playerManager then
                playerManager:setActiveWeapon(nil)
                print("  -> Notified PlayerManager to clear active weapon (set to nil).")
            else
                print("  -> WARNING: Could not get PlayerManager to clear weapon!")
            end
        end
        return itemToUnequip
    end
    return nil
end

--- Saves the HunterManager state (hunter definitions, active ID, next ID).
function HunterManager:saveState()
    print("[HunterManager] Requesting state save (activeHunterId, nextHunterId, hunter data)...")
    local serializableHunters = {}
    for hunterId, hunterData in pairs(self.hunters) do
        serializableHunters[hunterId] = {
            id = hunterData.id,
            name = hunterData.name,
            baseRankId = hunterData.baseRankId,
            finalRankId = hunterData.finalRankId,
            archetypeIds = hunterData.archetypeIds,
            equippedItems = {}
        }
        if hunterData.equippedItems then
            for slotId, itemInstance in pairs(hunterData.equippedItems) do
                if itemInstance then
                    serializableHunters[hunterId].equippedItems[slotId] = {
                        instanceId = itemInstance.instanceId,
                        itemBaseId = itemInstance.itemBaseId,
                        quantity = itemInstance.quantity or 1
                    }
                else
                    serializableHunters[hunterId].equippedItems[slotId] = nil
                end
            end
        end
    end

    local dataToSave = {
        version = 2,
        activeHunterId = self.activeHunterId,
        nextHunterId = self.nextHunterId,
        hunters = serializableHunters
    }
    local success = PersistenceManager.saveData(SAVE_FILE, dataToSave)
    if success then
        print("[HunterManager] State saved successfully.")
    else
        print("ERROR [HunterManager]: Failed to save state.")
    end
    return success
end

--- Loads the state from the save file.
function HunterManager:loadState()
    print("[HunterManager] Attempting to load state...")
    local loadedData = PersistenceManager.loadData(SAVE_FILE)

    self.hunters = {}
    self.activeHunterId = nil
    self.nextHunterId = 1

    if not loadedData or type(loadedData) ~= "table" then
        print("[HunterManager] No valid save data found. Will need to recruit initial hunter.")
        return false
    end

    if loadedData.version ~= 2 then
        print(string.format(
            "WARNING [HunterManager]: Save data version (%s) incompatible with current (%s). Attempting to load anyway...",
            tostring(loadedData.version), 2))
    end

    self.activeHunterId = loadedData.activeHunterId or nil
    self.nextHunterId = loadedData.nextHunterId or 1
    local loadedHuntersData = loadedData.hunters or {}

    for hunterId, savedHunterData in pairs(loadedHuntersData) do
        local newHunterEntry = {
            id = savedHunterData.id or hunterId,
            name = savedHunterData.name or ("Hunter " .. hunterId),
            baseRankId = savedHunterData.baseRankId or "E",
            finalRankId = savedHunterData.finalRankId or savedHunterData.baseRankId or "E",
            archetypeIds = savedHunterData.archetypeIds or {},
            equippedItems = {}
        }

        local savedEquippedItems = savedHunterData.equippedItems or {}
        for slotId, savedItemData in pairs(savedEquippedItems) do
            if savedItemData then
                local baseData = self.itemDataManager:getBaseItemData(savedItemData.itemBaseId)
                if baseData then
                    newHunterEntry.equippedItems[slotId] = {
                        instanceId = savedItemData.instanceId,
                        itemBaseId = savedItemData.itemBaseId,
                        quantity = savedItemData.quantity,
                        gridWidth = baseData.gridWidth or 1,
                        gridHeight = baseData.gridHeight or 1,
                        stackable = baseData.stackable or false,
                        maxStack = baseData.maxStack or (baseData.stackable and 99) or 1,
                        name = baseData.name,
                        icon = baseData.icon,
                        rarity = baseData.rarity or 'E'
                    }
                else
                    print(string.format(
                        "WARNING [HunterManager]: Could not find base data for equipped item '%s' (instance %s) for hunter '%s'. Slot will be empty.",
                        savedItemData.itemBaseId, tostring(savedItemData.instanceId), hunterId))
                    newHunterEntry.equippedItems[slotId] = nil
                end
            else
                newHunterEntry.equippedItems[slotId] = nil
            end
        end

        for _, slotId in ipairs(self.EQUIPMENT_SLOTS_BASE) do
            if newHunterEntry.equippedItems[slotId] == nil then
                newHunterEntry.equippedItems[slotId] = nil
            end
        end
        self.hunters[hunterId] = newHunterEntry
    end

    print(string.format("[HunterManager] Load complete. %d hunters loaded. Active: %s. Next ID: %d",
        table.maxn(self.hunters) or 0,
        tostring(self.activeHunterId), self.nextHunterId))
    return true
end

--- Internal helper to calculate final stats based ONLY on archetype IDs and base stats.
--- Does NOT consider equipped items.
--- @param archetypeIdsToCalculate table List of archetype IDs.
--- @return table Table with calculated final stats.
function HunterManager:_calculateStatsForCandidate(archetypeIdsToCalculate)
    local finalStats = {}
    for key, value in pairs(Constants.HUNTER_DEFAULT_STATS) do
        finalStats[key] = value
    end

    local currentArchetypeIds = archetypeIdsToCalculate or {}
    if type(currentArchetypeIds) == "string" then -- Lida com caso antigo onde poderia ser uma string única
        currentArchetypeIds = { currentArchetypeIds }
    end

    for _, archetypeId in ipairs(currentArchetypeIds) do
        local archetypeData = self.archetypeManager:getArchetypeData(archetypeId)
        if archetypeData and archetypeData.modifiers then
            for _, mod in ipairs(archetypeData.modifiers) do
                local statName = mod.stat
                local modType = mod.type
                local modValue = mod.value

                if finalStats[statName] == nil then
                    print(string.format(
                        "WARNING [_calculateStatsForCandidate]: Stat base '%s' não definido em HUNTER_DEFAULT_STATS para arquétipo '%s'. Modificador ignorado.",
                        statName, archetypeId))
                    goto continue_candidate_mod_loop
                end
                if modType == nil or modValue == nil then
                    print(string.format(
                        "WARNING [_calculateStatsForCandidate]: Modificador para stat '%s' no arquétipo '%s' não possui 'type' ou 'value'. Modificador ignorado.",
                        statName, archetypeId))
                    goto continue_candidate_mod_loop
                end

                if modType == "fixed" then
                    finalStats[statName] = finalStats[statName] + modValue
                elseif modType == "percentage" then
                    finalStats[statName] = finalStats[statName] * (1 + modValue / 100)
                elseif modType == "fixed_percentage_as_fraction" then
                    finalStats[statName] = finalStats[statName] + modValue
                else
                    print(string.format(
                        "WARNING [_calculateStatsForCandidate]: Tipo de modificador de arquétipo desconhecido '%s' para stat '%s' no arquétipo '%s'.",
                        modType, statName, archetypeId))
                end
                ::continue_candidate_mod_loop::
            end
        end
    end
    return finalStats
end

--- Helper function for weighted random selection from a table.
--- Input table format: { { weight = w1, data = d1 }, { weight = w2, data = d2 }, ... }
--- OR { key1 = { weight = w1, ... }, key2 = { weight = w2, ... } } (returns the key)
---@param choices table Table of choices with weights.
---@return any The chosen data element or key.
local function weightedRandomChoice(choices)
    local totalWeight = 0
    local isArray = type(choices[1]) == "table"

    if isArray then
        for i, choice in ipairs(choices) do
            totalWeight = totalWeight + (choice.weight or 0)
        end
    else
        for key, choiceData in pairs(choices) do
            totalWeight = totalWeight + (choiceData.recruitment_weight or 0)
        end
    end

    if totalWeight <= 0 then return nil end

    local randomNum = love.math.random() * totalWeight
    local cumulativeWeight = 0

    if isArray then
        -- Implementar lógica para array se necessário no futuro
    else
        for key, choiceData in pairs(choices) do
            local weight = choiceData.recruitment_weight or 0
            if randomNum < cumulativeWeight + weight then
                return key
            end
            cumulativeWeight = cumulativeWeight + weight
        end
    end
    return nil
end

--- Generates a list of potential hunter candidates for recruitment, respecting rank rules.
--- @param count number The number of candidates to generate.
--- @return table A list of candidate data tables, each containing { id, name, baseRankId, finalRankId, archetypeIds, archetypes, finalStats }.
function HunterManager:generateHunterCandidates(count)
    print(string.format("[HunterManager] Generating %d hunter candidates...", count))
    local candidates = {}
    local names = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta" }
    local archetypesByRank = {}
    for archId, archData in pairs(self.archetypeManager:getAllArchetypeData()) do -- Usa getter do ArchetypeManager
        local rank = archData.rank
        if rank then
            archetypesByRank[rank] = archetypesByRank[rank] or {}
            table.insert(archetypesByRank[rank], archId)
        end
    end

    for i = 1, count do
        local candidate = {}
        candidate.id = "candidate_" .. i
        candidate.name = "Candidato " .. (names[i] or i)

        local chosenRankId = weightedRandomChoice(ArchetypesData.Ranks)
        if not chosenRankId then
            print("ERROR [generateHunterCandidates]: Could not determine candidate rank. Defaulting to E.")
            chosenRankId = "E"
        end
        local rankData = ArchetypesData.Ranks[chosenRankId]
        candidate.baseRankId = chosenRankId
        candidate.finalRankId = chosenRankId

        local minArchetypes = rankData.archetype_count_min or 1
        local maxArchetypes = rankData.archetype_count_max or minArchetypes
        local numArchetypes = love.math.random(minArchetypes, maxArchetypes)

        candidate.archetypeIds = {}
        local pickedArchetypesSet = {}
        local rankSpecificArchetypes = archetypesByRank[chosenRankId] or {}
        local availableRankSpecific = {}
        for _, id in ipairs(rankSpecificArchetypes) do table.insert(availableRankSpecific, id) end

        local lowerRankArchetypesPool = {}
        local rankOrder = { "E", "D", "C", "B", "A", "S" }
        for _, currentRankId in ipairs(rankOrder) do
            if currentRankId == chosenRankId then break end
            local archetypesInThisRank = archetypesByRank[currentRankId] or {}
            for _, archId in ipairs(archetypesInThisRank) do
                table.insert(lowerRankArchetypesPool, archId)
            end
        end

        local numMandatoryPicked = 0
        if #availableRankSpecific > 0 then -- Tenta pegar um do rank específico primeiro
            local randomIndex = love.math.random(#availableRankSpecific)
            local chosenArchId = availableRankSpecific[randomIndex]
            table.insert(candidate.archetypeIds, chosenArchId)
            pickedArchetypesSet[chosenArchId] = true
            table.remove(availableRankSpecific, randomIndex)
            numMandatoryPicked = 1
        end

        local numRemainingToPick = numArchetypes - numMandatoryPicked
        if numRemainingToPick > 0 then
            local combinedPool = {}
            for _, id in ipairs(availableRankSpecific) do table.insert(combinedPool, id) end
            for _, id in ipairs(lowerRankArchetypesPool) do table.insert(combinedPool, id) end

            if #combinedPool > 0 then
                for _ = 1, math.min(numRemainingToPick, #combinedPool) do
                    if #combinedPool == 0 then break end -- Segurança extra
                    local randomIndex = love.math.random(#combinedPool)
                    local pickedId = combinedPool[randomIndex]
                    if not pickedArchetypesSet[pickedId] then
                        table.insert(candidate.archetypeIds, pickedId)
                        pickedArchetypesSet[pickedId] = true
                    else
                        -- Tenta pegar outro se o sorteado já foi pego (simples, pode repetir se o pool for pequeno)
                        -- Para uma solução mais robusta, removeria o pickedId do combinedPool
                        -- e re-sortearia ou pegaria o próximo se o pool ficasse vazio.
                        -- Por ora, a duplicidade é evitada pelo pickedArchetypesSet, mas pode resultar em menos arquétipos que o desejado.
                    end
                    table.remove(combinedPool, randomIndex) -- Remove para evitar pegar o mesmo novamente nesta fase
                end
            end
        end

        -- Garante que a contagem final não exceda o desejado, mesmo que a lógica de seleção tenha peculiaridades
        while #candidate.archetypeIds > numArchetypes do
            table.remove(candidate.archetypeIds)
        end

        candidate.archetypes = {}
        for _, arcId in ipairs(candidate.archetypeIds) do
            local arcData = self.archetypeManager:getArchetypeData(arcId)
            if arcData then
                table.insert(candidate.archetypes, arcData)
            else
                print(string.format(
                    "WARNING [generateHunterCandidates]: Could not get data for selected archetype ID '%s'", arcId))
            end
        end

        candidate.finalStats = self:_calculateStatsForCandidate(candidate.archetypeIds)
        table.insert(candidates, candidate)
        print(string.format("  > Candidate %d: Name=%s, Rank=%s, Archetypes=[%s] (%d total)", i, candidate.name,
            candidate.finalRankId, table.concat(candidate.archetypeIds, ", "), #candidate.archetypeIds))
    end
    return candidates
end

--- Recruits a hunter based on chosen candidate data.
--- @param candidateData table The data table of the chosen candidate.
--- @return string|nil The permanent ID of the newly recruited hunter, or nil on failure.
function HunterManager:recruitHunter(candidateData)
    if not candidateData or not candidateData.name or not candidateData.archetypeIds then
        print("ERROR [HunterManager:recruitHunter]: Invalid candidate data provided.")
        return nil
    end

    local hunterId = "hunter_" .. self.nextHunterId
    self.nextHunterId = self.nextHunterId + 1

    print(string.format("[HunterManager] Recruiting hunter %s from candidate %s...", hunterId, candidateData.name))

    local newHunterData = {
        id = hunterId,
        name = candidateData.name,
        baseRankId = candidateData.baseRankId or "E",
        finalRankId = candidateData.finalRankId or "E",
        archetypeIds = candidateData.archetypeIds,
    }

    self.hunters[hunterId] = newHunterData
    self:_initializeEquippedItems(hunterId)
    self:saveState()

    print(string.format("[HunterManager] Hunter %s recruited successfully.", hunterId))
    return hunterId
end

--- Returns the list of archetype IDs for a specific hunter.
--- @param hunterId string The ID of the hunter.
--- @return table | nil A list of archetype ID strings or nil if hunter not found.
function HunterManager:getArchetypeIds(hunterId)
    local hunterData = self.hunters[hunterId]
    if hunterData then
        return hunterData.archetypeIds or {}
    end
    print(string.format("WARNING [getArchetypeIds]: Hunter %s not found.", hunterId))
    return nil
end

--- Função auxiliar para agregar bônus de múltiplos arquétipos
---@param archetypeIds table Lista de IDs de arquétipos ativos
---@param bonusType string Tipo de bônus a agregar ("fixed", "percentage", "fixed_percentage_as_fraction")
---@param baseStatsForValidation table Tabela de stats base para validar a existência da chave do stat (opcional mas recomendado)
---@return table Tabela agregada de bônus { [statKey] = totalBonusValue }
function HunterManager:_getAggregatedBonuses(archetypeIds, bonusType, baseStatsForValidation)
    local aggregatedBonuses = {}
    baseStatsForValidation = baseStatsForValidation or
        Constants.HUNTER_DEFAULT_STATS -- Fallback para stats default globais

    for _, archIdInfo in ipairs(archetypeIds or {}) do
        local finalArchId = type(archIdInfo) == 'table' and archIdInfo.id or archIdInfo
        local archetypeData = self.archetypeManager:getArchetypeData(finalArchId)

        if archetypeData and archetypeData.modifiers then
            for _, mod in ipairs(archetypeData.modifiers) do
                if mod.type == bonusType then
                    local statName = mod.stat
                    local modValue = mod.value or 0

                    if baseStatsForValidation[statName] == nil then
                        print(string.format(
                            "AVISO [_getAggregatedBonuses]: Stat base '%s' não definido para arquétipo '%s' (tipo %s). Modificador ignorado.",
                            statName, finalArchId, bonusType))
                        goto continue_modifier_loop
                    end

                    aggregatedBonuses[statName] = (aggregatedBonuses[statName] or 0) + modValue
                end
                ::continue_modifier_loop::
            end
        end
    end
    return aggregatedBonuses
end

return HunterManager
