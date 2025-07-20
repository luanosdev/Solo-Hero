---@class TimerTaskRunner
---@description Executa uma tarefa repetidamente em um intervalo de tempo fixo (em segundos).
--- Ideal para lógicas de gameplay que devem ser consistentes independente do framerate.
--- @field interval number
--- @field action function
local TimerTaskRunner = {}
TimerTaskRunner.__index = TimerTaskRunner

---@alias TimerTaskRunnerConfig { interval: number, action: function }

---@param config TimerTaskRunnerConfig TimerTaskRunner config
function TimerTaskRunner:new(config)
    assert(config and config.interval and config.action, "TimerTaskRunner requires 'interval' and 'action' in config.")

    local instance = setmetatable({}, TimerTaskRunner)
    instance.interval = config.interval -- Em segundos
    instance.action = config.action     -- A função a ser executada
    instance.timer = 0
    return instance
end

---Deve ser chamado a cada frame no update(dt).
---@param dt number
function TimerTaskRunner:update(dt)
    self.timer = self.timer + dt
    if self.timer >= self.interval then
        self.timer = self.timer - self.interval
        self.action() -- Executa a tarefa
    end
end

return TimerTaskRunner
