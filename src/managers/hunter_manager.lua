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

    -- Load the loadout for the active hunter (internal structure of loadLoadout doesn't change)
    print(string.format("  [HunterManager] Requesting loadout load for %s...", instance.activeHunterId))
    instance.loadoutManager:loadLoadout(instance.activeHunterId)

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

    -- 1. Start with default stats
    local finalStats = {}
    for key, value in pairs(Constants.HUNTER_DEFAULT_STATS) do
        finalStats[key] = value
    end

    -- 2. Apply archetype modifiers
    local archetypeIds = hunterData.archetypeIds or {}
    local appliedModifiers = { -- To calculate multipliers separately
        mult = {},
        add = {}
    }

    for _, archetypeId in ipairs(archetypeIds) do
        local archetypeData = self.archetypeManager:getArchetypeData(archetypeId)
        if archetypeData and archetypeData.modifiers then
            for modifierKey, modifierValue in pairs(archetypeData.modifiers) do
                -- Split key (e.g., "health") from type (e.g., "_add" or "_mult")
                local statName, modifierType = modifierKey:match("^(.+)_([^_]+)$")

                if statName and modifierType then
                    if modifierType == "add" then
                        appliedModifiers.add[statName] = (appliedModifiers.add[statName] or 0) + modifierValue
                    elseif modifierType == "mult" then
                        appliedModifiers.mult[statName] = (appliedModifiers.mult[statName] or 1.0) * modifierValue
                    else
                        print(string.format(
                            "WARNING [_calculateFinalStats]: Unknown modifier type '%s' for '%s' in archetype '%s'",
                            modifierType, statName, archetypeId))
                    end
                else
                    print(string.format("WARNING [_calculateFinalStats]: Malformed modifier key '%s' in archetype '%s'",
                        modifierKey, archetypeId))
                end
            end
        end
    end

    -- 3. Apply accumulated modifiers (Add first, then Mult)
    for statName, addValue in pairs(appliedModifiers.add) do
        if finalStats[statName] ~= nil then
            finalStats[statName] = finalStats[statName] + addValue
        else
            print(string.format("WARNING [_calculateFinalStats]: Base stat '%s' not found to apply _add modifier.",
                statName))
        end
    end

    for statName, multValue in pairs(appliedModifiers.mult) do
        if finalStats[statName] ~= nil then
            finalStats[statName] = finalStats[statName] * multValue
        else
            print(string.format("WARNING [_calculateFinalStats]: Base stat '%s' not found to apply _mult modifier.",
                statName))
        end
    end

    -- TODO: Apply stats from equipped items (later phase)

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

--- NOVO: Returns the MAXIMUM number of rune slots for the active hunter.
-- Reads from the final calculated stats.
--- @return number Number of rune slots (defaults to 0).
function HunterManager:getActiveHunterMaxRuneSlots()
    if not self.activeHunterId then return 0 end
    local finalStats = self:getActiveHunterFinalStats() -- Usa a função existente que calcula
    return finalStats and finalStats.runeSlots or 0
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

        -- Save PREVIOUS hunter's data (loadout - equipment is saved with main state)
        if previousHunterId then
            self:saveActiveHunterLoadout(previousHunterId)
        end

        -- Switch the active ID
        self.activeHunterId = hunterId

        -- Load the NEW active hunter's loadout
        print(string.format("  [HunterManager] Requesting loadout load for %s...", self.activeHunterId))
        self.loadoutManager:loadLoadout(self.activeHunterId)

        -- Save the HunterManager state (which ID is active)
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

    -- 2. Apply archetype modifiers
    archetypeIds = archetypeIds or {}
    local appliedModifiers = { mult = {}, add = {} }

    for _, archetypeId in ipairs(archetypeIds) do
        local archetypeData = self.archetypeManager:getArchetypeData(archetypeId)
        if archetypeData and archetypeData.modifiers then
            for modifierKey, modifierValue in pairs(archetypeData.modifiers) do
                local statName, modifierType = modifierKey:match("^(.+)_([^_]+)$")
                if statName and modifierType then
                    if modifierType == "add" then
                        appliedModifiers.add[statName] = (appliedModifiers.add[statName] or 0) + modifierValue
                    elseif modifierType == "mult" then
                        appliedModifiers.mult[statName] = (appliedModifiers.mult[statName] or 1.0) * modifierValue
                    else
                        print(string.format(
                            "WARNING [_calculateStatsForCandidate]: Unknown modifier type '%s' for '%s' in archetype '%s'",
                            modifierType, statName, archetypeId))
                    end
                else
                    print(string.format(
                        "WARNING [_calculateStatsForCandidate]: Malformed modifier key '%s' in archetype '%s'",
                        modifierKey, archetypeId))
                end
            end
        end
    end

    -- 3. Apply accumulated modifiers (Add first, then Mult)
    for statName, addValue in pairs(appliedModifiers.add) do
        if finalStats[statName] ~= nil then
            finalStats[statName] = finalStats[statName] + addValue
        else
            print(string.format("WARNING [_calculateStatsForCandidate]: Base stat '%s' not found for _add modifier.",
                statName))
        end
    end
    for statName, multValue in pairs(appliedModifiers.mult) do
        if finalStats[statName] ~= nil then
            finalStats[statName] = finalStats[statName] * multValue
        else
            print(string.format("WARNING [_calculateStatsForCandidate]: Base stat '%s' not found for _mult modifier.",
                statName))
        end
    end

    return finalStats
end

--- Generates a list of potential hunter candidates for recruitment.
--- @param count number The number of candidates to generate.
--- @return table A list of candidate data tables, each containing { id, name, baseRankId, finalRankId, archetypeIds, finalStats }.
function HunterManager:generateHunterCandidates(count)
    print(string.format("[HunterManager] Generating %d hunter candidates...", count))
    local candidates = {}
    local names = { "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta" } -- Pool de nomes

    for i = 1, count do
        local candidate = {}
        candidate.id = "candidate_" .. i                 -- ID temporário
        candidate.name = "Candidato " .. (names[i] or i) -- Nome simples
        candidate.baseRankId = "E"                       -- Começa com Rank E por enquanto
        candidate.finalRankId = "E"

        -- Define número de arquétipos (ex: 1 ou 2)
        local numArchetypes = love.math.random(1, 2)
        candidate.archetypeIds = self.archetypeManager:getRandomArchetypeIds(numArchetypes)

        -- Calcula os stats finais baseados nos arquétipos
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

    -- Cria um loadout vazio para o novo caçador
    self.loadoutManager:createEmptyLoadout(hunterId)

    -- Salva o estado geral (incluindo o novo caçador e nextHunterId)
    self:saveState()

    print(string.format("[HunterManager] Hunter %s recruited successfully.", hunterId))
    return hunterId
end

return HunterManager
