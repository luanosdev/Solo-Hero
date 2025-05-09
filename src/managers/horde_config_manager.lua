---@class HordeConfigManager
local HordeConfigManager = {}

-- Cache para evitar recarregar arquivos desnecessariamente
local loadedConfigs = {}

-- Mapeamento de ID de mundo para arquivo de configuração
local worldConfigMapping = {
    ["default"] = "src.config.hordes.default_hordes",
    -- Exemplo futuro:
    -- ["larva_world"] = "src.config.hordes.larva_hordes", 
}

function HordeConfigManager.loadHordes(worldId)
    worldId = worldId or "default" -- Usa 'default' se nenhum ID for fornecido
    
    -- Verifica se já está em cache
    if loadedConfigs[worldId] then
        return loadedConfigs[worldId]
    end
    
    local configPath = worldConfigMapping[worldId]
    if not configPath then
        print("Erro: Configuração de hordas não encontrada para o mundo: " .. worldId)
        -- Carrega o padrão como fallback
        configPath = worldConfigMapping["default"]
        if not configPath then 
            error("Erro crítico: Configuração de hordas padrão não encontrada.")
        end
    end
    
    print("Carregando configuração de hordas de: " .. configPath)
    local success, configData = pcall(require, configPath)

    if success and type(configData) == "table" then
        loadedConfigs[worldId] = configData
        return configData
    else
        print("Erro ao carregar configuração de hordas de: " .. configPath)
        -- Tenta carregar o padrão como fallback se o erro não foi no padrão
        if worldId ~= "default" then
            return HordeConfigManager.loadHordes("default") 
        else
            error("Erro crítico ao carregar configuração de hordas padrão." ..worldId )
        end
    end
end

return HordeConfigManager