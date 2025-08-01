---@class TimerData
---@field interval number O intervalo em segundos para execução.
---@field timer number O contador de tempo atual.
---@field callback function A função a ser chamada.

---@class GameTimerService
---@description Um serviço global para gerenciar o tempo da sessão de gameplay e timers recorrentes.
---@field currentTime number O tempo total da sessão de jogo.
---@field _isRunning boolean
---@field _isPaused boolean
---@field timers table<string, TimerData> Um registro de todos os timers ativos.
---@field nextTimerId number Um contador para gerar IDs de timer únicos.
local GameTimerService = {}
GameTimerService.__index = GameTimerService

---@return GameTimerService
function GameTimerService:new()
    local instance = setmetatable({}, GameTimerService)
    instance.currentTime = 0
    instance._isRunning = false
    instance._isPaused = false
    instance.timers = {}
    instance.nextTimerId = 1
    return instance
end

--- Inicia ou reseta o timer principal da sessão.
function GameTimerService:start()
    self.currentTime = 0
    self._isRunning = true
    self._isPaused = false
    self.timers = {} -- Limpa timers antigos ao iniciar uma nova sessão
    Logger.info("game_timer_service.start.success", "[GameTimerService] Session timer started and old timers cleared.")
end

--- Para completamente o timer da sessão e todos os timers agendados.
function GameTimerService:stop()
    self._isRunning = false
    self.timers = {} -- Limpa todos os timers
    Logger.info("game_timer_service.stop.success", "[GameTimerService] Session timer stopped and all timers cleared.")
end

--- Pausa o timer da sessão e todos os timers agendados.
function GameTimerService:pause()
    if self:isRunning() and not self:isPaused() then
        self._isPaused = true
        Logger.info("game_timer_service.pause.success", "[GameTimerService] Session timer and all timers paused.")
    end
end

--- Retoma o timer da sessão e todos os timers agendados.
function GameTimerService:resume()
    if self:isRunning() and self:isPaused() then
        self._isPaused = false
        Logger.info("game_timer_service.resume.success", "[GameTimerService] Session timer and all timers resumed.")
    end
end

--- Retorna o tempo de jogo atual em segundos.
---@return number
function GameTimerService:getTime()
    return self.currentTime
end

--- Retorna se o timer está rodando (não parado).
---@return boolean
function GameTimerService:isRunning()
    return self._isRunning
end

--- Retorna se o timer está pausado.
---@return boolean
function GameTimerService:isPaused()
    return self._isPaused
end

--- Adiciona um timer que executa uma função repetidamente.
---@param interval number O intervalo em segundos entre as execuções.
---@param callback function A função a ser chamada.
---@return string timerId O ID do timer, para poder removê-lo posteriormente.
function GameTimerService:addRecurringTimer(interval, callback)
    assert(type(interval) == "number" and interval > 0, "Timer interval must be a positive number.")
    assert(type(callback) == "function", "Timer callback must be a function.")

    local timerId = tostring(self.nextTimerId)
    self.nextTimerId = self.nextTimerId + 1

    self.timers[timerId] = {
        interval = interval,
        timer = interval, -- Inicia o contador com o intervalo para a primeira execução
        callback = callback
    }
    Logger.debug("game_timer_service.add_timer",
        string.format("Timer adicionado com ID %s e intervalo %s.", timerId, interval))
    return timerId
end

--- Remove um timer agendado.
---@param timerId string O ID do timer a ser removido.
function GameTimerService:removeTimer(timerId)
    if timerId and self.timers[timerId] then
        self.timers[timerId] = nil
        Logger.debug("game_timer_service.remove_timer", string.format("Timer com ID %s removido.", timerId))
    end
end

--- Atualiza o timer. DEVE ser chamado no love.update(dt) principal.
---@param dt number
function GameTimerService:update(dt)
    if not self:isRunning() or self:isPaused() then
        return
    end

    -- Atualiza o tempo principal da sessão
    self.currentTime = self.currentTime + dt

    -- Atualiza todos os timers agendados
    for id, timer in pairs(self.timers) do
        timer.timer = timer.timer - dt
        if timer.timer <= 0 then
            timer.callback()
            -- Adiciona o intervalo ao invés de resetar para evitar "drift" de tempo
            timer.timer = timer.timer + timer.interval
        end
    end
end

return GameTimerService
