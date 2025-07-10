--------------------------------------------------------------------------------
--- @author ReyalS
--- @release 1.0
--- @license MIT
--- @description
--- Inicialização global do sistema de localização.
--- Define funções globais curtas para facilitar o uso em todo o projeto.
--- Deve ser chamado no main.lua para disponibilizar as funções globalmente.

local LocalizationHelpers = require("src.utils.localization_helpers")

--- Valida recursivamente se uma estrutura de traduções está completa comparando com uma base
--- @param baseTable table Estrutura base (pt_BR)
--- @param targetTable table Estrutura a ser validada
--- @param currentPath string Caminho atual para rastrear chaves aninhadas
--- @param missingKeys table Lista de chaves faltantes
--- @param languageId string ID do idioma sendo validado
local function validateTranslationStructure(baseTable, targetTable, currentPath, missingKeys, languageId)
    for key, value in pairs(baseTable) do
        local fullPath = currentPath == "" and key or (currentPath .. "." .. key)

        if targetTable[key] == nil then
            -- Chave completamente ausente
            table.insert(missingKeys, fullPath)
        elseif type(value) == "table" and type(targetTable[key]) == "table" then
            -- Ambos são tabelas, validar recursivamente
            validateTranslationStructure(value, targetTable[key], fullPath, missingKeys, languageId)
        elseif type(value) == "table" and type(targetTable[key]) ~= "table" then
            -- Base é tabela mas target não é - estrutura incorreta
            table.insert(missingKeys, fullPath .. " (estrutura incorreta - esperado tabela)")
        end
        -- Se ambos são valores (strings), então está OK
    end
end

--- Executa validação completa das traduções no modo DEV
--- @param baseLanguageId string ID do idioma base para comparação
local function validateTranslations(baseLanguageId)
    if not DEV then
        return -- Só executa no modo DEV
    end

    Logger.info(
        "localization_init.validation.start",
        "[LocalizationInit] Iniciando validação de traduções (modo DEV) - Base: " .. baseLanguageId
    )

    -- Carrega tradução base (pt_BR)
    local basePath = "src.data.translations." .. baseLanguageId
    local success, baseTranslations = pcall(require, basePath)

    if not success then
        Logger.error(
            "localization_init.validation.base_error",
            "[LocalizationInit] Erro ao carregar traduções base (" ..
            baseLanguageId .. "): " .. tostring(baseTranslations)
        )
        return
    end

    -- Lista de idiomas disponíveis para validar
    local availableLanguages = { "en" } -- Adicionar outros idiomas aqui conforme necessário

    local totalMissingKeys = 0
    local hasAnyMissingKeys = false

    for _, languageId in ipairs(availableLanguages) do
        if languageId ~= baseLanguageId then
            Logger.info(
                "localization_init.validation.check",
                "[LocalizationInit] Validando traduções: " .. languageId .. " contra " .. baseLanguageId
            )

            -- Carrega tradução do idioma sendo validado
            local targetPath = "src.data.translations." .. languageId
            local targetSuccess, targetTranslations = pcall(require, targetPath)

            if not targetSuccess then
                Logger.warn(
                    "localization_init.validation.target_error",
                    "[LocalizationInit] Erro ao carregar traduções de " ..
                    languageId .. ": " .. tostring(targetTranslations)
                )
            else
                -- Executa validação
                local missingKeys = {}
                validateTranslationStructure(baseTranslations, targetTranslations, "", missingKeys, languageId)

                if #missingKeys > 0 then
                    hasAnyMissingKeys = true
                    totalMissingKeys = totalMissingKeys + #missingKeys

                    Logger.warn(
                        "localization_init.validation.missing_keys",
                        string.format(
                            "[LocalizationInit] ⚠️  TRADUÇÕES FALTANTES em %s (%d chaves):",
                            languageId, #missingKeys
                        )
                    )

                    -- Log detalhado das chaves faltantes (agrupadas por categoria)
                    local categorizedKeys = {}
                    for _, missingKey in ipairs(missingKeys) do
                        local category = missingKey:match("^([^%.]+)")
                        category = category or "unknown"

                        if not categorizedKeys[category] then
                            categorizedKeys[category] = {}
                        end
                        table.insert(categorizedKeys[category], missingKey)
                    end

                    -- Exibe chaves faltantes organizadas por categoria
                    for category, keys in pairs(categorizedKeys) do
                        Logger.warn(
                            "localization_init.validation.category",
                            string.format("[LocalizationInit]   📁 %s (%d):", category, #keys)
                        )

                        for _, key in ipairs(keys) do
                            Logger.warn(
                                "localization_init.validation.missing_key",
                                "[LocalizationInit]     ❌ " .. key
                            )
                        end
                    end
                else
                    Logger.info(
                        "localization_init.validation.complete",
                        "[LocalizationInit] ✅ " .. languageId .. " - Todas as traduções estão presentes!"
                    )
                end
            end
        end
    end

    -- Resumo final
    if hasAnyMissingKeys then
        Logger.warn(
            "localization_init.validation.summary",
            string.format(
                "[LocalizationInit] 📊 RESUMO DA VALIDAÇÃO: %d chaves faltantes encontradas no total",
                totalMissingKeys
            )
        )
        Logger.warn(
            "localization_init.validation.recommendation",
            "[LocalizationInit] 💡 Recomendação: Adicione as chaves faltantes nos arquivos de tradução correspondentes"
        )
    else
        Logger.info(
            "localization_init.validation.all_complete",
            "[LocalizationInit] 🎉 Todas as traduções estão completas! Nenhuma chave faltante encontrada."
        )
    end
end

--- Inicializa o sistema de localização global
local function initializeLocalization()
    Logger.info(
        "localization_init.initialize.start",
        "[LocalizationInit] Inicializando sistema de localização global..."
    )

    --- Função global principal para obter traduções
    --- @param key string chave da tradução
    --- @param params table|nil Parâmetros para interpolação (opcional)
    --- @return string translation A tradução encontrada
    _G._T = function(key, params)
        return LocalizationHelpers.getText(key, params)
    end

    --- Função global para formatação com parâmetros (alias de _T)
    --- @param key string chave da tradução
    --- @param params table Parâmetros obrigatórios para interpolação
    --- @return string translation A tradução formatada
    _G._P = function(key, params)
        return LocalizationHelpers.getText(key, params)
    end

    --- Função global para obter traduções numéricas/plurais (future-proofing)
    --- @param key string chave da tradução
    --- @param count number Número para determinar forma plural
    --- @param params table|nil Parâmetros adicionais para interpolação
    --- @return string translation A tradução na forma adequada
    _G._N = function(key, count, params)
        -- Por enquanto, implementação simples
        -- No futuro, pode incluir lógica de pluralização
        local finalParams = params or {}
        finalParams.count = count
        return LocalizationHelpers.getText(key, finalParams)
    end

    --- Função global para definir idioma
    --- @param languageId "pt_BR"|"en" ID do idioma
    --- @return boolean success Se a mudança foi bem-sucedida
    _G.SetLanguage = function(languageId)
        return LocalizationHelpers.setLanguage(languageId)
    end

    --- Função global para obter idioma atual
    --- @return "pt_BR"|"en" currentLanguage
    _G.GetCurrentLanguage = function()
        return LocalizationHelpers.getCurrentLanguage()
    end

    --- Disponibiliza módulo de helpers globalmente para uso avançado
    _G.LocalizationHelpers = LocalizationHelpers

    Logger.info("localization_init.complete", "[LocalizationInit] Sistema de localização inicializado globalmente")
    Logger.info(
        "localization_init.functions",
        "[LocalizationInit] Funções globais disponíveis: _T(), _P(), _N(), SetLanguage(), GetCurrentLanguage()"
    )

    -- Executa validação no modo DEV
    validateTranslations("pt_BR")
end

--- Chama a inicialização
initializeLocalization()

return {
    initialize = initializeLocalization
}
