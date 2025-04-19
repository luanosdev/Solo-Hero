-- src/projectiles/fire_particle.lua

-- Carrega o spritesheet e cria os Quads uma vez
local fireSheet = love.graphics.newImage("assets/attacks/fire_particle/fireSheet5x5.png")
local sheetWidth = fireSheet:getWidth()
local sheetHeight = fireSheet:getHeight()
local frameWidth = sheetWidth / 5
local frameHeight = sheetHeight / 5
local totalFrames = 25
local quads = {}
for row = 0, 4 do
    for col = 0, 4 do
        local frameIndex = row * 5 + col + 1
        quads[frameIndex] = love.graphics.newQuad(col * frameWidth, row * frameHeight, frameWidth, frameHeight, sheetWidth, sheetHeight)
    end
end

local animationFrameTime = 0.04 -- Tempo entre frames (ajuste para velocidade desejada)
local baseScale = 0.8 -- Fator de escala base para a animação (ajuste o tamanho)

local FireParticle = {}
FireParticle.__index = FireParticle

function FireParticle:new(x, y, angle, speed, lifetime, damage, isCritical, enemyManager, color)
    local instance = setmetatable({}, FireParticle)
    
    instance.position = { x = x, y = y }
    instance.angle = angle -- Embora se mova em linha reta, guardar pode ser útil
    instance.speed = speed
    instance.lifetimeRemaining = lifetime
    instance.damage = damage
    instance.isCritical = isCritical -- O crítico é decidido na criação
    instance.enemyManager = enemyManager
    instance.color = color or {1, 1, 1, 1} -- Cor base (branco para não tingir por padrão)
    instance.collisionRadius = 8 -- Raio para colisão (menor que o visual)
    
    instance.velocity = {
        x = math.cos(angle) * speed,
        y = math.sin(angle) * speed
    }
    
    instance.isActive = true
    instance.hitEnemies = {} -- Guarda IDs dos inimigos já atingidos POR ESTA PARTÍCULA
    instance.initialLifetime = lifetime -- Para calcular fade/shrink

    -- Estado da Animação
    instance.animationTimer = 0
    instance.currentFrame = love.math.random(1, totalFrames) -- Inicia em frame aleatório

    return instance
end

function FireParticle:update(dt)
    if not self.isActive then return end

    -- Move a partícula
    self.position.x = self.position.x + self.velocity.x * dt
    self.position.y = self.position.y + self.velocity.y * dt
    
    -- Atualiza tempo de vida
    self.lifetimeRemaining = self.lifetimeRemaining - dt
    if self.lifetimeRemaining <= 0 then
        self.isActive = false
        return
    end
    
    -- Atualiza Animação
    self.animationTimer = self.animationTimer + dt
    while self.animationTimer >= animationFrameTime do
        self.animationTimer = self.animationTimer - animationFrameTime
        self.currentFrame = self.currentFrame + 1
        if self.currentFrame > totalFrames then
            self.currentFrame = 1 -- Volta para o primeiro frame
        end
    end

    -- Verifica colisão com inimigos (e aplica dano)
    self:checkCollision()
end

function FireParticle:checkCollision()
    local enemies = self.enemyManager:getEnemies()
    
    for id, enemy in pairs(enemies) do
        -- Garante que o inimigo tenha um ID (pode não ter em casos raros ou durante a criação)
        if enemy.isAlive and id then 
            local dx = enemy.position.x - self.position.x
            local dy = enemy.position.y - self.position.y
            local distanceSq = dx * dx + dy * dy
            -- Usa o collisionRadius para checar colisão
            local combinedRadius = enemy.radius + self.collisionRadius
            
            -- Verifica colisão (círculo-círculo)
            if distanceSq <= combinedRadius * combinedRadius then
                -- Verifica se esta partícula já atingiu este inimigo
                if not self.hitEnemies[id] then
                    -- Colidiu e ainda não tinha atingido!
                    enemy:takeDamage(self.damage, self.isCritical)
                    self.hitEnemies[id] = true -- Marca que esta partícula já atingiu este inimigo.
                    
                    -- A partícula continua (piercing), mas não atingirá este inimigo novamente.
                end
            end
        end
    end
end

function FireParticle:draw()
    if not self.isActive then return end
    
    -- Calcula a opacidade e escala baseado no tempo de vida restante
    local lifeRatio = math.max(0, self.lifetimeRemaining / self.initialLifetime)
    -- Fade out mais acentuado no final? Ex: lifeRatio = lifeRatio ^ 0.5
    local currentAlpha = lifeRatio 
    -- Encolhe um pouco no final
    local currentScale = baseScale * (lifeRatio * 0.5 + 0.5) 

    if currentScale > 0.1 and currentAlpha > 0.05 then
        -- Define cor com alpha (sem tingir o sprite, a menos que self.color seja diferente de branco)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], currentAlpha)
        
        -- Define o modo de mesclagem para aditivo (bom para fogo em fundo preto)
        local previousBlendMode = love.graphics.getBlendMode()
        love.graphics.setBlendMode("add")

        -- Desenha o frame atual da animação
        love.graphics.draw(
            fireSheet, 
            quads[self.currentFrame], 
            self.position.x, 
            self.position.y, 
            0, -- Rotação (0 para fogo normalmente)
            currentScale, -- Escala X
            currentScale, -- Escala Y
            frameWidth / 2, -- Origem X (centro do frame)
            frameHeight / 2 -- Origem Y (centro do frame)
        )

        -- Restaura o modo de mesclagem anterior
        love.graphics.setBlendMode(previousBlendMode)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return FireParticle 