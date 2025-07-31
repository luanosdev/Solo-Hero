# Exemplos de Integração do Sistema Adaptativo

## Exemplo 1: Integração no main.lua

```lua
-- main.lua - Adicione após a inicialização do ResolutionUtils

-- Inicializa o ResolutionUtils com a instância do push
ResolutionUtils.initialize(push)
_G.ResolutionUtils = ResolutionUtils

-- NOVO: Inicializa sistema adaptativo
local AdaptiveScaleManager = require("src.utils.adaptive_scale_manager")
local AdaptiveConfig = require("src.config.adaptive_config")

-- Inicializa com configuração padrão (ou mude para outro preset)
AdaptiveScaleManager.initialize(AdaptiveConfig.getActiveConfig())

Logger.info("main.adaptive.initialized", "[main.love.load] Sistema de medidas adaptativas inicializado")
```

## Exemplo 2: Adaptando UI de Botões

### ANTES (código atual)
```lua
-- src/ui/components/Button.lua
local Button = {}

function Button:new(text, x, y, width, height)
    return {
        text = text,
        x = x,
        y = y,
        width = width or 200,
        height = height or 50,
        fontSize = 16
    }
end

function Button:draw()
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setFont(fonts.main)
    love.graphics.print(self.text, self.x + 10, self.y + 10)
end
```

### DEPOIS (com adaptação gradual)
```lua
-- src/ui/components/Button.lua
local Button = {}

function Button:new(text, x, y, width, height)
    -- Aplica escala adaptativa na criação
    local scaledWidth = ResolutionUtils.scaleUI(width or 200, height or 50)
    local scaledHeight = ResolutionUtils.scaleUI(width or 200, height or 50)
    local scaledPadding = ResolutionUtils.scaleSpacing(10)
    
    return {
        text = text,
        x = x,
        y = y,
        width = scaledWidth,
        height = scaledHeight,
        fontSize = ResolutionUtils.scaleText(16),
        padding = scaledPadding
    }
end

function Button:draw()
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    -- Usa fonte adaptativa
    local font = love.graphics.newFont(self.fontSize)
    love.graphics.setFont(font)
    love.graphics.print(self.text, self.x + self.padding, self.y + self.padding)
end
```

## Exemplo 3: Adaptando Sistema de Fontes

### ANTES (fonts.lua atual)
```lua
-- src/ui/fonts.lua
function fonts.load()
    fonts.main_small = love.graphics.newFont(main_font_file, 14)
    fonts.main = love.graphics.newFont(main_font_file, 16)
    fonts.main_large = love.graphics.newFont(main_font_file, 18)
    fonts.title = love.graphics.newFont(bold_font_file, 24)
end
```

### DEPOIS (com escala adaptativa)
```lua
-- src/ui/fonts.lua
function fonts.load()
    -- Tamanhos base
    local sizes = {
        main_small = 14,
        main = 16,
        main_large = 18,
        title = 24
    }
    
    -- Aplica escala adaptativa
    fonts.main_small = love.graphics.newFont(main_font_file, ResolutionUtils.scaleText(sizes.main_small))
    fonts.main = love.graphics.newFont(main_font_file, ResolutionUtils.scaleText(sizes.main))
    fonts.main_large = love.graphics.newFont(main_font_file, ResolutionUtils.scaleText(sizes.main_large))
    fonts.title = love.graphics.newFont(bold_font_file, ResolutionUtils.scaleText(sizes.title))
end

-- Função utilitária para criar fontes adaptativas em runtime
function fonts.createAdaptive(fontFile, baseSize)
    local adaptiveSize = ResolutionUtils.scaleText(baseSize)
    return love.graphics.newFont(fontFile, adaptiveSize)
end
```

## Exemplo 4: Adaptando HUD de Gameplay

### ANTES (hud_gameplay_manager.lua)
```lua
-- Constantes de layout
local HEALTH_BAR_WIDTH = 200
local HEALTH_BAR_HEIGHT = 20
local HEALTH_BAR_X = 50
local HEALTH_BAR_Y = 50
local ICON_SIZE = 32

function HUDGameplayManager:drawHealthBar()
    -- Desenha barra de vida
    love.graphics.rectangle("fill", HEALTH_BAR_X, HEALTH_BAR_Y, HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
    
    -- Desenha ícone de vida
    love.graphics.draw(healthIcon, HEALTH_BAR_X - ICON_SIZE - 10, HEALTH_BAR_Y)
end
```

### DEPOIS (com escala adaptativa)
```lua
-- Constantes base (valores originais)
local BASE_HEALTH_BAR_WIDTH = 200
local BASE_HEALTH_BAR_HEIGHT = 20
local BASE_HEALTH_BAR_X = 50
local BASE_HEALTH_BAR_Y = 50
local BASE_ICON_SIZE = 32
local BASE_SPACING = 10

function HUDGameplayManager:drawHealthBar()
    -- Aplica escalas adaptativas
    local healthBarWidth = ResolutionUtils.scaleAdaptive(BASE_HEALTH_BAR_WIDTH, "hud")
    local healthBarHeight = ResolutionUtils.scaleAdaptive(BASE_HEALTH_BAR_HEIGHT, "hud")
    local healthBarX = ResolutionUtils.scaleSpacing(BASE_HEALTH_BAR_X)
    local healthBarY = ResolutionUtils.scaleSpacing(BASE_HEALTH_BAR_Y)
    local iconSize = ResolutionUtils.scaleIcon(BASE_ICON_SIZE)
    local spacing = ResolutionUtils.scaleSpacing(BASE_SPACING)
    
    -- Desenha barra de vida
    love.graphics.rectangle("fill", healthBarX, healthBarY, healthBarWidth, healthBarHeight)
    
    -- Desenha ícone de vida
    love.graphics.draw(healthIcon, healthBarX - iconSize - spacing, healthBarY, 0, iconSize/32, iconSize/32)
end
```

## Exemplo 5: Modal Adaptativo

### ANTES (item_details_modal.lua)
```lua
-- Constantes para layout
local PADDING = 10
local ICON_SIZE = 64
local MIN_MODAL_HEIGHT = 200

function ItemDetailsModal.draw(item, x, y)
    local modalWidth = 400
    local modalHeight = 300
    
    -- Desenha fundo do modal
    love.graphics.rectangle("fill", x, y, modalWidth, modalHeight)
    
    -- Desenha ícone do item
    love.graphics.draw(item.icon, x + PADDING, y + PADDING, 0, ICON_SIZE/32, ICON_SIZE/32)
end
```

### DEPOIS (com escala adaptativa)
```lua
-- Constantes base
local BASE_PADDING = 10
local BASE_ICON_SIZE = 64
local BASE_MIN_MODAL_HEIGHT = 200
local BASE_MODAL_WIDTH = 400
local BASE_MODAL_HEIGHT = 300

function ItemDetailsModal.draw(item, x, y)
    -- Aplica escalas adaptativas
    local padding = ResolutionUtils.scaleSpacing(BASE_PADDING)
    local iconSize = ResolutionUtils.scaleIcon(BASE_ICON_SIZE)
    local modalWidth = ResolutionUtils.scaleUI(BASE_MODAL_WIDTH, BASE_MODAL_HEIGHT)
    local modalHeight = ResolutionUtils.scaleUI(BASE_MODAL_WIDTH, BASE_MODAL_HEIGHT)
    
    -- Desenha fundo do modal
    love.graphics.rectangle("fill", x, y, modalWidth, modalHeight)
    
    -- Desenha ícone do item (com escala proporcional)
    local iconScale = iconSize / 32  -- Assumindo ícone original 32x32
    love.graphics.draw(item.icon, x + padding, y + padding, 0, iconScale, iconScale)
end
```

## Exemplo 6: Verificação Condicional por Dispositivo

```lua
-- Exemplo: Comportamento específico para mobile
function SomeUIComponent:update(dt)
    if ResolutionUtils.needsAdaptiveScale() then
        -- Mobile/Tablet: atualização mais lenta para economia de bateria
        self.updateInterval = 0.1
    else
        -- Desktop: atualização mais rápida
        self.updateInterval = 0.05
    end
end

function SomeUIComponent:draw()
    local info = ResolutionUtils.getAdaptiveInfo()
    
    if info.adaptive.deviceInfo.inputMethod == "touch" then
        -- Mobile: botões maiores e mais espaçados
        self:drawTouchFriendlyButtons()
    else
        -- Desktop: layout compacto
        self:drawCompactButtons()
    end
end
```

## Exemplo 7: Sistema de Debug Adaptativo

```lua
-- Função utilitária para debug do sistema adaptativo
function debugAdaptiveSystem()
    local info = ResolutionUtils.getAdaptiveInfo()
    
    print("=== SISTEMA ADAPTATIVO ===")
    print("Dispositivo:", info.adaptive.deviceInfo.type)
    print("Categoria Tela:", info.adaptive.deviceInfo.screenCategory)
    print("Método Input:", info.adaptive.deviceInfo.inputMethod)
    print("Precisa Escala:", info.adaptive.needsAdaptiveScale)
    
    print("\n--- ESCALAS ATUAIS ---")
    for category, scale in pairs(info.adaptive.currentScales) do
        print(string.format("%s: %.2fx", category, scale))
    end
    
    print("\n--- EXEMPLO DE CONVERSÕES ---")
    print(string.format("Botão 200x50 -> %.0fx%.0f", 
        ResolutionUtils.scaleUI(200, 50)))
    print(string.format("Fonte 16px -> %.0fpx", 
        ResolutionUtils.scaleText(16)))
    print(string.format("Ícone 32px -> %.0fpx", 
        ResolutionUtils.scaleIcon(32)))
end

-- Chame em modo DEV para testar
if DEV then
    debugAdaptiveSystem()
end
```

## Exemplo 8: Migração Gradual de Arquivo Existente

```lua
-- ESTRATÉGIA: Migre um arquivo por vez, função por função

-- PASSO 1: Identifique valores hardcoded
local OLD_BUTTON_WIDTH = 200  -- ❌ Hardcoded

-- PASSO 2: Extraia como constantes base
local BASE_BUTTON_WIDTH = 200  -- ✅ Valor base

-- PASSO 3: Aplique escala onde necessário
local buttonWidth = ResolutionUtils.scaleUI(BASE_BUTTON_WIDTH, 50)  -- ✅ Adaptativo

-- PASSO 4: Teste e ajuste
-- Se muito grande/pequeno, ajuste os fatores de escala no preset
```

## Dicas de Implementação

### ✅ Boas Práticas
- Sempre mantenha valores base como constantes
- Use categorias apropriadas (`ui`, `text`, `spacing`, `icons`, `hud`)
- Teste em dispositivos reais quando possível
- Aplique escala na criação de objetos, não a cada frame
- Use preset "development" para isolar problemas

### ⚠️ Cuidados
- Não aplique escala dupla (valor já escalado)
- Teste performance com muitos elementos
- Alguns elementos podem precisar ajuste manual
- Monitore logs para erros de detecção de dispositivo

### 🔧 Debugging
- Use `ResolutionUtils.getAdaptiveInfo()` para debug
- Verifique logs do `DeviceDetector` e `AdaptiveScaleManager`
- Teste com diferentes presets para encontrar configuração ideal