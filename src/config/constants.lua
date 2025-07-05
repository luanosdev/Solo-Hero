--- @class Constants
local Constants = {}

--[[
    SISTEMA DE MEDIDAS DO JOGO
    =========================

    Baseado no conceito do Halls of Torment:
    - 1 metro = 18 pixels
    - moveSpeed é definido em metros por segundo (m/s)
    - pickupRadius é definido em metros
    - dashDistance é definido em metros

    Conversões automáticas:
    - Use Constants.metersToPixels(meters) para converter metros → pixels
    - Use Constants.pixelsToMeters(pixels) para converter pixels → metros
    - Use Constants.moveSpeedToPixels(m/s) para converter velocidade

    Exemplos:
    - moveSpeed = 1.4 m/s = 25.2 pixels/s
    - pickupRadius = 5.5m = 99 pixels
    - dashDistance = 5.5m = 99 pixels
--]]

-- Sistema de Medidas do Jogo
-- Baseado no conceito do Halls of Torment: 1 metro = 18 pixels
Constants.METER_TO_PIXELS = 18

--- IDs constantes para as abas do Lobby.
Constants.TabIds = {
    SHOPPING = 1,
    CRAFTING = 2,
    EQUIPMENT = 3,
    PORTALS = 4,
    AGENCY = 5,
    SETTINGS = 6,
    QUIT = 7,
}

--- IDs constantes para os slots de equipamento.
Constants.SLOT_IDS = {
    WEAPON = "weapon",
    HELMET = "helmet",
    CHEST = "chest",
    GLOVES = "gloves",
    BOOTS = "boots",
    LEGS = "legs",
    RUNE = "rune_"
    -- Adicionar outros slots conforme necessário (amuletos, anéis etc.)
}

--- Ordem de exibição para os slots de equipamento na UI.
Constants.EQUIPMENT_SLOTS_ORDER = {
    Constants.SLOT_IDS.WEAPON,
    Constants.SLOT_IDS.HELMET,
    Constants.SLOT_IDS.CHEST,
    Constants.SLOT_IDS.LEGS,
    Constants.SLOT_IDS.GLOVES,
    Constants.SLOT_IDS.BOOTS,
    -- Adicionar outros slots na ordem desejada, ex: anéis, amuletos
}

--- Default Base Stats for New Hunters (Before Archetypes)
Constants.HUNTER_DEFAULT_STATS = {
    maxHealth = 300,
    attackSpeed = 1.0,         -- Attacks per second
    moveSpeed = 2.0,           -- Metros por segundo (m/s) - convertido automaticamente para pixels
    critChance = 0.10,         -- 10%
    critDamage = 1.5,          -- 150% Multiplier
    multiAttackChance = 0.1,   -- 20%
    expBonus = 1.0,            -- 100%
    defense = 10,
    healthRegenCooldown = 1.0, -- Seconds
    healthPerTick = 1,
    healthRegenDelay = 8.0,    -- Seconds after taking damage
    cooldownReduction = 1.0,   -- Multiplier (1.0 = no reduction)
    range = 1.0,               -- Multiplier (1.0 = base weapon/skill)
    attackArea = 1.0,          -- Multiplier (1.0 = base weapon/skill)
    pickupRadius = 3,          -- Metros - convertido automaticamente para pixels
    healingBonus = 1.0,        -- Multiplier (1.0 = 100% healing received)
    runeSlots = 3,             -- Number of rune slots
    luck = 1.0,                -- Multiplier (1.0 = 100% luck)
    strength = 1.0,            -- Multiplier (1.0 = 100% strength)
    -- Atributos de Dash
    dashCharges = 1,           -- Quantidade de cargas de dash
    dashCooldown = 8.0,        -- Tempo em segundos para recuperar uma carga
    dashDistance = 5.5,        -- Distância em metros que o dash percorre
    dashDuration = 0.1,        -- Duração do dash em segundos
    -- Atributos de Poções
    potionFlasks = 1,          -- Quantidade de frascos de poção
    potionHealAmount = 50,     -- Vida recuperada por frasco
    potionFillRate = 1.0,      -- Multiplicador da velocidade de preenchimento (1.0 = normal)
}

Constants.ENEMY_SPRITE_SIZES = {
    SMALL = 64,
    MEDIUM = 128,
    LARGE = 192,
}

Constants.DEFENSE_DAMAGE_REDUCTION_K = 52
Constants.MAX_DAMAGE_REDUCTION = 0.8

Constants.CHUNK_SIZE = 10           -- 10x10 tiles por chunk
Constants.VISIBLE_CHUNKS_RADIUS = 2 -- Raio de 2 chunks ao redor do jogador (total de 5x5 chunks visíveis)

-- <<< ADICIONADO: Dimensões Padrão da Grade >>>
Constants.GRID_ROWS = 4
Constants.GRID_COLS = 4
-- <<< FIM ADIÇÃO >>>

--- Tamanho lógico do tile (em pixels) para o grid do mapa isométrico
--- Este valor define o "tamanho do mundo" de cada tile, não a resolução da imagem do asset
--- Exemplo: 1 tile = 1 metro no mundo do jogo
Constants.TILE_SIZE = 64

--- Tamanho lógico do tile isométrico (em pixels)
--- Use proporção clássica: largura = 2x altura
Constants.TILE_WIDTH = 128
Constants.TILE_HEIGHT = 64

Constants.PLAYER_DAMAGE_COOLDOWN = 0.5
Constants.INITIAL_XP_TO_LEVEL = 30

Constants.KNOCKBACK_RESISTANCE = {
    NONE   = 0,        -- Inimigos muito leves (ratos, zumbis fracos)
    LOW    = 1,        -- Humanoides, zumbis normais
    MEDIUM = 5,        -- Guerreiros, elites
    HIGH   = 9,        -- Golems, tanques
    IMMUNE = math.huge -- Bosses, inimigos com resistência total
}

--- Valor que representa a "capacidade" do ataque de iniciar um knockback
Constants.KNOCKBACK_POWER = {
    NONE      = 0,  -- Não empurra (ex: magias contínuas, dano ao longo do tempo)
    VERY_LOW  = 1,  -- Flechas, ataques leves
    LOW       = 3,  -- Adagas, ataques rápidos
    MEDIUM    = 6,  -- Espadas médias, lança-chamas
    HIGH      = 10, -- Armas pesadas, martelo, explosões
    VERY_HIGH = 15, -- Ultimates, armas divinas, ataques especiais
}

Constants.KNOCKBACK_FORCE = {
    NONE         = 0,   -- Magias de dano contínuo, projéteis fracos
    CHAIN_LASER  = 0,   -- Lança-chamas com alto knockback
    FLAMETHROWER = 0,   -- Força moderada em função da pressão contínua
    BULLET       = 5,   -- Balas empurram levemente (útil com força alta)
    DUAL_DAGGERS = 10,  -- Golpes rápidos, mas pouco impacto
    BOW          = 25,  -- Flechas empurram levemente (útil com força alta)
    SWORDS       = 50,  -- Golpes médios (espadas comuns)
    HAMMER       = 100, -- Armas pesadas com alto knockback
}

-- Duração padrão do knockback em segundos
Constants.KNOCKBACK_DURATION = 0.5

Constants.HIT_COST = {
    BULLET = 0.4,
    ARROW = 0.8,
    FIRE_PARTICLE = 0.6,
}

-- Constantes do Sistema de Poções
Constants.POTION_SYSTEM = {
    -- Tempo base em segundos para encher um frasco completamente
    BASE_FILL_TIME = 60.0,
    -- Progresso por inimigo derrotado (0.5% por kill)
    ENEMY_KILL_PROGRESS = 0.005,
    -- Progresso por segundo baseado em tempo (2% por segundo)
    TIME_FILL_RATE = 0.02,
    -- Taxa mínima de preenchimento (não pode ser menor que 50%)
    MIN_FILL_RATE = 0.5,
    -- Taxa máxima de preenchimento (não pode ser maior que 300%)
    MAX_FILL_RATE = 3.0,
}

-- Constantes do Sistema de Spawn Otimizado
Constants.SPAWN_OPTIMIZATION = {
    -- Número máximo de inimigos spawnados por frame para evitar stuttering
    MAX_SPAWNS_PER_FRAME = 5,
    -- Limite mínimo permitido para maxSpawnsPerFrame
    MIN_SPAWNS_PER_FRAME = 1,
    -- Limite máximo permitido para maxSpawnsPerFrame
    MAX_SPAWNS_PER_FRAME_LIMIT = 50,
}

-- Funções utilitárias para conversão de unidades
--- Converte metros para pixels
--- @param meters number Valor em metros
--- @return number pixels Valor equivalente em pixels
function Constants.metersToPixels(meters)
    return meters * Constants.METER_TO_PIXELS
end

--- Converte pixels para metros
--- @param pixels number Valor em pixels
--- @return number meters Valor equivalente em metros
function Constants.pixelsToMeters(pixels)
    return pixels / Constants.METER_TO_PIXELS
end

--- Converte velocidade de m/s para pixels/s
--- @param metersPerSecond number Velocidade em metros por segundo
--- @return number pixelsPerSecond Velocidade equivalente em pixels por segundo
function Constants.moveSpeedToPixels(metersPerSecond)
    return metersPerSecond * Constants.METER_TO_PIXELS
end

return Constants
