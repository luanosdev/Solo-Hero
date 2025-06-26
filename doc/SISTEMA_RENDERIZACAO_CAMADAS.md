# Sistema de Renderização em Camadas - Player

## Visão Geral

O sistema de renderização do player foi completamente refatorado para usar um sistema de camadas, permitindo maior flexibilidade visual e personalização dos caçadores.

## Estrutura de Diretorios

```
assets/player/
├── body/           # Sprites do corpo (base)
│   ├── attack_melee.png
│   ├── attack_ranged.png
│   ├── attack_run_melee.png
│   ├── attack_run_ranged.png
│   ├── die.png
│   ├── idle.png
│   ├── idle2.png
│   ├── idle3.png
│   ├── idle4.png
│   ├── strafe_left.png
│   ├── strafe_right.png
│   ├── taunt.png
│   └── walk.png
├── bag/            # Equipamentos de costas (futuro)
├── belt/           # Cintos (futuro)
├── chest/          # Peitoral/armadura (futuro)
├── head/           # Capacetes/chapéus (futuro)
├── leg/            # Calças/perneiras (futuro)
├── shoe/           # Botas/sapatos (futuro)
└── weapons/        # Armas por tipo (futuro)
    ├── axe/
    ├── sword/
    ├── bow/
    ├── dagger/
    ├── staff/
    └── mace/
```

## Formato dos Sprite Sheets

Todos os sprite sheets seguem o padrão:
- **8 linhas** (direções)
- **15 colunas** (frames por direção)  
- **128x128 pixels** por frame
- **Primeira linha**: Este (E) - direita (0°)
- **Sequência**: Sentido horário de tela (E → SE → S → SW → W → NW → N → NE)

## Sistema de Cores de Pele

### Cores Disponíveis (colors.lua)
```lua
skinTones = {
    pale = { 0.96, 0.87, 0.82, 1.0 },        -- Tom muito claro
    light = { 0.94, 0.84, 0.76, 1.0 },       -- Tom claro
    medium_light = { 0.87, 0.72, 0.56, 1.0 }, -- Tom médio claro
    medium = { 0.80, 0.65, 0.48, 1.0 },      -- Tom médio (padrão)
    medium_dark = { 0.67, 0.49, 0.35, 1.0 }, -- Tom médio escuro
    dark = { 0.54, 0.36, 0.25, 1.0 },        -- Tom escuro
    very_dark = { 0.45, 0.28, 0.19, 1.0 },   -- Tom muito escuro
    olive = { 0.75, 0.68, 0.52, 1.0 },       -- Tom oliva
    warm = { 0.89, 0.75, 0.60, 1.0 },        -- Tom quente
    cool = { 0.85, 0.78, 0.72, 1.0 },        -- Tom frio
}
```

### Aplicação da Cor
- Os sprites do corpo são em **branco/cinza claro**
- A cor de pele é aplicada via multiplicação de cor no momento do desenho
- Cada caçador tem uma cor de pele única definida no recrutamento

## Arquitetura de Componentes

### SpritePlayer (src/animations/sprite_player.lua)
- **Gerencia**: Sistema de camadas, carregamento de recursos, renderização
- **Recursos**: Sprites organizados por tipo (body, equipment, weapons)
- **Quads**: Otimização de renderização com pre-cálculo de coordenadas
- **Animação**: Estados independentes por camada

### MovementController (src/controllers/movement_controller.lua)
- **Configura**: Aparência do player baseada nos dados do caçador
- **Aplica**: Cor de pele do caçador atual
- **Gerencia**: Estado visual durante o gameplay

### RecruitmentManager (src/managers/recruitment_manager.lua)
- **Gera**: Cor de pele aleatória para cada candidato
- **Atribui**: skinTone aos dados do candidato

### HunterManager (src/managers/hunter_manager.lua)
- **Persiste**: Cor de pele no save/load
- **Mantém**: Dados de aparência por caçador

## Ordem de Renderização das Camadas

1. **Corpo** (body) - Base com cor de pele aplicada
2. **Pernas** (leg) - Calças/perneiras
3. **Sapatos** (shoe) - Botas/calçados
4. **Cinto** (belt) - Cintos/faixas
5. **Peitoral** (chest) - Armaduras/roupas
6. **Mochila** (bag) - Equipamentos de costas
7. **Cabeça** (head) - Capacetes/chapéus
8. **Arma** (weapon) - Armas empunhadas

## Estados de Animação Suportados

- `idle` - Parado (base)
- `idle2`, `idle3`, `idle4` - Variações de idle (automáticas)
- `walk` - Caminhando normal (movimento alinhado com direção)
- `strafe_left` - Movimento lateral para esquerda (mantém direção do olhar)
- `strafe_right` - Movimento lateral para direita (mantém direção do olhar)
- `attack_melee` - Ataque corpo a corpo (parado)
- `attack_ranged` - Ataque à distância (parado)
- `attack_run_melee` - Ataque corpo a corpo (andando)
- `attack_run_ranged` - Ataque à distância (andando)
- `die` - Morte
- `taunt` - Provocação

### Sistema de Idle Aleatório

O sistema escolhe automaticamente uma animação idle aleatória toda vez que o personagem para:

- **Trigger**: Ativado quando o personagem para de se mover
- **Variações**: `idle`, `idle2`, `idle3`, `idle4`
- **Inteligente**: Não repete a mesma animação consecutivamente
- **Verificação**: Só usa sprites que existem no diretório
- **Persistente**: Mantém a mesma idle enquanto estiver parado

### Sistema de Strafe

O sistema detecta automaticamente quando o movimento é lateral em relação à direção que o personagem está olhando:

- **Threshold**: 30° de tolerância
- **Strafe Right**: Movimento 90° à direita da direção do olhar
- **Strafe Left**: Movimento 90° à esquerda da direção do olhar
- **Walk Normal**: Qualquer movimento fora do threshold de strafe

## Configuração de Aparência

```lua
local appearance = {
    skinTone = "medium",  -- Cor de pele
    equipment = {
        bag = nil,        -- ID do equipamento
        belt = nil,
        chest = nil,
        head = nil,
        leg = nil,
        shoe = nil
    },
    weapon = {
        type = "sword",   -- Tipo da arma
        sprite = nil      -- Sprite específico
    }
}
```

## API Principal

### SpritePlayer.setAppearance(config, appearance)
Define a aparência do jogador

### SpritePlayer.startAttackAnimation(config, attackType)
Inicia animação de ataque (melee/ranged)

### SpritePlayer.stopAttackAnimation(config)
Para animação de ataque

### SpritePlayer.draw(config)
Renderiza todas as camadas em ordem

### SpritePlayer.forceIdleChange(config)
Força uma nova escolha de idle na próxima vez que o personagem parar

## Exemplo de Uso - Sistema de Idle

```lua
-- O sistema funciona automaticamente:
-- 1. Personagem se move (WASD)
-- 2. Personagem para -> escolhe idle aleatório (idle2, idle3, idle4)
-- 3. Mantém essa idle enquanto parado
-- 4. Se mover novamente e parar -> nova idle aleatória

-- Forçar nova escolha na próxima parada
SpritePlayer.forceIdleChange(playerConfig)

-- Sistema automático durante update
SpritePlayer.update(playerConfig, dt, targetPosition)
```

## Expansões Futuras

### Equipamentos
- Implementar carregamento de sprites por slot
- Sistema de variações por equipamento
- Cores/tingimento de equipamentos

### Armas
- Sprites específicos por tipo de arma
- Animações diferenciadas por arma
- Efeitos visuais por arma

### Customização Avançada
- Editor de aparência
- Unlocks visuais
- Skins especiais por rank/conquista

## Compatibilidade

O sistema mantém compatibilidade com:
- ✅ Sistema de stats existente  
- ✅ Sistema de equipamentos
- ✅ Sistema de animações de ataque
- ✅ Save/load de caçadores
- ✅ Renderização otimizada

## Status de Implementação

- ✅ **Estrutura base** - Sistema de camadas funcional
- ✅ **Cores de pele** - Geração e aplicação automática
- ✅ **Persistência** - Save/load com aparência
- ✅ **Integração** - Sistema integrado ao gameplay
- 🔄 **Equipamentos** - Estrutura preparada (aguardando sprites)
- 🔄 **Armas** - Estrutura preparada (aguardando sprites)
- ❌ **Editor visual** - Não implementado (futuro) 