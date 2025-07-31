# Exemplos de Fontes Adaptativas

## Como usar o scaleText com fonts.lua

### 1. Uso Básico - Fontes Adaptativas Prontas

```lua
local fonts = require("src.ui.fonts")

-- Obtém todas as fontes com tamanhos adaptativos
local adaptiveFonts = fonts.getAdaptive()

function draw()
    -- Usa fonte adaptativa automaticamente
    love.graphics.setFont(adaptiveFonts.main)      -- 16px -> adaptado para dispositivo
    love.graphics.print("Texto principal", 100, 100)
    
    love.graphics.setFont(adaptiveFonts.title)     -- 24px -> adaptado para dispositivo  
    love.graphics.print("Título", 100, 50)
    
    love.graphics.setFont(adaptiveFonts.hud)       -- 15px -> adaptado para dispositivo
    love.graphics.print("HUD Info", 10, 10)
end
```

### 2. Função de Conveniência

```lua
-- Forma mais simples para obter uma fonte específica adaptativa
local titleFont = fonts.getAdaptiveFont("title")
local hudFont = fonts.getAdaptiveFont("hud")

love.graphics.setFont(titleFont)
love.graphics.print("Título Adaptativo", x, y)
```

### 3. Criação Dinâmica de Fontes Adaptativas

```lua
-- Cria fontes personalizadas com escala adaptativa
local customFont = fonts.createAdaptive("assets/fonts/MyFont.ttf", 20)
local boldCustomFont = fonts.createAdaptive("assets/fonts/MyFont-Bold.ttf", 18, "custom_bold")

love.graphics.setFont(customFont)
love.graphics.print("Fonte personalizada adaptativa", x, y)
```

### 4. Uso Direto do ResolutionUtils.scaleText()

```lua
-- Para casos onde você quer controle total
local baseSize = 16
local adaptiveSize = ResolutionUtils.scaleText(baseSize)
local manualFont = love.graphics.newFont("assets/fonts/Rajdhani-Medium.ttf", adaptiveSize)

love.graphics.setFont(manualFont)
```

## Exemplos Práticos de Migração

### ANTES (código atual)
```lua
-- src/ui/components/Text.lua
local Text = {}

function Text:new(text, size)
    local font = fonts.main
    if size == "title" then
        font = fonts.title
    elseif size == "small" then
        font = fonts.main_small
    end
    
    return {
        text = text,
        font = font
    }
end

function Text:draw()
    love.graphics.setFont(self.font)
    love.graphics.print(self.text, self.x, self.y)
end
```

### DEPOIS (com adaptação)
```lua
-- src/ui/components/Text.lua
local Text = {}

function Text:new(text, size, useAdaptive)
    useAdaptive = useAdaptive ~= false -- Padrão true
    
    local font
    if useAdaptive then
        -- Usa fontes adaptativas
        local adaptiveFonts = fonts.getAdaptive()
        if size == "title" then
            font = adaptiveFonts.title
        elseif size == "small" then
            font = adaptiveFonts.main_small
        else
            font = adaptiveFonts.main
        end
    else
        -- Mantém comportamento original
        font = fonts.main
        if size == "title" then
            font = fonts.title
        elseif size == "small" then
            font = fonts.main_small
        end
    end
    
    return {
        text = text,
        font = font,
        useAdaptive = useAdaptive
    }
end

function Text:draw()
    love.graphics.setFont(self.font)
    love.graphics.print(self.text, self.x, self.y)
end
```

## Exemplos por Tipo de Componente

### 1. Modal de Detalhes de Item

```lua
-- item_details_modal.lua - MIGRAÇÃO GRADUAL

-- ANTES
function ItemDetailsModal.draw(item, x, y)
    love.graphics.setFont(fonts.title)
    love.graphics.print(item.name, x + 10, y + 10)
    
    love.graphics.setFont(fonts.main)
    love.graphics.print(item.description, x + 10, y + 50)
end

-- DEPOIS (gradual)
function ItemDetailsModal.draw(item, x, y)
    -- Verifica se deve usar fontes adaptativas
    local useAdaptive = ResolutionUtils.needsAdaptiveScale()
    
    if useAdaptive then
        local adaptiveFonts = fonts.getAdaptive()
        love.graphics.setFont(adaptiveFonts.title)
        love.graphics.print(item.name, x + 10, y + 10)
        
        love.graphics.setFont(adaptiveFonts.main)
        love.graphics.print(item.description, x + 10, y + 50)
    else
        -- Comportamento original para desktop
        love.graphics.setFont(fonts.title)
        love.graphics.print(item.name, x + 10, y + 10)
        
        love.graphics.setFont(fonts.main)
        love.graphics.print(item.description, x + 10, y + 50)
    end
end
```

### 2. HUD de Gameplay

```lua
-- hud_gameplay_manager.lua

function HUDGameplayManager:drawPlayerStats()
    local adaptiveFonts = fonts.getAdaptive()
    
    -- Informações de vida
    love.graphics.setFont(adaptiveFonts.hud)
    love.graphics.print("HP: " .. player.health, 10, 10)
    
    -- Level do jogador
    love.graphics.setFont(adaptiveFonts.main_bold)
    love.graphics.print("Lv." .. player.level, 10, 35)
    
    -- Experiência
    love.graphics.setFont(adaptiveFonts.main_small)
    love.graphics.print("XP: " .. player.experience, 10, 60)
end
```

### 3. Botões Adaptativos

```lua
-- button_component.lua

function Button:new(text, x, y, width, height, style)
    local adaptiveFonts = fonts.getAdaptive()
    
    -- Escolhe fonte baseada no estilo
    local font = adaptiveFonts.main
    if style == "title" then
        font = adaptiveFonts.title
    elseif style == "small" then
        font = adaptiveFonts.main_small
    end
    
    return {
        text = text,
        x = x,
        y = y,
        width = ResolutionUtils.scaleUI(width, height),
        height = ResolutionUtils.scaleUI(width, height),
        font = font,
        padding = ResolutionUtils.scaleSpacing(10)
    }
end

function Button:draw()
    -- Desenha fundo do botão
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    -- Desenha texto centralizado
    love.graphics.setFont(self.font)
    local textWidth = self.font:getWidth(self.text)
    local textHeight = self.font:getHeight()
    local textX = self.x + (self.width - textWidth) / 2
    local textY = self.y + (self.height - textHeight) / 2
    
    love.graphics.print(self.text, textX, textY)
end
```

### 4. Sistema de Notificações

```lua
-- notification_display.lua

function NotificationDisplay.drawNotification(notification, x, y)
    local adaptiveFonts = fonts.getAdaptive()
    
    -- Título da notificação
    love.graphics.setFont(adaptiveFonts.main_bold)
    love.graphics.print(notification.title, x + 10, y + 5)
    
    -- Mensagem da notificação
    love.graphics.setFont(adaptiveFonts.main_small)
    love.graphics.print(notification.message, x + 10, y + 25)
    
    -- Timer (se houver)
    if notification.timer then
        love.graphics.setFont(adaptiveFonts.tooltip)
        love.graphics.print(string.format("%.1fs", notification.timer), x + 10, y + 45)
    end
end
```

## Função com Tamanho Dinâmico

### getFittingBoldFontAdaptive - Para textos que precisam caber em espaço específico

```lua
-- Exemplo: Nome de item que precisa caber em slot de inventário
function InventorySlot:drawItemName(item, slotX, slotY, slotWidth, slotHeight)
    local maxTextWidth = ResolutionUtils.scaleUI(slotWidth - 20, slotHeight) -- Margem de 10px cada lado
    local maxTextHeight = ResolutionUtils.scaleUI(slotWidth - 20, slotHeight) / 3 -- 1/3 da altura do slot
    
    -- Fonte que se ajusta automaticamente ao espaço disponível COM escala adaptativa
    local fittingFont = fonts.getFittingBoldFontAdaptive(
        item.name,           -- Texto
        maxTextWidth,        -- Largura máxima
        maxTextHeight,       -- Altura máxima  
        24,                  -- Tamanho inicial (será escalado)
        8                    -- Tamanho mínimo (será escalado)
    )
    
    love.graphics.setFont(fittingFont)
    love.graphics.print(item.name, slotX + 10, slotY + slotHeight - 30)
end
```

## Testando o Sistema

### Função de Debug

```lua
-- Adicione no seu código de debug para ver as escalas em ação
function debugFontScaling()
    if not DEV then return end
    
    local y = 100
    local x = 50
    local fonts = require("src.ui.fonts")
    local adaptiveFonts = fonts.getAdaptive()
    
    -- Mostra fontes originais vs adaptativas
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Original
    love.graphics.setFont(fonts.main)
    love.graphics.print("Original (16px): " .. fonts.main:getHeight() .. "px", x, y)
    
    -- Adaptativa
    love.graphics.setFont(adaptiveFonts.main)
    love.graphics.print("Adaptativa: " .. adaptiveFonts.main:getHeight() .. "px", x, y + 30)
    
    -- Info do dispositivo
    local info = ResolutionUtils.getAdaptiveInfo()
    love.graphics.setFont(fonts.main_small)
    love.graphics.print(string.format("Dispositivo: %s | Escala Text: %.2fx", 
        info.adaptive.deviceType, info.adaptive.currentScales.text), x, y + 60)
end

-- Chame na função draw() em modo DEV
if DEV then
    debugFontScaling()
end
```

## Dicas de Performance

### 1. Cache as fontes adaptativas
```lua
-- BOA PRÁTICA: Cache fontes em componentes que são redesenhados frequentemente
function MyComponent:init()
    -- Cache as fontes uma vez na inicialização
    local adaptiveFonts = fonts.getAdaptive()
    self.titleFont = adaptiveFonts.title
    self.textFont = adaptiveFonts.main
    self.smallFont = adaptiveFonts.main_small
end

function MyComponent:draw()
    -- Usa fontes do cache - mais rápido
    love.graphics.setFont(self.titleFont)
    -- ...
end
```

### 2. Limpe o cache quando necessário
```lua
-- Quando mudar configurações de escala, limpe o cache
function Settings:changeAdaptivePreset(newPreset)
    AdaptiveConfig.setActivePreset(newPreset)
    AdaptiveScaleManager.initialize(AdaptiveConfig.getActiveConfig())
    
    -- Limpa cache de fontes para recriar com novas escalas
    fonts.clearAdaptiveCache()
end
```

### 3. Use verificação condicional
```lua
-- Para elementos que mudam muito frequentemente
function FastUpdatingComponent:draw()
    if ResolutionUtils.needsAdaptiveScale() then
        love.graphics.setFont(fonts.getAdaptiveFont("main"))
    else
        love.graphics.setFont(fonts.main) -- Desktop: sem overhead de escala
    end
end
```

## Compatibilidade

### ✅ Totalmente Compatível
- Todo código existente com `fonts.main`, `fonts.title`, etc. continua funcionando
- Sistema adaptativo é opcional - só afeta quando usado
- Fallbacks seguros para quando ResolutionUtils não está disponível

### 📱 Funciona Automaticamente
- Mobile: Fontes automaticamente maiores
- Tablet: Fontes ligeiramente maiores 
- Desktop: Tamanhos originais mantidos