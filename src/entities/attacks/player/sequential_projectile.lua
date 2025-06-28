----------------------------------------------------------------------------
-- Sequential Projectile
-- Atira múltiplos projéteis em sequência.
----------------------------------------------------------------------------

local BaseAttackAbility = require("src.entities.attacks.base_attack_ability")
local MultiAttackCalculator = require("src.utils.multi_attack_calculator")
local ManagerRegistry = require("src.managers.manager_registry")
local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

---@class SequentialProjectileVisualAttack
---@field projectileSpeed number
---@field color table

---@class SequentialProjectile : BaseAttackAbility
---@field activeProjectiles BaseProjectile[] Projéteis ativos
---@field pooledProjectiles BaseProjectile[] Pool de projéteis reutilizáveis
---@field projectileClass table Classe do projétil
---@field isSequenceActive boolean Se uma sequência está ativa
---@field projectilesLeftInSequence number Projéteis restantes na sequência
---@field timeToNextShot number Timer para próximo disparo
---@field sequenceCadence number Tempo entre disparos
local SequentialProjectile = setmetatable({}, { __index = BaseAttackAbility })
SequentialProjectile.__index = SequentialProjectile

-- Configurações otimizadas
local CONFIG = {
    name = "Disparo Sequencial V2",
    description = "Versão otimizada que dispara múltiplos projéteis em sequência.",
    damageType = "ranged",
    attackType = "ranged",
    visual = {
        preview = {
            active = false,
            color = { 0.7, 0.7, 0.7, 0.2 }
        },
        attack = {
            projectileSpeed = 500,
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
---@return SequentialProjectile
function SequentialProjectile:new(playerManager, weaponInstance)
    ---@type SequentialProjectile
    local o = BaseAttackAbility.new(self, playerManager, weaponInstance, CONFIG)
    setmetatable(o, self)

    -- Estado específico
    o.activeProjectiles = {}
    o.pooledProjectiles = {}
    o.isSequenceActive = false
    o.projectilesLeftInSequence = 0
    o.timeToNextShot = 0
    o.sequenceCadence = o.cachedBaseData.cadence

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

--- Update específico otimizado
---@param dt number Delta time
---@param angle number Ângulo atual
function SequentialProjectile:updateSpecific(dt, angle)
    -- Atualiza projéteis ativos usando pool
    for i = #self.activeProjectiles, 1, -1 do
        local projectile = self.activeProjectiles[i]
        projectile:update(dt)
        if not projectile.isActive then
            table.remove(self.activeProjectiles, i)
            table.insert(self.pooledProjectiles, projectile) -- Move para pool
        end
    end

    -- Gerencia sequência ativa
    if self.isSequenceActive then
        self.timeToNextShot = self.timeToNextShot - dt

        if self.timeToNextShot <= 0 then
            if self.projectilesLeftInSequence > 0 then
                ---@type EnemyManager
                local enemyManager = ManagerRegistry:get("enemyManager")
                local spatialGrid = enemyManager.spatialGrid
                if not spatialGrid then
                    error("SequentialProjectile:updateSpecific SpatialGrid não encontrado")
                end

                -- Dispara projétil na direção atual da mira
                self:fireSingleProjectileOptimized(self.currentAngle, spatialGrid)
                self.projectilesLeftInSequence = self.projectilesLeftInSequence - 1
                self.timeToNextShot = self.sequenceCadence
            else
                -- Termina sequência
                self.isSequenceActive = false
            end
        end
    end
end

--- Cast específico super otimizado
---@param args table Argumentos do cast
---@return boolean success
function SequentialProjectile:castSpecific(args)
    -- Não pode iniciar nova sequência se outra já estiver ativa
    if self.isSequenceActive then
        return false
    end

    -- Calcula projéteis usando calculadora unificada
    local multiResult = MultiAttackCalculator.calculateProjectiles(
        self.cachedBaseData.projectiles,
        self.cachedStats.multiAttackChance,
        love.timer.getTime()
    )

    -- Inicia sequência
    self.isSequenceActive = true
    self.projectilesLeftInSequence = multiResult.totalAttacks
    self.timeToNextShot = 0 -- Primeiro tiro é imediato

    return true
end

--- Dispara um projétil otimizado
---@param projectileAngle number Ângulo do projétil
---@param spatialGrid SpatialGridIncremental
function SequentialProjectile:fireSingleProjectileOptimized(projectileAngle, spatialGrid)
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
    local strengthBonusPiercing = math.floor(stats.strength * CONFIG.constants.STRENGTH_TO_PIERCING_FACTOR)
    local currentPiercing = baseData.piercing + strengthBonusPiercing

    -- Calcula alcance e escala
    local currentRange = baseData.range * stats.range
    local areaScale = stats.attackArea

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
function SequentialProjectile:draw()
    -- Preview otimizado
    if self.visual.preview.active then
        self:drawPreviewOptimized()
    end

    -- Desenha projéteis ativos
    for _, projectile in ipairs(self.activeProjectiles) do
        projectile:draw()
    end
end

--- Preview otimizado simples
function SequentialProjectile:drawPreviewOptimized()
    if not self.playerPosition then return end

    love.graphics.setColor(self.visual.preview.color)

    local cx, cy = self.playerPosition.x, self.playerPosition.y
    local range = (self.cachedBaseData.range * self.cachedStats.range) / 2

    -- Linha simples na direção da mira
    local endX = cx + math.cos(self.currentAngle) * range
    local endY = cy + math.sin(self.currentAngle) * range
    love.graphics.line(cx, cy, endX, endY)

    love.graphics.setColor(1, 1, 1, 1)
end

--- Debug info para performance
function SequentialProjectile:getDebugInfo()
    return {
        ability = {
            cooldown = self:getCooldownRemaining(),
            activeProjectiles = #self.activeProjectiles,
            pooledProjectiles = #self.pooledProjectiles,
            isSequenceActive = self.isSequenceActive,
            projectilesLeft = self.projectilesLeftInSequence,
            timeToNext = self.timeToNextShot
        },
        multiAttackCalc = MultiAttackCalculator.getCacheInfo()
    }
end

return SequentialProjectile
