---@class HealthController
---@description Gerencia o estado de vida do jogador (dano, cura, morte) e se comunica com outros sistemas via eventos.
---@field eventService EventService O serviço de eventos global.
---@field currentHealth number A vida atual do jogador.
---@field maxHealth number A vida máxima atual do jogador.
---@field isAlive boolean Se o jogador está vivo.
---@field isInvincible boolean Se o jogador está temporariamente invencível.
---@field eventListeners table<string, function> Tabela para armazenar os listeners de eventos.
local HealthController = {}
HealthController.__index = HealthController

---@public Cria uma nova instância do HealthController.
---@param eventService EventService O serviço de eventos global.
---@return HealthController
function HealthController:new(eventService)
    assert(eventService, "[HealthController:new] 'eventService' dependency is missing.")

    local instance = setmetatable({}, HealthController)

    instance.eventService = eventService

    instance.currentHealth = 0
    instance.maxHealth = 0
    instance.isAlive = true
    instance.isInvincible = false
    instance.eventListeners = {}

    return instance
end

---@public Inicializa o controller.
---@param initialMaxHealth number A vida máxima do jogador.
function HealthController:init(initialMaxHealth)
    assert(initialMaxHealth, "[HealthController:init] 'initialMaxHealth' is required.")
    Logger.info("health_controller.init.start", "[HealthController] Initializing...")

    self.maxHealth = initialMaxHealth
    self.currentHealth = initialMaxHealth

    self:_startEventListeners()

    -- Emite o estado inicial para a UI.
    self:_emitHealthUpdate()

    Logger.info(
        "health_controller.init.end",
        string.format("[HealthController:init] Initialized with %d/%d HP.", self.currentHealth, self.maxHealth)
    )
end

---@public Aplica uma quantidade de dano ao jogador.
---@param amount number A quantidade de dano a ser aplicada.
---@return boolean, number|nil `true` se o dano foi aplicado, junto com a quantidade, ou `false` se o jogador estava invencível.
function HealthController:takeDamage(amount)
    if not self.isAlive or self.isInvincible or amount <= 0 then
        return false
    end

    local finalDamage = math.floor(amount)
    self.currentHealth = self.currentHealth - finalDamage

    Logger.debug(
        "health_controller.take_damage",
        string.format(
            "[HealthController:takeDamage] Player took %d damage. HP is now %d/%d.",
            finalDamage,
            self.currentHealth,
            self.maxHealth
        )
    )

    self:_emitHealthUpdate()

    if self.currentHealth <= 0 then
        self.currentHealth = 0
        self:_die()
    end

    return true, finalDamage
end

---@public Cura o jogador por uma certa quantidade.
---@param amount number A quantidade de vida a ser restaurada.
---@return boolean, number|nil `true` se a cura foi aplicada, junto com a quantidade, ou `false` se a cura não foi aplicada.
function HealthController:heal(amount)
    if not self.isAlive or amount <= 0 then
        return false
    end

    local amountToHeal = math.floor(amount)
    local oldHealth = self.currentHealth
    self.currentHealth = math.min(self.currentHealth + amountToHeal, self.maxHealth)

    local healedAmount = self.currentHealth - oldHealth
    if healedAmount > 0 then
        Logger.debug("health_controller.heal",
            string.format("[HealthController] Player healed for %d. HP is now %d/%d.", healedAmount, self.currentHealth,
                self.maxHealth))
        self:_emitHealthUpdate()
    end

    return true, healedAmount
end

---@public Define o estado de invencibilidade do jogador.
---@param isInvincible boolean
function HealthController:setInvincible(isInvincible)
    self.isInvincible = isInvincible
end

---@private Lida com as atualizações de stats do jogador, especificamente 'maxHealth'.
---@param eventData PlayerStatUpdatedEventData Dados do evento { stat, newValue, oldValue }.
function HealthController:_onPlayerStatUpdated(eventData)
    assert(eventData, "[HealthController:_onPlayerStatUpdated] 'eventData' is required.")

    if eventData.stat == "maxHealth" then
        local oldMaxHealth = self.maxHealth
        local newMaxHealth = eventData.newValue
        self.maxHealth = newMaxHealth

        -- Cura o jogador com a diferença entre a vida máxima antiga e a nova.
        if newMaxHealth > oldMaxHealth then
            self:heal(newMaxHealth - oldMaxHealth)
        end

        -- Ajusta a vida atual proporcionalmente se o máximo de vida diminuiu.
        if self.currentHealth > newMaxHealth then
            self.currentHealth = newMaxHealth
        end


        Logger.info(
            "health_controller.max_health_changed",
            string.format("[HealthController] Max health changed from %d to %d. Current HP: %d.", oldMaxHealth,
                newMaxHealth, self.currentHealth)
        )

        self:_emitHealthUpdate()
    end
end

---@private
--- Orquestra o que acontece quando a vida do jogador chega a zero.
function HealthController:_die()
    if not self.isAlive then return end

    self.isAlive = false
    Logger.info("health_controller.death", "[HealthController] Player has died.")

    -- TODO: Adicionar dados relevantes sobre a morte, se necessário
    self.eventService:emit(self.eventService.EVENTS.PLAYER_DIED, {
        -- Adicionar dados relevantes sobre a morte, se necessário
    })
end

---@private
--- Emite o evento de atualização de vida para notificar outros sistemas (como a UI).
function HealthController:_emitHealthUpdate()
    self.eventService:emit(self.eventService.EVENTS.PLAYER_HEALTH_UPDATED, {
        current = self.currentHealth,
        max = self.maxHealth,
    })
end

---@private Inicia as instancias de eventos
function HealthController:_startEventListeners()
    self:_listen(self.eventService.EVENTS.PLAYER_STAT_UPDATED, self._onPlayerStatUpdated)
end

---@private Registra um listener de eventos.
---@param event string
---@param handler function
function HealthController:_listen(event, handler)
    local listener = self.eventService:on(event, function(data) handler(self, data) end)
    table.insert(self.eventListeners, listener)
end

--- Limpa os recursos e se desregistra de eventos para evitar memory leaks.
function HealthController:destroy()
    Logger.info("health_controller.destroy", "[HealthController] Destroying...")
    for _, listener in ipairs(self.eventListeners) do
        self.eventService:off(listener.event, listener.id)
    end
    self.eventListeners = {}
end

return HealthController
