---@class AdaptiveScaleManager
local AdaptiveScaleManager = {}

local DeviceDetector = require("src.utils.device_detector")

---@class ScaleConfig
---@field ui number Fator de escala para elementos de UI
---@field text number Fator de escala para tamanhos de texto/fontes
---@field gameplay number Fator de escala para elementos de gameplay
---@field spacing number Fator de escala para espaçamentos e padding
---@field icons number Fator de escala para ícones e botões
---@field hud number Fator de escala para elementos do HUD

---@class AdaptiveScaleConfig
---@field desktop ScaleConfig Configuração para desktop
---@field mobile ScaleConfig Configuração para mobile
---@field tablet ScaleConfig Configuração para tablet

-- Configuração padrão dos fatores de escala por dispositivo
local defaultScaleConfig = {
    desktop = {
        ui = 1.0,       -- UI mantém tamanho original
        text = 1.0,     -- Texto mantém tamanho original
        gameplay = 1.0, -- Elementos de gameplay mantêm tamanho original
        spacing = 1.0,  -- Espaçamentos mantêm tamanho original
        icons = 1.0,    -- Ícones mantêm tamanho original
        hud = 1.0       -- HUD mantém tamanho original
    },
    mobile = {
        ui = 1.5,       -- UI 50% maior para touch
        text = 1.3,     -- Texto 30% maior para legibilidade
        gameplay = 1.2, -- Elementos de gameplay ligeiramente maiores
        spacing = 1.4,  -- Espaçamentos maiores para touch
        icons = 1.6,    -- Ícones bem maiores para touch
        hud = 1.3       -- HUD maior para visibilidade
    },
    tablet = {
        ui = 1.2,       -- UI ligeiramente maior
        text = 1.1,     -- Texto ligeiramente maior
        gameplay = 1.1, -- Elementos de gameplay ligeiramente maiores
        spacing = 1.2,  -- Espaçamentos ligeiramente maiores
        icons = 1.3,    -- Ícones maiores para touch
        hud = 1.15      -- HUD ligeiramente maior
    }
}

-- Configuração atual carregada
local currentConfig = nil

--- Inicializa o gerenciador de escala adaptativa
---@param customConfig? AdaptiveScaleConfig Configuração personalizada (opcional)
function AdaptiveScaleManager.initialize(customConfig)
    local config = customConfig or defaultScaleConfig

    -- Merge configuração personalizada com padrão
    currentConfig = {
        desktop = {},
        mobile = {},
        tablet = {}
    }

    for deviceType, defaultScales in pairs(defaultScaleConfig) do
        for category, defaultValue in pairs(defaultScales) do
            currentConfig[deviceType][category] =
                (config[deviceType] and config[deviceType][category]) or defaultValue
        end
    end

    Logger.info("adaptive_scale_manager.initialize.success",
        "[AdaptiveScaleManager:initialize] Sistema de escala adaptativa inicializado")
end

--- Obtém o fator de escala para uma categoria específica
---@param category string Categoria do elemento (ui, text, gameplay, spacing, icons, hud)
---@return number scaleFactor Fator de escala para a categoria
function AdaptiveScaleManager.getScale(category)
    if not currentConfig then
        AdaptiveScaleManager.initialize()
    end

    -- Verificação de segurança da configuração
    if not currentConfig or not currentConfig.desktop then
        Logger.error("adaptive_scale_manager.get_scale.invalid_config",
            "[AdaptiveScaleManager:getScale] Configuração inválida, retornando escala padrão")
        return 1.0
    end

    local deviceInfo = DeviceDetector.detect()
    local deviceType = deviceInfo.type

    -- Mapeia tipos de dispositivo para configurações
    local configKey = deviceType
    if deviceType == "unknown" then
        configKey = "desktop" -- Fallback seguro
    end

    local deviceConfig = currentConfig[configKey] or currentConfig.desktop
    if not deviceConfig then
        Logger.error("adaptive_scale_manager.get_scale.no_device_config",
            "[AdaptiveScaleManager:getScale] Nenhuma configuração de dispositivo disponível")
        return 1.0
    end

    local scaleFactor = deviceConfig[category]
    if not scaleFactor then
        Logger.warn("adaptive_scale_manager.get_scale.unknown_category",
            string.format("[AdaptiveScaleManager:getScale] Categoria '%s' não configurada, usando 1.0", category))
        return 1.0
    end

    return scaleFactor
end

--- Aplica escala a um valor baseado na categoria
---@param value number Valor original
---@param category string Categoria do elemento
---@return number scaledValue Valor com escala aplicada
function AdaptiveScaleManager.applyScale(value, category)
    local scaleFactor = AdaptiveScaleManager.getScale(category)
    return value * scaleFactor
end

--- Obtém configuração de escala para múltiplas categorias
---@param categories string[] Lista de categorias desejadas
---@return table<string, number> scaleFactors Mapa categoria -> fator de escala
function AdaptiveScaleManager.getScales(categories)
    local result = {}
    for _, category in ipairs(categories) do
        result[category] = AdaptiveScaleManager.getScale(category)
    end
    return result
end

--- Verifica se o dispositivo atual requer escalas adaptativas
---@return boolean needsAdaptiveScale
function AdaptiveScaleManager.needsAdaptiveScale()
    local deviceInfo = DeviceDetector.detect()
    return deviceInfo.type ~= "desktop"
end

--- Obtém informações detalhadas sobre escalas atuais
---@return table scaleInfo Informações detalhadas sobre configuração atual
function AdaptiveScaleManager.getScaleInfo()
    if not currentConfig then
        AdaptiveScaleManager.initialize()
    end

    -- Verificação de segurança da configuração
    if not currentConfig or not currentConfig.desktop then
        return {
            deviceType = "unknown",
            deviceInfo = DeviceDetector.detect(),
            currentScales = {},
            needsAdaptiveScale = false
        }
    end

    local deviceInfo = DeviceDetector.detect()
    local deviceType = deviceInfo.type == "unknown" and "desktop" or deviceInfo.type
    local currentScales = currentConfig[deviceType] or currentConfig.desktop or {}

    return {
        deviceType = deviceType,
        deviceInfo = deviceInfo,
        currentScales = currentScales,
        needsAdaptiveScale = AdaptiveScaleManager.needsAdaptiveScale()
    }
end

--- Atualiza configuração de escala para um dispositivo específico
---@param deviceType string Tipo do dispositivo (desktop, mobile, tablet)
---@param category string Categoria a atualizar
---@param scale number Novo fator de escala
function AdaptiveScaleManager.updateScale(deviceType, category, scale)
    if not currentConfig then
        AdaptiveScaleManager.initialize()
    end

    -- Verificação de segurança da configuração
    if not currentConfig then
        Logger.error("adaptive_scale_manager.update_scale.no_config",
            "[AdaptiveScaleManager:updateScale] Configuração não inicializada")
        return
    end

    if not currentConfig[deviceType] then
        Logger.error("adaptive_scale_manager.update_scale.invalid_device",
            string.format("[AdaptiveScaleManager:updateScale] Tipo de dispositivo inválido: %s", deviceType))
        return
    end

    currentConfig[deviceType][category] = scale
    Logger.info("adaptive_scale_manager.update_scale.success",
        string.format("[AdaptiveScaleManager:updateScale] Escala atualizada: %s.%s = %.2f",
            deviceType, category, scale))
end

return AdaptiveScaleManager
