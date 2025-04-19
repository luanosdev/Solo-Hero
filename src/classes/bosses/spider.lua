local BaseBoss = require("src.classes.bosses.base_boss")
local AnimatedSpider = require("src.animations.animated_spider")

local Spider = setmetatable({}, { __index = BaseBoss })

-- Configurações específicas do boss Spider
Spider.name = "Spider"
Spider.radius = 60
Spider.speed = 80
Spider.maxHealth = 2
Spider.damage = 40
Spider.color = {0.3, 0.3, 0.3} -- Cinza escuro
Spider.abilityCooldown = 4
Spider.class = Spider

function Spider:new(position, id)
    local boss = BaseBoss.new(self, position, id)
    setmetatable(boss, { __index = self })
    boss.sprite = AnimatedSpider.newConfig({
        position = position,
        scale = 2.0,
        speed = self.speed,
        animation = {
            frameTime = 0.12,
            currentFrame = 1,
            direction = 0
        }
    })
    boss.position = boss.sprite.position
    boss.isAlive = true
    boss.isDying = false
    boss.deathTimer = 0
    boss.deathDuration = 5.0
    boss.health = self.maxHealth
    boss.lastDirection = 0
    return boss
end

function Spider:update(dt, playerManager, enemies)
    if not self.isAlive then 
        -- Atualiza a animação de morte usando a última direção
        if self.lastDirection then
            -- Usa a última direção para a animação de morte
            self.sprite.animation.direction = self.lastDirection
            AnimatedSpider.update(self.sprite, dt, {x = self.position.x, y = self.position.y})
        else
            -- Se por algum motivo a direção não estiver definida, usa a direção atual do sprite
            AnimatedSpider.update(self.sprite, dt, {x = self.position.x, y = self.position.y})
        end
        self.deathTimer = self.deathTimer + dt
        if self.deathTimer >= self.deathDuration then
            self.shouldRemove = true
        end
        return 
    end
    
    -- Atualiza animação e posição
    AnimatedSpider.update(self.sprite, dt, playerManager.player.position)
    self.position = self.sprite.position
    -- Salva a direção atual
    self.lastDirection = self.sprite.animation.direction
    -- Chama update base para lógica de habilidades
    BaseBoss.update(self, dt, playerManager, enemies)
end

function Spider:draw()
    AnimatedSpider.draw(self.sprite)
end

function Spider:takeDamage(amount)
    self.health = self.health - amount
    if self.health <= 0 and self.isAlive then
        self.isAlive = false
    end
end

-- Função para iniciar a animação de morte
function Spider:startDeathAnimation()
    -- Garante que a direção da animação de morte seja a última direção
    self.sprite.animation.direction = self.lastDirection
    AnimatedSpider.startDeath(self.sprite)
end

return Spider 