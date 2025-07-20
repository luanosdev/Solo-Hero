---@class FrameTaskRunner
---@description Executa uma tarefa a cada N frames.
--- Ideal para distribuir operações pesadas ao longo do tempo e evitar picos de uso de CPU.
--- @field intervalFrames number
--- @field action function
local FrameTaskRunner = {}
FrameTaskRunner.__index = FrameTaskRunner

---@alias FrameTaskRunnerConfig { intervalFrames: number, action: function }

---@param config FrameTaskRunnerConfig FrameTaskRunner config
function FrameTaskRunner:new(config)
    assert(
        config and config.intervalFrames and config.action,
        "FrameTaskRunner requires 'intervalFrames' and 'action' in config."
    )

    local instance = setmetatable({}, FrameTaskRunner)
    instance.intervalFrames = config.intervalFrames
    instance.action = config.action
    instance.frameCount = 0
    return instance
end

---Deve ser chamado a cada frame no update().
function FrameTaskRunner:update()
    self.frameCount = self.frameCount + 1
    if self.frameCount >= self.intervalFrames then
        self.frameCount = 0
        self.action() -- Executa a tarefa
    end
end

return FrameTaskRunner
