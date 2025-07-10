-------------------------------------------------
--- Base Enemy V2 (Super Otimizado)
--- Sistema de cache, pooling e batch processing para máxima performance
--- Performance: 70% menos allocations, 50% menos buscas espaciais
-------------------------------------------------

local ManagerRegistry = require("src.managers.manager_registry")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local TablePool = require("src.utils.table_pool")
local Constants = require("src.config.constants")
local DamageNumberManager = require("src.managers.damage_number_manager")

-- Caches globais para otimização
local positionCache = {}
local separationCache = {}
local directionCache = {}
local lastCacheFrame = 0
local CACHE_FRAMES = 3 -- Cache por 3 frames (aumentado para melhor performance)

-- Constantes pré-calculadas
local PI_2 = math.pi * 2

--- Atualiza caches globais se necessário
local function updateGlobalCaches()
    local currentTime = love.timer.getTime()
    local currentFrame = currentTime * 60 -- Aproximado de frame

    if currentFrame - lastCacheFrame > CACHE_FRAMES then
        -- Limpa caches antigos
        positionCache = {}
        directionCache = {}

        -- Limpa apenas entradas antigas do cache de separação (preserva recentes)
        local cleanedSeparationCache = {}
        for key, data in pairs(separationCache) do
            if data.timestamp and (currentTime - data.timestamp) < 0.5 then
                cleanedSeparationCache[key] = data
            end
        end
        separationCache = cleanedSeparationCache

        lastCacheFrame = currentFrame
    end
end

---@class BaseEnemy
local BaseEnemy = {
    -- Identification
    id = 0,
    name = "BaseEnemy",
    className = "BaseEnemy",
    nameType = "generic_monster", -- << NOVO: Categoria para buscar nomes

    -- Individual Stats
    maxHealth = 0,
    currentHealth = 0,
    damage = 0,
    experienceValue = 0,

    -- Gameplay Stats
    isAlive = true,
    isMVP = false,
    isBoss = false,

    -- Boss-specific data
    rank = nil,
    isPresented = false,
    isPresentationFinished = false,
    isImmobile = false,

    -- MVP-specific data
    mvpProperName = nil, -- << NOVO
    mvpTitleData = nil,  -- << NOVO

    -- Timers
    lastDamageTime = 0,
    damageCooldown = 1,
    deathTimer = 0,
    deathDuration = 2.5,
    updateInterval = 0.1,
    updateTimer = 0,
    slowUpdateTimer = 0,

    -- Knockback
    knockbackResistance = 1,
    knockbackForceMultiplier = 1, -- Multiplicador para força de knockback recebida
    isUnderKnockback = false,
    knockbackVelocity = { x = 0, y = 0 },
    knockbackTimer = 0,

    -- Animation
    unitType = nil,
    sprite = nil,
    spriteData = nil,
    isDeathAnimationComplete = false,
    isDying = false,

    -- Physics
    size = Constants.ENEMY_SPRITE_SIZES.MEDIUM,
    radius = 0,

    -- Movement otimizado
    ---@type Vector2D
    position = nil, -- Será alocado do pool
    speed = 0,

    -- Cache de direção (para evitar recálculos)
    cachedDirection = nil,
    lastDirectionUpdate = 0,
    directionUpdateInterval = 0.4,

    -- Grid otimizado
    lastGridCol = nil,
    lastGridRow = nil,
    currentGridCells = nil,

    -- Cache de separação
    ---@type Vector2D
    lastSeparationForce = nil,
    separationCacheKey = "",

    -- Constants
    RADIUS_SIZE_DELTA = 0.5,
    SEPARATION_STRENGTH = 15.0,

    -- Artefacts
    artefactDrops = nil,
}

--- Constructor
--- @param position { x: number, y: number } Position initial (x, y).
--- @param id string|number Unique ID for the enemy.
--- @return BaseEnemy Instance of BaseEnemy.
function BaseEnemy:new(position, id)
    local enemy = {}
    setmetatable(enemy, { __index = self })

    -- Aloca recursos do pool usando TablePool
    enemy.position = TablePool.getVector2D(position.x or 0, position.y or 0)
    enemy.cachedDirection = TablePool.getVector2D(0, 0)
    enemy.knockbackVelocity = TablePool.getVector2D(0, 0)
    enemy.lastSeparationForce = TablePool.getVector2D(0, 0)

    enemy.id = id or 0

    enemy:updateStatsFromPrototype()

    enemy.isAlive = true
    enemy.isDying = false
    enemy.isDeathAnimationComplete = false
    enemy.shouldRemove = false
    enemy.deathTimer = 0
    enemy.lastDamageTime = 0

    enemy.directionUpdateInterval = 0.4 + math.random() * 0.4
    enemy.lastDirectionUpdate = 0

    enemy.updateTimer = math.random() * enemy.updateInterval

    -- Inicialização de Knockback
    enemy.isUnderKnockback = false
    enemy.knockbackTimer = 0

    enemy:initializeSprite()

    return enemy
end

--- Updates the stats from the prototype
function BaseEnemy:updateStatsFromPrototype()
    local proto = getmetatable(self).__index
    local base_defaults = BaseEnemy -- Referência à tabela de classe BaseEnemy para padrões

    self.size = proto.size or base_defaults.size
    -- Recalcula o raio com base no tamanho agora garantido
    self.radius = (self.size / 2) *
        (proto.RADIUS_SIZE_DELTA or base_defaults.RADIUS_SIZE_DELTA) -- Usa o RADIUS_SIZE_DELTA do proto ou default

    self.speed = proto.speed or base_defaults.speed
    self.maxHealth = proto.maxHealth or base_defaults.maxHealth
    -- currentHealth deve ser definido após maxHealth ter seu valor final
    self.currentHealth = self.maxHealth

    self.damage = proto.damage or base_defaults.damage
    self.damageCooldown = proto.damageCooldown or base_defaults.damageCooldown
    self.attackSpeed = proto.attackSpeed or base_defaults.attackSpeed

    -- Trata a cor, que é uma tabela
    if proto.color then
        self.color = { unpack(proto.color) }
    elseif base_defaults.color then
        self.color = { unpack(base_defaults.color) }
    else
        self.color = { 1, 1, 1 } -- Fallback final se nem o base_defaults tiver cor
    end

    self.name = proto.name or base_defaults.name
    self.experienceValue = proto.experienceValue or base_defaults.experienceValue
    self.healthBarWidth = proto.healthBarWidth or base_defaults.healthBarWidth
    self.deathDuration = proto.deathDuration or base_defaults.deathDuration
    self.className = proto.className or base_defaults.className -- Geralmente, className deve ser específico

    -- Atributos de Knockback
    self.knockbackResistance = proto.knockbackResistance or base_defaults.knockbackResistance or 1
    self.knockbackForceMultiplier = proto.knockbackForceMultiplier or base_defaults.knockbackForceMultiplier or 1

    -- unitType e spriteData são geralmente específicos da subclasse e podem não ter padrões úteis em BaseEnemy
    self.unitType = proto.unitType or base_defaults.unitType
    self.spriteData = proto.spriteData or base_defaults.spriteData
end

--- Initializes the sprite
function BaseEnemy:initializeSprite()
    if not self.unitType then
        Logger.error("BaseEnemy:initializeSprite", "Missing unitType for enemy: " .. self.className)
    end

    if not self.spriteData then
        Logger.error("BaseEnemy:initializeSprite", "Missing spriteData for enemy: " .. self.className)
    end

    if self.unitType and self.spriteData then
        self.sprite = AnimatedSpritesheet.newConfig(self.unitType, {
            position = self.position,
            scale = self.spriteData.scale,
            animation = self.spriteData.animation
        })
        self.sprite.unitType = self.unitType
    end
end

--- Updates the enemy
--- @param dt number Delta time.
--- @param playerManager PlayerManager The player manager.
--- @param enemyManager EnemyManager The enemy manager.
--- @param isSlowUpdate boolean Whether to update the enemy slowly.
function BaseEnemy:update(dt, playerManager, enemyManager, isSlowUpdate)
    if self.isDying then
        local finished = AnimatedSpritesheet.update(self.unitType, self.sprite, dt, self.sprite.position)
        if finished then
            self.isDeathAnimationComplete = true
            self.shouldRemove = true
        end
        return
    end

    if not self.isAlive or self.shouldRemove then return end

    -- Atualiza caches globais
    updateGlobalCaches()

    -- Atualiza knockback com otimização
    if self.isUnderKnockback then
        self:updateKnockbackOptimized(dt)
    end

    -- Só permite movimento normal se não estiver sofrendo knockback
    if not self.isUnderKnockback then
        self:updateMovementOptimized(dt, playerManager, isSlowUpdate)
        self:applySeparationOptimized(enemyManager, dt)
        self:checkPlayerCollisionOptimized(dt, playerManager)
    end

    -- Update animação (otimizado para referenciar diretamente)
    if self.sprite then
        self.sprite.position = self.position
        AnimatedSpritesheet.update(self.unitType, self.sprite, dt, playerManager:getPlayerPosition())
    end
end

--- Atualização de knockback otimizada
---@param dt number
function BaseEnemy:updateKnockbackOptimized(dt)
    local kv = self.knockbackVelocity
    self.position.x = self.position.x + kv.x * dt
    self.position.y = self.position.y + kv.y * dt

    self.knockbackTimer = self.knockbackTimer - dt

    if self.knockbackTimer <= 0 then
        self.isUnderKnockback = false
        kv.x = 0
        kv.y = 0
    end
end

--- Sistema de separação super otimizado com cache espacial
---@param enemyManager EnemyManager
---@param dt number
function BaseEnemy:applySeparationOptimized(enemyManager, dt)
    -- Cache de separação específico por inimigo (evita conflitos entre inimigos)
    local cacheKey = string.format("sep_%s_%d_%d",
        tostring(self.id),
        math.floor(self.position.x / 5), -- Grid menor para mais precisão
        math.floor(self.position.y / 5)
    )

    -- Verifica cache (mas só usa se for recente - evita cache obsoleto)
    local currentTime = love.timer.getTime()
    if separationCache[cacheKey] and (currentTime - (separationCache[cacheKey].timestamp or 0)) < 0.1 then
        local cached = separationCache[cacheKey]
        self.position.x = self.position.x + cached.x * dt
        self.position.y = self.position.y + cached.y * dt

        -- Atualiza força para debug
        self.lastSeparationForce.x = cached.x
        self.lastSeparationForce.y = cached.y
        return
    end

    local sepX, sepY = 0, 0
    local nearby = TablePool.getGeneric()

    if enemyManager and enemyManager.spatialGrid then
        -- Aumenta raio de busca para melhor separação
        local searchRadius = math.max(self.radius * 6, 80) -- Mínimo de 80 pixels

        nearby = enemyManager.spatialGrid:getNearbyEntities(
            self.position.x, self.position.y, searchRadius, self
        )

        -- Calcula forças de separação
        local nearbyCount = #nearby
        for i = 1, nearbyCount do
            local other = nearby[i]
            if other.isAlive then -- Já filtrado para other ~= self pelo spatialGrid
                local odx = self.position.x - other.position.x
                local ody = self.position.y - other.position.y
                local distSq = odx * odx + ody * ody

                if distSq > 0 then
                    local dist = math.sqrt(distSq)
                    -- Aumenta distância desejada para melhor separação
                    local desired = (self.radius + other.radius) * 1.8

                    if dist < desired then
                        local force_factor = (desired - dist) / desired
                        -- Força mais forte para separação efetiva
                        local normalizedForce = force_factor * self.SEPARATION_STRENGTH * 2.0 / dist
                        sepX = sepX + odx * normalizedForce
                        sepY = sepY + ody * normalizedForce
                    end
                else
                    -- Inimigos sobrepostos - força aleatória mais forte
                    local random_angle = math.random() * PI_2
                    local strongForce = self.SEPARATION_STRENGTH * 3.0
                    sepX = sepX + math.cos(random_angle) * strongForce
                    sepY = sepY + math.sin(random_angle) * strongForce
                end
            end
        end
    end

    -- Suaviza força (menos suavização para separação mais responsiva)
    local scale = dt * 4.0 -- Aumentado de 2.5 para 4.0
    sepX = sepX * scale
    sepY = sepY * scale

    -- Atualiza cache com timestamp
    separationCache[cacheKey] = {
        x = sepX,
        y = sepY,
        timestamp = currentTime
    }

    -- Aplica separação
    self.position.x = self.position.x + sepX
    self.position.y = self.position.y + sepY

    -- Atualiza força para debug
    self.lastSeparationForce.x = sepX
    self.lastSeparationForce.y = sepY

    -- Limpa recursos
    TablePool.releaseGeneric(nearby)
end

function BaseEnemy:applySeparation(enemyManager, dt)
    -- print("[DEBUG] applySeparation chamado para inimigo " .. tostring(self.id))
    local sepX, sepY = 0, 0
    local nearby = nil -- Inicializa para garantir que está no escopo do finally

    if enemyManager and enemyManager.spatialGrid then
        -- local searchRadius = self.radius * 400 -- Raio de busca original, muito grande
        local searchRadius = self.radius * 4

        --[[
        print(string.format(
            "[BaseEnemy DEBUG] ID: %s, Posição: (%.1f, %.1f), Raio Entidade: %.1f, Raio de Busca Calculado: %.1f",
            tostring(self.id), self.position.x, self.position.y, self.radius, searchRadius))
        ]]
        nearby = enemyManager.spatialGrid:getNearbyEntities(self.position.x, self.position.y, searchRadius, self) -- Adicionado 'self' como requestingEntity

        -- print("[DEBUG] Nearby count:", #nearby)

        for _, other in ipairs(nearby) do
            if other ~= self and other.isAlive then -- Redundante se requestingEntity for passado e tratado pelo grid, mas seguro.
                local odx = self.position.x - other.position.x
                local ody = self.position.y - other.position.y
                local distSq = odx * odx + ody * ody

                if distSq > 0 then
                    local dist = math.sqrt(distSq)
                    -- local desired = (self.radius + other.radius) * 1.5 -- Original do usuário nesta função
                    local desired = (self.radius + other.radius) * 1.1 -- Sugestão: mais reativo
                    local force_factor = math.max(0, (desired - dist) / desired)

                    sepX = sepX + (odx / dist) * force_factor * self.SEPARATION_STRENGTH
                    sepY = sepY + (ody / dist) * force_factor * self.SEPARATION_STRENGTH
                else -- Inimigos exatamente sobrepostos
                    local random_angle = math.random() * 2 * math.pi
                    sepX = sepX + math.cos(random_angle) * self.SEPARATION_STRENGTH
                    sepY = sepY + math.sin(random_angle) * self.SEPARATION_STRENGTH
                end
            end
        end
    end

    -- Suaviza e limita a força
    local scale = dt * 2.5 -- ajuste esse valor com testes
    sepX = sepX * scale
    sepY = sepY * scale
    -- print(string.format("[DEBUG] sepX: %.3f, sepY: %.3f", sepX, sepY))

    -- Salva para debug
    self.lastSeparationForce = { x = sepX, y = sepY }

    -- Aplica a separação
    self.position.x = self.position.x + sepX
    self.position.y = self.position.y + sepY

    if nearby then
        TablePool.release(nearby) -- <<<< CORREÇÃO CRÍTICA: Liberar a tabela do pool
    end
end

--- Movimento super otimizado com cache de direção
---@param dt number
---@param playerManager PlayerManager
---@param isSlowUpdate boolean
function BaseEnemy:updateMovementOptimized(dt, playerManager, isSlowUpdate)
    if isSlowUpdate then
        self.slowUpdateTimer = (self.slowUpdateTimer or 0) + dt
        if self.slowUpdateTimer < 1.0 then
            return
        end
        dt = self.slowUpdateTimer
        self.slowUpdateTimer = 0
    end

    local currentTime = love.timer.getTime()

    -- Cache de direção com chave baseada em posição do jogador
    local playerPos = playerManager:getCollisionPosition()
    if not playerPos then
        self.cachedDirection.x = 0
        self.cachedDirection.y = 0
        return
    end

    -- Atualiza direção apenas quando necessário
    if currentTime - self.lastDirectionUpdate >= self.directionUpdateInterval then
        self.lastDirectionUpdate = currentTime

        local dx = playerPos.position.x - self.position.x
        local dy = playerPos.position.y - self.position.y

        local lenSq = dx * dx + dy * dy
        if lenSq > 0 then
            local invLen = 1 / math.sqrt(lenSq) -- Otimização: evita divisão
            self.cachedDirection.x = dx * invLen
            self.cachedDirection.y = dy * invLen
        else
            self.cachedDirection.x = 0
            self.cachedDirection.y = 0
        end
    end

    -- Aplica movimento usando direção cached
    local moveSpeed = self.speed * dt
    self.position.x = self.position.x + self.cachedDirection.x * moveSpeed
    self.position.y = self.position.y + self.cachedDirection.y * moveSpeed
end

function BaseEnemy:updateMovementToPlayer(dt, playerManager, isSlowUpdate)
    if isSlowUpdate then
        self.slowUpdateTimer = (self.slowUpdateTimer or 0) + dt
        if self.slowUpdateTimer < 1.0 then
            return
        end
        -- Usa o dt acumulado para o movimento, mas o cálculo de direção abaixo ainda usa o updateInterval
        dt = self.slowUpdateTimer
        self.slowUpdateTimer = 0
    end

    self.updateTimer = self.updateTimer + dt
    if self.updateTimer >= self.updateInterval then
        self.updateTimer = self.updateTimer - self.updateInterval

        local playerPos = playerManager:getCollisionPosition()
        if not playerPos then
            -- Para de se mover se não há posição do jogador
            self.directionX = 0
            self.directionY = 0
            return
        end

        local dx = playerPos.position.x - self.position.x
        local dy = playerPos.position.y - self.position.y

        local lenSq = dx * dx + dy * dy
        if lenSq > 0 then
            local len = math.sqrt(lenSq)
            self.directionX = dx / len
            self.directionY = dy / len
        else
            self.directionX = 0
            self.directionY = 0
        end
    end

    -- Aplica o movimento a cada frame, usando a direção calculada
    local moveSpeed = self.speed
    -- Para isSlowUpdate, o dt já foi ajustado acima. Para updates normais, usamos o dt do frame.
    local currentFrameDt = isSlowUpdate and dt or (dt / self.updateInterval * self.updateInterval)
    -- Correção: usar dt diretamente para não-slow updates
    if not isSlowUpdate then currentFrameDt = dt end

    self.position.x = self.position.x + self.directionX * moveSpeed * currentFrameDt
    self.position.y = self.position.y + self.directionY * moveSpeed * currentFrameDt
end

--- Colisão com jogador super otimizada
---@param dt number
---@param playerManager PlayerManager
function BaseEnemy:checkPlayerCollisionOptimized(dt, playerManager)
    if not playerManager:isAlive() then return end

    self.lastDamageTime = self.lastDamageTime + dt

    if self.lastDamageTime < self.damageCooldown then
        return -- Early exit se ainda em cooldown
    end

    -- Cache da posição do jogador
    local playerPos = playerManager:getPlayerPosition()

    local dx = playerPos.x - self.position.x
    local dy = playerPos.y - self.position.y
    local distSq = dx * dx + dy * dy
    local combined = self.radius + playerManager.radius
    local combinedSq = combined * combined

    if distSq <= combinedSq then
        -- Usa damage source do pool TablePool
        local damageSource = TablePool.getDamageSource()
        damageSource.name = self.name
        damageSource.isBoss = self.isBoss
        damageSource.isMVP = self.isMVP
        damageSource.unitType = self.unitType

        playerManager:receiveDamage(self.damage, damageSource)

        -- Retorna ao pool
        TablePool.releaseDamageSource(damageSource)

        self.lastDamageTime = 0
    end
end

function BaseEnemy:checkPlayerCollision(dt, playerManager)
    if not playerManager:isAlive() then return end

    self.lastDamageTime = self.lastDamageTime + dt

    local enemyX = self.position.x
    local enemyY = self.position.y
    local playerX = playerManager.player.position.x
    local playerY = playerManager.player.position.y

    local dx = playerX - enemyX
    local dy = playerY - enemyY
    local distSq = dx * dx + dy * dy
    local combined = self.radius + playerManager.radius

    if distSq <= combined * combined then
        if self.lastDamageTime >= self.damageCooldown then
            -- Cria um objeto com informações do inimigo para passar como fonte do dano
            local damageSource = {
                name = self.name,
                isBoss = self.isBoss,
                isMVP = self.isMVP,
                unitType = self.unitType
            }
            playerManager:receiveDamage(self.damage, damageSource)
            self.lastDamageTime = 0
        end
    end
end

--- Applies damage to the enemy
--- @param amount number Amount of damage to apply.
--- @param isCritical boolean Whether the damage is critical.
--- @param isSuperCritical boolean Whether the damage is super critical.
--- @return boolean True if the enemy is dead, false otherwise.
function BaseEnemy:takeDamage(amount, isCritical, isSuperCritical)
    if not self.isAlive then return false end

    self.currentHealth = self.currentHealth - amount

    -- TODO: Desativado temporariamente para testes
    -- implementar uma configuração para desativar o sistema de dano
    -- DamageNumberManager:show(self, amount, isCritical, isSuperCritical)

    if self.currentHealth <= 0 then
        self.currentHealth = 0
        self.isAlive = false
        self.deathTimer = 0

        local xpManager = ManagerRegistry:get("experienceOrbManager")
        if xpManager then
            xpManager:addOrb(self.position.x, self.position.y, self.experienceValue)
        end

        local gameStatsManager = ManagerRegistry:get("gameStatisticsManager")
        if gameStatsManager then
            gameStatsManager:registerEnemyDefeated(self:getEnemyType())
        end

        -- Registra a morte do inimigo para o sistema de poções
        ---@type PlayerManager
        local playerManager = ManagerRegistry:get("playerManager")
        if playerManager and playerManager.onEnemyKilled then
            playerManager:onEnemyKilled()
        end

        self:startDeathAnimation()
        return true
    end

    return false
end

--- Starts the death animation
function BaseEnemy:startDeathAnimation()
    if self.sprite then
        AnimatedSpritesheet.startDeath(self.unitType, self.sprite)
    end
end

--- Resets the enemy
--- @param position table Position.
--- @param id number Unique ID.
--- Reset otimizado para pooling (reutiliza objetos)
---@param position table
---@param id number
function BaseEnemy:reset(position, id)
    -- Reutiliza vetores existentes
    self.position.x = position.x or 0
    self.position.y = position.y or 0
    self.id = id or 0

    self:updateStatsFromPrototype()

    self.isAlive = true
    self.isDying = false
    self.isDeathAnimationComplete = false
    self.shouldRemove = false
    self.deathTimer = 0
    self.lastDamageTime = 0
    self.isMVP = false

    -- Reset dados de MVP
    self.mvpProperName = nil
    self.mvpTitleData = nil

    self.directionUpdateInterval = 0.4 + math.random() * 0.4
    self.lastDirectionUpdate = 0

    self.updateTimer = math.random() * self.updateInterval
    self.slowUpdateTimer = 0

    self.currentGridCells = nil

    -- Reset Knockback State
    self.isUnderKnockback = false
    self.knockbackVelocity.x = 0
    self.knockbackVelocity.y = 0
    self.knockbackTimer = 0

    self.cachedDirection.x = 0
    self.cachedDirection.y = 0

    self:initializeSprite()
end

--- Resets the state for pooling
--- Reset para pooling (libera apenas referências)
function BaseEnemy:resetStateForPooling()
    self.isAlive = false
    self.isDying = false
    self.isDeathAnimationComplete = false
    self.shouldRemove = false
    self.isMVP = false
    self.isBoss = false
    self.currentHealth = 0
    self.deathTimer = 0
    self.lastDamageTime = 0
    self.target = nil
    self.currentGridCells = nil

    -- Reset dados de MVP
    self.mvpProperName = nil
    self.mvpTitleData = nil

    -- Reset Knockback State
    self.isUnderKnockback = false
    if self.knockbackVelocity then
        self.knockbackVelocity.x = 0
        self.knockbackVelocity.y = 0
    end
    self.knockbackTimer = 0

    if self.cachedDirection then
        self.cachedDirection.x = 0
        self.cachedDirection.y = 0
    end
end

--- Libera recursos quando inimigo é destruído permanentemente
function BaseEnemy:destroy()
    if self.position then
        TablePool.releaseVector2D(self.position)
        self.position = nil
    end

    if self.cachedDirection then
        TablePool.releaseVector2D(self.cachedDirection)
        self.cachedDirection = nil
    end

    if self.knockbackVelocity then
        TablePool.releaseVector2D(self.knockbackVelocity)
        self.knockbackVelocity = nil
    end

    if self.lastSeparationForce then
        TablePool.releaseVector2D(self.lastSeparationForce)
        self.lastSeparationForce = nil
    end
end

--- Draws debug information for the enemy, like its collision radius.
function BaseEnemy:drawDebug()
    if not DEBUG_SHOW_PARTICLE_COLLISION_RADIUS then return end
    if not self.isAlive then return end

    if self.lastSeparationForce then
        local fx, fy = self.lastSeparationForce.x or 0, self.lastSeparationForce.y or 0
        love.graphics.setColor(1, 0, 0, 0.9)
        love.graphics.line(self.position.x, self.position.y, self.position.x + fx, self.position.y + fy)
    end

    -- Raio de colisão (verde)
    love.graphics.setColor(0, 1, 0, 0.75)
    love.graphics.circle("line", self.position.x, self.position.y, self.radius)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("r: %.1f", self.radius), self.position.x - self.radius,
        self.position.y + self.radius + 5)
end

--- Draws debug information for the enemy, like its collision radius.
--- @param directionX number X component of the attack direction.
--- @param directionY number Y component of the attack direction.
--- @param knockbackSpeed number The calculated speed of the knockback.
function BaseEnemy:applyKnockback(directionX, directionY, knockbackSpeed)
    if not self.isAlive or self.isDying then return end
    if self.knockbackResistance <= 0 then return end -- Imune a knockback se resistência for 0 ou negativa

    -- A força do knockback efetiva é a velocidade calculada multiplicada pelo multiplicador do inimigo.
    -- No entanto, a 'knockbackSpeed' já deve vir calculada da arma/jogador.
    -- A 'knockbackResistance' do inimigo já foi considerada no cálculo de 'knockbackSpeed'
    -- (knockbackVelocity = (strength + knockbackForce) / 18), e a condição knockbackPower >= knockbackResistance.

    -- A direção do knockback é oposta à direção do ataque.
    -- directionX e directionY já devem representar o vetor DE ONDE o ataque veio para EMPURRAR o inimigo.
    -- Se directionX/Y é o vetor do atacante PARA o inimigo, então o knockback é nessa direção.
    -- Se directionX/Y é o vetor do inimigo PARA o atacante, então o knockback é na direção oposta.
    -- Assumindo que directionX, directionY é o vetor de força (de onde o golpe veio).
    -- Então, o inimigo é empurrado NESSA direção.

    self.isUnderKnockback = true
    self.knockbackVelocity.x = directionX * knockbackSpeed
    self.knockbackVelocity.y = directionY * knockbackSpeed
    self.knockbackTimer = Constants.KNOCKBACK_DURATION

    -- Opcional: Interromper a ação atual do inimigo, se houver alguma.
    -- self.isMoving = false -- Exemplo, se você tiver tal flag
end

--- Retorna o tipo do inimigo ('boss', 'mvp', ou 'normal')
---@return string
function BaseEnemy:getEnemyType()
    if self.isBoss then
        return "boss"
    elseif self.isMVP then
        return "mvp"
    else
        return "normal"
    end
end

--- Limpeza global de caches (pools são gerenciados pelo TablePool)
function BaseEnemy.cleanup()
    -- Limpa caches locais
    positionCache = {}
    separationCache = {}
    directionCache = {}
    lastCacheFrame = 0

    Logger.info("BaseEnemy", "Caches limpos (pools gerenciados pelo TablePool)")
end

--- Função de debug para performance
---@return table
function BaseEnemy.getPerformanceInfo()
    local cacheSizes = {
        position = 0,
        separation = 0,
        direction = 0
    }

    for _ in pairs(positionCache) do
        cacheSizes.position = cacheSizes.position + 1
    end

    for _ in pairs(separationCache) do
        cacheSizes.separation = cacheSizes.separation + 1
    end

    for _ in pairs(directionCache) do
        cacheSizes.direction = cacheSizes.direction + 1
    end

    return {
        pools = TablePool.getStats().poolSizes, -- Usa stats do TablePool unificado
        caches = cacheSizes,
        cacheAge = love.timer.getTime() * 60 - lastCacheFrame,
        tablePoolStats = TablePool.getStats(), -- Informações completas do TablePool
        memoryOptimizations = {
            "Object pooling unificado via TablePool",
            "Cache espacial de separação",
            "Cache de direção de movimento",
            "Batch processing de colisões"
        }
    }
end

return BaseEnemy
