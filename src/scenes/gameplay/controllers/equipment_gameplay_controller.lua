---@class EquipmentGameplayController
---@description Gerencia o estado de todos os itens equipados pelo jogador.
--- Emite eventos quando o equipamento muda, permitindo que outros sistemas reajam
--- de forma desacoplada.
---@field eventService EventService
---@field itemDataManager ItemDataService
---@field equippedItems table<string, ItemInstance|nil>
local EquipmentGameplayController = {}
EquipmentGameplayController.__index = EquipmentGameplayController

---@param eventService EventService
---@param itemDataManager ItemDataService
function EquipmentGameplayController:new(eventService, itemDataManager)
    local instance = setmetatable({}, EquipmentGameplayController)
    instance.eventService = eventService
    instance.itemDataManager = itemDataManager
    instance.equippedItems = {}
    return instance
end

--- Inicializa o controller com os itens que o jogador já tem equipado.
---@param equippedItems table<string, ItemInstance>
function EquipmentGameplayController:init(equippedItems)
    Logger.info("equipment_gameplay_controller.init", "[EquipmentGameplayController:init] Initializing...")

    -- DEBUG: Log detalhado dos itens equipados na inicialização
    Logger.info("equipment_gameplay_controller.debug.init_items",
        string.format("[DEBUG] Received %d equipped items to initialize",
            equippedItems and
            (function()
                local count = 0; for _ in pairs(equippedItems) do count = count + 1 end; return count
            end)() or 0))

    if equippedItems then
        for slotId, itemInstance in pairs(equippedItems) do
            if itemInstance then
                Logger.info("equipment_gameplay_controller.debug.equipped_item",
                    string.format("[DEBUG] Slot '%s' has item: %s (instanceId: %s)",
                        tostring(slotId),
                        tostring(itemInstance.itemBaseId),
                        tostring(itemInstance.instanceId)))
            else
                Logger.info("equipment_gameplay_controller.debug.empty_slot",
                    string.format("[DEBUG] Slot '%s' is empty (nil)", tostring(slotId)))
            end
        end
    else
        Logger.warn("equipment_gameplay_controller.debug.no_equipped_items",
            "[DEBUG] No equipped items table provided")
    end

    for slotId, itemInstance in pairs(equippedItems) do
        self.equippedItems[slotId] = itemInstance
    end

    -- Dispara um evento inicial para garantir que todos os sistemas
    -- comecem com o estado correto do equipamento.
    self:_dispatchEquipmentChangedEvent()
    self:_dispatchBonusesUpdatedEvent()
end

--- Equipa um item em um slot específico, substituindo o que estiver lá.
---@param slotId string O slot onde o item será equipado.
---@param itemInstance ItemInstance|nil A instância do item a ser equipado, ou nil para desequipar.
function EquipmentGameplayController:equipItem(slotId, itemInstance)
    local oldItem = self.equippedItems[slotId]
    self.equippedItems[slotId] = itemInstance

    Logger.info(
        "equipment_gameplay_controller.equip",
        string.format("[EquipmentGameplayController:equipItem] Slot '%s' changed.", slotId)
    )

    -- Dispara os eventos para notificar o resto do sistema sobre a mudança.
    self:_dispatchEquipmentChangedEvent(slotId, itemInstance, oldItem)
    self:_dispatchBonusesUpdatedEvent()
end

--- Dispara um evento genérico notificando que o equipamento mudou.
---@param slotId string|nil O slot específico que mudou.
---@param newItem ItemInstance|nil O novo item no slot.
---@param oldItem ItemInstance|nil O item antigo que estava no slot.
function EquipmentGameplayController:_dispatchEquipmentChangedEvent(slotId, newItem, oldItem)
    Logger.info("equipment_gameplay_controller.dispatchEquipmentChangedEvent",
        "[EquipmentGameplayController:_dispatchEquipmentChangedEvent] Dispatching event...")
    self.eventService:emit(self.eventService.EVENTS.EQUIPMENT_CHANGED, {
        slotId = slotId, -- Se for nil, significa uma atualização geral inicial.
        newItem = newItem,
        oldItem = oldItem,
        allEquipped = self.equippedItems
    })
end

--- Coleta os bônus de todos os itens equipados e dispara um evento.
function EquipmentGameplayController:_dispatchBonusesUpdatedEvent()
    ---@type StatModifier[]
    local allModifiers = {}

    for _, itemInstance in pairs(self.equippedItems) do
        if itemInstance then
            local baseItemData = self.itemDataManager:getBaseItemData(itemInstance.itemBaseId)
            if baseItemData then
                -- Adiciona os modificadores explícitos da lista 'modifiers'
                if baseItemData.modifiers then
                    for _, modifier in ipairs(baseItemData.modifiers) do
                        table.insert(allModifiers, modifier)
                    end
                end

                -- Adiciona o dano base da arma como um modificador FLAT
                if baseItemData.damage then
                    table.insert(allModifiers, {
                        stat = "damage",
                        type = "FLAT",
                        value = baseItemData.damage
                    })
                end
            end
        end
    end

    Logger.info("equipment_gameplay_controller.dispatchBonusesUpdatedEvent",
        "[EquipmentGameplayController:_dispatchBonusesUpdatedEvent] Dispatching event...")
    self.eventService:emit(self.eventService.EVENTS.EQUIPMENT_BONUSES_UPDATED, {
        modifiers = allModifiers
    })

    Logger.info("equipment_gameplay_controller.bonuses",
        string.format("[EquipmentGameplayController:_dispatchBonusesUpdatedEvent] Dispatched %d stat modifiers.",
            #allModifiers)
    )
end

function EquipmentGameplayController:destroy()
    -- Este controller não tem ouvintes de eventos, então não precisa de limpeza.
end

return EquipmentGameplayController
