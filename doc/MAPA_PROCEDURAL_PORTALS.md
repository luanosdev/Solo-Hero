# Sistema de Mapa Procedural para Portais

Este documento descreve a integração do sistema de mapa procedural no lobby de portais do Solo Hero, substituindo a imagem estática por um continente gerado dinamicamente.

## Visão Geral

O sistema integra o gerador de mapas procedurais do `map.lua` na arquitetura do Solo Hero, criando um mapa isométrico dinâmico onde os portais são posicionados automaticamente dentro do continente gerado.

## Componentes Principais

### 1. LobbyMapPortals (`src/ui/components/lobby_map_portals.lua`)

**Responsabilidades:**
- Geração procedural do continente usando algoritmos de subdivisão
- Criação de estruturas decorativas (cidades, fortes, vilas)
- Geração de estradas conectando estruturas
- Renderização em projeção isométrica
- Verificação de pontos dentro do continente (para posicionamento de portais)

**Características:**
- **Resolução Virtual:** 3000x2000 pixels para geração
- **Corrotinas:** Geração assíncrona para evitar travamentos
- **Sistema de Câmera:** Ancoragem automática numa extremidade do continente
- **Grade Tática:** Overlay isométrica para efeito visual

### 2. LobbyPortalManager Integrado (`src/managers/lobby_portal_manager.lua`)

**Melhorias:**
- **Posicionamento Inteligente:** Portais posicionados apenas dentro do continente
- **Margem de Segurança:** 200 pixels de distância das bordas do continente  
- **Validação de Distância:** Mínimo de 300 pixels entre portais
- **Fallback Automático:** Sistema de posicionamento em tela se mapa procedural falhar
- **Reposicionamento Dinâmico:** Portais reposicionados quando mapa fica disponível

### 3. PortalScreen Atualizado (`src/ui/screens/portal_screen.lua`)

**Modificações:**
- **Substituição da Imagem:** Sistema procedural substitui `assets/images/map.png`
- **Integração Automática:** Conexão automática entre mapa procedural e portal manager
- **Efeitos Preservados:** Névoa e zoom mantidos funcionando
- **Dimensões Virtuais:** Usa dimensões do mapa procedural (3000x2000)

## Fluxo de Funcionamento

### 1. Inicialização (LobbyScene)
```lua
-- O PortalScreen cria automaticamente o LobbyMapPortals
portalScreen = PortalScreen:new(lobbyPortalManager, hunterManager)

-- PortalScreen conecta o sistema procedural ao gerenciador de portais
lobbyPortalManager:setProceduralMap(proceduralMap)

-- LobbyScene inicializa com as dimensões virtuais
lobbyPortalManager:initialize(mapW, mapH)
```

### 2. Geração do Mapa
```lua
-- Geração assíncrona em corrotinas
proceduralMap:generateMap()
-- 1. Polígono inicial do continente
-- 2. Subdivisão iterativa para formar costas orgânicas
-- 3. Ancoragem de câmera em extremidade otimizada
-- 4. Geração de estruturas dentro do continente
-- 5. Criação de estradas conectando estruturas
```

### 3. Posicionamento de Portais
```lua
-- Aguarda geração completa do mapa
while not proceduralMap:isGenerationComplete() do
    -- Continua renderização sem portais
end

-- Posiciona portais dentro do continente
for each portal in portalDefinitions do
    repeat
        x, y = randomPosition()
    until isPointInContinent(x, y) and 
          isPositionSafeFromEdges(x, y) and 
          isValidPortalDistance(x, y)
end
```

### 4. Renderização
```lua
-- Ordem de renderização no PortalScreen:draw()
1. Mapa procedural (continente, estruturas, estradas, grade)
2. Efeito de névoa (shader) 
3. Portais com feixes de luz animados
4. Modal de detalhes (se portal selecionado)
5. Status de geração (durante carregamento)
```

## Configurações

### Mapa Procedural
```lua
CONFIG = {
    VIRTUAL_MAP_WIDTH = 3000,      -- Largura virtual
    VIRTUAL_MAP_HEIGHT = 2000,     -- Altura virtual  
    MAX_POINTS = 1280,             -- Máximo de pontos do continente
    STRUCTURE_COUNT = 25,          -- Número de estruturas
    MIN_STRUCTURE_DISTANCE = 150,  -- Distância mínima entre estruturas
    GRID_SIZE = 25,                -- Tamanho da grade tática
    ISO_SCALE = 1.2                -- Escala da projeção isométrica
}
```

### Posicionamento de Portais
```lua
CONTINENT_SPAWN_MARGIN = 200      -- Margem das bordas do continente
MIN_PORTAL_DISTANCE = 300         -- Distância mínima entre portais
```

## Temas Visuais

### Cores do Mapa (Estilo Solo Leveling)
- **Fundo:** `#0b040b` (roxo escuro)
- **Continente:** `#11213f` (azul escuro)
- **Estruturas:** `#233755` (azul acinzentado)
- **Estradas:** `#214ba0` com transparência
- **Grade:** `#6c9add` com baixa opacidade

### Estruturas Decorativas
- **Tipo 1:** Cidades (círculos grandes)
- **Tipo 2:** Fortes (quadrados)
- **Tipo 3:** Vilas (círculos pequenos)

## Performance

### Otimizações
- **Corrotinas:** Evitam travamentos durante geração
- **Culling:** Apenas elementos visíveis são renderizados
- **Cache de Estados:** Minimiza recálculos desnecessários
- **Renderização Inteligente:** Grade e estruturas só desenham quando necessário

### Métricas
- **Tempo de Geração:** ~2-5 segundos (dependendo da complexidade)
- **Memória:** ~50MB para assets do mapa (estimativa)
- **FPS:** Sem impacto significativo após geração completa

## Compatibilidade

### Sistema de Resolução
- **Adaptação Automática:** Funciona com qualquer resolução através do push.lua
- **Coordenadas Virtuais:** 1920x1080 base, escalada automaticamente
- **Projeção Isométrica:** Mantém proporções corretas em todas as resoluções

### Fallbacks
- **Mapa Procedural Falha:** Reverte para posicionamento baseado em tela
- **Shader de Névoa Falha:** Continua funcionando sem efeito de névoa
- **Geração Incompleta:** Exibe status e permite interação parcial

## Debug e Logs

### Logs Principais
```
[LobbyMapPortals] Geração iniciada
[LobbyPortalManager] Aguardando geração do mapa procedural
[LobbyMapPortals] Subdivisão concluída. Pontos finais: 640
[LobbyMapPortals] 25 estruturas geradas na área visível
[LobbyPortalManager] 7 portais posicionados no continente procedural
```

### Comandos de Debug
- Status de geração exibido na tela durante carregamento
- Logger integrado para rastreamento de problemas
- Validação automática de posicionamento de portais

## Integração com Sistema Existente

### Mantido
- ✅ Efeitos de névoa (shaders)
- ✅ Sistema de zoom/pan para portais
- ✅ Animações de feixes de luz dos portais
- ✅ Modal de detalhes dos portais
- ✅ Navegação por tabs do lobby
- ✅ Sistema de cores temáticas

### Removido/Substituído
- ❌ Carregamento de `assets/images/map.png`
- ❌ Posicionamento fixo de portais baseado em imagem
- ❌ Dimensões fixas de mapa (agora virtuais e dinâmicas)

## Extensibilidade

### Futuras Melhorias
- **Biomas Diferentes:** Deserto, floresta, montanha baseado no tema do portal
- **Animações de Água:** Ondas nas bordas do continente
- **Estruturas Temáticas:** Dungeons, torres, ruínas baseadas nos portais
- **Efeitos Climáticos:** Neve, chuva, neblina procedural
- **Pathfinding:** IA para movimentação de NPCs pelas estradas

### API de Extensão
```lua
-- Adicionar novos tipos de estruturas
LobbyMapPortals:addStructureType(id, drawFunction, spacing)

-- Modificar algoritmo de geração
LobbyMapPortals:setGenerationParams(params)

-- Customizar cores por tema
LobbyMapPortals:setThemeColors(theme, colorPalette)
```

## Conclusão

O sistema de mapa procedural traz dinamismo e imersão ao lobby de portais, mantendo toda a funcionalidade existente enquanto adiciona geração única a cada sessão. A integração respeita os padrões arquiteturais do projeto e oferece performance estável através de otimizações cuidadosas. 