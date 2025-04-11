local ExperienceOrb = require("src.entities.experience_orb")

--[[
    Experience Orb Manager
    Gerencia os orbes de experiência que podem ser coletados pelo jogador
]]

local ExperienceOrbManager = {
    orbs = {} -- Lista de orbes de experiência ativos
}

function ExperienceOrbManager:init()
    self.orbs = {}
end

function ExperienceOrbManager:update(dt, player)
    -- Atualiza e remove orbes coletados
    for i = #self.orbs, 1, -1 do
        local orb = self.orbs[i]
        if orb:update(dt, player) then
            player:addExperience(orb.experience)
            table.remove(self.orbs, i)
        end
    end
end

function ExperienceOrbManager:addOrb(x, y, experience)
    local orb = ExperienceOrb:new(x, y, experience)
    table.insert(self.orbs, orb)
end

function ExperienceOrbManager:draw()
    for _, orb in ipairs(self.orbs) do
        orb:draw()
    end
end

return ExperienceOrbManager 