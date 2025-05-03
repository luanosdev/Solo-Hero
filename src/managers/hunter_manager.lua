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

    -- If no hunter was loaded, recruit an initial one?
    if not next(instance.hunters) then
        print("[HunterManager] No hunters found. Recruiting initial hunter...")
        instance:_recruitInitialHunter() -- Function to be created
    end

    -- If there's still no active hunter (e.g., corrupted save or failed initial recruit?),
    -- try setting the first in the list as active.
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

    -- Dados básicos do caçador inicial
    local initialHunterData = {
        id = hunterId,
        name = "Recruta",           -- Nome inicial simples
        baseRankId = "E",
        finalRankId = "E",          -- Começa igual ao base
        archetypeIds = { "agile" }, -- Dá um arquétipo inicial simples
        -- Não inicializa equippedItems aqui, será feito em _initializeEquippedItems
    }

    -- Adiciona à tabela de caçadores
    self.hunters[hunterId] = initialHunterData

    -- Inicializa a estrutura de equipamento para ele (agora dinâmico)
    self:_initializeEquippedItems(hunterId)

    -- Define como ativo
    self.activeHunterId = hunterId

    print(string.format("  [HunterManager] Initial hunter recruited: ID=%s, Name=%s, Rank=%s, Archetypes=%s",
        hunterId, initialHunterData.name, initialHunterData.finalRankId,
        table.concat(initialHunterData.archetypeIds, ", ")))

    -- Salva o estado imediatamente após recrutar o inicial?
    -- self:saveState()
    -- Talvez seja melhor salvar apenas ao sair da cena/jogo.
end

--- Internal helper to calculate final hunter stats based on archetypes.
---@param hunterId string Hunter ID.
---@return table Table with calculated final stats.
function HunterManager:_calculateFinalStats(hunterId)
    local hunterData = self.hunters[hunterId]
    if not hunterData then
        print("WARNING [_calculateFinalStats]: Hunter not found:", hunterId)
        return {}
    end
    print(string.format("--- HunterManager:_calculateFinalStats for %s ---", hunterId)) -- DEBUG

    -- 1. Start with default stats
    local finalStats = {}
    print("  [DEBUG] Starting with default stats:") -- DEBUG
    for key, value in pairs(Constants.HUNTER_DEFAULT_STATS) do
        finalStats[key] = value
        print(string.format("    - %s = %s", key, tostring(value))) -- DEBUG
    end

    -- 2. Apply archetype modifiers (New Structure)
    local archetypeIds = hunterData.archetypeIds or {}
    print(string.format("  [DEBUG] Applying modifiers from archetypes: [%s]", table.concat(archetypeIds, ", "))) -- DEBUG
    local accumulatedBase = {}                                                                                   -- Accumulate base additions
    local accumulatedMult = {}                                                                                   -- Accumulate multiplicative changes (start at 1.0)

    for _, archetypeId in ipairs(archetypeIds) do
        local archetypeData = self.archetypeManager:getArchetypeData(archetypeId)
        if archetypeData and archetypeData.modifiers then
            print(string.format("    > Processing archetype: %s", archetypeId)) -- DEBUG
            -- Iterate through the list of modifier tables
            for _, mod in ipairs(archetypeData.modifiers) do
                local statName = mod.stat
                if not statName then
                    print(string.format(
                        "WARNING [_calculateFinalStats]: Missing 'stat' field in modifier for archetype '%s'",
                        archetypeId))
                    goto continue_modifier_loop                                 -- Skip this modifier
                end
                print(string.format("      - Modifier for stat: %s", statName)) -- DEBUG

                -- Check for baseValue
                if mod.baseValue ~= nil then
                    if finalStats[statName] == nil then
                        print(string.format(
                            "WARNING [_calculateFinalStats]: Base stat '%s' not found for baseValue in '%s'", statName,
                            archetypeId))
                    else
                        accumulatedBase[statName] = (accumulatedBase[statName] or 0) + mod.baseValue
                        print(string.format("        -> Base Value: %.2f (Accumulated Base for %s: %.2f)", mod.baseValue,
                            statName, accumulatedBase[statName])) -- DEBUG
                    end
                end

                -- Check for multValue
                if mod.multValue ~= nil then
                    if finalStats[statName] == nil then
                        print(string.format(
                            "WARNING [_calculateFinalStats]: Base stat '%s' not found for multValue in '%s'", statName,
                            archetypeId))
                    else
                        -- Accumulate the percentage change (0.08 means +8%)
                        accumulatedMult[statName] = (accumulatedMult[statName] or 0) + mod.multValue
                        print(string.format("        -> Mult Value: %.2f (Accumulated Mult for %s: %.2f)", mod.multValue,
                            statName, accumulatedMult[statName])) -- DEBUG
                    end
                end
                ::continue_modifier_loop::
            end
        end
    end

    -- 3. Apply accumulated modifiers (Base first, then Mult)
    print("  [DEBUG] Applying accumulated modifiers...") -- DEBUG
    -- Apply Base Additions
    for statName, baseAdd in pairs(accumulatedBase) do
        if finalStats[statName] ~= nil then
            print(string.format("    - Applying Base Add to %s: %.2f + %.2f = %.2f", statName, finalStats[statName],
                baseAdd, finalStats[statName] + baseAdd)) -- DEBUG
            finalStats[statName] = finalStats[statName] + baseAdd
        end
    end

    -- Apply Multiplicative Changes
    for statName, multChange in pairs(accumulatedMult) do
        if finalStats[statName] ~= nil then
            local multiplier = (1.0 + multChange)
            print(string.format("    - Applying Mult Change to %s: %.2f * %.2f (1.0 + %.2f) = %.2f", statName,
                finalStats[statName], multiplier, multChange, finalStats[statName] * multiplier)) -- DEBUG
            -- Apply the total multiplier (1.0 + accumulated percentage change)
            finalStats[statName] = finalStats[statName] * multiplier
        end
    end

    -- TODO: Apply stats from equipped items (later phase)
    print("  [DEBUG] Final calculated stats (before equipment):")                      -- DEBUG
    for k, v in pairs(finalStats) do print(string.format("    - %s = %.2f", k, v)) end -- DEBUG
    print("--- HunterManager:_calculateFinalStats END ---")                            -- DEBUG

    return finalStats
end

--- Returns the CALCULATED FINAL stats of the active hunter.
--- @return table Final stats or {} if not found.
function HunterManager:getActiveHunterFinalStats()
    if not self.activeHunterId then return {} end
    -- Idealmente, fazer cache disso para evitar recalcular sempre,
    -- mas por agora, recalcula quando solicitado.
    -- TODO: Implementar cache de stats se necessário para performance.
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
    local finalStats = self:getActiveHunterFinalStats() -- Usa a função existente que calcula
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
    -- Retorna a tabela completa, pode conter nils para slots vazios.
    -- Garante que a tabela exista, mesmo que vazia (caso raro de inicialização falha).
    return hunterData.equippedItems or {}
end

--- Internal helper to initialize the equipment table for a hunter.
--- NOW DYNAMIC based on base stats.
--- @param hunterId string
function HunterManager:_initializeEquippedItems(hunterId)
    local hunterData = self.hunters[hunterId]
    if not hunterData then
        print(string.format("ERROR [_initializeEquippedItems]: Hunter %s does not exist in self.hunters!", hunterId))
        return
    end
    print(string.format("  [HunterManager] Initializing equipment slots for %s", hunterId))
    hunterData.equippedItems = {} -- Cria/reseta a tabela

    -- 1. Adiciona os slots de equipamento BASE
    for _, slotId in ipairs(self.EQUIPMENT_SLOTS_BASE) do
        hunterData.equippedItems[slotId] = nil
    end

    -- 2. Adiciona os slots de Runa DINAMICAMENTE
    -- Pega o número de slots dos stats PADRÃO (Constants) para inicialização
    -- Poderia pegar dos stats FINAIS, mas _calculateFinalStats pode não ser seguro chamar aqui ainda.
    -- Usar o padrão é seguro para a estrutura inicial. O número real será usado pela UI.
    local numRuneSlots = Constants.HUNTER_DEFAULT_STATS.runeSlots or 0
    print(string.format("    > Initializing with %d default rune slots.", numRuneSlots))
    for i = 1, numRuneSlots do
        local slotId = "rune_" .. i
        hunterData.equippedItems[slotId] = nil
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
    if not self.hunters[hunterId] then -- Check if the hunter ID exists in our managed list
        print(string.format("ERROR [HunterManager]: Attempt to activate invalid/unknown hunter ID: %s", hunterId))
        return false
    end

    if hunterId ~= self.activeHunterId then
        local previousHunterId = self.activeHunterId
        print(string.format("[HunterManager] Switching active hunter from %s to %s", previousHunterId or "none", hunterId))

        -- Switch the active ID
        self.activeHunterId = hunterId

        -- Salva APENAS o estado do HunterManager (qual ID está ativo)
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
    return hunterData and hunterData.equippedItems -- Return the sub-table
end

--- Checks if a given slot ID is valid for the ACTIVE hunter.
-- Considers base slots and the DYNAMIC number of rune slots.
---@param slotId string The slot ID to check (e.g., "weapon", "rune_3").
---@return boolean True if the slot is valid for the active hunter.
function HunterManager:_isSlotValidForActiveHunter(slotId)
    if not self.activeHunterId then return false end

    -- 1. Check if it's a base equipment slot
    for _, baseSlotId in ipairs(self.EQUIPMENT_SLOTS_BASE) do
        if slotId == baseSlotId then
            return true
        end
    end

    -- 2. Check if it's a rune slot and within the hunter's limit
    local prefix, numStr = slotId:match("^(rune_)(%d+)$")
    if prefix and numStr then
        local slotNum = tonumber(numStr)
        local maxSlots = self:getActiveHunterMaxRuneSlots() -- Obtém o limite ATUAL
        if slotNum > 0 and slotNum <= maxSlots then
            return true
        end
    end

    -- 3. Not a valid base slot or rune slot for this hunter
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

    -- Check if slotId is valid FOR THE ACTIVE HUNTER
    if not self:_isSlotValidForActiveHunter(slotId) then
        print(string.format("ERROR [HunterManager:equipItem]: Invalid or inactive equipment slot for hunter %s: %s",
            self.activeHunterId, slotId))
        return false, nil
    end

    -- Check compatibility (this should ideally be done by UI, but double-check)
    local baseData = self.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
    if not baseData then
        print(string.format("ERROR [HunterManager:equipItem]: Could not get base data for %s", itemInstance.itemBaseId))
        return false, nil
    end
    -- Basic type check based on slot prefix/name
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
        return false, nil -- Deny equip if incompatible
    end

    local hunterData = self.hunters[self.activeHunterId]
    if not hunterData or not hunterData.equippedItems then
        print("ERROR [HunterManager:equipItem]: Equipment structure not found for active hunter.")
        return false, nil
    end

    local hunterEquipment = hunterData.equippedItems
    local oldItemInstance = hunterEquipment[slotId] -- Get the old instance directly

    if oldItemInstance then
        print(string.format("  [HunterManager] Unequipping previous item (%s, ID: %d) from slot %s",
            oldItemInstance.itemBaseId, oldItemInstance.instanceId, slotId))
    end

    -- Equip the new instance
    hunterEquipment[slotId] = itemInstance -- Store the full instance
    print(string.format("[HunterManager] Item %d (%s) equipped in slot %s for %s", itemInstance.instanceId,
        itemInstance.itemBaseId, slotId, self.activeHunterId))

    -- TODO: Recalculate hunter's final stats (or mark for recalculation)

    -- Return success and the old item instance (UI needs to handle placing it back)
    return true, oldItemInstance -- Return the old instance
end

--- Unequips the item from a specific slot for the active hunter.
--- @param slotId string Slot ID to unequip from.
--- @return table|nil Returns the instance of the unequipped item, or nil.
function HunterManager:unequipItem(slotId)
    if not self.activeHunterId or not slotId then return nil end

    local hunterData = self.hunters[self.activeHunterId]
    if not hunterData or not hunterData.equippedItems then return nil end

    local hunterEquipment = hunterData.equippedItems
    local itemToUnequip = hunterEquipment[slotId] -- Get the instance

    if itemToUnequip then
        print(string.format("[HunterManager] Unequipping item (%s, ID: %d) from slot %s for %s",
            itemToUnequip.itemBaseId, itemToUnequip.instanceId, slotId, self.activeHunterId))
        hunterEquipment[slotId] = nil
        -- TODO: Recalculate hunter's final stats (or mark for recalculation)
        return itemToUnequip -- Return the full instance
    end
    return nil
end

--- Saves the loadout associated with a specific hunter.
--- @param hunterId string The ID of the hunter whose loadout to save.
function HunterManager:saveActiveHunterLoadout(hunterId)
    if not hunterId then
        print("ERROR [HunterManager:saveActiveHunterLoadout]: hunterId not provided!")
        return
    end
    print(string.format("[HunterManager] Requesting save of hunter's loadout (%s)...", hunterId))
    if self.loadoutManager then
        self.loadoutManager:saveLoadout(hunterId)
    else
        print("ERROR [HunterManager:saveActiveHunterLoadout]: LoadoutManager not available!")
    end
end

--- Saves the HunterManager state (hunter definitions, active ID, next ID).
function HunterManager:saveState()
    print("[HunterManager] Requesting state save (activeHunterId, nextHunterId, hunter data)...")

    -- Create a serializable copy of the hunters data
    local serializableHunters = {}
    for hunterId, hunterData in pairs(self.hunters) do
        -- Basic hunter info
        serializableHunters[hunterId] = {
            id = hunterData.id,
            name = hunterData.name, -- Save the name
            baseRankId = hunterData.baseRankId,
            finalRankId = hunterData.finalRankId,
            archetypeIds = hunterData.archetypeIds,
            equippedItems = {} -- Prepare equipment sub-table
        }
        -- Serialize equipped items (similar to before)
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
        version = 2, -- Bump version for new structure
        activeHunterId = self.activeHunterId,
        nextHunterId = self.nextHunterId,
        hunters = serializableHunters -- Save the serializable hunter data
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

    self.hunters = {} -- Clear before loading
    self.activeHunterId = nil
    self.nextHunterId = 1

    if not loadedData or type(loadedData) ~= "table" then
        print("[HunterManager] No valid save data found. Will need to recruit initial hunter.")
        return false
    end

    -- Basic version check (can add migration later)
    if loadedData.version ~= 2 then
        print(string.format(
            "WARNING [HunterManager]: Save data version (%s) incompatible with current (%s). Attempting to load anyway...",
            tostring(loadedData.version), 2))
        -- TODO: Add migration logic if necessary for older versions
        -- For now, we might fail if the structure is too different.
    end

    self.activeHunterId = loadedData.activeHunterId or nil
    self.nextHunterId = loadedData.nextHunterId or 1
    local loadedHuntersData = loadedData.hunters or {}

    -- Reconstruct hunter data (including equipped items)
    for hunterId, savedHunterData in pairs(loadedHuntersData) do
        local newHunterEntry = {
            id = savedHunterData.id or hunterId,            -- Use saved ID or key as fallback
            name = savedHunterData.name or ("Hunter " .. hunterId),
            baseRankId = savedHunterData.baseRankId or "E", -- Default if missing
            finalRankId = savedHunterData.finalRankId or savedHunterData.baseRankId or "E",
            archetypeIds = savedHunterData.archetypeIds or {},
            equippedItems = {} -- Initialize equipment table
        }

        -- Reconstruct equipped items for this hunter
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
                        "WARNING [HunterManager]: Could not find base data for equipped item '%s' (instance %d) for hunter '%s'. Slot will be empty.",
                        savedItemData.itemBaseId, savedItemData.instanceId, hunterId))
                    newHunterEntry.equippedItems[slotId] = nil
                end
            else
                newHunterEntry.equippedItems[slotId] = nil
            end
        end

        -- Ensure all DEFINED BASE slots exist in the loaded data (for newly added slots)
        for _, slotId in ipairs(self.EQUIPMENT_SLOTS_BASE) do
            if newHunterEntry.equippedItems[slotId] == nil then
                newHunterEntry.equippedItems[slotId] = nil -- Ensure slot exists as nil
            end
        end
        -- NOTE: Rune slots from saved data ARE loaded above. We don't iterate through
        -- EQUIPMENT_SLOTS anymore, which contained the static rune slots.
        -- If a save file has more rune slots than the current default, they will load,
        -- but might not be displayed or usable if the hunter's stats limit them.
        -- If a save file has fewer, the missing ones won't be created here, but
        -- _initializeEquippedItems might handle this if called later? Revisit if needed.

        self.hunters[hunterId] = newHunterEntry -- Add the reconstructed hunter data
    end

    print(string.format("[HunterManager] Load complete. %d hunters loaded. Active: %s. Next ID: %d",
        table.maxn(self.hunters), -- Crude way to count, better to iterate
        tostring(self.activeHunterId), self.nextHunterId))
    return true
end

--- Internal helper to calculate final stats based ONLY on archetype IDs and base stats.
--- Does NOT consider equipped items.
--- @param archetypeIds table List of archetype IDs.
--- @return table Table with calculated final stats.
function HunterManager:_calculateStatsForCandidate(archetypeIds)
    -- 1. Start with default stats
    local finalStats = {}
    for key, value in pairs(Constants.HUNTER_DEFAULT_STATS) do
        finalStats[key] = value
    end

    -- 2. Apply archetype modifiers (New Structure)
    archetypeIds = archetypeIds or {}
    local accumulatedBase = {} -- Accumulate base additions
    local accumulatedMult = {} -- Accumulate multiplicative changes

    for _, archetypeId in ipairs(archetypeIds) do
        local archetypeData = self.archetypeManager:getArchetypeData(archetypeId)
        if archetypeData and archetypeData.modifiers then
            -- Iterate through the list of modifier tables
            for _, mod in ipairs(archetypeData.modifiers) do
                local statName = mod.stat
                if not statName then
                    print(string.format(
                        "WARNING [_calculateStatsForCandidate]: Missing 'stat' field in modifier for archetype '%s'",
                        archetypeId))
                    goto continue_candidate_mod_loop -- Skip this modifier
                end

                -- Check for baseValue
                if mod.baseValue ~= nil then
                    if finalStats[statName] == nil then
                        print(string.format(
                            "WARNING [_calculateStatsForCandidate]: Base stat '%s' not found for baseValue in '%s'",
                            statName,
                            archetypeId))
                    else
                        accumulatedBase[statName] = (accumulatedBase[statName] or 0) + mod.baseValue
                    end
                end

                -- Check for multValue
                if mod.multValue ~= nil then
                    if finalStats[statName] == nil then
                        print(string.format(
                            "WARNING [_calculateStatsForCandidate]: Base stat '%s' not found for multValue in '%s'",
                            statName,
                            archetypeId))
                    else
                        -- Accumulate the percentage change
                        accumulatedMult[statName] = (accumulatedMult[statName] or 0) + mod.multValue
                    end
                end
                ::continue_candidate_mod_loop::
            end
        end
    end

    -- 3. Apply accumulated modifiers (Base first, then Mult)
    -- Apply Base Additions
    for statName, baseAdd in pairs(accumulatedBase) do
        if finalStats[statName] ~= nil then
            finalStats[statName] = finalStats[statName] + baseAdd
        end
    end

    -- Apply Multiplicative Changes
    for statName, multChange in pairs(accumulatedMult) do
        if finalStats[statName] ~= nil then
            -- Apply the total multiplier (1.0 + accumulated percentage change)
            finalStats[statName] = finalStats[statName] * (1.0 + multChange)
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
    local isArray = type(choices[1]) == "table" -- Detect if it's an array of choices or a map

    if isArray then
        for i, choice in ipairs(choices) do
            totalWeight = totalWeight + (choice.weight or 0)
        end
    else
        -- Processando mapa (como ArchetypesData.Ranks)
        print("DEBUG weightedRandomChoice: Calculating total weight for map...")
        for key, choiceData in pairs(choices) do
            local w = choiceData.recruitment_weight or 0
            print(string.format("  - Key: %s, recruitment_weight: %.1f", tostring(key), w))
            totalWeight = totalWeight + w
        end
    end

    print(string.format("DEBUG weightedRandomChoice: Total Weight calculated: %.2f", totalWeight))
    if totalWeight <= 0 then
        print("DEBUG weightedRandomChoice: Total weight is zero or negative. Returning nil.")
        return nil
    end

    local randomNum = love.math.random() * totalWeight
    local cumulativeWeight = 0
    print(string.format("DEBUG weightedRandomChoice: randomNum (0..totalWeight): %.4f", randomNum))

    if isArray then
        -- ... (lógica do array, não deve ser usada para ranks)
    else
        -- Process map (like ArchetypesData.Ranks)
        print("DEBUG weightedRandomChoice: Iterating map for selection...")
        for key, choiceData in pairs(choices) do
            local weight = choiceData.recruitment_weight or 0
            print(string.format("  -> Check: Key '%s', Weight %.1f. Is %.4f < %.4f + %.1f ?",
                tostring(key), weight, randomNum, cumulativeWeight, weight))
            if randomNum < cumulativeWeight + weight then
                print(string.format("  -->> CHOSEN: %s", tostring(key)))
                return key -- Return the key of the chosen item
            end
            cumulativeWeight = cumulativeWeight + weight
        end
        print("DEBUG weightedRandomChoice: Loop finished without choice (map). Returning nil.")
    end

    return nil -- Fallback, should not be reached if totalWeight > 0
end

--- Generates a list of potential hunter candidates for recruitment, respecting rank rules.
--- @param count number The number of candidates to generate.
--- @return table A list of candidate data tables, each containing { id, name, baseRankId, finalRankId, archetypeIds, archetypes, finalStats }.
function HunterManager:generateHunterCandidates(count)
    print(string.format("[HunterManager] Generating %d hunter candidates...", count))
    local candidates = {}
    local names = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta" } -- Pool de nomes

    -- Pre-filter available archetypes by rank for efficiency
    local archetypesByRank = {}
    for archId, archData in pairs(ArchetypesData.Archetypes) do
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

        -- 1. Determine Rank based on weights
        local chosenRankId = weightedRandomChoice(ArchetypesData.Ranks)
        print(string.format("  >> Weighted random choice for rank: %s", tostring(chosenRankId)))
        if not chosenRankId then
            print("ERROR [generateHunterCandidates]: Could not determine candidate rank. Defaulting to E.")
            chosenRankId = "E"
        end
        local rankData = ArchetypesData.Ranks[chosenRankId]
        candidate.baseRankId = chosenRankId -- Start at the generated rank
        candidate.finalRankId = chosenRankId

        -- 2. Determine Number of Archetypes for the rank
        local minArchetypes = rankData.archetype_count_min or 1
        local maxArchetypes = rankData.archetype_count_max or minArchetypes
        local numArchetypes = love.math.random(minArchetypes, maxArchetypes)

        -- 3. Select Archetypes according to new rule (Mandatory Rank + Lower Ranks)
        candidate.archetypeIds = {}
        local numArchetypesToPick = numArchetypes
        local pickedArchetypesSet = {} -- To easily check for duplicates if needed

        -- Pool of archetypes specific to the chosen rank
        local rankSpecificArchetypes = archetypesByRank[chosenRankId] or {}
        local availableRankSpecific = {}
        for _, id in ipairs(rankSpecificArchetypes) do table.insert(availableRankSpecific, id) end -- Copy

        -- Pool of archetypes from ranks LOWER than the chosen rank
        local lowerRankArchetypesPool = {}
        local rankOrder = { "E", "D", "C", "B", "A", "S" }
        for _, currentRankId in ipairs(rankOrder) do
            if currentRankId == chosenRankId then break end -- Stop before the chosen rank
            local archetypesInThisRank = archetypesByRank[currentRankId] or {}
            for _, archId in ipairs(archetypesInThisRank) do
                table.insert(lowerRankArchetypesPool, archId)
            end
        end

        -- Step 1: Pick at least one archetype of the chosen rank (if possible and needed)
        if numArchetypesToPick > 0 and #availableRankSpecific > 0 then
            local randomIndex = love.math.random(#availableRankSpecific)
            local chosenArchId = availableRankSpecific[randomIndex]
            table.insert(candidate.archetypeIds, chosenArchId)
            pickedArchetypesSet[chosenArchId] = true
            table.remove(availableRankSpecific, randomIndex) -- Remove from specific pool for step 2
            numArchetypesToPick = numArchetypesToPick - 1
            print(string.format("    - Picked mandatory Rank %s archetype: %s", chosenRankId, chosenArchId))

            -- Also remove from the lower rank pool if it somehow existed there (shouldn't happen)
            for k = #lowerRankArchetypesPool, 1, -1 do
                if lowerRankArchetypesPool[k] == chosenArchId then
                    table.remove(lowerRankArchetypesPool, k)
                    break
                end
            end
        elseif numArchetypesToPick > 0 and #availableRankSpecific == 0 then
            print(string.format(
                "WARNING [generateHunterCandidates]: Candidate Rank is %s, but NO archetypes were found for this specific rank. Picking only from lower ranks.",
                chosenRankId))
        end

        -- Step 2: Pick remaining archetypes from the combined pool of lower ranks + REMAINING rank-specific
        local remainingAvailablePool = {}
        -- Add remaining rank-specific archetypes (those not picked in step 1)
        for _, id in ipairs(availableRankSpecific) do table.insert(remainingAvailablePool, id) end
        -- Add lower rank archetypes
        for _, id in ipairs(lowerRankArchetypesPool) do table.insert(remainingAvailablePool, id) end

        if numArchetypesToPick > 0 and #remainingAvailablePool > 0 then
            print(string.format("    - Picking %d remaining archetypes from pool of %d (Ranks <= %s)",
                numArchetypesToPick, #remainingAvailablePool, chosenRankId))
            -- Ensure we don't try to pick more than available
            local actualRemainingPicks = math.min(numArchetypesToPick, #remainingAvailablePool)

            -- Shuffle the remaining pool
            for j = #remainingAvailablePool, 2, -1 do
                local k = love.math.random(j)
                remainingAvailablePool[j], remainingAvailablePool[k] = remainingAvailablePool[k],
                    remainingAvailablePool[j]
            end

            -- Pick the required number
            local pickedCount = 0
            for j = 1, #remainingAvailablePool do
                if pickedCount >= actualRemainingPicks then break end -- Stop if we picked enough

                local pickedId = remainingAvailablePool[j]
                -- Check if already picked in step 1 OR earlier in this step (due to potential duplicates in original pools)
                if not pickedArchetypesSet[pickedId] then
                    table.insert(candidate.archetypeIds, pickedId)
                    pickedArchetypesSet[pickedId] = true
                    pickedCount = pickedCount + 1
                    -- else -- Optional: Log if duplicate was avoided
                    --    print(string.format("DEBUG: Skipped duplicate %s in remaining picks", pickedId))
                end
            end
            -- Check if we actually picked enough (could happen if pool had many duplicates of the mandatory pick)
            if pickedCount < actualRemainingPicks then
                print(string.format(
                    "WARNING [generateHunterCandidates]: Could only pick %d out of %d remaining archetypes due to potential duplicates or empty pool after mandatory pick.",
                    pickedCount, actualRemainingPicks))
            end
        elseif numArchetypesToPick > 0 then
            print(string.format(
                "WARNING [generateHunterCandidates]: Needed %d more archetypes, but the remaining pool (Ranks <= %s) is empty.",
                numArchetypesToPick, chosenRankId))
        end

        -- 4. Get full archetype data for the UI
        candidate.archetypes = {}
        for _, arcId in ipairs(candidate.archetypeIds) do
            local arcData = self.archetypeManager:getArchetypeData(arcId) -- Use manager to get data
            if arcData then
                table.insert(candidate.archetypes, arcData)
            else
                print(string.format(
                    "WARNING [generateHunterCandidates]: Could not get data for selected archetype ID '%s'", arcId))
            end
        end

        -- 5. Calculate final stats based on selected archetype IDs
        candidate.finalStats = self:_calculateStatsForCandidate(candidate.archetypeIds)

        table.insert(candidates, candidate)
        print(string.format("  > Candidate %d: Name=%s, Rank=%s, Archetypes=[%s]", i, candidate.name,
            candidate.finalRankId,
            table.concat(candidate.archetypeIds, ", ")))
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
        name = candidateData.name, -- Usa o nome do candidato
        baseRankId = candidateData.baseRankId or "E",
        finalRankId = candidateData.finalRankId or "E",
        archetypeIds = candidateData.archetypeIds,
        -- equippedItems será inicializado abaixo
    }

    -- Adiciona à tabela principal de caçadores
    self.hunters[hunterId] = newHunterData

    -- Inicializa a estrutura de equipamento para o novo caçador
    self:_initializeEquippedItems(hunterId)

    -- Salva o estado geral (incluindo o novo caçador e nextHunterId)
    self:saveState()

    print(string.format("[HunterManager] Hunter %s recruited successfully.", hunterId))
    return hunterId
end

return HunterManager
