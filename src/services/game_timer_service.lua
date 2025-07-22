---@class GameTimerService
---@description Um serviço global para gerenciar o tempo da sessão de gameplay.
--- Trata o tempo como um estado da sessão, e não de uma cena específica.
---@field currentTime number
---@field _isRunning boolean
---@field _isPaused boolean
local GameTimerService = {}
GameTimerService.__index = GameTimerService

---@return GameTimerService
function GameTimerService:new()
    local instance = setmetatable({}, GameTimerService)
    instance.currentTime = 0
    instance._isRunning = false
    instance._isPaused = false
    return instance
end

--- Inicia ou reseta o timer. Deve ser chamado no início de uma nova "run".
function GameTimerService:start()
    self.currentTime = 0
    self._isRunning = true
    self._isPaused = false
    Logger.info("game_timer_service.start.success", "[GameTimerService] Session timer started.")
end

--- Para completamente o timer.
function GameTimerService:stop()
    self._isRunning = false
    Logger.info("game_timer_service.stop.success", "[GameTimerService] Session timer stopped.")
end

--- Pausa o timer, mas preserva o tempo atual.
function GameTimerService:pause()
    if self:isRunning() and not self:isPaused() then
        self._isPaused = true
        Logger.info("game_timer_service.pause.success", "[GameTimerService] Session timer paused.")
    end
end

--- Retoma o timer de onde parou.
function GameTimerService:resume()
    if self:isRunning() and self:isPaused() then
        self._isPaused = false
        Logger.info("game_timer_service.resume.success", "[GameTimerService] Session timer resumed.")
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

--- Atualiza o timer. DEVE ser chamado no love.update(dt) principal.
---@param dt number
function GameTimerService:update(dt)
    if self:isRunning() and not self:isPaused() then
        self.currentTime = self.currentTime + dt
    end
end

return GameTimerService
