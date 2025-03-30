local FloatingText = require("src.entities.floating_text")

local FloatingTextManager = {
    texts = {}
}

function FloatingTextManager:init()
    self.texts = {}
end

function FloatingTextManager:update(dt)
    -- Atualiza e remove textos mortos
    for i = #self.texts, 1, -1 do
        local text = self.texts[i]
        if not text:update(dt) then
            table.remove(self.texts, i)
        end
    end
end

function FloatingTextManager:draw()
    for _, text in ipairs(self.texts) do
        text:draw()
    end
end

function FloatingTextManager:addText(x, y, text, isCritical, target, customColor)
    local floatingText = FloatingText:new(x, y, text, isCritical, target, customColor)
    table.insert(self.texts, floatingText)
end

return FloatingTextManager 