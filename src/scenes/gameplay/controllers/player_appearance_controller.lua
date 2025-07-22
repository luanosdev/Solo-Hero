local ServiceLocator = require("src.core.service_locator")
local Constants = require("src.config.constants")
local SpritePlayer = require("src.animations.sprite_player")

---@class PlayerAppearanceController
---@description Gerencia a aparência visual do jogador baseada no equipamento.
--- Ouve o evento EQUIPMENT_CHANGED e atualiza o sprite do jogador.
---@field eventService EventService
---@field itemDataService ItemDataService
---@field playerEntity table A referência para a entidade do jogador (para o SpritePlayer).
---@field eventListeners table
local PlayerAppearanceController = {}
PlayerAppearanceController.__index = PlayerAppearanceController

function PlayerAppearanceController:new(playerEntity)
    local instance = setmetatable({}, PlayerAppearanceController)
    instance.eventService = ServiceLocator.get("eventService")
    instance.itemDataService = ServiceLocator.get("itemDataService")
    instance.playerEntity = playerEntity
    instance.eventListeners = {}
    return instance
end

function PlayerAppearanceController:init()
    Logger.info("player_appearance_controller.init", "[PlayerAppearanceController:init] Initializing...")
    self:_registerEventListeners()
end

--- Registra o ouvinte para o evento de mudança de equipamento.
function PlayerAppearanceController:_registerEventListeners()
    local listener = self.eventService:on(
        self.eventService.EVENTS.EQUIPMENT_CHANGED,
        function(data) self:_onEquipmentChanged(data) end
    )
    table.insert(self.eventListeners, listener)
end

--- Lida com a mudança de equipamento, atualizando a aparência do jogador.
---@param data {allEquipped: table<string, ItemInstance>}
function PlayerAppearanceController:_onEquipmentChanged(data)
    if not self.playerEntity then return end

    local weaponItem = data.allEquipped[Constants.SLOT_IDS.WEAPON]
    local appearance = { weapon = {} }

    if weaponItem then
        local itemData = self.itemDataService:getBaseItemData(weaponItem.itemBaseId)
        if itemData then
            appearance.weapon = {
                folderPath = itemData.animationFolderPath or "sword_tier_1",
                animationType = itemData.animationType or "melee"
            }
            Logger.info("player_appearance_controller.update",
                string.format("[PlayerAppearanceController] Updating weapon appearance to: %s",
                    itemData.animationFolderPath)
            )
        end
    else
        Logger.info("player_appearance_controller.update", "[PlayerAppearanceController] Removing weapon appearance.")
    end

    -- TODO: Adicionar lógica para outros equipamentos (armadura, etc.) aqui.

    SpritePlayer.setAppearance(self.playerEntity, appearance)
end

function PlayerAppearanceController:destroy()
    Logger.info("player_appearance_controller.destroy", "[PlayerAppearanceController:destroy] Destroying...")
    for _, listener in ipairs(self.eventListeners) do
        self.eventService:off(listener.event, listener.id)
    end
end

return PlayerAppearanceController
