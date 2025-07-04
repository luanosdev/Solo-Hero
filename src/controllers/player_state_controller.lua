-------------------------------------------------------------------------
-- Controlador unificado para estado e estatísticas do jogador.
-- Integra gerenciamento de estado, cálculo de stats e progressão.
-------------------------------------------------------------------------

local Constants = require("src.config.constants")

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

---@class FinalStats Estatísticas finais calculadas do jogador
---@field health number Vida máxima final
---@field damage number Dano base final
---@field defense number Defesa final
---@field moveSpeed number Velocidade de movimento final
---@field attackSpeed number Velocidade de ataque final
---@field critChance number Chance crítica final
---@field critDamage number Multiplicador de dano crítico final
---@field healthRegen number Regeneração de vida final
---@field multiAttackChance number Chance de ataque múltiplo final
---@field runeSlots number Slots de runa disponíveis
---@field strength number Força final
---@field expBonus number Multiplicador de experiência final
---@field healingBonus number Multiplicador de cura final
---@field pickupRadius number Raio de coleta final
---@field healthRegenDelay number Atraso de regeneração final
---@field range number Alcance final
---@field luck number Sorte final
---@field attackArea number Área de ataque final
---@field healthPerTick number Vida por tick final
---@field cooldownReduction number Redução de cooldown final
---@field healthRegenCooldown number Cooldown de regeneração final
---@field dashCharges number Cargas de dash finais
---@field dashCooldown number Cooldown de dash final
---@field dashDistance number Distância de dash final
---@field dashDuration number Duração de dash final
---@field potionFlasks number Frascos de poção finais
---@field potionHealAmount number Cura por poção final
---@field potionFillRate number Velocidade de preenchimento final
---@field weaponDamage number Dano total da arma (base + multiplicadores)
---@field _baseWeaponDamage number Dano base da arma (apenas para referência)
---@field _playerDamageMultiplier number Multiplicador de dano do jogador
---@field _levelBonus LevelBonus Bônus de nível (para referência)
---@field _fixedBonus FixedBonus Bônus fixos (para referência)
---@field _learnedLevelUpBonuses LearnedLevelUpBonuses Bônus aprendidos (para referência)
---@field equippedItems EquippedItems Itens equipados (para referência)
---@field archetypeIds ArchetypeInfo[] Arquétipos ativos (para referência)

---@class PlayerStateController Controlador unificado de estado e estatísticas do jogador
---@field playerManager PlayerManager Referência ao PlayerManager
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
---@field learnedLevelUpBonuses LearnedLevelUpBonuses Bônus de level up aprendidos
---@field equippedItems EquippedItems Itens atualmente equipados
---@field archetypeIds ArchetypeInfo[] Lista de arquétipos ativos
---@field finalStatsCache FinalStats|nil Cache das estatísticas finais calculadas
---@field statsNeedRecalculation boolean Flag indicando se o cache precisa ser atualizado
local PlayerStateController = {}
PlayerStateController.__index = PlayerStateController

--- Cria uma nova instância do PlayerStateController.
---@param playerManager PlayerManager A instância do PlayerManager
---@param initialStats table Estatísticas base do hunter
---@return PlayerStateController
function PlayerStateController:new(playerManager, initialStats)
    Logger.debug(
        "player_state_controller.new",
        "[PlayerStateController:new] Inicializando controlador de estado do jogador"
    )

    local instance = setmetatable({}, PlayerStateController)

    instance.playerManager = playerManager

    -- Inicializa estado base
    instance:initializeBaseStats(initialStats)

    -- Inicializa sistema de cache de stats
    instance.finalStatsCache = nil
    instance.statsNeedRecalculation = true

    return instance
end

--- Inicializa as estatísticas base do jogador
---@param initialStats table Estatísticas base fornecidas
function PlayerStateController:initializeBaseStats(initialStats)
    local defaultStats = Constants.HUNTER_DEFAULT_STATS or {}

    -- Atributos de gameplay
    self.level = 1
    self.experience = 0
    self.experienceToNextLevel = Constants.INITIAL_XP_TO_LEVEL
    self.kills = 0
    self.gold = 0
    self.isAlive = true

    -- Atributos base (com fallbacks dos padrões)
    self.health = initialStats and initialStats.health or defaultStats.health or 100
    self.defense = initialStats and initialStats.defense or defaultStats.defense or 10
    self.moveSpeed = initialStats and initialStats.moveSpeed or defaultStats.moveSpeed or
    Constants.HUNTER_DEFAULT_STATS.moveSpeed
    self.attackSpeed = initialStats and initialStats.attackSpeed or defaultStats.attackSpeed or 1.0
    self.critChance = initialStats and initialStats.critChance or defaultStats.critChance or 0.1
    self.critDamage = initialStats and initialStats.critDamage or defaultStats.critDamage or 1.5
    self.healthRegen = initialStats and initialStats.healthRegen or defaultStats.healthRegen or 0.5
    self.multiAttackChance = initialStats and initialStats.multiAttackChance or defaultStats.multiAttackChance or 0
    self.runeSlots = initialStats and initialStats.runeSlots or defaultStats.runeSlots or 1
    self.strength = initialStats and initialStats.strength or defaultStats.strength or 1

    -- Atributos adicionais
    self.expBonus = initialStats and initialStats.expBonus or defaultStats.expBonus or 1.0
    self.healingBonus = initialStats and initialStats.healingBonus or defaultStats.healingBonus or 1.0
    self.pickupRadius = initialStats and initialStats.pickupRadius or defaultStats.pickupRadius or
    Constants.HUNTER_DEFAULT_STATS.pickupRadius
    self.healthRegenDelay = initialStats and initialStats.healthRegenDelay or defaultStats.healthRegenDelay or 8.0
    self.range = initialStats and initialStats.range or defaultStats.range or 0
    self.luck = initialStats and initialStats.luck or defaultStats.luck or 1.0
    self.attackArea = initialStats and initialStats.attackArea or defaultStats.attackArea or 0
    self.healthPerTick = initialStats and initialStats.healthPerTick or defaultStats.healthPerTick or 1.0
    self.cooldownReduction = initialStats and initialStats.cooldownReduction or defaultStats.cooldownReduction or 1.0
    self.healthRegenCooldown = initialStats and initialStats.healthRegenCooldown or defaultStats.healthRegenCooldown or
        1.0

    -- Atributos de dash
    self.dashCharges = initialStats and initialStats.dashCharges or defaultStats.dashCharges or 0
    self.dashCooldown = initialStats and initialStats.dashCooldown or defaultStats.dashCooldown or 0
    self.dashDistance = initialStats and initialStats.dashDistance or defaultStats.dashDistance or 0
    self.dashDuration = initialStats and initialStats.dashDuration or defaultStats.dashDuration or 0

    -- Atributos de poções
    self.potionFlasks = initialStats and initialStats.potionFlasks or defaultStats.potionFlasks or 1
    self.potionHealAmount = initialStats and initialStats.potionHealAmount or defaultStats.potionHealAmount or 50
    self.potionFillRate = initialStats and initialStats.potionFillRate or defaultStats.potionFillRate or 1.0

    -- Inicializa estruturas de bônus
    self.levelBonus = {}
    self.fixedBonus = {}
    self.statusModifiers = {}
    self.learnedLevelUpBonuses = {}
    self.equippedItems = initialStats and initialStats.equippedItems or {}
    self.archetypeIds = initialStats and initialStats.archetypeIds or {}

    -- Inicializa vida atual
    self.currentHealth = self.health

    Logger.info(
        "player_state_controller.init",
        string.format("[PlayerStateController:initializeBaseStats] Estado inicializado. HP: %.1f/%.1f",
            self.currentHealth, self.health)
    )
end

--- Aplica dano ao jogador
---@param damage number Quantidade de dano bruto a ser aplicado
---@return number O dano real sofrido após a redução
function PlayerStateController:takeDamage(damage)
    if not self.isAlive then return 0 end
    local finalDefense = self:getCurrentFinalStats().defense

    -- Calcula a redução de dano usando a defesa final
    local K = Constants.DEFENSE_DAMAGE_REDUCTION_K
    local finalDamageReduction = finalDefense / (finalDefense + K)
    finalDamageReduction = math.min(Constants.MAX_DAMAGE_REDUCTION, finalDamageReduction)

    local actualDamage = math.max(1, math.floor(damage * (1 - finalDamageReduction)))
    self.currentHealth = math.max(0, self.currentHealth - actualDamage)

    if self.currentHealth <= 0 then
        self.isAlive = false
    end

    return actualDamage
end

--- Restaura vida do jogador
---@param amount number Quantidade de vida a restaurar (antes dos bônus de cura)
---@return number Quantidade de vida efetivamente restaurada
function PlayerStateController:heal(amount)
    if not self.isAlive then return 0 end

    local finalStats = self:getCurrentFinalStats()

    local effectiveAmount = amount * finalStats.healingBonus
    local oldHealth = self.currentHealth
    self.currentHealth = math.floor(math.min(self.currentHealth + effectiveAmount, finalStats.health))

    return math.floor(self.currentHealth - oldHealth)
end

--- Adiciona experiência ao jogador e calcula level ups
---@param amount number A quantidade de experiência bruta recebida
---@param finalExpBonus number Um multiplicador aplicado sobre a experiência
---@return number levelsGained A quantidade total de níveis ganhos
function PlayerStateController:addExperience(amount, finalExpBonus)
    if not self.isAlive then return 0 end

    local effectiveAmount = amount * finalExpBonus
    self.experience = self.experience + effectiveAmount

    local levelsGained = 0

    while self.experience >= self.experienceToNextLevel do
        self.level = self.level + 1
        local previousRequired = self.experienceToNextLevel
        self.experience = self.experience - previousRequired

        -- Fórmula: floor(30 * level ^ 1.5)
        self.experienceToNextLevel = math.floor(30 * self.level ^ 1.5)

        levelsGained = levelsGained + 1
    end

    if levelsGained > 0 then
        self:invalidateStatsCache()
    end

    return levelsGained
end

--- Adiciona bônus a um atributo específico
---@param attribute StatKey Nome do atributo para adicionar o bônus
---@param percentage number Porcentagem de bônus para level bonus
---@param fixed number Valor fixo para fixed bonus
function PlayerStateController:addAttributeBonus(attribute, percentage, fixed)
    percentage = percentage or 0
    fixed = fixed or 0

    local bonusApplied = false

    -- Verifica se é bônus de Nível (geralmente percentual)
    if percentage ~= 0 then
        if not self.levelBonus[attribute] then self.levelBonus[attribute] = 0 end
        self.levelBonus[attribute] = self.levelBonus[attribute] + percentage
        bonusApplied = true
    end

    -- Verifica se é bônus Fixo
    if fixed ~= 0 then
        if not self.fixedBonus[attribute] then self.fixedBonus[attribute] = 0 end
        self.fixedBonus[attribute] = self.fixedBonus[attribute] + fixed
        bonusApplied = true
    end

    if bonusApplied then
        self:invalidateStatsCache()
    end
end

--- Invalida o cache de stats, forçando recálculo na próxima chamada
function PlayerStateController:invalidateStatsCache()
    Logger.debug(
        "player_state_controller.cache.invalidate",
        "[PlayerStateController:invalidateStatsCache] Cache de estatísticas invalidado"
    )
    self.statsNeedRecalculation = true
end

--- Retorna os stats finais calculados do jogador, utilizando cache quando possível
---@return FinalStats
function PlayerStateController:getCurrentFinalStats()
    -- Retorna o cache se ele for válido
    if not self.statsNeedRecalculation and self.finalStatsCache then
        return self.finalStatsCache
    end

    Logger.debug(
        "player_state_controller.calculate",
        "[PlayerStateController:getCurrentFinalStats] Recalculando estatísticas finais..."
    )

    -- 1. Pega os stats BASE
    local baseStats = {}
    local defaultStats = Constants.HUNTER_DEFAULT_STATS
    for key, value in pairs(defaultStats) do
        baseStats[key] = self[key] or value -- Usa valor atual ou padrão
    end

    -- 2. Agrega BÔNUS (Level Up + Arquétipos + Armas)
    local totalFixedBonuses = {}
    local totalFixedFractionBonuses = {}
    local totalPercentageBonuses = {}

    -- 2a. Bônus de Level Up
    for statKey, value in pairs(self.fixedBonus or {}) do
        if self:isPercentageStat(statKey) then
            totalFixedFractionBonuses[statKey] = (totalFixedFractionBonuses[statKey] or 0) + value
        else
            totalFixedBonuses[statKey] = (totalFixedBonuses[statKey] or 0) + value
        end
    end

    for statKey, value in pairs(self.levelBonus or {}) do
        totalPercentageBonuses[statKey] = (totalPercentageBonuses[statKey] or 0) + value
    end

    -- 2b. Bônus de Arquétipos
    local hunterArchetypeIds = self.archetypeIds or {}
    if self.playerManager.hunterManager and self.playerManager.hunterManager.archetypeManager then
        for _, archIdInfo in ipairs(hunterArchetypeIds) do
            local finalArchId = type(archIdInfo) == 'table' and archIdInfo.id or archIdInfo
            local archetypeData = self.playerManager.hunterManager.archetypeManager:getArchetypeData(finalArchId)
            if archetypeData and archetypeData.modifiers then
                for _, mod in ipairs(archetypeData.modifiers) do
                    local statName = mod.stat
                    local modValue = mod.value or 0
                    if mod.type == "fixed" then
                        totalFixedBonuses[statName] = (totalFixedBonuses[statName] or 0) + modValue
                    elseif mod.type == "fixed_percentage_as_fraction" then
                        totalFixedFractionBonuses[statName] = (totalFixedFractionBonuses[statName] or 0) + modValue
                    elseif mod.type == "percentage" then
                        totalPercentageBonuses[statName] = (totalPercentageBonuses[statName] or 0) + modValue
                    end
                end
            end
        end
    end

    -- 2c. Bônus da Arma Equipada
    local weaponInstance = self.equippedItems and self.equippedItems[Constants.SLOT_IDS.WEAPON]
    if weaponInstance and weaponInstance.itemBaseId and self.playerManager.itemDataManager then
        local weaponData = self.playerManager.itemDataManager:getBaseItemData(weaponInstance.itemBaseId)
        if weaponData and weaponData.modifiers then
            for _, mod in ipairs(weaponData.modifiers) do
                local statName = mod.stat
                local modValue = mod.value or 0
                if mod.type == "fixed" then
                    totalFixedBonuses[statName] = (totalFixedBonuses[statName] or 0) + modValue
                elseif mod.type == "fixed_percentage_as_fraction" then
                    totalFixedFractionBonuses[statName] = (totalFixedFractionBonuses[statName] or 0) + modValue
                elseif mod.type == "percentage" then
                    totalPercentageBonuses[statName] = (totalPercentageBonuses[statName] or 0) + modValue
                end
            end
        end
    end

    -- 3. Calcula os Stats FINAIS aplicando bônus na ordem correta
    ---@type FinalStats
    local calculatedStats = {}
    for statKey, baseValue in pairs(baseStats) do
        if statKey ~= "weaponDamage" then
            local currentValue = baseValue

            -- Aplica Fixed
            currentValue = currentValue + (totalFixedBonuses[statKey] or 0)

            -- Aplica Fixed Fraction (Aditivo)
            currentValue = currentValue + (totalFixedFractionBonuses[statKey] or 0)

            -- Aplica Percentage
            currentValue = currentValue * (1 + (totalPercentageBonuses[statKey] or 0) / 100)
            calculatedStats[statKey] = currentValue
        end
    end

    -- 4. Calcula weaponDamage separadamente
    local baseWeaponDamage = self:calculateWeaponDamage()
    calculatedStats._baseWeaponDamage = baseWeaponDamage

    -- Calcula o multiplicador de dano final
    local damageMultiplierBase = 1.0
    local damageMultiplierFixed = totalFixedBonuses["damageMultiplier"] or 0
    local damageMultiplierFixedFraction = totalFixedFractionBonuses["damageMultiplier"] or 0
    local damageMultiplierPercentage = totalPercentageBonuses["damageMultiplier"] or 0
    local finalDamageMultiplier = (damageMultiplierBase + damageMultiplierFixed + damageMultiplierFixedFraction) *
        (1 + damageMultiplierPercentage / 100)
    calculatedStats._playerDamageMultiplier = finalDamageMultiplier
    calculatedStats.weaponDamage = math.floor(baseWeaponDamage * finalDamageMultiplier)

    -- 5. Adiciona informações adicionais
    calculatedStats._levelBonus = self.levelBonus
    calculatedStats._fixedBonus = self.fixedBonus
    calculatedStats._learnedLevelUpBonuses = self.learnedLevelUpBonuses or {}
    calculatedStats.equippedItems = self.equippedItems or {}
    calculatedStats.archetypeIds = self.archetypeIds or {}

    -- 6. Aplica clamps finais
    calculatedStats.runeSlots = math.max(0, math.floor(calculatedStats.runeSlots or 0))
    calculatedStats.luck = math.max(0, calculatedStats.luck or 0)

    -- Armazena no cache e marca como atualizado
    self.finalStatsCache = calculatedStats
    self.statsNeedRecalculation = false

    return self.finalStatsCache
end

--- Calcula o dano base da arma equipada
---@return number
function PlayerStateController:calculateWeaponDamage()
    local baseWeaponDamage = 0
    local weaponBaseId = nil

    if self.playerManager.currentHunterId and self.playerManager.hunterManager and self.equippedItems then
        local equippedHunterItems = self.playerManager.hunterManager:getEquippedItems(self.playerManager.currentHunterId)
        if equippedHunterItems then
            local weaponInstance = equippedHunterItems[Constants.SLOT_IDS.WEAPON]
            if weaponInstance and weaponInstance.itemBaseId then
                weaponBaseId = weaponInstance.itemBaseId
            end
        end
    end

    if weaponBaseId and self.playerManager.itemDataManager then
        local weaponData = self.playerManager.itemDataManager:getBaseItemData(weaponBaseId)
        if weaponData then
            baseWeaponDamage = weaponData.damage or 0
        end
    end

    return baseWeaponDamage
end

--- Verifica se um stat é do tipo percentual/fração
---@param statKey string A chave do stat
---@return boolean
function PlayerStateController:isPercentageStat(statKey)
    local percentageStats = {
        "critChance", "critDamage", "attackSpeed", "multiAttackChance",
        "range", "attackArea", "luck", "expBonus", "healingBonus", "cooldownReduction"
    }

    for _, pStat in ipairs(percentageStats) do
        if statKey == pStat then
            return true
        end
    end

    return false
end

--- Retorna todos os bônus de level up aprendidos
---@return table
function PlayerStateController:getLearnedLevelUpBonuses()
    return self.learnedLevelUpBonuses or {}
end

--- Retorna o nível atual do jogador
---@return number
function PlayerStateController:getCurrentLevel()
    return self.level
end

--- Retorna a experiência atual do jogador
---@return number
function PlayerStateController:getCurrentExperience()
    return self.experience
end

--- Força um recálculo imediato dos stats finais
---@return table
function PlayerStateController:forceRecalculation()
    Logger.debug(
        "player_state_controller.force_recalc",
        "[PlayerStateController:forceRecalculation] Forçando recálculo de estatísticas"
    )

    self.statsNeedRecalculation = true
    return self:getCurrentFinalStats()
end

--- Verifica se o cache de stats é válido
---@return boolean
function PlayerStateController:isCacheValid()
    return not self.statsNeedRecalculation and self.finalStatsCache ~= nil
end

--- Obtém informações de debug sobre o controlador
---@return table
function PlayerStateController:getDebugInfo()
    return {
        -- Estado do jogador
        level = self.level,
        experience = self.experience,
        experienceToNextLevel = self.experienceToNextLevel,
        currentHealth = self.currentHealth,
        maxHealth = self.health,
        isAlive = self.isAlive,
        kills = self.kills,
        gold = self.gold,

        -- Cache de stats
        cacheValid = self:isCacheValid(),
        needsRecalculation = self.statsNeedRecalculation,
        hasCachedStats = self.finalStatsCache ~= nil
    }
end

--- Atualiza equipamentos e invalida cache
---@param newEquippedItems table Novos itens equipados
function PlayerStateController:updateEquippedItems(newEquippedItems)
    self.equippedItems = newEquippedItems or {}
    self:invalidateStatsCache()

    Logger.debug(
        "player_state_controller.equipment.update",
        "[PlayerStateController:updateEquippedItems] Equipamentos atualizados"
    )
end

--- Atualiza arquétipos e invalida cache
---@param newArchetypeIds table Novos arquétipos ativos
function PlayerStateController:updateArchetypes(newArchetypeIds)
    self.archetypeIds = newArchetypeIds or {}
    self:invalidateStatsCache()

    Logger.debug(
        "player_state_controller.archetypes.update",
        "[PlayerStateController:updateArchetypes] Arquétipos atualizados"
    )
end

return PlayerStateController
