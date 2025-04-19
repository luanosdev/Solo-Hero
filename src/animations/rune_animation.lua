local colors = require("src.ui.colors")

local animation = {
    rarityColors = {
        E = colors.rarity.E,
        D = colors.rarity.D,
        C = colors.rarity.C,
        B = colors.rarity.B,
        A = colors.rarity.A,
        S = colors.rarity.S,
        SS = {0.8, 0.3, 0.3, 1.0}, -- Vermelho escuro
        SSS = {0.9, 0.8, 0.3, 1.0} -- Dourado suave
    },
    -- Configurações de flutuação
    floatTimer = 0,
    floatSpeed = 1.5,
    floatAmplitude = 3,
    -- Configurações de brilho
    glowTimer = 0,
    glowSpeed = 2,
    currentLetter = "A",
    letterChangeTimer = 0,
    letterChangeInterval = 1.5,
    letters = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"},
    -- Configurações de tamanho
    size = 16,
    scale = 1.5,
    -- Configurações do prisma
    sides = 8,
    rotation = 0,
    rotationSpeed = 0.5
}

function animation:update(dt)
    -- Atualiza a flutuação
    self.floatTimer = self.floatTimer + dt * self.floatSpeed
    
    -- Atualiza o brilho
    self.glowTimer = self.glowTimer + dt * self.glowSpeed
    
    -- Atualiza a rotação
    self.rotation = self.rotation + dt * self.rotationSpeed
    
    -- Atualiza a mudança de letra
    self.letterChangeTimer = self.letterChangeTimer + dt
    if self.letterChangeTimer >= self.letterChangeInterval then
        self.letterChangeTimer = 0
        self.currentLetter = self.letters[math.random(1, #self.letters)]
    end
end

function animation:draw(x, y, rarity)
    local color = self.rarityColors[rarity] or colors.white
    
    -- Calcula a posição de flutuação
    local floatOffset = math.sin(self.floatTimer) * self.floatAmplitude
    local drawY = y + floatOffset
    
    -- Desenha a aura ciano
    local glowIntensity = 0.3 + math.sin(self.glowTimer) * 0.2
    if rarity == "S" or rarity == "SS" or rarity == "SSS" then
        glowIntensity = glowIntensity + 0.2
    end
    
    -- Aura externa ciano
    love.graphics.setColor(0.2, 0.8, 0.9, glowIntensity * 0.5)
    love.graphics.circle("fill", x, drawY, self.size * self.scale * 0.9)
    
    -- Aura interna ciano
    love.graphics.setColor(0.2, 0.8, 0.9, glowIntensity * 0.3)
    love.graphics.circle("fill", x, drawY, self.size * self.scale * 0.7)
    
    -- Desenha o prisma
    love.graphics.push()
    love.graphics.translate(x, drawY)
    love.graphics.rotate(self.rotation)
    
    -- Cor mística para o prisma (roxo com brilho)
    local prismColor = {0.4, 0.2, 0.6, 0.9} -- Roxo místico
    love.graphics.setColor(prismColor)
    
    -- Desenha o prisma de 8 lados
    local points = {}
    for i = 1, self.sides do
        local angle = (i / self.sides) * math.pi * 2
        local px = math.cos(angle) * self.size
        local py = math.sin(angle) * self.size
        table.insert(points, px)
        table.insert(points, py)
    end
    
    love.graphics.polygon("fill", points)
    
    -- Adiciona brilho nas bordas do prisma
    love.graphics.setColor(0.6, 0.4, 0.8, 0.5) -- Roxo mais claro
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", points)
    
    -- Adiciona um ponto de luz no centro
    love.graphics.setColor(0.2, 0.8, 0.9, 0.3) -- Ciano suave
    love.graphics.circle("fill", 0, 0, self.size * 0.3)
    
    love.graphics.pop()
    
    -- Desenha a letra
    love.graphics.setColor(0.2, 0.8, 0.9, 0.9) -- Letra ciano
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(self.currentLetter)
    local textHeight = font:getHeight()
    love.graphics.print(
        self.currentLetter,
        x - textWidth/2,
        drawY - textHeight/2
    )
    
    love.graphics.setColor(1, 1, 1, 1)
end

return animation 