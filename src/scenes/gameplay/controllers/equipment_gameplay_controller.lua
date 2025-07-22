local ServiceLocator = require("src.core.service_locator")
local ItemDataManager = require("src.managers.item_data_manager")

---@class EquipmentGameplayController
---@description Gerencia o estado de todos os itens equipados pelo jogador.
--- Emite eventos quando o equipamento muda, permitindo que outros sistemas reajam
--- de forma desacoplada.
---@field eventService EventService
---@field itemDataManager ItemDataService
---@field equippedItems table<string, ItemInstance|nil>
local EquipmentGameplayController = {}
EquipmentGameplayController.__index = EquipmentGameplayController

function EquipmentGameplayController:new()
    local instance = setmetatable({}, EquipmentGameplayController)
    instance.eventService = ServiceLocator.get("eventService")
    instance.itemDataManager = ServiceLocator.get("itemDataService")
    instance.equippedItems = {}
    return instance
end

--- Inicializa o controller com os itens que o jogador já tem equipado.
---@param initialEquippedItems table<string, ItemInstance>
function EquipmentGameplayController:init(initialEquippedItems)
    Logger.info("equipment_gameplay_controller.init", "[EquipmentGameplayController:init] Initializing...")
    for slotId, itemInstance in pairs(initialEquippedItems) do
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
            if baseItemData and baseItemData.modifiers then
                for _, modifier in ipairs(baseItemData.modifiers) do
                    table.insert(allModifiers, modifier)
                end
            end
        end
    end

    self.eventService:emit(self.eventService.EVENTS.EQUIPMENT_BONUSES_UPDATED, {
        modifiers = allModifiers
    })

    Logger.info("equipment_gameplay_controller.bonuses",
        string.format("[EquipmentGameplayController:_dispatchBonuses] Dispatched %d stat modifiers.", #allModifiers)
    )
end

function EquipmentGameplayController:destroy()
    -- Este controller não tem ouvintes de eventos, então não precisa de limpeza.
end

return EquipmentGameplayController
