local FloatingText = {
    positionX = 0,
    positionY = 0,
    text = "",
    color = {1, 1, 1}, -- Cor padrão (branco)
    alpha = 1,
    scale = 1,
    velocityY = -20, -- Velocidade vertical (movimento para cima)
    lifetime = 0.5, -- Tempo de vida em segundos
    currentTime = 0,
    isCritical = false,
    target = nil, -- Referência ao inimigo
    offsetY = 0 -- Offset vertical em relação ao inimigo
}

function FloatingText:new(x, y, text, isCritical, target, customColor)
    local floatingText = setmetatable({}, { __index = self })
    floatingText.positionX = x
    floatingText.positionY = y
    floatingText.text = text
    floatingText.isCritical = isCritical
    floatingText.target = target
    floatingText.offsetY = -20 -- Começa 20 pixels acima do inimigo
    
    -- Define a cor do texto
    if customColor then
        floatingText.color = customColor
    else
        -- Ajusta propriedades baseado se é crítico ou não
        if isCritical then
            floatingText.color = {1, 0.5, 0} -- Laranja para críticos
            floatingText.scale = 1.5
            floatingText.velocityY = -80 -- Movimento mais rápido
            floatingText.lifetime = 0.8 -- Vida mais curta
        else
            floatingText.color = {1, 1, 1} -- Branco para dano normal
        end
    end
    
    return floatingText
end

function FloatingText:update(dt)
    self.currentTime = self.currentTime + dt
    
    -- Atualiza posição baseado no alvo
    if self.target and self.target.isAlive then
        self.positionX = self.target.positionX
        self.positionY = self.target.positionY + self.offsetY
    end
    
    -- Atualiza offset vertical
    self.offsetY = self.offsetY + self.velocityY * dt
    
    -- Atualiza transparência
    local fadeStart = self.lifetime * 0.7 -- Começa a desaparecer nos últimos 30% do tempo
    if self.currentTime > fadeStart then
        self.alpha = 1 - ((self.currentTime - fadeStart) / (self.lifetime - fadeStart))
    end
    
    -- Retorna true se ainda está vivo
    return self.currentTime < self.lifetime
end

function FloatingText:draw()
    -- Define a cor com transparência
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
    
    -- Desenha o texto centralizado
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(self.text)
    local textHeight = font:getHeight()
    
    -- Desenha o texto na posição do mundo (não na tela)
    love.graphics.push()
    love.graphics.translate(self.positionX, self.positionY)
    love.graphics.scale(self.scale)
    
    -- Desenha a borda preta
    love.graphics.setColor(0, 0, 0, self.alpha)
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.print(self.text, -textWidth/2 + dx, -textHeight/2 + dy)
            end
        end
    end
    
    -- Desenha o texto principal
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
    love.graphics.print(self.text, -textWidth/2, -textHeight/2)
    
    love.graphics.pop()
end

return FloatingText