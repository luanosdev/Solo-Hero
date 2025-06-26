----------------------------------------------------------------------------
-- Flame Stream V2 (Otimizado)
-- Versão super otimizada usando a nova arquitetura BaseAttackAbility.
-- Performance máxima com pooling, cache e sistemas unificados.
----------------------------------------------------------------------------

local BaseAttackAbility = require("src.entities.attacks.base_attack_ability")
local MultiAttackCalculator = require("src.utils.multi_attack_calculator")
local FireParticle = require("src.entities.projectiles.fire_particle")
local ManagerRegistry = require("src.managers.manager_registry")
local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")
local Constants = require("src.config.constants")

---@class FlameStreamVisualAttack
---@field particleSpeed number
---@field particleLifetime number
---@field baseScale number
---@field color table

---@class FlameStream : BaseAttackAbility
---@field activeParticles FireParticle[] Partículas ativas
---@field pooledParticles FireParticle[] Pool de partículas reutilizáveis
---@field currentLifetime number Tempo de vida atual calculado
---@field currentAreaMultiplier number Multiplicador de área atual
local FlameStream = setmetatable({}, { __index = BaseAttackAbility })
FlameStream.__index = FlameStream

-- Configurações otimizadas
local CONFIG = {
    name = "Fluxo de Fogo",
    description = "Atira um fluxo de chamas em área.",
    damageType = "fire",
    attackType = "ranged",
    visual = {
        preview = {
            active = false,
            color = { 1, 0.5, 0, 0.2 }
        },
        attack = {
            particleSpeed = 150,
            particleLifetime = 1.2,
            baseScale = 0.8,
            color = { 1, 0.3, 0, 0.7 }
        },
        multiAttack = {
            angleSpread = 5,
            colors = {
                { 0.2, 0.8, 1,   0.7 }, -- Azul
                { 0.2, 1,   0.2, 0.7 }, -- Verde
                { 1,   1,   1,   0.7 }  -- Branco
            }
        }
    },
    constants = {
        BASE_HIT_LOSS = 0.5,
        PIERCING_REDUCTION_FACTOR = 0.1,
        MIN_HIT_LOSS = 0.2,
        STRENGTH_LIFETIME_FACTOR = 0.1,
        BASE_LIFETIME = 2
    }
}

--- Cria nova instância otimizada
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon
---@return FlameStream
function FlameStream:new(playerManager, weaponInstance)
    ---@type FlameStream
    local o = BaseAttackAbility.new(self, playerManager, weaponInstance, CONFIG)
    setmetatable(o, self)

    -- Estado específico
    o.activeParticles = {}
    o.pooledParticles = {}
    o.currentLifetime = o.cachedBaseData.baseLifetime or CONFIG.visual.attack.particleLifetime
    o.currentAreaMultiplier = 1.0

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
function FlameStream:onStatsUpdated()
    local stats = self.cachedStats
    local baseData = self.cachedBaseData

    -- Recalcula lifetime baseado no alcance e força
    local baseLifetime = baseData.range * stats.range / CONFIG.visual.attack.particleSpeed
    local strengthMultiplier = 1 + (stats.strength * CONFIG.constants.STRENGTH_LIFETIME_FACTOR)
    self.currentLifetime = baseLifetime * strengthMultiplier

    -- Atualiza multiplicador de área
    self.currentAreaMultiplier = stats.attackArea
end

--- Update específico otimizado
---@param dt number Delta time
---@param angle number Ângulo atual
function FlameStream:updateSpecific(dt, angle)
    -- Atualiza partículas ativas usando pool
    for i = #self.activeParticles, 1, -1 do
        local particle = self.activeParticles[i]
        particle:update(dt)
        if not particle.isActive then
            table.remove(self.activeParticles, i)
            table.insert(self.pooledParticles, particle) -- Move para pool
        end
    end
end

--- Cast específico super otimizado
---@param args table Argumentos do cast
---@return boolean success
function FlameStream:castSpecific(args)
    -- Calcula multi-attack para determinar número de partículas
    local multiAttackCount = math.floor(self.cachedStats.multiAttackChance)
    local numParticles = 1 + multiAttackCount

    -- Obtém SpatialGrid uma vez
    ---@type EnemyManager
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid

    if not spatialGrid then
        error("FlameStream:castSpecific SpatialGrid não encontrado")
    end

    -- Dispara todas as partículas
    for i = 1, numParticles do
        self:fireSingleParticleOptimized(i, spatialGrid)
    end

    return true
end

--- Dispara uma partícula otimizada
---@param particleIndex number Índice da partícula (1 = principal)
---@param spatialGrid table SpatialGrid para colisões
function FlameStream:fireSingleParticleOptimized(particleIndex, spatialGrid)
    local stats = self.cachedStats
    local baseData = self.cachedBaseData

    -- Calcula ângulo com dispersão
    local particleAngle = self.currentAngle
    local particleColor = self.visual.attack.color

    if particleIndex > 1 then
        -- Partículas extras têm dispersão angular
        local spreadDirection = (particleIndex % 2 == 0) and 1 or -1
        local spreadMagnitude = math.ceil((particleIndex - 1) / 2)
        local angleOffset = math.rad(CONFIG.visual.multiAttack.angleSpread * spreadMagnitude * spreadDirection)
        particleAngle = particleAngle + angleOffset

        -- Cor alternativa para partículas extras
        local colorIndex = ((particleIndex - 2) % #CONFIG.visual.multiAttack.colors) + 1
        particleColor = CONFIG.visual.multiAttack.colors[colorIndex] or self.visual.attack.color
    else
        -- Partícula principal tem pequena dispersão aleatória
        local halfWidth = (baseData.angle) / 2
        local randomOffset = (math.random() - 0.5) * halfWidth
        particleAngle = particleAngle + randomOffset
    end

    -- Calcula dano com crítico usando nova mecânica de Super Crítico
    local critChance = stats.critChance
    local critBonus = stats.critDamage - 1 -- Converte multiplicador para bônus
    local finalDamage, isCritical, isSuperCritical, critStacks = CombatHelpers.calculateSuperCriticalDamage(
        stats.weaponDamage,
        critChance,
        critBonus
    )

    -- Calcula lifetime baseado no alcance e força
    local baseLifetime = baseData.baseLifetime or CONFIG.constants.BASE_LIFETIME
    local strengthMultiplier = 1 + (stats.strength / 100)
    local rangeMultiplier = stats.range
    local finalLifetime = baseLifetime * strengthMultiplier * rangeMultiplier

    -- Escala das partículas
    local particleScale = (baseData.particleScale) * (stats.attackArea)

    -- Calcula posição de spawn com offset do raio do player
    local spawnPos = self:calculateSpawnPosition(particleAngle)

    -- Prepara parâmetros usando TablePool
    local params = TablePool.getGeneric()
    params.x = spawnPos.x
    params.y = spawnPos.y
    params.angle = particleAngle
    params.speed = CONFIG.visual.attack.particleSpeed
    params.lifetime = finalLifetime
    params.damage = finalDamage
    params.isCritical = isCritical
    params.isSuperCritical = isSuperCritical
    params.critStacks = critStacks
    params.scale = particleScale
    params.color = particleColor
    params.knockbackPower = self.knockbackData.power
    params.knockbackForce = self.knockbackData.force
    params.playerStrength = stats.strength
    params.playerManager = self.playerManager
    params.weaponInstance = self.weaponInstance
    params.owner = self.playerManager:getPlayerSprite()
    params.hitCost = Constants.HIT_COST.FIRE_PARTICLE
    params.piercing = 0 -- Fire particles não têm perfuração
    params.spatialGrid = spatialGrid
    params.baseHitLoss = CONFIG.constants.BASE_HIT_LOSS
    params.piercingReductionFactor = CONFIG.constants.PIERCING_REDUCTION_FACTOR
    params.minHitLoss = CONFIG.constants.MIN_HIT_LOSS

    -- Usa pool de partículas
    local particle
    if #self.pooledParticles > 0 then
        particle = table.remove(self.pooledParticles)
        particle:reset(params)
    else
        particle = FireParticle:new(params)
    end

    table.insert(self.activeParticles, particle)
    TablePool.releaseGeneric(params)
end

--- Desenho otimizado
function FlameStream:draw()
    -- Preview otimizado
    if self.visual.preview.active then
        self:drawPreviewOptimized()
    end

    -- Desenha partículas ativas
    for _, particle in ipairs(self.activeParticles) do
        particle:draw()
    end
end

--- Debug info para performance
function FlameStream:getDebugInfo()
    return {
        ability = {
            cooldown = self:getCooldownRemaining(),
            activeParticles = #self.activeParticles,
            pooledParticles = #self.pooledParticles,
            currentLifetime = self.currentLifetime,
            currentAreaMultiplier = self.currentAreaMultiplier
        },
        multiAttackCalc = MultiAttackCalculator.getCacheInfo()
    }
end

return FlameStream
