local Constants = require("src.config.constants")

---@class WeaponAttackController
---@description Gerencia a habilidade de ataque ativa baseada na arma equipada.
--- Ouve o evento EQUIPMENT_CHANGED e carrega/descarrega a instância
--- da habilidade de ataque correspondente.
---@field eventService EventService
---@field itemDataService ItemDataService
---@field inputService InputService
---@field attackInstance BaseAttackAbility|nil A instância da habilidade de ataque ativa.
---@field eventListeners table
---@field isHoldingAttack boolean
local WeaponAttackController = {}
WeaponAttackController.__index = WeaponAttackController

---@public Cria uma nova instância do WeaponAttackController.
---@param eventService EventService
---@param itemDataService ItemDataService
---@param inputService InputService
---@return WeaponAttackController
function WeaponAttackController:new(eventService, itemDataService, inputService)
    local instance = setmetatable({}, WeaponAttackController)

    instance.eventService = eventService
    instance.itemDataService = itemDataService
    instance.inputService = inputService
    instance.attackInstance = nil
    instance.eventListeners = {}
    instance.isHoldingAttack = false

    return instance
end

---@public Inicializa o WeaponAttackController.
function WeaponAttackController:init()
    Logger.info("weapon_attack_controller.init", "[WeaponAttackController:init] Initializing...")
    self:_registerEventListeners()
end

---@public Atualiza a instância de ataque, se houver.
---@param dt number
---@param angle number
function WeaponAttackController:update(dt, angle)
    if self.attackInstance then
        self.attackInstance:update(dt, angle)
    end

    self:_handleAttackInput(angle)
end

---@public Desenha a instância de ataque, se houver.
--- TODO: Implementar futuramente o BatchDraw
function WeaponAttackController:collectRenderables()
    if not self.attackInstance then
        Logger.warn("weapon_attack_controller.collectRenderables",
            "[WeaponAttackController] Tentou coletar, mas self.attackInstance é nil.")
        return
    end

    if self.attackInstance.draw then
        self.attackInstance:draw()
    end
end

---@public Executa o ataque da habilidade ativa.
---@param attackArgs table
---@return boolean success True se o ataque foi executado com sucesso
function WeaponAttackController:performAttack(attackArgs)
    if self.attackInstance and self.attackInstance.cast then
        self.attackInstance:cast(attackArgs)
        return true
    end

    Logger.warn("weapon_attack_controller.performAttack",
        "[WeaponAttackController] Tentou executar ataque, mas attackInstance é nil ou não tem 'cast'.")
    return false
end

---@private
--- Lida com o input do jogador para o ataque (mouse).
---@param angle number
function WeaponAttackController:_handleAttackInput(angle)
    self.isHoldingAttack = self.inputService:isActionDown("primary_attack")

    if self.isHoldingAttack then
        local args = { angle = angle }
        self:performAttack(args)
    end
end

---@private Registra o ouvinte para o evento de mudança de equipamento.
function WeaponAttackController:_registerEventListeners()
    local listener = self.eventService:on(
        self.eventService.EVENTS.EQUIPMENT_CHANGED,
        function(data) self:_onEquipmentChanged(data) end
    )
    table.insert(self.eventListeners, listener)
end

---@private Lida com a mudança de equipamento, atualizando a habilidade de ataque.
---@param data {slotId: string|nil, newItem: ItemInstance|nil, allEquipped: table}
function WeaponAttackController:_onEquipmentChanged(data)
    Logger.info(
        "weapon_attack_controller.onEquipmentChanged",
        string.format("[WeaponAttackController] Event details - slotId: %s, newItem: %s, allEquipped: %s ",
            data.slotId,
            data.newItem and data.newItem.itemBaseId or "nil",
            data.allEquipped and data.allEquipped[Constants.SLOT_IDS.WEAPON] and
            data.allEquipped[Constants.SLOT_IDS.WEAPON].itemBaseId or "nil"
        )
    )

    if not data.slotId and data.allEquipped then
        if data.allEquipped[Constants.SLOT_IDS.WEAPON] then
            -- Sem o slot e com allEquipped, é uma atualização geral de equipamentos
            self:_setActiveAttack(data.allEquipped[Constants.SLOT_IDS.WEAPON])
            return
        end
    end

    -- Se o evento não especificou um slot, usamos a atualização geral.
    if data.slotId and data.slotId ~= Constants.SLOT_IDS.WEAPON then
        return -- A mudança não foi na arma, então ignoramos.
    end

    self:_clearAttackInstance()

    if not data.newItem then
        return
    end

    self:_setActiveAttack(data.newItem)
end

---@private Limpa a instância de ataque atual.
function WeaponAttackController:_clearAttackInstance()
    if self.attackInstance and self.attackInstance.destroy then
        self.attackInstance:destroy()
    end
    self.attackInstance = nil
end

---@private Configura a nova habilidade de ataque baseada no item da arma.
---@param weaponItemInstance table
function WeaponAttackController:_setActiveAttack(weaponItemInstance)
    local itemData = self.itemDataService:getBaseItemData(weaponItemInstance.itemBaseId)

    local attackPath = string.format("src.entities.attacks.player.%s", itemData.attackClass)
    local success, AttackClass = pcall(require, attackPath)

    if success and AttackClass then
        self.attackInstance = AttackClass:new(weaponItemInstance)
        Logger.info(
            "weapon_attack_controller.ability_loaded",
            string.format("[WeaponAttackController] Loaded attack ability: %s", itemData.attackAbility)
        )
    else
        Logger.error(
            "weapon_attack_controller.load_fail",
            string.format("[WeaponAttackController] Failed to load attack ability '%s'. Error: %s", attackPath,
                tostring(AttackClass)
            )
        )
    end
end

---@public Destrói o WeaponAttackController.
function WeaponAttackController:destroy()
    Logger.info("weapon_attack_controller.destroy", "[WeaponAttackController:destroy] Destroying...")
    for _, listener in ipairs(self.eventListeners) do
        self.eventService:off(listener.event, listener.id)
    end

    self.eventListeners = {}
    self:_clearAttackInstance()
end

return WeaponAttackController
