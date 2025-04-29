local Component = require("src.ui.components.Component") -- <<< IMPORTA BASE

---@class YStack : Component
---@field width number Largura total disponível para a stack.
---@field padding number Espaçamento interno.
---@field gap number Espaçamento vertical EXTRA entre filhos (além das margens).
---@field alignment string Alinhamento horizontal dos filhos ('left', 'center', 'right').
---@field children table Lista de componentes filhos.
---@field actualHeight number Altura calculada com base nos filhos.
---@field fixedHeight number|nil Altura fixa definida na configuração.
local YStack = setmetatable({}, { __index = Component }) -- <<< HERANÇA
YStack.__index = YStack

--- Cria uma nova instância de YStack.
---@param config table Tabela de configuração contendo:
---  x, y, width (obrigatórios)
---  height (number|nil) - Opcional. Altura fixa para a stack. Se omitido, calcula automaticamente.
---  padding, gap, alignment - Opcionais
---@return YStack
function YStack:new(config)
    if not config or config.x == nil or config.y == nil or config.width == nil then -- Verificação ajustada
        error("YStack:new - Configuração inválida. 'x', 'y', e 'width' são obrigatórios.", 2)
    end
    -- Chama construtor base
    local instance = Component:new(config) ---@class YStack
    setmetatable(instance, YStack)

    -- Propriedades específicas de YStack
    instance.gap = config.gap or 0
    instance.alignment = config.alignment or "left"
    instance.children = {}
    instance.actualHeight = 0
    instance.fixedHeight = config.height -- <<< Armazena altura fixa

    -- Ajusta rect.w herdado e define rect.h inicial
    instance.rect.w = config.width
    instance.rect.h = instance.fixedHeight or 0 -- Usa altura fixa ou 0 inicial

    return instance
end

--- Adiciona um componente filho à stack.
function YStack:addChild(child)
    if not child or not child.rect or not child.rect.w or not child.rect.h then
        print("AVISO (YStack:addChild): Filho inválido ou sem rect/w/h. Ignorando.")
        return
    end
    -- Garante que o filho tenha margin (se não foi passado na config dele, herda da base)
    child.margin = child.margin or { top = 0, right = 0, bottom = 0, left = 0 }
    table.insert(self.children, child)
    self.needsLayout = true
end

--- Calcula e atualiza a posição E LARGURA dos filhos, considerando padding da stack e margin dos filhos.
--- Atualiza a altura REAL do conteúdo em self.actualHeight e define self.rect.h.
function YStack:_updateLayout()
    if not self.needsLayout then return end

    local innerWidth = self.rect.w - self.padding.left - self.padding.right
    local currentY = self.rect.y + self.padding.top
    local contentStartX = self.rect.x + self.padding.left

    -- >>> Loop para posicionar filhos (lógica de posicionamento X/Y igual)
    for i, child in ipairs(self.children) do
        local childMargin = child.margin or { top = 0, right = 0, bottom = 0, left = 0 }
        currentY = currentY + childMargin.top
        local childY = currentY
        local availableWidthForChild = innerWidth - childMargin.left - childMargin.right
        child.rect.w = math.max(0, availableWidthForChild)

        local childX
        if self.alignment == "center" then
            local totalChildWidth = child.rect.w + childMargin.left + childMargin.right
            local centeringOffset = (innerWidth - totalChildWidth) / 2
            childX = contentStartX + centeringOffset + childMargin.left
        elseif self.alignment == "right" then
            childX = contentStartX + innerWidth - child.rect.w - childMargin.right
        else -- Padrão 'left'
            childX = contentStartX + childMargin.left
        end

        child.rect.x = math.floor(childX)
        child.rect.y = math.floor(childY)

        if child.needsLayout and child._updateLayout then
            child:_updateLayout()
        elseif child.needsLayout then
            child.needsLayout = false
        end

        local childHeight = child.rect.h or 0 -- Garante que childHeight seja um número
        currentY = currentY + childHeight + childMargin.bottom + self.gap
    end

    -- >>> Calcula a altura REAL do conteúdo
    local calculatedContentHeight = 0
    if #self.children > 0 then
        local endY = currentY - self.gap -- Y onde o próximo item começaria
        calculatedContentHeight = endY - (self.rect.y + self.padding.top)
    end
    self.actualHeight = math.max(0, calculatedContentHeight) -- Altura total se não houvesse clipping

    -- >>> Define a altura final do componente YStack
    if self.fixedHeight ~= nil then
        -- Usa a altura fixa definida (mais padding)
        self.rect.h = self.fixedHeight
    else
        -- Usa a altura calculada baseada nos filhos (mais padding)
        self.rect.h = self.actualHeight + self.padding.top + self.padding.bottom
    end

    Component._updateLayout(self)
end

--- Atualiza o estado da stack e seus filhos.
--- Sobrescreve o método da classe base.
function YStack:update(dt, mx, my, allowHover)
    self:_updateLayout()

    for _, child in ipairs(self.children) do
        if child.update then
            -- Passa allowHover diretamente, o filho decide se usa
            child:update(dt, mx, my, allowHover)
        end
    end
end

--- Desenha a stack e seus filhos.
--- Aplica clipping interno se fixedHeight foi definido.
function YStack:draw()
    self:_updateLayout()

    -- Desenha debug da stack base
    Component.draw(self)

    -- >>> Aplica Scissor INTERNO se altura for fixa e área for válida
    local needsScissor = self.fixedHeight ~= nil
    local scissorX, scissorY, scissorW, scissorH
    if needsScissor then
        -- Calcula área de recorte DENTRO do padding
        scissorX = math.floor(self.rect.x + self.padding.left)
        scissorY = math.floor(self.rect.y + self.padding.top)
        scissorW = math.floor(self.rect.w - self.padding.left - self.padding.right)
        scissorH = math.floor(self.rect.h - self.padding.top - self.padding.bottom)

        -- Só aplica se a área for positiva
        if scissorW > 0 and scissorH > 0 then
            love.graphics.push()
            love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
        else
            needsScissor = false -- Não aplicar se área for inválida
        end
    end

    -- Desenha os filhos (dentro ou fora do scissor)
    for _, child in ipairs(self.children) do
        if child.draw then
            child:draw()
        else
            if self.debug and child.rect then
                love.graphics.push()
                love.graphics.setColor(1, 1, 0, 0.5)
                love.graphics.rectangle("line", child.rect.x, child.rect.y, child.rect.w, child.rect.h)
                love.graphics.pop()
            end
        end
    end

    -- >>> Remove Scissor se foi aplicado
    if needsScissor then
        love.graphics.setScissor()
        love.graphics.pop()
    end
end

--- Processa cliques do mouse, delegando aos filhos.
--- Sobrescreve o método da classe base.
function YStack:handleMousePress(x, y, button)
    -- Garante layout atualizado antes de verificar limites dos filhos
    self:_updateLayout()

    for i = #self.children, 1, -1 do
        local child = self.children[i]
        if child.handleMousePress then
            -- Verifica se o clique está dentro dos limites ATUALIZADOS do filho
            if x >= child.rect.x and x < child.rect.x + child.rect.w and
                y >= child.rect.y and y < child.rect.y + child.rect.h then
                local consumed = child:handleMousePress(x, y, button)
                if consumed then
                    return true
                end
            end
        end
    end
    return false
end

--- Processa o soltar do mouse, delegando aos filhos.
--- Sobrescreve o método da classe base.
function YStack:handleMouseRelease(x, y, button)
    -- Garante layout atualizado, embora o release possa ocorrer fora
    self:_updateLayout()

    for i = #self.children, 1, -1 do
        local child = self.children[i]
        if child.handleMouseRelease then
            local consumed = child:handleMouseRelease(x, y, button)
            if consumed then
                return true
            end
        end
    end
    return false
end

return YStack
