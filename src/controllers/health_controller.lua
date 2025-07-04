-------------------------------------------------------------------------
-- Controlador para gerenciar a saúde do jogador.
-- Responsável por regeneração de vida, dano recebido e invencibilidade.
-------------------------------------------------------------------------

local Constants = require("src.config.constants")
local Colors = require("src.ui.colors")
local TablePool = require("src.utils.table_pool")

---@class HealthController
---@field playerManager PlayerManager Referência ao PlayerManager
---@field lastDamageTime number Timestamp do último dano recebido
---@field lastRegenTime number Timer para regeneração de vida
---@field regenInterval number Intervalo de regeneração em segundos
---@field accumulatedRegen number HP acumulado para regeneração
---@field isInvincible boolean Estado de invencibilidade do jogador
---@field lastDamageSource any|nil Última fonte de dano recebida
---@field hasReceivedDamage boolean Se o jogador já recebeu dano alguma vez
local HealthController = {}
HealthController.__index = HealthController

--- Cria uma nova instância do HealthController.
---@param playerManager PlayerManager A instância do PlayerManager
---@return HealthController
function HealthController:new(playerManager)
    Logger.debug(
        "health_controller.new",
        "[HealthController:new] Inicializando controlador de saúde"
    )

    local instance = setmetatable({}, HealthController)

    instance.playerManager = playerManager
    instance.lastDamageTime = 0
    instance.lastRegenTime = 0
    instance.regenInterval = 1.0  -- Intervalo de regeneração em segundos
    instance.accumulatedRegen = 0 -- HP acumulado para regeneração
    instance.isInvincible = false
    instance.lastDamageSource = nil
    instance.hasReceivedDamage = false -- Flag para controlar se já recebeu dano

    return instance
end

--- Atualiza o sistema de regeneração de vida
---@param dt number Delta time
function HealthController:update(dt)
    if not self.playerManager:isAlive() then
        return
    end

    self:updateHealthRecovery(dt)
end

--- Atualiza a lógica de recuperação de vida do jogador
---@param dt number Delta time
function HealthController:updateHealthRecovery(dt)
    if not self.playerManager.stateController then return end

    -- Só permite regeneração se o jogador já tiver tomado dano pelo menos uma vez
    if not self.hasReceivedDamage then
        return
    end

    local finalStats = self.playerManager:getCurrentFinalStats()
    local finalMaxHealth = finalStats.health
    local finalHealthRegenPerSecond = finalStats.healthPerTick

    if self.playerManager.gameTime >= self.lastDamageTime + finalStats.healthRegenDelay then
        self.lastRegenTime = self.lastRegenTime + dt

        if self.lastRegenTime >= self.regenInterval then
            self.lastRegenTime = self.lastRegenTime - self.regenInterval
            self.accumulatedRegen = self.accumulatedRegen + finalHealthRegenPerSecond
            local healAmount = math.floor(self.accumulatedRegen)

            if healAmount >= 1 and self.playerManager.stateController.currentHealth < finalMaxHealth then
                local healedAmount = self.playerManager.stateController:heal(healAmount)
                self.accumulatedRegen = self.accumulatedRegen - healedAmount

                if healedAmount > 0 then
                    -- Registra estatísticas
                    if self.playerManager.gameStatisticsManager then
                        self.playerManager.gameStatisticsManager:registerHealthRecovered(healedAmount)
                    end

                    -- Adiciona texto flutuante
                    local playerPosition = self.playerManager:getPlayerPosition()
                    if playerPosition then
                        local props = TablePool.getGeneric()
                        props.textColor = Colors.heal
                        props.scale = 1.1
                        props.velocityY = -30
                        props.lifetime = 1.0
                        props.baseOffsetY = -40
                        props.baseOffsetX = 0
                        self.playerManager:addFloatingText("+" .. healedAmount .. " HP", props)
                        TablePool.releaseGeneric(props)
                    end
                end
            end
        end
    else
        self.lastRegenTime = 0
        self.accumulatedRegen = 0
    end
end

--- Aplica dano ao jogador
---@param amount number A quantidade bruta de dano a ser aplicada
---@param source table|nil A fonte do dano
---@return number actualDamage O dano real infligido após defesas
function HealthController:receiveDamage(amount, source)
    if not self.playerManager:isAlive() then
        return 0
    end

    if self.isInvincible then
        return 0
    end

    -- Atualiza a fonte do último dano
    if source then
        self.lastDamageSource = source
    end

    local damageTaken = self.playerManager.stateController:takeDamage(amount)
    local reducedAmount = amount - damageTaken

    if damageTaken > 0 then
        -- Marca que o jogador já recebeu dano (habilita regeneração)
        self.hasReceivedDamage = true

        -- Registra estatísticas
        if self.playerManager.gameStatisticsManager then
            self.playerManager.gameStatisticsManager:registerDamageTaken(damageTaken, reducedAmount)
        end

        -- Reseta timers de regeneração
        self.lastDamageTime = self.playerManager.gameTime
        self.lastRegenTime = 0
        self.accumulatedRegen = 0

        -- Adiciona texto flutuante de dano
        local props = TablePool.getGeneric()
        props.textColor = Colors.damage_player
        props.scale = 1.1
        props.velocityY = -45
        props.lifetime = 0.9
        props.isCritical = false
        props.baseOffsetY = -40
        props.baseOffsetX = 0
        self.playerManager:addFloatingText("-" .. tostring(damageTaken), props)
        TablePool.releaseGeneric(props)

        Logger.debug(
            "health_controller.damage.taken",
            string.format("[HealthController:receiveDamage] Jogador tomou %.2f de dano.", damageTaken)
        )
    end

    -- Verifica se o jogador morreu
    if not self.playerManager:isAlive() then
        self:handlePlayerDeath()
    end

    return damageTaken
end

--- Lida com a morte do jogador
function HealthController:handlePlayerDeath()
    Logger.info(
        "health_controller.death",
        string.format(
            "[HealthController:handlePlayerDeath] Jogador '%s' MORREU.",
            self.playerManager.currentHunterId or "Desconhecido"
        )
    )

    -- Para o movimento do jogador
    if self.playerManager.movementController then
        self.playerManager.movementController:stopMovement()
        Logger.debug("health_controller.death.movement_stopped", "Movimento do jogador parado devido à morte.")
    end

    -- Chama o callback de morte se existir
    if self.playerManager.onPlayerDiedCallback then
        Logger.debug("health_controller.death.callback", "Chamando onPlayerDiedCallback.")
        self.playerManager.onPlayerDiedCallback()
    else
        Logger.warn("health_controller.death.no_callback", "Jogador morreu, mas onPlayerDiedCallback não está definido.")
    end
end

--- Define o estado de invencibilidade
---@param isInvincible boolean Estado de invencibilidade
function HealthController:setInvincible(isInvincible)
    self.isInvincible = isInvincible
    Logger.debug(
        "health_controller.invincibility",
        string.format("[HealthController:setInvincible] Invencibilidade definida para: %s", tostring(isInvincible))
    )
end

--- Verifica se o jogador está invencível
---@return boolean
function HealthController:isPlayerInvincible()
    return self.isInvincible
end

--- Obtém a última fonte de dano
---@return any|nil
function HealthController:getLastDamageSource()
    return self.lastDamageSource
end

--- Força a parada da regeneração (útil para testes ou mecânicas especiais)
function HealthController:stopRegeneration()
    self.lastRegenTime = 0
    self.accumulatedRegen = 0
    Logger.debug("health_controller.regen.stopped", "[HealthController:stopRegeneration] Regeneração parada manualmente")
end

return HealthController
