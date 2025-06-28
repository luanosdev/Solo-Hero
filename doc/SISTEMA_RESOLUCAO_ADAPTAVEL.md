# Sistema de Resolução Adaptável

## Visão Geral

O Solo Hero agora utiliza o sistema **push** para adaptar automaticamente o jogo para diferentes tipos de tela e resoluções, mantendo a jogabilidade consistente em todos os dispositivos.

## Características

### Resolução Base
- **Resolução virtual do jogo**: 1920x1080 (Full HD)
- Todos os elementos do jogo são desenhados nesta resolução virtual
- O sistema escala automaticamente para diferentes tamanhos de tela

### Modos de Funcionamento

#### Modo Desenvolvimento (DEV = true)
- Janela redimensionável de 1280x720 por padrão
- Permite teste em diferentes resoluções
- Facilita o desenvolvimento e debug

#### Modo Produção (DEV = false)
- Fullscreen automático na resolução nativa do monitor
- Escala inteligente mantendo proporções
- Barras pretas nas laterais quando necessário (letterboxing)

## Como Usar

### Conversão de Coordenadas

#### Mouse/Touch
As coordenadas são automaticamente convertidas nos callbacks do LÖVE:
```lua
-- Conversão automática em main.lua
function love.mousepressed(x, y, button, istouch, presses)
    local gameX, gameY = push:toGame(x, y)
    if gameX and gameY then
        SceneManager.mousepressed(gameX, gameY, button, istouch, presses)
    end
end
```

#### ResolutionUtils
Para conversões manuais em outras partes do código:
```lua
local ResolutionUtils = require("src.utils.resolution_utils")

-- Converte coordenadas de tela para jogo
local gameX, gameY = ResolutionUtils.toGame(screenX, screenY)

-- Converte coordenadas de jogo para tela
local screenX, screenY = ResolutionUtils.toReal(gameX, gameY)

-- Obter dimensões do jogo
local gameWidth, gameHeight = ResolutionUtils.getGameDimensions()

-- Centralizar elementos
local centerX, centerY = ResolutionUtils.centerElement(width, height)
```

### Funções Utilitárias

#### Informações de Escala
```lua
local scaleInfo = ResolutionUtils.getScaleInfo()
-- Retorna: scaleX, scaleY, offsetX, offsetY, etc.
```

#### Verificação de Área
```lua
-- Verifica se um ponto está dentro da área visível do jogo
local isInside = ResolutionUtils.isPointInGameArea(x, y)
```

#### Centralização
```lua
-- Centralizar um elemento
local centerX, centerY = ResolutionUtils.centerElement(elementWidth, elementHeight)

-- Centralizar apenas horizontalmente
local centerX = ResolutionUtils.centerHorizontally(elementWidth)

-- Centralizar apenas verticalmente
local centerY = ResolutionUtils.centerVertically(elementHeight)
```

## Controles

- **F11**: Toggle fullscreen/janela
- **Redimensionamento**: Suportado automaticamente

## Implementação Técnica

### Estrutura
```
src/libs/push.lua           # Biblioteca principal
src/utils/resolution_utils.lua  # Utilitários e helpers
main.lua                    # Integração e configuração
conf.lua                    # Configurações básicas da janela
```

### Fluxo de Renderização
1. `push:start()` - Inicia o canvas virtual
2. Desenho normal do jogo (1920x1080)
3. `push:finish()` - Escala e desenha na tela real

### Canvas Virtual
- O jogo desenha em um canvas de 1920x1080 com suporte a stencil
- O push escala este canvas para a resolução real
- Mantém proporções com letterboxing quando necessário
- Suporte completo a stencil buffer para elementos de UI complexos

## Benefícios

### Para Jogadores
- **Compatibilidade universal**: Funciona em qualquer resolução
- **Qualidade consistente**: Elementos sempre proporcionais
- **Flexibilidade**: Suporte a fullscreen e janela

### Para Desenvolvimento
- **Código simples**: Sempre trabalha com 1920x1080
- **Teste fácil**: Redimensionamento em tempo real
- **Manutenção**: Sem código específico para cada resolução

## Considerações

### Performance
- Uso de canvas pode ter impacto mínimo na performance
- Benefício compensado pela simplicidade de desenvolvimento
- Otimizado para LÖVE 2D

### Coordenadas
- **Sempre use coordenadas de jogo (1920x1080) no código**
- As conversões são automáticas nos callbacks
- Use ResolutionUtils para conversões manuais quando necessário

### Compatibilidade
- Funciona com todos os sistemas de input existentes
- Compatível com shaders e efeitos visuais
- Suporte a telas de alta densidade (Retina, etc.)

## Migração

O sistema foi implementado de forma não-destrutiva:
- Todo código existente continua funcionando
- Coordenadas hardcoded em 1920x1080 permanecem válidas
- Melhorias automáticas em compatibilidade de tela

## Troubleshooting

### Problemas Comuns

1. **Elementos fora de posição**: Verifique se está usando coordenadas corretas (1920x1080)
2. **Mouse não funcionando**: As conversões são automáticas, não modifique callbacks de mouse
3. **Performance**: Se houver problemas, considere desabilitar canvas no push

### Debug
```lua
-- Informações de escala no console
local info = ResolutionUtils.getScaleInfo()
print("Escala atual:", info.scaleX, info.scaleY)
print("Offset:", info.offsetX, info.offsetY)
```

## Correções Implementadas

### Suporte a Stencil Buffer
**Problema**: Erro "Drawing to the stencil buffer with a Canvas active requires either stencil=true"
**Solução**: Sistema robusto com múltiplas tentativas de criação de canvas com stencil e fallback automático.

```lua
-- Sistema de fallback robusto
function push:_createCanvasWithStencil(width, height)
    local canvas, hasStencil = nil, false
    
    -- Tentativa 1: LÖVE 12+ syntax
    pcall(function()
        canvas = love.graphics.newCanvas(width, height, {stencil = true})
        hasStencil = true
    end)
    
    -- Tentativa 2: LÖVE 11.x syntax
    if not canvas then
        pcall(function()
            canvas = love.graphics.newCanvas(width, height, {format = "rgba8", stencil = true})
            hasStencil = true
        end)
    end
    
    -- Fallback: Canvas padrão
    if not canvas then
        canvas = love.graphics.newCanvas(width, height)
        hasStencil = false
    end
    
    return canvas, hasStencil
end
```

**Verificação de Suporte**:
```lua
-- Verificar se stencil está disponível
local hasStencil = ResolutionUtils.getScaleInfo().hasStencil
```

**Integração com UI**:
- Sistema de UI automaticamente detecta disponibilidade de stencil
- Fallback visual: bordas arredondadas desenhadas como linhas quando stencil não disponível
- Logs informativos quando fallback é usado (modo DEBUG)
- Nenhuma alteração necessária no código de UI existente 