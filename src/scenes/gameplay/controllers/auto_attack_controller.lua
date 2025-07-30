local ActionTypes = require("src.types.action_types")

---@class AutoAttackController
---@description Gerencia o estado de "auto-ataque" (ligado/desligado).
---@field autoAttackEnabled boolean
---@field inputService InputService
---@field isOverridden boolean
local AutoAttackController = {}
AutoAttackController.__index = AutoAttackController

---@public
---@param inputService InputService
---@return AutoAttackController
function AutoAttackController:new(inputService)
    local instance = setmetatable({}, AutoAttackController)

    instance.autoAttackEnabled = false
    instance.inputService = inputService
    instance.isOverridden = false

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
    if self.isOverridden then
        Logger.warn("auto_attack_controller.set.attack.overridden",
            "[AutoAttackController:setAutoAttackEnabled] Tentativa de alterar o estado enquanto sobreposto. Ignorado.")
        return
    end

    self.autoAttackEnabled = enabled
    Logger.info("auto_attack_controller.set.attack",
        string.format("[AutoAttackController:setAutoAttackEnabled] Auto-ataque definido para: %s", tostring(enabled))
    )
end

---@public
--- Alterna o estado do auto-ataque.
function AutoAttackController:toggleAutoAttack()
    Logger.debug("auto_attack_controller.toggle", "[AutoAttackController:toggleAutoAttack] Toggle auto attack.")
    self:setAutoAttackEnabled(not self.autoAttackEnabled)
end

---@public Sobrepõe temporariamente o estado do auto-ataque.
--- Útil para forçar o ataque ao segurar um botão, por exemplo.
---@param overridden boolean true para sobrepor, false para remover a sobreposição.
function AutoAttackController:overrideAutoAttack(overridden)
    self.isOverridden = overridden
    Logger.info("auto_attack_controller.override",
        string.format("[AutoAttackController:overrideAutoAttack] Sobreposição do auto-ataque: %s", tostring(overridden))
    )
end

---@public
--- Verifica se o auto-ataque está habilitado.
---@return boolean
function AutoAttackController:isAutoAttackEnabled()
    return self.isOverridden or self.autoAttackEnabled
end

---@public
function AutoAttackController:destroy()
    Logger.info("auto_attack_controller.destroy", "[AutoAttackController:destroy] Destruído.")
end

return AutoAttackController
