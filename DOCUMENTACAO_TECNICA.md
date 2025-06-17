# Documentação Técnica - Solo Hero

## 1. Visão Geral da Arquitetura

O projeto é estruturado em torno de uma arquitetura modular baseada em "Managers", onde cada manager é responsável por um subsistema específico do jogo (jogador, inimigos, itens, etc.).

-   **Ponto de Entrada**: O ciclo de vida do jogo é gerenciado pelo `SceneManager` (`src/core/scene_manager.lua`), que controla a transição entre telas como o Bootloader, Lobby e a Gameplay.
-   **Registro de Managers**: Um `ManagerRegistry` (`src/managers/manager_registry.lua`) atua como um container de injeção de dependência, permitindo que diferentes managers acessem uns aos outros sem acoplamento direto. Managers são registrados durante a inicialização (em `main.lua` e `src/core/bootstrap.lua`).
-   **Separação de Responsabilidades**: O código é organizado com uma clara separação entre:
    -   **Dados**: Arquivos de configuração em `src/data/` (itens, arquétipos, hordas).
    -   **Lógica de Jogo**: Classes em `src/classes/`, `src/entities/`, e a orquestração principal nos `src/managers/`.
    -   **Apresentação**: A interface do usuário em `src/ui/` e as cenas em `src/scenes/`.

## 2. Fluxo de Dados e Cálculo de Atributos do Caçador

O sistema de atributos é fundamental e segue uma ordem de operações estrita para garantir consistência.

### 2.1. Definições Base

-   **Atributos Padrão**: Todo caçador começa com um conjunto de atributos base definidos em `src/config/constants.lua`, na tabela `Constants.HUNTER_DEFAULT_STATS`.
-   **Arquétipos**: Os arquétipos, definidos em `src/data/archetypes_data.lua`, fornecem os primeiros modificadores a estes stats base.

### 2.2. Cálculo de Atributos (Fora de Jogo)

Quando um caçador está no Lobby, seus atributos finais são calculados pelo `HunterManager` (`src/managers/hunter_manager.lua`) através da função `_calculateFinalStats`. Esta função é usada para exibir os stats na UI do Lobby e para preparar o estado inicial do jogador para uma partida.

A ordem de cálculo é:
1.  Começa com `Constants.HUNTER_DEFAULT_STATS`.
2.  Agrega todos os modificadores de **todos os arquétipos** do caçador.
3.  Aplica os bônus na seguinte ordem para cada atributo:
    -   **Soma de Bônus Fixos**: Adiciona valores de arquétipos do tipo `"fixed"`.
    -   **Soma de Frações Fixas**: Adiciona valores de arquétipos do tipo `"fixed_percentage_as_fraction"` (usado para stats que já são percentuais, como chance de crítico).
    -   **Aplicação de Multiplicadores**: Multiplica o resultado por `(1 + SomaPercentuais / 100)`, onde `SomaPercentuais` vem de arquétipos do tipo `"percentage"`.

### 2.3. Cálculo de Atributos (Em Jogo)

Uma vez que uma partida começa (`gameplay_scene.lua`), o `PlayerManager` (`src/managers/player_manager.lua`) assume o controle do estado do jogador.

-   **Estado Inicial**: O `PlayerManager` recebe os stats calculados pelo `HunterManager` e os usa para inicializar um `PlayerState` (`src/entities/player_state.lua`).
-   **Recálculo Dinâmico**: A função `PlayerManager:getCurrentFinalStats()` é a fonte da verdade para os atributos do jogador *durante o jogo*. Ela **recalcula tudo do zero**, aplicando não apenas os bônus de arquétipo novamente, mas também os bônus adquiridos durante a partida (de `levelBonus` e `fixedBonus` no `PlayerState`). Isso garante que a ordem de operações seja sempre mantida, mesmo com novos bônus.
-   **Regra de Cache**: Para otimizar o desempenho, `PlayerManager` armazena o resultado de `getCurrentFinalStats` em um cache (`finalStatsCache`). **Qualquer sistema que altere um stat do jogador (como o modal de level-up) deve obrigatoriamente chamar `playerManager:invalidateStatsCache()` para forçar um recálculo.**

## 3. Sistema de Combate

### 3.1. Habilidades de Armas

A lógica de ataque é desacoplada do jogador. Cada arma define sua `attackClass` e `weaponClass` em `src/data/items/weapons.lua`.
1.  Ao equipar uma arma, o `PlayerManager` carrega a classe da arma (ex: `src/items/weapons/generic_cone_slash.lua`).
2.  A classe da arma, em seu método `:equip`, carrega e instancia a `attackClass` correspondente (ex: `src/abilities/player/attacks/cone_slash.lua`).
3.  O `PlayerManager` então interage com essa instância de habilidade para executar e desenhar os ataques.

### 3.2. Redução de Dano por Defesa

A quantidade de dano que um ataque causa é reduzida pela defesa do alvo. A fórmula, encontrada em `player_manager.lua` e `base_enemy.lua`, é:
`Redução = Defesa / (Defesa + K)`
Onde `K` é `Constants.DEFENSE_DAMAGE_REDUCTION_K`. A redução máxima é limitada por `Constants.MAX_DAMAGE_REDUCTION`.

### 3.3. Knockback

O sistema de knockback é determinado pela interação de duas propriedades (definidas em `Constants.lua` e aplicadas em `CombatHelpers.lua`):
-   `KNOCKBACK_POWER`: O "poder" de um ataque para iniciar um knockback.
-   `KNOCKBACK_RESISTANCE`: A resistência de um inimigo a ser empurrado.
Um knockback só ocorre se `attackKnockbackPower >= targetEnemy.knockbackResistance`. A força do empurrão é então calculada usando `attackKnockbackForce` e o atributo `strength` do jogador.

## 4. Geração de Inimigos e Hordas

O `EnemyManager` (`src/managers/enemy_manager.lua`) controla o fluxo de inimigos com base em configurações de horda definidas em `src/data/portals/portal_definitions.lua` e `src/config/hordes/`.

-   **Ciclos de Horda**: Cada mapa tem uma série de "ciclos" com duração, inimigos permitidos e regras de spawn próprias.
-   **Major Spawns**: Ondas grandes que ocorrem em intervalos fixos. A quantidade de inimigos aumenta com o tempo de jogo (`countScalePerMin`).
-   **Minor Spawns**: Pequenos grupos contínuos. A frequência aumenta com o tempo (`intervalReductionPerMin`) até um limite (`minInterval`).
-   **MVPs e Bosses**: Spawnam em tempos pré-definidos (`bossConfig`) ou intervalos regulares (`mvpConfig`). Um inimigo normal é transformado em MVP recebendo um nome (`EnemyNamesData`) e um título com bônus (`MVPTitlesData`).

## 5. Sistema de Itens e Drops

### 5.1. Gerenciamento de Dados de Itens

O `ItemDataManager` (`src/managers/item_data_manager.lua`) carrega todos os dados base dos itens de `src/data/items/` para um banco de dados em memória, o `itemDatabase`. Ele é a fonte única da verdade para as propriedades de um item.

### 5.2. Lógica de Drop

O `DropManager` (`src/managers/drop_manager.lua`) lida com a geração de itens quando um inimigo é derrotado.
-   **Tabelas de Drop**: As classes de inimigos (ex: `src/classes/enemies/zombie.lua`) definem uma `dropTable` com itens `guaranteed` (garantidos) e de `chance`. A tabela pode ter seções para `normal`, `mvp` e `boss`.
-   **Drop Pools**: É possível definir um `item_pool`, do qual um item aleatório será selecionado e dropado.
-   **Drops Globais**: Uma tabela em `src/data/global_drops.lua` é verificada para cada inimigo derrotado, dando uma pequena chance de dropar itens raros independentemente do inimigo.
-   **Influência da Sorte (Luck)**: O atributo `luck` do jogador atua como um multiplicador direto na chance de todos os drops não garantidos: `Chance Final = (Chance Base / 100) * Multiplicador de Sorte`.

## 6. Otimização

-   **Culling**: O `EnemyManager` usa uma margem (`despawnMargin`) para remover inimigos que estão muito longe da câmera, evitando atualizações desnecessárias.
-   **Pooling**: Inimigos, projéteis e entidades de drop são reutilizados através de um sistema de *object pooling* para minimizar a criação de novas tabelas e a sobrecarga do coletor de lixo (`TablePool`).
-   **Spatial Grid**: O `SpatialGridIncremental` (`src/utils/spatial_grid_incremental.lua`) é usado para otimizar a detecção de colisões e buscas em área, dividindo o mapa em células e permitindo que as entidades consultem apenas as células vizinhas em vez de todas as outras entidades do jogo.
-   **Render Pipeline**: A renderização é centralizada no `RenderPipeline` (`src/core/render_pipeline.lua`), que utiliza `SpriteBatch` para desenhar grandes quantidades de inimigos de forma eficiente, agrupando-os por textura e ordenando-os por profundidade (eixo Y) para criar o efeito 2.5D.