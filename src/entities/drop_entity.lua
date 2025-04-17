--[[
    Drop Entity
    Representa um item dropado no mundo que pode ser coletado pelo jogador
]]

local DropEntity = {
    position = {
        x = 0,
        y = 0
    },
    initialPosition = {
        x = 0,
        y = 0
    },
    radius = 10,
    config = nil,
    collected = false,
    collectionProgress = 0,
    collectionSpeed = 3,
    initialY = 0,
    color = {1, 1, 1},
    glowEffect = true,
    glowTimer = 0
}

function DropEntity:new(x, y, config)
    local drop = setmetatable({}, { __index = self })
    drop.initialPosition = {
        x = x,
        y = y
    }
    drop.position = drop.initialPosition
    drop.config = config
    drop.collected = false
    drop.collectionProgress = 0
    
    -- Define a cor baseado no tipo de drop
    if config.type == "rune" then
        drop.color = {1, 0.5, 0} -- Laranja para runas
    elseif config.type == "gold" then
        drop.color = {1, 0.84, 0} -- Dourado para ouro
    elseif config.type == "experience" then
        drop.color = {0.5, 0, 0.5} -- Roxo para experiência
    end
    
    return drop
end

function DropEntity:update(dt, playerManager)
    if self.collected then return true end
    
    -- Atualiza o efeito de brilho
    self.glowTimer = self.glowTimer + dt
    
    -- Calcula a distância até o jogador
    local dx = playerManager.player.position.x - self.position.x
    local dy = playerManager.player.position.y - self.position.y
    local distance = math.sqrt(dx * dx + dy * dy)
    
    -- Se estiver dentro do raio de coleta do jogador
    if distance <= playerManager.collectionRadius then
        -- Inicia a animação de coleta
        self.collectionProgress = self.collectionProgress + dt * self.collectionSpeed
        
        -- Atualiza a posição do drop
        local t = self.collectionProgress
        -- Função de easing para movimento suave
        local easeOutQuad = 1 - (1 - t) * (1 - t)
        
        -- Atualiza a posição com a animação
        self.position.x = self.initialPosition.x + (playerManager.player.position.x - self.initialPosition.x) * easeOutQuad
        self.position.y = self.initialPosition.y + (playerManager.player.position.y - self.initialPosition.y) * easeOutQuad
        
        -- Se a animação terminou
        if self.collectionProgress >= 1 then
            self.collected = true
            return true
        end
    end
    
    return false
end

function DropEntity:draw()
    if self.collected then return end
    
    -- Desenha o efeito de brilho
    if self.glowEffect then
        local glowAlpha = 0.3 + math.sin(self.glowTimer * 2) * 0.2
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], glowAlpha)
        love.graphics.circle("fill", self.position.x, self.position.y, self.radius * 1.5)
    end
    
    -- Desenha o drop
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.position.x, self.position.y, self.radius)
    
    -- Desenha um brilho interno
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", self.position.x, self.position.y, self.radius * 0.7)
end

return DropEntity 