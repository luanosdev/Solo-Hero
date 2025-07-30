local MathUtils = require("src.utils.math_utils")

---@class BaseEntityForCulling
---@description Interface esperada pelas entidades para o sistema de culling.
---@field position {x: number, y: number} Posição da entidade no mundo.
---@field size number|nil Tamanho da entidade (usado como largura e altura se presente).
---@field radius number|nil Raio da entidade (convertido para dimensões quadradas se presente).
---@field id number|nil ID da entidade (usado para debug).

---@class CullingController
---@description Realiza a lógica de culling (seleção de objetos visíveis) usando AABB de forma stateless.
local CullingController = {}
CullingController.__index = CullingController

--- Cria uma nova instância do CullingController.
---@return CullingController
function CullingController:new()
    local instance = setmetatable({}, CullingController)
    return instance
end

--- Verifica se uma entidade está dentro da área visível usando Culling por Interseção de Bounding Box (AABB).
--- Este método é mais preciso que o culling por raio, especialmente para objetos retangulares.
--- Mantém suporte completo para mapas toroidais (infinitos).
---@param entity BaseEnemy|BaseEntityForCulling A entidade a ser verificada.
---@param cameraData {x: number, y: number, w: number, h: number} Dados da câmera (posição e dimensões).
---@param worldDimensions {w: number, h: number} Dimensões do mundo em pixels.
---@param margin? number Uma margem extra (em pixels) para adicionar à área de visão.
---@return boolean
function CullingController:isInView(entity, cameraData, worldDimensions, margin)
    margin = margin or 0

    local worldW, worldH = worldDimensions.w, worldDimensions.h
    if not worldW or worldH <= 0 then
        return true
    end

    -- Determina as dimensões da entidade
    local entityWidth, entityHeight
    if entity.size then
        entityWidth = entity.size
        entityHeight = entity.size
    elseif entity.radius then
        entityWidth = entity.radius * 2
        entityHeight = entity.radius * 2
    else
        entityWidth = 32
        entityHeight = 32
    end

    -- Define o retângulo da entidade
    local entityRect = {
        x = entity.position.x,
        y = entity.position.y,
        w = entityWidth,
        h = entityHeight,
    }

    -- Define o retângulo da área visível (câmera + margem)
    -- Usa uma margem extra baseada no tamanho da entidade para compensar a precisão do AABB
    local extraMargin = entityWidth * 0.5
    local totalMargin = margin + extraMargin

    local viewRect = {
        x = cameraData.x + cameraData.w / 2,
        y = cameraData.y + cameraData.h / 2,
        w = cameraData.w + (totalMargin * 2),
        h = cameraData.h + (totalMargin * 2),
    }

    -- Usa interseção AABB toroidal para verificar se a entidade está visível
    local result = MathUtils.rectangleIntersectionToroidal(entityRect, viewRect, worldW, worldH)

    return result
end

function CullingController:destroy()
end

return CullingController
