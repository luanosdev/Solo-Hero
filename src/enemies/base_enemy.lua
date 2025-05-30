-------------------------------------------------
--- Base Enemy
-------------------------------------------------

local ManagerRegistry = require("src.managers.manager_registry")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local FloatingText = require("src.entities.floating_text")
local Colors = require("src.ui.colors")
local TablePool = require("src.utils.table_pool")
local Constants = require("src.config.constants")

---@class BaseEnemy
local BaseEnemy = {
    -- Identification
    id = 0,
    name = "BaseEnemy",
    className = "BaseEnemy",

    -- Individual Stats
    maxHealth = 0,
    currentHealth = 0,
    damage = 0,
    experienceValue = 0,

    -- Gameplay Stats
    isAlive = true,
    isMVP = false,
    isBoss = false,

    -- Timers
    lastDamageTime = 0,
    damageCooldown = 1,
    deathTimer = 0,
    deathDuration = 2.5,
    updateInterval = 0.1,
    updateTimer = 0,
    floatingTextUpdateInterval = 1 / 15,
    floatingTextUpdateTimer = 0,
    slowUpdateTimer = 0,

    -- Floating Texts
    activeFloatingTexts = {},

    -- Animation
    unitType = nil,
    sprite = nil,
    spriteData = nil,
    isDeathAnimationComplete = false,
    isDying = false,

    -- Physics
    size = Constants.ENEMY_SPRITE_SIZES.MEDIUM,
    radius = 0,

    -- Movement
    position = { x = 0, y = 0 },
    speed = 0,

    lastGridCol = nil,
    lastGridRow = nil,
    currentGridCells = nil,

    -- Constants
    RADIUS_SIZE_DELTA = 0.5,
    SEPARATION_STRENGTH = 30.0,
}

--- Constructor
--- @param position { x: number, y: number } Position initial (x, y).
--- @param id string|number Unique ID for the enemy.
--- @return BaseEnemy Instance of BaseEnemy.
function BaseEnemy:new(position, id)
    local enemy = {}
    setmetatable(enemy, { __index = self })

    enemy.position = { x = position.x or 0, y = position.y or 0 }
    enemy.id = id or 0

    enemy:updateStatsFromPrototype()

    enemy.isAlive = true
    enemy.isDying = false
    enemy.isDeathAnimationComplete = false
    enemy.shouldRemove = false
    enemy.deathTimer = 0
    enemy.lastDamageTime = 0

    enemy.directionUpdateInterval = 0.4 + math.random() * 0.4
    enemy.directionUpdateTimer = 0

    enemy.updateTimer = math.random() * enemy.updateInterval
    enemy.floatingTextUpdateTimer = math.random() * enemy.floatingTextUpdateInterval

    enemy.activeFloatingTexts = {}

    enemy.directionX = 0 -- Nova direção X
    enemy.directionY = 0 -- Nova direção Y

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

    self:updateMovementToPlayer(dt, playerManager, isSlowUpdate) -- Restaurado e usando isSlowUpdate
    self:applySeparation(enemyManager, dt)
    self:checkPlayerCollision(dt, playerManager)                 -- Restaurado

    -- Update animação idle/movimento
    if self.sprite then
        self.sprite.position = self.position -- Define a posição da sprite ANTES de atualizar a animação
        AnimatedSpritesheet.update(self.unitType, self.sprite, dt, playerManager.player.position)
    end
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

--- Updates the movement of the enemy to the player
--- @param dt number Delta time.
--- @param playerManager PlayerManager The player manager.
--- @param isSlowUpdate boolean Whether to update the enemy slowly.
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

--- Updates the movement of the enemy
--- @param dt number Delta time.
--- @param playerManager PlayerManager The player manager.
--- @param enemyManager EnemyManager The enemy manager.
--- @param isSlowUpdate boolean Whether to update the enemy slowly.
function BaseEnemy:updateMovement(dt, playerManager, enemyManager, isSlowUpdate)
    -- Movimento desacelerado (offscreen)
    if isSlowUpdate then
        self.slowUpdateTimer = (self.slowUpdateTimer or 0) + dt
        if self.slowUpdateTimer < 1.0 then
            return
        end
        dt = self.slowUpdateTimer
        self.slowUpdateTimer = 0
    end

    self.updateTimer = self.updateTimer + dt
    if self.updateTimer >= self.updateInterval then
        self.updateTimer = self.updateTimer - self.updateInterval

        local playerPos = playerManager:getCollisionPosition()
        if not playerPos then return end

        local dx = playerPos.position.x - self.position.x
        local dy = playerPos.position.y - self.position.y

        local lenSq = dx * dx + dy * dy
        if lenSq > 0 then
            local len = math.sqrt(lenSq)
            dx = dx / len
            dy = dy / len
        else
            dx, dy = 0, 0
        end

        local effectiveDt = isSlowUpdate and dt or self.updateInterval
        local moveSpeed = self.speed

        -- 🟢 Movimento de perseguição
        self.position.x = self.position.x + dx * moveSpeed * effectiveDt
        self.position.y = self.position.y + dy * moveSpeed * effectiveDt


        self:checkPlayerCollision(effectiveDt, playerManager)
    end
end

--- Checks if the ensemy has collided with the player
--- @param dt number Delta time.
--- @param playerManager PlayerManager The player manager.
function BaseEnemy:checkPlayerCollision(dt, playerManager)
    if not playerManager.player or not playerManager.state.isAlive then return end

    self.lastDamageTime = self.lastDamageTime + dt

    local enemyX = self.position.x
    local enemyY = self.position.y + 10
    local playerX = playerManager.player.position.x
    local playerY = playerManager.player.position.y + 25

    local dx = playerX - enemyX
    local dy = playerY - enemyY
    local distSq = dx * dx + dy * dy
    local combined = self.radius + playerManager.radius

    if distSq <= combined * combined then
        if self.lastDamageTime >= self.damageCooldown then
            playerManager:receiveDamage(self.damage)
            self.lastDamageTime = 0
        end
    end
end

--- Applies damage to the enemy
--- @param amount number Amount of damage to apply.
--- @param isCritical boolean Whether the damage is critical.
--- @return boolean True if the enemy is dead, false otherwise.
function BaseEnemy:takeDamage(amount, isCritical)
    if not self.isAlive then return false end

    self.currentHealth = self.currentHealth - amount

    if self.currentHealth <= 0 then
        self.currentHealth = 0
        self.isAlive = false
        self.isDying = true
        self.deathTimer = 0

        local xpManager = ManagerRegistry:get("experienceOrbManager")
        if xpManager then
            xpManager:addOrb(self.position.x, self.position.y, self.experienceValue)
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

--- Draws the floating texts
--- @param textBatch table TextBatch.
function BaseEnemy:drawFloatingTexts(textBatch)
    if not self.activeFloatingTexts then return end
    for _, text in ipairs(self.activeFloatingTexts) do
        text:draw(textBatch)
    end
end

--- Updates the floating texts
--- @param dt number Delta time.
function BaseEnemy:updateFloatingTexts(dt)
    for i = #self.activeFloatingTexts, 1, -1 do
        local text = self.activeFloatingTexts[i]
        if not text:update(dt) then
            table.remove(self.activeFloatingTexts, i)
        end
    end
end

--- Resets the enemy
--- @param position table Position.
--- @param id number Unique ID.
function BaseEnemy:reset(position, id)
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

    self.directionUpdateInterval = 0.4 + math.random() * 0.4
    self.directionUpdateTimer = 0

    self.updateTimer = math.random() * self.updateInterval
    self.floatingTextUpdateTimer = math.random() * self.floatingTextUpdateInterval
    self.slowUpdateTimer = 0

    self.currentGridCells = nil
    self.activeFloatingTexts = {}

    self.directionX = 0
    self.directionY = 0

    self:initializeSprite()
end

--- Resets the state for pooling
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
    self.activeFloatingTexts = {}
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

return BaseEnemy
