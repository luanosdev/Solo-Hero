local TablePool = require("src.utils.table_pool")

-- Carrega a imagem da flecha uma vez
local arrowImage = love.graphics.newImage("assets/attacks/arrow/arrow.png")
-- Pega as dimensões da imagem para usar como origem (centro)
local imgWidth = arrowImage:getWidth()
local imgHeight = arrowImage:getHeight()
local originX = imgWidth / 2
local originY = imgHeight / 2

-- Calcula a escala para que a altura (comprimento da flecha) seja ~20 pixels
local desiredLength = 60
local scale = desiredLength / imgHeight

local Arrow = {}
Arrow.__index = Arrow

function Arrow:new(x, y, angle, speed, range, damage, isCritical, spatialGrid, color)
    local instance = setmetatable({}, Arrow)

    instance.position = { x = x, y = y }
    instance.angle = angle
    instance.speed = speed
    instance.maxRange = range
    instance.damage = damage
    instance.isCritical = isCritical
    instance.spatialGrid = spatialGrid       -- NOVO: Referência ao grid espacial
    instance.color = color or { 1, 1, 1, 1 } -- Branco por padrão (pode ser usado para tingir o sprite)

    instance.velocity = {
        x = math.cos(angle) * speed,
        y = math.sin(angle) * speed
    }

    instance.distanceTraveled = 0
    instance.isActive = true -- A flecha está ativa no mundo?
    -- Mantém o size antigo por enquanto para a colisão AABB.
    -- Idealmente, ajustaríamos a colisão para usar a forma da imagem.
    instance.size = { width = 15, height = 3 }
    instance.hitEnemies = {} -- Guarda IDs dos inimigos já atingidos por esta flecha

    return instance
end

function Arrow:update(dt)
    if not self.isActive then return end

    -- Move a flecha
    local moveX = self.velocity.x * dt
    local moveY = self.velocity.y * dt
    self.position.x = self.position.x + moveX
    self.position.y = self.position.y + moveY

    -- Atualiza a distância percorrida
    self.distanceTraveled = self.distanceTraveled + math.sqrt(moveX ^ 2 + moveY ^ 2)

    -- Desativa se atingiu o alcance máximo
    if self.distanceTraveled >= self.maxRange then
        self.isActive = false
        return
    end

    -- Verifica colisão com inimigos
    self:checkCollision()
end

function Arrow:checkCollision()
    if not self.spatialGrid then
        error("Arrow:checkCollision spatialGrid não fornecido. Colisão não será verificada.")
        return
    end

    -- Define um raio de busca para o spatialGrid.
    -- Este raio deve ser suficiente para capturar inimigos que a flecha possa atingir.
    -- Usar o maior entre a largura e altura da bounding box da flecha como uma heurística simples,
    -- ou um valor fixo um pouco maior que o raio médio dos inimigos.
    -- Para uma flecha pequena e rápida, um raio de busca modesto é geralmente suficiente.
    local searchRadius = math.max(self.size.width, self.size.height) * 2 -- Dobro do tamanho da flecha para garantir.

    local nearbyEnemies = self.spatialGrid:getNearbyEntities(self.position.x, self.position.y, searchRadius, nil)

    local arrowRect = {
        x = self.position.x - self.size.width / 2,
        y = self.position.y - self.size.height / 2,
        width = self.size.width,
        height = self.size.height
    }

    for _, enemy in ipairs(nearbyEnemies) do
        local enemyId = enemy.id

        if not enemyId then
            error("AVISO [Arrow:checkCollision]: Entidade próxima não possui ID, pulando.")
        end

        if enemy.isAlive and not self.hitEnemies[enemyId] then
            -- Colisão simples AABB (Axis-Aligned Bounding Box)
            -- Para precisão, seria necessário OBB (Oriented Bounding Box) ou colisão por círculo
            local enemyRect = {
                x = enemy.position.x - enemy.radius,
                y = enemy.position.y - enemy.radius,
                width = enemy.radius * 2,
                height = enemy.radius * 2
            }

            -- Checa sobreposição AABB
            if arrowRect.x < enemyRect.x + enemyRect.width and
                arrowRect.x + arrowRect.width > enemyRect.x and
                arrowRect.y < enemyRect.y + enemyRect.height and
                arrowRect.y + arrowRect.height > enemyRect.y then
                -- Colidiu!
                local killed = enemy:takeDamage(self.damage, self.isCritical)
                self.hitEnemies[enemyId] = true -- Marca como atingido por esta flecha

                -- Decide se a flecha continua (penetração) ou é destruída
                -- Por agora, vamos destruir a flecha ao atingir o primeiro inimigo
                self.isActive = false
                -- Não precisa mais de 'return' aqui se quisermos que a flecha possa atingir múltiplos inimigos
                -- se a penetração for implementada. Por enquanto, com isActive = false, o efeito é o mesmo.
                break -- Sai do loop de inimigos próximos, pois a flecha foi desativada
            end
        end
    end

    TablePool.release(nearbyEnemies)
end

function Arrow:draw()
    if not self.isActive then return end

    local outlineColor = self.color  -- Preto para a borda
    local outlineThickness = 1       -- Espessura da borda em pixels (ajustado pela escala)
    local mainColor = { 1, 1, 1, 1 } -- Branco para o sprite principal

    love.graphics.push()
    love.graphics.translate(self.position.x, self.position.y)
    love.graphics.rotate(self.angle + math.pi / 2)

    -- Desenha a borda (desenhando o sprite deslocado com a cor da borda)
    love.graphics.setColor(outlineColor)
    local offsets = {
        { outlineThickness, 0 }, { -outlineThickness, 0 },               -- Horizontal offsets
        { 0,                outlineThickness }, { 0, -outlineThickness } -- Vertical offsets
        -- {outlineThickness, outlineThickness}, {-outlineThickness, -outlineThickness}, -- Diagonal (opcional)
        -- {outlineThickness, -outlineThickness}, {-outlineThickness, outlineThickness} -- Diagonal (opcional)
    }
    for _, offset in ipairs(offsets) do
        love.graphics.draw(arrowImage, offset[1], offset[2], 0, scale, scale, originX, originY)
    end

    -- Desenha a imagem principal da flecha por cima
    love.graphics.setColor(mainColor)
    love.graphics.draw(arrowImage, 0, 0, 0, scale, scale, originX, originY)

    love.graphics.pop()

    -- Reseta a cor global
    love.graphics.setColor(1, 1, 1, 1)
end

return Arrow
