--------------------------------------------------------------------------------
-- Base Projectile
-- Uma classe base para todos os projéteis do jogo.
-- Contém lógica comum para movimento, colisão, dano e tempo de vida.
-- As classes de projéteis específicas devem herdar desta.
--------------------------------------------------------------------------------

local CombatHelpers = require("src.utils.combat_helpers")
local TablePool = require("src.utils.table_pool")

---@class BaseProjectile
---@field position { x: number, y: number } Posição atual do projétil.
---@field angle number Ângulo de movimento em radianos.
---@field speed number Velocidade de movimento.
---@field velocity { x: number, y: number } Vetor de velocidade.
---@field damage number Dano causado por acerto.
---@field isCritical boolean Se o acerto é crítico.
---@field color table {r,g,b,a} Cor do projétil.
---@field isActive boolean Se o projétil está ativo no jogo.
---@field spatialGrid SpatialGridIncremental Referência ao grid espacial para otimização.
---@field playerManager PlayerManager Referência ao gerenciador do jogador.
---@field weaponInstance BaseWeapon Instância da arma que disparou o projétil.
---@field knockbackPower number Poder de knockback.
---@field knockbackForce number Força de knockback.
---@field playerStrength number Força do jogador para cálculos de knockback.
---@field hitEnemies table Tabela para rastrear inimigos já atingidos.
---@field owner any A entidade que disparou o projétil (opcional).
---@field durability number Durabilidade atual do projétil (1.0 a 0.0).
---@field hitCost number Custo de durabilidade ao atingir um inimigo (0.0 a 1.0).
---@field piercing number Poder de perfuração que reduz o custo do hit.
local BaseProjectile = {}
BaseProjectile.__index = BaseProjectile

--- Inicializa uma nova instância de projétil base.
-- As subclasses devem chamar este método.
---@param params table Tabela de parâmetros de configuração.
function BaseProjectile:new(params)
    -- O metatable deve ser definido na subclasse para garantir a herança correta.
    self:reset(params)
    return self
end

--- Reseta um projétil para reutilização (object pooling).
---@param params table Tabela de parâmetros de configuração.
---@param params.x number
---@param params.y number
---@param params.angle number
---@param params.speed number
---@param params.damage number
---@param params.isCritical boolean
---@param params.spatialGrid SpatialGridIncremental
---@param params.color table {r, g, b, a}
---@param params.knockbackPower number
---@param params.knockbackForce number
---@param params.playerStrength number
---@param params.playerManager PlayerManager
---@param params.weaponInstance BaseWeapon
---@param params.owner any
---@param params.hitCost number
---@param params.piercing number
function BaseProjectile:reset(params)
    self.position = self.position or { x = 0, y = 0 }
    self.position.x = params.x
    self.position.y = params.y
    self.angle = params.angle
    self.speed = params.speed
    self.damage = params.damage
    self.isCritical = params.isCritical
    self.spatialGrid = params.spatialGrid
    self.color = params.color or { 1, 1, 1, 1 }

    self.knockbackPower = params.knockbackPower or 0
    self.knockbackForce = params.knockbackForce or 0
    self.playerStrength = params.playerStrength or 0
    self.playerManager = params.playerManager
    self.weaponInstance = params.weaponInstance
    self.owner = params.owner

    self.velocity = self.velocity or { x = 0, y = 0 }
    self.velocity.x = math.cos(self.angle) * self.speed
    self.velocity.y = math.sin(self.angle) * self.speed

    self.isActive = true
    self.hitEnemies = self.hitEnemies or {}
    for k in pairs(self.hitEnemies) do self.hitEnemies[k] = nil end

    self.durability = 1.0
    self.hitCost = params.hitCost or 0.34
    self.piercing = params.piercing or 0
end

--- Atualiza o estado do projétil a cada frame.
---@param dt number O tempo delta desde o último frame.
function BaseProjectile:update(dt)
    if not self.isActive then return end

    local moveX = self.velocity.x * dt
    local moveY = self.velocity.y * dt
    self.position.x = self.position.x + moveX
    self.position.y = self.position.y + moveY

    -- Hook para a lógica de tempo de vida da subclasse
    self:_updateLifetime(dt, moveX, moveY)

    if not self.isActive then return end

    -- A verificação de colisão agora é um método modelo
    self:checkCollision()
end

--- Hook para que as subclasses implementem sua própria lógica de tempo de vida.
-- Ex: baseado em distância (maxRange) ou tempo (lifetime).
---@param dt number
---@param moveX number
---@param moveY number
function BaseProjectile:_updateLifetime(dt, moveX, moveY)
    Logger.error("[BaseProjectile:_updateLifetime]", "Subclasse deve implementar _updateLifetime()")
    -- A subclasse deve sobrescrever este método se tiver um tempo de vida.
    -- Por padrão, não faz nada (projéteis infinitos sem uma implementação).
end

--- Template method para verificação de colisão.
-- Orquestra a busca por inimigos e a lógica de acerto.
function BaseProjectile:checkCollision()
    if not self.spatialGrid or not self.isActive then return end

    -- Hook para obter os limites de busca da subclasse
    local searchBounds = self:_getSearchBounds()
    if not searchBounds then return end

    local nearbyEnemies = self.spatialGrid:getNearbyEntities(searchBounds.x, searchBounds.y, searchBounds.radius, nil)

    for _, enemy in ipairs(nearbyEnemies) do
        if enemy and enemy.isAlive and not self.hitEnemies[enemy.id] then
            -- A verificação geométrica agora é centralizada
            if self:_doCollisionCheck(enemy) then
                self:_applyHit(enemy)

                if not self.isActive then
                    -- Projétil foi desativado (ex: acabou a durabilidade)
                    break -- Para de verificar outros inimigos neste frame
                end
            end
        end
    end

    TablePool.release(nearbyEnemies)
end

--- Hook para que as subclasses definam sua área de busca por colisões.
---@return table? {x: number, y: number, radius: number}
function BaseProjectile:_getSearchBounds()
    error("Subclasse deve implementar _getSearchBounds()")
end

--- Realiza a verificação de colisão geométrica (círculo-círculo).
---@param enemy BaseEnemy O inimigo a ser verificado.
---@return boolean True se houve colisão, false caso contrário.
function BaseProjectile:_doCollisionCheck(enemy)
    -- Hook para obter a geometria de colisão da subclasse
    local projectileCircle = self:_getCollisionCircle()
    if not projectileCircle or not enemy.radius then return false end

    -- Lógica de colisão círculo-círculo
    local dx = projectileCircle.x - enemy.position.x
    local dy = projectileCircle.y - enemy.position.y
    local distanceSq = dx * dx + dy * dy
    local sumOfRadii = projectileCircle.radius + CombatHelpers.getPermissiveRadius(enemy)
    local sumOfRadiiSq = sumOfRadii * sumOfRadii

    return distanceSq <= sumOfRadiiSq
end

--- Hook para que a subclasse retorne sua geometria de colisão.
---@return {x: number, y: number, radius: number}
function BaseProjectile:_getCollisionCircle()
    error("Subclasse deve implementar _getCollisionCircle()")
end

--- Aplica todos os efeitos de um acerto a um inimigo.
---@param enemy BaseEnemy O inimigo que foi atingido.
function BaseProjectile:_applyHit(enemy)
    self:_applyKnockback(enemy)
    self:_applyDamage(enemy)

    self.hitEnemies[enemy.id] = true

    -- Lógica de custo de durabilidade por acerto
    self:_consumeHitDurability()
end

--- Aplica knockback ao inimigo.
---@param enemy BaseEnemy
function BaseProjectile:_applyKnockback(enemy)
    if self.knockbackPower > 0 then
        local knockbackDir = self:_getKnockbackDirection(enemy)

        CombatHelpers.applyKnockback(
            enemy,               -- targetEnemy
            nil,                 -- attackerPosition (projétil usa override)
            self.knockbackPower, -- attackKnockbackPower
            self.knockbackForce, -- attackKnockbackForce
            self.playerStrength, -- playerStrength
            knockbackDir         -- knockbackDirectionOverride
        )
    end
end

--- Determina a direção do knockback.
---@param enemy BaseEnemy
---@return table {x: number, y: number} A direção normalizada.
function BaseProjectile:_getKnockbackDirection(enemy)
    -- A direção padrão é a da velocidade do projétil.
    local dirX, dirY = 0, 0
    if self.speed > 0 then
        dirX = self.velocity.x / self.speed
        dirY = self.velocity.y / self.speed
    else
        -- Fallback se o projétil estiver parado.
        local dx = enemy.position.x - self.position.x
        local dy = enemy.position.y - self.position.y
        local distSq = dx * dx + dy * dy
        if distSq > 0 then
            local dist = math.sqrt(distSq)
            dirX = dx / dist
            dirY = dy / dist
        else -- Sobrepostos, usa direção aleatória para evitar divisão por zero.
            local randomAngle = math.random() * 2 * math.pi
            dirX = math.cos(randomAngle)
            dirY = math.sin(randomAngle)
        end
    end
    return { x = dirX, y = dirY }
end

--- Aplica dano ao inimigo e registra as estatísticas.
---@param enemy BaseEnemy
function BaseProjectile:_applyDamage(enemy)
    local isSuperCritical = false -- TODO: Implementar super-crítico
    enemy:takeDamage(self.damage, self.isCritical, isSuperCritical)

    -- Registra o dano para as estatísticas do jogo
    if self.playerManager and self.weaponInstance then
        local source = { weaponId = self.weaponInstance.itemBaseId }
        self.playerManager:registerDamageDealt(self.damage, self.isCritical, source, isSuperCritical)
    end
end

--- Consome durabilidade ao atingir um inimigo.
-- A perfuração reduz o custo do impacto.
function BaseProjectile:_consumeHitDurability()
    -- Fórmula: Custo Efetivo = Custo Base / (1 + Perfuração)
    -- Isso faz com que a perfuração tenha retornos decrescentes,
    -- mas cada ponto ainda ajuda.
    local effectiveHitCost = self.hitCost / (1 + self.piercing)

    self.durability = self.durability - effectiveHitCost
    if self.durability <= 0 then
        self.isActive = false
    end
end

--- Hook para o desenho do projétil.
-- Deve ser implementado pela subclasse.
function BaseProjectile:draw()
    error("Subclasse deve implementar draw()")
end

return BaseProjectile
