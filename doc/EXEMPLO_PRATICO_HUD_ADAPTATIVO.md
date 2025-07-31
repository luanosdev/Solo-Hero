# Exemplo Prático: HUD Adaptativo

## Implementação Real no HUDGameplayManager

Vou mostrar como adaptar o `HUDGameplayManager` atual para usar fontes adaptativas de forma gradual.

### ANTES (código atual)
```lua
-- src/scenes/gameplay/managers/hud_gameplay_manager.lua

function HUDGameplayManager:_drawEnemyDebugInfo()
    local enemyManager = self.context.registry:getEnemyManager()
    local info = enemyManager:getDebugInfo()
    if not info then return end

    love.graphics.setFont(fonts.main)
    love.graphics.setColor(1, 1, 1)

    local x = 10
    local y = 10
    local lineHeight = fonts.main:getHeight()

    love.graphics.print("--- Enemy Culling Debug ---", x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Total: %d", info.total), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Active (Full Logic): %d", info.active), x, y)
    y = y + lineHeight
    love.graphics.print(string.format("Slow (Anim Only): %d", info.slow), x, y)
end
```

### DEPOIS (com sistema adaptativo)
```lua
-- src/scenes/gameplay/managers/hud_gameplay_manager.lua

function HUDGameplayManager:init()
    local playerManager = self.context.registry:getPlayerManager()
    
    -- Cache fontes adaptativas na inicialização para performance
    local adaptiveFonts = fonts.getAdaptive()
    self.fonts = {
        hud = adaptiveFonts.hud,           -- Para informações gerais do HUD
        debug = adaptiveFonts.main_small,  -- Para informações de debug
        title = adaptiveFonts.main_bold,   -- Para títulos de seções
        stats = adaptiveFonts.main         -- Para stats do jogador
    }
    
    -- Cache espaçamentos adaptativos
    self.spacing = {
        margin = ResolutionUtils.scaleSpacing(10),
        lineHeight = ResolutionUtils.scaleSpacing(5),
        sectionGap = ResolutionUtils.scaleSpacing(20)
    }
end

function HUDGameplayManager:_drawEnemyDebugInfo()
    local enemyManager = self.context.registry:getEnemyManager()
    local info = enemyManager:getDebugInfo()
    if not info then return end

    love.graphics.setColor(1, 1, 1)
    local x = self.spacing.margin
    local y = self.spacing.margin

    -- Título da seção com fonte adaptativa
    love.graphics.setFont(self.fonts.title)
    love.graphics.print("--- Enemy Culling Debug ---", x, y)
    y = y + self.fonts.title:getHeight() + self.spacing.lineHeight

    -- Informações com fonte adaptativa de debug
    love.graphics.setFont(self.fonts.debug)
    local debugLineHeight = self.fonts.debug:getHeight() + self.spacing.lineHeight
    
    love.graphics.print(string.format("Total: %d", info.total), x, y)
    y = y + debugLineHeight
    love.graphics.print(string.format("Active (Full Logic): %d", info.active), x, y)
    y = y + debugLineHeight
    love.graphics.print(string.format("Slow (Anim Only): %d", info.slow), x, y)
end

-- Nova função: HUD completo com informações do jogador
function HUDGameplayManager:_drawPlayerHUD()
    local playerManager = self.context.registry:getPlayerManager()
    if not playerManager then return end
    
    local gameWidth = ResolutionUtils.getGameWidth()
    local gameHeight = ResolutionUtils.getGameHeight()
    
    -- Posição do HUD do jogador (canto superior esquerdo)
    local hudX = self.spacing.margin
    local hudY = self.spacing.margin
    
    love.graphics.setColor(1, 1, 1)
    
    -- Título "Player Stats"
    love.graphics.setFont(self.fonts.title)
    love.graphics.print("Player", hudX, hudY)
    hudY = hudY + self.fonts.title:getHeight() + self.spacing.lineHeight
    
    -- Stats do jogador
    love.graphics.setFont(self.fonts.stats)
    local statsLineHeight = self.fonts.stats:getHeight() + self.spacing.lineHeight
    
    -- Exemplo de stats (adapte conforme seu PlayerManager)
    local playerState = playerManager.stateController -- Adaptado para nova arquitetura
    if playerState then
        love.graphics.print(string.format("HP: %d/%d", 
            playerState:getCurrentHealth(), 
            playerState:getMaxHealth()), hudX, hudY)
        hudY = hudY + statsLineHeight
        
        love.graphics.print(string.format("Level: %d", 
            playerState:getLevel()), hudX, hudY)
        hudY = hudY + statsLineHeight
        
        love.graphics.print(string.format("XP: %d", 
            playerState:getExperience()), hudX, hudY)
    end
end

function HUDGameplayManager:draw(isPaused)
    -- Desenha HUD completo do jogador
    self:_drawPlayerHUD()
    
    -- Desenha informações de debug (apenas em modo DEV)
    if DEV then
        -- Posiciona debug info no lado direito da tela
        local gameWidth = ResolutionUtils.getGameWidth()
        local debugX = gameWidth - 250 -- Ajustado para tela adaptativa
        
        love.graphics.push()
        love.graphics.translate(debugX - self.spacing.margin, 0)
        self:_drawEnemyDebugInfo()
        love.graphics.pop()
    end
end
```

## Resultado da Adaptação

### Desktop (1920x1080)
- Fontes mantêm tamanho original
- Layout compacto
- Informações bem organizadas

### Mobile/Tablet
- Fontes automaticamente maiores para melhor legibilidade
- Espaçamentos aumentados para touch
- Layout se adapta ao tamanho da tela

## Exemplo Completo: HUD com Barras de Vida Adaptativas

```lua
-- Função adicional: Barra de vida adaptativa
function HUDGameplayManager:_drawAdaptiveHealthBar()
    local playerManager = self.context.registry:getPlayerManager()
    if not playerManager then return end
    
    local playerState = playerManager.stateController
    if not playerState then return end
    
    -- Dimensões adaptativas da barra
    local barWidth = ResolutionUtils.scaleUI(200, 20)
    local barHeight = ResolutionUtils.scaleUI(200, 20)
    local x = self.spacing.margin
    local y = ResolutionUtils.getGameHeight() - barHeight - self.spacing.margin
    
    -- Background da barra
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)
    
    -- Barra de vida
    local healthRatio = playerState:getCurrentHealth() / playerState:getMaxHealth()
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", x, y, barWidth * healthRatio, barHeight)
    
    -- Borda da barra
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", x, y, barWidth, barHeight)
    
    -- Texto da vida (adaptativo)
    love.graphics.setFont(self.fonts.hud)
    local healthText = string.format("%d/%d", 
        playerState:getCurrentHealth(), 
        playerState:getMaxHealth())
    
    -- Centraliza texto na barra
    local textWidth = self.fonts.hud:getWidth(healthText)
    local textHeight = self.fonts.hud:getHeight()
    local textX = x + (barWidth - textWidth) / 2
    local textY = y + (barHeight - textHeight) / 2
    
    love.graphics.print(healthText, textX, textY)
end

-- Atualiza a função draw principal
function HUDGameplayManager:draw(isPaused)
    -- HUD do jogador
    self:_drawPlayerHUD()
    
    -- Barra de vida adaptativa
    self:_drawAdaptiveHealthBar()
    
    -- Debug info (apenas DEV)
    if DEV then
        local gameWidth = ResolutionUtils.getGameWidth()
        local debugX = gameWidth - ResolutionUtils.scaleUI(250, 100)
        
        love.graphics.push()
        love.graphics.translate(debugX - self.spacing.margin, 0)
        self:_drawEnemyDebugInfo()
        love.graphics.pop()
    end
end
```

## Como Testar

### 1. Simulação no Main.lua
```lua
-- Para testar diferentes dispositivos em desenvolvimento
function love.keypressed(key)
    if DEV and key == "f1" then
        -- Simula mobile
        AdaptiveConfig.setActivePreset("default")
        AdaptiveScaleManager.initialize(AdaptiveConfig.getActiveConfig())
        fonts.clearAdaptiveCache()
        Logger.info("test.mobile_simulation", "Simulando dispositivo mobile")
    elseif DEV and key == "f2" then
        -- Simula desktop
        AdaptiveConfig.setActivePreset("development")
        AdaptiveScaleManager.initialize(AdaptiveConfig.getActiveConfig())
        fonts.clearAdaptiveCache()
        Logger.info("test.desktop_simulation", "Simulando dispositivo desktop")
    end
end
```

### 2. Debug Visual
```lua
-- Adicione ao HUDGameplayManager:draw() para visualizar escalas
function HUDGameplayManager:_drawAdaptiveDebug()
    if not DEV then return end
    
    local info = ResolutionUtils.getAdaptiveInfo()
    local debugY = ResolutionUtils.getGameHeight() - 100
    
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(1, 1, 0, 0.8) -- Amarelo
    
    love.graphics.print(string.format("Dispositivo: %s", info.adaptive.deviceType), 10, debugY)
    love.graphics.print(string.format("Escala Text: %.2fx", info.adaptive.currentScales.text), 10, debugY + 20)
    love.graphics.print(string.format("Escala UI: %.2fx", info.adaptive.currentScales.ui), 10, debugY + 40)
    love.graphics.print(string.format("Escala HUD: %.2fx", info.adaptive.currentScales.hud), 10, debugY + 60)
end
```

## Vantagens da Implementação

### ✅ Performance
- Fontes cacheadas na inicialização
- Espaçamentos calculados uma vez
- Sem overhead em cada frame

### ✅ Flexibilidade
- Fácil ajuste de presets
- Componentes adaptativos independentes
- Fallbacks seguros

### ✅ Compatibilidade
- Código existente continua funcionando
- Migração gradual
- Funciona em qualquer resolução

### ✅ Mobile-Friendly
- Textos automaticamente maiores
- Espaçamentos adequados para touch
- Barras de vida proporcionais