local PlayerManager = require("src.managers.player_manager")

--[[
    Experience Orb
    Representa um orbe de experiência que pode ser coletado pelo jogador
]]

local ExperienceOrb = {
    positionX = 0,
    positionY = 0,
    radius = 5,
    experience = 0,
    color = {0.5, 0, 0.5}, -- Cor roxa base
    collected = false,
    collectionProgress = 0, -- Progresso da animação de coleta (0 a 1)
    collectionSpeed = 3, -- Velocidade da animação
    initialX = 0, -- Posição X inicial
    initialY = 0, -- Posição Y inicial
    
    -- Novas propriedades para animação
    levitationHeight = 5, -- Altura máxima da levitação
    levitationSpeed = 2, -- Velocidade da levitação
    levitationTime = 0, -- Timer para a animação de levitação
    flameParticles = {}, -- Partículas da chama
    maxFlameParticles = 8, -- Número máximo de partículas
    particleLifetime = 0.5, -- Tempo de vida das partículas
}

function ExperienceOrb:new(x, y, exp)
    local orb = setmetatable({}, { __index = self })
    orb.positionX = x
    orb.positionY = y
    orb.initialX = x
    orb.initialY = y
    orb.experience = exp
    orb.collected = false
    orb.collectionProgress = 0
    orb.levitationTime = math.random() * math.pi * 2 -- Inicia em um ponto aleatório da animação
    orb.flameParticles = {}
    return orb
end

function ExperienceOrb:update(dt)
    if self.collected then return end
    
    -- Atualiza a animação de levitação
    self.levitationTime = self.levitationTime + dt * self.levitationSpeed
    local levitationOffset = math.sin(self.levitationTime) * self.levitationHeight
    
    -- Atualiza as partículas da chama
    for i = #self.flameParticles, 1, -1 do
        local particle = self.flameParticles[i]
        particle.lifetime = particle.lifetime - dt
        particle.y = particle.y - dt * 20 -- Move para cima
        particle.alpha = particle.alpha - dt * 2 -- Fade out
        
        if particle.lifetime <= 0 then
            table.remove(self.flameParticles, i)
        end
    end
    
    -- Adiciona novas partículas se necessário
    if #self.flameParticles < self.maxFlameParticles then
        local angle = math.random() * math.pi * 2
        local distance = math.random() * self.radius * 0.5
        table.insert(self.flameParticles, {
            x = math.cos(angle) * distance,
            y = math.sin(angle) * distance,
            lifetime = self.particleLifetime,
            alpha = 1,
            size = math.random(2, 4)
        })
    end
    
    -- Calcula a distância até o jogador
    local dx = PlayerManager.player.x - self.positionX
    local dy = PlayerManager.player.y - (self.positionY + levitationOffset)
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Se estiver dentro do raio de coleta do jogador
    if distance <= PlayerManager.collectionRadius then
        -- Inicia a animação de coleta
        self.collectionProgress = self.collectionProgress + dt * self.collectionSpeed
        
        -- Atualiza a posição do orbe
        local t = self.collectionProgress
        -- Função de easing para movimento suave
        local easeOutQuad = 1 - (1 - t) * (1 - t)
        
        -- Atualiza a posição com a animação
        self.positionX = self.initialX + (PlayerManager.player.x - self.initialX) * easeOutQuad
        self.positionY = self.initialY + (PlayerManager.player.y - self.initialY) * easeOutQuad
        
        -- Se a animação terminou
        if self.collectionProgress >= 1 then
            self.collected = true
            return true
        end
    end
    
    return false
end

function ExperienceOrb:draw()
    if self.collected then return end
    
    -- Calcula o offset de levitação atual
    local levitationOffset = math.sin(self.levitationTime) * self.levitationHeight
    
    -- Desenha a sombra
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", self.positionX, self.positionY + 3, self.radius * 0.8)
    
    -- Desenha as partículas da chama
    for _, particle in ipairs(self.flameParticles) do
        love.graphics.setColor(0.2, 0.6, 1, particle.alpha) -- Cor azul para a chama
        love.graphics.circle("fill", 
            self.positionX + particle.x, 
            self.positionY + particle.y + levitationOffset, 
            particle.size
        )
    end
    
    -- Desenha o orbe principal
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.positionX, self.positionY + levitationOffset, self.radius)
    
    -- Desenha o brilho interno
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", self.positionX, self.positionY + levitationOffset, self.radius * 0.7)
    
    -- Desenha o brilho externo (aura)
    love.graphics.setColor(0.2, 0.6, 1, 0.3) -- Cor azul para a aura
    love.graphics.circle("fill", self.positionX, self.positionY + levitationOffset, self.radius * 1.5)
end

return ExperienceOrb 