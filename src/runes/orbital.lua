--[[
    Orbital Rune
    Cria orbes que orbitam ao redor do jogador e causam dano aos inimigos próximos
]]

local OrbitalRune = {}

OrbitalRune.name = "Orbes Orbitais"
OrbitalRune.description = "Cria orbes que orbitam ao redor do jogador e causam dano aos inimigos próximos"
OrbitalRune.damage = 150
OrbitalRune.damageType = "orbital"
OrbitalRune.color = {0, 0.8, 1, 0.3} -- Cor azul para os orbes

OrbitalRune.orbitRadius = 90 -- Raio da órbita
OrbitalRune.orbCount = 3 -- Número de orbes
OrbitalRune.orbRadius = 20 -- Tamanho de cada orbe
OrbitalRune.rotationSpeed = 2 -- Velocidade de rotação em radianos por segundo
OrbitalRune.shadowOffset = 3 -- Deslocamento da sombra
OrbitalRune.shadowAlpha = 0.2 -- Transparência da sombra

-- Configuração da animação
OrbitalRune.animation = {
    width = 67,
    height = 67,
    frameCount = 7,
    frameTime = 0.1,
    scale = OrbitalRune.orbRadius / 33.5, -- Ajustado para corresponder ao orbRadius (8 / 33.5 = 0.24)
    frames = {}, -- Inicializa a tabela de frames
    currentFrame = 1,
    timer = 0
}

function OrbitalRune:init(playerManager)
    self.playerManager = playerManager

    -- Carrega os frames da animação
    for i = 1, self.animation.frameCount do
        self.animation.frames[i] = love.graphics.newImage("assets/abilities/orbital/orbital_" .. i .. ".png")
    end

    -- Estado dos orbes
    self.orbs = {}
    for i = 1, self.orbCount do
        table.insert(self.orbs, {
            angle = (i - 1) * (2 * math.pi / self.orbCount), -- Distribui os orbes igualmente
            damagedEnemies = {}, -- Cooldown específico deste orbe para cada inimigo
            lastDamageTime = 0, -- Tempo desde o último dano DESTE ORBE
            damageCooldown = 0.1, -- Cooldown GERAL do orbe após atingir QUALQUER inimigo (baixo)
            enemyCooldown = 2 -- Cooldown para ESTE ORBE atingir o MESMO inimigo novamente (curto)
        })
    end
end

function OrbitalRune:update(dt, enemies)
    -- Atualiza a animação
    self.animation.timer = self.animation.timer + dt
    if self.animation.timer >= self.animation.frameTime then
        self.animation.timer = self.animation.timer - self.animation.frameTime
        self.animation.currentFrame = self.animation.currentFrame + 1
        if self.animation.currentFrame > self.animation.frameCount then
            self.animation.currentFrame = 1
        end
    end

    -- Atualiza a posição dos orbes
    for i, orb in ipairs(self.orbs) do
        -- Atualiza o ângulo de rotação
        orb.angle = orb.angle + self.rotationSpeed * dt
        
        -- Atualiza o tempo desde o último dano GERAL deste orbe
        orb.lastDamageTime = orb.lastDamageTime + dt

        -- Atualiza cooldowns específicos deste orbe para inimigos
        local enemiesToRemoveFromOrbCD = {}
        for enemyId, time in pairs(orb.damagedEnemies) do
            orb.damagedEnemies[enemyId] = time - dt
            if orb.damagedEnemies[enemyId] <= 0 then
                table.insert(enemiesToRemoveFromOrbCD, enemyId)
            end
        end
        for _, enemyId in ipairs(enemiesToRemoveFromOrbCD) do
            orb.damagedEnemies[enemyId] = nil
        end
        
        -- Aplica dano
        self:applyOrbitalDamage(orb, i, dt, enemies)
    end
end

function OrbitalRune:draw()
    local playerX = self.playerManager.player.position.x
    local playerY = self.playerManager.player.position.y + 25 -- Ajusta para ficar nos pés do sprite
    
    for _, orb in ipairs(self.orbs) do
        -- Calcula a posição do orbe
        local orbX = playerX + math.cos(orb.angle) * self.orbitRadius
        local orbY = playerY + math.sin(orb.angle) * self.orbitRadius

        -- Desenha o orbe animado
        local frame = self.animation.frames[self.animation.currentFrame]
        if frame then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                frame,
                orbX,
                orbY,
                0, -- Rotação
                self.animation.scale, -- Escala X
                self.animation.scale, -- Escala Y
                frame:getWidth() / 2, -- Origem X (centro)
                frame:getHeight() / 2  -- Origem Y (centro)
            )
        end
    end
end

function OrbitalRune:cast()
    return true
end

function OrbitalRune:applyDamage(target)
    if not target or not target.takeDamage then return false end
    return target:takeDamage(self.damage)
end

function OrbitalRune:applyOrbitalDamage(orb, orbIndex, dt, enemies)
    if not enemies then return end
    
    -- 1. Verifica se ESTE ORBE pode causar dano (cooldown geral do orbe)
    if orb.lastDamageTime < orb.damageCooldown then return end
    
    -- Posições
    local playerX = self.playerManager.player.position.x
    local playerY = self.playerManager.player.position.y
    local orbX = playerX + math.cos(orb.angle) * self.orbitRadius
    local orbY = playerY + math.sin(orb.angle) * self.orbitRadius
    local damageRadius = self.orbRadius * 2

    local enemiesHitThisPass = {}
    local anEnemyWasHit = false

    for _, enemy in ipairs(enemies) do
        if enemy.isAlive and enemy.id then
            local enemyId = enemy.id
            
            -- Distância
            local dx = enemy.position.x - orbX
            local dy = enemy.position.y - orbY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Verifica colisão
            if distance <= damageRadius then
                if not orb.damagedEnemies[enemyId] and not enemiesHitThisPass[enemyId] then
                    local died = self:applyDamage(enemy)
                    
                    enemiesHitThisPass[enemyId] = true 
                    orb.damagedEnemies[enemyId] = orb.enemyCooldown 
                    anEnemyWasHit = true
                end
            end
        end
    end

    -- Se este orbe atingiu QUALQUER inimigo nesta passagem, reinicia seu cooldown geral.
    if anEnemyWasHit then
        orb.lastDamageTime = 0
    end
end

return OrbitalRune 