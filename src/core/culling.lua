--- @class Culling
local Culling = {}

--- Verifica se uma entidade está dentro da viewport + margem opcional
---@param entity table Deve ter .position {x, y} e opcionalmente .radius
---@param camX number
---@param camY number
---@param screenW number
---@param screenH number
---@param margin number (opcional) - margem além da tela
---@return boolean
function Culling.isInView(entity, camX, camY, screenW, screenH, margin)
    local cullRadius = (entity.radius or 0) + (margin or 200)
    local posX, posY = entity.position.x, entity.position.y

    return
        (posX + cullRadius) > camX and
        (posX - cullRadius) < (camX + screenW) and
        (posY + cullRadius) > camY and
        (posY - cullRadius) < (camY + screenH)
end

--- Verifica se uma entidade está completamente FORA da viewport + margem opcional
---@param entity table
---@param camX number
---@param camY number
---@param screenW number
---@param screenH number
---@param margin number (opcional)
---@return boolean
function Culling.isOffScreen(entity, camX, camY, screenW, screenH, margin)
    return not Culling.isInView(entity, camX, camY, screenW, screenH, margin)
end

--- Verifica se um ponto (x, y) está dentro da viewport + margem
---@param x number
---@param y number
---@param camX number
---@param camY number
---@param screenW number
---@param screenH number
---@param margin number (opcional)
---@return boolean
function Culling.pointInView(x, y, camX, camY, screenW, screenH, margin)
    margin = margin or 200
    return
        (x + margin) > camX and
        (x - margin) < (camX + screenW) and
        (y + margin) > camY and
        (y - margin) < (camY + screenH)
end

return Culling
