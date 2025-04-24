--[[
    Level Up Animation (Isometric Hades Bomb Style with ENHANCED Rotation)
    Animação baseada na Hades Bomb (Crimson) do Rocket League,
    com simulação de rotação 3D aprimorada nos pedaços da explosão.
]]

local LevelUpAnimation = {
    -- Estado da animação
    effectActive = false,
    effectTimer = 0,
    effectDuration = 1.6, -- Duração total em segundos (ajustada)
    
    -- Partículas
    activeChunks = {},     -- Pedaços principais da explosão
    activeInitialSparks = {}, -- Faíscas iniciais

    -- Estado do Anel de Choque
    ringRadius = 0,
    ringAlpha = 0,
    ringMaxRadius = 250,   -- Quão grande o anel fica
    ringDuration = 0.5,    -- Quanto tempo o anel leva para expandir e sumir

    -- Estado do Núcleo
    coreAlpha = 0,
    coreRadius = 0,
    coreDuration = 0.1,   -- Duração muito curta do núcleo brilhante

    -- Parâmetros de Emissão (Burst)
    chunkBurstAmount = 160, -- Quantos pedaços criar no início
    sparkBurstAmount = 90,  -- Quantas faíscas iniciais criar

    -- Cores
    chunkColorDarkRed = { r = 0.5, g = 0.05, b = 0.05 },
    chunkColorBlack = { r = 0.1, g = 0.1, b = 0.1 },
    sparkColorRed = { r = 1.0, g = 0.2, b = 0.1 },
    ringColorRed = { r = 1.0, g = 0.1, b = 0.1 },
    coreColorYellow = { r = 1.0, g = 1.0, b = 0.5 },

     -- Offset para desenhar na base isométrica (ajuste conforme seu sprite)
    baseOffsetY = 15, 

    -- << PARÂMETROS DE ROTAÇÃO/ESCALA AJUSTADOS PARA ÊNFASE >>
    -- *** AJUSTE ESTE VALOR SIGNIFICATIVAMENTE! ***
    -- Aumenta a velocidade com que os pedaços giram em torno do centro.
    chunkRotationSpeedMagnitude = 550, -- << AUMENTADO BASTANTE (Valor anterior: 250) 
    
    -- *** AJUSTE ESTE VALOR PARA VISIBILIDADE DA PROFUNDIDADE ***
    -- Controla o quão menores/maiores os pedaços ficam com a distância Y.
    chunkDepthScaleFactor = 0.6,     -- << AUMENTADO (Valor anterior: 0.5)

    -- Distância Y para escala máxima (depende da velocidade vertical)
    chunkMaxDepthY = 120,            -- << Talvez reduzir um pouco se a explosão for mais baixa
    
    -- *** AJUSTE ESTE VALOR PARA CONTROLAR A DESACELERAÇÃO ***
    -- Menor valor = menos atrito, o giro persiste mais.
    chunkDrag = 0.15                 -- << REDUZIDO (Valores anteriores: 0.25, 0.15)
}

function LevelUpAnimation:new()
    local anim = setmetatable({}, { __index = self })
    anim.effectActive = false
    anim.effectTimer = 0
    anim.activeChunks = {}
    anim.activeInitialSparks = {}
    anim.ringRadius = 0
    anim.ringAlpha = 0
    anim.coreAlpha = 0
    anim.coreRadius = 0
    anim.isComplete = false 
    return anim
end

-- Função para criar um "pedaço" da explosão - COM VELOCIDADE TANGENCIAL AJUSTADA
function LevelUpAnimation:createChunk(pos)
    local baseColor
    if love.math.random(1, 3) <= 2 then 
        baseColor = self.chunkColorBlack 
    else 
        baseColor = self.chunkColorDarkRed 
    end
    
    -- Posição inicial na base
    local startX = pos.x + love.math.random(-5, 5)
    local startY = pos.y + self.baseOffsetY + love.math.random(-5, 5)

    -- Calcula direção de explosão RADIAL (para fora)
    local radialAngle = love.math.random() * math.pi * 2
    -- Reduzi um pouco a velocidade radial para não sobrepor tanto o giro
    local radialSpeedMagnitude = love.math.random(200, 450) -- << REDUZIDO (Era 250-550)
    local radialSpeedX = math.cos(radialAngle) * radialSpeedMagnitude
    local radialSpeedY = math.sin(radialAngle) * radialSpeedMagnitude * 0.6 - love.math.random(40, 120) -- Reduzi um pouco o impulso vertical

    -- Calcula direção TANGENCIAL (para girar, perpendicular à radial)
    local tangentAngle = radialAngle + math.pi / 2 -- Ou -math.pi/2 para girar no outro sentido
    -- Usa o valor ALTO de chunkRotationSpeedMagnitude para forçar o giro
    local tangentSpeedMagnitude = self.chunkRotationSpeedMagnitude * love.math.random(0.8, 1.2) -- Varia um pouco a velocidade de giro
    local tangentSpeedX = math.cos(tangentAngle) * tangentSpeedMagnitude
    local tangentSpeedY = math.sin(tangentAngle) * tangentSpeedMagnitude * 0.4 -- Fator isométrico menor para giro

    -- Combina as velocidades radial e tangencial
    local finalSpeedX = radialSpeedX + tangentSpeedX
    local finalSpeedY = radialSpeedY + tangentSpeedY

    local baseWidth = love.math.random(12, 30) -- Guarda o tamanho base para scaling
    local baseHeight = love.math.random(8, 22)

    local chunk = {
        x = startX,
        y = startY,
        baseWidth = baseWidth, -- Guarda tamanho original
        baseHeight = baseHeight, -- Guarda tamanho original
        width = baseWidth,     -- Tamanho atual (será modificado)
        height = baseHeight,    -- Tamanho atual (será modificado)
        angle = love.math.random() * math.pi * 2, 
        speedX = finalSpeedX,
        speedY = finalSpeedY, 
        rotationSpeed = love.math.random(-math.pi * 2.5, math.pi * 2.5), -- Rotação do próprio retângulo
        life = love.math.random(0.6, 1.0),       -- << Vida um pouco mais longa para ver giro
        maxLife = 0,                             
        color = { r = baseColor.r, g = baseColor.g, b = baseColor.b }, 
        alpha = love.math.random(0.8, 1.0)        
    }
    chunk.maxLife = chunk.life 
    table.insert(self.activeChunks, chunk)
end

-- Função para criar uma faísca inicial (sem mudanças significativas)
function LevelUpAnimation:createInitialSpark(pos)
    local angle = love.math.random() * math.pi * 2
    local speedMagnitude = love.math.random(400, 700) 
    local speedX = math.cos(angle) * speedMagnitude
    local speedY = math.sin(angle) * speedMagnitude * 0.3 - love.math.random(0, 50) 

    local spark = {
        x = pos.x + love.math.random(-5, 5), 
        y = pos.y + self.baseOffsetY + love.math.random(-5, 5),
        radius = love.math.random(2, 4),       
        speedX = speedX,   
        speedY = speedY,
        life = love.math.random(0.1, 0.3),     -- Vida MUITO curta
        maxLife = 0,                          
        color = { r = self.sparkColorRed.r, g = self.sparkColorRed.g, b = self.sparkColorRed.b },  
        alpha = 1                             
    }
    spark.maxLife = spark.life
    table.insert(self.activeInitialSparks, spark)
end

function LevelUpAnimation:update(dt, playerX, playerY)
    if self.effectActive then
        local timeElapsed = self.effectDuration - self.effectTimer
        self.effectTimer = self.effectTimer - dt

        local currentBasePos = { x = playerX, y = playerY } 
        local drawBaseY = playerY + self.baseOffsetY -- Y da base para cálculos

        -- 1. EMISSÃO (Acontece apenas no primeiríssimo frame)
        if timeElapsed <= dt then -- Se for o primeiro passo do update após o start
             -- Emitir Núcleo (setar estado)
             self.coreAlpha = 1.0
             self.coreRadius = 20 -- Tamanho inicial do núcleo

             -- Emitir Anel (setar estado inicial)
             self.ringAlpha = 1.0
             self.ringRadius = 10 -- Começa pequeno

             -- Emitir Burst de Pedaços
             for i = 1, self.chunkBurstAmount do
                 self:createChunk(currentBasePos)
             end
             -- Emitir Burst de Faíscas Iniciais
             for i = 1, self.sparkBurstAmount do
                 self:createInitialSpark(currentBasePos)
             end
        end

        -- 2. ATUALIZAÇÃO DO NÚCLEO
        if timeElapsed < self.coreDuration then
            self.coreAlpha = 1.0 - (timeElapsed / self.coreDuration)
            self.coreRadius = 20 * (1.0 - (timeElapsed / self.coreDuration) * 0.5) 
        else
            self.coreAlpha = 0
        end

        -- 3. ATUALIZAÇÃO DO ANEL
        if timeElapsed < self.ringDuration then
            local ringProgress = timeElapsed / self.ringDuration
            self.ringRadius = 10 + (self.ringMaxRadius - 10) * ringProgress -- Expande linearmente
            self.ringAlpha = 1.0 - ringProgress -- Fade out linear
        else
             self.ringAlpha = 0 -- Garante que some
        end

        -- 4. ATUALIZAÇÃO dos Pedaços (Chunks) com SCALING e DRAG AJUSTADO
        for i = #self.activeChunks, 1, -1 do 
            local p = self.activeChunks[i]
            p.life = p.life - dt

            if p.life <= 0 then
                table.remove(self.activeChunks, i) 
            else
                -- Movimento
                p.x = p.x + p.speedX * dt
                p.y = p.y + p.speedY * dt
                p.angle = p.angle + p.rotationSpeed * dt
                
                -- Atrito/Drag (Usando o valor ajustado de self.chunkDrag)
                p.speedX = p.speedX * (1 - self.chunkDrag * dt)
                p.speedY = p.speedY * (1 - self.chunkDrag * dt)

                -- Cálculo da Escala por Profundidade (Y)
                local y_diff = p.y - drawBaseY -- Diferença do Y atual para a base da explosão
                -- Normaliza a diferença Y (limitado entre -1 e 1 mais ou menos)
                local depth_norm = math.max(-1, math.min(1, y_diff / self.chunkMaxDepthY)) 
                -- Calcula o fator de escala: < 1 se y_diff > 0 (abaixo/fundo), > 1 se y_diff < 0 (acima/frente)
                local depthScale = 1.0 - depth_norm * self.chunkDepthScaleFactor 

                -- Combina escala de vida e escala de profundidade
                local lifeRatio = p.life / p.maxLife
                local finalScale = lifeRatio * depthScale
                
                -- Aplica escala ao tamanho atual, baseado no tamanho original
                p.width = p.baseWidth * math.max(0.1, finalScale) -- Garante tamanho mínimo
                p.height = p.baseHeight * math.max(0.1, finalScale)

                -- Atualiza alpha
                p.alpha = math.min(1.0, lifeRatio * 1.5) * love.math.random(0.7, 1.0) -- Fade mais acentuado no fim
            end
        end

        -- 5. ATUALIZAÇÃO das Faíscas Iniciais
        for i = #self.activeInitialSparks, 1, -1 do
            local s = self.activeInitialSparks[i]
            s.life = s.life - dt

            if s.life <= 0 then
                table.remove(self.activeInitialSparks, i) 
            else
                s.x = s.x + s.speedX * dt 
                s.y = s.y + s.speedY * dt 
                s.alpha = (s.life / s.maxLife) -- Fade out linear simples
            end
        end

        -- Termina o efeito geral
        if self.effectTimer <= 0 and #self.activeChunks == 0 and #self.activeInitialSparks == 0 then
            self.effectActive = false
            self.isComplete = true 
        end
    end
end

function LevelUpAnimation:draw(playerX, playerY)
    -- Só desenha se o efeito estiver ativo OU se ainda houver partículas desaparecendo
    if self.effectActive or #self.activeChunks > 0 or #self.activeInitialSparks > 0 then
        
        local drawBaseY = playerY + self.baseOffsetY
        local playerCenterY = playerY -- Assumindo que playerY é o centro vertical para comparação de camadas

        -- 1. Desenha o Anel (na base)
        if self.ringAlpha > 0 then
            love.graphics.setColor(self.ringColorRed.r, self.ringColorRed.g, self.ringColorRed.b, self.ringAlpha)
            love.graphics.setLineWidth(math.max(1, 4 * self.ringAlpha)) -- Linha fica mais fina ao sumir
            love.graphics.circle("line", playerX, drawBaseY, self.ringRadius)
            love.graphics.setLineWidth(1) 
        end
        
        -- 2. Desenha o Núcleo (no centro da base)
        if self.coreAlpha > 0 then
             love.graphics.setColor(self.coreColorYellow.r, self.coreColorYellow.g, self.coreColorYellow.b, self.coreAlpha)
             love.graphics.circle("fill", playerX, drawBaseY, self.coreRadius)
        end

        -- 3. Desenho Isométrico das Partículas (Chunks e Sparks)
        
        -- Desenha Partículas "Atrás" (Y >= centro do jogador)
        love.graphics.setColor(1,1,1,1) -- Reset color before loop
        for i, p in ipairs(self.activeChunks) do
            if p.y >= playerCenterY then 
                love.graphics.setColor(p.color.r, p.color.g, p.color.b, p.alpha)
                -- USA p.width e p.height ATUALIZADOS PELA ESCALA
                love.graphics.rectangle("fill", p.x, p.y, p.width, p.height, p.width / 2, p.height / 2, p.angle)
            end
        end
        love.graphics.setColor(1,1,1,1) -- Reset color
        for i, s in ipairs(self.activeInitialSparks) do
             if s.y >= playerCenterY then
                love.graphics.setColor(s.color.r, s.color.g, s.color.b, s.alpha)
                love.graphics.circle("fill", s.x, s.y, s.radius)
             end
        end
        
        -- [[ DESENHE SEU JOGADOR AQUI ]] --
        -- Exemplo: 
        -- local playerSprite = assets.playerSprite -- Obtenha seu sprite
        -- local pw = playerSprite:getWidth()
        -- local ph = playerSprite:getHeight()
        -- love.graphics.draw(playerSprite, playerX, playerY, 0, 1, 1, pw/2, ph) -- Desenha com origem na base central
        
        -- Desenha Partículas "Frente" (Y < centro do jogador)
        love.graphics.setColor(1,1,1,1) -- Reset color
         for i, p in ipairs(self.activeChunks) do
            if p.y < playerCenterY then 
                 love.graphics.setColor(p.color.r, p.color.g, p.color.b, p.alpha)
                 -- USA p.width e p.height ATUALIZADOS PELA ESCALA
                 love.graphics.rectangle("fill", p.x, p.y, p.width, p.height, p.width / 2, p.height / 2, p.angle)
            end
        end
         love.graphics.setColor(1,1,1,1) -- Reset color
         for i, s in ipairs(self.activeInitialSparks) do
             if s.y < playerCenterY then
                 love.graphics.setColor(s.color.r, s.color.g, s.color.b, s.alpha)
                 love.graphics.circle("fill", s.x, s.y, s.radius)
             end
        end

        -- Reseta a cor 
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Função para iniciar/resetar a animação
function LevelUpAnimation:start(pos) -- pos é recebido, mas playerX/Y do update/draw são mais usados
    self.effectActive = true
    self.effectTimer = self.effectDuration -- Começa a contagem regressiva
    -- Resetar estados e tabelas
    self.activeChunks = {}
    self.activeInitialSparks = {}
    self.ringRadius = 0
    self.ringAlpha = 0
    self.coreAlpha = 0
    self.coreRadius = 0
    self.isComplete = false
    -- A emissão ocorrerá no primeiro quadro do update após esta chamada
end

-- Função para verificar se a animação terminou completamente
function LevelUpAnimation:isFinished()
    return self.isComplete
end

return LevelUpAnimation