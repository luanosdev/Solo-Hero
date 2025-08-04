local SpritesheetEffect = require("src.effects.spritesheet_effect")
local TablePool = require("src.utils.table_pool")
local Constants = require("src.config.constants")
local EventService = require("src.services.event_service")
local LevelUpData = require("src.data.effects.level_up_data")

---@class LevelUpManager
--------------------------------------------------------------------------------
-- LevelUpManager (Scene-Specific)
-- Orquestra o processo de level up do jogador durante a gameplay.
--------------------------------------------------------------------------------
---@field context GameplaySceneContext
---@field effectData table Dados de configuração para o efeito visual.
---@field levelUpQueue table<number, table> Fila de level ups pendentes
---@field currentState string Estado atual da máquina de estados
---@field activeEffect SpritesheetEffect|nil O efeito visual ativo
---@field waitTimer number Timer para o intervalo entre level ups
---@field waitDuration number Duração do intervalo
---@field eventListeners EventListenerIdentifier[] Tabela para armazenar os listeners de eventos
local LevelUpManager = {}
LevelUpManager.__index = LevelUpManager

LevelUpManager.STATES = {
    IDLE = "idle",
    EFFECT_PLAYING = "effect_playing",
    AWAITING_MODAL = "awaiting_modal",
    WAITING = "waiting",
}

---@public Cria uma nova instância do LevelUpManager.
---@param context GameplaySceneContext
---@return LevelUpManager
function LevelUpManager:new(context)
    assert(context, "[LevelUpManager] missing a GameplayContext")

    local instance = setmetatable({}, LevelUpManager)
    instance.context = context
    instance.effectData = nil -- Será carregado no :init()
    instance.levelUpQueue = {}
    instance.currentState = LevelUpManager.STATES.IDLE
    instance.activeEffect = nil
    instance.eventListeners = {}
    instance.waitTimer = 0
    instance.waitDuration = Constants.GAMEPLAY_CONFIG.LEVEL_INTERVAL_BETWEEN_LEVEL_UPS

    Logger.info("level_up_manager.new", "[LevelUpManager] Instância criada.")
    return instance
end

---@public Inicializa o manager, carregando dados e registrando eventos.
function LevelUpManager:init()
    self.effectData = LevelUpData

    -- Carrega as imagens do efeito uma vez
    local assetService = self.context.serviceLocator:getAssetService()
    self.effectData.baseImage = assetService:getImage(self.effectData.baseImagePath)
    self.effectData.overlayImage = assetService:getImage(self.effectData.overlayImagePath)

    self:_registerEventListeners()
    Logger.info("level_up_manager.init", "[LevelUpManager] Inicializado e pronto.")
end

---@private Registra os listeners de eventos.
function LevelUpManager:_registerEventListeners()
    self:_listen(EventService.EVENTS.PLAYER_LEVELED_UP, self.onPlayerLeveledUp)
    self:_listen(EventService.EVENTS.LEVEL_UP_MODAL_CLOSED, self.onLevelUpModalClosed)
end

--- Manipulador para o evento de level up do jogador.
---@param eventData PlayerLeveledUpEventData
function LevelUpManager:onPlayerLeveledUp(eventData)
    assert(eventData, "[LevelUpManager] missing eventData")
    assert(eventData.levelsGained, "[LevelUpManager] missing levelsGained")

    Logger.info(
        "level_up_manager.event.received",
        string.format("[LevelUpManager] Recebido evento de level up! Níveis ganhos: %d", eventData.levelsGained)
    )

    for _ = 1, eventData.levelsGained do
        table.insert(self.levelUpQueue, {}) -- Adiciona uma "tarefa" para cada nível ganho
    end

    if self.currentState == LevelUpManager.STATES.IDLE then
        self:processNextInQueue()
    end
end

--- Chamado quando o modal de level up é fechado.
function LevelUpManager:onLevelUpModalClosed()
    if self.currentState == LevelUpManager.STATES.AWAITING_MODAL then
        Logger.info("level_up_manager.modal_closed", "[LevelUpManager] Modal fechado, continuando a fila.")
        self.currentState = LevelUpManager.STATES.WAITING -- Inicia o período de espera
    end
end

--- Processa o próximo item da fila de level up.
function LevelUpManager:processNextInQueue()
    if #self.levelUpQueue == 0 then
        self.currentState = LevelUpManager.STATES.IDLE
        Logger.info("level_up_manager.queue.empty", "[LevelUpManager] Fila de level ups vazia.")
        return
    end

    table.remove(self.levelUpQueue, 1)
    self.currentState = LevelUpManager.STATES.EFFECT_PLAYING

    Logger.info(
        "level_up_manager.queue.processing",
        string.format("[LevelUpManager] Processando level up. Restantes na fila: %d", #self.levelUpQueue)
    )

    self:triggerEffect()
end

--- Dispara o efeito visual e o knockback.
function LevelUpManager:triggerEffect()
    local playerManager = self.context.registry:getPlayerManager()
    local playerPosition = playerManager:getPosition()

    -- Monta a configuração final para o efeito
    local pickupRadius = playerManager.stateController:getStat("pickupRadius")
    local knockbackRadiusPixels = Constants.metersToPixels(pickupRadius)

    ---@type SpritesheetEffectConfig
    local effectConfig = {
        position = playerPosition,
        baseImage = self.effectData.baseImage,
        overlayImage = self.effectData.overlayImage,
        grid = self.effectData.grid,
        frameDuration = self.effectData.frameDuration,
        tint = self.effectData.tint,
        overlayTint = self.effectData.overlayTint,
    }

    self.activeEffect = SpritesheetEffect:new(effectConfig)
    self:applyKnockback(playerPosition, knockbackRadiusPixels)
end

--- Aplica knockback em área ao redor do jogador.
---@param center Vector2D O centro da área de knockback.
---@param radius number O raio da área de knockback em pixels.
function LevelUpManager:applyKnockback(center, radius)
    local playerManager = self.context.registry:getPlayerManager()
    local enemyManager = self.context.registry:getEnemyManager()

    local candidates = enemyManager:getNearbyEnemies(center, radius)
    local enemiesHit = playerManager.areaOfEffectController:findEntitiesInCircle(candidates, center, radius)

    if #enemiesHit > 0 then
        Logger.info("level_up_manager.knockback.found",
            string.format("[LevelUpManager] %d inimigos atingidos pelo knockback.", #enemiesHit))

        for _, enemy in ipairs(enemiesHit) do
            local dx, dy = enemy.position.x - center.x, enemy.position.y - center.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance > 0 then
                enemy:applyKnockback(dx / distance, dy / distance, Constants.GAMEPLAY_CONFIG.LEVEL_UP_KNOCKBACK_FORCE)
            else
                local randomAngle = math.random() * 2 * math.pi
                enemy:applyKnockback(
                    math.cos(randomAngle),
                    math.sin(randomAngle),
                    Constants.GAMEPLAY_CONFIG.LEVEL_UP_KNOCKBACK_FORCE
                )
            end
        end
    end

    TablePool.releaseArray(candidates)
    TablePool.releaseArray(enemiesHit)
end

--- Atualiza a máquina de estados.
---@param dt number Delta time.
function LevelUpManager:update(dt)
    if self.currentState == LevelUpManager.STATES.EFFECT_PLAYING then
        if self.activeEffect and not self.activeEffect.isFinished then
            self.activeEffect:update(dt)
        else
            self:finishEffect()
        end
    elseif self.currentState == LevelUpManager.STATES.WAITING then
        self.waitTimer = self.waitTimer + dt
        if self.waitTimer >= self.waitDuration then
            self.waitTimer = 0
            self.currentState = LevelUpManager.STATES.IDLE
            self:processNextInQueue()
        end
    end
end

--- Finaliza o efeito, solicita o modal e transita para o estado de espera.
function LevelUpManager:finishEffect()
    self.activeEffect = nil
    self.currentState = LevelUpManager.STATES.AWAITING_MODAL

    local eventService = self.context.serviceLocator:getEventService()
    eventService:emit(EventService.EVENTS.REQUEST_LEVEL_UP_MODAL)

    Logger.info("level_up_manager.effect.finished", "[LevelUpManager] Efeito finalizado, solicitando modal.")
end

--- Coleta os renderizáveis do efeito ativo.
---@param renderPipeline RenderPipeline
function LevelUpManager:collectRenderables(renderPipeline)
    if self.activeEffect then
        self.activeEffect:collectRenderables(renderPipeline)
    end
end

---@private Registra um listener de evento de forma segura.
---@param event string Nome do evento.
---@param callback function Callback para o evento.
function LevelUpManager:_listen(event, callback)
    local eventService = self.context.serviceLocator:getEventService()
    local listener = eventService:on(event, function(...)
        callback(self, ...)
    end)
    table.insert(self.eventListeners, listener)
end

--- Encerra o manager, removendo os listeners.
function LevelUpManager:destroy()
    local eventService = self.context.serviceLocator:getEventService()
    for _, listener in ipairs(self.eventListeners) do
        eventService:off(listener)
    end

    self.eventListeners = {}
    Logger.info("level_up_manager.destroy", "[LevelUpManager] Encerrado.")
end

return LevelUpManager
