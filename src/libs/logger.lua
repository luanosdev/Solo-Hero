-- logger.lua - Logger completo com níveis, fundo, cores e exportação opcional

local Logger = {}

Logger.enabled = LOGGERS
Logger.logInterval = 1
Logger.timers = {}
Logger.logs = {} -- Logs para visualização na tela
Logger.showOnScreen = true
Logger.maxLines = 10
Logger.visibleLevels = { debug = true, info = true, warn = true, error = true }
Logger.saveToFile = true
Logger.logFileName = "log.txt"
Logger.printToConsole = LOGS_ON_CONSOLE
Logger.toggleKey = "'"

--- Níveis de log
--- @class LogLevel
--- @field label string
--- @field color table
local levels = {
    debug = { label = "[DEBUG]", color = { 0.5, 0.7, 1 } },
    info  = { label = "[INFO]", color = { 1, 1, 1 } },
    warn  = { label = "[WARN]", color = { 1, 1, 0 } },
    error = { label = "[ERROR]", color = { 1, 0.4, 0.4 } }
}

--- Define os níveis de log visíveis
--- @param levelTable table<string, boolean>
function Logger.setVisibleLevels(levelTable)
    Logger.visibleLevels = levelTable
end

--- Define se os logs serão salvos em um arquivo
--- @param enabled boolean
--- @param filename string?
function Logger.setSaveToFile(enabled, filename)
    Logger.saveToFile = enabled
    if filename then
        Logger.logFileName = filename
    end
end

--- Define se os logs serão impressos no console
--- @param enabled boolean
function Logger.setPrintToConsole(enabled)
    Logger.printToConsole = enabled
end

--- Registra um log
--- @param key string
--- @param message string
--- @param level string?
--- @param showOnScreen boolean?
function Logger.log(key, message, level, showOnScreen)
    if not Logger.enabled then return end
    level = level or "info"
    local now = love.timer.getTime()
    if not Logger.timers[key] or now - Logger.timers[key] >= Logger.logInterval then
        local label = levels[level] and levels[level].label or "[LOG]"
        local color = levels[level] and levels[level].color or { 1, 1, 1 }
        local entry = string.format("%s %s", label, message)

        if Logger.printToConsole then
            print(entry)
        end

        if Logger.saveToFile then
            local file = io.open(Logger.logFileName, "a")
            if file then
                file:write(entry .. "\n")
                file:close()
            end
        end

        if Logger.showOnScreen and (showOnScreen or Logger.visibleLevels[level]) then
            table.insert(Logger.logs, { text = entry, color = color })
            if #Logger.logs > Logger.maxLines then
                table.remove(Logger.logs, 1)
            end
        end

        Logger.timers[key] = now
    end
end

--- Registra um log de erro
--- @param key string
--- @param message string
--- @param showOnScreen boolean?
--- @return nil
function Logger.error(key, message, showOnScreen)
    Logger.log(key, message, "error", showOnScreen)
end

--- Registra um log de aviso
--- @param key string
--- @param message string
--- @param showOnScreen boolean?
function Logger.warn(key, message, showOnScreen)
    Logger.log(key, message, "warn", showOnScreen)
end

--- Registra um log de informação
--- @param key string
--- @param message string
--- @param showOnScreen boolean?
function Logger.info(key, message, showOnScreen)
    Logger.log(key, message, "info", showOnScreen)
end

--- Registra um log de depuração
--- @param key string
--- @param message string
--- @param showOnScreen boolean?
function Logger.debug(key, message, showOnScreen)
    Logger.log(key, message, "debug", showOnScreen)
end

--- Desenha os logs na tela
function Logger.draw()
    if not Logger.enabled or not Logger.showOnScreen then return end

    local screenWidth, screenHeight = ResolutionUtils.getGameDimensions()
    local lineHeight = 14
    local margin = 10
    local bgHeight = lineHeight * Logger.maxLines + 10
    local bgWidth = 400
    local baseY = screenHeight - bgHeight - margin
    local baseX = screenWidth - bgWidth - margin

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", baseX, baseY, bgWidth, bgHeight)

    local y = baseY + 5
    for _, log in ipairs(Logger.logs) do
        love.graphics.setColor(log.color)
        love.graphics.print(log.text, baseX + 5, y)
        y = y + lineHeight
    end

    love.graphics.setColor(1, 1, 1)
end

function Logger.disable()
    Logger.enabled = false
end

--- Alterna a visibilidade dos logs ao pressionar uma tecla
--- @param key string
function Logger.keypressed(key)
    if key == Logger.toggleKey then
        Logger.showOnScreen = not Logger.showOnScreen
    end
end

--- Debuga recursivamente uma tabela
--- @param tbl table
--- @param indent? number
function Logger.dumpTable(tbl, indent)
    indent = indent or 2
    local toprint = string.rep(" ", indent) .. "{\n"
    indent = indent + 2

    if tbl == nil then
        return "nil"
    end

    if not type(tbl) == "table" then
        return tostring(tbl)
    end

    for k, v in pairs(tbl) do
        toprint = toprint .. string.rep(" ", indent)
        if type(k) == "number" then
            toprint = toprint .. "[" .. k .. "] = "
        elseif type(k) == "string" then
            toprint = toprint .. k .. " = "
        end
        if type(v) == "number" then
            toprint = toprint .. v .. ",\n"
        elseif type(v) == "string" then
            toprint = toprint .. "\"" .. v .. "\",\n"
        elseif type(v) == "table" then
            toprint = toprint .. Logger.dumpTable(v, indent + 2) .. ",\n"
        else
            toprint = toprint .. "\"" .. tostring(v) .. "\",\n"
        end
    end
    toprint = toprint .. string.rep(" ", indent - 2) .. "}"
    return toprint
end

return Logger
