----------------------------------------------------------------------------
-- Attack Animation System
-- Sistema unificado de animação para todas as habilidades de ataque.
-- Gerencia instâncias de animação com pooling e performance otimizada.
----------------------------------------------------------------------------

local TablePool = require("src.utils.table_pool")

---@class AttackAnimationSystem
local AttackAnimationSystem = {}

-- Pool de instâncias de animação para reutilização
local animationInstancePool = {}

---@class AnimationInstance
---@field progress number Progresso da animação (0-1)
---@field duration number Duração total da animação
---@field delay number Delay antes de iniciar
---@field data table Dados específicos da animação
---@field isActive boolean Se a animação está ativa
---@field type string Tipo da animação

--- Cria ou reutiliza uma instância de animação
---@param animationType string Tipo da animação
---@param duration number Duração da animação
---@param delay number Delay antes de iniciar
---@param data table Dados específicos da animação
---@return AnimationInstance
function AttackAnimationSystem.createInstance(animationType, duration, delay, data)
    local instance

    if #animationInstancePool > 0 then
        -- Reutiliza do pool
        instance = table.remove(animationInstancePool)
        instance.progress = 0
        instance.duration = duration
        instance.delay = delay or 0
        instance.type = animationType
        instance.isActive = true

        -- Limpa dados antigos e aplica novos
        for k in pairs(instance.data) do
            instance.data[k] = nil
        end
        if data then
            for k, v in pairs(data) do
                instance.data[k] = v
            end
        end
    else
        -- Cria nova instância
        instance = {
            progress = 0,
            duration = duration,
            delay = delay or 0,
            type = animationType,
            isActive = true,
            data = data and TablePool.get() or {}
        }

        if data then
            for k, v in pairs(data) do
                instance.data[k] = v
            end
        end
    end

    return instance
end

--- Atualiza uma instância de animação
---@param instance AnimationInstance
---@param dt number Delta time
---@return boolean isComplete Se a animação terminou
function AttackAnimationSystem.updateInstance(instance, dt)
    if not instance.isActive then
        return true
    end

    -- Processa delay primeiro
    if instance.delay > 0 then
        instance.delay = instance.delay - dt
        return false
    end

    -- Atualiza progresso
    instance.progress = instance.progress + (dt / instance.duration)

    if instance.progress >= 1 then
        instance.isActive = false
        return true
    end

    return false
end

--- Libera uma instância de animação de volta para o pool
---@param instance AnimationInstance
function AttackAnimationSystem.releaseInstance(instance)
    if not instance then return end

    instance.isActive = false
    instance.progress = 0
    instance.delay = 0
    instance.type = nil

    -- Libera dados se veio do TablePool
    if instance.data then
        TablePool.release(instance.data)
        instance.data = {}
    end

    table.insert(animationInstancePool, instance)
end

--- Sistema de atualização em lote para múltiplas animações
---@param animations AnimationInstance[] Lista de animações
---@param dt number Delta time
---@return number removedCount Número de animações removidas
function AttackAnimationSystem.updateBatch(animations, dt)
    local removedCount = 0

    for i = #animations, 1, -1 do
        local animation = animations[i]
        local isComplete = AttackAnimationSystem.updateInstance(animation, dt)

        if isComplete then
            AttackAnimationSystem.releaseInstance(animation)
            table.remove(animations, i)
            removedCount = removedCount + 1
        end
    end

    return removedCount
end

--- Utilitários para diferentes tipos de animação

--- Cria snapshot de área para animações de cone/área
---@param area table Área original
---@return table areaSnapshot
function AttackAnimationSystem.createAreaSnapshot(area)
    return {
        position = { x = area.position.x, y = area.position.y },
        angle = area.angle,
        range = area.range,
        angleWidth = area.angleWidth,
        halfWidth = area.halfWidth
    }
end

--- Cria dados para animação de cone alternado
---@param area table Área do cone
---@param hitLeft boolean Se ataca o lado esquerdo
---@return table animationData
function AttackAnimationSystem.createConeData(area, hitLeft)
    return {
        area = AttackAnimationSystem.createAreaSnapshot(area),
        hitLeft = hitLeft
    }
end

--- Cria dados para animação circular
---@param position table Posição do centro
---@param radius number Raio da área
---@return table animationData
function AttackAnimationSystem.createCircularData(position, radius)
    return {
        center = { x = position.x, y = position.y },
        radius = radius
    }
end

--- Calcula progresso de shell/onda para animações
---@param progress number Progresso base (0-1)
---@param playerRadius number Raio do jogador
---@param maxRange number Alcance máximo
---@param shellWidth number Largura da shell
---@return number shellInner, number shellOuter, boolean isValid
function AttackAnimationSystem.calculateShellProgress(progress, playerRadius, maxRange, shellWidth)
    if progress < 0.01 then
        return 0, 0, false
    end

    local shellRadius = playerRadius + (maxRange - playerRadius) * progress
    local shellInner = math.max(playerRadius, shellRadius - shellWidth * 0.5)
    local shellOuter = math.min(maxRange, shellRadius + shellWidth * 0.5)

    return shellInner, shellOuter, shellOuter > shellInner
end

--- Função de debug para monitorar pool
function AttackAnimationSystem.getPoolInfo()
    return {
        poolSize = #animationInstancePool,
        poolCapacity = 50 -- Podemos limitar o pool se necessário
    }
end

return AttackAnimationSystem
