local ServiceLocator = require("src.core.service_locator")
local Constants = require("src.config.constants")

---@class WeaponAttackController
---@description Gerencia a habilidade de ataque ativa baseada na arma equipada.
--- Ouve o evento EQUIPMENT_CHANGED e carrega/descarrega a instância
--- da habilidade de ataque correspondente.
---@field eventService EventService
---@field itemDataService ItemDataService
---@field attackInstance BaseAttackAbility|nil A instância da habilidade de ataque ativa.
---@field eventListeners table
local WeaponAttackController = {}
WeaponAttackController.__index = WeaponAttackController

function WeaponAttackController:new()
    local instance = setmetatable({}, WeaponAttackController)
    instance.eventService = ServiceLocator.get("eventService")
    instance.itemDataService = ServiceLocator.get("itemDataService")
    instance.attackInstance = nil
    instance.eventListeners = {}
    return instance
end

function WeaponAttackController:init()
    Logger.info("weapon_attack_controller.init", "[WeaponAttackController:init] Initializing...")
    self:_registerEventListeners()
end

--- Registra o ouvinte para o evento de mudança de equipamento.
function WeaponAttackController:_registerEventListeners()
    local listener = self.eventService:on(
        self.eventService.EVENTS.EQUIPMENT_CHANGED,
        function(data) self:_onEquipmentChanged(data) end
    )
    table.insert(self.eventListeners, listener)
end

--- Lida com a mudança de equipamento, atualizando a habilidade de ataque.
---@param data {slotId: string|nil, newItem: ItemInstance|nil, allEquipped: table}
function WeaponAttackController:_onEquipmentChanged(data)
    -- Se o evento não especificou um slot, usamos a atualização geral.
    local weaponItem
    if data.slotId and data.slotId ~= Constants.SLOT_IDS.WEAPON then
        return -- A mudança não foi na arma, então ignoramos.
    end

    weaponItem = data.allEquipped[Constants.SLOT_IDS.WEAPON]
    self:_setActiveAttackAbility(weaponItem)
end

--- Configura a nova habilidade de ataque baseada no item da arma.
---@param weaponItemInstance ItemInstance|nil
function WeaponAttackController:_setActiveAttackAbility(weaponItemInstance)
    -- Limpa a habilidade de ataque anterior.
    if self.attackInstance and self.attackInstance.destroy then
        self.attackInstance:destroy()
    end
    self.attackInstance = nil

    if not weaponItemInstance then
        Logger.info(
            "weapon_attack_controller.unequip",
            "[WeaponAttackController] Weapon unequipped, attack ability cleared."
        )
        return
    end

    local itemData = self.itemDataService:getBaseItemData(weaponItemInstance.itemBaseId)
    if not (itemData and itemData.attackAbility) then
        Logger.warn("weapon_attack_controller.no_ability",
            string.format("[WeaponAttackController] Weapon '%s' has no 'attackAbility' defined.",
                weaponItemInstance.itemBaseId)
        )
        return
    end

    local abilityPath = string.format("src.entities.attacks.player.%s", itemData.attackAbility)
    local success, AbilityClass = pcall(require, abilityPath)

    if success and AbilityClass then
        self.attackInstance = AbilityClass:new(weaponItemInstance)
        Logger.info(
            "weapon_attack_controller.ability_loaded",
            string.format("[WeaponAttackController] Loaded attack ability: %s", itemData.attackAbility)
        )
    else
        Logger.error(
            "weapon_attack_controller.load_fail",
            string.format("[WeaponAttackController] Failed to load attack ability '%s'. Error: %s", abilityPath,
                tostring(AbilityClass)
            )
        )
    end
end

--- Atualiza a instância de ataque, se houver.
---@param dt number
function WeaponAttackController:update(dt)
    if self.attackInstance then
        self.attackInstance:update(dt)
    end
end

--- Executa o ataque da habilidade ativa.
---@param attackArgs table|nil
function WeaponAttackController:performAttack(attackArgs)
    if self.attackInstance and self.attackInstance.cast then
        self.attackInstance:cast(attackArgs)
        return true
    end
    return false
end

--- Coleta renderizáveis da habilidade de ataque.
---@param renderPipeline RenderPipeline
function WeaponAttackController:collectRenderables(renderPipeline)
    if self.attackInstance and self.attackInstance.collectRenderables then
        self.attackInstance:collectRenderables(renderPipeline)
    end
end

function WeaponAttackController:destroy()
    Logger.info("weapon_attack_controller.destroy", "[WeaponAttackController:destroy] Destroying...")
    for _, listener in ipairs(self.eventListeners) do
        self.eventService:off(listener.event, listener.id)
    end
    if self.attackInstance and self.attackInstance.destroy then
        self.attackInstance:destroy()
    end
end

return WeaponAttackController
