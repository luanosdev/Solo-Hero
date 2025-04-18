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
            currentFrame = 1
        }
    })
    boss.position = boss.sprite.position
    boss.isAlive = true
    return boss
end

function Spider:update(dt, playerManager, enemies)
    if not self.isAlive then return end
    -- Atualiza animação e posição
    AnimatedSpider.update(self.sprite, dt, playerManager.player.position)
    self.position = self.sprite.position
    -- Chama update base para lógica de habilidades
    BaseBoss.update(self, dt, playerManager, enemies)
end

function Spider:draw()
    if not self.isAlive then return end
    AnimatedSpider.draw(self.sprite)
end

return Spider 