# Solo Hero
 
## Bugs rastreados: 

[x] - Corrigir a mira automatica
[x] - Coneslash: Aumentar por padrao a distancia do cone
[x] - Diminuir o colisor dos esqueletos
[x] - Verificar porque os esqueletos estao tao rapidos
[x] - Adicionar valores inteiros para Velocidade, Recuperação de vida, Dano Critico, Defesa
[ ] - Adicionar super critico
[ ] - ConeSlash: No ataque multiplo, adicioar animação de slash com delay para cada ataque extra
[ ] - FloatingNumber - Ver como pode stackar os numeros para em danos multiplos um nao sobrescrever o outro
[ ] - Criar no playermanager uma funcao para adicionar o texto em cima do jogador e criar um padrao
[ ] - Desativar os colisores ou fazer com que os inimigos se desviem de si mesmos
[ ] - Fazer um loop para rodar o level up sempre que o tiver ja XP para o proximo nivel
[ ] - Fazer uma fila para a exibição de modais
[ ] - Adicionar um contador de nivel de upgrades vc ja conseguiu para limitar um valor maximo
[x] - Constatado, no halls of torment os ataques ao tem nada de isometricos, somente o visual
[ ] - Verificar bug onde se pega o XP e nao contabiliza na barra

---

## Arquitetura do Jogo

Esta seção descreve alguns dos principais componentes e como eles interagem.

### Atributos do Jogador (`PlayerState`)

*   O estado atual do jogador, incluindo seus atributos base e bônus acumulados (nível, itens, buffs), é gerenciado centralmente (provavelmente em um módulo como `PlayerState` ou similar).
*   Funções como `getTotalDamage()`, `getTotalRange()`, `getTotalArea()`, `getTotalAttackSpeed()`, `getTotalCriticalChance()`, `getTotalMultiAttackChance()`, etc., calculam o valor final de um atributo somando o valor base com todos os bônus relevantes.
*   As habilidades consultam esses métodos para obter os valores atuais dos atributos do jogador quando necessário.

**Tabela de Atributos:**

| Atributo                  | Descrição                                                                 | Cálculo/Fonte                                         | Uso Principal                                     |
| ------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------- |
| **Dano**                  | Dano base aplicado por cada golpe/projétil da habilidade.                   | `PlayerState:getTotalDamage(baseWeaponDamage)`        | Habilidade (`cast`)                               |
| **Velocidade de Ataque**  | Multiplicador que reduz o cooldown base da arma (`cooldown / atkSpeed`).   | `PlayerState:getTotalAttackSpeed()`                   | Habilidade (`cast`)                               |
| **Alcance (Range)**       | Aumenta a distância/raio das habilidades.                                 | `PlayerState:getTotalRange()`                         | Habilidade (`update` para recalcular área)        |
| **Área**                  | Aumenta a largura (ângulo) ou raio das habilidades de área.               | `PlayerState:getTotalArea()`                          | Habilidade (`update` para recalcular área)        |
| **Chance Crítica (%)**    | Probabilidade de um golpe causar dano crítico.                            | `PlayerState:getTotalCriticalChance()`                | Habilidade (`cast`)                               |
| **Multiplicador Crítico** | Fator pelo qual o dano é multiplicado em um golpe crítico.                | `PlayerState:getTotalCriticalMultiplier()`            | Habilidade (`cast`)                               |
| **Chance Multi-Ataque**   | Chance de executar ataques extras a cada ativação (1.0 = +1 atk, 1.5 = +1 atk e 50% de +1). | `PlayerState:getTotalMultiAttackChance()`             | Habilidade (`cast`)                               |
| **Velocidade Movimento**  | Velocidade com que o jogador se move.                                     | `PlayerState:getTotalMovementSpeed()` (presumido)   | Movimentação do Jogador                           |
| **Vida Máxima**           | Quantidade máxima de pontos de vida.                                      | `PlayerState:getTotalMaxHealth()` (presumido)         | Sistema de Vida do Jogador                        |
| **Regeneração de Vida**   | Vida recuperada por segundo.                                              | `PlayerState:getTotalHealthRegen()` (presumido)       | Sistema de Vida do Jogador                        |
| **Defesa/Armadura**       | Redução de dano sofrido (fórmula a definir).                            | `PlayerState:getTotalDefense()` (presumido)           | Cálculo de Dano Sofrido                           |
| **Cooldown (Base)**       | Tempo base entre ativações de uma arma (modificado pela Vel. Ataque).     | Definido na Arma (`weapon.cooldown`)                  | Habilidade (`init`, `cast`)                       |
| **Dano (Base)**           | Dano base específico da arma (modificado pelo Dano total do jogador).      | Definido na Arma (`weapon.damage`)                    | Habilidade (`init`, `cast`)                       |
| **Range (Base)**          | Alcance/Raio base específico da arma (modificado pelo Alcance do jogador). | Definido na Arma (`weapon.range`)                     | Habilidade (`init`, `update`)                     |
| **Angle (Base)**          | Ângulo base específico da arma (modificado pela Área do jogador).          | Definido na Arma (`weapon.angle`)                     | Habilidade (`init`, `update`)                     |
| **Projéteis (Base)**      | Número base de projéteis (algumas armas/habilidades).                     | Definido na Arma (`weapon.baseProjectiles`, opcional) | Habilidade (`init`, `cast`)                       |

*Nota: Nomes de funções como `getTotal...()` e a existência de alguns atributos (Defesa, Vida Máx, etc.) são presumidos com base no contexto e podem precisar de ajuste conforme a implementação exata do `PlayerState`.*

### Armas (`BaseWeapon` e tipos específicos)

*   As armas herdam de `BaseWeapon` (`src/items/weapons/base_weapon.lua`).
*   Cada arquivo de arma específica (ex: `bow.lua`, `dual_daggers.lua`, `hammer.lua`) define as **estatísticas base** daquela arma (dano, cooldown, range, angle, etc.) e, crucialmente, o `attackType`.
*   O `attackType` referencia a tabela/classe da **Habilidade** primária que a arma utilizará (ex: `TripleArrow`, `AlternatingConeStrike`, `CircularSmash`).
*   Quando uma arma é equipada (`BaseWeapon:equip`), ela instancia a habilidade definida em seu `attackType`, passando as estatísticas base da arma para a instância da habilidade.

### Habilidades (Ataques em `src/abilities/player/attacks/`)

*   Cada habilidade de ataque (ex: `ConeSlash`, `CircularSmash`) é uma tabela/classe autocontida que define a lógica de um tipo específico de ataque.
*   **`init(playerManager)`:** Chamado quando a habilidade é instanciada pela arma. Recebe as estatísticas base da arma e armazena-as. Calcula valores iniciais da área de efeito usando os bônus *atuais* do jogador (`getTotalRange`, `getTotalArea`).
*   **`update(dt, angle)`:** Chamado a cada frame. Atualiza cooldowns, animações e, importante, **recalcula as dimensões da área de efeito** (`range`, `angleWidth`, `radius`, etc.) usando os bônus *atuais* do jogador (`getTotalRange`, `getTotalArea`). Isso garante que buffs e level ups sejam refletidos dinamicamente.
*   **`cast(...)`:** Chamado para executar o ataque. É aqui que o dano, velocidade de ataque, chance crítica e chance de multi-ataque são consultados do `PlayerState` (`getTotalDamage`, `getTotalAttackSpeed`, etc.) para garantir que usem os valores mais recentes. Aplica a lógica de dano aos inimigos na área calculada.
*   **`draw()`:** Desenha a representação visual da habilidade (a animação do ataque, prévia, etc.).

## Otimizações Futuras

*   **Recálculo de Atributos de Área:** Atualmente, atributos como `range`, `angleWidth`, `radius` são recalculados dentro do `update` de cada habilidade para garantir que os bônus do jogador (`getTotalRange`, `getTotalArea`) sejam aplicados dinamicamente. Embora funcional, isso pode gerar custo computacional se houver muitas habilidades ativas. 
    *   **Alternativa Futura:** Implementar um sistema de eventos/observador onde o `PlayerState` notifica as habilidades ativas *apenas* quando um atributo relevante muda, ou utilizar um sistema de cache com "dirty flag" no `PlayerState` para evitar recálculos desnecessários a cada frame.

## Possíveis Melhorias Futuras

*   **Introdução de um `AttributesManager`:** Atualmente, o `PlayerState` gerencia os atributos base do jogador e calcula os valores totais. Para maior escalabilidade, especialmente com a adição de mais itens, buffs/debuffs e upgrades complexos, poderíamos introduzir um `AttributesManager`.
    *   **Responsabilidade:** Centralizar o cálculo dos *atributos efetivos* do jogador (e futuramente outras entidades), considerando valores base (`PlayerState`), modificadores de itens equipados (`InventoryManager`/`PlayerManager`), bônus de runas (`RuneManager`), e buffs/debuffs temporários.
    *   **Funcionamento:** Outros sistemas consultariam o `AttributesManager` para obter o valor final de um atributo (ex: `getEffectiveAttribute("player", "damage")`) em vez de depender de cálculos dentro do `PlayerState` ou outros locais.
    *   **Colaboração:** Este manager *colaboraria* com o `PlayerState` (que continuaria armazenando os valores base e o estado atual como HP) e não o substituiria completamente.
    *   **Benefícios:** Desacoplamento, melhor gerenciamento de modificadores, maior clareza na aplicação de upgrades e bônus.
    *   **Quando considerar:** Implementar quando o gerenciamento de atributos no `PlayerState` ou a aplicação de modificadores de diversas fontes começar a ficar complexa.

*   **Unificação do Sistema de Pausa:** Atualmente, a pausa do jogo é tratada de duas formas: a tela de inventário (`InventoryScreen`) define explicitamente a flag global `game.isPaused`, enquanto os modais (`LevelUpModal`, `RuneChoiceModal`) dependem da verificação de `modal.visible` em `main.lua` para interromper a atualização do jogo. Embora funcional, isso representa uma inconsistência. 
    *   **Melhoria Futura:** Unificar a abordagem fazendo com que os modais `:show()` também definam `game.isPaused = true` e os métodos `:hide()` definam `game.isPaused = false`. Isso exigiria passar o controle do estado de pausa para os modais ou usar um sistema de eventos, mas resultaria em uma gestão de pausa mais consistente e centralizada. Considerar essa refatoração quando a gestão de múltiplos estados de pausa/UI se tornar mais complexa.

*   **Refatoração de Dependências (Service Locator vs. Injeção de Dependência):** Atualmente, a maioria dos managers obtém suas dependências usando `ManagerRegistry:get("...")` dentro de suas funções `init` (padrão Service Locator). O `InventoryManager`, por exemplo, depende do `ItemDataManager` e o busca através do Registry. Embora funcional e consistente com outros managers, uma abordagem alternativa seria usar Injeção de Dependência (DI), onde as dependências são passadas explicitamente durante a criação da instância (ex: `InventoryManager:new({ itemDataManager = itemDataMgr })`). A DI pode levar a um código mais explícito sobre as dependências e facilitar testes unitários. Considerar uma refatoração para DI no futuro se o gerenciamento de dependências se tornar mais complexo ou se a testabilidade se tornar uma prioridade maior.

*   **Abordagem de Componentes de UI:** Adotar uma abordagem de componentes de UI reutilizáveis (como a classe `Button` em `src/ui/components/button.lua`) para construir telas futuras e refatorar as existentes. 
    *   **Base Visual:** Utilizar as funções de desenho existentes em `src/ui/ui_elements.lua` como base para a lógica visual dentro dos métodos `draw()` dos novos componentes.
    *   **Layout Automático (Visão Futura):** Evoluir para um sistema de layout mais automático (inspirado em conceitos como Flexbox/Grid) para reduzir cálculos manuais de posicionamento e padding, tornando a UI mais adaptável e fácil de manter.

*   **(Adicione outras ideias futuras aqui)**