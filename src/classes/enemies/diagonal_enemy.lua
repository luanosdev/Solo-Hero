local BaseEnemy = require("src.classes.enemies.base_enemy")

-- Função auxiliar para determinar o sinal de um número
local function sign(x)
    if x > 0 then return 1
    elseif x < 0 then return -1
    else return 0 end
end

local DiagonalEnemy = setmetatable({}, { __index = BaseEnemy })

DiagonalEnemy.name = "Diagonal Enemy"
DiagonalEnemy.radius = 9
DiagonalEnemy.speed = 75 -- Velocidade durante o passo de movimento
DiagonalEnemy.maxHealth = 35
DiagonalEnemy.damage = 9
DiagonalEnemy.color = {0.5, 0, 1} -- Roxo
DiagonalEnemy.experienceValue = 8

-- Configurações do movimento pausado
DiagonalEnemy.moveDuration = 0.4 -- Tempo se movendo
DiagonalEnemy.pauseDuration = 0.6 -- Tempo parado
DiagonalEnemy.normalizationFactor = 1 / math.sqrt(2) -- Para normalizar vetor diagonal (1,1)
DiagonalEnemy.minAngle = math.pi / 4 -- Ângulo mínimo de 45 graus para o zigue-zague
DiagonalEnemy.currentAngle = 0 -- Ângulo atual do movimento
DiagonalEnemy.angleChange = math.pi / 2 -- Mudança de ângulo a cada passo (90 graus)

function DiagonalEnemy:new(x, y)
    local enemy = BaseEnemy.new(self, x, y)
    setmetatable(enemy, { __index = self })
    
    -- Estado inicial do movimento
    enemy.isMoving = false -- Começa parado
    enemy.moveTimer = math.random() * self.pauseDuration -- Começa em um ponto aleatório da pausa inicial
    enemy.currentAngle = math.random() * math.pi * 2 -- Ângulo inicial aleatório
    
    return enemy
end

function DiagonalEnemy:update(dt, player, enemies)
    if not self.isAlive then return end

    -- Atualiza o timer de estado
    self.moveTimer = self.moveTimer + dt

    -- Lógica de transição de estado e movimento
    if self.isMoving then
        -- Se estava movendo, verifica se terminou o passo
        if self.moveTimer >= self.moveDuration then
            self.isMoving = false
            self.moveTimer = 0 -- Reinicia timer para a pausa
            -- Muda o ângulo para o próximo passo do zigue-zague
            self.currentAngle = self.currentAngle + self.angleChange
        else
            -- Calcula a direção para o jogador
            local dx = player.positionX - self.positionX
            local dy = player.positionY - self.positionY
            local targetAngle = math.atan2(dy, dx)
            
            -- Ajusta o ângulo atual para se aproximar do ângulo alvo, mas mantendo o padrão de zigue-zague
            local angleDiff = (targetAngle - self.currentAngle) % (math.pi * 2)
            if angleDiff > math.pi then angleDiff = angleDiff - math.pi * 2 end
            
            -- Se a diferença for muito grande, ajusta o ângulo
            if math.abs(angleDiff) > self.minAngle then
                self.currentAngle = self.currentAngle + sign(angleDiff) * self.minAngle
            end
            
            -- Calcula o vetor de movimento baseado no ângulo atual
            local moveX = math.cos(self.currentAngle)
            local moveY = math.sin(self.currentAngle)
            
            -- Calcula a nova posição potencial
            local stepX = moveX * self.speed * dt
            local stepY = moveY * self.speed * dt
            local newX = self.positionX + stepX
            local newY = self.positionY + stepY

            -- Verifica colisão com outros inimigos ANTES de mover
            local canMove = true
            for _, other in ipairs(enemies) do
                if other ~= self and other.isAlive then
                    local distSq = (other.positionX - newX)^2 + (other.positionY - newY)^2
                    if distSq < (self.radius + other.radius)^2 then
                        canMove = false
                        break
                    end
                end
            end

            -- Move se não houver colisão
            if canMove then
                self.positionX = newX
                self.positionY = newY
            end
        end
    else
        -- Se estava pausado, verifica se terminou a pausa
        if self.moveTimer >= self.pauseDuration then
            self.isMoving = true
            self.moveTimer = 0 -- Reinicia timer para o movimento
        end
        -- Não faz nada enquanto está pausado
    end

    -- Verifica colisão com o jogador (reutiliza método da classe base)
    self:checkPlayerCollision(dt, player)
end

-- Reutiliza a função de desenho da classe base
-- function DiagonalEnemy:draw()
--    BaseEnemy.draw(self)
-- end

return DiagonalEnemy