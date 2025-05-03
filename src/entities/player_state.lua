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
    damage = 0,            -- Nota: 'damage' parece ser tratado de forma diferente (vem da arma?), manter por enquanto
    defense = 10,
    moveSpeed = 40,        -- Renomeado de 'speed'
    attackSpeed = 1.0,
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
    range = 1.0,               -- Multiplicador? Pixels? (Padrão 1)
    luck = 1.0,                -- Multiplicador? (Padrão 1)
    attackArea = 1.0,          -- Multiplicador? (Padrão 1)
    healthPerTick = 1.0,       -- HP por tick de regeneração (Padrão 1)
    cooldownReduction = 1.0,   -- Multiplicador (1.0 = sem redução)
    healthRegenCooldown = 1.0, -- Segundos entre ticks de regen? (Padrão 1)

    -- Bônus por nível (em porcentagem ou valor base, dependendo do stat)
    levelBonus = {
        health = 0,
        damage = 0,
        defense = 0,
        moveSpeed = 0,
        attackSpeed = 0,
        critChance = 0, -- Renomeado
        critDamage = 0, -- Renomeado
        healthRegen = 0,
        multiAttackChance = 0,
        -- Adicionar outros bônus de level se aplicável (luck, area, etc.)? Por enquanto não.
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
    },

    -- Bônus fixos (aditivos)
    fixedBonus = {
        health = 0,
        damage = 0,
        defense = 0,
        moveSpeed = 0,  -- Renomeado
        attackSpeed = 0,
        critChance = 0, -- Renomeado
        critDamage = 0, -- Renomeado
        healthRegen = 0,
        multiAttackChance = 0,
        -- Adicionar outros bônus fixos se aplicável
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
    -- Inicializa atributos base
    self.health = baseStats.health or PlayerState.health
    self.damage = baseStats.damage or PlayerState.damage
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
    self.range = baseStats.range or PlayerState.range
    self.luck = baseStats.luck or PlayerState.luck
    self.attackArea = baseStats.attackArea or PlayerState.attackArea
    self.healthPerTick = baseStats.healthPerTick or PlayerState.healthPerTick
    self.cooldownReduction = baseStats.cooldownReduction or PlayerState.cooldownReduction
    self.healthRegenCooldown = baseStats.healthRegenCooldown or PlayerState.healthRegenCooldown

    -- Reinicializa atributos de jogo para o estado inicial
    self.level = 1
    self.experience = 0
    self.experienceToNextLevel = 100
    self.experienceMultiplier = 1.10
    self.kills = 0
    self.gold = 0

    -- Inicializa bônus de nível (com novos nomes e adicionados)
    self.levelBonus = {
        health = 0,
        damage = 0,
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
        damage = 0,
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
    return (self.health * (1 + self.levelBonus.health / 100)) + self.fixedBonus.health
end

--[[
    Get total damage (base + bonus)
    @param baseDamage Valor base do dano (pode ser número ou tabela {min, max})
    @return number Total damage (calculado com base na média se for range)
]]
function PlayerState:getTotalDamage(baseDamage)
    local effectiveBase = 0
    if type(baseDamage) == "number" then
        effectiveBase = baseDamage
    else
        print("[PlayerState:getTotalDamage] Aviso: baseDamage inválido -", baseDamage)
        effectiveBase = self.damage -- Usa o 'damage' base do PlayerState como fallback
    end

    local totalDamage = math.floor(effectiveBase * (1 + self.levelBonus.damage / 100))
    return totalDamage
end

--[[
    Get total defense (base + bonus)
    @return number Total defense
]]
function PlayerState:getTotalDefense()
    return math.floor(self.defense * (1 + self.levelBonus.defense / 100) + self.fixedBonus.defense)
end

--[[
    Get damage reduction percentage
    @return number Damage reduction percentage (0 to 0.8)
]]
function PlayerState:getDamageReduction()
    local defense = self:getTotalDefense()
    local K = Constants and Constants.DEFENSE_DAMAGE_REDUCTION_K
    local reduction = defense / (defense + K)
    return math.min(Constants and Constants.MAX_DAMAGE_REDUCTION, reduction) -- Limita a redução
end

--[[
    Get total move speed (base + bonus)
    @return number Total move speed
]]
function PlayerState:getTotalMoveSpeed()
    return (self.moveSpeed * (1 + self.levelBonus.moveSpeed / 100)) + self.fixedBonus.moveSpeed
end

--[[
    Get total attack speed (base + bonus)
    @return number Total attack speed
]]
function PlayerState:getTotalAttackSpeed()
    return (self.attackSpeed * (1 + self.levelBonus.attackSpeed / 100)) + self.fixedBonus.attackSpeed
end

--[[
    Get total critical chance (base + bonus)
    @return number Total critical chance
]]
function PlayerState:getTotalCritChance()
    return self.critChance * (1 + self.levelBonus.critChance / 100) + self.fixedBonus.critChance
end

--[[
    Get total critical multiplier (base + bonus)
    @return number Total critical multiplier
]]
function PlayerState:getTotalCritDamage()
    -- Assumindo bônus de level e fixo são aditivos (pois são multiplicadores/%)
    -- Retorna como multiplicador (ex: 1.7 para +70% dano)
    return (self.critDamage + self.levelBonus.critDamage / 100) + self.fixedBonus.critDamage / 100
end

--[[
    Get total health regeneration (base + bonus)
    @return number Quantidade de HP recuperado por segundo
]]
function PlayerState:getTotalHealthRegen()
    -- Assumindo bônus de level percentual, fixo aditivo
    return (self.healthRegen * (1 + self.levelBonus.healthRegen / 100)) + self.fixedBonus.healthRegen
end

--[[
    Get total multi attack chance (base + bonus)
    @return number Total multi attack chance
]]
function PlayerState:getTotalMultiAttackChance()
    return self.multiAttackChance * (1 + self.levelBonus.multiAttackChance / 100)
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
---@return number|nil Effective amount of health restored
function PlayerState:heal(amount)
    if not self.isAlive then return end

    local effectiveAmount = amount *
        (self.healingBonus * (1 + self.levelBonus.healingBonus / 100)) -- Aplica bônus de cura
    self.currentHealth = math.min(self.currentHealth + effectiveAmount, self:getTotalHealth())

    return effectiveAmount
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
    @param percentage Percentage of bonus to add
    @param fixed Fixed percentage of bonus to add (for defense)
]]
function PlayerState:addAttributeBonus(attribute, percentage, fixed)
    fixed = fixed or 0

    local isLevelBonus = self.levelBonus[attribute] ~= nil
    local isFixedBonus = self.fixedBonus[attribute] ~= nil

    if isLevelBonus then
        local oldBonus = self.levelBonus[attribute]
        self.levelBonus[attribute] = self.levelBonus[attribute] +
            percentage -- Assume bônus de level é sempre percentual? Verificar.
        print(string.format(
            "[PlayerState] Bônus de Level %s adicionado: +%.1f%% (Antigo: %.1f%%, Novo: %.1f%%)",
            attribute, percentage, oldBonus, self.levelBonus[attribute]))
    elseif isFixedBonus then -- Se não for bônus de level, talvez seja fixo?
        local oldBonus = self.fixedBonus[attribute]
        self.fixedBonus[attribute] = self.fixedBonus[attribute] +
            (fixed or percentage) -- Usa 'fixed' se fornecido, senão 'percentage'
        print(string.format(
            "[PlayerState] Bônus Fixo %s adicionado: +%.1f (Antigo: %.1f, Novo: %.1f)",
            attribute, (fixed or percentage), oldBonus, self.fixedBonus[attribute]))
    else
        print(string.format("[PlayerState] ERRO: Atributo '%s' não encontrado para adicionar bônus.", attribute))
        return -- Sai se o atributo não existe nem em levelBonus nem em fixedBonus
    end

    -- Atualiza valores derivados APENAS se for health
    if attribute == "health" then
        self.maxHealth = self:getTotalHealth()
        -- Cura completa ao ganhar vida máxima? Ou mantém percentual? Manter percentual parece melhor.
        local percent = self:getHealthPercentage()
        self.currentHealth = self.maxHealth * percent
        print(string.format("[PlayerState] Vida atualizada: %.1f/%.1f", self.currentHealth, self.maxHealth))
    end

    -- Adiciona logs para outros atributos se necessário (getTotal... já calcula o valor final)
    -- Ex: if attribute == "moveSpeed" then print(...) end
end

--[[
    Atualiza os atributos base quando uma nova arma é equipada
    @param weapon A nova arma equipada
]]
function PlayerState:updateWeaponStats(weapon)
    if not weapon then return end
    -- Atualiza apenas o dano base da arma (se a arma definir 'damage')
    self.damage = weapon.damage or self.damage -- Mantém o anterior se a arma não tiver 'damage'
    -- Poderia atualizar outros stats aqui se a arma os fornecer (ex: attackSpeed base da arma)
    -- self.attackSpeed = weapon.attackSpeed or self.attackSpeed
end

--[[
    Get total area (base + bonus)
    @return number Total area
]]
function PlayerState:getTotalArea()
    -- Usando attackArea agora que foi adicionado
    return self:getTotalAttackArea() -- Delega para o novo método (se criado) ou cálculo direto
    -- return (self.attackArea * (1 + self.levelBonus.attackArea / 100)) + self.fixedBonus.attackArea
end

--[[
    Get total range (base + bonus)
    @return number Total range
]]
function PlayerState:getTotalRange()
    -- Assumindo bônus de level percentual, fixo aditivo
    return (self.range * (1 + self.levelBonus.range / 100)) + self.fixedBonus.range
end

--[[
    Adiciona experiência ao jogador e verifica se houve level up.
    @param amount Quantidade de experiência a adicionar.
    @return boolean True se o jogador subiu de nível, false caso contrário.
]]
function PlayerState:addExperience(amount)
    if not self.isAlive then return false end
    local effectiveAmount = amount * (self.expBonus * (1 + self.levelBonus.expBonus / 100)) -- Aplica bônus de XP
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
    -- local effectiveAmount = amount * (self:getTotalLuck() * ??)
    self.gold = self.gold + amount
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

    -- 1. Define valores padrão da CLASSE para todos os atributos
    for key, value in pairs(PlayerState) do
        if type(value) ~= 'function' and key ~= '__index' then -- Copia apenas dados, não métodos
            if type(value) == 'table' then
                state[key] = {}                                -- Cria uma nova tabela para bônus
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
            if state[key] ~= nil then                                                                             -- Só sobrescreve se o atributo existir no PlayerState
                state[key] = value
                print(string.format("    - Applied: state.%s = %.2f", key, value))                                -- DEBUG
            else
                print(string.format("    - WARNING: initialStat '%s' not defined in PlayerState. Ignored.", key)) -- DEBUG
            end
        end
    else
        print("    - WARNING: No initialStats provided! Using PlayerState class defaults.") -- DEBUG
    end

    -- 3. Define estado inicial
    state.level = 1
    state.experience = 0
    state.experienceToNextLevel = Constants and Constants.INITIAL_XP_TO_LEVEL or 100
    state.kills = 0
    state.gold = 0
    state.isAlive = true
    state.maxHealth = state:getTotalHealth() -- Calcula maxHealth com base nos stats aplicados
    state.currentHealth = state.maxHealth    -- Começa com vida cheia
    state.statusModifiers = {}               -- Limpa modificadores

    -- Log final de verificação para moveSpeed
    print(string.format("  [DEBUG] PlayerState:new - Final value check before return: state.moveSpeed = %.2f",
        state.moveSpeed)) -- DEBUG

    return state
end

--[[
    Get total rune slots
    @return number Total rune slots
]]
function PlayerState:getTotalRuneSlots()
    -- Assumindo que bônus de level e fixo são aditivos
    return self.runeSlots
end

--[[ Get total luck ]] -- NOVO
function PlayerState:getTotalLuck()
    -- Assumindo bônus de level percentual, fixo aditivo
    return (self.luck * (1 + self.levelBonus.luck / 100)) + self.fixedBonus.luck
end

--[[ Get total attackArea ]] -- NOVO
function PlayerState:getTotalAttackArea()
    -- Assumindo bônus de level percentual, fixo aditivo
    return (self.attackArea * (1 + self.levelBonus.attackArea / 100)) + self.fixedBonus.attackArea
end

--[[ Get total pickupRadius ]] -- NOVO
function PlayerState:getTotalPickupRadius()
    -- Assumindo bônus de level percentual, fixo aditivo
    return (self.pickupRadius * (1 + self.levelBonus.pickupRadius / 100)) + self.fixedBonus.pickupRadius
end

return PlayerState
