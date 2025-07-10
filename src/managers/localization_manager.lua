--------------------------------------------------------------------------------
--- Sistema de localização global para o Solo Hero.
--- Gerencia traduções, idiomas, fallbacks e validação de chaves.
--- Disponível globalmente após inicialização.

--------------------------------------------------------------------------------
--- TIPOS DE LOCALIZAÇÃO (LDOC)
--------------------------------------------------------------------------------

---@class TranslationData
---@field [string] string|table Dados de tradução organizados hierarquicamente

---@class LanguageInfo
---@field id string Código ISO da língua (ex: "pt_BR", "en")
---@field name string Nome legível da língua
---@field fallback string|nil Idioma de fallback se tradução não for encontrada

---@class LocalizationManager
---@field currentLanguage string Idioma atualmente ativo
---@field availableLanguages table<string, LanguageInfo> Idiomas disponíveis
---@field translations table<string, TranslationData> Cache de traduções carregadas
---@field fallbackLanguage string Idioma de fallback principal
---@field initialized boolean Se o sistema foi inicializado
local LocalizationManager = {}
LocalizationManager.__index = LocalizationManager

-- Constantes do sistema
local DEFAULT_LANGUAGE = "pt_BR"
local FALLBACK_LANGUAGE = "pt_BR"
local TRANSLATIONS_PATH = "src/data/translations/"

-- Cache estático (singleton)
LocalizationManager._instance = nil

--- Obtém ou cria a instância singleton do LocalizationManager
---@return LocalizationManager
function LocalizationManager:getInstance()
    if not LocalizationManager._instance then
        LocalizationManager._instance = setmetatable({}, LocalizationManager)
        LocalizationManager._instance:_initialize()
    end
    return LocalizationManager._instance
end

--- Inicialização interna do manager
function LocalizationManager:_initialize()
    Logger.debug("localization_manager.initialize.start", "[LocalizationManager] Inicializando sistema de localização...")

    self.currentLanguage = DEFAULT_LANGUAGE
    self.fallbackLanguage = FALLBACK_LANGUAGE
    self.initialized = false
    self.translations = {}

    -- Define idiomas disponíveis
    self.availableLanguages = {
        pt_BR = {
            id = "pt_BR",
            name = "Português (Brasil)",
            fallback = nil -- Idioma principal, sem fallback
        },
        en = {
            id = "en",
            name = "English",
            fallback = "pt_BR" -- Fallback para português se tradução não existir
        }
    }

    -- Carrega tradução padrão
    self:_loadLanguage(DEFAULT_LANGUAGE)

    self.initialized = true
    Logger.info(
        "localization_manager.initialize.successs",
        "[LocalizationManager] Sistema inicializado com idioma: " .. DEFAULT_LANGUAGE
    )
end

--- Carrega um arquivo de tradução para um idioma específico
---@param languageId string ID do idioma a ser carregado
---@return boolean success Se o carregamento foi bem-sucedido
function LocalizationManager:_loadLanguage(languageId)
    if self.translations[languageId] then
        Logger.debug(
            "localization_manager.load",
            "[LocalizationManager] Idioma " .. languageId .. " já carregado (cache)"
        )
        return true
    end

    local filepath = TRANSLATIONS_PATH .. languageId .. ".lua"
    Logger.debug("localization_manager.load.loading", "[LocalizationManager] Carregando " .. filepath)

    local success, translationData = pcall(
        require,
        filepath:gsub("%.lua$", ""):gsub("/", ".")
    )

    if success and translationData then
        self.translations[languageId] = translationData
        Logger.info(
            "localization_manager.load.success",
            "[LocalizationManager] Idioma " .. languageId .. " carregado com sucesso"
        )
        return true
    else
        Logger.error(
            "localization_manager.load.error",
            "[LocalizationManager] Falha ao carregar idioma " .. languageId .. ": " .. tostring(translationData)
        )
        return false
    end
end

--- Define o idioma ativo do sistema
---@param languageId string ID do idioma para ativar
---@return boolean success Se a mudança foi bem-sucedida
function LocalizationManager:setLanguage(languageId)
    if not self.availableLanguages[languageId] then
        Logger.error("localization_manager.set_language", "[LocalizationManager] Idioma não suportado: " .. languageId)
        return false
    end

    -- Carrega o idioma se ainda não estiver em cache
    if not self:_loadLanguage(languageId) then
        Logger.error(
            "localization_manager.set_language.error",
            "[LocalizationManager] Falha ao carregar idioma: " .. languageId
        )
        return false
    end

    self.currentLanguage = languageId
    Logger.info("localization_manager.set_language", "[LocalizationManager] Idioma alterado para: " .. languageId)
    return true
end

--- Obtém o idioma atualmente ativo
---@return string currentLanguage
function LocalizationManager:getCurrentLanguage()
    return self.currentLanguage
end

--- Obtém lista de idiomas disponíveis
---@return table<string, LanguageInfo> availableLanguages
function LocalizationManager:getAvailableLanguages()
    return self.availableLanguages
end

--- Navega pela estrutura hierárquica de traduções usando uma chave com pontos
---@param data table Dados de tradução
---@param keyParts string[] Partes da chave separadas por ponto
---@return string|nil result Tradução encontrada ou nil
function LocalizationManager:_navigateTranslationData(data, keyParts)
    local current = data

    for i, part in ipairs(keyParts) do
        if type(current) ~= "table" then
            return nil
        end

        current = current[part]
        if current == nil then
            return nil
        end
    end

    return type(current) == "string" and current or nil
end

--- Obtém uma tradução para a chave especificada
---@param key string Chave da tradução (formato hierárquico com pontos)
---@param params table|nil Parâmetros para interpolação na string
---@return string translation Tradução encontrada ou chave original se não encontrada
function LocalizationManager:getText(key, params)
    if not self.initialized then
        Logger.warn(
            "localization_manager.get_text.warning",
            "[LocalizationManager] Sistema não inicializado, retornando chave: " .. key
        )
        return key
    end

    local keyParts = {}
    for part in key:gmatch("[^%.]+") do
        table.insert(keyParts, part)
    end

    -- Tenta encontrar na língua atual
    local currentTranslations = self.translations[self.currentLanguage]
    local result = nil

    if currentTranslations then
        result = self:_navigateTranslationData(currentTranslations, keyParts)
    end

    -- Fallback para idioma principal se não encontrou
    if not result and self.currentLanguage ~= self.fallbackLanguage then
        local fallbackTranslations = self.translations[self.fallbackLanguage]
        if fallbackTranslations then
            result = self:_navigateTranslationData(fallbackTranslations, keyParts)
            if result then
                Logger.debug(
                    "localization_manager.get_text.fallback",
                    "[LocalizationManager] Usando fallback para chave: " .. key
                )
            end
        end
    end

    -- Se ainda não encontrou, retorna a chave original
    if not result then
        Logger.warn(
            "localization_manager.get_text.missing",
            "[LocalizationManager] Tradução não encontrada para chave: " .. key
        )
        return key
    end

    -- Interpola parâmetros se fornecidos
    if params and type(params) == "table" then
        for paramKey, paramValue in pairs(params) do
            result = result:gsub("{" .. paramKey .. "}", tostring(paramValue))
        end
    end

    return result
end

--- Verifica se uma chave de tradução existe
---@param key string Chave da tradução
---@return boolean exists Se a chave existe em qualquer idioma carregado
function LocalizationManager:keyExists(key)
    if not self.initialized then
        return false
    end

    local keyParts = {}
    for part in key:gmatch("[^%.]+") do
        table.insert(keyParts, part)
    end

    -- Verifica na língua atual
    local currentTranslations = self.translations[self.currentLanguage]
    if currentTranslations then
        local result = self:_navigateTranslationData(currentTranslations, keyParts)
        if result then
            return true
        end
    end

    -- Verifica no fallback
    if self.currentLanguage ~= self.fallbackLanguage then
        local fallbackTranslations = self.translations[self.fallbackLanguage]
        if fallbackTranslations then
            local result = self:_navigateTranslationData(fallbackTranslations, keyParts)
            if result then
                return true
            end
        end
    end

    return false
end

--- Obtém estatísticas do sistema de localização
---@return table stats Estatísticas de uso e cache
function LocalizationManager:getStats()
    local stats = {
        currentLanguage = self.currentLanguage,
        fallbackLanguage = self.fallbackLanguage,
        initialized = self.initialized,
        loadedLanguages = {},
        availableLanguages = {}
    }

    -- Lista idiomas carregados em cache
    for langId, _ in pairs(self.translations) do
        table.insert(stats.loadedLanguages, langId)
    end

    -- Lista idiomas disponíveis
    for langId, langInfo in pairs(self.availableLanguages) do
        table.insert(stats.availableLanguages, langInfo.name)
    end

    return stats
end

--- Recarrega todas as traduções (útil para development/hot reload)
function LocalizationManager:reload()
    Logger.info("localization_manager.reload", "[LocalizationManager] Recarregando sistema de localização...")

    -- Limpa cache
    self.translations = {}

    -- Recarrega idioma atual
    self:_loadLanguage(self.currentLanguage)

    -- Recarrega fallback se diferente
    if self.currentLanguage ~= self.fallbackLanguage then
        self:_loadLanguage(self.fallbackLanguage)
    end

    Logger.info("localization_manager.reload", "[LocalizationManager] Sistema recarregado")
end

return LocalizationManager
