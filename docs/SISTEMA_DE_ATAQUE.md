# Sistema de Orquestração de Ataque

Este documento descreve as regras de como as ações do jogador se traduzem em ataques no jogo, gerenciadas pelo `PlayerManager`. O sistema foi projetado para ser híbrido, oferecendo tanto responsividade para cliques rápidos quanto a conveniência do auto-ataque.

## Regras de Interação

O comportamento do ataque é definido por três eventos de input principais:

### 1. Ataque por Clique (Ação Pressionada)

-   **Gatilho:** `inputService:wasActionPressed(ActionTypes.ATTACK)`
-   **Comportamento:**
    -   Ao detectar o **pressionar** da ação de ataque (ex: clique no botão esquerdo do mouse), o sistema imediatamente tenta disparar um ataque (`tryAttack`). Isso garante que cliques rápidos sejam responsivos e sempre resultem em uma ação imediata.
    -   Simultaneamente, ele ativa uma sobreposição temporária no `AutoAttackController` (`overrideAutoAttack(true)`), forçando o modo de auto-ataque.

### 2. Ataque Contínuo (Ação Segurada)

-   **Gatilho:** `inputService:isActionDown(ActionTypes.ATTACK)`
-   **Comportamento:**
    -   Enquanto o botão de ataque estiver **segurado**, a sobreposição de auto-ataque permanece ativa.
    -   A verificação `autoAttackController:isAutoAttackEnabled()` retornará `true`, fazendo com que `tryAttack` seja chamado continuamente a cada frame que o cooldown da arma permitir.
    -   Isso cria a funcionalidade de "segurar para atacar continuamente".

### 3. Fim do Ataque (Ação Solta)

-   **Gatilho:** `inputService:wasActionReleased(ActionTypes.ATTACK)`
-   **Comportamento:**
    -   Ao detectar que o botão de ataque foi **solto**, a sobreposição temporária é removida (`overrideAutoAttack(false)`).
    -   O `AutoAttackController` retorna imediatamente ao seu estado padrão, que é controlado pelo jogador através da tecla de alternância (padrão: 'X').
    -   Se o modo de auto-ataque padrão estiver desligado, os ataques cessam. Se estiver ligado, eles continuarão.

## Alternância do Auto-Ataque (Modo Padrão)

-   **Gatilho:** `inputService:wasActionPressed(ActionTypes.TOGGLE_AUTO_ATTACK)` (padrão: tecla 'X')
-   **Comportamento:**
    -   Esta ação alterna o estado **padrão** do auto-ataque.
    -   Este estado é independente da sobreposição temporária causada por segurar o botão de ataque.
    -   **Exemplo:** Um jogador pode desativar o auto-ataque com 'X' para ter controle total sobre cada ataque, mas ainda pode segurar o botão para atacar continuamente quando necessário.

## Resumo da Lógica

Este sistema híbrido garante que o jogador tenha tanto a precisão de um ataque por clique quanto a conveniência de um ataque automático ao segurar o botão, sem conflitos entre os dois modos de jogo. A lógica centraliza-se no `PlayerManager` que orquestra o `InputService` e o `AutoAttackController`. 