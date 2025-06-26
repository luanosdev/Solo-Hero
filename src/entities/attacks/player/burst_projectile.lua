----------------------------------------------------------------------------
-- Burst Projectile
-- Atira múltiplos projéteis em um ângulo de dispersão.
----------------------------------------------------------------------------

local BaseAttackAbility = require("src.entities.attacks.base_attack_ability")
local MultiAttackCalculator = require("src.utils.multi_attack_calculator")
local ManagerRegistry = require("src.managers.manager_registry")
local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

---@class BurstProjectileVisualAttack
---@field projectileSpeed number
---@field color table

---@class BurstProjectile : BaseAttackAbility
---@field activeProjectiles BaseProjectile[] Projéteis ativos
---@field pooledProjectiles BaseProjectile[] Pool de projéteis reutilizáveis
---@field projectileClass table Classe do projétil
---@field currentSpreadAngle number Ângulo de dispersão calculado
local BurstProjectile = setmetatable({}, { __index = BaseAttackAbility })
BurstProjectile.__index = BurstProjectile

-- Configurações otimizadas
local CONFIG = {
    name = "Rajada de Projéteis V2",
    description = "Versão otimizada que dispara múltiplos projéteis em leque.",
    damageType = "ranged",
    attackType = "ranged",
    visual = {
        preview = {
            active = false,
            color = { 0.7, 0.7, 0.7, 0.2 }
        },
        attack = {
            projectileSpeed = 300,
            color = { 1, 1, 1, 1 }
        }
    },
    constants = {
        STRENGTH_TO_PIERCING_FACTOR = 0.1
    }
}

--- Cria nova instância otimizada
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon
---@return BurstProjectile
function BurstProjectile:new(playerManager, weaponInstance)
    ---@type BurstProjectile
    local o = BaseAttackAbility.new(self, playerManager, weaponInstance, CONFIG)
    setmetatable(o, self)

    -- Estado específico
    o.activeProjectiles = {}
    o.pooledProjectiles = {}
    o.currentSpreadAngle = o.cachedBaseData.angle

    -- Carrega classe do projétil
    local projectileClassPath = "src.entities.projectiles." .. weaponInstance:getBaseData().projectileClass
    o.projectileClass = require(projectileClassPath)

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
function BurstProjectile:onStatsUpdated()
    -- Recalcula ângulo de dispersão baseado em attackArea
    local baseAngle = self.cachedBaseData.angle
    self.currentSpreadAngle = baseAngle * self.cachedStats.attackArea
end

--- Update específico otimizado
---@param dt number Delta time
---@param angle number Ângulo atual
function BurstProjectile:updateSpecific(dt, angle)
    -- Atualiza projéteis ativos usando pool
    for i = #self.activeProjectiles, 1, -1 do
        local projectile = self.activeProjectiles[i]
        projectile:update(dt)
        if not projectile.isActive then
            table.remove(self.activeProjectiles, i)
            table.insert(self.pooledProjectiles, projectile) -- Move para pool
        end
    end
end

--- Cast específico super otimizado
---@param args table Argumentos do cast
---@return boolean success
function BurstProjectile:castSpecific(args)
    -- Calcula projéteis usando calculadora unificada
    local multiResult = MultiAttackCalculator.calculateProjectiles(
        self.cachedBaseData.projectiles,
        self.cachedStats.multiAttackChance,
        love.timer.getTime()
    )

    -- Calcula ângulos de dispersão
    local projectileAngles = self:calculateProjectileAnglesOptimized(multiResult.totalProjectiles)

    -- Obtém SpatialGrid uma vez
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid
    if not spatialGrid then
        error("BurstProjectile:castSpecific SpatialGrid não encontrado")
    end

    -- Dispara todos os projéteis
    for _, projectileAngle in ipairs(projectileAngles) do
        self:fireSingleProjectileOptimized(projectileAngle, spatialGrid)
    end

    return true
end

--- Calcula ângulos de projéteis otimizado
---@param totalProjectiles number Número total de projéteis
---@return number[] Lista de ângulos
function BurstProjectile:calculateProjectileAnglesOptimized(totalProjectiles)
    local angles = {}

    if totalProjectiles == 1 then
        table.insert(angles, self.currentAngle)
    else
        local angleStep = self.currentSpreadAngle / (totalProjectiles - 1)
        local startAngle = self.currentAngle - self.currentSpreadAngle / 2

        for i = 0, totalProjectiles - 1 do
            table.insert(angles, startAngle + i * angleStep)
        end
    end

    return angles
end

--- Dispara um projétil otimizado
---@param projectileAngle number Ângulo do projétil
---@param spatialGrid table SpatialGrid para colisões
function BurstProjectile:fireSingleProjectileOptimized(projectileAngle, spatialGrid)
    local stats = self.cachedStats
    local baseData = self.cachedBaseData

    -- Calcula dano com crítico usando nova mecânica de Super Crítico
    local critChance = stats.critChance
    local critBonus = stats.critDamage - 1 -- Converte multiplicador para bônus
    local finalDamage, isCritical, isSuperCritical, critStacks = CombatHelpers.calculateSuperCriticalDamage(
        stats.weaponDamage,
        critChance,
        critBonus
    )

    -- Calcula perfuração
    local strengthBonusPiercing = math.floor((stats.strength or 0) * CONFIG.constants.STRENGTH_TO_PIERCING_FACTOR)
    local currentPiercing = (baseData.piercing or 0) + strengthBonusPiercing

    -- Calcula alcance e escala
    local currentRange = baseData.range * (stats.range or 1)
    local areaScale = stats.attackArea or 1

    -- Calcula posição de spawn com offset do raio do player
    local spawnPos = self:calculateSpawnPosition(projectileAngle)

    -- Prepara parâmetros usando pool
    local params = TablePool.getGeneric()
    params.x = spawnPos.x
    params.y = spawnPos.y
    params.angle = projectileAngle
    params.speed = CONFIG.visual.attack.projectileSpeed
    params.range = currentRange
    params.damage = finalDamage
    params.isCritical = isCritical
    params.isSuperCritical = isSuperCritical
    params.critStacks = critStacks
    params.spatialGrid = spatialGrid
    params.color = self.visual.attack.color
    params.piercing = currentPiercing
    params.areaScale = areaScale
    params.knockbackPower = self.knockbackData.power
    params.knockbackForce = self.knockbackData.force
    params.playerStrength = stats.strength
    params.playerManager = self.playerManager
    params.weaponInstance = self.weaponInstance
    params.owner = self.playerManager:getPlayerSprite()
    params.hitCost = Constants.HIT_COST.BULLET

    -- Usa pool de projéteis
    local projectile
    if #self.pooledProjectiles > 0 then
        projectile = table.remove(self.pooledProjectiles)
        projectile:reset(params)
    else
        projectile = self.projectileClass:new(params)
    end

    table.insert(self.activeProjectiles, projectile)
    TablePool.releaseGeneric(params)
end

--- Desenho otimizado
function BurstProjectile:draw()
    -- Preview otimizado
    if self.visual.preview.active then
        self:drawPreviewOptimized()
    end

    -- Desenha projéteis ativos
    for _, projectile in ipairs(self.activeProjectiles) do
        projectile:draw()
    end
end

--- Debug info para performance
function BurstProjectile:getDebugInfo()
    return {
        ability = {
            cooldown = self:getCooldownRemaining(),
            activeProjectiles = #self.activeProjectiles,
            pooledProjectiles = #self.pooledProjectiles,
            spreadAngle = math.deg(self.currentSpreadAngle)
        },
        multiAttackCalc = MultiAttackCalculator.getCacheInfo()
    }
end

return BurstProjectile
