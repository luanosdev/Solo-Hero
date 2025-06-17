--------------------------------------------------------------------------------
-- Pellet Projectile
-- Um projétil simples, circular, usado por armas como escopetas.
--------------------------------------------------------------------------------

---@class Pellet
---@field position table {x, y}
---@field angle number
---@field speed number
---@field maxRange number
---@field damage number
---@field isCritical boolean
---@field spatialGrid SpatialGridIncremental
---@field color table
---@field velocity table {x, y}
---@field distanceTraveled number
---@field isActive boolean
---@field hitEnemies table
---@field currentPiercing number
---@field radius number Raio visual e de colisão do projétil.
---@field knockbackPower number
---@field knockbackForce number
---@field playerStrength number
---@field playerManager PlayerManager
---@field weaponInstance BaseWeapon
local Pellet = {}
Pellet.__index = Pellet

-- Raio base do projétil antes de qualquer escala de área.
local BASE_RADIUS = 4

--- Cria uma nova instância de Pellet.
function Pellet:new(
    x, y, angle, speed, range, damage, isCritical, spatialGrid, color,
    piercing, areaScale, knockbackPower, knockbackForce, playerStrength,
    playerManager, weaponInstance
)
    local instance = setmetatable({}, Pellet)
    instance:reset(
        x, y, angle, speed, range, damage, isCritical, spatialGrid, color,
        piercing, areaScale, knockbackPower, knockbackForce, playerStrength,
        playerManager, weaponInstance
    )
    return instance
end

--- Reseta um Pellet para reutilização (pooling).
function Pellet:reset(
    x, y, angle, speed, range, damage, isCritical, spatialGrid, color,
    piercing, areaScale, knockbackPower, knockbackForce, playerStrength,
    playerManager, weaponInstance
)
    self.position = self.position or { x = 0, y = 0 }
    self.position.x = x
    self.position.y = y

    self.angle = angle
    self.speed = speed
    self.maxRange = range or 100
    self.damage = damage
    self.isCritical = isCritical
    self.spatialGrid = spatialGrid
    self.color = color or { 1, 1, 1, 1 }
    self.currentPiercing = piercing or 1
    self.radius = BASE_RADIUS * (areaScale or 1)

    self.knockbackPower = knockbackPower or 0
    self.knockbackForce = knockbackForce or 0
    self.playerStrength = playerStrength or 0
    self.playerManager = playerManager
    self.weaponInstance = weaponInstance

    self.velocity = self.velocity or { x = 0, y = 0 }
    self.velocity.x = math.cos(angle) * speed
    self.velocity.y = math.sin(angle) * speed

    self.distanceTraveled = 0
    self.isActive = true
    self.hitEnemies = self.hitEnemies or {}
    for k in pairs(self.hitEnemies) do self.hitEnemies[k] = nil end
end

function Pellet:update(dt)
    if not self.isActive then return end

    local moveX = self.velocity.x * dt
    local moveY = self.velocity.y * dt
    self.position.x = self.position.x + moveX
    self.position.y = self.position.y + moveY

    self.distanceTraveled = self.distanceTraveled + math.sqrt(moveX ^ 2 + moveY ^ 2)

    if self.distanceTraveled >= self.maxRange then
        self.isActive = false
        return
    end

    self:checkCollision()
end

function Pellet:checkCollision()
    if not self.spatialGrid then return end

    local nearbyEnemies = self.spatialGrid:getNearbyEntities(self.position.x, self.position.y, self.radius, nil)

    for _, enemy in ipairs(nearbyEnemies) do
        if enemy and enemy.isAlive and not self.hitEnemies[enemy.id] then
            local dx = self.position.x - enemy.position.x
            local dy = self.position.y - enemy.position.y
            local distanceSq = dx * dx + dy * dy
            local sumOfRadii = self.radius + enemy.radius
            local sumOfRadiiSq = sumOfRadii * sumOfRadii

            if distanceSq <= sumOfRadiiSq then
                self.hitEnemies[enemy.id] = true

                -- TODO: Chamar helper de combate para aplicar dano e knockback.
                -- CombatHelpers.applyHit(self, enemy)

                self.currentPiercing = self.currentPiercing - 1
                if self.currentPiercing < 0 then
                    self.isActive = false
                    return -- Sai da função após desativar
                end
            end
        end
    end
end

function Pellet:draw()
    if not self.isActive then return end
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.position.x, self.position.y, self.radius)
end

return Pellet
