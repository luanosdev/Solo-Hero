local ExperiencePrism = require("src.entities.experience_prism")

local PrismManager = {
    prisms = {}
}

function PrismManager:init()
    self.prisms = {}
end

function PrismManager:update(dt, player)
    -- Atualiza e remove prismas coletados
    for i = #self.prisms, 1, -1 do
        local prism = self.prisms[i]
        if prism:update(dt, player) then
            player:addExperience(prism.experience)
            table.remove(self.prisms, i)
        end
    end
end

function PrismManager:addPrism(x, y, experience)
    local prism = ExperiencePrism:new(x, y, experience)
    table.insert(self.prisms, prism)
end

function PrismManager:draw()
    for _, prism in ipairs(self.prisms) do
        prism:draw()
    end
end

return PrismManager 