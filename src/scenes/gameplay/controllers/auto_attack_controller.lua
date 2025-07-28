local ActionTypes = require("src.types.action_types")

---@class AutoAttackController
---@description Gerencia o estado de "auto-ataque" (ligado/desligado).
---@field autoAttackEnabled boolean
---@field inputService InputService
local AutoAttackController = {}
AutoAttackController.__index = AutoAttackController

---@public
---@param inputService InputService
---@return AutoAttackController
function AutoAttackController:new(inputService)
    local instance = setmetatable({}, AutoAttackController)

    instance.autoAttackEnabled = true
    instance.inputService = inputService

    return instance
end

---@public Inicializa o AutoAttackController.
function AutoAttackController:init()
    Logger.info("auto_attack_controller.init", "[AutoAttackController:init] Inicializando AutoAttackController")
end

---@public
--- Apenas um placeholder, a lógica de checagem é feita pelo PlayerManager.
function AutoAttackController:update()
    if self.inputService:wasActionPressed(ActionTypes.TOGGLE_AUTO_ATTACK) then
        self:toggleAutoAttack()
    end
    -- No futuro, pode conter lógica de cooldown/timer para o auto-ataque.
end

---@public
--- Define o estado do auto-ataque.
---@param enabled boolean
function AutoAttackController:setAutoAttackEnabled(enabled)
    self.autoAttackEnabled = enabled
    Logger.info("auto_attack_controller.set.attack",
        string.format("[AutoAttackController:setAutoAttackEnabled] Auto-attack definido para: %s", tostring(enabled))
    )
end

---@public
--- Alterna o estado do auto-ataque.
function AutoAttackController:toggleAutoAttack()
    self:setAutoAttackEnabled(not self.autoAttackEnabled)
end

---@public
--- Verifica se o auto-ataque está habilitado.
---@return boolean
function AutoAttackController:isAutoAttackEnabled()
    Logger.debug("auto_attack_controller.isAutoAttackEnabled",
        "[AutoAttackController:isAutoAttackEnabled] Auto-attack está " .. tostring(self.autoAttackEnabled))
    return self.autoAttackEnabled
end

---@public
function AutoAttackController:destroy()
    Logger.info("auto_attack_controller.destroy", "[AutoAttackController:destroy] Destruído.")
end

return AutoAttackController
