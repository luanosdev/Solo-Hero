local Constants = require("src.config.constants")

---@class GameStateManager
--------------------------------------------------------------------------------
-- Gerencia o estado global da cena de gameplay, como pausa e execução.
--
-- Responsabilidades:
-- 1. Centralizar o estado de 'pausa' do jogo.
-- 2. Lidar com múltiplas solicitações de pausa através de um contador.
-- 3. Implementar um delay ao despausar para suavizar o retorno à ação.
--------------------------------------------------------------------------------
---@field context GameplaySceneContext Contexto da cena de gameplay.
---@field state string Estado atual da máquina de estados ('RUNNING', 'PAUSED', 'UNPAUSING_DELAY').
---@field pauseRequestCount number Contador de quantas fontes solicitaram a pausa.
---@field unpauseTimer number Timer para o delay antes de despausar.
---@field eventListeners table<string, EventListenerIdentifier> Listeners de eventos.
local GameStateManager = {}
GameStateManager.__index = GameStateManager

-- Constantes de estado para clareza
GameStateManager.STATE = {
    RUNNING = "RUNNING",
    PAUSED = "PAUSED",
    UNPAUSING_DELAY = "UNPAUSING_DELAY"
}

---Cria uma nova instância do GameStateManager.
---@param context GameplaySceneContext
---@return GameStateManager
function GameStateManager:new(context)
    local instance = setmetatable({}, GameStateManager)

    instance.context = context
    instance.state = GameStateManager.STATE.RUNNING
    instance.pauseRequestCount = 0
    instance.unpauseTimer = 0
    instance.eventListeners = {}

    return instance
end

---Inicializa o manager, subscrevendo aos eventos necessários.
function GameStateManager:init()
    self:_listenEvents()
    Logger.info("GameStateManager:init", "[GameStateManager: init] GameStateManager inicializado.")
end

---Atualiza o estado do manager (principalmente o timer de delay).
---@param dt number Delta time.
function GameStateManager:update(dt)
    if self.state == GameStateManager.STATE.UNPAUSING_DELAY then
        self.unpauseTimer = self.unpauseTimer - dt
        if self.unpauseTimer <= 0 then
            self.state = GameStateManager.STATE.RUNNING
            Logger.info("GameStateManager:update", "[GameStateManager: update] Jogo despausado após delay.")
        end
    end
end

---Verifica se o jogo está pausado.
---@return boolean True se o jogo não estiver no estado 'RUNNING'.
function GameStateManager:isPaused()
    return self.state ~= GameStateManager.STATE.RUNNING
end

--------------------------------------------------------------------------------
-- Private Methods
--------------------------------------------------------------------------------

---@private Inscreve o manager nos eventos necessários.
function GameStateManager:_listenEvents()
    local eventService = self.context.serviceLocator:getEventService()
    self:_listen(eventService.EVENTS.REQUEST_GAME_PAUSE, self._onRequestPause)
    self:_listen(eventService.EVENTS.REQUEST_GAME_UNPAUSE, self._onRequestUnpause)
end

---Lida com uma solicitação para pausar o jogo.
function GameStateManager:_onRequestPause()
    self.pauseRequestCount = self.pauseRequestCount + 1

    if self.state ~= GameStateManager.STATE.PAUSED then
        self.state = GameStateManager.STATE.PAUSED
        -- Cancela qualquer timer de unpause que possa estar ativo
        self.unpauseTimer = 0

        Logger.info("GameStateManager:_onRequestPause",
            "[GameStateManager: _onRequestPause] Jogo pausado. Requisições: " .. self.pauseRequestCount)
    end
end

---Lida com uma solicitação para despausar o jogo.
function GameStateManager:_onRequestUnpause()
    self.pauseRequestCount = math.max(0, self.pauseRequestCount - 1)
    if self.pauseRequestCount == 0 and self.state == GameStateManager.STATE.PAUSED then
        self.state = GameStateManager.STATE.UNPAUSING_DELAY
        self.unpauseTimer = Constants.GAMEPLAY_CONFIG.UNPAUSE_DELAY_SECONDS
        Logger.info(
            "GameStateManager:_onRequestUnpause",
            "[GameStateManager: _onRequestUnpause] Última requisição de pausa liberada. Iniciando delay para despausar..."
        )
    end
end

---@private Registra um listener de evento.
---@param event string Nome do evento.
---@param callback function Callback para o evento.
function GameStateManager:_listen(event, callback)
    local eventService = self.context.serviceLocator:getEventService()
    local listener = eventService:on(event, function(...)
        callback(self, ...)
    end)
    table.insert(self.eventListeners, listener)
end

---@public Destrói o GameStateManager.
function GameStateManager:destroy()
    local eventService = self.context.serviceLocator:getEventService()
    for _, listener in ipairs(self.eventListeners) do
        eventService:off(listener)
    end
    self.eventListeners = {}
end

return GameStateManager
