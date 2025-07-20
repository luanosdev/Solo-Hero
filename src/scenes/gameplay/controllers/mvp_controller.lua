---@class MVPController
---@description Encapsula a lógica de transformar inimigos em "MVPs".
local MVPController = {}
MVPController.__index = MVPController

function MVPController:new()
    local instance = setmetatable({}, MVPController)
    return instance
end

function MVPController:init()
    Logger.info("mvp_controller.init.success", "[MVPController:init] MVP Controller initialized.")
end

function MVPController:destroy()
    Logger.info("mvp_controller.destroy.success", "[MVPController:destroy] MVP Controller destroyed.")
end

return MVPController
