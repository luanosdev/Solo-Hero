-------------------------------------------------------------------------
-- Controlador unificado para estado e estatísticas do jogador.
-- Integra gerenciamento de estado, cálculo de stats e progressão.
-- Sistema de atributos baseado no modelo do Halls of Torment:
-- Final Stat = (Base Stat + Base Bonus) × (100% + Multiplier Bonus)
-------------------------------------------------------------------------

local Constants = require("src.config.constants")

---@class BaseBonus Bônus base (flat) aplicados ao stat base
---@field maxHealth number Bônus base de vida (flat)
---@field damage number Bônus base de dano (flat)
---@field defense number Bônus base de defesa (flat)
---@field moveSpeed number Bônus base de velocidade de movimento (flat)
---@field attackSpeed number Bônus base de velocidade de ataque (flat)
---@field critChance number Bônus base de chance crítica (flat)
---@field critDamage number Bônus base de dano crítico (flat)
---@field healthRegen number Bônus base de regeneração de vida (flat)
---@field multiAttackChance number Bônus base de chance de ataque múltiplo (flat)
---@field strength number Bônus base de força (flat)
---@field expBonus number Bônus base de experiência (flat)
---@field healingBonus number Bônus base de cura recebida (flat)
---@field pickupRadius number Bônus base de raio de coleta (flat)
---@field healthRegenDelay number Bônus base de atraso de regeneração (flat)
---@field range number Bônus base de alcance (flat)
---@field luck number Bônus base de sorte (flat)
---@field attackArea number Bônus base de área de ataque (flat)
---@field healthPerTick number Bônus base de vida por tick (flat)
---@field cooldownReduction number Bônus base de redução de cooldown (flat)
---@field healthRegenCooldown number Bônus base de cooldown de regeneração (flat)
---@field dashCharges number Bônus base de cargas de dash (flat)
---@field dashCooldown number Bônus base de cooldown de dash (flat)
---@field dashDistance number Bônus base de distância de dash (flat)
---@field dashDuration number Bônus base de duração de dash (flat)
---@field potionFlasks number Bônus base de frascos de poção (flat)
---@field potionHealAmount number Bônus base de cura por poção (flat)
---@field potionFillRate number Bônus base de velocidade de preenchimento (flat)

---@class MultiplierBonus Bônus multiplicadores (%) aplicados ao stat base
---@field maxHealth number Bônus multiplicador de vida (%)
---@field damage number Bônus multiplicador de dano (%)
---@field defense number Bônus multiplicador de defesa (%)
---@field moveSpeed number Bônus multiplicador de velocidade de movimento (%)
---@field attackSpeed number Bônus multiplicador de velocidade de ataque (%)
---@field critChance number Bônus multiplicador de chance crítica (%)
---@field critDamage number Bônus multiplicador de dano crítico (%)
---@field healthRegen number Bônus multiplicador de regeneração de vida (%)
---@field multiAttackChance number Bônus multiplicador de chance de ataque múltiplo (%)
---@field strength number Bônus multiplicador de força (%)
---@field expBonus number Bônus multiplicador de experiência (%)
---@field healingBonus number Bônus multiplicador de cura recebida (%)
---@field pickupRadius number Bônus multiplicador de raio de coleta (%)
---@field healthRegenDelay number Bônus multiplicador de atraso de regeneração (%)
---@field range number Bônus multiplicador de alcance (%)
---@field luck number Bônus multiplicador de sorte (%)
---@field attackArea number Bônus multiplicador de área de ataque (%)
---@field healthPerTick number Bônus multiplicador de vida por tick (%)
---@field cooldownReduction number Bônus multiplicador de redução de cooldown (%)
---@field healthRegenCooldown number Bônus multiplicador de cooldown de regeneração (%)
---@field dashCharges number Bônus multiplicador de cargas de dash (%)
---@field dashCooldown number Bônus multiplicador de cooldown de dash (%)
---@field dashDistance number Bônus multiplicador de distância de dash (%)
---@field dashDuration number Bônus multiplicador de duração de dash (%)
---@field potionFlasks number Bônus multiplicador de frascos de poção (%)
---@field potionHealAmount number Bônus multiplicador de cura por poção (%)
---@field potionFillRate number Bônus multiplicador de velocidade de preenchimento (%)

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
---@field maxHealth number Vida máxima final
---@field damage number Dano final
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
---@field _baseBonuses BaseBonus Bônus base (para referência)
---@field _multiplierBonuses MultiplierBonus Bônus multiplicadores (para referência)
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
---@field damage number Dano base do jogador
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
---@field baseBonuses BaseBonus Bônus base (flat) de todas as fontes
---@field multiplierBonuses MultiplierBonus Bônus multiplicadores (%) de todas as fontes
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

    -- Inicializa sistema de bônus
    instance.baseBonuses = {}
    instance.multiplierBonuses = {}

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
    self.maxHealth = initialStats and initialStats.maxHealth or defaultStats.maxHealth
    self.damage = 0 -- Caçador começa com 0 de dano base
    self.defense = initialStats and initialStats.defense or defaultStats.defense
    self.moveSpeed = initialStats and initialStats.moveSpeed or defaultStats.moveSpeed
    self.attackSpeed = initialStats and initialStats.attackSpeed or defaultStats.attackSpeed
    self.critChance = initialStats and initialStats.critChance or defaultStats.critChance
    self.critDamage = initialStats and initialStats.critDamage or defaultStats.critDamage
    self.healthRegen = initialStats and initialStats.healthRegen or defaultStats.healthRegen
    self.multiAttackChance = initialStats and initialStats.multiAttackChance or defaultStats.multiAttackChance
    self.runeSlots = initialStats and initialStats.runeSlots or defaultStats.runeSlots
    self.strength = initialStats and initialStats.strength or defaultStats.strength

    -- Atributos adicionais
    self.expBonus = initialStats and initialStats.expBonus or defaultStats.expBonus
    self.healingBonus = initialStats and initialStats.healingBonus or defaultStats.healingBonus
    self.pickupRadius = initialStats and initialStats.pickupRadius or defaultStats.pickupRadius
    self.healthRegenDelay = initialStats and initialStats.healthRegenDelay or defaultStats.healthRegenDelay
    self.range = initialStats and initialStats.range or defaultStats.range
    self.luck = initialStats and initialStats.luck or defaultStats.luck
    self.attackArea = initialStats and initialStats.attackArea or defaultStats.attackArea
    self.healthPerTick = initialStats and initialStats.healthPerTick or defaultStats.healthPerTick
    self.cooldownReduction = initialStats and initialStats.cooldownReduction or defaultStats.cooldownReduction
    self.healthRegenCooldown = initialStats and initialStats.healthRegenCooldown or defaultStats.healthRegenCooldown

    -- Atributos de dash
    self.dashCharges = initialStats and initialStats.dashCharges or defaultStats.dashCharges
    self.dashCooldown = initialStats and initialStats.dashCooldown or defaultStats.dashCooldown
    self.dashDistance = initialStats and initialStats.dashDistance or defaultStats.dashDistance
    self.dashDuration = initialStats and initialStats.dashDuration or defaultStats.dashDuration

    -- Atributos de poções
    self.potionFlasks = initialStats and initialStats.potionFlasks or defaultStats.potionFlasks
    self.potionHealAmount = initialStats and initialStats.potionHealAmount or defaultStats.potionHealAmount
    self.potionFillRate = initialStats and initialStats.potionFillRate or defaultStats.potionFillRate

    -- Inicializa estruturas de dados
    self.statusModifiers = {}
    self.learnedLevelUpBonuses = {}
    self.equippedItems = initialStats and initialStats.equippedItems or {}
    self.archetypeIds = initialStats and initialStats.archetypeIds or {}

    -- Inicializa vida atual
    self.currentHealth = self.maxHealth

    Logger.info(
        "player_state_controller.init",
        string.format("[PlayerStateController:initializeBaseStats] Estado inicializado. HP: %.1f/%.1f",
            self.currentHealth, self.maxHealth)
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
    self.currentHealth = math.floor(math.min(self.currentHealth + effectiveAmount, finalStats.maxHealth))

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

--- Adiciona bônus base (flat) a um atributo
---@param attribute StatKey Nome do atributo
---@param amount number Valor do bônus base
function PlayerStateController:addBaseBonus(attribute, amount)
    if not self.baseBonuses[attribute] then
        self.baseBonuses[attribute] = 0
    end

    self.baseBonuses[attribute] = self.baseBonuses[attribute] + amount

    if attribute == "maxHealth" then
        self:heal(amount)
    end

    self:invalidateStatsCache()

    Logger.debug(
        "player_state_controller.bonus.base",
        string.format("[PlayerStateController:addBaseBonus] +%.2f %s (base)", amount, attribute)
    )
end

--- Adiciona bônus multiplicador (%) a um atributo
---@param attribute StatKey Nome do atributo
---@param percentage number Valor do bônus em porcentagem (ex: 25 para +25%)
function PlayerStateController:addMultiplierBonus(attribute, percentage)
    if not self.multiplierBonuses[attribute] then
        self.multiplierBonuses[attribute] = 0
    end
    self.multiplierBonuses[attribute] = self.multiplierBonuses[attribute] + percentage

    self:invalidateStatsCache()

    if attribute == "maxHealth" then
        -- calcula o valor a ser curado com base na porcentagem
        local effectiveAmount = self.maxHealth * (percentage / 100)
        self:heal(effectiveAmount)
    end

    Logger.debug(
        "player_state_controller.bonus.multiplier",
        string.format("[PlayerStateController:addMultiplierBonus] +%.2f%% %s (multiplier)", percentage, attribute)
    )
end

--- Método compatível com o sistema anterior (deprecated)
---@param attribute StatKey Nome do atributo
---@param percentage number Porcentagem de bônus (se > 0)
---@param fixed number Valor fixo (se > 0)
function PlayerStateController:addAttributeBonus(attribute, percentage, fixed)
    Logger.warn(
        "player_state_controller.deprecated",
        "[PlayerStateController:addAttributeBonus] Método depreciado. Use addBaseBonus() ou addMultiplierBonus()"
    )

    if fixed and fixed ~= 0 then
        self:addBaseBonus(attribute, fixed)
    end

    if percentage and percentage ~= 0 then
        self:addMultiplierBonus(attribute, percentage)
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

--- Retorna os stats finais calculados usando a fórmula do Halls of Torment
--- Formula: Final Stat = (Base Stat + Base Bonus) × (100% + Multiplier Bonus)
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

    -- 1. Coleta todos os bônus de todas as fontes
    local allBaseBonuses = {}
    local allMultiplierBonuses = {}

    -- Copia os bônus aplicados diretamente
    for stat, value in pairs(self.baseBonuses) do
        allBaseBonuses[stat] = (allBaseBonuses[stat]) + value
    end

    for stat, value in pairs(self.multiplierBonuses) do
        allMultiplierBonuses[stat] = (allMultiplierBonuses[stat]) + value
    end

    -- 2. Bônus de Arquétipos
    local hunterArchetypeIds = self.archetypeIds or {}
    if self.playerManager.hunterManager and self.playerManager.hunterManager.archetypeManager then
        for _, archIdInfo in ipairs(hunterArchetypeIds) do
            local finalArchId = type(archIdInfo) == 'table' and archIdInfo.id or archIdInfo
            local archetypeData = self.playerManager.hunterManager.archetypeManager:getArchetypeData(finalArchId)
            if archetypeData and archetypeData.modifiers then
                for _, mod in ipairs(archetypeData.modifiers) do
                    local statName = mod.stat
                    local modValue = mod.value or 0

                    if mod.type == "base" then
                        allBaseBonuses[statName] = (allBaseBonuses[statName] or 0) + modValue
                    elseif mod.type == "percentage" then
                        allMultiplierBonuses[statName] = (allMultiplierBonuses[statName] or 0) + modValue
                    else
                        error(string.format("Invalid modifier type: %s", mod.type))
                    end
                end
            end
        end
    end

    -- 3. Bônus da Arma Equipada
    local weaponInstance = self.equippedItems and self.equippedItems[Constants.SLOT_IDS.WEAPON]
    if weaponInstance and weaponInstance.itemBaseId and self.playerManager.itemDataManager then
        local weaponData = self.playerManager.itemDataManager:getBaseItemData(weaponInstance.itemBaseId)
        if weaponData then
            allBaseBonuses["damage"] = (allBaseBonuses["damage"] or 0) + weaponData.damage
            if weaponData.modifiers then
                for _, mod in ipairs(weaponData.modifiers) do
                    local statName = mod.stat
                    local modValue = mod.value or 0

                    if mod.type == "base" then
                        allBaseBonuses[statName] = (allBaseBonuses[statName] or 0) + modValue
                    elseif mod.type == "percentage" then
                        allMultiplierBonuses[statName] = (allMultiplierBonuses[statName] or 0) + modValue
                    else
                        error(string.format("Invalid modifier type: %s %s", mod.type, statName))
                    end
                end
            end
        end
    end

    -- 4. Aplica a fórmula do Halls of Torment: Final Stat = (Base Stat + Base Bonus) × (100% + Multiplier Bonus)
    ---@type FinalStats
    local calculatedStats = {}

    -- Lista de todos os stats possíveis
    local allStats = {
        "maxHealth", "damage", "defense", "moveSpeed", "attackSpeed", "critChance", "critDamage",
        "healthRegen", "multiAttackChance", "runeSlots", "strength", "expBonus",
        "healingBonus", "pickupRadius", "healthRegenDelay", "range", "luck",
        "attackArea", "healthPerTick", "cooldownReduction", "healthRegenCooldown",
        "dashCharges", "dashCooldown", "dashDistance", "dashDuration",
        "potionFlasks", "potionHealAmount", "potionFillRate"
    }

    for _, statName in ipairs(allStats) do
        local baseStat = self[statName] or 0
        local baseBonus = allBaseBonuses[statName] or 0
        local multiplierBonus = allMultiplierBonuses[statName] or 0

        -- Fórmula: Final Stat = (Base Stat + Base Bonus) × (100% + Multiplier Bonus)
        local finalStat = (baseStat + baseBonus) * (1 + multiplierBonus / 100)
        calculatedStats[statName] = finalStat
    end

    -- 5. Adiciona informações adicionais
    calculatedStats._baseBonuses = allBaseBonuses
    calculatedStats._multiplierBonuses = allMultiplierBonuses
    calculatedStats._learnedLevelUpBonuses = self.learnedLevelUpBonuses or {}
    calculatedStats.equippedItems = self.equippedItems or {}
    calculatedStats.archetypeIds = self.archetypeIds or {}

    -- 6. Aplica clamps finais
    calculatedStats.runeSlots = math.max(0, math.floor(calculatedStats.runeSlots))
    calculatedStats.dashCharges = math.max(0, math.floor(calculatedStats.dashCharges))
    calculatedStats.potionFlasks = math.max(0, math.floor(calculatedStats.potionFlasks))

    -- Armazena no cache e marca como atualizado
    self.finalStatsCache = calculatedStats
    self.statsNeedRecalculation = false

    Logger.debug(
        "player_state_controller.calculate.complete",
        "[PlayerStateController:getCurrentFinalStats] Atualização de stats concluída"
    )

    return self.finalStatsCache
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

--- Retorna o dano final calculado do jogador
---@return number
function PlayerStateController:getCurrentDamage()
    return self:getCurrentFinalStats().damage
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
        maxHealth = self.maxHealth,
        isAlive = self.isAlive,
        kills = self.kills,
        gold = self.gold,

        -- Sistema de bônus
        baseBonuses = self.baseBonuses,
        multiplierBonuses = self.multiplierBonuses,

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

--- Limpa todos os bônus aplicados
function PlayerStateController:clearAllBonuses()
    self.baseBonuses = {}
    self.multiplierBonuses = {}
    self:invalidateStatsCache()

    Logger.debug(
        "player_state_controller.bonus.clear",
        "[PlayerStateController:clearAllBonuses] Todos os bônus foram limpos"
    )
end

--- Retorna os bônus base atuais
---@return BaseBonus
function PlayerStateController:getBaseBonuses()
    return self.baseBonuses or {}
end

--- Retorna os bônus multiplicadores atuais
---@return MultiplierBonus
function PlayerStateController:getMultiplierBonuses()
    return self.multiplierBonuses or {}
end

return PlayerStateController
