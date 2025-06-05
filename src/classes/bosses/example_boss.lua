local BaseBoss = require("src.classes.bosses.base_boss")
local colors = require("src.ui.colors")

local ExampleBoss = setmetatable({}, { __index = BaseBoss })

-- Configurações específicas deste boss
ExampleBoss.name = "Example Boss"
ExampleBoss.radius = 20
ExampleBoss.speed = 40
ExampleBoss.maxHealth = 1000
ExampleBoss.damage = 30
ExampleBoss.powerLevel = 3 -- Nível de poder do boss (1-5)
ExampleBoss.color = {0.8, 0.2, 0.2} -- Vermelho (#FF0000)
ExampleBoss.abilityCooldown = 3 -- Cooldown entre habilidades em segundos
ExampleBoss.class = ExampleBoss -- Define a classe do boss

-- Configurações da habilidade de ataque giratório
ExampleBoss.spinAttackConfig = {
    chargeTime = 1, -- Tempo de carregamento antes do ataque
    spinSpeed = 500,  -- Velocidade de rotação durante o ataque
    spinDuration = 1, -- Duração do ataque giratório
    lineWidth = 20,    -- Largura da linha vermelha
    lineLength = 300,  -- Comprimento fixo da linha de ataque
    damageMultiplier = 0.1 -- Multiplicador de dano baseado na velocidade
}

-- Habilidades do boss
ExampleBoss.abilities = {
    {
        name = "Ataque Giratório",
        cast = function(boss, player, enemies)
            -- Verifica se o player existe
            if not player or not player.positionX or not player.positionY then
                print("Erro: Player inválido para o ataque do boss!")
                return false
            end
            
            -- Verifica se o boss está inicializado corretamente
            if not boss or not boss.positionX or not boss.positionY then
                print("Erro: Boss não está inicializado corretamente!")
                return false
            end
            
            -- Calcula a distância até o jogador
            local dx = player.positionX - boss.positionX
            local dy = player.positionY - boss.positionY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            -- Se o jogador estiver fora do alcance da habilidade, não usa
            if distance > boss.spinAttackConfig.lineLength then
                print("Jogador fora do alcance do ataque giratório!")
                return false
            end
            
            print("Boss iniciando ataque giratório!")
            -- Inicia o carregamento do ataque
            boss.spinAttack = {
                isCharging = true,
                isSpinning = false,
                chargeTimer = 0,
                spinTimer = 0,
                targetX = player.positionX,
                targetY = player.positionY,
                startX = boss.positionX,
                startY = boss.positionY,
                rotation = 0,
                damageDealt = false -- Flag para controlar se o dano já foi aplicado
            }
            return true
        end
    },
}

function ExampleBoss:new(x, y)
    local boss = BaseBoss.new(self, x, y)
    setmetatable(boss, { __index = self })
    -- Ajusta os status baseado no nível de poder
    local powerMultiplier = 1 + (boss.powerLevel - 1) * 0.5 -- Aumenta 50% por nível
    boss.maxHealth = boss.maxHealth * powerMultiplier
    boss.currentHealth = boss.maxHealth
    boss.damage = boss.damage * powerMultiplier
    boss.speed = boss.speed * (1 + (boss.powerLevel - 1) * 0.1) -- Aumenta 10% por nível
    
    -- Inicializa as propriedades necessárias
    boss.positionX = x
    boss.positionY = y
    boss.abilityTimer = 0
    boss.isAlive = true
    
    return boss
end

function ExampleBoss:update(dt, player, enemies)
    if not self.isAlive then return end
    
    -- Verifica se o boss está inicializado corretamente
    if not self.positionX or not self.positionY then
        print("Erro: Boss não está inicializado corretamente!")
        return
    end

    -- Atualiza o timer de habilidades
    self.abilityTimer = self.abilityTimer + dt
    
    -- Verifica se pode usar uma habilidade
    if self.abilityTimer >= self.abilityCooldown then
        -- Seleciona uma habilidade aleatória
        local ability = self.abilities[1] -- Por enquanto só temos uma habilidade
        if ability and ability.cast then
            -- Tenta usar a habilidade
            local success = ability.cast(self, player, enemies)
            if success then
                self.abilityTimer = 0 -- Reinicia o timer apenas se a habilidade foi usada
            end
        end
    end

    -- Atualiza a habilidade de ataque giratório
    if self.spinAttack and self.spinAttack.isCharging then
        self.spinAttack.chargeTimer = self.spinAttack.chargeTimer + dt
        
        -- Quando termina o carregamento, inicia o ataque
        if self.spinAttack.chargeTimer >= self.spinAttackConfig.chargeTime then
            self.spinAttack.isCharging = false
            self.spinAttack.isSpinning = true
            self.spinAttack.spinTimer = 0
            print("Boss iniciando movimento giratório!")
        end
    elseif self.spinAttack and self.spinAttack.isSpinning then
        self.spinAttack.spinTimer = self.spinAttack.spinTimer + dt
        self.spinAttack.rotation = self.spinAttack.rotation + self.spinAttackConfig.spinSpeed * dt
        
        -- Calcula a posição ao longo da linha
        local progress = self.spinAttack.spinTimer / self.spinAttackConfig.spinDuration
        if progress <= 1 then
            -- Calcula a direção normalizada
            local dx = self.spinAttack.targetX - self.spinAttack.startX
            local dy = self.spinAttack.targetY - self.spinAttack.startY
            local length = math.sqrt(dx * dx + dy * dy)
            dx = dx / length * self.spinAttackConfig.lineLength
            dy = dy / length * self.spinAttackConfig.lineLength
            
            -- Atualiza a posição
            self.positionX = self.spinAttack.startX + dx * progress
            self.positionY = self.spinAttack.startY + dy * progress
            
            -- Verifica colisão com o player e aplica dano
            if not self.spinAttack.damageDealt and player and player.isAlive then
                local playerDx = player.positionX - self.positionX
                local playerDy = player.positionY - self.positionY
                local playerDistance = math.sqrt(playerDx * playerDx + playerDy * playerDy)
                
                if playerDistance < self.radius + player.radius then
                    -- Calcula o dano baseado na velocidade
                    local speed = self.spinAttackConfig.spinSpeed * dt
                    local damage = math.floor(self.damage * (1 + speed * self.spinAttackConfig.damageMultiplier))
                    player:receiveDamage(damage, self)
                    self.spinAttack.damageDealt = true
                    print("Boss acertou o jogador com ataque giratório!")
                end
            end
        else
            -- Termina o ataque
            self.spinAttack = nil
            print("Boss terminou o ataque giratório!")
        end
    end

    -- Chama o update da classe base apenas se não estiver carregando ou girando
    if not self.spinAttack or not (self.spinAttack.isCharging or self.spinAttack.isSpinning) then
        BaseBoss.update(self, dt, player, enemies)
    end
end

function ExampleBoss:draw()
    if not self.isAlive then return end

    -- Desenha o corpo do boss
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius)
    
    -- Desenha o efeito de brilho
    if self.glowEffect then
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.3)
        love.graphics.circle("fill", self.positionX, self.positionY, self.radius * 1.2)
    end
    
    -- Desenha a linha de ataque durante o carregamento
    if self.spinAttack and self.spinAttack.isCharging then
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.setLineWidth(self.spinAttackConfig.lineWidth)
        
        -- Calcula a direção normalizada
        local dx = self.spinAttack.targetX - self.spinAttack.startX
        local dy = self.spinAttack.targetY - self.spinAttack.startY
        local length = math.sqrt(dx * dx + dy * dy)
        dx = dx / length * self.spinAttackConfig.lineLength
        dy = dy / length * self.spinAttackConfig.lineLength
        
        -- Desenha a linha até o limite máximo
        love.graphics.line(
            self.spinAttack.startX,
            self.spinAttack.startY,
            self.spinAttack.startX + dx,
            self.spinAttack.startY + dy
        )
        love.graphics.setLineWidth(1)
    end
    
    -- Desenha o boss com rotação durante o ataque
    if self.spinAttack and self.spinAttack.isSpinning then
        love.graphics.push()
        love.graphics.translate(self.positionX, self.positionY)
        love.graphics.rotate(self.spinAttack.rotation)
        love.graphics.setColor(self.color)
        love.graphics.rectangle("fill", -self.radius, -self.radius, self.radius * 2, self.radius * 2)
        love.graphics.pop()
    end
end

return ExampleBoss 