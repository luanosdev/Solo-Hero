---@class DeviceDetector
local DeviceDetector = {}

---@class DeviceInfo
---@field type DeviceType Tipo do dispositivo
---@field screenCategory ScreenCategory Categoria da tela
---@field inputMethod InputMethod Método de entrada principal
---@field os string Sistema operacional detectado

---@alias DeviceType
---| "desktop" # Computador desktop/laptop
---| "mobile" # Dispositivo móvel (Android/iOS)
---| "tablet" # Tablet
---| "console" # Console de jogos
---| "unknown" # Não identificado

---@alias ScreenCategory
---| "small" # Tela pequena (< 6 polegadas)
---| "medium" # Tela média (6-10 polegadas)
---| "large" # Tela grande (10-24 polegadas)
---| "xlarge" # Tela extra grande (> 24 polegadas)

---@alias InputMethod
---| "keyboard_mouse" # Teclado e mouse
---| "touch" # Touch screen
---| "gamepad" # Controle de jogos
---| "mixed" # Múltiplos métodos

-- Cache do resultado da detecção
local cachedDeviceInfo = nil

--- Detecta o tipo de dispositivo atual
---@return DeviceInfo deviceInfo Informações completas do dispositivo
function DeviceDetector.detect()
    if cachedDeviceInfo then
        return cachedDeviceInfo
    end

    local os = love.system.getOS()
    local deviceInfo = {
        type = "unknown",
        screenCategory = "medium",
        inputMethod = "keyboard_mouse",
        os = os
    }

    -- Detecção baseada no SO
    if os == "Windows" or os == "Linux" or os == "OS X" then
        deviceInfo.type = "desktop"
        deviceInfo.inputMethod = "keyboard_mouse"
    elseif os == "Android" or os == "iOS" then
        deviceInfo.type = "mobile"
        deviceInfo.inputMethod = "touch"
    else
        -- Para SO não reconhecidos, assume desktop como padrão seguro
        deviceInfo.type = "desktop"
        deviceInfo.inputMethod = "keyboard_mouse"
    end

    -- Detecção de categoria de tela baseada na resolução física
    local windowW, windowH = love.graphics.getDimensions()
    local diagonalPixels = math.sqrt(windowW * windowW + windowH * windowH)

    if diagonalPixels < 1000 then
        deviceInfo.screenCategory = "small"
    elseif diagonalPixels < 2000 then
        deviceInfo.screenCategory = "medium"
    elseif diagonalPixels < 3500 then
        deviceInfo.screenCategory = "large"
    else
        deviceInfo.screenCategory = "xlarge"
    end

    -- Ajustes específicos para mobile
    if deviceInfo.type == "mobile" then
        -- Força categoria small ou medium para mobile
        if deviceInfo.screenCategory == "large" or deviceInfo.screenCategory == "xlarge" then
            deviceInfo.screenCategory = "medium" -- Tablets grandes
            deviceInfo.type = "tablet"
        end
    end

    cachedDeviceInfo = deviceInfo
    Logger.info("device_detector.detect.result",
        string.format("[DeviceDetector:detect] Dispositivo detectado: %s, tela: %s, entrada: %s, OS: %s",
            deviceInfo.type, deviceInfo.screenCategory, deviceInfo.inputMethod, deviceInfo.os))

    return deviceInfo
end

--- Verifica se o dispositivo atual é mobile (telefone ou tablet)
---@return boolean isMobile
function DeviceDetector.isMobile()
    local info = DeviceDetector.detect()
    return info.type == "mobile" or info.type == "tablet"
end

--- Verifica se o dispositivo atual é desktop
---@return boolean isDesktop
function DeviceDetector.isDesktop()
    local info = DeviceDetector.detect()
    return info.type == "desktop"
end

--- Verifica se o dispositivo usa touch como método principal
---@return boolean isTouch
function DeviceDetector.isTouch()
    local info = DeviceDetector.detect()
    return info.inputMethod == "touch"
end

--- Obtém a categoria de tela atual
---@return ScreenCategory screenCategory
function DeviceDetector.getScreenCategory()
    local info = DeviceDetector.detect()
    return info.screenCategory
end

--- Força uma nova detecção (limpa cache)
function DeviceDetector.refresh()
    cachedDeviceInfo = nil
end

return DeviceDetector
