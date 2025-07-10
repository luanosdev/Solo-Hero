# Sistema de Localização - Solo Hero

## Visão Geral

O Solo Hero implementou um sistema completo de localização que permite suporte a múltiplos idiomas de forma globalizada e eficiente. O sistema foi projetado para ser:

- **Globalmente disponível**: Funções acessíveis de qualquer lugar do código
- **Tipado com LDoc**: Validação de chaves através de tipos LDoc
- **Hierárquico**: Organização estruturada das traduções
- **Com fallback**: Sistema automático de fallback para português
- **Retrocompatível**: Mantém compatibilidade com código existente

## Arquivos do Sistema

### Core do Sistema
```
src/managers/localization_manager.lua          # Manager principal (singleton)
src/utils/localization_helpers.lua             # Funções auxiliares
src/utils/localization_init.lua                # Inicialização global
```

### Arquivos de Tradução
```
src/data/translations/pt_BR.lua                # Traduções em português
src/data/translations/en.lua                   # Traduções em inglês
```

### Exemplos e Documentação
```
examples/localization_usage_examples.lua       # Exemplos práticos de uso
docs/SISTEMA_LOCALIZACAO.md                   # Esta documentação
```

## Idiomas Suportados

| Código | Idioma | Fallback | Status |
|--------|--------|----------|---------|
| `pt_BR` | Português (Brasil) | - | Principal |
| `en` | English | `pt_BR` | Completo |

## Inicialização

O sistema é inicializado automaticamente no `main.lua`:

```lua
-- main.lua
function love.load()
    -- ... outras inicializações ...
    
    --- Inicializa o sistema de localização global
    require("src.utils.localization_init")
    
    -- ... resto da inicialização ...
end
```

## Funções Globais Disponíveis

### Funções Principais

```lua
-- Função principal para traduções
_T(key, params?)          -- Obtém tradução com parâmetros opcionais
_P(key, params)           -- Alias de _T com parâmetros obrigatórios  
_N(key, count, params?)   -- Para traduções numéricas/plurais (future-proof)

-- Funções de controle de idioma
SetLanguage(languageId)   -- Define idioma ativo ("pt_BR" | "en")
GetCurrentLanguage()      -- Obtém idioma atual
```

### Exemplos de Uso Básico

```lua
-- Traduções simples
local loading = _T("general.loading")           -- "Carregando..."
local error = _T("general.error")               -- "Erro"

-- Traduções de interface
local health = _T("ui.health")                  -- "Vida"
local inventory = _T("ui.inventory")            -- "Inventário"

-- Traduções com parâmetros
local msg = _T("system.language_changed", { language = "English" })
-- Result: "Idioma alterado para: English"

-- Mudança de idioma
SetLanguage("en")
local loading_en = _T("general.loading")        -- "Loading..."
SetLanguage("pt_BR")
```

## Estrutura Hierárquica das Chaves

As chaves de tradução seguem uma estrutura hierárquica com pontos:

```lua
-- Formato: categoria.subcategoria.propriedade
"general.loading"                    -- Sistema geral
"ui.health"                          -- Interface do usuário  
"weapons.cone_slash_e_001.name"      -- Nome de arma específica
"archetypes.agile.description"       -- Descrição de arquétipo
"ranks.S.name"                       -- Nome de rank
"system.language_changed"           -- Mensagens do sistema
```

## Integração com Dados Existentes

### Armas (weapons.lua)

Cada arma agora possui métodos de localização:

```lua
local weapons = require("src.data.items.weapons")
local sword = weapons.cone_slash_e_001

-- Método tradicional (mantido para compatibilidade)
print(sword.name)                    -- "Espada de Ferro" (hardcoded)

-- Métodos localizados (novos)
print(sword:getLocalizedName())      -- "Espada de Ferro" ou "Iron Sword"
print(sword:getLocalizedDescription()) -- Descrição localizada
```

### Arquétipos (archetypes_data.lua)

Similar às armas, os arquétipos têm métodos de localização:

```lua
local archetypes = require("src.data.archetypes_data")
local agile = archetypes.Archetypes.agile

print(agile:getLocalizedName())      -- "Ágil" ou "Agile"
print(agile:getLocalizedDescription()) -- Descrição localizada
```

### Ranks

Os ranks também suportam localização:

```lua
local ranks = archetypes.Ranks
local rankS = ranks.S

print(rankS:getLocalizedName())      -- "Rank S"
print(rankS:getLocalizedDescription()) -- Descrição localizada
```

## Funções Auxiliares Avançadas

O módulo `LocalizationHelpers` oferece funcionalidades avançadas:

```lua
-- Verificação de existência de chaves
if LocalizationHelpers.keyExists("weapons.new_weapon.name") then
    -- Chave existe
end

-- Informações específicas por tipo
local weaponName, weaponDesc = LocalizationHelpers.getWeaponInfo("bow")
local archetypeName, archetypeDesc = LocalizationHelpers.getArchetypeInfo("agile")
local rankName, rankDesc = LocalizationHelpers.getRankInfo("A")

-- Controle de idiomas
local availableLanguages = LocalizationHelpers.getAvailableLanguages()
local currentLang = LocalizationHelpers.getCurrentLanguage()

-- Estatísticas do sistema
local stats = LocalizationHelpers.getStats()
print("Idiomas carregados:", table.concat(stats.loadedLanguages, ", "))

-- Recarregamento (desenvolvimento)
LocalizationHelpers.reload()
```

## Validação com LDoc

O sistema inclui tipos LDoc para validação das chaves:

```lua
---@param key LocalizationKey A chave da tradução
---@param params table|nil Parâmetros opcionais
function myFunction(key, params)
    return _T(key, params)
end

-- Tipos específicos também estão disponíveis:
---@param weaponKey WeaponLocalizationKey
---@param archetypeKey ArchetypeLocalizationKey
```

Os tipos incluem todas as chaves válidas como autocomplete e validação.

## Adicionando Novas Traduções

### 1. Adicionar nos Arquivos de Tradução

**pt_BR.lua:**
```lua
weapons = {
    new_weapon_id = {
        name = "Nome da Nova Arma",
        description = "Descrição em português"
    }
}
```

**en.lua:**
```lua
weapons = {
    new_weapon_id = {
        name = "New Weapon Name", 
        description = "Description in English"
    }
}
```

### 2. Atualizar Tipos LDoc

Adicionar a nova chave nos tipos em `localization_helpers.lua`:

```lua
---@alias WeaponLocalizationKey
---| "weapons.new_weapon_id.name"
---| "weapons.new_weapon_id.description"
```

### 3. Usar no Código

```lua
-- Direto
local name = _T("weapons.new_weapon_id.name")

-- Ou via helper
local name, desc = LocalizationHelpers.getWeaponInfo("new_weapon_id")
```

## Adicionando Novos Idiomas

### 1. Criar Arquivo de Tradução

Criar `src/data/translations/[codigo].lua`:

```lua
local translations = {
    general = {
        loading = "Chargement...",  -- francês
        error = "Erreur"
    },
    -- ... resto das traduções
}

return translations
```

### 2. Atualizar LocalizationManager

Em `localization_manager.lua`, adicionar o novo idioma:

```lua
self.availableLanguages = {
    pt_BR = { id = "pt_BR", name = "Português (Brasil)", fallback = nil },
    en = { id = "en", name = "English", fallback = "pt_BR" },
    fr = { id = "fr", name = "Français", fallback = "pt_BR" }  -- novo
}
```

### 3. Atualizar Tipos LDoc

Atualizar os tipos para incluir o novo idioma:

```lua
---@param languageId "pt_BR"|"en"|"fr" ID do idioma
```

## Sistema de Fallback

O sistema possui fallback automático:

1. **Busca na língua atual**: Se `_T("some.key")` for chamado em inglês
2. **Fallback para português**: Se não encontrar, busca em pt_BR
3. **Retorna a chave**: Se ainda não encontrar, retorna a própria chave

Exemplo:
```lua
SetLanguage("en")
_T("key.only.in.portuguese")  -- Retorna valor de pt_BR automaticamente
_T("completely.missing.key")  -- Retorna "completely.missing.key"
```

## Performance

- **Singleton Manager**: Uma única instância gerencia todo o sistema
- **Cache de traduções**: Idiomas carregados permanecem em memória
- **Carregamento lazy**: Idiomas são carregados apenas quando necessário
- **Navegação eficiente**: Estrutura hierárquica otimizada para busca

## Testes e Debug

### Funções de Teste Globais

```lua
-- No console do jogo (modo DEV)
TestLocalization()              -- Executa todos os exemplos
TestLocalizationBasic()         -- Testa funcionalidades básicas
TestLocalizationLanguages()     -- Testa troca de idiomas
TestLocalizationStats()         -- Mostra estatísticas do sistema
```

### Logs de Debug

O sistema usa o Logger do projeto:

```lua
-- Logs de inicialização
Logger.info("localization_manager.initialize", "Sistema inicializado")

-- Logs de mudança de idioma  
Logger.info("localization_manager.set_language", "Idioma alterado para: en")

-- Logs de fallback
Logger.debug("localization_manager.fallback", "Usando fallback para chave: missing.key")
```

## Melhores Práticas

### ✅ Recomendado

```lua
-- Use as funções globais
local text = _T("ui.health")

-- Use os métodos localizados dos objetos
weapon:getLocalizedName()

-- Organize chaves hierarquicamente
"category.subcategory.property"

-- Verifique existência quando necessário
if LocalizationHelpers.keyExists(key) then
    return _T(key)
end
```

### ❌ Evite

```lua
-- Não acesse o manager diretamente
LocalizationManager:getInstance():getText(key)  -- Use _T(key)

-- Não use hardcoded quando há localização disponível
"Vida"  -- Use _T("ui.health")

-- Não crie chaves muito profundas
"a.very.deep.nested.key.that.is.hard.to.read"

-- Não ignore o sistema de fallback
-- O fallback funciona automaticamente
```

## Migração Gradual

O sistema foi projetado para migração gradual:

1. **Código antigo continua funcionando**: `weapon.name` ainda funciona
2. **Novos métodos disponíveis**: `weapon:getLocalizedName()` para localização
3. **Migração opcional**: Pode migrar código antigo quando conveniente

## Exemplo Completo de Uso

```lua
-- Em uma função de interface
function createWeaponTooltip(weaponId)
    local weapons = require("src.data.items.weapons")
    local weapon = weapons[weaponId]
    
    if not weapon then return nil end
    
    return {
        title = weapon:getLocalizedName(),     -- Nome localizado
        description = weapon:getLocalizedDescription(), -- Descrição localizada
        damage = weapon.damage,
        rarity = _T("ui.rarity") .. ": " .. _T("ranks." .. weapon.rank .. ".name"),
        buttons = {
            equip = _T("general.confirm"),
            cancel = _T("general.cancel")
        }
    }
end
```

Este sistema fornece uma base sólida para internacionalização completa do Solo Hero, mantendo flexibilidade para expansões futuras e facilidade de uso para desenvolvedores. 