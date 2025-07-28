local CombatGeometry = require("src.utils.combat_geometry")
local TablePool = require("src.utils.table_pool")

---@class AreaOfEffectController
---@description Um controller especializado em realizar consultas espaciais de combate (queries).
--- Recebe uma lista de candidatos (e.g., inimigos) e uma área de efeito (círculo, cone, etc.)
--- e retorna uma lista filtrada de entidades que estão dentro dessa área.
--- Este controller é sem estado (stateless) em relação ao mundo do jogo e não deve
--- conter referências diretas a managers.
local AreaOfEffectController = {}
AreaOfEffectController.__index = AreaOfEffectController

---@return AreaOfEffectController
function AreaOfEffectController:new()
    local instance = setmetatable({}, AreaOfEffectController)
    return instance
end

---@public Inicializa o AreaOfEffectController.
function AreaOfEffectController:init()
    Logger.info("area_of_effect_controller.init", "[AreaOfEffectController:init] Inicializando AreaOfEffectController")
end

---@public Filtra uma lista de entidades, retornando apenas aquelas dentro de uma área circular.
--- A verificação de colisão é permissiva, considerando o raio da entidade.
---@param candidates BaseEnemy[] A lista de entidades candidatas a serem verificadas.
---@param circleCenter Vector2D O centro da área circular.
---@param circleRadius number O raio da área circular.
---@return BaseEnemy[] Uma nova lista (do TablePool) contendo apenas as entidades atingidas.
function AreaOfEffectController:findEntitiesInCircle(candidates, circleCenter, circleRadius)
    local entitiesHit = TablePool.getArray()
    if not candidates or #candidates == 0 or not circleRadius or circleRadius <= 0 then
        return entitiesHit
    end

    for i = 1, #candidates do
        local entity = candidates[i]
        if entity and entity.isAlive then
            -- Verificação permissiva: raio do ataque + raio da entidade.
            local combinedRadius = circleRadius + (entity.radius or 0)
            if CombatGeometry.isPointInCircle(entity.position, circleCenter, combinedRadius) then
                table.insert(entitiesHit, entity)
            end
        end
    end

    return entitiesHit
end

---@public Filtra uma lista de entidades, retornando apenas aquelas dentro de uma área de cone.
--- A verificação de colisão é permissiva, considerando o raio da entidade.
---@param candidates BaseEnemy[] A lista de entidades candidatas a serem verificadas.
---@param coneOrigin Vector2D A origem do cone.
---@param coneAngle number O ângulo central do cone em radianos.
---@param coneRange number O alcance (comprimento) do cone.
---@param coneHalfWidth number Metade da largura angular do cone em radianos.
---@return BaseEnemy[] Uma nova lista (do TablePool) contendo apenas as entidades atingidas.
function AreaOfEffectController:findEntitiesInCone(candidates, coneOrigin, coneAngle, coneRange, coneHalfWidth)
    local entitiesHit = TablePool.getArray()
    if not candidates or #candidates == 0 or not coneRange or coneRange <= 0 then
        return entitiesHit
    end

    for i = 1, #candidates do
        local entity = candidates[i]
        if entity and entity.isAlive then
            -- Verificação de distância permissiva
            local combinedRange = coneRange + (entity.radius or 0)
            local dx = entity.position.x - coneOrigin.x
            local dy = entity.position.y - coneOrigin.y
            local distanceSq = dx * dx + dy * dy

            if distanceSq <= (combinedRange * combinedRange) then
                -- Se estiver no alcance, verifica o ângulo
                if CombatGeometry.isPointInCone(entity.position, coneOrigin, coneAngle, combinedRange, coneHalfWidth) then
                    table.insert(entitiesHit, entity)
                end
            end
        end
    end

    return entitiesHit
end

---@public Filtra uma lista de entidades, retornando apenas aquelas dentro de uma área de linha.
---@param candidates BaseEnemy[] A lista de entidades candidatas.
---@param lineStart Vector2D Posição inicial da linha.
---@param lineEnd Vector2D Posição final da linha.
---@param lineWidth number Largura da linha.
---@return BaseEnemy[] Uma nova lista (do TablePool) com as entidades atingidas.
function AreaOfEffectController:findEntitiesInLine(candidates, lineStart, lineEnd, lineWidth)
    local entitiesHit = TablePool.getArray()
    if not candidates or #candidates == 0 or not lineWidth or lineWidth <= 0 then
        return entitiesHit
    end

    for i = 1, #candidates do
        local entity = candidates[i]
        if entity and entity.isAlive then
            local entityRadius = entity.radius or 0
            if CombatGeometry.isPointInLineArea(entity.position, entityRadius, lineStart, lineEnd, lineWidth) then
                table.insert(entitiesHit, entity)
            end
        end
    end

    return entitiesHit
end

return AreaOfEffectController
