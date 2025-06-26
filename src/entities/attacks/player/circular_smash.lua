----------------------------------------------------------------------------
-- Circular Smash V2 (Otimizado)
-- Versão super otimizada usando a nova arquitetura BaseAttackAbility.
-- Performance máxima com área crescente e sistemas unificados.
----------------------------------------------------------------------------

local BaseAttackAbility = require("src.entities.attacks.base_attack_ability")
local AttackAnimationSystem = require("src.utils.attack_animation_system")
local MultiAttackCalculator = require("src.utils.multi_attack_calculator")
local CombatHelpers = require("src.utils.combat_helpers")

---@class CircularSmashVisualAttack
---@field animationDuration number
---@field color table


---@class CircularSmash : BaseAttackAbility
---@field isAttacking boolean Se está executando animação
---@field attackProgress number Progresso da animação atual (0-1)
---@field targetPos Vector2D Posição alvo do ataque
---@field currentAttackRadius number Raio do ataque atual
---@field impactDistance number Distância de impacto calculada
---@field explosionRadius number Raio de explosão calculado
local CircularSmash = setmetatable({}, { __index = BaseAttackAbility })
CircularSmash.__index = CircularSmash

-- Configurações otimizadas
local CONFIG = {
    name = "Esmagamento Circular V2",
    description = "Versão otimizada que golpeia o chão causando dano em área crescente.",
    damageType = "melee",
    attackType = "area",
    visual = {
        preview = {
            active = false,
            color = { 0.7, 0.7, 0.7, 0.2 }
        },
        attack = {
            animationDuration = 0.3,
            color = { 0.8, 0.8, 0.7, 0.8 }
        }
    },
    constants = {
        AREA_GROWTH_RATE = 0.20 -- 20% de crescimento por ataque extra
    }
}

--- Cria nova instância otimizada
---@param playerManager PlayerManager
---@param weaponInstance CircularSmashWeapon
---@return CircularSmash
function CircularSmash:new(playerManager, weaponInstance)
    ---@type CircularSmash
    local o = BaseAttackAbility.new(self, playerManager, weaponInstance, CONFIG)
    setmetatable(o, self)

    -- Estado específico
    o.isAttacking = false
    o.attackProgress = 0
    o.targetPos = { x = 0, y = 0 }
    o.currentAttackRadius = 0

    -- Valores calculados (atualizados em onStatsUpdated)
    o.impactDistance = o.cachedBaseData.baseAreaEffectRadius
    o.explosionRadius = o.cachedBaseData.baseAreaEffectRadius

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
function CircularSmash:onStatsUpdated()
    local baseRadius = self.cachedBaseData.baseAreaEffectRadius
    local areaMultiplier = self.cachedStats.attackArea

    self.impactDistance = baseRadius * areaMultiplier
    self.explosionRadius = baseRadius * areaMultiplier
end

--- Update específico otimizado
---@param dt number Delta time
---@param angle number Ângulo atual
function CircularSmash:updateSpecific(dt, angle)
    -- Atualiza animação se ativa
    if self.isAttacking then
        self.attackProgress = self.attackProgress + (dt / CONFIG.visual.attack.animationDuration)
        if self.attackProgress >= 1 then
            self.isAttacking = false
            self.attackProgress = 0
            self.currentAttackRadius = 0
        end
    end
end

--- Cast específico super otimizado
---@param args table Argumentos do cast
---@return boolean success
function CircularSmash:castSpecific(args)
    local angle = args and args.angle or self.currentAngle

    -- Calcula posição do impacto
    self.targetPos.x = self.playerPosition.x + math.cos(angle) * self.impactDistance
    self.targetPos.y = self.playerPosition.y + math.sin(angle) * self.impactDistance

    -- Inicia animação
    self.isAttacking = true
    self.attackProgress = 0

    -- Calcula multi-attacks com área crescente
    local multiResult = MultiAttackCalculator.calculateAreaGrowth(
        self.cachedStats.multiAttackChance,
        self.cachedStats.range,
        love.timer.getTime()
    )

    local attackInstances = {}
    self.enemiesKnockedBackInThisCast = {}

    -- Executa todos os ataques com raios progressivos
    for i = 1, multiResult.totalAttacks do
        local radiusMultiplier = multiResult.progressiveMultipliers[i]
        self.currentAttackRadius = self.explosionRadius * radiusMultiplier

        -- Executa ataque
        local enemies = CombatHelpers.findEnemiesInCircularAreaOptimized(
            self.targetPos,
            self.currentAttackRadius,
            self.playerManager:getPlayerSprite()
        )
        if #enemies > 0 then
            table.insert(attackInstances, {
                enemies = enemies,
                knockbackData = {
                    power = self.knockbackData.power,
                    force = self.knockbackData.force,
                    attackerPosition = self.targetPos -- Usa posição do impacto
                }
            })
        end
    end

    -- Aplica efeitos em lote (mais eficiente)
    if #attackInstances > 0 then
        CombatHelpers.applyBatchHitEffects(
            attackInstances,
            self.cachedStats,
            self.playerManager,
            self.weaponInstance
        )
    end

    return true
end

--- Executa ataque otimizado
---@return BaseEnemy[] enemies Lista de inimigos atingidos
function CircularSmash:executeAttackOptimized()
    if not self.currentAttackRadius or self.currentAttackRadius <= 0 then
        return {}
    end

    -- Usa função otimizada com cache
    local enemies = CombatHelpers.findEnemiesInCircularAreaOptimized(
        self.targetPos,
        self.currentAttackRadius,
        self.playerManager:getPlayerSprite()
    )

    return enemies
end

--- Desenho otimizado
function CircularSmash:draw()
    if not self.playerPosition then return end

    -- Preview otimizado
    if self.visual.preview.active then
        self:drawPreviewOptimized()
    end

    -- Animação do ataque
    if self.isAttacking then
        self:drawAttackAnimationOptimized()
    end
end

--- Desenho de preview otimizado
function CircularSmash:drawPreviewOptimized()
    local previewX = self.playerPosition.x + math.cos(self.currentAngle) * self.impactDistance
    local previewY = self.playerPosition.y + math.sin(self.currentAngle) * self.impactDistance

    love.graphics.setColor(self.visual.preview.color)
    love.graphics.circle("line", previewX, previewY, self.explosionRadius, 32)
    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenho de animação otimizado
function CircularSmash:drawAttackAnimationOptimized()
    if not self.currentAttackRadius or self.currentAttackRadius <= 0 then return end

    local currentRadius = self.currentAttackRadius * self.attackProgress
    local alpha = (self.visual.attack.color[4] or 0.8) * (1 - self.attackProgress ^ 2)
    local thickness = 3 * (1 - self.attackProgress) + 1

    if currentRadius > 1 and alpha > 0.05 then
        local color = self.visual.attack.color
        love.graphics.setColor(color[1], color[2], color[3], alpha)
        love.graphics.setLineWidth(thickness)
        love.graphics.circle("line", self.targetPos.x, self.targetPos.y, currentRadius, 48)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

--- Função de debug para performance
function CircularSmash:getDebugInfo()
    return {
        ability = {
            cooldown = self:getCooldownRemaining(),
            isAttacking = self.isAttacking,
            attackProgress = self.attackProgress,
            currentRadius = self.currentAttackRadius,
            impactDistance = self.impactDistance,
            explosionRadius = self.explosionRadius
        },
        combatHelpers = CombatHelpers.getPerformanceInfo(),
        multiAttackCalc = MultiAttackCalculator.getCacheInfo()
    }
end

return CircularSmash
