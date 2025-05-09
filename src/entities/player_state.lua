--[[
    Player State
    Manages player's current state and status
]]

local Constants = require("src.config.constants") -- Usado para valores padrão se necessário

---@class PlayerState
local PlayerState = {
    currentHealth = 0,
    maxHealth = 0,
    isAlive = true,

    -- Atributos de Jogo
    level = 1,
    experience = 0,
    experienceToNextLevel = 100,
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

    -- Bônus por nível (em porcentagem ou valor base, dependendo do stat)
    levelBonus = {
        health = 0,             -- %
        damageMultiplier = 0,   -- % (RENOMEADO)
        defense = 0,            -- %
        moveSpeed = 0,          -- %
        attackSpeed = 0,        -- %
        critChance = 0,         -- %
        critDamage = 0,         -- % (Multiplicador adicional, ex: 20 significa +20% no multiplicador total)
        healthRegen = 0,        -- %
        multiAttackChance = 0,  -- %
        -- Adicionar outros bônus de level se aplicável (luck, area, etc.)? Por enquanto não.
        expBonus = 0,           -- %
        healingBonus = 0,       -- %
        pickupRadius = 0,       -- %
        healthRegenDelay = 0,   -- % (Redução?)
        range = 0,              -- % (Aditivo ao bônus percentual total)
        luck = 0,               -- %
        attackArea = 0,         -- % (Aditivo ao bônus percentual total)
        healthPerTick = 0,      -- %
        cooldownReduction = 0,  -- %
        healthRegenCooldown = 0 -- % (Redução?)
    },

    -- Bônus fixos (aditivos ou percentuais fixos, dependendo do stat)
    fixedBonus = {
        health = 0,             -- Aditivo
        damageMultiplier = 0,   -- Percentual fixo (ex: 0.1 = +10%) (RENOMEADO)
        defense = 0,            -- Aditivo
        moveSpeed = 0,          -- Aditivo
        attackSpeed = 0,        -- Percentual fixo (ex: 0.2 = +20%)
        critChance = 0,         -- Percentual fixo (ex: 0.05 = +5%)
        critDamage = 0,         -- Percentual fixo (ex: 0.25 = +25% no multiplicador total)
        healthRegen = 0,        -- Aditivo (HP/s)
        multiAttackChance = 0,  -- Percentual fixo (ex: 0.1 = +10%)
        -- Adicionar outros bônus fixos se aplicável
        expBonus = 0,           -- Percentual fixo
        healingBonus = 0,       -- Percentual fixo
        pickupRadius = 0,       -- Aditivo (Pixels)
        healthRegenDelay = 0,   -- Aditivo (Segundos - redução?)
        range = 0,              -- Percentual fixo (ex: 0.2 = +20%)
        luck = 0,               -- Percentual fixo? Aditivo? (Assumindo percentual fixo)
        attackArea = 0,         -- Percentual fixo (ex: 0.15 = +15%)
        healthPerTick = 0,      -- Aditivo (HP por tick)
        cooldownReduction = 0,  -- Percentual fixo
        healthRegenCooldown = 0 -- Aditivo (Segundos - redução?)
    },

    -- Modificadores de status (ex: buffs/debuffs temporários)
    statusModifiers = {}
}

PlayerState.__index = PlayerState

--- Initialize player state
---@param baseStats table Containing base stats
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
    self.experienceToNextLevel = Constants.INITIAL_XP_TO_LEVEL or 100 -- Usa constante ou padrão
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
---@param initialStats table Tabela contendo os atributos base (geralmente de HunterManager).
---@return table A nova instância de PlayerState.
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
    state.experienceToNextLevel = Constants and Constants.INITIAL_XP_TO_LEVEL or 100
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

--- Take damage
---@param damage number Quantidade de dano bruto a ser aplicado.
---@param finalDamageReduction number The calculated final damage reduction.
---@return number O dano real sofrido após a redução.
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

--- Heal player
---@param amount number Amount of health to restore (before healing bonuses)
---@param finalMaxHealth number The calculated maximum health of the player.
---@param finalHealingBonusMultiplier number The calculated final healing bonus multiplier.
---@return number Amount of health actually restored
function PlayerState:heal(amount, finalMaxHealth, finalHealingBonusMultiplier)
    if not self.isAlive then return 0 end

    -- Aplica bônus de cura
    local effectiveAmount = amount * finalHealingBonusMultiplier
    local oldHealth = self.currentHealth
    -- Limita a cura pela vida máxima final
    self.currentHealth = math.min(self.currentHealth + effectiveAmount, finalMaxHealth)

    return self.currentHealth - oldHealth
end

--- Add bonus to an attribute
---@param attribute string Name of the attribute to add bonus
---@param percentage number Percentage of bonus to add (for level bonus)
---@param fixed number Fixed value to add (for fixed bonus)
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

--- Adiciona experiência ao jogador e verifica se houve level up.
--- NÃO realiza mais a cura ao subir de nível.
---@param amount number Quantidade de experiência a adicionar.
---@param finalExpBonus number O multiplicador final de experiência.
---@return number levelsGained O número de níveis que o jogador ganhou (0 se nenhum).
function PlayerState:addExperience(amount, finalExpBonus)
    if not self.isAlive then return 0 end

    local effectiveAmount = amount * finalExpBonus
    self.experience = self.experience + effectiveAmount

    local levelsGained = 0 -- Modificado para contar os níveis

    while self.experience >= self.experienceToNextLevel do
        self.level = self.level + 1
        local previousRequired = self.experienceToNextLevel
        self.experience = self.experience - previousRequired
        local xpFactor = Constants and Constants.XP_LEVEL_FACTOR or 1.15
        self.experienceToNextLevel = math.floor(self.experienceToNextLevel * xpFactor)
        levelsGained = levelsGained + 1 -- Incrementa o contador
    end

    return levelsGained -- Retorna o número de níveis ganhos
end

--- Retorna todos os bônus de level up aprendidos (ID do bônus -> nível aprendido)
---@return table<string, number>
function PlayerState:getLearnedLevelUpBonuses()
    return self.learnedLevelUpBonuses or {}
end

return PlayerState
