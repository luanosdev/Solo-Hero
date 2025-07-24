# Sistema de Mapas Procedurais - Solo Hero

## Visão Geral

O sistema de mapas procedurais substitui a imagem estática do mapa na tela de portais por cidades geradas proceduralmente em tempo real. Inspirado no [MapGenerator](https://github.com/ProbableTrain/MapGenerator), o sistema cria mapas realistas com:

- **Ruas** - Sistema de ruas principais e secundárias
- **Estradas principais** - Artérias principais da cidade
- **Áreas de prédios** - Quarteirões com diferentes tipos de construções
- **Parques** - Áreas verdes distribuídas pela cidade
- **Água** - Rios e lagos para dar vida ao ambiente

## Características

### 🎨 **Tema Visual**
- Paleta de cores escura compatível com o tema Solo Leveling
- Fundo escuro com elementos contrastantes
- Cores diferenciadas para cada tipo de estrutura

### 🏙️ **Tipos de Cidade**
- **Modern** - Cidade moderna com alta densidade e muitas ruas
- **Medieval** - Cidade antiga com poucas ruas principais e baixa densidade
- **Industrial** - Zona industrial com alta densidade de prédios
- **Rural** - Área rural com poucos prédios e muitos parques

### 🔧 **Geração Procedural**
- Algoritmos baseados em grids para criação de ruas
- Sistema de seeds para reproduzir mapas consistentes
- Variação aleatória controlada para mapas únicos
- Diferentes tipos de prédios baseados na distância do centro

## Como Usar

### Controles na Tela de Portais

- **R** - Regenera o mapa com uma nova seed aleatória
- **T** - Alterna entre tipos de cidade (Modern → Medieval → Industrial → Rural)
- **Shift+S** - Mostra estatísticas da cidade atual no console

### API do ProceduralCityManager

```lua
-- Criar um novo gerador
local cityManager = ProceduralCityManager:new(2048, 2048, seed)

-- Gerar cidade padrão
cityManager:generateCity()

-- Gerar cidade por tipo
cityManager:generateCityByType("modern", seed)

-- Verificar se está pronto
if cityManager:isReady() then
    local canvas = cityManager:getCanvas()
    -- Usar o canvas para desenhar
end

-- Obter estatísticas
local stats = cityManager:getCityStats()
print("Prédios:", stats.buildings)
print("Ruas:", stats.totalRoads)

-- Liberar recursos
cityManager:release()
```

## Estrutura do Código

### Arquivos Principais

- `src/managers/procedural_city_manager.lua` - Gerador principal
- `src/ui/screens/portal_screen.lua` - Integração com a tela de portais

### Algoritmo de Geração

1. **Inicialização** - Cria grid vazio e define seed
2. **Ruas Principais** - Gera artérias principais horizontais e verticais
3. **Ruas Secundárias** - Cria grid de ruas secundárias com variação
4. **Água** - Adiciona rios e lagos
5. **Parques** - Distribui áreas verdes
6. **Prédios** - Preenche espaços vazios com construções
7. **Renderização** - Converte grid para canvas visual

### Configurações Ajustáveis

```lua
-- Em CITY_CONFIG
MAIN_ROAD_COUNT = 4        -- Número de ruas principais
ROAD_GRID_SIZE = 150       -- Espaçamento entre ruas
BUILDING_DENSITY = 0.6     -- Densidade de prédios (0-1)
PARK_COUNT = 8             -- Número de parques
RIVER_WIDTH = 15           -- Largura dos rios
```

## Integração com o Projeto

O sistema foi integrado de forma transparente:

- **Fallback automático** - Se a geração falhar, usa a imagem estática original
- **Cache eficiente** - Canvas é reutilizado até nova geração
- **Liberação de recursos** - Cleanup automático quando necessário
- **Logs detalhados** - Sistema de logging integrado

## Performance

- Geração acontece uma vez ao carregar a tela
- Canvas é reutilizado para múltiplos frames
- Algoritmos otimizados para execução rápida
- Dimensão padrão: 2048x2048 pixels

## Expansões Futuras

- [ ] Diferentes biomas (deserto, floresta, neve)
- [ ] Estruturas especiais (monumentos, pontes)
- [ ] Animações (tráfego, luzes)
- [ ] Mapas 3D isométricos
- [ ] Integração com sistema de clima

## Créditos

Inspirado no projeto [MapGenerator](https://github.com/ProbableTrain/MapGenerator) de ProbableTrain.
Adaptado para LÖVE2D e integrado ao sistema Solo Hero. 