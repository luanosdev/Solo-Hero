---@class AdaptiveConfig
local AdaptiveConfig = {}

---@class AdaptiveScalePreset
---@field name string Nome do preset
---@field description string Descrição do preset
---@field config AdaptiveScaleConfig Configuração de escalas

-- Presets predefinidos para diferentes cenários de uso
local presets = {
    -- Preset padrão - escalas moderadas e balanceadas
    default = {
        name = "Padrão",
        description = "Configuração balanceada para a maioria dos dispositivos",
        config = {
            desktop = {
                ui = 1.0,
                text = 1.0,
                gameplay = 1.0,
                spacing = 1.0,
                icons = 1.0,
                hud = 1.0
            },
            mobile = {
                ui = 1.5,
                text = 1.3,
                gameplay = 1.2,
                spacing = 1.4,
                icons = 1.6,
                hud = 1.3
            },
            tablet = {
                ui = 1.2,
                text = 1.1,
                gameplay = 1.1,
                spacing = 1.2,
                icons = 1.3,
                hud = 1.15
            }
        }
    },

    -- Preset para acessibilidade - escalas maiores
    accessibility = {
        name = "Acessibilidade",
        description = "Elementos maiores para melhor visibilidade e acessibilidade",
        config = {
            desktop = {
                ui = 1.2,
                text = 1.3,
                gameplay = 1.0,
                spacing = 1.2,
                icons = 1.4,
                hud = 1.2
            },
            mobile = {
                ui = 1.8,
                text = 1.6,
                gameplay = 1.3,
                spacing = 1.6,
                icons = 2.0,
                hud = 1.6
            },
            tablet = {
                ui = 1.5,
                text = 1.4,
                gameplay = 1.2,
                spacing = 1.4,
                icons = 1.7,
                hud = 1.4
            }
        }
    },

    -- Preset compacto - elementos menores para maximizar espaço
    compact = {
        name = "Compacto",
        description = "Interface mais compacta para maximizar área de jogo",
        config = {
            desktop = {
                ui = 0.9,
                text = 0.95,
                gameplay = 1.0,
                spacing = 0.8,
                icons = 0.85,
                hud = 0.9
            },
            mobile = {
                ui = 1.2,
                text = 1.1,
                gameplay = 1.1,
                spacing = 1.1,
                icons = 1.3,
                hud = 1.1
            },
            tablet = {
                ui = 1.0,
                text = 1.0,
                gameplay = 1.0,
                spacing = 1.0,
                icons = 1.1,
                hud = 1.0
            }
        }
    },

    -- Preset para desenvolvimento - sem escalas para teste
    development = {
        name = "Desenvolvimento",
        description = "Sem escalas adaptativas para teste e desenvolvimento",
        config = {
            desktop = {
                ui = 1.0,
                text = 1.0,
                gameplay = 1.0,
                spacing = 1.0,
                icons = 1.0,
                hud = 1.0
            },
            mobile = {
                ui = 1.0,
                text = 1.0,
                gameplay = 1.0,
                spacing = 1.0,
                icons = 1.0,
                hud = 1.0
            },
            tablet = {
                ui = 1.0,
                text = 1.0,
                gameplay = 1.0,
                spacing = 1.0,
                icons = 1.0,
                hud = 1.0
            }
        }
    }
}

-- Configuração ativa atual
local activePreset = "default"

--- Obtém a lista de presets disponíveis
---@return table<string, AdaptiveScalePreset> presets Lista de presets disponíveis
function AdaptiveConfig.getPresets()
    return presets
end

--- Obtém um preset específico
---@param presetName string Nome do preset
---@return AdaptiveScalePreset|nil preset Preset encontrado ou nil
function AdaptiveConfig.getPreset(presetName)
    return presets[presetName]
end

--- Define qual preset está ativo
---@param presetName string Nome do preset a ativar
---@return boolean success Se o preset foi ativado com sucesso
function AdaptiveConfig.setActivePreset(presetName)
    if not presets[presetName] then
        Logger.error("adaptive_config.set_active_preset.not_found",
            string.format("[AdaptiveConfig:setActivePreset] Preset '%s' não encontrado", presetName))
        return false
    end

    activePreset = presetName
    Logger.info("adaptive_config.set_active_preset.success",
        string.format("[AdaptiveConfig:setActivePreset] Preset ativo: %s", presetName))
    return true
end

--- Obtém o preset atualmente ativo
---@return AdaptiveScalePreset activePresetData Dados do preset ativo
function AdaptiveConfig.getActivePreset()
    return presets[activePreset]
end

--- Obtém a configuração do preset ativo
---@return AdaptiveScaleConfig config Configuração de escalas do preset ativo
function AdaptiveConfig.getActiveConfig()
    return presets[activePreset].config
end

--- Cria um preset personalizado
---@param name string Nome do preset
---@param description string Descrição do preset
---@param config AdaptiveScaleConfig Configuração de escalas
---@return boolean success Se o preset foi criado com sucesso
function AdaptiveConfig.createPreset(name, description, config)
    if presets[name] then
        Logger.warn("adaptive_config.create_preset.already_exists",
            string.format("[AdaptiveConfig:createPreset] Preset '%s' já existe, será substituído", name))
    end

    presets[name] = {
        name = name,
        description = description,
        config = config
    }

    Logger.info("adaptive_config.create_preset.success",
        string.format("[AdaptiveConfig:createPreset] Preset '%s' criado", name))
    return true
end

--- Remove um preset personalizado (não permite remover presets padrão)
---@param presetName string Nome do preset a remover
---@return boolean success Se o preset foi removido com sucesso
function AdaptiveConfig.removePreset(presetName)
    -- Protege presets padrão
    local protectedPresets = { "default", "accessibility", "compact", "development" }
    for _, protected in ipairs(protectedPresets) do
        if presetName == protected then
            Logger.error("adaptive_config.remove_preset.protected",
                string.format("[AdaptiveConfig:removePreset] Preset '%s' é protegido e não pode ser removido", presetName))
            return false
        end
    end

    if not presets[presetName] then
        Logger.error("adaptive_config.remove_preset.not_found",
            string.format("[AdaptiveConfig:removePreset] Preset '%s' não encontrado", presetName))
        return false
    end

    presets[presetName] = nil

    -- Se o preset removido era o ativo, volta para o padrão
    if activePreset == presetName then
        activePreset = "default"
        Logger.info("adaptive_config.remove_preset.fallback",
            "[AdaptiveConfig:removePreset] Preset ativo removido, voltando para 'default'")
    end

    Logger.info("adaptive_config.remove_preset.success",
        string.format("[AdaptiveConfig:removePreset] Preset '%s' removido", presetName))
    return true
end

return AdaptiveConfig
