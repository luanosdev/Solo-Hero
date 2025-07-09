# Sistema de Notificações Globais - Solo Hero

O sistema de notificações globais permite exibir notificações animadas em qualquer cena do jogo (lobby ou gameplay). As notificações aparecem no canto esquerdo da tela com animações suaves de entrada e saída.

## Características

### ✨ **Visuais**
- **Posicionamento**: Canto esquerdo da tela
- **Animações**: Slide de entrada da esquerda + fade out suave
- **Stack**: Notificações mais novas empurram as antigas para baixo
- **Cores**: Fundo baseado na raridade do item (E, D, C, B, A, S)
- **Componentes**: Ícone, título, valor/quantidade

### ⚡ **Performance**
- **Pooling**: Sistema de pool para evitar garbage collection
- **Limite**: Máximo de 5 notificações simultâneas
- **Otimização**: Reutilização de objetos para performance

### 🎯 **Funcionalidades**
- **Auto-stack**: Mesmo item incrementa valor e reseta duração
- **Tipos**: Coleta, patrimônio, compra, venda, level up, conquistas
- **Global**: Funciona em qualquer cena do jogo

## Configuração

### Constants.lua
```lua
-- Constantes do Sistema de Notificações
Constants.NOTIFICATION_SYSTEM = {
    MAX_VISIBLE_NOTIFICATIONS = 5,    -- Máximo simultâneo
    DEFAULT_DURATION = 4.0,           -- Duração padrão (segundos)
    SLIDE_IN_DURATION = 0.4,         -- Animação de entrada
    FADE_OUT_DURATION = 0.3,         -- Animação de saída
    NOTIFICATION_HEIGHT = 60,         -- Altura de cada notificação
    NOTIFICATION_WIDTH = 300,         -- Largura das notificações
    NOTIFICATION_SPACING = 10,        -- Espaçamento entre notificações
    NOTIFICATION_X = 20,             -- Posição X (margem esquerda)
    NOTIFICATION_START_Y = 80,       -- Posição Y inicial
    ICON_SIZE = 40,                  -- Tamanho do ícone
    POOL_SIZE = 10,                  -- Pool inicial
    SLIDE_DISTANCE = 350,            -- Distância da animação
}

-- Tipos de notificação
Constants.NOTIFICATION_TYPES = {
    ITEM_PICKUP = "item_pickup",
    ARTEFACT_PICKUP = "artefact_pickup", 
    MONEY_CHANGE = "money_change",
    ITEM_PURCHASE = "item_purchase",
    ITEM_SALE = "item_sale",
    LEVEL_UP = "level_up",
    ACHIEVEMENT = "achievement",
}
```

## Integração Automática

### 🎒 **Coleta de Items**
```lua
-- src/managers/drop_manager.lua - função applyDrop()
if addedQuantity > 0 then
    -- ... código existente ...
    
    -- Notificação automática de coleta
    if NotificationDisplay then
        local itemIcon = baseData and baseData.icon and love.graphics.newImage(baseData.icon)
        NotificationDisplay.showItemPickup(itemName, addedQuantity, itemIcon, itemRarity)
    end
end
```

### 💎 **Coleta de Artefatos**
```lua
-- src/managers/artefact_manager.lua - função addArtefact()
-- Notificação automática quando artefatos são coletados
if NotificationDisplay and artefactData then
    NotificationDisplay.showItemPickup(artefactData.name, quantity, artefactData.icon, artefactData.rarity)
end
```

### 💰 **Compras e Vendas**
```lua
-- src/managers/patrimony_manager.lua

-- Compras
if NotificationDisplay then
    NotificationDisplay.showItemPurchase(itemName, itemPrice)
end

-- Vendas  
if NotificationDisplay then
    NotificationDisplay.showItemSale(itemName, sellPrice)
end

-- Mudanças de patrimônio (exceto compra/venda)
if NotificationDisplay and not string.match(reason, "^sale_") and not string.match(reason, "^purchase_") then
    NotificationDisplay.showMoneyChange(amount) -- positivo ou negativo
end
```

## API de Uso

### NotificationManager

```lua
-- Exibir notificação customizada
NotificationManager.show({
    type = Constants.NOTIFICATION_TYPES.ITEM_PICKUP,
    title = "Item Coletado",
    value = "+5",
    icon = itemIcon,                    -- love.Image opcional
    rarityColor = Colors.rarity.A,      -- cor de fundo opcional
    duration = 4.0                      -- duração opcional
})

-- Limpar todas as notificações
NotificationManager.clear()

-- Estatísticas do sistema
local stats = NotificationManager.getStats()
-- retorna: { activeCount, poolCount, nextId }
```

### NotificationDisplay

```lua
-- Funções de conveniência para tipos comuns

-- Coleta de item
NotificationDisplay.showItemPickup(itemName, quantity, icon, rarity)

-- Mudança de patrimônio 
NotificationDisplay.showMoneyChange(amount) -- positivo = ganho, negativo = perda

-- Compra de item
NotificationDisplay.showItemPurchase(itemName, cost)

-- Venda de item  
NotificationDisplay.showItemSale(itemName, earnings)
```

## Testes e Debug

### Função de Teste Global
```lua
-- No console ou código, chame:
GSTestNotifications()

-- Isso irá disparar uma sequência de notificações de teste:
-- 1. Coleta de item comum (raridade E)
-- 2. Coleta de item lendário (raridade A) 
-- 3. Ganho de 500 gold
-- 4. Compra de poção (25 gold)
-- 5. Venda de equipamento (15 gold)
```

### Debug no Logger
```lua
-- Ativar logs de debug para notificações
Logger.setVisibleLevels({ debug = true, info = true, warn = true, error = true })

-- As notificações logam:
-- - Criação e inicialização
-- - Exibição de cada notificação
-- - Pool usage e performance
-- - Erros e warnings
```

## Arquitetura

### Componentes Principais

1. **NotificationManager** (`src/managers/notification_manager.lua`)
   - Gerencia pool de notificações
   - Controla animações e timing
   - Sistema de auto-stack para itens similares

2. **NotificationDisplay** (`src/ui/components/notification_display.lua`) 
   - Renderização visual das notificações
   - Funções de conveniência para tipos comuns
   - Sistema de cores baseado em raridade

3. **Integração Global** (`main.lua`)
   - Inicialização automática no love.load()
   - Update e draw integrados ao loop principal
   - Disponível globalmente como _G.NotificationManager e _G.NotificationDisplay

### Fluxo de Dados

```
Evento do Jogo → Manager Específico → NotificationDisplay.show*() → NotificationManager.show() → Pool → Animação → Renderização
```

## Casos de Uso

### ✅ **Já Implementados**
- ✅ Coleta de drops e artefatos
- ✅ Compras e vendas na loja
- ✅ Mudanças de patrimônio (ganhos/perdas não relacionados a compra/venda)

### 🔄 **Fáceis de Adicionar**
- Level up do hunter
- Conquistas/achievements
- Progresso de missões
- Craft de itens
- Abertura de baús
- Eventos especiais

### Exemplo de Implementação para Level Up
```lua
-- Em algum lugar do sistema de level up:
if NotificationDisplay then
    NotificationDisplay.show({
        type = Constants.NOTIFICATION_TYPES.LEVEL_UP,
        title = "Level Up!",
        value = "Nível " .. newLevel,
        icon = levelUpIcon,
        rarityColor = Colors.ui.success,
        duration = 6.0  -- Level up fica mais tempo na tela
    })
end
```

## Localização

O sistema usa um sistema de traduções temporário que pode ser facilmente integrado ao sistema de localização global do projeto:

```lua
-- Em notification_display.lua (temporário)
local translations = {
    ["notifications.item_pickup"] = "Item coletado: %s",
    ["notifications.money_change"] = "Patrimônio alterado", 
    ["notifications.item_purchase"] = "Item comprado: %s",
    ["notifications.item_sale"] = "Item vendido: %s"
}
```

**TODO**: Integrar com o sistema de localização global `_T()` quando disponível.

## Performance

### Otimizações Implementadas
- **Object Pooling**: Pool de 10 notificações pré-criadas
- **Render Culling**: Notificações invisíveis não são processadas
- **Efficient Animation**: Interpolação matemática otimizada
- **Memory Management**: Reutilização de objetos, evita garbage collection

### Métricas Esperadas
- **Memory**: ~1KB por notificação ativa
- **CPU**: <0.1ms por notificação por frame
- **Pool Miss Rate**: <5% (raramente cria novas notificações)

O sistema foi projetado para ser altamente performático mesmo com múltiplas notificações simultâneas em cenas de combate intenso. 