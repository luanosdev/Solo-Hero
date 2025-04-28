local Component = require("src.ui.components.Component") -- <<< IMPORTA BASE

---@class YStack : Component
---@field width number Largura total disponível para a stack.
---@field padding number Espaçamento interno.
---@field gap number Espaçamento vertical EXTRA entre filhos (além das margens).
---@field alignment string Alinhamento horizontal dos filhos ('left', 'center', 'right').
---@field children table Lista de componentes filhos.
---@field actualHeight number Altura calculada com base nos filhos.
local YStack = setmetatable({}, { __index = Component }) -- <<< HERANÇA
YStack.__index = YStack

--- Cria uma nova instância de YStack.
---@param config table Tabela de configuração contendo:
---@return YStack
function YStack:new(config)
    if not config or not config.x or not config.y or not config.width then
        error("YStack:new - Configuração inválida. 'x', 'y', e 'width' são obrigatórios.", 2)
    end
    -- Chama construtor base (inicializa rect, padding, margin, needsLayout, debug)
    local instance = Component:new(config) ---@class YStack
    setmetatable(instance, YStack)

    -- Propriedades específicas de YStack
    instance.gap = config.gap or 0
    instance.alignment = config.alignment or "left"
    instance.children = {}
    instance.actualHeight = 0

    -- Ajusta rect.w herdado (Component pode ter inicializado com config.w)
    instance.rect.w = config.width

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
function YStack:_updateLayout()
    if not self.needsLayout then return end

    local innerWidth = self.rect.w - self.padding.left - self.padding.right
    local currentY = self.rect.y + self.padding.top -- Y inicial DENTRO do padding
    local contentStartX = self.rect.x + self.padding.left

    for i, child in ipairs(self.children) do
        local childMargin = child.margin

        -- *** 1. Calcula a posição Y do filho ATUAL (baseado no currentY) ***
        currentY = currentY + childMargin.top
        local childY = currentY -- Guarda a posição Y inicial deste filho

        -- *** 2. Define a largura do filho (para cálculo de alinhamento X e altura interna) ***
        local availableWidthForChild = innerWidth - childMargin.left - childMargin.right
        child.rect.w = math.max(0, availableWidthForChild)

        -- *** 3. Calcula a posição X do filho ATUAL (depende da largura do filho) ***
        local childX
        if self.alignment == "center" then
            -- Nota: child.rect.w precisa estar definido antes disto
            local totalChildWidth = child.rect.w + childMargin.left + childMargin.right
            local centeringOffset = (innerWidth - totalChildWidth) / 2
            childX = contentStartX + centeringOffset + childMargin.left
        elseif self.alignment == "right" then
            childX = contentStartX + innerWidth - child.rect.w - childMargin.right
        else -- Padrão 'left'
            childX = contentStartX + childMargin.left
        end

        -- *** 4. Define a posição (absoluta na tela) do filho ANTES de chamar seu layout ***
        child.rect.x = math.floor(childX)
        child.rect.y = math.floor(childY)

        -- *** 5. CHAMA o layout interno do filho (AGORA com a posição correta definida) ***
        if child.needsLayout and child._updateLayout then
            -- O filho (ex: headerStack) usará seu self.rect.y (agora 64) como base
            child:_updateLayout()
        elseif child.needsLayout then
            child.needsLayout = false
        end

        -- *** 6. Lê a altura final do filho (pode ter sido atualizada pelo passo 5) ***
        local childHeight = child.rect.h

        -- *** 7. Atualiza currentY para o PRÓXIMO filho ***
        currentY = currentY + childHeight + childMargin.bottom + self.gap
    end

    -- Calcula a altura total usada (lógica permanece a mesma)
    local calculatedHeight = 0
    if #self.children > 0 then
        local endY = currentY - self.gap
        calculatedHeight = endY - (self.rect.y + self.padding.top) + self.padding.bottom
    else
        calculatedHeight = self.padding.top + self.padding.bottom
    end
    self.actualHeight = math.max(0, calculatedHeight)
    self.rect.h = self.actualHeight

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
--- Sobrescreve o método da classe base.
function YStack:draw()
    self:_updateLayout()

    -- Desenha debug da stack base (agora usa self.rect.w e self.rect.h)
    Component.draw(self)

    -- Desenha área de padding (mantido para visualização específica do YStack)
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
        else
            if self.debug and child.rect then
                love.graphics.push()
                love.graphics.setColor(1, 1, 0, 0.5)
                love.graphics.rectangle("line", child.rect.x, child.rect.y, child.rect.w, child.rect.h)
                love.graphics.pop()
            end
        end
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
