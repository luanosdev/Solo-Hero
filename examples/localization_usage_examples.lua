--------------------------------------------------------------------------------
--- @author ReyalS
--- @release 1.0
--- @license MIT
--- @description
--- Exemplos práticos de uso do sistema de localização do Solo Hero.
--- Este arquivo demonstra todas as funcionalidades disponíveis e serve como
--- documentação de referência para desenvolvedores.

--------------------------------------------------------------------------------
--- NOTA: Este arquivo é apenas para exemplos/demonstração.
--- Não deve ser usado em produção, apenas para referência e testes.
--------------------------------------------------------------------------------

-- Este arquivo assume que o sistema de localização foi inicializado no main.lua

local LocalizationExamples = {}

--- Demonstra o uso básico das funções globais de localização
function LocalizationExamples.basicUsage()
    print("=== EXEMPLOS BÁSICOS ===")

    -- Função principal _T() para traduções simples
    print("Carregando: " .. _T("general.loading"))
    print("Erro: " .. _T("general.error"))
    print("Sucesso: " .. _T("general.success"))

    -- Tradução de interface
    print("Interface:")
    print("  Vida: " .. _T("ui.health"))
    print("  Mana: " .. _T("ui.mana"))
    print("  Inventário: " .. _T("ui.inventory"))

    -- Tradução de ranks
    print("Ranks:")
    print("  " .. _T("ranks.E.name") .. ": " .. _T("ranks.E.description"))
    print("  " .. _T("ranks.S.name") .. ": " .. _T("ranks.S.description"))
end

--- Demonstra o uso de traduções com parâmetros
function LocalizationExamples.parametrizedTranslations()
    print("=== EXEMPLOS COM PARÂMETROS ===")

    -- Usando _P() para traduções com parâmetros obrigatórios
    local playerName = "João"
    local level = 15

    -- Exemplo hipotético (não existe na nossa tradução atual, mas mostra como usar)
    -- print(_P("player.level_up", { player = playerName, level = level }))
    -- Result: "João subiu para o nível 15!"

    -- Usando _T() também funciona com parâmetros opcionais
    print(_T("system.language_changed", { language = "Português" }))

    -- Exemplo com números usando _N()
    local itemCount = 5
    -- _N() é future-proof para pluralização
    print(_N("items.collected", itemCount, { count = itemCount }))
end

--- Demonstra o uso das funções auxiliares específicas
function LocalizationExamples.helperFunctions()
    print("=== EXEMPLOS DE FUNÇÕES AUXILIARES ===")

    -- LocalizationHelpers para funcionalidades avançadas
    print("Idioma atual: " .. LocalizationHelpers.getCurrentLanguage())

    -- Informações específicas de armas
    local weaponName, weaponDesc = LocalizationHelpers.getWeaponInfo("cone_slash_e_001")
    print("Arma: " .. weaponName)
    print("Descrição: " .. weaponDesc)

    -- Informações específicas de arquétipos
    local archetypeName, archetypeDesc = LocalizationHelpers.getArchetypeInfo("agile")
    print("Arquétipo: " .. archetypeName)
    print("Descrição: " .. archetypeDesc)

    -- Informações específicas de ranks
    local rankName, rankDesc = LocalizationHelpers.getRankInfo("A")
    print("Rank: " .. rankName)
    print("Descrição: " .. rankDesc)
end

--- Demonstra o uso dos métodos de localização dos objetos de dados
function LocalizationExamples.objectMethods()
    print("=== EXEMPLOS COM MÉTODOS DE OBJETOS ===")

    -- Usando métodos de localização em armas
    local weapons = require("src.data.items.weapons")
    local sword = weapons.cone_slash_e_001

    print("Arma (método original): " .. sword.name)
    print("Arma (localizada): " .. sword:getLocalizedName())
    print("Descrição (localizada): " .. sword:getLocalizedDescription())

    -- Usando métodos de localização em arquétipos
    local archetypes = require("src.data.archetypes_data")
    local agileArchetype = archetypes.Archetypes.agile

    print("Arquétipo (método original): " .. agileArchetype.name)
    print("Arquétipo (localizado): " .. agileArchetype:getLocalizedName())
    print("Descrição (localizada): " .. agileArchetype:getLocalizedDescription())

    -- Usando métodos de localização em ranks
    local rankE = archetypes.Ranks.E
    print("Rank (método original): " .. rankE.name)
    print("Rank (localizado): " .. rankE:getLocalizedName())
    print("Descrição (localizada): " .. rankE:getLocalizedDescription())
end

--- Demonstra a troca de idiomas
function LocalizationExamples.languageSwitching()
    print("=== EXEMPLOS DE TROCA DE IDIOMA ===")

    print("Idioma atual: " .. GetCurrentLanguage())
    print("Carregando em português: " .. _T("general.loading"))

    -- Muda para inglês
    if SetLanguage("en") then
        print("Idioma alterado para: " .. GetCurrentLanguage())
        print("Loading in English: " .. _T("general.loading"))

        -- Mostra a mesma arma em inglês
        local weapons = require("src.data.items.weapons")
        local sword = weapons.cone_slash_e_001
        print("Weapon (English): " .. sword:getLocalizedName())
    else
        print("Falha ao alterar idioma para inglês")
    end

    -- Volta para português
    SetLanguage("pt_BR")
    print("Voltou para português: " .. _T("general.loading"))
end

--- Demonstra verificação de existência de chaves
function LocalizationExamples.keyValidation()
    print("=== EXEMPLOS DE VALIDAÇÃO DE CHAVES ===")

    -- Chaves válidas
    local validKey = "general.loading"
    print("Chave '" .. validKey .. "' existe? " .. tostring(LocalizationHelpers.keyExists(validKey)))
    print("Valor: " .. _T(validKey))

    -- Chave inválida
    local invalidKey = "nonexistent.key"
    print("Chave '" .. invalidKey .. "' existe? " .. tostring(LocalizationHelpers.keyExists(invalidKey)))
    print("Valor (retorna a própria chave): " .. _T(invalidKey))
end

--- Demonstra obtenção de estatísticas do sistema
function LocalizationExamples.systemStats()
    print("=== ESTATÍSTICAS DO SISTEMA ===")

    local stats = LocalizationHelpers.getStats()

    print("Idioma atual: " .. stats.currentLanguage)
    print("Idioma de fallback: " .. stats.fallbackLanguage)
    print("Sistema inicializado: " .. tostring(stats.initialized))

    print("Idiomas carregados:")
    for _, lang in ipairs(stats.loadedLanguages) do
        print("  - " .. lang)
    end

    print("Idiomas disponíveis:")
    for _, langName in ipairs(stats.availableLanguages) do
        print("  - " .. langName)
    end
end

--- Exemplo prático de uso em uma interface de usuário
function LocalizationExamples.uiExample()
    print("=== EXEMPLO PRÁTICO DE UI ===")

    -- Simula criação de uma interface de configurações
    local settingsUI = {
        title = _T("ui.settings"),
        sections = {
            {
                name = _T("ui.audio"),
                options = {
                    { label = _T("ui.audio"), value = "volume_master" }
                }
            },
            {
                name = _T("ui.video"),
                options = {
                    { label = _T("ui.graphics"), value = "quality" }
                }
            },
            {
                name = _T("ui.language"),
                options = {}
            }
        },
        buttons = {
            save = _T("general.save"),
            cancel = _T("general.cancel"),
            back = _T("general.back")
        }
    }

    print("Interface de " .. settingsUI.title .. ":")
    for _, section in ipairs(settingsUI.sections) do
        print("  Seção: " .. section.name)
    end
    print("  Botões: " .. settingsUI.buttons.save .. ", " ..
        settingsUI.buttons.cancel .. ", " .. settingsUI.buttons.back)
end

--- Executa todos os exemplos
function LocalizationExamples.runAllExamples()
    print("=====================================")
    print("EXEMPLOS DO SISTEMA DE LOCALIZAÇÃO")
    print("=====================================")

    LocalizationExamples.basicUsage()
    print("\n")

    LocalizationExamples.parametrizedTranslations()
    print("\n")

    LocalizationExamples.helperFunctions()
    print("\n")

    LocalizationExamples.objectMethods()
    print("\n")

    LocalizationExamples.languageSwitching()
    print("\n")

    LocalizationExamples.keyValidation()
    print("\n")

    LocalizationExamples.systemStats()
    print("\n")

    LocalizationExamples.uiExample()
    print("\n")

    print("=====================================")
    print("EXEMPLOS CONCLUÍDOS")
    print("=====================================")
end

--- Função global para testar o sistema de localização
--- Pode ser chamada no console do jogo durante desenvolvimento
_G.TestLocalization = function()
    LocalizationExamples.runAllExamples()
end

--- Funções globais individuais para testes específicos
_G.TestLocalizationBasic = LocalizationExamples.basicUsage
_G.TestLocalizationParams = LocalizationExamples.parametrizedTranslations
_G.TestLocalizationHelpers = LocalizationExamples.helperFunctions
_G.TestLocalizationObjects = LocalizationExamples.objectMethods
_G.TestLocalizationLanguages = LocalizationExamples.languageSwitching
_G.TestLocalizationValidation = LocalizationExamples.keyValidation
_G.TestLocalizationStats = LocalizationExamples.systemStats
_G.TestLocalizationUI = LocalizationExamples.uiExample

return LocalizationExamples
