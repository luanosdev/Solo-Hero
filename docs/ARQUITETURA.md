# Constituição Arquitetural - Solo Hero

Este documento é a nossa **fonte única da verdade** para as regras de arquitetura, padrões de código e convenções do projeto Solo Hero. Seguir estas diretrizes não é opcional; é o que garante que nosso código seja limpo, sustentável, escalável e fácil de trabalhar.

## Índice

1.  [Princípios Fundamentais](#1-princípios-fundamentais)
2.  [Hierarquia e Nomenclatura de Componentes](#2-hierarquia-e-nomenclatura-de-componentes)
    *   [Service](#service)
    *   [Manager](#manager)
    *   [Controller](#controller)
    *   [Entity](#entity)
3.  [Ciclo de Vida e Estrutura de Cenas](#3-ciclo-de-vida-e-estrutura-de-cenas)
    *   [Estrutura de Diretórios](#estrutura-de-diretórios)
    *   [Ciclo de Vida de um Manager](#ciclo-de-vida-de-um-manager)
4.  [Regras de Ouro](#4-regras-de-ouro)
    *   [Regra 1: Fluxo de Dependência Unidirecional](#regra-1-fluxo-de-dependência-unidirecional)
    *   [Regra 2: Separação Estrita de Dados e Lógica](#regra-2-separação-estrita-de-dados-e-lógica)
    *   [Regra 3: Proibição de "Magic Values"](#regra-3-proibição-de-magic-values)
    *   [Regra 4: Documentação LDoc Obrigatória](#regra-4-documentação-ldoc-obrigatória)
    *   [Regra 5: Padrão de Nomenclatura Consistente](#regra-5-padrão-de-nomenclatura-consistente)
    *   [Regra 6: Padronização do Tratamento de Erros](#regra-6-padronização-do-tratamento-de-erros)
    *   [Regra 7: Abstração de Entradas do Usuário](#regra-7-abstração-de-entradas-do-usuário)
    *   [Regra 8: Fluxo de Dados da UI de Mão Única](#regra-8-fluxo-de-dados-da-ui-de-mão-única)

---

## 1. Princípios Fundamentais

*   **Composição sobre Herança:** Preferimos montar objetos complexos a partir de componentes menores e especializados em vez de criar longas cadeias de herança.
*   **Desacoplamento Alto:** Componentes devem saber o mínimo possível uns sobre os outros. Isso é alcançado através de injeção de dependência e um sistema de eventos.
*   **Responsabilidade Única:** Cada classe (Service, Manager, Controller) tem um, e apenas um, motivo para existir e para ser modificada.

---

## 2. Hierarquia e Nomenclatura de Componentes

A arquitetura do Solo Hero é dividida em cinco camadas principais de componentes.

### `Core`
*   **Função:** Representa as **classes de infraestrutura e utilitários** da aplicação. São as "ferramentas" e os "tijolos" que usamos para construir a arquitetura, mas que não contêm lógica de jogo direta. Eles existem para dar suporte aos `Services` e `Managers`.
*   **Exemplos:** `SceneManagerRegistry`, `Logger`, `Timer`, `EventDispatcher`.
*   **Localização:** Tipicamente residem em `src/core/` ou `src/libs/`.
*   **Ciclo de Vida:** Geralmente são classes instanciáveis (`:new()`) ou módulos estáticos, dependendo da necessidade.

### `Service`
*   **Função:** Gerencia estado e lógica **global** que persistem entre as cenas. São os "Imortais" da aplicação.
*   **Exemplos:** `PersistenceService`, `SettingsService`, `HunterService`, `EventService`, `InputService`.
*   **Ciclo de Vida:** Criado uma vez no `main.lua` ou `bootloader`, vive durante toda a execução do jogo.
*   **Comunicação:** Pode ser acessado globalmente ou através de injeção em outros services.

### `Manager`
*   **Função:** Orquestra um sistema complexo **específico de uma cena**. É o "cérebro" que gerencia um conjunto de entidades e a comunicação entre seus controllers.
*   **Exemplos:** `EnemyManager`, `PlayerManager`, `HUDGameplayManager`.
*   **Ciclo de Vida:** Criado e destruído junto com a cena a que pertence.
*   **Comunicação:** Comunica-se com outros `Managers` via injeção de dependência (através de um `ManagerRegistry` da cena). Ele instancia e gerencia seus próprios `Controllers`.

### `Controller`
*   **Função:** Encapsula uma única responsabilidade ou regra de negócio. É um "Especialista" que pertence a um `Manager`.
*   **Exemplos:** `MovementController`, `SpawnController`, `AutoAttackController`, `HealthController`.
*   **Ciclo de Vida:** Criado e destruído pelo seu `Manager` dono.
*   **Comunicação:** É uma caixa-preta. **Não pode** conhecer outros controllers, managers ou o `ManagerRegistry`. Ele recebe dados, processa e retorna, ou modifica o estado que lhe foi passado diretamente por seu manager.

### `Entity`
*   **Função:** Representa um objeto no mundo do jogo. Contém principalmente dados e lógica de comportamento muito básica.
*   **Exemplos:** `BaseEnemy`, `ExperienceOrb`, `Projectile`.
*   **Ciclo de Vida:** Criado e destruído dinamicamente pelos `Managers`.
*   **Comunicação:** Não conhece ninguém. Para sinalizar eventos importantes (como sua morte), ele despacha um evento que um `Manager` escuta.

---

## 3. Ciclo de Vida e Estrutura de Cenas

### Estrutura de Diretórios
Para manter a organização, cada cena terá sua própria pasta com uma estrutura padronizada:

```
src/
└── scenes/
    └── nome_da_cena/
        ├── managers/           # Managers específicos desta cena
        │   ├── manager_a.lua
        │   └── manager_b.lua
        ├── controllers/        # (Opcional) Controllers muito específicos desta cena
        ├── nome_da_cena_bootstrap.lua  # Responsável por criar e conectar os managers
        └── nome_da_cena_scene.lua      # O arquivo principal da cena
```

### Ciclo de Vida de um Manager
Para evitar condições de corrida na inicialização, todos os managers de cena devem seguir este ciclo de vida:

1.  **`new(deps)` (Construção):** O construtor é simples. Ele apenas cria a tabela `self`, inicializa variáveis com valores padrão (`self.list = {}`) e **recebe as dependências** de outros managers, sem usá-las ainda.
2.  **`init()` (Inicialização):** Chamado pelo bootstrap da cena **depois** que todos os managers foram construídos. Aqui, o manager pode usar suas dependências, criar seus `Controllers` e configurar seus subsistemas internos.
3.  **`destroy()` (Destruição):** Chamado pela cena quando ela está terminando. O manager deve limpar seus recursos, como parar timers ou remover listeners de eventos, para evitar vazamentos de memória.

**Exemplo Conceitual (`gameplay_bootstrap.lua`):**
```lua
function GameplayBootstrap:initializeManagers()
    local registry = ManagerRegistry:new()

    -- 1. CONSTRUÇÃO: Apenas cria as instâncias e injeta o registry.
    local playerManager = PlayerManager:new(registry)
    local enemyManager = EnemyManager:new(registry)
    registry:register("playerManager", playerManager)
    registry:register("enemyManager", enemyManager)

    -- 2. INICIALIZAÇÃO: Agora eles podem se comunicar e criar seus controllers.
    playerManager:init()
    enemyManager:init() -- Garante que o PlayerManager já existe quando o EnemyManager precisar dele.

    return registry
end
```

---

## 4. Regras de Ouro

Estas são as regras inegociáveis do projeto.

### Regra 1: Fluxo de Dependência Unidirecional
As dependências fluem em uma única direção: **`Scene` -> `Manager` -> `Controller` -> `Entity`**. Um componente de nível inferior **nunca** pode ter uma referência direta a um componente de nível superior. Para comunicar "para cima", use eventos.

**Exemplo:**
```lua
-- RUIM: A entidade conhece e chama o manager diretamente (acoplamento alto)
function BaseEnemy:die()
    -- ... lógica de morte
    EnemyManager:removeEnemy(self) -- Proibido!
end

-- BOM: A entidade dispara um evento genérico (desacoplado)
function BaseEnemy:die()
    -- ... lógica de morte
    EventService:dispatch(GameEvents.ENEMY_DIED, { enemyId = self.id, value = self.expValue })
end

-- Em EnemyManager, ele escuta o evento:
function EnemyManager:init()
    EventService:subscribe(GameEvents.ENEMY_DIED, function(data)
        self:removeEnemyById(data.enemyId)
    end)
end
```

### Regra 2: Separação Estrita de Dados e Lógica
Arquivos de lógica (`managers`, `controllers`) **não devem** conter dados de jogo "hardcoded". **Todos** os dados de balanceamento devem residir em `src/data/`.

**Exemplo:**
```lua
-- RUIM: Stats definidos diretamente na lógica do inimigo
function Zombie:new()
    self.health = 100 -- Magic number
    self.damage = 15  -- Magic number
end

-- BOM: A lógica carrega os dados de um arquivo central
-- Em src/data/enemies_data.lua
EnemiesData = {
    ZOMBIE = { health = 100, damage = 15, asset = "zombie_walk.png" }
}

-- Em src/entities/zombie.lua
function Zombie:new(type)
    local data = EnemiesData[type]
    assert(data, "Dados não encontrados para o inimigo: " .. type)
    self.health = data.health
    self.damage = data.damage
    self.asset = Assets.get(data.asset)
end
```

### Regra 3: Proibição de "Magic Values"
Nunca use strings ou números soltos no código. Use constantes e "enums".

**Exemplo:**
```lua
-- RUIM: Valores "mágicos" espalhados pelo código, frágeis a erros de digitação.
player.moveSpeed = 1.4
if weapon.rarity == "legendary" then
    -- ...
end

-- BOM: Valores centralizados, reutilizáveis e com autocompletar.
-- Em src/config/constants.lua
Constants = { MOVE_SPEED_DEFAULT = 1.4 }

-- Em src/data/enums.lua
RarityType = { COMMON = "common", RARE = "rare", LEGENDARY = "legendary" }

-- No código:
player.moveSpeed = Constants.MOVE_SPEED_DEFAULT
if weapon.rarity == RarityType.LEGENDARY then
    -- ...
end
```

### Regra 4: Documentação LDoc Obrigatória
**Toda** classe, método público, parâmetro e retorno deve ter documentação LDoc completa e precisa.

**Exemplo:**
```lua
---@class PlayerManager
---@field player Player|nil O jogador atual da cena.
local PlayerManager = {}

---Move o jogador para uma nova posição.
---@param x number A coordenada X para onde mover.
---@param y number A coordenada Y para onde mover.
---@return boolean success Se o movimento foi bem-sucedido.
function PlayerManager:moveTo(x, y)
    -- ... lógica
    return true
end
```

### Regra 5: Padrão de Nomenclatura Consistente
*   **Classes/Módulos:** `PascalCase` (e.g., `EnemyManager`, `HealthController`)
*   **Instâncias e Funções:** `camelCase` (e.g., `local enemyManager`, `function getEnemies()`)
*   **Arquivos:** `snake_case` (e.g., `enemy_manager.lua`)
*   **Constantes:** `SCREAMING_SNAKE_CASE` (e.g., `Constants.MAX_ENEMIES`)

### Regra 6: Padronização do Tratamento de Erros
*   **`assert()`**: Para **erros de programação** que indicam um bug e devem parar o jogo no desenvolvimento.
*   **`Logger.error()`**: Para **erros operacionais** que podem acontecer em produção e devem ser registrados sem travar.

**Exemplo:**
```lua
---@param playerManager PlayerManager
function EnemyManager:new(playerManager)
    -- ERRO DE PROGRAMAÇÃO: É um bug se o PlayerManager não for fornecido.
    assert(playerManager, "EnemyManager requer uma instância de PlayerManager.")
    self.playerManager = playerManager
end

function PersistenceService:loadGame()
    local success, data = love.filesystem.read("save.dat")
    if not success then
        -- ERRO OPERACIONAL: O save pode não existir, o que é previsto.
        Logger:error("[PersistenceService] Falha ao ler save.dat: " .. tostring(data))
        return nil -- Recupera-se graciosamente.
    end
    return JSON:decode(data)
end
```

### Regra 7: Abstração de Entradas do Usuário
A lógica de jogo não deve depender de entradas físicas. Deve haver um `InputService` que mapeia entradas para **ações de jogo**.

**Exemplo:**
```lua
-- RUIM: Código acoplado à tecla física 'q'.
function PlayerManager:update(dt)
    if love.keyboard.isDown('q') then
        self:usePotion()
    end
end

-- BOM: Código desacoplado, que funciona com teclado, controle, etc.
-- Em InputService (configuração):
InputService:mapActionToKey("use_potion", "q")

-- Em PlayerManager:
function PlayerManager:update(dt)
    if InputService:isActionPressed("use_potion") then
        self:usePotion()
    end
end
```

### Regra 8: Fluxo de Dados da UI de Mão Única
A UI pode **ler** dados diretamente dos managers, mas para **modificar** o estado do jogo, ela dispara um evento.

**Exemplo:**
```lua
-- Em HUDGameplayManager (para desenhar a vida):
function HUDGameplayManager:draw()
    -- LEITURA (OK): Acessa o dado para exibir.
    local health = self.playerManager:getHealth()
    love.graphics.print("HP: " .. health, 10, 10)
end

-- Em um botão da UI (para usar a poção):
function PotionButton:onClick()
    -- ESCRITA (RUIM): Chamar o manager diretamente é proibido.
    -- self.playerManager:usePotion() -- PROIBIDO!

    -- ESCRITA (BOM): Dispara um evento que o PlayerManager vai escutar.
    EventService:dispatch(GameEvents.POTION_BUTTON_CLICKED)
end
``` 