-- profiler.lua
local profiler = {}
profiler.__index = profiler

function profiler.start()
    profiler.times = {}
    profiler.startTime = os.clock()
    profiler.running = true
end

function profiler.stop()
    profiler.endTime = os.clock()
    profiler.running = false
end

function profiler.hook(event)
    if not profiler.running then return end
    local info = debug.getinfo(2, "nS")
    if not info.name then return end
    local name = string.format("%s:%s", info.short_src, info.name)
    profiler.times[name] = (profiler.times[name] or 0) + 1
end

function profiler.report(filename)
    local f = io.open(filename, "w")
    f:write("Profiler Report\n\n")
    f:write(string.format("Total time: %.4f sec\n\n", profiler.endTime - profiler.startTime))
    f:write(string.format("%-40s %s\n", "Function", "Calls"))
    f:write(string.rep("-", 50) .. "\n")
    for k, v in pairs(profiler.times) do
        f:write(string.format("%-40s %d\n", k, v))
    end
    f:close()
end

debug.sethook(profiler.hook, "c")

return profiler
