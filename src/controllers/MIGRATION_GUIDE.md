# Guia de Migração: PlayerStateController

## **Visão Geral**

O `PlayerStateController` unifica as funcionalidades do `PlayerState` e `StatsController` em um único controlador, seguindo a nova arquitetura do projeto.

## **Mudanças Principais**

### **Antes (PlayerManager)**
```lua
-- Múltiplas referências
self.state = PlayerState:new(initialStats)
self.statsController = StatsController:new(self)

-- Múltiplas chamadas
local finalStats = self.statsController:getCurrentFinalStats()
local damage = self.state:takeDamage(amount, reduction)
self.statsController:invalidateCache()
```

### **Depois (PlayerManager)**
```lua
-- Uma única referência
self.stateController = PlayerStateController:new(self, initialStats)

-- Chamadas unificadas
local finalStats = self.stateController:getCurrentFinalStats()
local damage = self.stateController:takeDamage(amount, reduction)
self.stateController:invalidateStatsCache()
```

## **Integração no PlayerManager**

### **1. Substituir Inicialização**
```lua
-- REMOVER estas linhas do PlayerManager:new()
-- self.state = PlayerState:new(initialStats)
-- self.statsController = StatsController:new(self)

-- ADICIONAR esta linha
self.stateController = PlayerStateController:new(self, initialStats)
```

### **2. Atualizar Referências de Estado**
```lua
-- SUBSTITUIR todas as ocorrências de:
self.state.currentHealth    → self.stateController.currentHealth
self.state.level           → self.stateController.level
self.state.experience      → self.stateController.experience
self.state.isAlive         → self.stateController.isAlive
self.state.kills           → self.stateController.kills
self.state.gold            → self.stateController.gold
```

### **3. Atualizar Chamadas de Métodos**
```lua
-- SUBSTITUIR chamadas de estado:
self.state:takeDamage(amount, reduction)
→ self.stateController:takeDamage(amount, reduction)

self.state:heal(amount, maxHealth, bonus)
→ self.stateController:heal(amount, maxHealth, bonus)

self.state:addExperience(amount, bonus)
→ self.stateController:addExperience(amount, bonus)

-- SUBSTITUIR chamadas de stats:
self.statsController:getCurrentFinalStats()
→ self.stateController:getCurrentFinalStats()

self.statsController:invalidateCache()
→ self.stateController:invalidateStatsCache()
```

### **4. Atualizar Outros Controllers**

**HealthController:**
```lua
-- SUBSTITUIR
if not self.playerManager.state or not self.playerManager.state.isAlive then
-- POR
if not self.playerManager.stateController or not self.playerManager.stateController.isAlive then

-- SUBSTITUIR
self.playerManager.state:heal(amount, maxHealth, bonus)
-- POR
self.playerManager.stateController:heal(amount, maxHealth, bonus)
```

**ExperienceController:**
```lua
-- SUBSTITUIR
if not self.playerManager.state then return end
-- POR
if not self.playerManager.stateController then return end

-- SUBSTITUIR
self.playerManager.state:addExperience(amount, bonus)
-- POR
self.playerManager.stateController:addExperience(amount, bonus)
```

**Outros Controllers:**
- `MovementController`: Verificar referências a `self.playerManager.state.isAlive`
- `AutoAttackController`: Verificar referências a `self.playerManager.state.isAlive`
- `WeaponController`: Verificar referências a `self.playerManager.state.isAlive`

### **5. Atualizar Método invalidateStatsCache()**
```lua
-- NO PlayerManager, SUBSTITUIR:
function PlayerManager:invalidateStatsCache()
    if self.statsController then
        self.statsController:invalidateCache()
    end
end

-- POR:
function PlayerManager:invalidateStatsCache()
    if self.stateController then
        self.stateController:invalidateStatsCache()
    end
end
```

### **6. Atualizar getCurrentFinalStats()**
```lua
-- NO PlayerManager, SUBSTITUIR:
function PlayerManager:getCurrentFinalStats()
    if not self.statsController then
        error("Error [PlayerManager:getCurrentFinalStats]: StatsController não inicializado.")
    end
    return self.statsController:getCurrentFinalStats()
end

-- POR:
function PlayerManager:getCurrentFinalStats()
    if not self.stateController then
        error("Error [PlayerManager:getCurrentFinalStats]: PlayerStateController não inicializado.")
    end
    return self.stateController:getCurrentFinalStats()
end
```

## **Vantagens da Migração**

✅ **Responsabilidade única**: Um controlador para estado e stats  
✅ **Menos dependências**: Elimina dependência circular entre PlayerState e StatsController  
✅ **Cache integrado**: Sistema de cache mais eficiente  
✅ **Tipagem forte**: LDoc completo com tipos customizados  
✅ **Consistência**: Segue padrão Manager/Controller do projeto  
✅ **Manutenibilidade**: Código mais organizado e fácil de manter  

## **Arquivos a Remover Após Migração**

Após a migração completa e testes:
- `src/entities/player_state.lua` (funcionalidade movida para PlayerStateController)
- `src/controllers/stats_controller.lua` (funcionalidade movida para PlayerStateController)

## **Testes Recomendados**

1. **Inicialização**: Verificar se o PlayerManager inicializa corretamente
2. **Stats**: Confirmar cálculo de stats finais
3. **Combate**: Testar dano e cura
4. **Progressão**: Verificar ganho de XP e level ups
5. **Cache**: Confirmar invalidação de cache ao equipar itens
6. **Controllers**: Testar todos os outros controllers

## **Exemplo de Migração Completa**

```lua
-- PlayerManager:new() - ANTES
function PlayerManager:new(currentHunterId, hunterManager, ...)
    -- ... outras inicializações ...
    self.state = PlayerState:new(initialStats)
    self.statsController = StatsController:new(self)
    -- ... resto da inicialização ...
end

-- PlayerManager:new() - DEPOIS  
function PlayerManager:new(currentHunterId, hunterManager, ...)
    -- ... outras inicializações ...
    self.stateController = PlayerStateController:new(self, initialStats)
    -- ... resto da inicialização ...
end
```

Esta migração simplifica significativamente a arquitetura do PlayerManager e melhora a manutenibilidade do código. 