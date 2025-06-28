# Arquitetura de Carregamento Assíncrono

## Visão Geral

O sistema de carregamento foi refatorado para resolver problemas de travamento durante a inicialização do jogo. A nova arquitetura separa claramente as responsabilidades:

- **GameLoadingScene**: Carregamento pesado e assíncrono de todos os sistemas
- **GameplayScene**: Configuração rápida específica da sessão de jogo

## Fluxo de Carregamento

```
[Seleção de Portal] → [GameLoadingScene] → [GameplayScene]
                           ↓
                    [Carregamento Assíncrono]
                    - Fontes
                    - Bootstrap
                    - Animações
                    - Managers
                    - SpriteBatches
                    - Sistemas
```

## Componentes Principais

### GameLoadingScene

**Responsabilidades:**
- Carregamento assíncrono usando corrotinas
- Feedback visual de progresso
- Validação de dados do portal
- Inicialização de sistemas globais

**Sistema de Tarefas:**
```lua
self.loadingTasks = {
    { name = "Carregando fontes...", task = function() return self:_loadFonts() end },
    { name = "Inicializando Bootstrap...", task = function() return self:_initializeBootstrap() end },
    -- ... outras tarefas
}
```

**Controle de Performance:**
- Budget de 16ms por frame (~60fps)
- Yield periódico para evitar travamentos
- Logging de tarefas que demoram mais que 16ms

### GameplayScene

**Responsabilidades:**
- Configuração específica da sessão
- Instanciação de managers locais
- Setup de sistemas de gameplay
- Posicionamento inicial

**Operações Rápidas:**
- Criação de RenderPipeline
- Configuração de managers já inicializados
- Setup de callbacks
- Posicionamento de câmera

## Vantagens da Nova Arquitetura

### Performance
- **Eliminação de travamentos**: Carregamento distribuído ao longo de múltiplos frames
- **Feedback visual**: Usuário vê progresso em tempo real
- **Budget de tempo**: Controle preciso do tempo gasto por frame

### Manutenibilidade
- **Separação clara**: Cada cena tem responsabilidades bem definidas
- **Modularidade**: Tarefas de carregamento são independentes
- **Logging**: Rastreamento detalhado de performance

### Escalabilidade
- **Fácil adição de tarefas**: Sistema extensível para novos tipos de carregamento
- **Carregamento condicional**: Pode carregar apenas o necessário para cada portal
- **Priorização**: Tarefas podem ser ordenadas por importância

## Exemplo de Uso

### Adicionando Nova Tarefa

```lua
-- Em GameLoadingScene:_initializeLoadingTasks()
{
    name = "Carregando novos assets...",
    task = function() return self:_loadNewAssets() end
}

-- Implementação da tarefa
function GameLoadingScene:_loadNewAssets()
    local assetCount = 0
    for _, assetPath in ipairs(self.newAssets) do
        -- Carrega asset
        AssetManager:loadAsset(assetPath)
        assetCount = assetCount + 1
        
        -- Yield periodicamente
        if assetCount % TASK_YIELD_FREQUENCY == 0 then
            coroutine.yield()
        end
    end
end
```

### Configuração Específica do Portal

```lua
-- Em GameLoadingScene:_loadPortalAnimations()
if self.currentPortalData.customAnimations then
    AnimationLoader.loadCustom(self.currentPortalData.customAnimations)
end
```

## Monitoramento e Debug

### Logs de Performance
```
[GameLoadingScene] Tarefa 'Carregando animações...' demorou 23.5ms
[GameLoadingScene] Carregamento completo em 156.2ms
```

### Métricas Disponíveis
- Tempo total de carregamento
- Tempo por tarefa individual
- Número de yields executados
- Uso de memória antes/depois

## Futuras Melhorias

### Carregamento Prioritário
- Carregar assets críticos primeiro
- Carregar assets menos importantes em background
- Cache inteligente baseado em uso

### Streaming de Assets
- Carregamento contínuo durante gameplay
- Descarregamento automático de assets não utilizados
- Previsão de necessidades baseada em posição do jogador

### Profiles de Carregamento
- Profiles diferentes para diferentes portais
- Carregamento adaptativo baseado no hardware
- Configurações de qualidade dinâmicas

## Considerações de Implementação

### Thread Safety
- Todas as operações são executadas na thread principal
- Corrotinas garantem execução sequencial segura
- Sem necessidade de sincronização complexa

### Gerenciamento de Memória
- Coleta de lixo forçada antes do gameplay
- Monitoramento de uso de memória
- Liberação automática de recursos temporários

### Tratamento de Erros
- Validação em cada etapa do carregamento
- Mensagens de erro claras e específicas
- Fallbacks para situações de erro 