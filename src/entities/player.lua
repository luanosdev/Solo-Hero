--[[
    Player entity
    Handles player movement and properties
]]

local PlayerState = require("src.entities.player_state")
local EnemyManager = require("src.managers.enemy_manager")
local FloatingTextManager = require("src.managers.floating_text_manager")
local LevelUpModal = require("src.ui.level_up_modal")

local Player = {
    -- Position
    positionX = 0,
    positionY = 0,
    
    -- Movement
    radius = 8,
    collectionRadius = 20, -- Raio base para coletar prismas
    
    -- Class
    class = nil,
    
    -- Base Stats (will be set by class)
    maxHealth = 100,
    currentHealth = 100,
    damage = 0,
    defense = 0,
    baseSpeed = 0,
    attackSpeed = 0,
    criticalChance = 20, -- Chance de crítico
    criticalMultiplier = 1.5, -- Multiplicador de dano crítico
    
    -- Level System
    level = 1,
    experience = 0,
    experienceToNextLevel = 100,
    experienceMultiplier = 1.5, -- Multiplicador de experiência para o próximo nível
    
    -- Game Stats
    gameTime = 0,
    kills = 0,
    gold = 0,
    
    -- State
    state = nil,
    
    -- Abilities
    attackAbility = nil,
    
    -- Auto Attack
    autoAttack = false,
    autoAttackEnabled = false,
    autoAim = false,
    autoAimEnabled = false,
    
    -- Damage cooldown
    lastDamageTime = 0,
    damageCooldown = 0.5,
    
    -- Mouse tracking
    lastMouseX = 0,
    lastMouseY = 0,
}

--[[
    Initialize player with a class
    @param playerClass Class to initialize the player with
]]
function Player:init(playerClass)
    -- Set class and base stats
    self.class = playerClass
    local baseStats = self.class:getBaseStats()
    
    -- Apply base stats
    self.maxHealth = baseStats.health
    self.damage = baseStats.damage
    self.defense = baseStats.defense
    self.baseSpeed = baseStats.speed
    self.attackSpeed = baseStats.attackSpeed
    
    -- Initialize ability
    local AbilityClass = self.class:getInitialAbility()
    self.attackAbility = setmetatable({}, { __index = AbilityClass })
    self.attackAbility:init(self)
    
    -- Initialize state
    self.state = PlayerState
    self.state:init(self.maxHealth)
    
    -- Set initial position
    self.positionX = 400 -- Posição inicial X
    self.positionY = 300 -- Posição inicial Y
    self.currentHealth = self.maxHealth
    self.isAlive = true
    self.lastDamageTime = 0
end

--[[
    Update player movement and speed
    @param dt Delta time (time between frames)
]]
function Player:update(dt)
    if not self.state.isAlive then return end
    
    -- Atualiza o tempo de jogo
    self.gameTime = self.gameTime + dt
    
    -- Update ability
    self.attackAbility:update(dt)
    
    -- Auto Attack logic
    if self.autoAttack or love.mouse.isDown(1) then
        local cooldown = self.attackAbility:getCooldownRemaining()
        if cooldown <= 0 then
            local targetX, targetY = self:getTargetPosition()
            if targetX and targetY then
                self:castAbility(targetX, targetY)
            end
        end
    end
    
    -- Atualiza a prévia da mira
    local targetX, targetY = self:getTargetPosition()
    if targetX and targetY then
        self.attackAbility:updateVisual(targetX, targetY)
    end
    
    -- Atualiza o tempo do último dano
    self.lastDamageTime = self.lastDamageTime + dt
    
    -- Movimento do jogador
    local moveX, moveY = 0, 0
    
    if love.keyboard.isDown("w") then moveY = moveY - 1 end
    if love.keyboard.isDown("s") then moveY = moveY + 1 end
    if love.keyboard.isDown("a") then moveX = moveX - 1 end
    if love.keyboard.isDown("d") then moveX = moveX + 1 end
    
    -- Normaliza o vetor de movimento
    if moveX ~= 0 or moveY ~= 0 then
        local length = math.sqrt(moveX * moveX + moveY * moveY)
        moveX = moveX / length
        moveY = moveY / length
    end
    
    -- Calcula a nova posição
    local newX = self.positionX + moveX * self.baseSpeed * dt
    local newY = self.positionY + moveY * self.baseSpeed * dt
    
    -- Atualiza a posição do jogador
    self.positionX = newX
    self.positionY = newY
end

--[[
    Draw the player on screen
]]
function Player:draw()
    -- Draw ability visual
    self.attackAbility:draw()
    
    -- Draw player body
    love.graphics.setColor(0.918, 0.059, 0.573)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius)
    
    -- Draw health bar
    local baseWidth = 40
    local maxWidth = 60
    local healthBarHeight = 5
    local healthPercentage = self.state:getHealthPercentage()
    
    -- Calculate dynamic width based on max health
    local healthBarWidth = baseWidth + (maxWidth - baseWidth) * (self.state.maxHealth / 200)
    
    -- Draw level circle (agora à esquerda da barra de vida)
    local levelCircleRadius = 8
    local experiencePercentage = self.experience / self.experienceToNextLevel
    
    -- Posição do círculo de nível
    local levelCircleX = self.positionX - healthBarWidth/2 - levelCircleRadius - 5
    local levelCircleY = self.positionY - self.radius - 10 + healthBarHeight/2
    
    -- Fundo do círculo de nível
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.circle("line", levelCircleX, levelCircleY, levelCircleRadius)
    
    -- Preenchimento do círculo de nível
    love.graphics.setColor(0.5, 0, 0.5) -- Cor roxa para experiência
    love.graphics.arc("fill", "open", levelCircleX, levelCircleY, levelCircleRadius, -math.pi/2, -math.pi/2 + (2 * math.pi * experiencePercentage))
    
    -- Número do nível
    love.graphics.setColor(1, 1, 1)
    local levelText = tostring(self.level)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(levelText) * 0.8 -- 0.8 é a escala do texto
    local textHeight = font:getHeight() * 0.8
    
    -- Calcula a posição central do texto
    local textX = levelCircleX - textWidth/2
    local textY = levelCircleY - textHeight/2
    
    love.graphics.print(levelText, textX, textY, 0, 0.8)
    
    -- Health bar background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 10,
        healthBarWidth, 
        healthBarHeight
    )
    
    -- Health bar fill
    love.graphics.setColor(0, 1, 0)
    love.graphics.rectangle("fill", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 10,
        healthBarWidth * healthPercentage, 
        healthBarHeight
    )
    
    -- Draw health bar segments
    love.graphics.setColor(0, 0, 0, 0.3)
    local segmentCount = 5
    local segmentWidth = healthBarWidth / segmentCount
    
    for i = 1, segmentCount - 1 do
        local x = self.positionX - healthBarWidth/2 + segmentWidth * i
        love.graphics.line(
            x,
            self.positionY - self.radius - 10,
            x,
            self.positionY - self.radius - 5
        )
    end
    
    -- Draw health bar border
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("line", 
        self.positionX - healthBarWidth/2, 
        self.positionY - self.radius - 10,
        healthBarWidth, 
        healthBarHeight
    )
    
    -- Draw cooldown bar
    local cooldown = self.attackAbility:getCooldownRemaining()
    if cooldown > 0 then
        local cooldownPercentage = cooldown / self.attackAbility.cooldown
        
        -- Cooldown bar background
        love.graphics.setColor(0.2, 0, 0, 0.3)
        love.graphics.rectangle("fill", 
            self.positionX - healthBarWidth/2, 
            self.positionY - self.radius - 5,
            healthBarWidth, 
            2
        )
        
        -- Cooldown bar fill
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.rectangle("fill", 
            self.positionX - healthBarWidth/2, 
            self.positionY - self.radius - 5,
            healthBarWidth * cooldownPercentage, 
            2
        )
    end
    
    -- Draw class name
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.class.name, 
        self.positionX - 20, 
        self.positionY - self.radius - 25, 
        0, 0.8)
end

--[[
    Take damage
    @param damage Amount of damage to take
    @return boolean Whether the player died from this damage
]]
function Player:takeDamage(damage)
    return self.state:takeDamage(damage, self.defense)
end

--[[
    Heal player
    @param amount Amount of health to restore
]]
function Player:heal(amount)
    self.state:heal(amount)
end

--[[
    Increase max health
    @param amount Amount of health to increase
]]
function Player:increaseMaxHealth(amount)
    self.state:increaseMaxHealth(amount)
end

--[[
    Cast ability
    @param x Mouse X position
    @param y Mouse Y position
    @return boolean Whether the ability was cast successfully
]]
function Player:castAbility(x, y)
    -- Passa a referência do mundo para a habilidade
    self.attackAbility.owner.world = { enemies = EnemyManager:getEnemies() }
    
    local success = self.attackAbility:cast(x, y)
    if success then
        -- Verifica se é uma habilidade instantânea (como ConeSlash)
        if self.attackAbility.damageType == "physical" then
            -- Verifica colisão com inimigos
            local enemies = EnemyManager:getEnemies()
            for _, enemy in ipairs(enemies) do
                if enemy.isAlive then
                    -- Verifica se o inimigo está dentro da área de efeito da habilidade
                    if self.attackAbility:isPointInArea(enemy.positionX, enemy.positionY) then
                        local isCritical = math.random() < self.criticalChance
                        local damage = self.damage * (isCritical and self.criticalMultiplier or 1)
                        
                        if enemy:takeDamage(damage, isCritical) then
                            self.kills = self.kills + 1
                            self:addExperience(enemy.experienceValue)
                            self.gold = self.gold + math.random(1, 5) -- Adiciona 1-5 de ouro por kill
                        end
                    end
                end
            end
        end
        -- Para habilidades de projétil (como LinearProjectile), o dano é aplicado na colisão
    end
    return success
end

--[[
    Toggle ability auto-cast
]]
function Player:toggleAbilityAutoCast()
    self.autoAttackEnabled = not self.autoAttackEnabled
    self.autoAttack = self.autoAttackEnabled
end

--[[
    Toggle ability visual
]]
function Player:toggleAbilityVisual()
    self.attackAbility:toggleVisual()
end

--[[
    Return the ability visual
]]
function Player:getAbilityVisual()
    return self.attackAbility:getVisual()
end

--[[
    Handle mouse movement
    @param x Mouse X position
    @param y Mouse Y position
]]
function Player:mousemoved(x, y)
    self.lastMouseX = x
    self.lastMouseY = y
end

--[[
    Toggle auto aim
]]
function Player:toggleAutoAim()
    self.autoAimEnabled = not self.autoAimEnabled
    self.autoAim = self.autoAimEnabled
end

--[[
    Handle key press
    @param key Key that was pressed
]]
function Player:keypressed(key)
    -- Test functions
    if key == "h" then
        self:heal(20)  -- Heal 20 HP when pressing H
    elseif key == "q" then
        self:increaseMaxHealth(10) -- Increase max health by 10
    elseif key == "g" then
        self:takeDamage(30)  -- Take 30 damage when pressing D
    elseif key == "x" then
        self:toggleAbilityAutoCast() -- Toggle ability auto-cast
    elseif key == "v" then
        self:toggleAbilityVisual() -- Toggle ability visual
    elseif key == "z" then
        self:toggleAutoAim() -- Toggle auto aim
    end
end

--[[
    Handle mouse press
    @param x Mouse X position
    @param y Mouse Y position
    @param button Mouse button pressed
]]
function Player:mousepressed(x, y, button)
    if button == 1 then -- Left click
        -- Realiza um único ataque
        self:castAbility(x, y)
    end
end

--[[
    Handle mouse release
    @param x Mouse X position
    @param y Mouse Y position
    @param button Mouse button released
]]
function Player:mousereleased(x, y, button)
    if button == 1 then -- Left click
        -- Reativa o auto aim se estiver habilitado
        self.autoAim = self.autoAimEnabled
    end
end

function Player:addExperience(amount)
    self.experience = self.experience + amount
    
    -- Verifica se subiu de nível
    if self.experience >= self.experienceToNextLevel then
        self:levelUp()
    end
end

function Player:levelUp()
    self.level = self.level + 1
    self.experience = self.experience - self.experienceToNextLevel
    self.experienceToNextLevel = math.floor(self.experienceToNextLevel * self.experienceMultiplier)
    
    -- Mostra texto de level up
    FloatingTextManager:addText(
        self.positionX,
        self.positionY - self.radius - 30,
        "LEVEL UP!",
        true,
        self,
        {1, 1, 0}
    )
    
    -- Mostra o modal de level up
    LevelUpModal:show()
end

--[[
    Get target position for auto aim
    @return number, number Target X and Y coordinates, or nil if no target found
]]
function Player:getTargetPosition()
    -- Se o auto aim não estiver ativado ou o botão do mouse estiver pressionado, usa a posição do mouse
    if not self.autoAim or love.mouse.isDown(1) then
        return love.mouse.getPosition()
    end
    
    local enemies = EnemyManager:getEnemies()
    local closestEnemy = nil
    local closestDistance = math.huge
    
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.positionX - self.positionX
            local dy = enemy.positionY - self.positionY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance < closestDistance then
                closestDistance = distance
                closestEnemy = enemy
            end
        end
    end
    
    if closestEnemy then
        -- Converte as coordenadas do mundo para coordenadas da tela
        local screenX = closestEnemy.positionX * camera.scale - camera.x
        local screenY = closestEnemy.positionY * camera.scale - camera.y
        
        -- Adiciona um pequeno offset para centralizar no inimigo
        screenX = screenX + closestEnemy.radius * camera.scale
        screenY = screenY + closestEnemy.radius * camera.scale
        
        return screenX, screenY
    end
    
    return love.mouse.getPosition()
end

return Player