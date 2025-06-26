-------------------------------------------------------------------------
-- Estado do jogador durante o gameplay.
-- Gerencia estado atual, estatísticas base e progressão do jogador.
-------------------------------------------------------------------------

local Constants = require("src.config.constants")

---@alias StatKey string Chave de stat para modificadores
---@alias ItemSlotId string ID de slot de equipamento
---@alias ArchetypeId string ID de arquétipo

---@class LevelBonus Bônus percentuais ganhos por level up
---@field health number Bônus de vida por nível (%)
---@field damageMultiplier number Bônus de multiplicador de dano por nível (%)
---@field defense number Bônus de defesa por nível (%)
---@field moveSpeed number Bônus de velocidade de movimento por nível (%)
---@field attackSpeed number Bônus de velocidade de ataque por nível (%)
---@field critChance number Bônus de chance crítica por nível (%)
---@field critDamage number Bônus de dano crítico por nível (%)
---@field healthRegen number Bônus de regeneração de vida por nível (%)
---@field multiAttackChance number Bônus de chance de ataque múltiplo por nível (%)
---@field strength number Bônus de força por nível (%)
---@field expBonus number Bônus de experiência por nível (%)
---@field healingBonus number Bônus de cura recebida por nível (%)
---@field pickupRadius number Bônus de raio de coleta por nível (%)
---@field healthRegenDelay number Redução do atraso de regeneração por nível (%)
---@field range number Bônus de alcance por nível (%)
---@field luck number Bônus de sorte por nível (%)
---@field attackArea number Bônus de área de ataque por nível (%)
---@field healthPerTick number Bônus de vida por tick de regeneração por nível (%)
---@field cooldownReduction number Bônus de redução de cooldown por nível (%)
---@field healthRegenCooldown number Redução do cooldown de regeneração por nível (%)
---@field dashCharges number Cargas de dash adicionais por nível (fixo)
---@field dashCooldown number Redução do cooldown de dash por nível (%)
---@field dashDistance number Bônus de distância de dash por nível (%)
---@field dashDuration number Bônus de duração de dash por nível (%)
---@field potionFlasks number Frascos de poção adicionais por nível (fixo)
---@field potionHealAmount number Bônus de cura por poção por nível (%)
---@field potionFillRate number Bônus de velocidade de preenchimento por nível (%)

---@class FixedBonus Bônus fixos aplicados de arquétipos ou outras fontes
---@field health number Bônus fixo de vida (aditivo)
---@field damageMultiplier number Bônus fixo de multiplicador de dano (percentual, ex: 0.1 = +10%)
---@field defense number Bônus fixo de defesa (aditivo)
---@field moveSpeed number Bônus fixo de velocidade de movimento (aditivo)
---@field attackSpeed number Bônus fixo de velocidade de ataque (percentual)
---@field critChance number Bônus fixo de chance crítica (percentual)
---@field critDamage number Bônus fixo de dano crítico (percentual)
---@field healthRegen number Bônus fixo de regeneração de vida (aditivo HP/s)
---@field multiAttackChance number Bônus fixo de chance de ataque múltiplo (percentual)
---@field strength number Bônus fixo de força (aditivo)
---@field expBonus number Bônus fixo de experiência (percentual)
---@field healingBonus number Bônus fixo de cura recebida (percentual)
---@field pickupRadius number Bônus fixo de raio de coleta (aditivo, pixels)
---@field healthRegenDelay number Bônus fixo de atraso de regeneração (aditivo, segundos)
---@field range number Bônus fixo de alcance (percentual)
---@field luck number Bônus fixo de sorte (percentual)
---@field attackArea number Bônus fixo de área de ataque (percentual)
---@field healthPerTick number Bônus fixo de vida por tick (aditivo HP)
---@field cooldownReduction number Bônus fixo de redução de cooldown (percentual)
---@field healthRegenCooldown number Bônus fixo de cooldown de regeneração (aditivo, segundos)
---@field dashCharges number Cargas de dash adicionais (aditivo)
---@field dashCooldown number Redução de cooldown de dash (aditivo, segundos)
---@field dashDistance number Bônus de distância de dash (aditivo, pixels)
---@field dashDuration number Bônus de duração de dash (aditivo, segundos)
---@field potionFlasks number Frascos de poção adicionais (aditivo)
---@field potionHealAmount number Bônus de cura por poção (aditivo)
---@field potionFillRate number Bônus de velocidade de preenchimento (percentual)

---@class LearnedLevelUpBonuses Bônus de level up aprendidos pelo jogador
---@field [string] number Mapeamento de ID do bônus para nível aprendido

---@class EquippedItem Informações de um item equipado
---@field itemBaseId string ID base do item
---@field [string] any Outras propriedades específicas do item

---@class EquippedItems Itens equipados por slot
---@field [ItemSlotId] EquippedItem Itens equipados mapeados por ID do slot

---@class ArchetypeInfo Informações de um arquétipo ativo
---@field id ArchetypeId ID do arquétipo
---@field [string] any Outras informações do arquétipo

---@class StatusModifier Modificador de status temporário
---@field [string] any Propriedades do modificador

---@class PlayerState Estado principal do jogador durante o gameplay
---@field currentHealth number Vida atual do jogador
---@field maxHealth number Vida máxima base (sem modificadores)
---@field isAlive boolean Se o jogador está vivo
---@field level number Nível atual do jogador
---@field experience number Experiência atual acumulada
---@field experienceToNextLevel number Experiência necessária para o próximo nível
---@field experienceMultiplier number Multiplicador base de experiência
---@field kills number Número de inimigos eliminados
---@field gold number Quantidade de ouro possuída
---@field health number Vida base máxima
---@field damage number Dano base do jogador (não da arma)
---@field defense number Defesa base
---@field moveSpeed number Velocidade de movimento base
---@field attackSpeed number Multiplicador base de velocidade de ataque
---@field critChance number Chance crítica base (fração, 0.1 = 10%)
---@field critDamage number Multiplicador de dano crítico base (1.5 = +50%)
---@field healthRegen number Regeneração de vida base (HP/s)
---@field multiAttackChance number Chance de ataque múltiplo base (fração)
---@field runeSlots number Quantidade de slots de runa disponíveis
---@field strength number Força base do jogador
---@field expBonus number Multiplicador de experiência base
---@field healingBonus number Multiplicador de cura recebida base
---@field pickupRadius number Raio de coleta base (pixels)
---@field healthRegenDelay number Atraso para iniciar regeneração após dano (segundos)
---@field range number Bônus percentual base de alcance
---@field luck number Multiplicador de sorte base
---@field attackArea number Bônus percentual base de área de ataque
---@field healthPerTick number Vida regenerada por tick base
---@field cooldownReduction number Multiplicador de redução de cooldown base
---@field healthRegenCooldown number Tempo entre ticks de regeneração base
---@field dashCharges number Quantidade base de cargas de dash
---@field dashCooldown number Tempo base para recuperar uma carga de dash (segundos)
---@field dashDistance number Distância base do dash (pixels)
---@field dashDuration number Duração base do dash (segundos)
---@field potionFlasks number Quantidade base de frascos de poção
---@field potionHealAmount number Vida base recuperada por frasco
---@field potionFillRate number Multiplicador base de velocidade de preenchimento
---@field levelBonus LevelBonus Bônus percentuais ganhos por level up
---@field fixedBonus FixedBonus Bônus fixos de arquétipos e outras fontes
---@field statusModifiers StatusModifier[] Modificadores de status temporários
---@field _levelBonus table Bônus de nível internos (uso interno)
---@field _fixedBonus table Bônus fixos internos (uso interno)
---@field _archetypeBonus table Bônus de arquétipos consolidados (uso interno)
---@field learnedLevelUpBonuses LearnedLevelUpBonuses Bônus de level up aprendidos
---@field equippedItems EquippedItems Itens atualmente equipados
---@field archetypeIds ArchetypeInfo[] Lista de arquétipos ativos
local PlayerState = {
    currentHealth = 0,
    maxHealth = 0,
    isAlive = true,

    -- Atributos de Jogo
    level = 1,
    experience = 0,
    experienceToNextLevel = Constants.INITIAL_XP_TO_LEVEL,
    experienceMultiplier = 1.10,
    kills = 0,
    gold = 0,

    -- Atributos base (Nomes padronizados com initialStats)
    health = 100,
    damage = 0,            -- Dano base do JOGADOR (não da arma), pode ser usado para habilidades não-arma? Manter por ora.
    defense = 10,
    moveSpeed = 40,        -- Renomeado de 'speed'
    attackSpeed = 1.0,     -- Multiplicador base de velocidade de ataque
    critChance = 0.1,      -- Renomeado de 'criticalChance', valor como fração (0.1 = 10%)
    critDamage = 1.5,      -- Renomeado de 'criticalMultiplier', valor como multiplicador (1.5 = +50%)
    healthRegen = 0.5,     -- HP/s base
    multiAttackChance = 0, -- Como fração (0 = 0%)
    runeSlots = 1,
    strength = 1,          -- NOVO ATRIBUTO: Força base

    -- Atributos Adicionados (com base nos logs de initialStats, com padrões)
    expBonus = 1.0,            -- Multiplicador
    healingBonus = 1.0,        -- Multiplicador
    pickupRadius = 100,        -- Pixels
    healthRegenDelay = 8.0,    -- Segundos
    range = 0,                 -- Bônus percentual base de alcance (0 = +0%)
    luck = 1.0,                -- Multiplicador? (Padrão 1)
    attackArea = 0,            -- Bônus percentual base de área (0 = +0%)
    healthPerTick = 1.0,       -- HP por tick de regeneração (Padrão 1)
    cooldownReduction = 1.0,   -- Multiplicador (1.0 = sem redução)
    healthRegenCooldown = 1.0, -- Segundos entre ticks de regen? (Padrão 1)

    -- Atributos de Dash
    dashCharges = 0,  -- Quantidade de cargas de dash
    dashCooldown = 0, -- Tempo em segundos para recuperar uma carga
    dashDistance = 0, -- Distância em pixels que o dash percorre
    dashDuration = 0, -- Duração do dash em segundos

    -- Atributos do Sistema de Poções
    potionFlasks = 1,      -- Quantidade de frascos de poção disponíveis
    potionHealAmount = 50, -- Quantidade de HP restaurada por poção
    potionFillRate = 1.0,  -- Multiplicador da velocidade de preenchimento dos frascos

    -- Bônus por nível (em porcentagem ou valor base, dependendo do stat)
    levelBonus = {
        health = 0,              -- %
        damageMultiplier = 0,    -- %
        defense = 0,             -- %
        moveSpeed = 0,           -- %
        attackSpeed = 0,         -- %
        critChance = 0,          -- %
        critDamage = 0,          -- % (Multiplicador adicional, ex: 20 significa +20% no multiplicador total)
        healthRegen = 0,         -- %
        multiAttackChance = 0,   -- %
        strength = 0,            -- Bônus percentual de Força por nível
        expBonus = 0,            -- %
        healingBonus = 0,        -- %
        pickupRadius = 0,        -- %
        healthRegenDelay = 0,    -- % (Redução?)
        range = 0,               -- % (Aditivo ao bônus percentual total)
        luck = 0,                -- %
        attackArea = 0,          -- % (Aditivo ao bônus percentual total)
        healthPerTick = 0,       -- %
        cooldownReduction = 0,   -- %
        healthRegenCooldown = 0, -- % (Redução?)
        -- Dash
        dashCharges = 0,         -- Fixo
        dashCooldown = 0,        -- %
        dashDistance = 0,        -- %
        dashDuration = 0,        -- %
        -- Poções
        potionFlasks = 0,        -- Fixo
        potionHealAmount = 0,    -- %
        potionFillRate = 0       -- %
    },

    -- Bônus fixos (aditivos ou percentuais fixos, dependendo do stat)
    fixedBonus = {
        health = 0,              -- Aditivo
        damageMultiplier = 0,    -- Percentual fixo (ex: 0.1 = +10%) (RENOMEADO)
        defense = 0,             -- Aditivo
        moveSpeed = 0,           -- Aditivo
        attackSpeed = 0,         -- Percentual fixo (ex: 0.2 = +20%)
        critChance = 0,          -- Percentual fixo (ex: 0.05 = +5%)
        critDamage = 0,          -- Percentual fixo (ex: 0.25 = +25% no multiplicador total)
        healthRegen = 0,         -- Aditivo (HP/s)
        multiAttackChance = 0,   -- Percentual fixo (ex: 0.1 = +10%)
        strength = 0,            -- NOVO: Bônus fixo de Força
        -- Adicionar outros bônus fixos se aplicável
        expBonus = 0,            -- Percentual fixo
        healingBonus = 0,        -- Percentual fixo
        pickupRadius = 0,        -- Aditivo (Pixels)
        healthRegenDelay = 0,    -- Aditivo (Segundos - redução?)
        range = 0,               -- Percentual fixo (ex: 0.2 = +20%)
        luck = 0,                -- Percentual fixo? Aditivo? (Assumindo percentual fixo)
        attackArea = 0,          -- Percentual fixo (ex: 0.15 = +15%)
        healthPerTick = 0,       -- Aditivo (HP por tick)
        cooldownReduction = 0,   -- Percentual fixo
        healthRegenCooldown = 0, -- Aditivo (Segundos - redução?)
        -- Dash
        dashCharges = 0,         -- Aditivo
        dashCooldown = 0,        -- Aditivo (para redução de tempo)
        dashDistance = 0,        -- Aditivo
        dashDuration = 0,        -- Aditivo
        -- Poções
        potionFlasks = 0,        -- Aditivo
        potionHealAmount = 0,    -- Aditivo
        potionFillRate = 0       -- Percentual fixo (ex: 0.25 = +25%)
    },

    -- Modificadores de status (ex: buffs/debuffs temporários)
    statusModifiers = {}
}

PlayerState.__index = PlayerState

--- Inicializa o estado do jogador com estatísticas base
---@param baseStats table Tabela contendo as estatísticas base do hunter
function PlayerState:init(baseStats)
    -- Inicializa atributos base usando baseStats ou os padrões da classe
    self.health = baseStats.health or PlayerState.health
    self.defense = baseStats.defense or PlayerState.defense
    self.moveSpeed = baseStats.moveSpeed or PlayerState.moveSpeed
    self.critChance = baseStats.critChance or PlayerState.critChance
    self.critDamage = baseStats.critDamage or PlayerState.critDamage
    self.healthPerTick = baseStats.healthPerTick or PlayerState.healthPerTick
    self.healthRegenDelay = baseStats.healthRegenDelay or PlayerState.healthRegenDelay
    self.multiAttackChance = baseStats.multiAttackChance or PlayerState.multiAttackChance
    self.attackSpeed = baseStats.attackSpeed or PlayerState.attackSpeed
    self.expBonus = baseStats.expBonus or PlayerState.expBonus
    self.cooldownReduction = baseStats.cooldownReduction or PlayerState.cooldownReduction
    self.range = baseStats.range or PlayerState.range
    self.attackArea = baseStats.attackArea or PlayerState.attackArea       -- Adicionado attackArea
    self.healingBonus = baseStats.healingBonus or PlayerState.healingBonus
    self.pickupRadius = baseStats.pickupRadius or PlayerState.pickupRadius -- Adicionado pickupRadius
    self.runeSlots = baseStats.runeSlots or PlayerState.runeSlots
    self.luck = baseStats.luck or PlayerState.luck
    self.strength = baseStats.strength or PlayerState.strength -- NOVO: Inicializa strength

    -- NOVO: Inicializa Atributos de Dash
    self.dashCharges = baseStats.dashCharges or PlayerState.dashCharges
    self.dashCooldown = baseStats.dashCooldown or PlayerState.dashCooldown
    self.dashDistance = baseStats.dashDistance or PlayerState.dashDistance
    self.dashDuration = baseStats.dashDuration or PlayerState.dashDuration

    -- Inicializa Atributos do Sistema de Poções
    self.potionFlasks = baseStats.potionFlasks or PlayerState.potionFlasks
    self.potionHealAmount = baseStats.potionHealAmount or PlayerState.potionHealAmount
    self.potionFillRate = baseStats.potionFillRate or PlayerState.potionFillRate

    -- <<< CORREÇÃO: Armazena equippedItems e archetypeIds de baseStats >>>
    self.equippedItems = baseStats.equippedItems or {}
    self.archetypeIds = baseStats.archetypeIds or {}

    -- Inicializa bônus (serão preenchidos por arquétipos e level ups)
    self._levelBonus = {}           -- Bônus percentuais de level up (ex: { health = 5 } para +5%)
    self._fixedBonus = {}           -- Bônus fixos de level up ou outras fontes (ex: { health = 10 })
    self._archetypeBonus = {}       -- Consolidado dos arquétipos (pode ser usado internamente se necessário)
    self.learnedLevelUpBonuses = {} -- <<< GARANTE INICIALIZAÇÃO CORRETA >>>

    -- Stats de Gameplay
    self.level = baseStats.level or 1
    self.experience = 0
    self.experienceToNextLevel = Constants.INITIAL_XP_TO_LEVEL
    self.kills = 0
    self.gold = 0

    -- Inicializa vida atual e máxima
    self.maxHealth = self.health
    self.currentHealth = self.maxHealth
    self.isAlive = true

    -- Log final de verificação
    print(string.format("  [DEBUG] PlayerState:new - Final health: %.1f/%.1f", self.currentHealth, self.maxHealth))
end

--- Construtor: Cria e inicializa uma nova instância de PlayerState.
---@param initialStats table Tabela contendo os atributos base (geralmente de HunterManager)
---@return PlayerState A nova instância de PlayerState
function PlayerState:new(initialStats)
    local state = setmetatable({}, PlayerState)

    -- 1. Copia valores padrão da CLASSE (incluindo tabelas de bônus vazias)
    for key, value in pairs(PlayerState) do
        if type(value) ~= 'function' and key ~= '__index' then
            if type(value) == 'table' then
                state[key] = {} -- Cria CÓPIA RASA
                for k, v in pairs(value) do state[key][k] = v end
            else
                state[key] = value
            end
        end
    end

    -- Garante que tabelas de bônus comecem vazias
    state.learnedLevelUpBonuses = {}
    state._archetypeBonus = {} -- Limpa também (se usado)
    state.equippedItems = {}   -- Limpa também
    state.archetypeIds = {}    -- Limpa também

    -- 2. Sobrescreve com initialStats (que contém stats base JÁ CALCULADOS com arquétipos iniciais)
    if initialStats and next(initialStats) then
        for key, value in pairs(initialStats) do
            -- Apenas atualiza atributos base e listas conhecidas
            if state[key] ~= nil and type(state[key]) == type(value) then
                state[key] = value
                -- Não copiar tabelas internas como _levelBonus, _fixedBonus de initialStats, pois elas são do Manager
                -- Copia apenas IDs de arquétipos e itens equipados (se vierem)
            elseif key == "archetypeIds" then
                state.archetypeIds = value
            elseif key == "equippedItems" then
                state.equippedItems = value -- Deveria conter IDs de instância
            end
        end
    end

    -- 3. Define estado inicial de gameplay
    state.level = 1 -- Começa sempre no nível 1 no gameplay
    state.experience = 0
    state.experienceToNextLevel = Constants.INITIAL_XP_TO_LEVEL
    state.kills = 0
    state.gold = 0
    state.isAlive = true
    -- Calcula a vida inicial baseada nos stats que vieram (que já incluem bônus base + arquétipo)
    state.maxHealth = state.health -- 'maxHealth' agora é apenas o BASE (+ arq inicial)
    state.currentHealth = state.health
    state.statusModifiers = {}

    print(string.format("  [PlayerState:new] Estado inicializado. HP Base(com arq): %.1f", state.health))

    return state
end

--- Aplica dano ao jogador
---@param damage number Quantidade de dano bruto a ser aplicado
---@param finalDamageReduction number Redução de dano final calculada (0-1)
---@return number O dano real sofrido após a redução
function PlayerState:takeDamage(damage, finalDamageReduction)
    if not self.isAlive then return 0 end

    -- Calcula o dano real usando a redução fornecida
    local actualDamage = math.max(1, math.floor(damage * (1 - finalDamageReduction)))

    self.currentHealth = math.max(0, self.currentHealth - actualDamage)

    if self.currentHealth <= 0 then
        self.isAlive = false
    end

    return actualDamage
end

--- Restaura vida do jogador
---@param amount number Quantidade de vida a restaurar (antes dos bônus de cura)
---@param finalMaxHealth number Vida máxima calculada final do jogador
---@param finalHealingBonusMultiplier number Multiplicador final de bônus de cura
---@return number Quantidade de vida efetivamente restaurada
function PlayerState:heal(amount, finalMaxHealth, finalHealingBonusMultiplier)
    if not self.isAlive then return 0 end

    -- Aplica bônus de cura
    local effectiveAmount = amount * finalHealingBonusMultiplier
    local oldHealth = self.currentHealth
    -- Limita a cura pela vida máxima final
    self.currentHealth = math.floor(math.min(self.currentHealth + effectiveAmount, finalMaxHealth))

    return math.floor(self.currentHealth - oldHealth)
end

--- Adiciona bônus a um atributo específico
---@param attribute StatKey Nome do atributo para adicionar o bônus
---@param percentage number Porcentagem de bônus para level bonus
---@param fixed number Valor fixo para fixed bonus
function PlayerState:addAttributeBonus(attribute, percentage, fixed)
    percentage = percentage or 0
    fixed = fixed or 0

    local bonusApplied = false

    -- Verifica se é bônus de Nível (geralmente percentual)
    if self.levelBonus[attribute] ~= nil then
        self.levelBonus[attribute] = self.levelBonus[attribute] + percentage
        bonusApplied = true
    end

    -- Verifica se é bônus Fixo
    if self.fixedBonus[attribute] ~= nil then
        self.fixedBonus[attribute] = self.fixedBonus[attribute] + fixed
        bonusApplied = true
    end

    if not bonusApplied then
        error(string.format("[PlayerState] ERRO: Atributo '%s' não encontrado para adicionar bônus.", attribute))
    end
end

--- Adiciona experiência ao jogador e calcula o ganho de níveis com base na nova fórmula.
---
--- A fórmula usada para determinar a experiência necessária para o próximo nível é:
--- `experienceToNextLevel = floor(30 * level ^ 1.5)`
---
--- Esse escalonamento gera uma progressão suave, onde cada nível exige mais XP que o anterior,
--- mas de forma controlada (não exponencial demais), ideal para runs curtas e médias como em roguelikes.
---
--- O sistema permite múltiplos níveis ganhos de uma vez, caso a quantidade de XP recebida seja alta.
---
--- @param amount number A quantidade de experiência bruta recebida.
--- @param finalExpBonus number Um multiplicador aplicado sobre a experiência (ex: 1.2 para +20% XP).
--- @return number levelsGained A quantidade total de níveis ganhos com essa adição de XP.
function PlayerState:addExperience(amount, finalExpBonus)
    if not self.isAlive then return 0 end

    local effectiveAmount = amount * finalExpBonus
    self.experience = self.experience + effectiveAmount

    local levelsGained = 0

    while self.experience >= self.experienceToNextLevel do
        self.level = self.level + 1
        local previousRequired = self.experienceToNextLevel
        self.experience = self.experience - previousRequired

        self.experienceToNextLevel = math.floor(30 * self.level ^ 1.5)

        levelsGained = levelsGained + 1
    end

    return levelsGained
end

--- Retorna todos os bônus de level up aprendidos (ID do bônus -> nível aprendido)
---@return LearnedLevelUpBonuses
function PlayerState:getLearnedLevelUpBonuses()
    return self.learnedLevelUpBonuses or {}
end

return PlayerState
