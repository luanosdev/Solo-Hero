---@class MVPRepositionController
---@description Reposiciona MVPs e Bosses que estão muito longe do jogador.
local MVPRepositionController = {}
MVPRepositionController.__index = MVPRepositionController

function MVPRepositionController:new()
    local instance = setmetatable({}, MVPRepositionController)
    return instance
end

function MVPRepositionController:init()
    Logger.info(
        "mvp_reposition_controller.init.success",
        "[MVPRepositionController:init] MVP Reposition Controller initialized."
    )
end

function MVPRepositionController:destroy()
    Logger.info(
        "mvp_reposition_controller.destroy.success",
        "[MVPRepositionController:destroy] MVP Reposition Controller destroyed."
    )
end

return MVPRepositionController
