# Análise Arquitetural e Sugestões de Melhoria

Este documento descreve os principais pontos de dor arquiteturais identificados no projeto e sugere melhorias para aumentar a robustez, manutenibilidade e escalabilidade do código.

## 1. Pontos de Dor e Desafios Atuais

### 1.1. Acoplamento Elevado entre Managers Core

-   **Observação**: Existe um forte acoplamento entre os managers principais, especialmente visível na `gameplay_scene.lua` e no `player_manager.lua`. O `PlayerManager`, por exemplo, possui referências diretas a quase todos os outros managers de gameplay (`EnemyManager`, `InputManager`, `DropManager`, etc.). Da mesma forma, o `DropManager` depende do `PlayerManager` para obter o `luck` e do `EnemyManager` para o tipo de inimigo.
-   **Dor**: Esse acoplamento torna a substituição ou o teste de um manager isoladamente muito difícil. Uma mudança em um manager pode ter efeitos cascata inesperados em outros. Por exemplo, a lógica para iniciar a extração de itens na `gameplay_scene.lua` precisa acessar o `PlayerManager`, o `InventoryManager` e o `HunterManager` para coletar todos os dados necessários.
-   **Sugestão**: Introduzir um **sistema de eventos (Event Bus/Dispatcher)**. Em vez de managers se chamarem diretamente, eles emitiriam eventos (ex: `"player_leveled_up"`, `"enemy_defeated"`, `"item_looted"`). Outros managers poderiam se inscrever nesses eventos e reagir a eles. Isso desacoplaria os managers, permitindo que eles operem de forma mais independente.

### 1.2. Duplicação da Lógica de Cálculo de Atributos

-   **Observação**: A lógica para calcular os atributos finais de um personagem (base + arquétipos + bônus) está presente de forma muito similar tanto no `HunterManager` (`_calculateFinalStats`) quanto no `PlayerManager` (`getCurrentFinalStats`).
-   **Dor**: Manter duas implementações da mesma regra de negócio complexa é uma fonte provável de bugs. Se a fórmula de cálculo mudar, ela precisa ser atualizada em dois lugares distintos, aumentando a chance de inconsistências.
-   **Sugestão**: Criar um módulo utilitário, como `StatsCalculator.lua`, que contenha uma única função `calculateFinalStats`. Esta função receberia os dados base, os arquétipos e os bônus (de level-up, etc.) e retornaria os atributos finais. Tanto o `HunterManager` quanto o `PlayerManager` chamariam esta função, garantindo que a regra seja aplicada de forma consistente em todo o jogo.

### 1.3. Gerenciamento de Animação Distribuído e Repetitivo

-   **Observação**: Existem múltiplos arquivos de animação (`animated_player.lua`, `animated_skeleton.lua`, `animated_character.lua`, `animated_spritesheet.lua`). Embora o `AnimatedSpritesheet` seja o mais recente e robusto, a existência dos outros indica uma evolução que deixou código legado. O carregamento e a lógica de atualização são específicos para cada um, levando a repetição de código, especialmente no `getDirectionFromAngle` e na lógica de timers.
-   **Dor**: Adicionar um novo personagem ou inimigo requer decidir qual sistema de animação usar, ou até mesmo criar um novo. A manutenção se torna complexa, pois uma correção de bug em uma lógica de animação pode precisar ser replicada em outros arquivos.
-   **Sugestão**: Unificar todos os sistemas de animação em um único e poderoso manager, provavelmente expandindo o `AnimatedSpritesheet`. Este novo `AnimationManager` centralizaria o carregamento de assets (usando o `AssetManager`), a lógica de atualização de frames, o cálculo de direção e a transição entre estados (idle, walk, attack, death). Os dados específicos de cada personagem (paths dos spritesheets, grids, frame times) seriam definidos em um único local, como o `src/data/enemies.lua`, e o `AnimationManager` usaria essa configuração para animar qualquer entidade.

### 1.4. Lógica de UI Descentralizada

-   **Observação**: A lógica para desenhar e interagir com elementos da UI está espalhada entre as cenas (`lobby_scene.lua`, `gameplay_scene.lua`) e componentes específicos (`level_up_modal.lua`). A `lobby_scene.lua`, por exemplo, gerencia diretamente o estado de arrastar e soltar (`isDragging`, `draggedItem`, etc.).
-   **Dor**: A cena principal se torna muito complexa e com muitas responsabilidades, misturando lógica de UI com a orquestração de managers. Adicionar novos elementos de UI ou modais pode aumentar ainda mais essa complexidade.
-   **Sugestão**: Criar um `UIManager` ou usar uma abordagem de Componentes de UI mais robusta. A `lobby_scene` não deveria saber sobre `isDragging`; ela deveria delegar todos os eventos de mouse para os componentes (`EquipmentScreen`, `InventoryGridUI`), e eles deveriam gerenciar seus próprios estados internos. Isso encapsularia a lógica da UI e limparia o código da cena. A introdução de uma classe `Component` base (`src/ui/components/Component.lua`) é um ótimo primeiro passo nessa direção.

## 2. Sugestões de Melhorias Estruturais

### 2.1. Centralizar a Lógica de Armas e Habilidades

-   **Observação**: Atualmente, uma arma (`src/items/weapons/*.lua`) instancia sua própria lógica de ataque (`src/abilities/player/attacks/*.lua`). O `PlayerManager` interage com a `attackInstance` da arma equipada.
-   **Sugestão**: Consolidar a definição de armas e habilidades. Em vez de arquivos separados para a arma (item) e sua lógica, poderíamos ter uma abordagem mais orientada a dados. O arquivo da arma em `data/items/weapons.lua` poderia conter todas as informações necessárias, incluindo a classe de habilidade a ser usada e seus parâmetros. O `PlayerManager` leria esses dados e instanciaria a habilidade genérica correspondente, configurando-a com os parâmetros da arma. Isso simplificaria a adição de novas armas.
-   **Exemplo**: A refatoração que levou à criação de `generic_cone_slash.lua` e `generic_circular_smash.lua` já aponta nessa direção e deve ser o padrão para todas as armas.

### 2.2. Refatorar o `PlayerState`

-   **Observação**: O `PlayerState` armazena os bônus, mas a lógica de cálculo final está no `PlayerManager`. Isso causa uma separação entre os dados e a lógica que os utiliza.
-   **Sugestão**: Mover a lógica de cálculo de stats para dentro do `PlayerState` ou para o `StatsCalculator` sugerido anteriormente. O `PlayerState` poderia ter métodos como `getFinalHealth()`, `getFinalCritChance()`, que internamente aplicariam a fórmula correta sobre seus próprios dados (`base`, `levelBonus`, `fixedBonus`). O `PlayerManager` apenas consultaria esses métodos, sem precisar conhecer a fórmula.

### 2.3. Padronizar a Estrutura de Inimigos

-   **Observação**: Assim como na animação, existem várias maneiras de definir um inimigo (ex: `common_enemy.lua`, `zombie.lua`). O `zombie.lua` e o `spider.lua` utilizam a abordagem mais moderna com `AnimatedCharacter` e `dropTable`.
-   **Sugestão**: Padronizar todas as definições de inimigos para seguir a estrutura de `zombie.lua`. Cada inimigo deve ser definido por sua tabela de configuração em `src/data/enemies.lua`, que inclui stats, animações e a `dropTable`. A classe do inimigo (`src/classes/enemies/*.lua`) seria então uma casca fina que carrega essa configuração e implementa comportamentos de IA únicos, se necessário.

Ao abordar esses pontos, o projeto se tornará mais fácil de manter, depurar e expandir com novos conteúdos e funcionalidades.