# Como Adicionar Novas Runas e Melhorias

## Adicionando uma Nova Runa

### 1. Definir a Runa Base

Primeiro, adicione a definição da runa em `src/data/items/runes.lua`:

```lua
rune_nova_e = {
    itemBaseId = "rune_nova_e",
    type = "rune",
    name = "Runa Nova",
    description = "Uma nova runa com efeitos únicos.",
    icon = "assets/runes/rune_nova_e.png",
    rarity = "E",
    color = { 1, 0.5, 0, 1 }, -- Laranja
    gridWidth = 1,
    gridHeight = 1,
    stackable = false,
    effect = "nova",
    abilityClass = "src.entities.equipments.runes.nova",
    -- Atributos específicos da runa
    damage = 100,
    explosionRadius = 120,
    cooldown = 3.0,
    chain_count = 2
}
```

### 2. Criar a Classe de Habilidade

Crie o arquivo `src/entities/equipments/runes/nova.lua`:

```lua
local Nova = {}
Nova.__index = Nova

Nova.identifier = "rune_nova"
Nova.defaultDamage = 100
Nova.defaultRadius = 120
Nova.defaultCooldown = 3.0
Nova.defaultChainCount = 2

function Nova:new(playerManager, runeItemData)
    local instance = setmetatable({}, self)
    
    instance.playerManager = playerManager
    instance.runeItemData = runeItemData
    
    -- Inicializa atributos da runa
    instance.damage = runeItemData.damage or self.defaultDamage
    instance.explosionRadius = runeItemData.explosionRadius or self.defaultRadius
    instance.cooldown = runeItemData.cooldown or self.defaultCooldown
    instance.chain_count = runeItemData.chain_count or self.defaultChainCount
    
    return instance
end

-- Implementar métodos update, draw, cast, etc.
```

### 3. Adicionar Traduções

Em `src/data/translations/pt_BR.lua`, adicione:

```lua
runes = {
    -- ... runas existentes ...
    rune_nova_e = {
        name = "Runa Nova",
        description = "Uma nova runa com efeitos únicos."
    }
}
```

## Adicionando Melhorias para uma Runa

### 1. Definir as Melhorias

Em `src/data/rune_upgrades_data.lua`, adicione as melhorias na tabela `RuneUpgradesData.Upgrades`:

```lua
-- Melhoria normal
rune_nova_e_damage_boost = {
    id = "rune_nova_e_damage_boost",
    name = "Explosão Potente",
    description = "A explosão causa |30%| mais dano.",
    image_path = tempIconPath,
    max_uses = 3,
    rune_id = "rune_nova_e",
    is_ultra = false,
    required_level = 1,
    modifiers = {
        { attribute = "damage", type = "percentage", value = 30 }
    },
    color = UPGRADE_COLORS.normal
},

-- Melhoria de alcance
rune_nova_e_range_boost = {
    id = "rune_nova_e_range_boost",
    name = "Explosão Ampla",
    description = "A explosão tem |25%| mais alcance.",
    image_path = tempIconPath,
    max_uses = 3,
    rune_id = "rune_nova_e",
    is_ultra = false,
    required_level = 2,
    modifiers = {
        { attribute = "explosionRadius", type = "percentage", value = 25 }
    },
    color = UPGRADE_COLORS.normal
},

-- Ultra melhoria
rune_nova_e_ultra_chain = {
    id = "rune_nova_e_ultra_chain",
    name = "Reação em Cadeia",
    description = "Ganha |2| explosões adicionais em cadeia, mas causa |20%| menos dano.",
    image_path = tempIconPath,
    max_uses = 1,
    rune_id = "rune_nova_e",
    is_ultra = true,
    required_level = 5,
    modifiers = {
        { attribute = "chain_count", type = "base", value = 2 },
        { attribute = "damage", type = "percentage", value = -20 }
    },
    color = UPGRADE_COLORS.ultra
}
```

### 2. Adicionar Traduções das Melhorias

Em `src/data/translations/pt_BR.lua`, adicione:

```lua
rune_upgrades = {
    -- ... melhorias existentes ...
    rune_nova_e_damage_boost = {
        name = "Explosão Potente",
        description = "A explosão causa mais dano."
    },
    rune_nova_e_range_boost = {
        name = "Explosão Ampla",
        description = "A explosão tem mais alcance."
    },
    rune_nova_e_ultra_chain = {
        name = "Reação em Cadeia",
        description = "Explosões em cadeia com trade-off de dano."
    }
}
```

## Atributos Modificáveis

### Tipos de Modificadores

```lua
-- Modificador percentual (multiplica o valor atual)
{ attribute = "damage", type = "percentage", value = 25 } -- +25%

-- Modificador base (adiciona ao valor atual)
{ attribute = "chain_count", type = "base", value = 1 } -- +1 cadeia
```

### Atributos Comuns

- **damage**: Dano base da runa
- **cooldown**: Tempo de recarga
- **radius**: Raio de efeito
- **range**: Alcance
- **duration**: Duração do efeito
- **tick_interval**: Intervalo entre ticks
- **projectile_count**: Número de projéteis
- **chain_count**: Número de cadeias
- **speed**: Velocidade de movimento/rotação

## Níveis e Raridades

### Configuração de Níveis

O sistema usa a função `RuneUpgradesData.GetMaxLevelByRarity()` para determinar o nível máximo:

```lua
-- Rank E = 5 níveis máximos
-- Rank D = 10 níveis máximos
-- Rank C = 15 níveis máximos
-- etc.
```

### Ultra Melhorias

- Aparecem apenas em níveis múltiplos de 5
- Geralmente têm efeitos poderosos com trade-offs
- Só podem ser escolhidas uma vez (`max_uses = 1`)

## Balanceamento

### Diretrizes Gerais

1. **Melhorias Normais**: Incrementos moderados (15-30%)
2. **Ultra Melhorias**: Efeitos dramáticos com trade-offs
3. **Limitação de Uso**: Previne stacking excessivo
4. **Progressão**: Melhorias mais poderosas em níveis superiores

### Exemplo de Progressão

```lua
-- Nível 1: Melhorias básicas (+20-25%)
-- Nível 2: Melhorias especializadas (+15-20%)
-- Nível 5: Ultra melhoria (efeito dramático + trade-off)
```

## Testando Novas Melhorias

### Usando o Arquivo de Exemplo

Execute `examples/rune_upgrades_usage_example.lua` para testar:

```lua
-- Adicione sua nova runa ao teste
local novaUpgrades = RuneUpgradesData.GetUpgradesByRuneId("rune_nova_e")
for _, upgrade in ipairs(novaUpgrades) do
    print(upgrade.name, upgrade.description)
end
```

### Verificações Importantes

1. **Nomes únicos**: Todos os IDs devem ser únicos
2. **Atributos válidos**: Atributos devem existir na instância da runa
3. **Limites de uso**: Verificar se `max_uses` está correto
4. **Traduções**: Certificar-se de que todas as strings estão traduzidas

## Expansão do Sistema

### Novos Tipos de Modificadores

Para adicionar novos tipos de modificadores, edite `RuneUpgradesData.ApplyRuneUpgrade()`:

```lua
elseif type == "multiplicative" then
    -- Novo tipo de modificador multiplicativo
    runeInstance[attribute] = (runeInstance[attribute] or 0) * value
```

### Novas Condições de Desbloqueio

Para adicionar novas condições além de nível, edite `RuneUpgradesData.GetAvailableUpgrades()`:

```lua
-- Exemplo: Melhoria só disponível se outra foi aprendida
local prerequisiteRequirement = true
if upgrade.requires_upgrade then
    prerequisiteRequirement = usedUpgrades[upgrade.requires_upgrade] and 
                             usedUpgrades[upgrade.requires_upgrade] > 0
end
```

## Considerações de Performance

1. **Cache de Resultados**: Evite recalcular melhorias disponíveis constantemente
2. **Lazy Loading**: Carregue apenas as melhorias necessárias
3. **Validação**: Valide dados apenas durante desenvolvimento

## Debugging

### Logs Úteis

```lua
Logger.debug("rune_upgrades", "Melhoria aplicada: " .. upgrade.name)
Logger.debug("rune_upgrades", "Valor anterior: " .. tostring(oldValue))
Logger.debug("rune_upgrades", "Valor atual: " .. tostring(newValue))
```

### Verificações de Integridade

```lua
-- Verificar se a runa existe
assert(RuneUpgradesData.Upgrades[upgradeId], "Melhoria não encontrada")

-- Verificar se os atributos existem
assert(runeInstance[attribute], "Atributo não encontrado na instância")
``` 