--[[
    Runa do Trovão
    Faz raios caírem em inimigos aleatórios periodicamente
]]

local ThunderRune = {}

ThunderRune.name = "Runa do Trovão"
ThunderRune.description = "Faz raios caírem em inimigos aleatórios periodicamente"
ThunderRune.damage = 30
ThunderRune.damageType = "thunder"
ThunderRune.color = {0.2, 0.6, 1, 0.3} -- Cor azul para o raio

-- Configuração da runa
ThunderRune.cooldown = 2 -- Tempo entre cada raio
ThunderRune.currentCooldown = 0
ThunderRune.range = 0 -- Será definido com base na área visível da câmera
ThunderRune.animation = {
    width = 128,
    height = 128,
    frameCount = 22,
    frameTime = 0.02, -- Mais rápido (era 0.05)
    scale = 1, -- Mais fino (era 1.5)
    frames = {},
    currentFrame = 1,
    timer = 0
}

-- Estrutura para armazenar raios ativos
ThunderRune.activeBolts = {}

function ThunderRune:init(playerManager)
    self.playerManager = playerManager
    
    -- Carrega os frames da animação
    for i = 1, self.animation.frameCount do
        self.animation.frames[i] = love.graphics.newImage("assets/abilities/thunder/spell_bluetop_1_" .. i .. ".png")
    end
    
    -- Define o alcance como a área visível da câmera
    self.range = math.max(love.graphics.getWidth(), love.graphics.getHeight()) * 0.6
end

function ThunderRune:update(dt, enemies)
    -- Atualiza o cooldown
    self.currentCooldown = self.currentCooldown - dt
    
    -- Atualiza os raios ativos
    for i = #self.activeBolts, 1, -1 do
        local bolt = self.activeBolts[i]
        bolt.timer = bolt.timer + dt
        
        -- Atualiza a animação do raio
        bolt.animation.timer = bolt.animation.timer + dt
        if bolt.animation.timer >= bolt.animation.frameTime then
            bolt.animation.timer = bolt.animation.timer - bolt.animation.frameTime
            bolt.animation.currentFrame = bolt.animation.currentFrame + 1
            if bolt.animation.currentFrame > self.animation.frameCount then
                bolt.animation.currentFrame = 1
            end
        end
        
        -- Remove o raio quando terminar
        if bolt.timer >= bolt.duration then
            table.remove(self.activeBolts, i)
        end
    end
    
    -- Verifica se pode lançar um novo raio
    if self.currentCooldown <= 0 and #enemies > 0 then
        self:cast(enemies)
        self.currentCooldown = self.cooldown
    end
end

function ThunderRune:draw()
    -- Desenha todos os raios ativos
    for _, bolt in ipairs(self.activeBolts) do
        local frame = self.animation.frames[bolt.animation.currentFrame]
        if frame then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                frame,
                bolt.x,
                bolt.y,
                0,
                self.animation.scale,
                self.animation.scale,
                frame:getWidth() / 2, -- Origem X no centro
                frame:getHeight()     -- Origem Y na base
            )
        end
    end
end

function ThunderRune:cast(enemies)
    -- Encontra inimigos dentro do alcance
    local validEnemies = {}
    local playerX = self.playerManager.player.position.x
    local playerY = self.playerManager.player.position.y
    
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.position.x - playerX
            local dy = enemy.position.y - playerY
            local distance = math.sqrt(dx * dx + dy * dy)
            
            if distance <= self.range then
                table.insert(validEnemies, enemy)
            end
        end
    end
    
    -- Escolhe um inimigo aleatório
    if #validEnemies > 0 then
        local target = validEnemies[math.random(1, #validEnemies)]
        
        -- Aplica o dano
        self:applyDamage(target)
        
        -- Obtém a posição de colisão do inimigo (base do sprite)
        local collisionPosition = target:getCollisionPosition()
        
        -- Cria o efeito visual do raio
        table.insert(self.activeBolts, {
            x = collisionPosition.position.x,
            y = collisionPosition.position.y + 20, -- Ajusta para cair um pouco abaixo
            timer = 0,
            duration = 0.3, -- Duração mais curta (era 0.5)
            animation = {
                currentFrame = 1,
                timer = 0,
                frameTime = 0.02 -- Mais rápido (era 0.05)
            }
        })
    end
end

function ThunderRune:applyDamage(target)
    if not target or not target.takeDamage then return false end
    return target:takeDamage(self.damage)
end

return ThunderRune 