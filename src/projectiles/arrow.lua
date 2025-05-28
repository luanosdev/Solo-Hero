local TablePool = require("src.utils.table_pool")

-- Carrega a imagem da flecha uma vez
local arrowImage = love.graphics.newImage("assets/attacks/arrow/arrow.png")
-- Pega as dimensões da imagem para usar como origem (centro)
local imgWidth = arrowImage:getWidth()   -- Espessura da imagem original
local imgHeight = arrowImage:getHeight() -- Comprimento da imagem original
local originX = imgWidth / 2
local originY = imgHeight / 2

-- Calcula a escala base para que a altura (comprimento da flecha) seja ~60 pixels
local baseDesiredLength = 60
local baseScale = baseDesiredLength / imgHeight

-- Define um raio de colisão base para a ponta da flecha.
-- Este valor será escalado pelo areaScale.
-- Por exemplo, pode ser metade da espessura base da flecha ou um valor ajustado para gameplay.
local baseCollisionRadiusAtTip = (imgWidth * baseScale) / 2 -- Metade da espessura visual base

---@class Arrow
---@field position table Posição {x, y} do CENTRO da flecha.
---@field angle number Ângulo de movimento em radianos.
---@field speed number Velocidade da flecha.
---@field maxRange number Alcance máximo da flecha.
---@field damage number Dano base da flecha.
---@field isCritical boolean Se a flecha é um acerto crítico.
---@field spatialGrid SpatialGridIncremental Referência ao grid espacial para otimização de colisão.
---@field color table Cor para tingir o sprite da flecha {r, g, b, a}.
---@field velocity table Velocidade decomposta {x, y}.
---@field distanceTraveled number Distância percorrida pela flecha.
---@field isActive boolean Se a flecha está ativa no mundo.
---@field hitEnemies table Tabela para rastrear inimigos já atingidos.
---@field currentPiercing number Quantidade de inimigos que a flecha ainda pode perfurar.
---@field visualScale number Escala visual final da flecha, afetada pela área.
---@field collisionRadiusAtTip number Raio de colisão final na ponta da flecha.
---@field tipOffsetFromCenter number Distância do centro da imagem da flecha até sua ponta.
local Arrow = {}
Arrow.__index = Arrow

--- Cria uma nova instância de Flecha.
---@param x number Posição inicial X (centro da flecha).
---@param y number Posição inicial Y (centro da flecha).
---@param angle number Ângulo inicial em radianos.
---@param speed number Velocidade da flecha.
---@param range number Alcance máximo da flecha.
---@param damage number Dano a ser causado.
---@param isCritical boolean Se o dano é crítico.
---@param spatialGrid SpatialGridIncremental Grid espacial para detecção de colisão.
---@param color table Cor da flecha (opcional).
---@param piercing number Capacidade de perfuração inicial da flecha.
---@param areaScale number Multiplicador de escala da área de efeito (afeta tamanho visual e raio de colisão).
function Arrow:new(x, y, angle, speed, range, damage, isCritical, spatialGrid, color, piercing, areaScale)
    local instance = setmetatable({}, Arrow)

    instance.position = { x = x, y = y }
    instance.angle = angle
    instance.speed = speed
    instance.maxRange = range or 100
    instance.damage = damage
    instance.isCritical = isCritical
    instance.spatialGrid = spatialGrid
    instance.color = color or { 1, 1, 1, 1 }
    instance.currentPiercing = piercing or 1
    local currentAreaScale = areaScale or 1

    instance.velocity = {
        x = math.cos(angle) * speed,
        y = math.sin(angle) * speed
    }

    instance.distanceTraveled = 0
    instance.isActive = true
    instance.hitEnemies = {}

    instance.visualScale = baseScale * currentAreaScale
    -- O raio de colisão na ponta é o raio base escalado pela areaScale
    instance.collisionRadiusAtTip = baseCollisionRadiusAtTip * currentAreaScale

    -- A imagem da flecha é desenhada com origem no centro (originX, originY).
    -- A "ponta" da flecha, considerando que a imagem aponta para "cima" (Y negativo local) antes da rotação,
    -- estaria a originY pixels de distância do centro, na direção local Y negativo.
    -- Após a escala, essa distância é originY * instance.visualScale.
    -- Como usamos imgHeight / 2 para originY, a distância do centro até a ponta é (imgHeight / 2) * visualScale.
    instance.tipOffsetFromCenter = (imgHeight / 2) * instance.visualScale

    return instance
end

--- Reseta uma instância de Flecha existente para reutilização (pooling).
--- Os parâmetros são os mesmos de Arrow:new.
---@param x number Posição inicial X (centro da flecha).
---@param y number Posição inicial Y (centro da flecha).
---@param angle number Ângulo inicial em radianos.
---@param speed number Velocidade da flecha.
---@param range number Alcance máximo da flecha.
---@param damage number Dano a ser causado.
---@param isCritical boolean Se o dano é crítico.
---@param spatialGrid SpatialGridIncremental Grid espacial para detecção de colisão.
---@param color table Cor da flecha (opcional).
---@param piercing number Capacidade de perfuração inicial da flecha.
---@param areaScale number Multiplicador de escala da área de efeito.
function Arrow:reset(x, y, angle, speed, range, damage, isCritical, spatialGrid, color, piercing, areaScale)
    self.position.x = x
    self.position.y = y
    self.angle = angle
    self.speed = speed
    self.maxRange = range or 100
    self.damage = damage
    self.isCritical = isCritical
    self.spatialGrid = spatialGrid -- Pode ter mudado se o grid for dinâmico
    self.color = color or { 1, 1, 1, 1 }
    self.currentPiercing = piercing or 1
    local currentAreaScale = areaScale or 1

    self.velocity.x = math.cos(angle) * speed
    self.velocity.y = math.sin(angle) * speed

    self.distanceTraveled = 0
    self.isActive = true -- MUITO IMPORTANTE: Reativar a flecha
    self.hitEnemies = {} -- Limpa a lista de inimigos atingidos

    self.visualScale = baseScale * currentAreaScale
    self.collisionRadiusAtTip = baseCollisionRadiusAtTip * currentAreaScale
    self.tipOffsetFromCenter = (imgHeight / 2) * self.visualScale

    -- Limpa quaisquer outros estados específicos da flecha se houver
end

function Arrow:update(dt)
    if not self.isActive then return end

    local moveX = self.velocity.x * dt
    local moveY = self.velocity.y * dt
    self.position.x = self.position.x + moveX
    self.position.y = self.position.y + moveY

    self.distanceTraveled = self.distanceTraveled + math.sqrt(moveX ^ 2 + moveY ^ 2)

    if self.distanceTraveled >= self.maxRange then
        self.isActive = false
        return
    end

    self:checkCollision()
end

function Arrow:checkCollision()
    if not self.spatialGrid then
        return
    end

    -- Calcula a posição atual da ponta da flecha para a colisão
    -- A flecha se move na direção do seu 'angle'.
    -- Se 'position' é o centro, a ponta está 'tipOffsetFromCenter' à frente.
    local tipX = self.position.x + math.cos(self.angle) * self.tipOffsetFromCenter
    local tipY = self.position.y + math.sin(self.angle) * self.tipOffsetFromCenter

    -- O searchRadius para o spatialGrid ainda pode ser baseado no tamanho geral da flecha
    -- para encontrar candidatos. O comprimento visual da flecha é imgHeight * self.visualScale.
    local visualLength = imgHeight * self.visualScale
    local visualWidth = imgWidth * self.visualScale
    local searchRadius = math.max(visualLength, visualWidth) * 0.75 -- Um pouco mais que a metade da maior dimensão

    local nearbyEnemies = self.spatialGrid:getNearbyEntities(self.position.x, self.position.y, searchRadius, nil)

    for _, enemy in ipairs(nearbyEnemies) do
        if not enemy or not enemy.isAlive then goto continue_enemy_loop end

        local enemyId = enemy.id
        if not enemyId then goto continue_enemy_loop end

        if not self.hitEnemies[enemyId] then
            -- Colisão Círculo-Círculo
            -- Círculo da flecha: centro em (tipX, tipY), raio self.collisionRadiusAtTip
            -- Círculo do inimigo: centro em (enemy.position.x, enemy.position.y), raio enemy.radius

            local dx = tipX - enemy.position.x
            local dy = tipY - enemy.position.y
            local distanceSq = dx * dx + dy * dy
            local sumOfRadii = self.collisionRadiusAtTip + enemy.radius
            local sumOfRadiiSq = sumOfRadii * sumOfRadii

            if distanceSq <= sumOfRadiiSq then
                -- Colidiu!
                enemy:takeDamage(self.damage, self.isCritical)
                self.hitEnemies[enemyId] = true
                self.currentPiercing = self.currentPiercing - 1

                if self.currentPiercing <= 0 then
                    self.isActive = false
                    TablePool.release(nearbyEnemies)
                    return -- Flecha destruída
                end
                -- Se ainda tem piercing, a flecha continua.
            end
        end
        ::continue_enemy_loop::
    end

    TablePool.release(nearbyEnemies)
end

function Arrow:draw()
    if not self.isActive then return end

    local outlineColor = self.color
    local outlineThickness = 1
    local mainColor = { 1, 1, 1, 1 }

    love.graphics.push()
    love.graphics.translate(self.position.x, self.position.y)
    love.graphics.rotate(self.angle + math.pi / 2) -- Imagem da flecha aponta para cima, +pi/2 para alinhar com ângulo 0 = direita

    -- Desenha a borda
    love.graphics.setColor(outlineColor)
    local offsets = {
        { outlineThickness, 0 }, { -outlineThickness, 0 },
        { 0,                outlineThickness }, { 0, -outlineThickness }
    }
    for _, offset in ipairs(offsets) do
        love.graphics.draw(arrowImage, offset[1] / self.visualScale, offset[2] / self.visualScale, 0, self.visualScale,
            self.visualScale, originX, originY)
    end

    -- Desenha a imagem principal
    love.graphics.setColor(mainColor)
    love.graphics.draw(arrowImage, 0, 0, 0, self.visualScale, self.visualScale, originX, originY)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)

    -- DEBUG: Desenha o círculo de colisão da ponta
    if self.isActive and DEBUG_SHOW_PARTICLE_COLLISION_RADIUS then
        local tipX_debug = self.position.x + math.cos(self.angle) * self.tipOffsetFromCenter
        local tipY_debug = self.position.y + math.sin(self.angle) * self.tipOffsetFromCenter
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.circle("fill", tipX_debug, tipY_debug, self.collisionRadiusAtTip)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Arrow
