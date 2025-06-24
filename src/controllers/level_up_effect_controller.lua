--------------------------------------------------------------------------
-- Controller para gerenciar os efeitos visuais e de gameplay do level up
--------------------------------------------------------------------------

local CombatHelpers = require("src.utils.combat_helpers")
local LevelUpEffect = require("src.effects.level_up_effect")
local TablePool = require("src.utils.table_pool")

---@class LevelUpEffectController
---@field playerManager PlayerManager
---@field isActive boolean
---@field levelUpEffect LevelUpEffect|nil
---@field knockbackApplied boolean
---@field onCompleteCallback function|nil
local LevelUpEffectController = {}
LevelUpEffectController.__index = LevelUpEffectController

--- Cria uma nova instância do LevelUpEffectController.
---@param playerManager PlayerManager
---@return LevelUpEffectController
function LevelUpEffectController:new(playerManager)
    local instance = setmetatable({}, LevelUpEffectController)

    instance.playerManager = playerManager
    instance.isActive = false
    instance.levelUpEffect = nil
    instance.knockbackApplied = false
    instance.onCompleteCallback = nil

    return instance
end

--- Inicia o efeito de level up.
---@param onCompleteCallback function|nil Callback chamado quando o efeito terminar
function LevelUpEffectController:triggerLevelUpEffect(onCompleteCallback)
    if self.isActive then
        Logger.warn(
            "level_up_effect_controller.trigger.already_active",
            "[LevelUpEffectController:triggerLevelUpEffect] Efeito já está ativo, ignorando novo trigger"
        )
        return
    end

    Logger.info(
        "level_up_effect_controller.trigger.start",
        "[LevelUpEffectController:triggerLevelUpEffect] Iniciando efeito de level up"
    )

    self.isActive = true
    self.knockbackApplied = false
    self.onCompleteCallback = onCompleteCallback

    -- Cria o efeito visual
    if self.playerManager.player and self.playerManager.player.position then
        self.levelUpEffect = LevelUpEffect:new(self.playerManager.player.position)
    end

    -- Aplica o knockback imediatamente
    self:applyLevelUpKnockback()
end

--- Aplica knockback em área baseado no pickupRadius do player.
function LevelUpEffectController:applyLevelUpKnockback()
    if self.knockbackApplied or not self.playerManager.player then
        return
    end

    local finalStats = self.playerManager:getCurrentFinalStats()
    local knockbackRadius = finalStats.pickupRadius
    local playerPosition = self.playerManager.player.position

    Logger.debug(
        "level_up_effect_controller.knockback.radius",
        string.format(
            "[LevelUpEffectController:applyLevelUpKnockback] Aplicando knockback em raio de %.1f pixels",
            knockbackRadius
        )
    )

    -- Encontra inimigos na área
    local enemiesInArea = CombatHelpers.findEnemiesInCircularArea(
        playerPosition,
        knockbackRadius,
        self.playerManager.player
    )

    if #enemiesInArea > 0 then
        Logger.info(
            "level_up_effect_controller.knockback.enemies_found",
            string.format(
                "[LevelUpEffectController:applyLevelUpKnockback] Encontrados %d inimigos para knockback",
                #enemiesInArea
            )
        )

        -- Aplica knockback uniforme a todos os inimigos
        for i = 1, #enemiesInArea do
            local enemy = enemiesInArea[i]
            if enemy and enemy.isAlive then
                -- Knockback forte e uniforme (ignora resistência)
                local dx = enemy.position.x - playerPosition.x
                local dy = enemy.position.y - playerPosition.y
                local distance = math.sqrt(dx * dx + dy * dy)

                if distance > 0 then
                    local dirX = dx / distance
                    local dirY = dy / distance

                    -- Força fixa de knockback para level up (mais forte que ataques normais)
                    local knockbackForce = 100
                    enemy:applyKnockback(dirX, dirY, knockbackForce)
                else
                    -- Se estão na mesma posição, empurra em direção aleatória
                    local randomAngle = math.random() * 2 * math.pi
                    local dirX = math.cos(randomAngle)
                    local dirY = math.sin(randomAngle)
                    enemy:applyKnockback(dirX, dirY, 300)
                end
            end
        end
    end

    TablePool.release(enemiesInArea)
    self.knockbackApplied = true
end

--- Atualiza o controller.
---@param dt number
function LevelUpEffectController:update(dt)
    if not self.isActive then
        return
    end

    -- Atualiza o efeito visual
    if self.levelUpEffect then
        self.levelUpEffect:update(dt)

        -- Verifica se o efeito terminou
        if self.levelUpEffect.isFinished then
            self:finishEffect()
        end
    else
        -- Se não há efeito visual, termina imediatamente
        self:finishEffect()
    end
end

--- Finaliza o efeito e chama o callback.
function LevelUpEffectController:finishEffect()
    Logger.info(
        "level_up_effect_controller.finish.complete",
        "[LevelUpEffectController:finishEffect] Efeito de level up finalizado"
    )

    self.isActive = false
    self.levelUpEffect = nil
    self.knockbackApplied = false

    -- Chama o callback se existir
    if self.onCompleteCallback then
        self.onCompleteCallback()
        self.onCompleteCallback = nil
    end
end

--- Coleta renderáveis para o pipeline de renderização.
---@param renderPipeline RenderPipeline
function LevelUpEffectController:collectRenderables(renderPipeline)
    if self.isActive and self.levelUpEffect then
        self.levelUpEffect:collectRenderables(renderPipeline)
    end
end

--- Verifica se o efeito está ativo.
---@return boolean
function LevelUpEffectController:isEffectActive()
    return self.isActive
end

return LevelUpEffectController
