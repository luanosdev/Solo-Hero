--[[
    Player State
    Manages player's current state and status
]]

local Constants = require("src.config.constants") -- Usado para valores padrão se necessário

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

--[[
    Initialize player state
    @param baseStats Table containing base stats
]]
function PlayerState:init(baseStats)
    -- Inicializa atributos base usando baseStats ou os padrões da classe
    self.health = baseStats.health or PlayerState.health
    -- self.damage = baseStats.damage or PlayerState.damage -- Mantém para possível uso futuro
    self.defense = baseStats.defense or PlayerState.defense
    self.moveSpeed = baseStats.moveSpeed or PlayerState.moveSpeed    -- Atualizado
    self.attackSpeed = baseStats.attackSpeed or PlayerState.attackSpeed
    self.critChance = baseStats.critChance or PlayerState.critChance -- Atualizado
    self.critDamage = baseStats.critDamage or PlayerState.critDamage -- Atualizado
    self.healthRegen = baseStats.healthRegen or PlayerState.healthRegen
    self.multiAttackChance = baseStats.multiAttackChance or PlayerState.multiAttackChance
    self.runeSlots = baseStats.runeSlots or PlayerState.runeSlots
    -- Adiciona inicialização para os novos atributos
    self.expBonus = baseStats.expBonus or PlayerState.expBonus
    self.healingBonus = baseStats.healingBonus or PlayerState.healingBonus
    self.pickupRadius = baseStats.pickupRadius or PlayerState.pickupRadius
    self.healthRegenDelay = baseStats.healthRegenDelay or PlayerState.healthRegenDelay
    self.range = baseStats.range or PlayerState.range                -- Bônus percentual base
    self.luck = baseStats.luck or PlayerState.luck
    self.attackArea = baseStats.attackArea or PlayerState.attackArea -- Bônus percentual base
    self.healthPerTick = baseStats.healthPerTick or PlayerState.healthPerTick
    self.cooldownReduction = baseStats.cooldownReduction or PlayerState.cooldownReduction
    self.healthRegenCooldown = baseStats.healthRegenCooldown or PlayerState.healthRegenCooldown

    -- Reinicializa atributos de jogo para o estado inicial
    self.level = 1
    self.experience = 0
    self.experienceToNextLevel = Constants.INITIAL_XP_TO_LEVEL or 100 -- Usa constante ou padrão
    self.kills = 0
    self.gold = 0

    -- Inicializa bônus de nível (com novos nomes e adicionados)
    self.levelBonus = {
        health = 0,
        damageMultiplier = 0, -- RENOMEADO
        defense = 0,
        moveSpeed = 0,
        attackSpeed = 0,
        critChance = 0,
        critDamage = 0,
        healthRegen = 0,
        multiAttackChance = 0,
        expBonus = 0,
        healingBonus = 0,
        pickupRadius = 0,
        healthRegenDelay = 0,
        range = 0,
        luck = 0,
        attackArea = 0,
        healthPerTick = 0,
        cooldownReduction = 0,
        healthRegenCooldown = 0
    }
    -- Inicializa bônus fixos (com novos nomes e adicionados)
    self.fixedBonus = {
        health = 0,
        damageMultiplier = 0, -- RENOMEADO
        defense = 0,
        moveSpeed = 0,
        attackSpeed = 0,
        critChance = 0,
        critDamage = 0,
        healthRegen = 0,
        multiAttackChance = 0,
        expBonus = 0,
        healingBonus = 0,
        pickupRadius = 0,
        healthRegenDelay = 0,
        range = 0,
        luck = 0,
        attackArea = 0,
        healthPerTick = 0,
        cooldownReduction = 0,
        healthRegenCooldown = 0
    }

    -- Inicializa vida atual e máxima
    self.maxHealth = self:getTotalHealth()
    self.currentHealth = self.maxHealth
    self.isAlive = true
end

--[[
    Get total health (base + bonus)
    @return number Total health
]]
function PlayerState:getTotalHealth()
    -- Base * (1 + %LevelBonus) + FixedBonus (Aditivo)
    return (self.health * (1 + self.levelBonus.health / 100)) + self.fixedBonus.health
end

--[[
    Get total damage multiplier from player stats.
    Este método NÃO inclui o dano base da arma. Ele retorna o multiplicador total
    que deve ser aplicado ao dano base da arma.
    @return number Total damage multiplier (ex: 1.3 para +30%)
]]
function PlayerState:getTotalDamageMultiplier()
    -- 1 (base) + %LevelBonus + FixedBonus%
    return 1 + (self.levelBonus.damageMultiplier / 100) + self.fixedBonus.damageMultiplier
end

--[[
    Calcula o dano final, aplicando o multiplicador total do jogador ao dano base fornecido.
    @param baseDamage number Dano base (geralmente da arma).
    @return number Dano total calculado.
]]
function PlayerState:getTotalDamage(baseDamage)
    if type(baseDamage) ~= "number" then
        print(string.format("[PlayerState:getTotalDamage] Aviso: baseDamage inválido (%.2f), usando 0.", baseDamage or -1))
        baseDamage = 0
    end
    local multiplier = self:getTotalDamageMultiplier()
    return math.floor(baseDamage * multiplier)
end

--[[
    Get total defense (base + bonus)
    @return number Total defense
]]
function PlayerState:getTotalDefense()
    -- Base * (1 + %LevelBonus) + FixedBonus (Aditivo)
    return math.floor((self.defense * (1 + self.levelBonus.defense / 100)) + self.fixedBonus.defense)
end

--[[
    Get damage reduction percentage
    @return number Damage reduction percentage (0 to 0.8)
]]
function PlayerState:getDamageReduction()
    local defense = self:getTotalDefense()
    local K = Constants and Constants.DEFENSE_DAMAGE_REDUCTION_K or
        100                                                                         -- Valor padrão se constante não existir
    local reduction = defense / (defense + K)
    return math.min(Constants and Constants.MAX_DAMAGE_REDUCTION or 0.8, reduction) -- Limita a redução
end

--[[
    Get total move speed (base + bonus)
    @return number Total move speed
]]
function PlayerState:getTotalMoveSpeed()
    -- Base * (1 + %LevelBonus) + FixedBonus (Aditivo)
    return (self.moveSpeed * (1 + self.levelBonus.moveSpeed / 100)) + self.fixedBonus.moveSpeed
end

--[[
    Get total attack speed (base + bonus)
    @return number Total attack speed multiplier (ex: 1.2 = 20% mais rápido)
]]
function PlayerState:getTotalAttackSpeed()
    -- BaseMultiplier * (1 + %LevelBonus + FixedBonus%)
    -- Nota: O base self.attackSpeed já é um multiplicador (1.0 = 100%)
    return self.attackSpeed * (1 + self.levelBonus.attackSpeed / 100 + self.fixedBonus.attackSpeed)
end

--[[
    Get total critical chance (base + bonus)
    @return number Total critical chance (fraction, e.g., 0.15 for 15%)
]]
function PlayerState:getTotalCritChance()
    -- (Base * (1 + %LevelBonus)) + FixedBonus%
    -- Nota: Base e FixedBonus são frações (0.1 = 10%)
    return (self.critChance * (1 + self.levelBonus.critChance / 100)) + self.fixedBonus.critChance
end

--[[
    Get total critical multiplier (base + bonus)
    @return number Total critical multiplier (e.g., 1.75 for +75% crit damage)
]]
function PlayerState:getTotalCritDamage() -- RENOMEADO DE getTotalCritDamage
    -- BaseMultiplier + (%LevelBonus / 100) + FixedBonus%
    -- Nota: Base e FixedBonus são multiplicadores/percentuais (1.5 = +50%, 0.25 = +25%)
    return self.critDamage + (self.levelBonus.critDamage / 100) + self.fixedBonus.critDamage
end

--[[
    Get total health regeneration (base + bonus)
    @return number Quantidade de HP recuperado por segundo
]]
function PlayerState:getTotalHealthRegen()
    -- Base * (1 + %LevelBonus) + FixedBonus (Aditivo)
    return (self.healthRegen * (1 + self.levelBonus.healthRegen / 100)) + self.fixedBonus.healthRegen
end

--[[
    Get total multi attack chance (base + bonus)
    @return number Total multi attack chance (fraction, e.g., 0.2 for 20%)
]]
function PlayerState:getTotalMultiAttackChance()
    -- (Base * (1 + %LevelBonus)) + FixedBonus%
    -- Nota: Base e FixedBonus são frações (0.1 = 10%)
    return (self.multiAttackChance * (1 + self.levelBonus.multiAttackChance / 100)) + self.fixedBonus.multiAttackChance
end

--[[
    Get total range bonus percentage (as fraction).
    Retorna o bônus total que deve ser adicionado ao range base da arma/habilidade.
    Ex: Retorna 0.3 para um bônus total de +30%.
    @return number Total range bonus percentage (fraction).
]]
function PlayerState:getTotalRange()
    -- %Base + %LevelBonus + FixedBonus%
    return self.range + (self.levelBonus.range / 100) + self.fixedBonus.range
end

--[[
    Get total attack area bonus percentage (as fraction).
    Retorna o bônus total que deve ser adicionado à área base da arma/habilidade.
    Ex: Retorna 0.15 para um bônus total de +15%.
    @return number Total attack area bonus percentage (fraction).
]]
function PlayerState:getTotalArea() -- Mantendo nome por compatibilidade com AlternatingConeStrike
    -- %Base + %LevelBonus + FixedBonus%
    return self.attackArea + (self.levelBonus.attackArea / 100) + self.fixedBonus.attackArea
end

--[[
    Take damage
    Calcula o dano real sofrido após a redução pela defesa e atualiza a vida.
    Marca o jogador como não-vivo se a vida chegar a zero ou menos.
    @param damage (number): Quantidade de dano bruto a ser aplicado.
    @return number: O dano real sofrido após a redução.
]]
function PlayerState:takeDamage(damage)
    if not self.isAlive then return 0 end -- Retorna 0 dano se já estiver morto

    -- Calcula a redução de dano
    local reduction = self:getDamageReduction()
    local actualDamage = math.max(1, math.floor(damage * (1 - reduction)))

    self.currentHealth = math.max(0, self.currentHealth - actualDamage)

    if self.currentHealth <= 0 then
        self.isAlive = false
    end

    return actualDamage -- Retorna o dano real sofrido
end

--- Heal player
---@param amount number Amount of health to restore
---@return number Amount of health actually restored
function PlayerState:heal(amount)
    if not self.isAlive then return 0 end

    -- MultiplicadorBase * (1 + %LevelBonus + FixedBonus%)
    local effectiveMultiplier = self.healingBonus *
        (1 + self.levelBonus.healingBonus / 100 + self.fixedBonus.healingBonus)
    local effectiveAmount = amount * effectiveMultiplier
    local oldHealth = self.currentHealth
    self.currentHealth = math.min(self.currentHealth + effectiveAmount, self:getTotalHealth())

    return self.currentHealth - oldHealth -- Retorna quanto curou de fato
end

--[[
    Get current health percentage
    @return number Health percentage (0 to 1)
]]
function PlayerState:getHealthPercentage()
    local totalHealth = self:getTotalHealth()
    if totalHealth <= 0 then return 0 end -- Evita divisão por zero
    return self.currentHealth / totalHealth
end

--[[
    Add bonus to an attribute
    @param attribute Name of the attribute to add bonus
    @param percentage Percentage of bonus to add (for level bonus)
    @param fixed Fixed value to add (for fixed bonus)
]]
function PlayerState:addAttributeBonus(attribute, percentage, fixed)
    percentage = percentage or 0
    fixed = fixed or 0

    local bonusApplied = false

    -- Verifica se é bônus de Nível (geralmente percentual)
    if self.levelBonus[attribute] ~= nil then
        local oldBonus = self.levelBonus[attribute]
        -- Assumindo que levelBonus sempre recebe o valor percentual
        self.levelBonus[attribute] = self.levelBonus[attribute] + percentage
        print(string.format(
            "[PlayerState] Bônus de Level %s adicionado: +%.1f%% (Antigo: %.1f%%, Novo: %.1f%%)",
            attribute, percentage, oldBonus, self.levelBonus[attribute]))
        bonusApplied = true
    end

    -- Verifica se é bônus Fixo (pode ser aditivo ou percentual fixo)
    -- Usamos 'fixed' como o valor a ser adicionado ao bônus fixo existente.
    if self.fixedBonus[attribute] ~= nil then
        local oldValue = self.fixedBonus[attribute]
        self.fixedBonus[attribute] = self.fixedBonus[attribute] + fixed
        print(string.format(
            "[PlayerState] Bônus Fixo %s adicionado: +%.2f (Antigo: %.2f, Novo: %.2f)",
            attribute, fixed, oldValue, self.fixedBonus[attribute]))
        bonusApplied = true
    end

    if not bonusApplied then
        print(string.format("[PlayerState] ERRO: Atributo '%s' não encontrado para adicionar bônus.", attribute))
        return
    end

    -- Atualiza valores derivados APENAS se for health
    if attribute == "health" then
        local oldMaxHealth = self.maxHealth
        self.maxHealth = self:getTotalHealth()
        -- Cura o valor aumentado da vida máxima
        local healthIncrease = self.maxHealth - oldMaxHealth
        if healthIncrease > 0 then
            self:heal(healthIncrease) -- Usa o heal para aplicar bônus de cura
        end
        print(string.format("[PlayerState] Vida Máxima atualizada: %.1f -> %.1f. Vida Atual: %.1f", oldMaxHealth,
            self.maxHealth, self.currentHealth))
    end

    -- Adiciona logs para outros atributos se necessário (getTotal... já calcula o valor final)
    -- Ex: if attribute == "moveSpeed" then print(...) end
end

--[[
    Adiciona experiência ao jogador e verifica se houve level up.
    @param amount Quantidade de experiência a adicionar.
    @return boolean True se o jogador subiu de nível, false caso contrário.
]]
function PlayerState:addExperience(amount)
    if not self.isAlive then return false end
    -- MultiplicadorBase * (1 + %LevelBonus + FixedBonus%)
    local effectiveMultiplier = self.expBonus * (1 + self.levelBonus.expBonus / 100 + self.fixedBonus.expBonus)
    local effectiveAmount = amount * effectiveMultiplier
    self.experience = self.experience + effectiveAmount
    local leveledUp = false
    while self.experience >= self.experienceToNextLevel do
        self.level = self.level + 1
        local previousRequired = self.experienceToNextLevel
        self.experience = self.experience - previousRequired
        -- Recalcula XP para o próximo nível (ex: usando constante ou fórmula)
        local xpFactor = Constants and Constants.XP_LEVEL_FACTOR or 1.15
        self.experienceToNextLevel = math.floor(self.experienceToNextLevel * xpFactor)
        leveledUp = true
        self:heal(self:getTotalHealth() * 0.25) -- Cura 25% ao subir de nível
    end
    return leveledUp
end

--[[
    Adiciona ouro ao jogador.
    @param amount Quantidade de ouro a adicionar.
]]
function PlayerState:addGold(amount)
    if not self.isAlive then return end
    -- Aplicar bônus de sorte/gold find aqui?
    -- local effectiveAmount = amount * (self:getTotalLuck() * ??) -- Assumindo getTotalLuck retorna multiplicador
    -- self.gold = self.gold + effectiveAmount
    self.gold = self.gold + amount -- Sem bônus de luck aplicado por enquanto
end

--[[
    Incrementa a contagem de abates do jogador.
]]
function PlayerState:addKill()
    if not self.isAlive then return end
    self.kills = self.kills + 1
end

--[[
    Construtor: Cria e inicializa uma nova instância de PlayerState.
    @param initialStats (table): Tabela contendo os atributos base.
    @return table: A nova instância de PlayerState.
]]
function PlayerState:new(initialStats)
    print("--- PlayerState:new --- ") -- DEBUG
    local state = setmetatable({}, PlayerState)

    -- 1. Copia valores padrão da CLASSE (incluindo tabelas de bônus)
    for key, value in pairs(PlayerState) do
        if type(value) ~= 'function' and key ~= '__index' then -- Copia apenas dados, não métodos
            if type(value) == 'table' then
                state[key] = {}                                -- Cria uma CÓPIA RASA da tabela de bônus
                for k, v in pairs(value) do
                    state[key][k] = v
                end
            else
                state[key] = value
            end
        end
    end

    -- 2. Sobrescreve com initialStats, se fornecido
    print("  [DEBUG] Applying initialStats:") -- DEBUG
    if initialStats and next(initialStats) then
        for key, value in pairs(initialStats) do
            -- Só sobrescreve se o atributo existir no PlayerState e o tipo for compatível
            if state[key] ~= nil and type(state[key]) == type(value) then
                state[key] = value
                print(string.format("    - Applied: state.%s = %s", key, tostring(value)))                        -- DEBUG
            elseif state[key] == nil then
                print(string.format("    - WARNING: initialStat '%s' not defined in PlayerState. Ignored.", key)) -- DEBUG
            else                                                                                                  -- Tipo incompatível
                print(string.format("    - WARNING: initialStat '%s' type mismatch (Expected %s, got %s). Ignored.", key,
                    type(state[key]), type(value)))                                                               -- DEBUG
            end
        end
    else
        print("    - WARNING: No initialStats provided! Using PlayerState class defaults.") -- DEBUG
    end

    -- 3. Define estado inicial (já feito ao copiar defaults e aplicar initialStats, mas garante reset)
    state.level = 1
    state.experience = 0
    state.experienceToNextLevel = Constants and Constants.INITIAL_XP_TO_LEVEL or 100
    state.kills = 0
    state.gold = 0
    state.isAlive = true
    state.maxHealth = state:getTotalHealth() -- Calcula maxHealth com base nos stats aplicados
    state.currentHealth = state.maxHealth    -- Começa com vida cheia
    state.statusModifiers = {}               -- Limpa modificadores

    -- Log final de verificação
    print(string.format("  [DEBUG] PlayerState:new - Final health: %.1f/%.1f", state.currentHealth, state.maxHealth)) -- DEBUG

    return state
end

--[[
    Get total rune slots
    @return number Total rune slots
]]
function PlayerState:getTotalRuneSlots()
    -- Por enquanto, runas não são afetadas por bônus
    return self.runeSlots
end

--[[ Get total luck ]] -- NOVO
function PlayerState:getTotalLuck()
    -- BaseMultiplier * (1 + %LevelBonus + FixedBonus%)
    return self.luck * (1 + self.levelBonus.luck / 100 + self.fixedBonus.luck)
end

--[[ Get total pickupRadius ]] -- NOVO
function PlayerState:getTotalPickupRadius()
    -- Base * (1 + %LevelBonus) + FixedBonus (Aditivo)
    return (self.pickupRadius * (1 + self.levelBonus.pickupRadius / 100)) + self.fixedBonus.pickupRadius
end

--[[ Get total expBonus ]] -- NOVO
function PlayerState:getTotalExpBonus()
    -- BaseMultiplier * (1 + %LevelBonus + FixedBonus%)
    return self.expBonus * (1 + self.levelBonus.expBonus / 100 + self.fixedBonus.expBonus)
end

--[[ Get total healingBonus ]] -- NOVO
function PlayerState:getTotalHealingBonus()
    -- BaseMultiplier * (1 + %LevelBonus + FixedBonus%)
    return self.healingBonus * (1 + self.levelBonus.healingBonus / 100 + self.fixedBonus.healingBonus)
end

--[[ Get total healthRegenDelay ]] -- NOVO
function PlayerState:getTotalHealthRegenDelay()
    -- Base - (%LevelBonus / 100 * Base) - FixedBonus (Assumindo que bônus REDUZEM o delay)
    -- Cuidado para não ficar negativo
    local baseDelay = self.healthRegenDelay
    local levelReduction = baseDelay * (self.levelBonus.healthRegenDelay / 100)
    local fixedReduction = self.fixedBonus.healthRegenDelay
    return math.max(0.1, baseDelay - levelReduction - fixedReduction) -- Garante um delay mínimo
end

--[[ Get total healthPerTick ]] -- NOVO
function PlayerState:getTotalHealthPerTick()
    -- Base * (1 + %LevelBonus) + FixedBonus (Aditivo)
    return (self.healthPerTick * (1 + self.levelBonus.healthPerTick / 100)) + self.fixedBonus.healthPerTick
end

--[[ Get total cooldownReduction ]] -- NOVO
function PlayerState:getTotalCooldownReduction()
    -- Retorna um multiplicador (ex: 0.8 para 20% de redução)
    -- BaseMultiplier * (1 - %LevelBonus - FixedBonus%)
    -- Cuidado para não ficar negativo ou zero
    local levelReductionPercent = self.levelBonus.cooldownReduction / 100
    local fixedReductionPercent = self.fixedBonus.cooldownReduction
    local totalReductionPercent = levelReductionPercent + fixedReductionPercent
    -- Limita a redução máxima (ex: 80%) para evitar cooldown zero ou negativo
    totalReductionPercent = math.min(totalReductionPercent, Constants.MAX_COOLDOWN_REDUCTION or 0.8)
    return self.cooldownReduction * (1 - totalReductionPercent)
end

return PlayerState
