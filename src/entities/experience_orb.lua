--[[
    Experience Orb
    Representa um orbe de experiência que pode ser coletado pelo jogador
]]

local ExperienceOrb = {
    positionX = 0,
    positionY = 0,
    radius = 5,
    experience = 0,
    color = {0.5, 0, 0.5}, -- Cor roxa
    collected = false,
    collectionProgress = 0, -- Progresso da animação de coleta (0 a 1)
    collectionSpeed = 3, -- Velocidade da animação
    initialX = 0, -- Posição X inicial
    initialY = 0, -- Posição Y inicial
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
    return orb
end

function ExperienceOrb:update(dt, player)
    if self.collected then return end
    
    -- Calcula a distância até o jogador
    local dx = player.positionX - self.positionX
    local dy = player.positionY - self.positionY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Se estiver dentro do raio de coleta do jogador
    if distance <= player.collectionRadius then
        -- Inicia a animação de coleta
        self.collectionProgress = self.collectionProgress + dt * self.collectionSpeed
        
        -- Atualiza a posição do orbe
        local t = self.collectionProgress
        -- Função de easing para movimento suave
        local easeOutQuad = 1 - (1 - t) * (1 - t)
        
        -- Atualiza a posição com a animação
        self.positionX = self.initialX + (player.positionX - self.initialX) * easeOutQuad
        self.positionY = self.initialY + (player.positionY - self.initialY) * easeOutQuad
        
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
    
    -- Desenha o orbe
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius)
    
    -- Desenha um brilho
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius * 0.7)
end

return ExperienceOrb 