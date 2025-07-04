--------------------------------------------------------------------------
-- Controller para gerenciar os efeitos visuais e de gameplay do level up
--------------------------------------------------------------------------

local CombatHelpers = require("src.utils.combat_helpers")
local LevelUpEffect = require("src.effects.level_up_effect")
local TablePool = require("src.utils.table_pool")
local Constants = require("src.config.constants")

---@class LevelUpEffectController
---@field playerManager PlayerManager
---@field isActive boolean
---@field levelUpEffect LevelUpEffect|nil
---@field knockbackApplied boolean
---@field onCompleteCallback function|nil
---@field levelUpQueue table
---@field currentState string
---@field waitTimer number
---@field waitDuration number
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

    -- Sistema de filas
    instance.levelUpQueue = {}
    instance.currentState = "idle" -- idle, effect_playing, modal_shown, waiting
    instance.waitTimer = 0
    instance.waitDuration = 0.5

    Logger.debug(
        "level_up_effect_controller.new.queue_init",
        "[LevelUpEffectController:new] Sistema de filas inicializado com delay de 0.5s"
    )

    return instance
end

--- Adiciona um level up à fila ou inicia imediatamente se não há fila.
---@param onCompleteCallback function|nil Callback chamado quando o efeito terminar
function LevelUpEffectController:triggerLevelUpEffect(onCompleteCallback)
    -- Adiciona à fila
    table.insert(self.levelUpQueue, {
        callback = onCompleteCallback
    })

    Logger.info(
        "level_up_effect_controller.queue.add",
        string.format("[LevelUpEffectController:triggerLevelUpEffect] Level up adicionado à fila. Total: %d",
            #self.levelUpQueue)
    )

    -- Se não está processando, inicia a sequência
    if self.currentState == "idle" then
        self:processNextLevelUp()
    end
end

--- Processa o próximo level up da fila.
function LevelUpEffectController:processNextLevelUp()
    if #self.levelUpQueue == 0 then
        self.currentState = "idle"
        Logger.debug(
            "level_up_effect_controller.queue.empty",
            "[LevelUpEffectController:processNextLevelUp] Fila vazia, retornando ao estado idle"
        )
        return
    end

    if self.currentState ~= "idle" then
        Logger.warn(
            "level_up_effect_controller.queue.busy",
            "[LevelUpEffectController:processNextLevelUp] Controlador ocupado, aguardando"
        )
        return
    end

    local levelUpData = table.remove(self.levelUpQueue, 1)
    self.onCompleteCallback = levelUpData.callback
    self.currentState = "effect_playing"

    Logger.info(
        "level_up_effect_controller.queue.process",
        string.format("[LevelUpEffectController:processNextLevelUp] Processando level up. Restantes: %d",
            #self.levelUpQueue)
    )

    self.isActive = true
    self.knockbackApplied = false

    -- Cria o efeito visual
    local playerPosition = self.playerManager:getPlayerPosition()
    if playerPosition then
        self.levelUpEffect = LevelUpEffect:new(playerPosition)
    end

    -- Aplica o knockback imediatamente
    self:applyLevelUpKnockback()
end

--- Aplica knockback em área baseado no pickupRadius do player.
function LevelUpEffectController:applyLevelUpKnockback()
    if self.knockbackApplied then
        return
    end

    local finalStats = self.playerManager:getCurrentFinalStats()
    local knockbackRadius = Constants.metersToPixels(finalStats.pickupRadius)
    local playerPosition = self.playerManager:getPlayerPosition()

    Logger.debug(
        "level_up_effect_controller.knockback.radius",
        string.format(
            "[LevelUpEffectController:applyLevelUpKnockback] Aplicando knockback em raio de %.1f pixels (%.1f metros)",
            knockbackRadius,
            finalStats.pickupRadius
        )
    )

    -- Encontra inimigos na área
    local enemiesInArea = CombatHelpers.findEnemiesInCircularArea(
        playerPosition,
        knockbackRadius,
        self.playerManager:getPlayerSprite()
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
    -- Atualiza o timer de espera
    if self.currentState == "waiting" then
        self.waitTimer = self.waitTimer + dt
        if self.waitTimer >= self.waitDuration then
            self.waitTimer = 0
            self.currentState = "idle"
            self:processNextLevelUp()
        end
        return
    end

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
    self.currentState = "modal_shown"

    -- Chama o callback se existir (mostra o modal) mas NÃO continua automaticamente
    if self.onCompleteCallback then
        Logger.debug(
            "level_up_effect_controller.modal.show",
            "[LevelUpEffectController:finishEffect] Mostrando modal e aguardando fechamento"
        )

        -- Passa uma função para ser chamada quando o modal for fechado
        local originalCallback = self.onCompleteCallback
        self.onCompleteCallback = nil

        if not originalCallback then
            error("LevelUpEffectController:finishEffect - Callback não definido")
        end

        -- Chama o callback original passando uma função de continuação
        originalCallback(function()
            self:onModalClosed()
        end)
    else
        -- Se não há callback, vai direto para o próximo
        self.currentState = "idle"
        self:processNextLevelUp()
    end
end

--- Chamado quando o modal é fechado para continuar a sequência.
function LevelUpEffectController:onModalClosed()
    Logger.debug(
        "level_up_effect_controller.modal.closed",
        "[LevelUpEffectController:onModalClosed] Modal fechado, iniciando espera"
    )

    self:startWaitPeriod()
end

--- Inicia o período de espera após mostrar o modal.
function LevelUpEffectController:startWaitPeriod()
    self.currentState = "waiting"
    self.waitTimer = 0

    Logger.debug(
        "level_up_effect_controller.wait.start",
        string.format("[LevelUpEffectController:startWaitPeriod] Iniciando espera de %.1fs antes do próximo efeito",
            self.waitDuration)
    )
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

--- Verifica se há level ups na fila.
---@return boolean
function LevelUpEffectController:hasQueuedLevelUps()
    return #self.levelUpQueue > 0
end

--- Obtém o número de level ups na fila.
---@return number
function LevelUpEffectController:getQueueSize()
    return #self.levelUpQueue
end

--- Obtém o estado atual do controller.
---@return string
function LevelUpEffectController:getCurrentState()
    return self.currentState
end

--- Força o processamento do próximo level up (para debug/testes).
function LevelUpEffectController:forceNextLevelUp()
    if self.currentState == "waiting" then
        self.waitTimer = self.waitDuration
        Logger.debug(
            "level_up_effect_controller.force.next",
            "[LevelUpEffectController:forceNextLevelUp] Forçando próximo level up"
        )
    end
end

return LevelUpEffectController
