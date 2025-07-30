local MathUtils = require("src.utils.math_utils")

---@class CullingController
---@description Realiza a lógica de culling (seleção de objetos visíveis) de forma stateless.
local CullingController = {}
CullingController.__index = CullingController

function CullingController:new()
    local instance = setmetatable({}, CullingController)
    return instance
end

--- Verifica se uma entidade está dentro de um raio de culling ao redor do jogador, com suporte a mapas toroidais.
--- Esta lógica é baseada na sugestão do usuário de simplificar o culling para um raio, similar ao spawn.
---@param entity BaseEntity A entidade a ser verificada.
---@param cameraData {x: number, y: number, w: number, h: number} Dados da câmera (posição e dimensões).
---@param worldDimensions {w: number, h: number} Dimensões do mundo em pixels.
---@param margin? number Uma margem extra (em pixels) para adicionar à área de visão.
---@return boolean
function CullingController:isInView(entity, cameraData, worldDimensions, margin)
    margin = margin or 0

    local worldW, worldH = worldDimensions.w, worldDimensions.h
    if not worldW or worldW <= 0 then return true end

    -- O jogador está sempre no centro da câmera.
    local playerX = cameraData.x + cameraData.w / 2
    local playerY = cameraData.y + cameraData.h / 2

    local entityX, entityY = entity.position.x, entity.position.y

    -- Calcula a menor distância vetorial entre o jogador e a entidade no mundo toroidal.
    local dx = math.abs(entityX - playerX)
    local dy = math.abs(entityY - playerY)
    local shortestDistX = math.min(dx, worldW - dx)
    local shortestDistY = math.min(dy, worldH - dy)

    -- Calcula a distância real (ao quadrado para performance) a partir do vetor de menor distância.
    local distanceSq = shortestDistX * shortestDistX + shortestDistY * shortestDistY

    -- O raio de culling é a distância do centro da tela até um dos cantos, mais a margem.
    -- Isso garante que tudo na tela seja incluído.
    local cullRadius = MathUtils.vectorLength(cameraData.w / 2, cameraData.h / 2) + margin
    local cullRadiusSq = cullRadius * cullRadius

    return distanceSq <= cullRadiusSq
end

function CullingController:destroy()
end

return CullingController
