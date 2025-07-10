----------------------------------------------------------------------------
-- Arrow Projectile V2 (Otimizado)
-- Versão super otimizada usando a nova arquitetura BaseAttackAbility.
-- Performance máxima com pooling, cache e sistemas unificados.
----------------------------------------------------------------------------

local BaseAttackAbility = require("src.entities.attacks.base_attack_ability")
local MultiAttackCalculator = require("src.utils.multi_attack_calculator")
local Arrow = require("src.entities.projectiles.arrow")
local ManagerRegistry = require("src.managers.manager_registry")
local Constants = require("src.config.constants")
local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

---@class ArrowProjectileVisualAttack
---@field arrowSpeed number
---@field maxTotalSpreadAngle number
---@field color table

---@class ArrowProjectile : BaseAttackAbility
---@field activeArrows Arrow[] Flechas ativas
---@field pooledArrows Arrow[] Pool de flechas reutilizáveis
---@field currentSpreadAngle number Ângulo de dispersão calculado
local ArrowProjectile = setmetatable({}, { __index = BaseAttackAbility })
ArrowProjectile.__index = ArrowProjectile

-- Configurações otimizadas
local CONFIG = {
    name = "Flecha",
    description = "Atira flechas em um ângulo e alcance específicos.",
    damageType = "melee",
    attackType = "ranged",
    visual = {
        preview = {
            active = false,
            color = { 0.7, 0.7, 0.7, 0.2 }
        },
        attack = {
            arrowSpeed = 600,
            maxTotalSpreadAngle = math.rad(20),
            color = { 0.2, 0.8, 0.2, 0.7 }
        }
    },
    constants = {
        STRENGTH_TO_PIERCING_FACTOR = 0.1
    }
}

--- Cria uma nova instância da habilidade ArrowProjectile.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon
---@return ArrowProjectile
function ArrowProjectile:new(playerManager, weaponInstance)
    ---@type ArrowProjectile
    local o = BaseAttackAbility.new(self, playerManager, weaponInstance, CONFIG)
    setmetatable(o, self)

    -- Estado específico
    o.activeArrows = {}
    o.pooledArrows = {}
    o.currentSpreadAngle = o.cachedBaseData.angle or CONFIG.visual.attack.maxTotalSpreadAngle

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
function ArrowProjectile:onStatsUpdated()
    -- Recalcula ângulo de dispersão baseado em attackArea
    local baseAngle = self.cachedBaseData.angle or CONFIG.visual.attack.maxTotalSpreadAngle
    self.currentSpreadAngle = baseAngle * (self.cachedStats.attackArea or 1)
end

--- Update específico otimizado
---@param dt number Delta time
---@param angle number Ângulo atual
function ArrowProjectile:updateSpecific(dt, angle)
    -- Atualiza flechas ativas usando pool
    for i = #self.activeArrows, 1, -1 do
        local arrow = self.activeArrows[i]
        arrow:update(dt)
        if not arrow.isActive then
            table.remove(self.activeArrows, i)
            table.insert(self.pooledArrows, arrow) -- Move para pool
        end
    end
end

--- Cast específico super otimizado
---@param args table Argumentos do cast
---@return boolean success
function ArrowProjectile:castSpecific(args)
    -- Calcula projéteis usando calculadora unificada
    local multiResult = MultiAttackCalculator.calculateProjectiles(
        self.cachedBaseData.projectiles or 1,
        self.cachedStats.multiAttackChance,
        love.timer.getTime()
    )

    -- Calcula ângulos de dispersão
    local arrowAngles = self:calculateArrowAnglesOptimized(multiResult.totalAttacks)

    -- Obtém SpatialGrid uma vez
    ---@type EnemyManager
    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager.spatialGrid

    if not spatialGrid then
        error("ArrowProjectile:castSpecific SpatialGrid não encontrado")
    end

    -- Dispara todas as flechas
    for _, arrowAngle in ipairs(arrowAngles) do
        self:fireSingleArrowOptimized(arrowAngle, spatialGrid)
    end

    return true
end

--- Calcula ângulos de flechas otimizado
---@param totalArrows number Número total de flechas
---@return number[] Lista de ângulos
function ArrowProjectile:calculateArrowAnglesOptimized(totalArrows)
    local angles = {}

    if totalArrows == 1 then
        table.insert(angles, self.currentAngle)
    else
        local angleStep = self.currentSpreadAngle / (totalArrows - 1)
        local startAngleOffset = -self.currentSpreadAngle / 2

        for i = 0, totalArrows - 1 do
            table.insert(angles, self.currentAngle + startAngleOffset + (i * angleStep))
        end
    end

    return angles
end

--- Dispara uma flecha otimizada
---@param arrowAngle number Ângulo da flecha
---@param spatialGrid SpatialGridIncremental SpatialGrid para colisões
function ArrowProjectile:fireSingleArrowOptimized(arrowAngle, spatialGrid)
    local stats = self.cachedStats

    -- Calcula dano com crítico usando nova mecânica de Super Crítico
    local critChance = stats.critChance
    local critBonus = stats.critDamage - 1 -- Converte multiplicador para bônus
    local finalDamage, isCritical, isSuperCritical, critStacks = CombatHelpers.calculateSuperCriticalDamage(
        stats.damage,
        critChance,
        critBonus
    )

    -- Calcula perfuração
    local strengthBonusPiercing = math.floor(stats.strength * CONFIG.constants.STRENGTH_TO_PIERCING_FACTOR)
    local currentPiercing = self.cachedBaseData.piercing + strengthBonusPiercing

    -- Calcula alcance e escala
    local currentRange = Constants.metersToPixels(self.cachedBaseData.range) * stats.range
    local areaScale = stats.attackArea or 1

    -- Calcula posição de spawn com offset do raio do player
    local spawnPos = self:calculateSpawnPosition(arrowAngle)

    -- Prepara parâmetros usando pool
    local params = TablePool.getGeneric()
    params.x = spawnPos.x
    params.y = spawnPos.y
    params.angle = arrowAngle
    params.speed = CONFIG.visual.attack.arrowSpeed
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
    params.hitCost = Constants.HIT_COST.ARROW

    -- Usa pool de flechas
    local arrow
    if #self.pooledArrows > 0 then
        arrow = table.remove(self.pooledArrows)
        arrow:reset(params)
    else
        arrow = Arrow:new(params)
    end

    table.insert(self.activeArrows, arrow)
    TablePool.releaseGeneric(params)
end

--- Desenho otimizado
function ArrowProjectile:draw()
    -- Preview otimizado
    if self.visual.preview.active then
        self:drawPreviewOptimized()
    end

    -- Desenha flechas ativas
    for _, arrow in ipairs(self.activeArrows) do
        arrow:draw()
    end
end

--- Debug info para performance
function ArrowProjectile:getDebugInfo()
    return {
        ability = {
            cooldown = self:getCooldownRemaining(),
            activeArrows = #self.activeArrows,
            pooledArrows = #self.pooledArrows,
            spreadAngle = math.deg(self.currentSpreadAngle)
        },
        multiAttackCalc = MultiAttackCalculator.getCacheInfo()
    }
end

return ArrowProjectile
