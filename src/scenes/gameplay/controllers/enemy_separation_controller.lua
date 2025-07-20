---@class EnemySeparationController
---@description Aplica forças de separação para evitar que inimigos se sobreponham.
local EnemySeparationController = {}
EnemySeparationController.__index = EnemySeparationController

function EnemySeparationController:new()
    local instance = setmetatable({}, EnemySeparationController)
    return instance
end

function EnemySeparationController:init()
    Logger.info("enemy_separation_controller.init.success",
        "[EnemySeparationController:init] Enemy Separation Controller initialized.")
end

function EnemySeparationController:destroy()
    Logger.info("enemy_separation_controller.destroy.success",
        "[EnemySeparationController:destroy] Enemy Separation Controller destroyed.")
end

return EnemySeparationController
