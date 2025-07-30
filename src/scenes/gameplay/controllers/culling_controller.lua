---@class CullingController
---@description Realiza a lógica de culling (seleção de objetos visíveis) de forma stateless.
--- Este controller não possui estado e recebe todos os dados necessários por parâmetro.
local CullingController = {}
CullingController.__index = CullingController

function CullingController:new()
    local instance = setmetatable({}, CullingController)
    return instance
end

--- Verifica se uma entidade está dentro da visão da câmera, com suporte a mapas infinitos (toroidais).
---@param entity BaseEntity A entidade a ser verificada.
---@param cameraData {x: number, y: number, w: number, h: number} Dados da câmera (posição e dimensões).
---@param worldDimensions {w: number, h: number} Dimensões do mundo em pixels.
---@param margin? number Uma margem extra (em pixels) para adicionar à área de visão.
---@return boolean
function CullingController:isInView(entity, cameraData, worldDimensions, margin)
    margin = margin or 0

    local worldW, worldH = worldDimensions.w, worldDimensions.h
    if worldW <= 0 or worldH <= 0 then
        return true -- Não faz culling se o mundo não tiver dimensões
    end

    local entityX, entityY = entity.position.x, entity.position.y

    local cameraCenterX = cameraData.x + cameraData.w / 2
    local cameraCenterY = cameraData.y + cameraData.h / 2

    local dx = entityX - cameraCenterX
    local dy = entityY - cameraCenterY

    -- Lógica para mapa toroidal (infinito)
    if math.abs(dx) > worldW / 2 then
        if dx > 0 then
            dx = dx - worldW
        else
            dx = dx + worldW
        end
    end
    if math.abs(dy) > worldH / 2 then
        if dy > 0 then
            dy = dy - worldH
        else
            dy = dy + worldH
        end
    end

    local virtualEntityX = cameraCenterX + dx
    local virtualEntityY = cameraCenterY + dy

    local viewX1 = cameraData.x - margin
    local viewY1 = cameraData.y - margin
    local viewX2 = cameraData.x + cameraData.w + margin
    local viewY2 = cameraData.y + cameraData.h + margin

    return virtualEntityX >= viewX1 and virtualEntityX <= viewX2 and
        virtualEntityY >= viewY1 and virtualEntityY <= viewY2
end

-- Não há estado para limpar, então o destroy pode ser vazio ou removido.
function CullingController:destroy()
end

return CullingController
