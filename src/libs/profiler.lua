-- profiler.lua
local profiler = {}
profiler.__index = profiler

local active = false
local times = {}
local callStack = {}
local startTime = 0
local endTime = 0

function profiler.start()
    times = {}
    callStack = {}
    startTime = os.clock()
    endTime = 0
    active = true
    debug.sethook(profiler.hook, "cr")
end

function profiler.stop()
    debug.sethook()
    endTime = os.clock()
    active = false
end

function profiler.hook(event)
    local info = debug.getinfo(2, "nS")
    if not info then return end

    local name = info.name or info.namewhat or "[anon]"
    local src = info.short_src or "[C]"
    local linedefined = info.linedefined or 0

    -- Cria uma chave mais robusta
    local key = string.format("%s:%s:%d", src, name, linedefined)

    if event == "call" then
        local t = os.clock()
        table.insert(callStack, {key = key, start = t})
    elseif event == "return" then
        local t = os.clock()
        local frame = table.remove(callStack)

        if frame then
            local elapsed = t - frame.start
            local data = times[frame.key] or {calls = 0, time = 0}
            data.calls = data.calls + 1
            data.time = data.time + elapsed
            times[frame.key] = data
        end
    end
end

function profiler.report(filename)
    filename = filename or "profiler_report.txt"
    local f = io.open(filename, "w")
    local totalTime = endTime - startTime

    f:write("Profiler Report\n\n")
    f:write(string.format("Total time: %.4f sec\n\n", totalTime))
    f:write(string.format("%-60s %10s %10s %10s\n", "Function", "Calls", "Time(s)", "% of Total"))
    f:write(string.rep("-", 100) .. "\n")

    -- Ordenar por tempo decrescente
    local sorted = {}
    for k, v in pairs(times) do
        table.insert(sorted, {key = k, calls = v.calls, time = v.time})
    end
    table.sort(sorted, function(a, b) return a.time > b.time end)

    for _, v in ipairs(sorted) do
        local percent = (v.time / totalTime) * 100
        f:write(string.format("%-60s %10d %10.4f %9.2f%%\n", v.key, v.calls, v.time, percent))
    end

    f:close()
end

return profiler
