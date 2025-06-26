---@class HunterManager
---@field loadoutManager LoadoutManager
---@field itemDataManager ItemDataManager
---@field archetypeManager ArchetypeManager
---@field activeHunterId string | nil
---@field hunters table<string, table>
---@field nextHunterId number
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

---@class HunterManager.EQUIPMENT_SLOTS_BASE
--- Define os IDs dos slots de equipamento base que todo caçador possui.
--- Estes são independentes de arquétipos ou outros bônus (ex: slots de runas são dinâmicos).
---@type table<number, string>
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

    -- Agrega com base nos items equipados
    local equippedItems = hunterData.equippedItems or {}
    for slot, itemInst in pairs(equippedItems) do
        if itemInst and itemInst.itemBaseId and self.itemDataManager then
            local itemData = self.itemDataManager:getBaseItemData(itemInst.itemBaseId)
            if itemData and itemData.modifiers then
                for _, mod in ipairs(itemData.modifiers) do
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
            if itemInst and itemInst.itemBaseId then
                finalStats.equippedItems[slot] = itemInst.itemBaseId
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

--- Return a hunter data by id
--- @param hunterId string
function HunterManager:getHunterData(hunterId)
    return self.hunters[hunterId]
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
--- @param slotId string The slot ID to check (e.g., "weapon", "rune_3").
--- @return boolean True if the slot is valid for the active hunter.
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
        error("ERROR [HunterManager:equipItem]: Invalid arguments.")
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

    ---@type PlayerManager
    local playerManager = ManagerRegistry:tryGet("playerManager")

    if slotId == Constants.SLOT_IDS.WEAPON then
        if playerManager then
            playerManager:setActiveWeapon(itemInstance)
            print("  -> Notified PlayerManager to set new active weapon.")
        else
            print("  -> WARNING: Could not get PlayerManager to set new weapon!")
        end
    elseif baseData and baseData.type == "rune" then
        if playerManager then
            playerManager.runeController:activateRuneAbility(slotId, itemInstance)
            print(string.format("  -> Notified PlayerManager to activate rune ability for slot %s.", slotId))
        else
            print(string.format("  -> WARNING: Could not get PlayerManager to activate rune for slot %s!", slotId))
        end
    end
    return true, oldItemInstance
end

--- Exclui permanentemente um caçador do jogo.
--- @param hunterId string O ID do caçador a ser excluído.
function HunterManager:deleteHunter(hunterId)
    if not hunterId or not self.hunters[hunterId] then
        print(string.format("AVISO [HunterManager]: Tentativa de excluir caçador inexistente com ID: %s",
            tostring(hunterId)))
        return
    end

    print(string.format("[HunterManager] Excluindo permanentemente o caçador: %s (%s)", self.hunters[hunterId].name,
        hunterId))

    -- Remove o caçador da tabela
    self.hunters[hunterId] = nil

    -- Se o caçador excluído era o ativo, precisamos selecionar um novo.
    if self.activeHunterId == hunterId then
        local newActiveId = next(self.hunters) -- Pega o primeiro caçador que encontrar na lista

        if newActiveId then
            print(string.format("[HunterManager] Caçador ativo excluído. Novo caçador ativo selecionado: %s", newActiveId))
            self.activeHunterId = newActiveId
        else
            -- Se não houver mais caçadores, recruta um novo.
            print("[HunterManager] Todos os caçadores foram perdidos. Recrutando um novo recruta.")
            self:_recruitInitialHunter() -- Isso já define o novo caçador como ativo.
        end
    end

    -- Salva o estado para persistir a exclusão.
    self:saveState()
    print(string.format("[HunterManager] Exclusão do caçador %s concluída.", hunterId))
end

--- Desequipa um item de um slot para o caçador ativo.
--- @param slotId string O ID do slot de onde o item será removido.
--- @return table|nil A instância do item que foi desequipado, ou nil se não havia item.
function HunterManager:unequipItemFromActiveHunter(slotId)
    return self:unequipItem(self.activeHunterId, slotId)
end

--- Desequipa um item de um slot para um caçador específico.
--- @param hunterId string O ID do caçador.
--- @param slotId string O ID do slot de onde o item será removido.
--- @return table|nil A instância do item que foi desequipado, ou nil se não havia item.
function HunterManager:unequipItem(hunterId, slotId)
    local hunterData = self.hunters[hunterId]
    if not hunterData or not hunterData.equippedItems then
        print(string.format("AVISO (unequipItem): Caçador %s ou seu equipamento não encontrado.", hunterId))
        return nil
    end

    local unequippedItem = hunterData.equippedItems[slotId]
    if unequippedItem then
        print(string.format("[HunterManager] Desequipando item %s do slot %s para o caçador %s.",
            unequippedItem.itemBaseId, slotId, hunterId))
        hunterData.equippedItems[slotId] = nil
    end
    return unequippedItem
end

--- NOVO: Equipa um item a um slot específico do loadout de um caçador específico.
--- Usado pela LobbyScene após a extração para registrar os equipamentos que vieram da gameplay.
--- Esta função NÃO lida com devolução de itens antigos para o inventário, pois assume
--- que o inventário (LoadoutManager) já foi tratado separadamente.
---@param hunterId string O ID do caçador.
---@param slotId string O ID do slot onde o item será equipado.
---@param itemInstance table A instância do item a ser equipada.
---@return boolean True se o item foi equipado com sucesso, false caso contrário.
function HunterManager:equipItemToLoadout(hunterId, slotId, itemInstance)
    if not hunterId or not slotId or not itemInstance then
        print(string.format(
            "ERROR [HunterManager:equipItemToLoadout]: Argumentos inválidos recebidos. HunterID: %s, SlotID: %s, Item: %s",
            tostring(hunterId), tostring(slotId), tostring(itemInstance and itemInstance.itemBaseId)))
        return false
    end

    local hunterData = self.hunters[hunterId]
    if not hunterData then
        print(string.format("ERROR [HunterManager:equipItemToLoadout]: Caçador com ID '%s' não encontrado.", hunterId))
        return false
    end

    -- Garante que a estrutura equippedItems exista.
    hunterData.equippedItems = hunterData.equippedItems or {}
    self:_initializeEquippedItems(hunterId) -- Garante que todos os slots base e de runas existem

    -- Validação opcional do tipo de item vs slot (similar à :equipItem)
    -- Por simplicidade e porque a GameplayScene já deve ter validado, vamos omitir por enquanto,
    -- mas pode ser adicionado aqui se necessário para robustez.
    local baseData = self.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
    if not baseData then
        print(string.format(
            "ERROR [HunterManager:equipItemToLoadout]: Não foi possível obter dados base para o item %s do caçador %s.",
            itemInstance.itemBaseId, hunterId))
        return false
    end

    local expectedItemType = "unknown"
    if slotId == Constants.SLOT_IDS.WEAPON then
        expectedItemType = "weapon"
    elseif slotId == Constants.SLOT_IDS.HELMET then
        expectedItemType = "helmet"
    elseif slotId == Constants.SLOT_IDS.CHEST then
        expectedItemType = "chest"
    elseif slotId == Constants.SLOT_IDS.GLOVES then
        expectedItemType = "gloves"
    elseif slotId == Constants.SLOT_IDS.BOOTS then
        expectedItemType = "boots"
    elseif slotId == Constants.SLOT_IDS.LEGS then
        expectedItemType = "legs"
    elseif string.sub(slotId, 1, string.len(Constants.SLOT_IDS.RUNE)) == Constants.SLOT_IDS.RUNE then
        expectedItemType = "rune"
        -- Adicionar outros tipos de slot se necessário (ex: amuleto, anel)
    end

    if expectedItemType ~= "unknown" and baseData.type ~= expectedItemType then
        print(string.format(
            "WARNING [HunterManager:equipItemToLoadout]: Tipo de item '%s' (item %s) incompatível com slot '%s' (espera '%s') para caçador %s. Equipamento negado.",
            baseData.type, itemInstance.itemBaseId, slotId, expectedItemType, hunterId))
        return false
    end

    print(string.format(
        "[HunterManager:equipItemToLoadout] Equipando item (BaseID: %s, InstID: %s) no slot '%s' do caçador '%s'.",
        tostring(itemInstance.itemBaseId), tostring(itemInstance.instanceId), slotId, hunterId))

    hunterData.equippedItems[slotId] = itemInstance
    return true
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
            skinTone = hunterData.skinTone,
            equippedItems = {}
        }
        if hunterData.equippedItems then
            for slotId, itemInstance in pairs(hunterData.equippedItems) do
                if itemInstance then
                    serializableHunters[hunterId].equippedItems[slotId] = {
                        instanceId = itemInstance.instanceId,
                        itemBaseId = itemInstance.itemBaseId,
                        quantity = itemInstance.quantity or 1,
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
            skinTone = savedHunterData.skinTone or "medium",
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
                        modifiers = baseData.modifiers or {},
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
        skinTone = candidateData.skinTone or "medium",
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

--- Move um item equipado de um slot para outro para um caçador específico.
--- Usado para trocar itens entre slots de equipamento (ex: trocar runas de lugar).
--- @param hunterId string O ID do caçador.
--- @param sourceSlotId string O ID do slot de origem.
--- @param targetSlotId string O ID do slot de destino.
--- @return boolean True se a troca foi bem-sucedida, false caso contrário.
function HunterManager:moveEquippedItem(hunterId, sourceSlotId, targetSlotId)
    if not hunterId or not sourceSlotId or not targetSlotId then
        error("ERROR [HunterManager:moveEquippedItem]: Argumentos inválidos.")
    end

    if sourceSlotId == targetSlotId then
        Logger.warn(
            "hunter_manager.move_equipped_item.equal_slots",
            "[HunterManager:moveEquippedItem] Slots de origem e destino são iguais."
        )
        return true -- Considera sucesso pois não há trabalho a fazer
    end

    local hunterData = self.hunters[hunterId]
    if not hunterData or not hunterData.equippedItems then
        error(string.format("[HunterManager:moveEquippedItem] Caçador '%s' ou equipamentos não encontrados.", hunterId))
    end

    local sourceItem = hunterData.equippedItems[sourceSlotId]
    local targetItem = hunterData.equippedItems[targetSlotId]

    if not sourceItem then
        Logger.warn(
            "hunter_manager.move_equipped_item.no_source_item",
            string.format(
                "[HunterManager:moveEquippedItem] Nenhum item encontrado no slot de origem '%s'.",
                sourceSlotId
            )
        )
        return true
    end

    -- Validações de compatibilidade de tipos para o slot de destino
    local sourceItemData = self.itemDataManager:getBaseItemData(sourceItem.itemBaseId)
    if sourceItemData then
        local expectedTargetType = "unknown"

        if targetSlotId == "weapon" then expectedTargetType = "weapon" end
        if targetSlotId == "helmet" then expectedTargetType = "helmet" end
        if targetSlotId == "chest" then expectedTargetType = "chest" end
        if targetSlotId == "gloves" then expectedTargetType = "gloves" end
        if targetSlotId == "boots" then expectedTargetType = "boots" end
        if targetSlotId == "legs" then expectedTargetType = "legs" end
        if string.sub(targetSlotId, 1, 5) == "rune_" then expectedTargetType = "rune" end

        if expectedTargetType ~= "unknown" and sourceItemData.type ~= expectedTargetType then
            error(string.format(
                "[HunterManager:moveEquippedItem] Item tipo '%s' incompatível com slot destino '%s' (espera '%s').",
                sourceItemData.type, targetSlotId, expectedTargetType
            ))
        end
    end

    -- Se há item no destino, valida se pode ser movido para origem
    if targetItem then
        local targetItemData = self.itemDataManager:getBaseItemData(targetItem.itemBaseId)
        if targetItemData then
            local expectedSourceType = "unknown"

            if sourceSlotId == "weapon" then expectedSourceType = "weapon" end
            if sourceSlotId == "helmet" then expectedSourceType = "helmet" end
            if sourceSlotId == "chest" then expectedSourceType = "chest" end
            if sourceSlotId == "gloves" then expectedSourceType = "gloves" end
            if sourceSlotId == "boots" then expectedSourceType = "boots" end
            if sourceSlotId == "legs" then expectedSourceType = "legs" end
            if string.sub(sourceSlotId, 1, 5) == "rune_" then expectedSourceType = "rune" end

            if expectedSourceType ~= "unknown" and targetItemData.type ~= expectedSourceType then
                error(string.format(
                    "[HunterManager:moveEquippedItem] Item alvo tipo '%s' incompatível com slot origem '%s' (espera '%s').",
                    targetItemData.type, sourceSlotId, expectedSourceType
                ))
            end
        end
    end

    -- Realiza a troca
    hunterData.equippedItems[sourceSlotId] = targetItem
    hunterData.equippedItems[targetSlotId] = sourceItem

    -- Salva o estado para garantir persistência
    self:saveState()

    -- Notifica PlayerManager das mudanças se for o caçador ativo
    if hunterId == self.activeHunterId then
        ---@type PlayerManager
        local playerManager = ManagerRegistry:tryGet("playerManager")

        if playerManager then
            -- Para armas
            if sourceSlotId == Constants.SLOT_IDS.WEAPON then
                playerManager:setActiveWeapon(targetItem)
            elseif targetSlotId == Constants.SLOT_IDS.WEAPON then
                playerManager:setActiveWeapon(sourceItem)
            end

            -- Para runas
            if string.sub(sourceSlotId, 1, 5) == "rune_" then
                if targetItem then
                    playerManager.runeController:updateRuneInSlot(sourceSlotId, targetItem)
                else
                    playerManager.runeController:updateRuneInSlot(sourceSlotId, nil)
                end
            end

            if string.sub(targetSlotId, 1, 5) == "rune_" then
                playerManager.runeController:updateRuneInSlot(targetSlotId, sourceItem)
            end
        else
            Logger.warn("hunter_manager.move_equipped_item.player_manager_not_found",
                "PlayerManager não encontrado para notificar mudanças!")
        end
    end

    return true
end

return HunterManager
