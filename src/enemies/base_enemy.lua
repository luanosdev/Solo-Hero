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
    RADIUS_SIZE_DELTA = 0.9,
    SEPARATION_STRENGTH = 60.0,
}

--- Constructor
--- @param position { x: number, y: number } Position initial (x, y).
--- @param id string|number Unique ID for the enemy.
--- @return BaseEnemy Instance of BaseEnemy.
function BaseEnemy:new(position, id)
    Logger.info("BaseEnemy:new", " Criando inimigo.")
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

    enemy:initializeSprite()

    return enemy
end

--- Updates the stats from the prototype
function BaseEnemy:updateStatsFromPrototype()
    local proto = getmetatable(self).__index

    self.size = proto.size
    self.radius = (self.size / 2) * self.RADIUS_SIZE_DELTA
    self.speed = proto.speed
    self.maxHealth = proto.maxHealth
    self.currentHealth = proto.maxHealth
    self.damage = proto.damage
    self.damageCooldown = proto.damageCooldown
    self.attackSpeed = proto.attackSpeed
    self.color = proto.color and { unpack(proto.color) } or { 1, 1, 1 }
    self.name = proto.name
    self.experienceValue = proto.experienceValue
    self.healthBarWidth = proto.healthBarWidth
    self.deathDuration = proto.deathDuration
    self.className = proto.className
    self.unitType = proto.unitType
    self.spriteData = proto.spriteData
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
            speed = self.spriteData.speed,
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

    if not self.isAlive then return end

    -- Update animação idle/movimento
    if self.sprite then
        AnimatedSpritesheet.update(self.unitType, self.sprite, dt, playerManager.player.position)
        self.position = self.sprite.position
    end

    -- Update movimento e colisão
    BaseEnemy:updateMovement(dt, playerManager, enemyManager, isSlowUpdate)
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
        local dy = (playerPos.position.y - self.position.y) * 2

        local lenSq = dx * dx + dy * dy
        if lenSq > 0 then
            local len = math.sqrt(lenSq)
            dx = dx / len
            dy = dy / len
        end

        local effectiveDt = isSlowUpdate and dt or self.updateInterval
        local targetX = self.position.x + dx * self.speed * effectiveDt
        local targetY = self.position.y + dy * self.speed * effectiveDt

        -- Separação de outros inimigos
        local sepX, sepY = 0, 0

        if enemyManager and enemyManager.spatialGrid then
            local nearby = enemyManager.spatialGrid:getNearbyEntities(self.position.x, self.position.y, 1)
            for _, other in ipairs(nearby) do
                if other ~= self and other.isAlive then
                    local dx = self.position.x - other.position.x
                    local dy = (self.position.y - other.position.y) * 2
                    local distSq = dx * dx + dy * dy

                    if distSq > 0 then
                        local dist = math.sqrt(distSq)
                        local desired = (self.radius + other.radius) * 1.5
                        local force = math.max(0, (desired - dist) / desired)

                        sepX = sepX + (dx / dist) * force * self.SEPARATION_STRENGTH
                        sepY = sepY + (dy / dist) * force * self.SEPARATION_STRENGTH
                    end
                end
            end
        end

        self.position.x = targetX + sepX * effectiveDt
        self.position.y = targetY + sepY * effectiveDt

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

return BaseEnemy
