---@class BaseEntityForCulling
---@description Interface esperada pelas entidades para o sistema de culling.
---@field position {x: number, y: number} Posição da entidade no mundo.
---@field size number|nil Tamanho da entidade (usado como largura e altura se presente).
---@field radius number|nil Raio da entidade (convertido para dimensões quadradas se presente).
---@field id number|nil ID da entidade (usado para debug).

---@class CullingController
---@field worldDimensions {w: number, h: number} Dimensões do mundo em pixels.
---@field cameraX number
---@field cameraY number
---@description Realiza a lógica de culling (seleção de objetos visíveis) usando conversão para coordenadas de tela e testes simples.
local CullingController = {}
CullingController.__index = CullingController

--- Cria uma nova instância do CullingController.
---@return CullingController
function CullingController:new()
    local instance = setmetatable({}, CullingController)
    return instance
end

---@public Inicializa o culling controller.
---@param worldDimensions {w: number, h: number} Dimensões do mundo em pixels.
function CullingController:init(worldDimensions, cameraData)
    self.worldDimensions = worldDimensions
end

--- Verifica se uma entidade está dentro da área visível convertendo para coordenadas de tela.
--- Esta implementação é simples e eficiente, similar ao main.lua, mas suporta mapas toroidais.
---@param entity BaseEnemy|BaseEntityForCulling A entidade a ser verificada.
---@param playerPosition Vector2D Posição do player.
---@param margin? number Uma margem extra (em pixels) para adicionar à área de visão.
---@return boolean
function CullingController:isInView(entity, playerPosition, margin)
    assert(self.worldDimensions, "World dimensions not initialized")

    margin = margin or 0

    local worldW, worldH = self.worldDimensions.w, self.worldDimensions.h
    if not worldW or worldH <= 0 then
        return true
    end

    local screenW, screenH = ResolutionUtils.getGameDimensions()

    -- 1. CONVERTER COORDENADAS DE MUNDO PARA COORDENADAS RELATIVAS À CÂMERA
    local playerWorldX = playerPosition.x
    local playerWorldY = playerPosition.y

    -- Calcula o vetor mais curto em mundo toroidal (igual ao MathUtils.calculateShortestTorusVector)
    local dx = entity.position.x - playerWorldX
    local dy = entity.position.y - playerWorldY

    -- Normaliza para o caminho mais curto no mundo toroidal
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

    -- 2. CONVERTER PARA COORDENADAS DE TELA (igual ao main.lua)
    local screenX = screenW / 2 + dx
    local screenY = screenH / 2 + dy

    -- 3. TESTE SIMPLES DE BOUNDING BOX (igual ao main.lua)
    local centerX = screenW / 2
    local centerY = screenH / 2

    -- Determina as dimensões da entidade para o teste de margem
    local entityRadius = 0
    if entity.size then
        entityRadius = entity.size / 2
    elseif entity.radius then
        entityRadius = entity.radius
    else
        entityRadius = 16 -- Default radius
    end

    -- Área de culling com margem (margem fixa + raio da entidade)
    local totalMargin = margin + entityRadius
    local halfWidth = screenW / 2 + totalMargin
    local halfHeight = screenH / 2 + totalMargin

    -- Teste simples de bounding box retangular
    return screenX >= centerX - halfWidth and screenX <= centerX + halfWidth and
        screenY >= centerY - halfHeight and screenY <= centerY + halfHeight
end

function CullingController:destroy()
end

return CullingController
