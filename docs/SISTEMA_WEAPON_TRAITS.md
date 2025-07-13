# Sistema de Weapon Traits (Class Traits)

## Visão Geral

O Sistema de Weapon Traits é inspirado no sistema de "class traits" do jogo Halls of Torment, permitindo que os jogadores especializem suas armas através de caminhos de progressão únicos. Cada tipo de ataque possui dois caminhos distintos, cada um com duas variações, criando opções de build diversificadas e especializações estratégicas.

## Características Principais

### Estrutura de Progressão
- **8 tipos de ataque** suportados
- **2 caminhos** por tipo de ataque
- **2 variações** por caminho
- **5 níveis regulares** + **1 ultimate** por variação
- **Máximo de 2 weapon traits** por level up
- **50% de chance** de weapon traits aparecerem no level up

### Tipos de Ataque Suportados
1. **Cone Slash** (Espadas) - Maestria Física vs Maestria Espiritual
2. **Alternating Cone Strike** (Adagas) - Arte da Velocidade vs Arte da Mobilidade
3. **Circular Smash** (Martelos) - Força Bruta vs Resistência
4. **Arrow Projectile** (Arcos) - Precisão vs Velocidade
5. **Chain Lightning** (Raios) - Poder vs Velocidade
6. **Flame Stream** (Fogo) - Intensidade vs Velocidade
7. **Burst Projectile** (Shotguns) - Dispersão vs Velocidade
8. **Sequential Projectile** (Metralhadoras) - Supressão vs Precisão

## Regras de Progressão

### Restrições de Variação
- **Não é possível misturar variações** no mesmo nível dentro de um caminho
- Uma vez escolhida uma variação, deve-se continuar com ela ou mudar para a outra variação **no mesmo nível**
- Exemplo: Se escolher "Cobertura I", só pode prosseguir para "Cobertura II" ou mudar para "Técnica I"

### Requisitos para Ultimates
- Requer o trait base da mesma variação no **nível 5**
- Exemplo: "Maestria Devastadora" requer "Cobertura V"
- Ultimates têm **trade-offs significativos** (bônus alto com malus)

## Implementação Técnica

### Arquivos Principais

#### `src/data/weapon_traits_data.lua`
- Contém todas as definições de weapon traits
- Estrutura hierárquica: `attack_class_path_variation_level`
- Modificadores com tipos "base" e "percentage"
- Sistema de cores por caminho

#### `src/controllers/weapon_traits_controller.lua`
- Gerencia weapon traits aprendidos
- Valida regras de progressão
- Aplica modificadores no PlayerStateController

#### Integração com Sistemas Existentes
- **PlayerManager**: Inicializa e persiste weapon traits
- **HunterManager**: Salva weapon traits por hunter
- **LevelUpModal**: Inclui weapon traits nas opções
- **PlayerStateController**: Aplica modificadores de stats

## Exemplos de Progressão

### Cone Slash - Caminho 1: Maestria Física

#### Variação 1: Cobertura
```
Cobertura I → Cobertura II → Cobertura III → Cobertura IV → Cobertura V → Maestria Devastadora
+8% área   +8% área      +8% área       +8% área      +8% área    +100 dano, -0.3 crit
```

#### Variação 2: Técnica
```
Técnica I → Técnica II → Técnica III → Técnica IV → Técnica V → Técnica Perfeita
+3% crit   +3% crit    +3% crit     +3% crit    +3% crit   +50% crit dmg, -15% atk speed
```

### Alternating Cone Strike - Caminho 2: Arte da Mobilidade

#### Variação 1: Mobilidade
```
Mobilidade I → Mobilidade II → ... → Dançarino Sombrio
+3% move     +3% move           +50% move, -25% vida
```

## Balanceamento

### Filosofia de Design
- **Especialização vs Versatilidade**: Escolhas definem o estilo de jogo
- **Trade-offs nos Ultimates**: Poder extremo com consequências
- **Progressão Linear**: Cada nível oferece melhoria consistente
- **Escolhas Estratégicas**: Múltiplos caminhos viáveis

### Valores Base
- **Níveis regulares**: Bônus moderados (3-12% por nível)
- **Ultimates**: Bônus altos (50-150%) com malus significativo (15-50%)
- **Frequência**: 50% chance de aparecer, máximo 2 por level up

## Sistema de Traduções

### Estrutura no pt_BR.lua
```lua
weapon_traits = {
    cone_slash_path1_coverage = {
        name = "Cobertura",
        description = "Expande o alcance e área dos golpes de espada."
    },
    -- ... outros traits
}
```

### Convenção de Nomes
- **IDs**: `attack_class_path_variation_level`
- **Traduções**: Nome descritivo + descrição temática
- **Ultimates**: Nomes épicos que refletem o poder

## Debug e Desenvolvimento

### Logs Disponíveis
```lua
Logger.debug("weapon_traits_controller.apply_trait.success", ...)
Logger.info("weapon_traits_controller.reapply_all", ...)
Logger.error("weapon_traits_controller.apply_trait.cannot_learn", ...)
```

### Métodos de Debug
```lua
-- Informações de debug
local debugInfo = weaponTraitsController:getDebugInfo()

-- Limpar todos os traits
weaponTraitsController:clearAllTraits()

-- Replicar traits (útil para testes)
weaponTraitsController:reapplyAllTraits()
```

## Casos de Uso

### Builds Especializadas

#### Build "Berserker" (Cone Slash)
- **Caminho**: Maestria Física → Técnica
- **Foco**: Dano crítico extremo
- **Ultimate**: Técnica Perfeita
- **Estilo**: Alto risco, alto retorno

#### Build "Tank" (Circular Smash)
- **Caminho**: Resistência → Resistência
- **Foco**: Sobrevivência
- **Ultimate**: Fortaleza Inabalável
- **Estilo**: Absorver dano, controlar área

#### Build "Velocista" (Alternating Cone Strike)
- **Caminho**: Arte da Velocidade → Rajada
- **Foco**: Ataques múltiplos rápidos
- **Ultimate**: Tempestade de Lâminas
- **Estilo**: DPS alto com volume de ataques

## Considerações para Expansão

### Novos Tipos de Ataque
1. Adicionar definições em `weapon_traits_data.lua`
2. Criar traduções em `pt_BR.lua`
3. Testar balanceamento
4. Documentar novos caminhos

### Novos Modificadores
- Sistema suporta novos tipos de stats
- Adicionar em `modifiers_per_level`
- Verificar integração com PlayerStateController

### Melhorias Futuras
- **Synergias entre caminhos**: Bônus por combinar diferentes ultimates
- **Weapon Mastery**: Meta-progressão além dos traits
- **Visual Effects**: Efeitos visuais únicos por ultimate
- **Sound Design**: Áudio específico para ativação de ultimates

## Troubleshooting

### Problemas Comuns

#### Weapon Traits não aparecendo no Level Up
1. Verificar se arma está equipada
2. Confirmar que `attackClass` está definido na arma
3. Verificar se há traits disponíveis para aprender

#### Traits não sendo aplicados
1. Verificar se `WeaponTraitsController` está inicializado
2. Confirmar integração com `PlayerStateController`
3. Verificar logs de erro

#### Save/Load não funcionando
1. Verificar métodos `saveData()`/`loadData()` 
2. Confirmar integração com `HunterManager`
3. Verificar formato dos dados salvos

### Comandos de Debug
```lua
-- No console do jogo (se disponível)
local pm = ManagerRegistry:get("playerManager")
local debugInfo = pm.weaponTraitsController:getDebugInfo()
print(json.encode(debugInfo))
```

## Conclusão

O Sistema de Weapon Traits adiciona profundidade estratégica significativa ao Solo Hero, permitindo especialização de builds e criando rejoabilidade através de diferentes estilos de jogo. A implementação modular permite fácil expansão e manutenção, enquanto as regras de progressão garantem escolhas significativas para os jogadores.

A integração com sistemas existentes é transparente, mantendo compatibilidade com saves antigos e permitindo evolução gradual do sistema conforme necessário. 