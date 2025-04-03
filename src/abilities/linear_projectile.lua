--[[
    Linear Projectile Ability
    A projectile that travels in a straight line and deals damage on impact
]]

local BaseAbility = require("src.abilities.base_ability")

local LinearProjectile = setmetatable({}, { __index = BaseAbility })

LinearProjectile.name = "Linear Projectile"
LinearProjectile.cooldown = 0.8
LinearProjectile.damage = 40
LinearProjectile.damageType = "projectile"
LinearProjectile.color = {1, 0.8, 0, 1}

LinearProjectile.speed = 200
LinearProjectile.maxDistance = 300

function LinearProjectile:init(owner)
    BaseAbility.init(self, owner)
    
    -- Estado do projétil
    self.projectile = {
        active = false,
        x = 0,
        y = 0,
        angle = 0,
        distance = 0,
        radius = 5
    }
    
    -- Estado da visualização
    self.visual = {
        active = false,
        targetX = 0,
        targetY = 0,
        angle = 0
    }
end

--[[
    Update the ability state
    @param dt Delta time
]]
function LinearProjectile:update(dt)
    BaseAbility.update(self, dt)
    
    -- Update projectile if active
    if self.projectile.active then
        -- Calculate movement
        local dx = math.cos(self.projectile.angle) * self.speed * dt
        local dy = math.sin(self.projectile.angle) * self.speed * dt
        
        -- Update position
        self.projectile.x = self.projectile.x + dx
        self.projectile.y = self.projectile.y + dy
        
        -- Update distance
        self.projectile.distance = self.projectile.distance + math.sqrt(dx * dx + dy * dy)
        
        -- Check for collisions
        if self.owner.world then
            -- Se o dono é um inimigo, verifica colisão com o jogador
            if self.owner.player then
                local player = self.owner.player
                local dx = player.positionX - self.projectile.x
                local dy = player.positionY - self.projectile.y
                local distance = math.sqrt(dx * dx + dy * dy)
                
                if distance <= (player.radius + 5) then -- 5 é o raio do projétil
                    -- Aplica o dano no jogador
                    if player:takeDamage(self.damage) then
                        -- Se o jogador morreu, remove o projétil
                        self.projectile.active = false
                    end
                end
            else
                -- Se o dono é o jogador, verifica colisão com inimigos
                local enemies = self.owner.world.enemies or {}
                for _, enemy in ipairs(enemies) do
                    if enemy.isAlive then
                        local dx = enemy.positionX - self.projectile.x
                        local dy = enemy.positionY - self.projectile.y
                        local distance = math.sqrt(dx * dx + dy * dy)
                        
                        if distance <= (enemy.radius + self.projectile.radius) then -- 5 é o raio do projétil
                            -- Aplica o dano no inimigo
                            self:applyDamage(enemy)
                            self.projectile.active = false
                            break
                        end
                    end
                end
            end
        end
        
        -- Check if reached max distance
        if self.projectile.distance >= self.maxDistance then
            self.projectile.active = false
        end
    end
end

--[[
    Draw the ability visual
]]
function LinearProjectile:draw()
    -- Draw preview line if active
    if self.visual.active then
        love.graphics.setColor(self.color)
        
        -- Calcula o ponto final da linha baseado no ângulo e distância máxima
        local endX = self.owner.positionX + math.cos(self.visual.angle) * self.maxDistance
        local endY = self.owner.positionY + math.sin(self.visual.angle) * self.maxDistance
        
        love.graphics.line(
            self.owner.positionX,
            self.owner.positionY,
            endX,
            endY
        )
    end
    
    -- Draw projectile if active
    if self.projectile.active then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", self.projectile.x, self.projectile.y, self.projectile.radius)
    end
end

--[[
    Cast the ability
    @param x Target X position or angle (if isAngle is true)
    @param y Target Y position or nil (if isAngle is true)
    @param isAngle Whether x is an angle in radians
    @return boolean Whether the ability was cast successfully
]]
function LinearProjectile:cast(x, y, isAngle)
    if self.cooldownRemaining > 0 then return false end
    
    local angle
    if isAngle then
        -- Se x já é um ângulo, usa diretamente
        angle = x
    else
        -- Calcula o ângulo para o alvo
        local worldX = (x + camera.x) / camera.scale
        local worldY = (y + camera.y) / camera.scale
        local dx = worldX - self.owner.positionX
        local dy = worldY - self.owner.positionY
        angle = math.atan2(dy, dx)
    end
    
    -- Initialize projectile
    self.projectile.active = true
    self.projectile.x = self.owner.positionX
    self.projectile.y = self.owner.positionY
    self.projectile.angle = angle
    self.projectile.distance = 0
    
    -- Atualiza o ângulo da visualização
    self.visual.angle = angle
    
    -- Set cooldown
    self.cooldownRemaining = self.cooldown
    
    return true
end

--[[
    Toggle ability visual
]]
function LinearProjectile:toggleVisual()
    self.visual.active = not self.visual.active
end

--[[
    Get remaining cooldown
    @return number Remaining cooldown time
]]
function LinearProjectile:getCooldownRemaining()
    return self.cooldownRemaining
end

--[[
    Update visual angle based on mouse position
    @param x Mouse X position
    @param y Mouse Y position
]]
function LinearProjectile:updateVisual(x, y)
    if not self.visual.active then return end
    
    -- Calcula o ângulo para o mouse
    local worldX = (x + camera.x) / camera.scale
    local worldY = (y + camera.y) / camera.scale
    local dx = worldX - self.owner.positionX
    local dy = worldY - self.owner.positionY
    self.visual.angle = math.atan2(dy, dx)
end

return LinearProjectile