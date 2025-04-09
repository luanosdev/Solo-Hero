-- Conteúdo copiado de src/abilities/enemies/damage_puddle.lua
local FloatingTextManager = require("src.managers.floating_text_manager")

local DamagePuddle = {}
DamagePuddle.__index = DamagePuddle

function DamagePuddle:new(x, y, radius, duration, damagePerSecond)
    local instance = setmetatable({}, DamagePuddle)
    instance.positionX = x
    instance.positionY = y
    instance.radius = radius or 25
    instance.duration = duration or 5
    instance.damagePerSecond = damagePerSecond or 3
    instance.damageInterval = 1
    
    instance.timer = 0
    instance.damageTimer = 0
    instance.isExpired = false
    instance.color = {0.2, 0.8, 0.2, 0.5}

    print(string.format("Poça de dano criada em (%.1f, %.1f) com DPS %.1f", x, y, instance.damagePerSecond))
    return instance
end

function DamagePuddle:update(dt, player)
    if self.isExpired then return end

    self.timer = self.timer + dt
    if self.timer >= self.duration then
        self.isExpired = true
        print("Poça de dano expirou.")
        return
    end

    self.damageTimer = self.damageTimer + dt

    local dx = player.positionX - self.positionX
    local dy = player.positionY - self.positionY
    local distanceSq = dx*dx + dy*dy

    if distanceSq <= (self.radius + player.radius)^2 then
        if self.damageTimer >= self.damageInterval then
            local damageToDeal = self.damagePerSecond * self.damageInterval
            print(string.format("Jogador na poça. Aplicando %.1f de dano.", damageToDeal))
            
            if player:takeDamage(damageToDeal) then
                print("Jogador morreu por dano da poça.")
            end

            FloatingTextManager:addText(
                player.positionX + math.random(-5, 5), 
                player.positionY - player.radius - 15, 
                "-" .. tostring(math.floor(damageToDeal)),
                false, 
                player,
                {self.color[1], self.color[2], self.color[3]}
            )

            self.damageTimer = self.damageTimer - self.damageInterval 
            if self.damageTimer < 0 then self.damageTimer = 0 end 
        end
    end
end

function DamagePuddle:draw()
    if self.isExpired then return end
    
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(self.color)
    love.graphics.circle("fill", self.positionX, self.positionY, self.radius)
    love.graphics.setColor(r, g, b, a)
end

return DamagePuddle 