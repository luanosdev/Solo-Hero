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
    if not child or not child.rect then -- Simplifica verificação, rect é essencial
        print("AVISO (YStack:addChild): Filho inválido ou sem rect. Ignorando.")
        return
    end
    -- Garante que o filho tenha margin (se não for absoluto, layout usará)
    if not child.isAbsolute then
        child.margin = child.margin or { top = 0, right = 0, bottom = 0, left = 0 }
    end
    table.insert(self.children, child)
    self.needsLayout = true
end

--- Calcula e atualiza a posição E LARGURA dos filhos RELATIVOS.
function YStack:_updateLayout()
    if not self.needsLayout then return end

    local innerWidth = self.rect.w - self.padding.left - self.padding.right
    local currentY = self.rect.y + self.padding.top
    local contentStartX = self.rect.x + self.padding.left
    local actualContentHeight = 0 -- Rastreia altura apenas dos filhos relativos

    for i, child in ipairs(self.children) do
        -- >>> SÓ POSICIONA SE NÃO FOR ABSOLUTO
        if not child.isAbsolute then
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

            local childHeight = child.rect.h or 0
            currentY = currentY + childHeight + childMargin.bottom + self.gap
        else
            -- Se for absoluto, ainda chama seu layout interno
            if child.needsLayout and child._updateLayout then
                child:_updateLayout()
            elseif child.needsLayout then
                child.needsLayout = false
            end
            -- NÃO avança currentY
        end
    end

    -- Calcula altura baseada no último filho RELATIVO
    local lastRelativeEndY = self.rect.y + self.padding.top
    for i = #self.children, 1, -1 do
        if not self.children[i].isAbsolute then
            local child = self.children[i]
            local margin = child.margin or { top = 0, bottom = 0 }
            lastRelativeEndY = child.rect.y + (child.rect.h or 0) + margin.bottom
            break
        end
    end
    actualContentHeight = lastRelativeEndY - (self.rect.y + self.padding.top)
    if #self.children == 0 then actualContentHeight = 0 end -- Caso sem filhos
    self.actualHeight = math.max(0, actualContentHeight)

    -- Define altura final do YStack baseada no conteúdo RELATIVO
    self.rect.h = self.actualHeight + self.padding.top + self.padding.bottom

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
function YStack:draw()
    self:_updateLayout()

    -- Desenha debug da stack base
    Component.draw(self)

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
