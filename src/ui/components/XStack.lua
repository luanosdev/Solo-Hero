-- src/ui/components/XStack.lua
local Component = require("src.ui.components.Component")

---@class XStack : Component
---@field height number Altura total disponível para a stack (pode ser ajustada pela stack).
---@field padding table Espaçamento interno { top, right, bottom, left }.
---@field gap number Espaçamento horizontal EXTRA entre filhos.
---@field alignment string Alinhamento VERTICAL dos filhos ('top', 'center', 'bottom').
---@field children table Lista de componentes filhos.
---@field actualWidth number Largura calculada com base nos filhos.
local XStack = setmetatable({}, { __index = Component })
XStack.__index = XStack

--- Cria uma nova instância de XStack.
---@param config table Tabela de configuração contendo:
---   x, y: Coordenadas iniciais.
---   height: Altura base da stack (pode ser opcional ou usada como min/max).
---   width: Largura inicial (pode ser substituída pela largura calculada).
---   padding?: { top=0, right=0, bottom=0, left=0 }.
---   margin?: { top=0, right=0, bottom=0, left=0 }.
---   gap?: number Espaçamento horizontal entre filhos.
---   alignment?: string Alinhamento vertical ('top', 'center', 'bottom', default='top').
---   debug?: boolean.
---@return XStack
function XStack:new(config)
    if not config or not config.x or not config.y then
        error("XStack:new - Configuração inválida. 'x' e 'y' são obrigatórios.", 2)
    end
    local instance = Component:new(config) ---@class XStack
    setmetatable(instance, XStack)

    instance.gap = config.gap or 0
    instance.alignment = config.alignment or "top" -- Alinhamento vertical
    instance.children = {}
    instance.actualWidth = 0

    -- Define altura base; pode ser recalculada se a stack não tiver altura fixa
    instance.rect.h = config.height or 0 -- Usa a altura passada ou 0

    return instance
end

--- Adiciona um componente filho à stack.
function XStack:addChild(child)
    if not child or not child.rect or not child.rect.w or not child.rect.h then
        print("AVISO (XStack:addChild): Filho inválido ou sem rect/w/h. Ignorando.")
        return
    end
    child.margin = child.margin or { top = 0, right = 0, bottom = 0, left = 0 }
    table.insert(self.children, child)
    self.needsLayout = true
end

--- Calcula e atualiza a posição E ALTURA dos filhos, e a LARGURA da stack.
function XStack:_updateLayout()
    if not self.needsLayout then return end

    local innerHeight = self.rect.h - self.padding.top - self.padding.bottom
    local currentX = self.rect.x + self.padding.left -- X inicial DENTRO do padding
    local contentStartY = self.rect.y + self.padding.top
    local maxChildHeightInLayout = 0                 -- Para calcular a altura final da stack se necessário

    for i, child in ipairs(self.children) do
        local childMargin = child.margin

        -- *** 1. Calcula a posição X do filho ATUAL ***
        currentX = currentX + childMargin.left
        local childX = currentX

        -- *** 2. Define a ALTURA do filho (para cálculo de alinhamento Y) ***
        -- Assume que a altura do filho é definida por ele mesmo ou por uma altura fixa da stack.
        -- Se a stack define a altura, poderíamos ajustar child.rect.h aqui.
        -- Por agora, vamos usar a altura que o filho já tem ou que a stack impõe.
        local availableHeightForChild = innerHeight - childMargin.top - childMargin.bottom
        -- Poderia fazer: child.rect.h = math.max(0, availableHeightForChild) se a stack ditar a altura.

        -- *** 3. Calcula a posição Y do filho ATUAL (depende da altura do filho) ***
        local childY
        local childHeightWithMargins = child.rect.h + childMargin.top + childMargin.bottom
        if self.alignment == "center" then
            local centeringOffset = (innerHeight - childHeightWithMargins) / 2
            childY = contentStartY + centeringOffset + childMargin.top
        elseif self.alignment == "bottom" then
            childY = contentStartY + innerHeight - child.rect.h - childMargin.bottom
        else -- Padrão 'top'
            childY = contentStartY + childMargin.top
        end

        -- *** 4. Define a posição (absoluta na tela) do filho ANTES de chamar seu layout ***
        child.rect.x = math.floor(childX)
        child.rect.y = math.floor(childY)

        -- *** 5. CHAMA o layout interno do filho (se aplicável) ***
        if child.needsLayout and child._updateLayout then
            child:_updateLayout()
        elseif child.needsLayout then
            child.needsLayout = false
        end

        -- *** 6. Lê a largura final do filho (pode ter sido atualizada pelo passo 5) ***
        local childWidth = child.rect.w

        -- *** 7. Atualiza currentX para o PRÓXIMO filho ***
        currentX = currentX + childWidth + childMargin.right + self.gap

        -- Guarda a maior altura encontrada (incluindo margens) para cálculo da altura da stack
        maxChildHeightInLayout = math.max(maxChildHeightInLayout, childHeightWithMargins)
    end

    -- Calcula a largura total usada
    local calculatedWidth = 0
    if #self.children > 0 then
        local endX = currentX - self.gap -- Tira o último gap
        calculatedWidth = endX - (self.rect.x + self.padding.left) + self.padding.right
    else
        calculatedWidth = self.padding.left + self.padding.right
    end
    self.actualWidth = math.max(0, calculatedWidth)
    self.rect.w = self.actualWidth -- Atualiza a largura da stack

    -- Atualiza a altura da stack se ela não for fixa (config.height não foi passado ou era 0)
    if self.rect.h == 0 then
        self.rect.h = maxChildHeightInLayout + self.padding.top + self.padding.bottom
    end

    Component._updateLayout(self) -- Chama base para marcar layout como feito
end

--- Atualiza o estado da stack e seus filhos.
function XStack:update(dt, mx, my, allowHover)
    self:_updateLayout()
    for _, child in ipairs(self.children) do
        if child.update then
            child:update(dt, mx, my, allowHover)
        end
    end
end

--- Desenha a stack e seus filhos.
function XStack:draw()
    self:_updateLayout()
    Component.draw(self) -- Debug da stack base

    -- Debug do padding (opcional)
    if self.debug then
        love.graphics.push()
        love.graphics.setColor(0, 1, 1, 0.3)
        love.graphics.rectangle("line", self.rect.x + self.padding.left, self.rect.y + self.padding.top,
            self.rect.w - self.padding.left - self.padding.right, self.rect.h - self.padding.top - self.padding.bottom)
        love.graphics.pop()
    end

    -- Desenha os filhos
    for _, child in ipairs(self.children) do
        if child.draw then
            child:draw()
        elseif self.debug and child.rect then -- Fallback debug para filhos sem draw
            love.graphics.push()
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.rectangle("line", child.rect.x, child.rect.y, child.rect.w, child.rect.h)
            love.graphics.pop()
        end
    end
end

--- Processa cliques do mouse, delegando aos filhos.
function XStack:handleMousePress(x, y, button)
    self:_updateLayout()
    for i = #self.children, 1, -1 do
        local child = self.children[i]
        if child.handleMousePress then
            if x >= child.rect.x and x < child.rect.x + child.rect.w and
                y >= child.rect.y and y < child.rect.y + child.rect.h then
                local consumed = child:handleMousePress(x, y, button)
                if consumed then return true end
            end
        end
    end
    return false
end

--- Processa o soltar do mouse, delegando aos filhos.
function XStack:handleMouseRelease(x, y, button)
    self:_updateLayout()
    for i = #self.children, 1, -1 do
        local child = self.children[i]
        if child.handleMouseRelease then
            local consumed = child:handleMouseRelease(x, y, button)
            if consumed then return true end
        end
    end
    return false
end

return XStack
