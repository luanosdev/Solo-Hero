# Sistema de Melhorias de Runas

## Visão Geral

O sistema de melhorias de runas permite que o jogador aprimore as runas equipadas através de melhorias escolhidas no level up. Cada melhoria afeta apenas os atributos da própria runa, não alterando atributos do personagem ou de outras runas.

## Funcionalidades Principais

### 1. Níveis Máximos por Raridade

- **Rank E**: 5 níveis máximos
- **Rank D**: 10 níveis máximos  
- **Rank C**: 15 níveis máximos
- **Rank B**: 20 níveis máximos
- **Rank A**: 25 níveis máximos
- **Rank S**: 30 níveis máximos

### 2. Tipos de Melhorias

#### Melhorias Normais
- Disponíveis desde o nível 1 ou 2 da runa
- Podem ser escolhidas múltiplas vezes (até o limite definido)
- Exemplos: Energia Concentrada, Rotação Acelerada, Aura Tóxica

#### Ultra Melhorias
- Aparecem apenas em níveis múltiplos de 5
- Geralmente têm efeitos poderosos com trade-offs
- Só podem ser escolhidas uma vez
- Exemplos: Constelação Orbital, Tempestade Devastadora

### 3. Remoção do Pool

Quando uma runa atinge seu nível máximo baseado na raridade, todas as suas melhorias são automaticamente removidas do pool de opções de level up.

## Runas Disponíveis

### Runa Orbital (rune_orbital_e)
**Atributos modificáveis**: damage, orbitRadius, orbCount, orbRadius, rotationSpeed

**Melhorias Disponíveis**:
- **Energia Concentrada**: +25% dano (máximo 3 usos)
- **Rotação Acelerada**: +20% velocidade de rotação (máximo 3 usos)
- **Órbita Expandida**: +15% raio de órbita (máximo 3 usos)
- **Esferas Ampliadas**: +10% tamanho das esferas (máximo 3 usos)
- **Constelação Orbital (Ultra)**: +1 esfera orbital, -15% dano (nível 5)

### Runa de Trovão (rune_thunder_e)
**Atributos modificáveis**: damage, interval, radius

**Melhorias Disponíveis**:
- **Tempestade Furiosa**: +30% dano (máximo 3 usos)
- **Descarga Rápida**: -20% intervalo entre raios (máximo 3 usos)
- **Alcance Estendido**: +25% alcance (máximo 3 usos)
- **Tempestade Devastadora (Ultra)**: +100% dano, +50% intervalo (nível 5)

### Runa de Aura (rune_aura_e)
**Atributos modificáveis**: damage, tick_interval, radius

**Melhorias Disponíveis**:
- **Aura Tóxica**: +25% dano por tick (máximo 3 usos)
- **Pulso Acelerado**: -20% intervalo entre ticks (máximo 3 usos)
- **Aura Expandida**: +20% alcance (máximo 3 usos)
- **Aura Devastadora (Ultra)**: +80% dano, -30% alcance (nível 5)

## Implementação Técnica

### Arquivos Principais

- **`src/data/rune_upgrades_data.lua`**: Definições das melhorias
- **`src/controllers/rune_controller.lua`**: Lógica de aplicação
- **`src/ui/level_up_modal.lua`**: Interface de seleção
- **`src/data/translations/pt_BR.lua`**: Traduções

### Fluxo de Funcionamento

1. **Geração de Opções**: `LevelUpModal` consulta `RuneController` para obter melhorias disponíveis
2. **Verificação de Elegibilidade**: Sistema verifica nível da runa, usos restantes e se atingiu nível máximo
3. **Aplicação**: Melhoria é aplicada diretamente na instância da runa ativa
4. **Rastreamento**: Sistema registra quantas vezes cada melhoria foi usada

### Tipos de Modificadores

```lua
-- Exemplo de modificador percentual
{ attribute = "damage", type = "percentage", value = 25 }

-- Exemplo de modificador base
{ attribute = "orbCount", type = "base", value = 1 }
```

## Considerações de Design

### Balanceamento
- Melhorias normais oferecem incrementos moderados
- Ultra melhorias têm efeitos dramáticos mas com trade-offs
- Limitações de uso previnem stacking excessivo

### Progressão
- Sistema encoraja especialização em runas específicas
- Runas de raridade superior têm mais oportunidades de melhoria
- Níveis múltiplos de 5 oferecem marcos importantes

### Integração
- Melhorias aparecem no pool junto com traits de armas e bônus de level up
- Sistema de peso igual garante distribuição balanceada
- Remoção automática do pool previne opções desnecessárias

## Expansão Futura

O sistema foi projetado para ser facilmente expansível:
- Adicionar novas runas requer apenas definir seus atributos modificáveis
- Criar novas melhorias segue o mesmo padrão existente
- Sistema de raridade permite escalonamento automático de níveis máximos 