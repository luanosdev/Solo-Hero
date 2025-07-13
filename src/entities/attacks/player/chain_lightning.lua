----------------------------------------------------------------------------
-- Chain Lightning V2 (Otimizado)
-- Versão super otimizada usando a nova arquitetura BaseAttackAbility.
-- Performance máxima com cache, pooling e sistemas unificados.
----------------------------------------------------------------------------

local BaseAttackAbility = require("src.entities.attacks.base_attack_ability")
local MultiAttackCalculator = require("src.utils.multi_attack_calculator")
local CombatHelpers = require("src.utils.combat_helpers")
local TablePool = require("src.utils.table_pool")
local Constants = require("src.config.constants")

---@class ChainLightningVisualAttack
---@field segmentDuration number
---@field thickness number
---@field color table

---@class ChainLightning : BaseAttackAbility
---@field activeChains table[] Correntes de raio ativas
---@field currentRange number Alcance atual calculado
---@field currentThickness number Espessura atual calculada
---@field jumpRangeDecay number Fator de decaimento por salto
local ChainLightning = setmetatable({}, { __index = BaseAttackAbility })
ChainLightning.__index = ChainLightning

-- Configurações otimizadas
local CONFIG = {
    name = "Corrente Elétrica",
    description = "Atinge um inimigo e salta para outros próximos.",
    damageType = "lightning",
    attackType = "ranged",
    visual = {
        preview = {
            active = false,
            color = { 0.2, 0.8, 1, 0.2 }
        },
        attack = {
            segmentDuration = 0.15,
            thickness = 3,
            color = { 0.5, 1, 1, 0.9 }
        }
    },
    constants = {
        JUMP_RANGE_DECAY = 0.85,
        RANGE_MULTIPLIER_EFFECT = 1.0,
        MULTI_ATTACK_BONUS_WEIGHT = 0.50,
        STRENGTH_BONUS_WEIGHT = 0.25
    }
}

--- Cria uma nova instância da habilidade ChainLightning.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon
---@return ChainLightning
function ChainLightning:new(playerManager, weaponInstance)
    ---@type ChainLightning
    local o = BaseAttackAbility.new(self, playerManager, weaponInstance, CONFIG)
    setmetatable(o, self)

    -- Estado específico
    o.activeChains = {}
    o.currentRange = Constants.metersToPixels(o.cachedBaseData.range)
    o.currentThickness = CONFIG.visual.attack.thickness
    o.jumpRangeDecay = CONFIG.constants.JUMP_RANGE_DECAY

    -- Cores da weaponInstance
    if weaponInstance.previewColor then
        o.visual.preview.color = weaponInstance.previewColor
    end
    if weaponInstance.attackColor then
        o.visual.attack.color = weaponInstance.attackColor
    end

    return o
end

--- Hook para atualização quando stats mudam
function ChainLightning:onStatsUpdated()
    local stats = self.cachedStats
    local baseData = self.cachedBaseData

    -- Recalcula valores baseados nos stats
    self.currentRange = Constants.metersToPixels(baseData.range) * stats.range
    self.currentThickness = CONFIG.visual.attack.thickness * stats.attackArea
end

--- Update específico otimizado
---@param dt number Delta time
---@param angle number Ângulo atual
function ChainLightning:updateSpecific(dt, angle)
    -- Atualiza correntes ativas
    for i = #self.activeChains, 1, -1 do
        local chain = self.activeChains[i]
        chain.duration = chain.duration - dt
        if chain.duration <= 0 then
            table.remove(self.activeChains, i)
        end
    end
end

--- Cast específico super otimizado
---@param args table Argumentos do cast
---@return boolean success
function ChainLightning:castSpecific(args)
    -- Calcula posição de spawn com offset do raio do player
    local spawnPos = self:calculateSpawnPosition(self.currentAngle)

    local chainCount = self.cachedStats._baseBonuses["chainCount"] or 0
    local baseChainCount = self.cachedBaseData.chainCount

    -- Calcula correntes usando calculadora unificada
    local multiResult = MultiAttackCalculator.calculateChains(
        baseChainCount + chainCount,
        self.cachedStats,
        love.timer.getTime()
    )

    -- Busca primeiro alvo usando otimizações
    local firstTarget = self:findFirstTargetOptimized(spawnPos)
    if not firstTarget then
        -- Ainda dispara raio no vazio se não houver alvo
        self:createMissedChain(spawnPos)
        return true
    end

    -- Executa cadeia de raios otimizada
    local hitPositions = { { x = spawnPos.x, y = spawnPos.y } }
    local excludedIDs = TablePool.getArray()
    local targetsHit = TablePool.getArray() -- Array simples ao invés de mapa

    -- Primeiro alvo - com validação adicional
    if firstTarget and firstTarget.position and firstTarget.id and firstTarget.isAlive then
        table.insert(hitPositions, { x = firstTarget.position.x, y = firstTarget.position.y })
        table.insert(targetsHit, firstTarget) -- Adiciona o inimigo diretamente
        excludedIDs[firstTarget.id] = true
    else
        Logger.warn(
            "chain_lightning.cast.invalid_first_target",
            "[ChainLightning:castSpecific] Primeiro alvo encontrado é inválido"
        )
        self:createMissedChain(spawnPos)
        TablePool.releaseArray(excludedIDs)
        TablePool.releaseArray(targetsHit)
        return true
    end

    -- Aplica knockback no primeiro alvo
    if self.knockbackData.power > 0 then
        CombatHelpers.applyKnockback(
            firstTarget,
            spawnPos, -- Usa spawn position
            self.knockbackData.power,
            self.knockbackData.force,
            self.cachedStats.strength,
            nil
        )
    end

    -- Processa saltos subsequentes
    local currentTarget = firstTarget
    local successfulJumps = 0
    local maxJumps = multiResult.totalAttacks

    while currentTarget and successfulJumps < maxJumps do
        local nextTarget = self:findNextTargetOptimized(
            currentTarget.position,
            successfulJumps,
            excludedIDs
        )

        if nextTarget and nextTarget.position and nextTarget.id and nextTarget.isAlive then
            table.insert(hitPositions, { x = nextTarget.position.x, y = nextTarget.position.y })
            table.insert(targetsHit, nextTarget) -- Adiciona o inimigo diretamente
            excludedIDs[nextTarget.id] = true
            successfulJumps = successfulJumps + 1

            -- Aplica knockback
            if self.knockbackData.power > 0 then
                CombatHelpers.applyKnockback(
                    nextTarget,
                    currentTarget.position,
                    self.knockbackData.power,
                    self.knockbackData.force,
                    self.cachedStats.strength,
                    nil
                )
            end

            currentTarget = nextTarget
        else
            -- Inválido ou não encontrado, para a cadeia
            if nextTarget then
                Logger.warn(
                    "chain_lightning.cast.invalid_next_target",
                    "[ChainLightning:castSpecific] Próximo alvo encontrado é inválido"
                )
            end
            break
        end
    end

    -- Aplica dano em lote
    self:applyChainDamageOptimized(targetsHit)

    -- Cria efeito visual
    if #hitPositions > 1 then
        table.insert(self.activeChains, {
            points = hitPositions,
            duration = CONFIG.visual.attack.segmentDuration,
            color = self.visual.attack.color,
            thickness = self.currentThickness
        })
    end

    -- Libera recursos
    TablePool.releaseArray(excludedIDs)
    TablePool.releaseArray(targetsHit)

    return true
end

--- Encontra primeiro alvo otimizado
---@param spawnPos Vector2D Posição de spawn
---@return BaseEnemy|nil
function ChainLightning:findFirstTargetOptimized(spawnPos)
    local endX = spawnPos.x + math.cos(self.currentAngle) * self.currentRange
    local endY = spawnPos.y + math.sin(self.currentAngle) * self.currentRange

    -- Usa CombatHelpers otimizado para busca
    local lineArea = {
        startPosition = spawnPos,
        endPosition = { x = endX, y = endY },
        width = self.currentThickness
    }

    local enemies = CombatHelpers.findEnemiesInLineAreaOptimized(
        lineArea,
        self.playerManager:getPlayerSprite()
    )

    -- Retorna o mais próximo válido
    if #enemies > 0 then
        for _, enemy in ipairs(enemies) do
            if enemy and enemy.id and enemy.isAlive then
                return enemy -- Retorna o primeiro inimigo válido
            end
        end
    end

    return nil
end

--- Encontra próximo alvo na corrente
---@param currentPos Vector2D Posição atual
---@param jumpIndex number Índice do salto
---@param excludedIDs table IDs excluídos
---@return BaseEnemy|nil
function ChainLightning:findNextTargetOptimized(currentPos, jumpIndex, excludedIDs)
    local baseJumpRange = self.cachedBaseData.jumpRange
    local jumpRange = self.cachedStats._baseBonuses["jumpRange"] or 0

    local decayedRange = (baseJumpRange + jumpRange) * (self.jumpRangeDecay ^ jumpIndex)
    local finalRange = decayedRange * (self.cachedStats.attackArea or 1)

    -- Usa CombatHelpers otimizado
    local enemies = CombatHelpers.findEnemiesInCircularAreaOptimized(
        currentPos,
        finalRange,
        self.playerManager:getPlayerSprite()
    )

    -- Filtra excluídos e retorna o mais próximo
    for _, enemy in ipairs(enemies) do
        if enemy and enemy.id and enemy.isAlive and not excludedIDs[enemy.id] then
            return enemy
        end
    end

    return nil
end

--- Aplica dano em lote otimizado
---@param targetsHit BaseEnemy[] Array de alvos atingidos
function ChainLightning:applyChainDamageOptimized(targetsHit)
    local function applyDamageToTarget(target)
        -- Validação robusta: verifica se target é um objeto válido com as propriedades necessárias
        if not target or type(target) ~= "table" or not target.isAlive or not target.takeDamage then
            Logger.warn(
                "chain_lightning.apply_damage.invalid_target",
                string.format("[ChainLightning:applyDamageToTarget] Target inválido: %s", tostring(target))
            )
            return false
        end

        local stats = self.cachedStats

        -- Calcula dano com crítico usando nova mecânica de Super Crítico
        local critChance = stats.critChance
        local critBonus = stats.critDamage - 1 -- Converte multiplicador para bônus
        local finalDamage, isCritical, isSuperCritical, critStacks = CombatHelpers.calculateSuperCriticalDamage(
            stats.damage,
            critChance,
            critBonus
        )

        target:takeDamage(finalDamage, isCritical, isSuperCritical)

        -- Registra dano para estatísticas
        if self.playerManager and self.playerManager.registerDamageDealt then
            local source = { weaponId = self.weaponInstance and self.weaponInstance.itemBaseId }
            self.playerManager:registerDamageDealt(finalDamage, isCritical, source, isSuperCritical)
        end

        -- Aplica knockback
        if self.knockbackData.power > 0 then
            CombatHelpers.applyKnockback(
                target,
                self.knockbackData.attackerPosition,
                self.knockbackData.power,
                self.knockbackData.force,
                self.cachedStats.strength,
                nil
            )
        end

        return true
    end

    -- Itera sobre o array de inimigos com validação adicional
    if not targetsHit or type(targetsHit) ~= "table" then
        Logger.warn(
            "chain_lightning.apply_damage.invalid_targets_array",
            "[ChainLightning:applyChainDamageOptimized] Array de alvos inválido"
        )
        return
    end

    for i, enemy in ipairs(targetsHit) do
        if enemy then -- Validação básica antes de chamar applyDamageToTarget
            applyDamageToTarget(enemy)
        else
            Logger.warn(
                "chain_lightning.apply_damage.null_enemy",
                string.format("[ChainLightning:applyChainDamageOptimized] Inimigo nulo encontrado no índice %d", i)
            )
        end
    end
end

--- Cria corrente que não atingiu nada
---@param spawnPos Vector2D Posição de spawn
function ChainLightning:createMissedChain(spawnPos)
    local endX = spawnPos.x + math.cos(self.currentAngle) * self.currentRange
    local endY = spawnPos.y + math.sin(self.currentAngle) * self.currentRange

    local hitPositions = {
        { x = spawnPos.x, y = spawnPos.y },
        { x = endX,       y = endY }
    }

    table.insert(self.activeChains, {
        points = hitPositions,
        duration = CONFIG.visual.attack.segmentDuration,
        color = self.visual.attack.color,
        thickness = self.currentThickness
    })
end

function ChainLightning:draw()
    if self.visual.preview.active then
        self:drawPreviewOptimized()
    end

    -- Desenha correntes ativas
    for _, chain in ipairs(self.activeChains) do
        love.graphics.setColor(chain.color)
        love.graphics.setLineWidth(chain.thickness)

        -- Desenha linhas da corrente
        for i = 1, #chain.points - 1 do
            local p1 = chain.points[i]
            local p2 = chain.points[i + 1]
            love.graphics.line(p1.x, p1.y, p2.x, p2.y)
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

--- Debug info para performance
function ChainLightning:getDebugInfo()
    return {
        ability = {
            cooldown = self:getCooldownRemaining(),
            activeChains = #self.activeChains,
            currentRange = self.currentRange,
            currentThickness = self.currentThickness
        },
        combatHelpers = CombatHelpers.getPerformanceInfo(),
        multiAttackCalc = MultiAttackCalculator.getCacheInfo()
    }
end

return ChainLightning
