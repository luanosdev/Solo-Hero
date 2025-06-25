--------------------------------------------------------------------------------
-- BaseProjectileAbility
-- Classe base para habilidades que disparam projéteis.
-- Contém a lógica compartilhada de cooldown, pooling, cálculo de stats e
-- gerenciamento do ciclo de vida dos projéteis.
--------------------------------------------------------------------------------

local ManagerRegistry = require("src.managers.manager_registry")
local TablePool = require("src.utils.table_pool")
local Constants = require("src.config.constants")

---@class BaseProjectileAttack
---@field playerManager PlayerManager
---@field weaponInstance BaseWeapon
---@field projectileClass table A classe do projétil a ser instanciada (ex: Arrow, FireParticle).
---@field activeProjectiles table Lista de projéteis ativos em jogo.
---@field pooledProjectiles BaseProjectile[] Lista de projéteis inativos para reutilização.
---@field cooldownRemaining number
---@field baseDamage number
---@field baseCooldown number
---@field baseRange number
---@field baseProjectiles number
---@field basePiercing number
---@field baseKnockbackPower number
---@field baseKnockbackForce number
---@field baseProjectileScale number
---@field currentPosition table {x, y}
---@field currentAngle number
---@field finalStats table Cache dos stats finais do jogador.
---@field visual table Configurações visuais.
local BaseProjectileAttack = {}
BaseProjectileAttack.__index = BaseProjectileAttack

-- Fator de conversão para Força -> Perfuração.
-- Ex: 0.1 significa que 10 de Força = +1 de Perfuração.
local STRENGTH_TO_PIERCING_FACTOR = 0.1

--- Cria uma nova instância da habilidade base.
--- Este método deve ser chamado pelo :new da classe filha.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon
---@param projectileClass BaseProjectile A classe do projétil (ex: require("src.projectiles.arrow")).
---@return table self
function BaseProjectileAttack:new(playerManager, weaponInstance, projectileClass)
    local o = setmetatable({}, self)

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance
    o.projectileClass = projectileClass -- Classe do projétil (Arrow, FireParticle, etc)

    o.cooldownRemaining = 0
    o.activeProjectiles = {}
    o.pooledProjectiles = {}

    local baseData = o.weaponInstance:getBaseData()
    if not baseData then
        error(string.format("BaseProjectileAbility:new - Falha ao obter dados base para %s",
            o.weaponInstance.itemBaseId or "arma desconhecida"))
    end

    -- Stats base da arma
    o.baseDamage = baseData.damage or 10
    o.baseCooldown = baseData.cooldown or 1
    o.baseRange = baseData.range or 100
    o.baseProjectiles = baseData.projectiles or 1
    o.basePiercing = baseData.piercing or 0
    o.baseKnockbackPower = baseData.knockbackPower or 0
    o.baseKnockbackForce = baseData.knockbackForce or 0
    o.baseProjectileScale = baseData.projectileScale or 1

    -- Configurações visuais
    o.visual = {
        preview = {
            active = false,
        },
        attack = {
            color = weaponInstance.attackColor or { 1, 1, 1, 1 },
            -- Velocidade do projétil pode ser um atributo da arma ou da habilidade
            projectileSpeed = baseData.projectileSpeed or 300,
        }
    }

    o.currentPosition = { x = 0, y = 0 }
    o.currentAngle = 0
    o.finalStats = {}

    return o
end

--- Atualiza o estado da habilidade e dos projéteis.
---@param dt number Delta time.
---@param angle number Ângulo atual (da mira).
function BaseProjectileAttack:update(dt, angle)
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição e ângulo
    if self.playerManager then
        self.currentPosition = self.playerManager:getPlayerPosition()
    else
        return -- Impede atualização se não há jogador
    end
    self.currentAngle = angle

    -- Cache dos stats para uso no frame
    self.finalStats = self.playerManager:getCurrentFinalStats()
    if not self.finalStats then
        return -- Impede atualização se não há stats
    end

    -- Atualiza projéteis ativos e os move para o pool quando inativos
    for i = #self.activeProjectiles, 1, -1 do
        local projectile = self.activeProjectiles[i]
        projectile:update(dt)
        if not projectile.isActive then
            table.remove(self.activeProjectiles, i)
            table.insert(self.pooledProjectiles, projectile)
        end
    end
end

--- Lógica principal de disparo, a ser chamada pelas subclasses.
--- As subclasses devem implementar o método :cast e chamar este.
---@param args table Argumentos de disparo, como `angle`.
function BaseProjectileAttack:cast(args)
    -- Lógica de cooldown
    if self.cooldownRemaining > 0 then
        return false, "cooldown"
    end

    local totalAttackSpeed = self.finalStats.attackSpeed or 1
    if totalAttackSpeed <= 0 then totalAttackSpeed = 0.01 end
    self.cooldownRemaining = (self.baseCooldown or 1) / totalAttackSpeed

    return true, "fired"
end

--- Dispara um único projétil.
-- Este é um método auxiliar para ser usado pelas subclasses.
---@param fireAngle number O ângulo exato para este disparo.
function BaseProjectileAttack:_fireSingleProjectile(fireAngle)
    local stats = self.finalStats
    if not stats then
        print("AVISO [BaseProjectile:_fireSingleProjectile]: finalStats não disponíveis.")
        return
    end

    -- Dano
    local damage = stats.weaponDamage or self.baseDamage
    local isCritical = math.random() <= (stats.critChance or 0)
    if isCritical then
        damage = math.floor(damage * (stats.critDamage or 1.5))
    end

    -- Alcance
    local range = self.baseRange * (stats.range or 1)

    -- Tamanho/Área
    local scale = self.baseProjectileScale * (stats.attackArea or 1)

    -- Perfuração
    local strengthBonusPiercing = math.floor((stats.strength or 0) * STRENGTH_TO_PIERCING_FACTOR)
    local piercing = (self.basePiercing or 0) + strengthBonusPiercing

    local enemyManager = ManagerRegistry:get("enemyManager")
    local spatialGrid = enemyManager and enemyManager.spatialGrid

    local projectile = nil
    local params = TablePool.get()
    params.x = self.currentPosition.x
    params.y = self.currentPosition.y
    params.angle = fireAngle
    params.speed = self.visual.attack.projectileSpeed
    params.range = range
    params.damage = damage
    params.isCritical = isCritical
    params.spatialGrid = spatialGrid
    params.color = self.visual.attack.color
    params.piercing = piercing
    params.areaScale = scale
    params.knockbackPower = self.baseKnockbackPower
    params.knockbackForce = self.baseKnockbackForce
    params.playerStrength = stats.strength
    params.playerManager = self.playerManager
    params.weaponInstance = self.weaponInstance
    params.owner = self.playerManager:getPlayerSprite()
    params.hitCost = Constants.HIT_COST.BULLET

    if #self.pooledProjectiles > 0 then
        -- Reutiliza um projétil do pool
        ---@type BaseProjectile
        projectile = table.remove(self.pooledProjectiles)
        projectile:reset(params)
    else
        -- Cria um novo projétil se o pool estiver vazio
        projectile = self.projectileClass:new(params)
    end

    table.insert(self.activeProjectiles, projectile)
    TablePool.release(params)
end

--- Calcula o número total de projéteis com base nos stats.
---@return number O número total de projéteis a serem disparados.
function BaseProjectileAttack:_getTotalProjectiles()
    if not self.finalStats then return self.baseProjectiles end

    local multiAttackValue = self.finalStats.multiAttack or 0

    -- A parte inteira do multiAttack é o número de projéteis extras garantidos.
    local multiAttackBonus = math.floor(multiAttackValue)

    -- A parte fracionária é a chance de disparar um projétil a mais.
    local fractionalChance = multiAttackValue - multiAttackBonus
    if fractionalChance > 0 and math.random() < fractionalChance then
        multiAttackBonus = multiAttackBonus + 1
    end

    return self.baseProjectiles + multiAttackBonus
end

function BaseProjectileAttack:draw()
    -- Desenha a prévia (agora uma linha de range inicial)
    if self.visual.preview.active then
        self:drawPreviewLine(self.visual.preview.color)
        -- Poderia desenhar um círculo menor para o jumpRange também
    end

    for _, projectiles in ipairs(self.activeProjectiles) do
        projectiles:draw()
    end
end

function BaseProjectileAttack:drawPreviewLine(color)
    love.graphics.setColor(color)
    -- Desenha uma linha do jogador na direção da mira com o comprimento do range atual
    local startX, startY = self.currentPosition.x, self.currentPosition.y
    local endX = startX + math.cos(self.currentAngle) * self.baseRange
    local endY = startY + math.sin(self.currentAngle) * self.baseRange
    love.graphics.line(startX, startY, endX, endY)
end

return BaseProjectileAttack
