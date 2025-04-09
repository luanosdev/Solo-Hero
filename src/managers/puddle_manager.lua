local DamagePuddle = require("src.effects.enemies.damage_puddle")

local PuddleManager = {
    puddles = {} -- Lista de poças ativas
}

function PuddleManager:init()
    self.puddles = {}
    print("PuddleManager inicializado.")
end

function PuddleManager:addPuddle(x, y, radius, duration, dps)
    local puddle = DamagePuddle:new(x, y, radius, duration, dps)
    table.insert(self.puddles, puddle)
end

function PuddleManager:update(dt, player)
    -- Itera de trás para frente para remoção segura
    for i = #self.puddles, 1, -1 do
        local puddle = self.puddles[i]
        puddle:update(dt, player)
        
        -- Remove poças expiradas
        if puddle.isExpired then
            table.remove(self.puddles, i)
        end
    end
end

function PuddleManager:draw()
    for _, puddle in ipairs(self.puddles) do
        puddle:draw()
    end
end

return PuddleManager