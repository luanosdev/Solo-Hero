# Sistema de Conversão HEX para LÖVE

## Como usar cores HEX no colors.lua

Agora você pode usar cores no formato HEX (#FFFFFF) diretamente no seu `colors.lua` e vê-las na IDE!

### 1. Uso Básico - Função `colors.hex()`

```lua
-- ANTES (formato LÖVE manual)
my_color = { 0.8, 0.2, 0.2, 1.0 },  -- Vermelho - difícil de visualizar

-- DEPOIS (formato HEX - você vê a cor na IDE!)
my_color = colors.hex("#CC3333"),    -- Vermelho - muito mais fácil!
```

### 2. Exemplos Práticos de Conversão

```lua
-- Cores básicas
white = colors.hex("#FFFFFF"),        -- Branco puro
black = colors.hex("#000000"),        -- Preto puro  
red = colors.hex("#FF0000"),          -- Vermelho puro
green = colors.hex("#00FF00"),        -- Verde puro
blue = colors.hex("#0000FF"),         -- Azul puro

-- Cores com alpha
semi_transparent = colors.hex("#FF0000", 0.5),  -- Vermelho 50% transparente
almost_invisible = colors.hex("#00FF00", 0.1),  -- Verde quase invisível

-- Formato curto (3 dígitos)
white_short = colors.hex("#FFF"),     -- Equivale a #FFFFFF
black_short = colors.hex("#000"),     -- Equivale a #000000
red_short = colors.hex("#F00"),       -- Equivale a #FF0000

-- Sem # (também funciona)
purple = colors.hex("9966FF"),        -- Funciona sem #
```

### 3. Criando Paletas Completas

```lua
-- Paleta temática Solo Leveling
solo_leveling_colors = colors.palette({
    shadow_monarch = "#1A0B2E",     -- Roxo escuro do Monarca das Sombras
    ice_blue = "#00D4FF",           -- Azul gelo dos ataques mágicos  
    hunter_gold = "#FFD700",        -- Dourado dos hunters rank S
    system_green = "#00FF88",       -- Verde dos sistemas/upgrades
    boss_red = "#FF0040",           -- Vermelho intenso dos bosses
    portal_purple = "#8A2BE2",      -- Roxo místico dos portais
    dark_dungeon = "#0D1117",       -- Preto azulado das dungeons
    mana_crystal = "#4FC3F7",       -- Azul cristalino do mana
})

-- Agora use: solo_leveling_colors.shadow_monarch, etc.
```

### 4. Criando Variações Automáticas

```lua
-- Cria 5 variações de azul (mais claro para mais escuro)
blue_variants = colors.variations("#2196F3")
-- Resultado:
-- blue_variants.lighter2  (mais claro)
-- blue_variants.lighter1
-- blue_variants.base      (cor original)
-- blue_variants.darker1
-- blue_variants.darker2   (mais escuro)

-- Use nas suas interfaces
button_bg = blue_variants.base,
button_hover = blue_variants.lighter1,
button_pressed = blue_variants.darker1,
```

### 5. Integrando com Sistema Existente

```lua
-- Atualize cores existentes no colors.lua
-- ANTES
window_bg = { 0.06, 0.07, 0.09, 0.95 },

-- DEPOIS (mais fácil de ajustar e visualizar)
window_bg = colors.hex("#0F1218", 0.95),

-- ANTES
hp_fill = { 0.7, 0.2, 0.2, 1.0 },

-- DEPOIS  
hp_fill = colors.hex("#B33333"),     -- Vermelho escuro para vida
```

### 6. Conversão Reversa (LÖVE para HEX)

```lua
-- Se você tem uma cor em formato LÖVE e quer o HEX
existing_color = { 0.8, 0.2, 0.2, 1.0 }
hex_version = colors.toHex(existing_color)  -- Retorna "#CC3333"

-- Útil para debug ou documentação
print("A cor é: " .. colors.toHex(colors.hp_fill))
```

## Exemplos por Categoria

### Cores de UI Modernas

```lua
-- Interface moderna escura
modern_dark_ui = colors.palette({
    background = "#121212",      -- Material Design dark
    surface = "#1E1E1E",        -- Superfícies elevadas
    primary = "#BB86FC",        -- Roxo primário
    secondary = "#03DAC6",      -- Verde-azulado
    error = "#CF6679",          -- Vermelho de erro
    on_background = "#FFFFFF",   -- Texto sobre fundo
    on_surface = "#E1E1E1",     -- Texto sobre superfície
})
```

### Cores de Gameplay

```lua
-- Sistema de raridade colorido
rarity_colors = colors.palette({
    common = "#9E9E9E",         -- Cinza
    uncommon = "#4CAF50",       -- Verde
    rare = "#2196F3",           -- Azul
    epic = "#9C27B0",           -- Roxo
    legendary = "#FF9800",      -- Laranja
    mythic = "#F44336",         -- Vermelho
    divine = "#FFD700",         -- Dourado
})
```

### Cores de Feedback

```lua
-- Estados e feedback do usuário
feedback_colors = colors.palette({
    success = "#4CAF50",        -- Verde de sucesso
    warning = "#FF9800",        -- Laranja de aviso
    error = "#F44336",          -- Vermelho de erro
    info = "#2196F3",           -- Azul de informação
    loading = "#9C27B0",        -- Roxo de carregamento
})
```

## Como Usar no Código

### 1. Em Componentes de UI

```lua
-- button_component.lua
function Button:draw()
    -- Usa cores HEX convertidas
    love.graphics.setColor(unpack(colors.blue_variants.base))
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    if self.hovered then
        love.graphics.setColor(unpack(colors.blue_variants.lighter1))
    end
end
```

### 2. Em Sistemas de Partículas

```lua
-- particle_system.lua  
function ParticleSystem:createFireEffect()
    local fire_colors = colors.palette({
        yellow = "#FFFF00",
        orange = "#FF8800", 
        red = "#FF0000",
        dark_red = "#880000"
    })
    
    -- Use fire_colors.yellow, etc.
end
```

### 3. Em Debug e Desenvolvimento

```lua
-- Debug com cores facilmente identificáveis
debug_colors = colors.palette({
    collision_box = "#FF00FF",    -- Magenta para caixas de colisão
    spawn_point = "#00FFFF",      -- Ciano para pontos de spawn
    path_line = "#FFFF00",        -- Amarelo para linhas de caminho
    trigger_area = "#FF8800",     -- Laranja para áreas de trigger
})
```

## Vantagens do Sistema

### ✅ **Visualização na IDE**
- Você vê as cores diretamente no código
- Fácil identificação de problemas visuais
- Cores ficam autodocumentadas

### ✅ **Facilidade de Uso**
- Copie cores direto do Photoshop/Figma/CSS
- Formatos flexíveis (#FFF, #FFFFFF, FFFFFF)
- Suporte a transparência

### ✅ **Compatibilidade Total**
- Todo código existente continua funcionando
- Conversão bidirecional (HEX ↔ LÖVE)
- Fallbacks seguros para erros

### ✅ **Ferramentas Úteis**
- Criação automática de paletas
- Variações de cor automáticas
- Validação de formato

## Migração Gradual

### Passo 1: Comece com cores novas
```lua
-- Adicione novas cores usando HEX
new_button_color = colors.hex("#2196F3"),
```

### Passo 2: Migre cores existentes aos poucos
```lua
-- Substitua gradualmente
-- hp_fill = { 0.7, 0.2, 0.2, 1.0 },  -- ANTES
hp_fill = colors.hex("#B33333"),        -- DEPOIS
```

### Passo 3: Use paletas para grupos relacionados
```lua
-- Agrupe cores relacionadas
ui_theme = colors.palette({
    primary = "#2196F3",
    secondary = "#FFC107", 
    background = "#121212",
    surface = "#1E1E1E"
})
```

O sistema está **pronto para uso**! Agora você pode trabalhar com cores HEX de forma natural e ver as cores diretamente na sua IDE, tornando o desenvolvimento visual muito mais fácil e intuitivo.