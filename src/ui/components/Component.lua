---@class Component Classe base para todos os componentes de UI.
---@field rect table {x, y, w, h} Retângulo do componente (posição e dimensões externas).
---@field padding table {top, right, bottom, left} Espaçamento interno.
---@field margin table {top, right, bottom, left} Espaçamento externo.
---@field needsLayout boolean Flag que indica se o layout precisa ser recalculado.
---@field debug boolean Flag para desenhar informações de debug.
local Component = {}
Component.__index = Component

--- Função helper para parsear padding/margin
local function parseSpacing(value)
    local spacing = { top = 0, right = 0, bottom = 0, left = 0 }
    if type(value) == "number" then
        spacing.top, spacing.right, spacing.bottom, spacing.left = value, value, value, value
    elseif type(value) == "table" then
        if value.vertical ~= nil or value.horizontal ~= nil then -- { vertical, horizontal }
            local v = value.vertical or 0
            local h = value.horizontal or 0
            spacing.top, spacing.right, spacing.bottom, spacing.left = v, h, v, h
        else                                                                        -- { top, right, bottom, left } ou array { t, r, b, l } ou { v, h } ou { all }
            spacing.top = value.top or value[1] or 0
            spacing.right = value.right or value[2] or value.left or value[1] or 0  -- Usa left se right ausente, ou 1
            spacing.bottom = value.bottom or value[3] or value.top or value[1] or 0 -- Usa top se bottom ausente, ou 1
            spacing.left = value.left or value[4] or value.right or value[2] or 0   -- Usa right se left ausente, ou 2
        end
    end
    return spacing
end

--- Construtor base para componentes.
---@param config table Tabela de configuração.
function Component:new(config)
    local instance = setmetatable({}, Component)
    config = config or {}

    -- Inicializa o retângulo, priorizando config.rect sobre config.x/y/w/h
    -- GARANTE QUE instance.rect SEJA UMA NOVA TABELA
    local cfg_rect = config.rect or {}
    instance.rect = {
        x = cfg_rect.x or config.x or 0, -- Prioridade: rect.x > config.x > 0
        y = cfg_rect.y or config.y or 0, -- Prioridade: rect.y > config.y > 0
        w = cfg_rect.w or config.w or 0, -- Prioridade: rect.w > config.w > 0
        h = cfg_rect.h or config.h or 0  -- Prioridade: rect.h > config.h > 0
    }

    -- Inicializa padding e margin
    instance.padding = parseSpacing(config.padding)
    instance.margin = parseSpacing(config.margin)

    instance.needsLayout = true
    instance.debug = config.debug or false

    return instance
end

--- Método para recalcular o layout interno do componente.
-- Classes filhas (como YStack) devem sobrescrever isso.
-- A implementação base apenas reseta a flag.
function Component:_updateLayout()
    -- print("Component:_updateLayout called for", self)
    self.needsLayout = false
end

--- Método de atualização do componente (chamado a cada frame).
-- Classes filhas devem sobrescrever para adicionar lógica de update.
function Component:update(dt, mx, my, allowHover)
    -- Implementação padrão vazia
end

--- Método de desenho do componente.
-- Agora desenha padding e margin no modo debug.
function Component:draw()
    if self.debug then
        love.graphics.push()
        love.graphics.setLineWidth(1)
        -- Define o estilo como suave
        love.graphics.setLineStyle("smooth")

        -- Desenha Margem (fora do rect)
        love.graphics.setColor(1, 0, 0, 0.4) -- Vermelho para margem
        love.graphics.rectangle("line",
            self.rect.x - self.margin.left,
            self.rect.y - self.margin.top,
            self.rect.w + self.margin.left + self.margin.right,
            self.rect.h + self.margin.top + self.margin.bottom
        )

        -- Desenha Rect (borda do componente)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5) -- Cinza para rect
        love.graphics.rectangle("line", self.rect.x, self.rect.y, self.rect.w, self.rect.h)

        -- Desenha Padding (dentro do rect)
        love.graphics.setColor(0, 0, 1, 0.4) -- Azul para padding
        love.graphics.rectangle("line",
            self.rect.x + self.padding.left,
            self.rect.y + self.padding.top,
            self.rect.w - self.padding.left - self.padding.right,
            self.rect.h - self.padding.top - self.padding.bottom
        )

        love.graphics.pop()
    end
end

--- Manipula clique do mouse.
-- Classes filhas devem sobrescrever se forem interativas.
---@return boolean consumed Se o evento foi consumido.
function Component:handleMousePress(x, y, button)
    return false -- Padrão: não consome
end

--- Manipula soltar do mouse.
-- Classes filhas devem sobrescrever se forem interativas.
---@return boolean consumed Se o evento foi consumido.
function Component:handleMouseRelease(x, y, button)
    return false -- Padrão: não consome
end

--- Manipula scroll do mouse.
-- Classes filhas podem sobrescrever.
function Component:handleMouseScroll(dx, dy)
    -- Implementação padrão vazia
end

--- Manipula pressionamento de tecla.
-- Classes filhas podem sobrescrever.
function Component:keypressed(key, scancode, isrepeat)
    -- Implementação padrão vazia
end

--- Manipula soltar de tecla.
-- Classes filhas podem sobrescrever.
function Component:keyreleased(key, scancode)
    -- Implementação padrão vazia
end

return Component
