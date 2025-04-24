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
    
    -- Equipment
    equippedWeapon = nil,
    
    -- Level System
    level = 1,
    experience = 0,
    experienceToNextLevel = 50,
    experienceMultiplier = 1.10, -- Multiplicador de experiência para o próximo nível
    
    -- Game Stats
    gameTime = 0,
    kills = 0,
    gold = 0,
    
    -- State
    state = nil,
    
    -- Abilities
    runes = {}, -- Lista de habilidades de runas
    attackAbility = nil, -- Habilidade principal de ataque
    
    -- Auto Attack
    autoAttack = false,
    autoAttackEnabled = false,
    autoAim = false,
    autoAimEnabled = false,
    
    -- Damage cooldown
    lastDamageTime = 0,
    damageCooldown = 5.0, -- Tempo de espera após receber dano para começar a regenerar
    
    -- Health regeneration
    lastRegenTime = 0,
    regenInterval = 1.0, -- Intervalo de regeneração em segundos
    regenAmount = 1, -- Quantidade fixa de HP recuperado
    accumulatedRegen = 0, -- HP acumulado para regeneração
    
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
    
    -- Initialize state with base stats
    self.state = PlayerState
    self.state:init(baseStats)
    
    -- Equip starting weapon
    if self.class.startingWeapon then
        self:equipWeapon(self.class.startingWeapon)
    end
    
    -- Set initial position
    self.positionX = 400 -- Posição inicial X
    self.positionY = 300 -- Posição inicial Y
    self.isAlive = true
    self.lastDamageTime = 0
end

--[[
    Equip a weapon
    @param weapon The weapon to equip
]]
function Player:equipWeapon(weapon)
    -- Desequipa a arma atual se houver uma
    if self.equippedWeapon then
        self.equippedWeapon:unequip()
    end
    
    -- Equipa a nova arma
    self.equippedWeapon = weapon:new()
    self.equippedWeapon:equip(self)
    
    -- Atualiza a habilidade de ataque com base na arma
    self.attackAbility = self.equippedWeapon:getAttackInstance()
end

--[[
    Add a new rune ability to the player
    @param rune The rune ability to add
]]
function Player:addRune(rune)
    if not rune then return end
    
    -- Adiciona a runa à lista de runas
    table.insert(self.runes, rune)
    
    -- Inicializa a runa se necessário
    if rune.init then
        rune:init(self)
    end
end

--[[
    Update player movement and speed
    @param dt Delta time (time between frames)
]]
function Player:update(dt)
    if not self.state.isAlive then return end
    
    -- Atualiza o tempo de jogo
    self.gameTime = self.gameTime + dt
    
    -- Atualiza o tempo desde o último dano
    self.lastDamageTime = self.lastDamageTime + dt
    
    -- Atualiza a regeneração de vida
    if self.state.currentHealth < self.state.maxHealth and self.lastDamageTime >= self.damageCooldown then
        local hpPerSecond = self.state:getTotalHealthRegen()
        self.accumulatedRegen = self.accumulatedRegen + (hpPerSecond * dt)
        
        -- Se acumulou pelo menos 1 HP, recupera
        if self.accumulatedRegen >= 1 then
            FloatingTextManager:addText(
                self.positionX,
                self.positionY - self.radius - 40,
                "+1",
                false,
                self,
                {0, 1, 0}
            )
            self:heal(1)
            self.accumulatedRegen = self.accumulatedRegen - 1
        end
    else
        self.accumulatedRegen = 0 -- Reseta o acumulado quando a vida está cheia ou em cooldown
    end
    
    -- Update main ability
    self.attackAbility:update(dt)

    -- Update all rune abilities
    for _, rune in ipairs(self.runes) do
        rune:update(dt)
        
        -- Executa a runa automaticamente se o cooldown zerar
        if rune.cooldownRemaining <= 0 then
            rune:cast(self.positionX, self.positionY)
        end
    end
    
    -- Auto Attack logic
    if self.autoAttack or love.mouse.isDown(1) then
        local cooldown = self.attackAbility:getCooldownRemaining()
        if cooldown <= 0 then
            local targetX, targetY = self:getTargetPosition()
            if targetX and targetY then
                self:attack(targetX, targetY)
            end
        end
    end
    
    -- Atualiza a prévia da mira
    local targetX, targetY = self:getTargetPosition()
    if targetX and targetY then
        self.attackAbility:updateVisual(targetX, targetY)
    end
    
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
    local newX = self.positionX + moveX * self.state:getTotalSpeed() * dt
    local newY = self.positionY + moveY * self.state:getTotalSpeed() * dt
    
    -- Atualiza a posição do jogador
    self.positionX = newX
    self.positionY = newY
end

--[[
    Draw the player on screen
]]
function Player:draw()
    -- Draw main ability
    self.attackAbility:draw()

    -- Draw all rune abilities
    for _, rune in ipairs(self.runes) do
        rune:draw()
    end
    
    -- Draw player body
    love.graphics.setColor(0.918, 0.059, 0.573)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius)
    
    -- Draw health bar
    local baseWidth = 40
    local maxWidth = 60
    local healthBarHeight = 5
    local healthPercentage = self.state:getHealthPercentage()
    
    -- Calculate dynamic width based on max health
    local healthBarWidth = baseWidth + (maxWidth - baseWidth) * (self.state:getTotalHealth() / 200)
    
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
    self.lastDamageTime = 0 -- Reseta o tempo desde o último dano
    return self.state:takeDamage(damage)
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
        self:attack(x, y)
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
    -- Calcula o novo valor necessário para o próximo nível de forma acumulativa
    local previousRequired = self.experienceToNextLevel
    self.experienceToNextLevel = previousRequired + math.floor(previousRequired * self.experienceMultiplier)
    
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