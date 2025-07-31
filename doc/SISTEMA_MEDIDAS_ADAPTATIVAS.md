# Sistema de Medidas Adaptativas

## Visão Geral

O Sistema de Medidas Adaptativas permite que o Solo Hero se adapte automaticamente a diferentes tipos de dispositivos (desktop, mobile, tablet) ajustando tamanhos de UI, texto, espaçamentos e outros elementos baseado no dispositivo detectado.

Este sistema se integra perfeitamente com o `resolution_utils.lua` existente e pode ser adotado **gradualmente** no projeto sem quebrar o código atual.

## Características

### Detecção Automática de Dispositivo
- **Desktop**: Windows, Linux, macOS com teclado/mouse
- **Mobile**: Android, iOS com touch screen  
- **Tablet**: Dispositivos com tela grande + touch

### Categorias de Escala
- **UI**: Elementos de interface (botões, modais, painéis)
- **Text**: Tamanhos de fonte e texto
- **Gameplay**: Elementos do jogo (sprites, efeitos)
- **Spacing**: Espaçamentos, padding, margens
- **Icons**: Ícones e imagens pequenas
- **HUD**: Elementos do HUD (barras de vida, etc.)

### Presets Configuráveis
- **Padrão**: Configuração balanceada
- **Acessibilidade**: Elementos maiores para melhor visibilidade
- **Compacto**: Interface menor para maximizar área de jogo
- **Desenvolvimento**: Sem escalas para teste

## Como Usar

### 1. Inicialização (main.lua)

```lua
-- Adicione após a inicialização do ResolutionUtils
local AdaptiveScaleManager = require("src.utils.adaptive_scale_manager")
local AdaptiveConfig = require("src.config.adaptive_config")

-- Inicializa com configuração padrão
AdaptiveScaleManager.initialize(AdaptiveConfig.getActiveConfig())
```

### 2. Uso Básico - Funções de Conveniência

```lua
-- Exemplo: Redimensionar botão baseado no dispositivo
local buttonWidth = ResolutionUtils.scaleUI(200, 50)  -- 200x50 -> adaptado automaticamente
local buttonHeight = ResolutionUtils.scaleUI(200, 50)

-- Exemplo: Tamanho de fonte adaptativo
local fontSize = ResolutionUtils.scaleText(16)  -- 16px -> adaptado automaticamente

-- Exemplo: Espaçamento adaptativo
local padding = ResolutionUtils.scaleSpacing(10)  -- 10px -> adaptado automaticamente

-- Exemplo: Ícone adaptativo
local iconSize = ResolutionUtils.scaleIcon(32)  -- 32px -> adaptado automaticamente
```

### 3. Uso Avançado - Escala por Categoria

```lua
-- Aplica escala específica por categoria
local scaledValue = ResolutionUtils.scaleAdaptive(100, "ui")

-- Verifica se precisa de escala adaptativa
if ResolutionUtils.needsAdaptiveScale() then
    -- Lógica específica para mobile/tablet
end

-- Informações completas do sistema
local info = ResolutionUtils.getAdaptiveInfo()
print(info.adaptive.deviceType)  -- "mobile", "desktop", etc.
print(info.adaptive.currentScales.ui)  -- fator de escala atual para UI
```

## Integração Gradual

### Passo 1: Inicialização
Adicione a inicialização no `main.lua` sem modificar código existente.

### Passo 2: Adoção Seletiva 
Comece usando em **novos componentes** ou ao **refatorar existentes**:

```lua
-- ANTES (código existente - continua funcionando)
local buttonWidth = 200
local buttonHeight = 50

-- DEPOIS (gradualmente adapte)
local buttonWidth = ResolutionUtils.scaleUI(200, 50)
local buttonHeight = ResolutionUtils.scaleUI(200, 50)
```

### Passo 3: Componentes Prioritários
Foque primeiro nos componentes mais impactados:
1. **Botões e elementos touch** (categoria "ui")
2. **Texto e fontes** (categoria "text") 
3. **Espaçamentos** (categoria "spacing")
4. **HUD e elementos críticos** (categoria "hud")

### Passo 4: Expansão Completa
Gradualmente estenda para todos os elementos conforme necessário.

## Exemplos Práticos

### Adaptando um Modal Existente

```lua
-- ANTES
local MODAL_WIDTH = 400
local MODAL_HEIGHT = 300
local PADDING = 20
local TITLE_FONT_SIZE = 24

-- DEPOIS (adaptação gradual)
local MODAL_WIDTH = ResolutionUtils.scaleUI(400, 300)
local MODAL_HEIGHT = ResolutionUtils.scaleUI(400, 300)
local PADDING = ResolutionUtils.scaleSpacing(20)
local TITLE_FONT_SIZE = ResolutionUtils.scaleText(24)
```

### Adaptando Elementos de HUD

```lua
-- ANTES
local healthBarWidth = 200
local healthBarHeight = 20
local iconSize = 32

-- DEPOIS
local healthBarWidth = ResolutionUtils.scaleAdaptive(200, "hud")
local healthBarHeight = ResolutionUtils.scaleAdaptive(20, "hud")
local iconSize = ResolutionUtils.scaleIcon(32)
```

### Verificação Condicional

```lua
-- Aplica lógica específica para mobile
if ResolutionUtils.needsAdaptiveScale() then
    -- Mobile/tablet: botões maiores, mais espaçamento
    spacing = ResolutionUtils.scaleSpacing(spacing * 1.5)
else
    -- Desktop: mantém layout compacto
    spacing = spacing
end
```

## Configuração Avançada

### Alterando Presets

```lua
local AdaptiveConfig = require("src.config.adaptive_config")

-- Muda para preset de acessibilidade
AdaptiveConfig.setActivePreset("accessibility")

-- Reinicializa o sistema com novo preset
AdaptiveScaleManager.initialize(AdaptiveConfig.getActiveConfig())
```

### Criando Preset Personalizado

```lua
local customConfig = {
    desktop = { ui = 1.0, text = 1.0, spacing = 1.0, icons = 1.0, hud = 1.0 },
    mobile = { ui = 2.0, text = 1.8, spacing = 2.0, icons = 2.5, hud = 1.8 },
    tablet = { ui = 1.5, text = 1.3, spacing = 1.5, icons = 1.8, hud = 1.4 }
}

AdaptiveConfig.createPreset("custom", "Meu preset personalizado", customConfig)
AdaptiveConfig.setActivePreset("custom")
```

## Fatores de Escala por Dispositivo

### Desktop (Padrão)
- UI: 1.0x (sem alteração)
- Text: 1.0x (sem alteração)
- Spacing: 1.0x (sem alteração)
- Icons: 1.0x (sem alteração)
- HUD: 1.0x (sem alteração)

### Mobile (Adaptado para Touch)
- UI: 1.5x (50% maior)
- Text: 1.3x (30% maior)
- Spacing: 1.4x (40% maior)
- Icons: 1.6x (60% maior)
- HUD: 1.3x (30% maior)

### Tablet (Meio Termo)
- UI: 1.2x (20% maior)
- Text: 1.1x (10% maior)
- Spacing: 1.2x (20% maior)
- Icons: 1.3x (30% maior)
- HUD: 1.15x (15% maior)

## Compatibilidade

### ✅ Totalmente Compatível
- Todo código existente continua funcionando
- Sistema opcional - só afeta quando usado
- Integração com `resolution_utils.lua` existente
- Fallbacks seguros para casos não configurados

### ⚠️ Considerações
- Teste em dispositivos reais após implementação
- Ajuste fatores de escala conforme feedback
- Alguns elementos podem precisar ajuste manual
- Performance: escala é calculada em runtime

## Troubleshooting

### Elementos Muito Grandes/Pequenos
Ajuste os fatores de escala no preset ativo ou crie um preset personalizado.

### Dispositivo Não Detectado Corretamente
O sistema usa desktop como fallback seguro. Verifique logs para detalhes da detecção.

### Layout Quebrado
Teste com preset "development" (sem escalas) para isolar problemas de layout.

### Performance
O cálculo de escala é leve, mas para elementos que mudam frequentemente, considere cachear o resultado.