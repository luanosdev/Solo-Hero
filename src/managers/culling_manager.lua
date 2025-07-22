local ResolutionUtils = require("src.utils.resolution_utils")
local MathUtils = require("src.utils.math_utils")

---@class CullingManager
---@description Gerencia a lógica de culling (seleção de objetos visíveis) de forma centralizada.
--- Abstrai a complexidade de obter câmera, jogador e mapa, oferecendo uma API simples.
local CullingManager = {}
CullingManager.__index = CullingManager

function CullingManager:new()
    local instance = setmetatable({}, CullingManager)

    return instance
end

---@param playerManager PlayerManager
---@param mapManager InfinityWrapMapManager
function CullingManager:init(playerManager, mapManager)
    self.playerManager = playerManager
    self.mapManager = mapManager
end

--- Verifica se uma entidade está dentro da visão da câmera, com suporte a mapas infinitos (toroidais).
--- Esta função centraliza a lógica, obtendo internamente a posição da câmera e as dimensões da tela.
---@param entity BaseEntity A entidade a ser verificada.
---@param margin? number Uma margem extra (em pixels) para adicionar à área de visão.
---@return boolean
function CullingManager:isInView(entity, margin)
    margin = margin or 0

    -- O cálculo da câmera é idêntico ao que funciona no RenderPipeline
    local playerPos = self.playerManager.movementController:getPosition()
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    local camX = playerPos.x - screenW / 2
    local camY = playerPos.y - screenH / 2

    local worldW, worldH = self.mapManager:getWorldPixelDimensions()

    if worldW <= 0 or worldH <= 0 then
        return true -- Não faz culling se o mundo não tiver dimensões
    end

    local entityX, entityY = entity.position.x, entity.position.y

    local cameraCenterX = camX + screenW / 2
    local cameraCenterY = camY + screenH / 2

    local dx = entityX - cameraCenterX
    local dy = entityY - cameraCenterY

    -- CORRIGIDO: Revertida a "otimização" que usava math.sign.
    -- Esta lógica if/else é explícita e não depende de funções que
    -- podem não existir no ambiente.
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

    local viewX1 = camX - margin
    local viewY1 = camY - margin
    local viewX2 = camX + screenW + margin
    local viewY2 = camY + screenH + margin

    return virtualEntityX >= viewX1 and virtualEntityX <= viewX2 and
        virtualEntityY >= viewY1 and virtualEntityY <= viewY2
end

function CullingManager:destroy()
    self.playerManager = nil
    self.mapManager = nil
end

return CullingManager
