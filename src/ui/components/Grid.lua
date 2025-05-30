-- src/ui/components/Grid.lua
local Component = require("src.ui.components.Component")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")

---@class Grid : Component
---@field columns number Número de colunas.
---@field gap table { horizontal: number, vertical: number } Espaçamento entre células.
---@field children table Lista de componentes filhos.
local Grid = setmetatable({}, { __index = Component })
Grid.__index = Grid

-- Função helper para parsear gap (similar ao padding/margin do Component)
local function parseGap(value)
    local spacing = { horizontal = 0, vertical = 0 }
    if type(value) == "number" then
        spacing.horizontal, spacing.vertical = value, value
    elseif type(value) == "table" then
        spacing.horizontal = value.horizontal or value[1] or 0
        spacing.vertical = value.vertical or value[2] or spacing.horizontal -- Usa horizontal se vertical ausente
    end
    return spacing
end

--- Cria uma nova instância de Grid.
---@param config table Configuração:
---  columns (number) - Obrigatório. Número de colunas.
---  gap (number|table|nil) - Opcional. Espaçamento entre células (padrão 0).
---  children (table|nil) - Opcional. Filhos iniciais.
---  x, y, width, padding, margin, debug - Passados para o Component base.
---@return Grid
function Grid:new(config)
    if not config or not config.columns or config.columns < 1 then
        error("Grid:new - Configuração inválida. 'columns' é obrigatório e deve ser >= 1.", 2)
    end

    local instance = Component:new(config) ---@type Grid
    setmetatable(instance, Grid)

    instance.columns = math.floor(config.columns)
    instance.gap = parseGap(config.gap)
    instance.children = {}

    -- Adiciona filhos iniciais, se houver
    if config.children then
        for _, child in ipairs(config.children) do
            instance:addChild(child)
        end
    end

    instance.needsLayout = true
    return instance
end

--- Adiciona um componente filho à grid.
---@param child Component O componente a ser adicionado.
function Grid:addChild(child)
    if child then
        -- Não precisa garantir margin aqui, pois layout só considera relativos
        table.insert(self.children, child)
        self.needsLayout = true
    end
end

--- Remove um componente filho.
---@param child Component O componente a ser removido.
function Grid:removeChild(child)
    for i = #self.children, 1, -1 do
        if self.children[i] == child then
            table.remove(self.children, i)
            self.needsLayout = true
            return
        end
    end
end

--- Remove todos os filhos.
function Grid:clearChildren()
    self.children = {}
    self.needsLayout = true
end

--- Calcula o layout da grid e posiciona os filhos RELATIVOS.
function Grid:_updateLayout()
    if not self.needsLayout then return end
    if self.debug then print(string.format("[Grid _updateLayout %s] START. needsLayout=true", self._debug_id or "?")) end

    -- >>> Filtra filhos relativos para layout
    local relativeChildren = {}
    for i, child in ipairs(self.children) do
        if not child.isAbsolute then
            table.insert(relativeChildren, child)
        else
            -- Layout interno de filhos absolutos
            if child.needsLayout and child._updateLayout then
                if self.debug then
                    print(string.format("  [Grid _updateLayout %s] Updating layout for ABSOLUTE child %d",
                        self._debug_id or "?", i))
                end
                child:_updateLayout()
            elseif child.needsLayout then
                child.needsLayout = false
            end
        end
    end
    if self.debug then
        print(string.format("  [Grid _updateLayout %s] Found %d relative children.", self._debug_id or "?",
            #relativeChildren))
    end

    -- Se não há filhos relativos, altura é só padding
    if #relativeChildren == 0 then
        self.rect.h = self.padding.top + self.padding.bottom
        if self.debug then
            print(string.format(
                "  [Grid _updateLayout %s] No relative children. Setting height to padding: %.2f", self._debug_id or "?",
                self.rect.h))
        end
        Component._updateLayout(self)
        return
    end

    local startX = self.rect.x + self.padding.left
    local startY = self.rect.y + self.padding.top
    local innerWidth = self.rect.w - self.padding.left - self.padding.right
    local totalHorizontalGap = self.gap.horizontal * (self.columns - 1)
    local cellWidth = (innerWidth - totalHorizontalGap) / self.columns
    if cellWidth < 0 then cellWidth = 0 end
    if self.debug then
        print(string.format(
            "  [Grid _updateLayout %s] innerWidth=%.2f, totalHGap=%.2f, columns=%d -> cellWidth=%.2f",
            self._debug_id or "?",
            innerWidth, totalHorizontalGap, self.columns, cellWidth))
    end

    local currentX = startX
    local currentY = startY
    local maxHeightInRow = 0
    local currentColumn = 0

    -- >>> Itera sobre filhos RELATIVOS
    for i, child in ipairs(relativeChildren) do
        currentColumn = currentColumn + 1
        if self.debug then
            print(string.format("    [Grid _updateLayout %s] Processing child %d (col %d)",
                self._debug_id or "?", i, currentColumn))
        end

        -- Define posição e largura do filho relativo
        child.rect.x = currentX
        child.rect.y = currentY
        child.rect.w = cellWidth
        if self.debug then
            print(string.format("      -> Set child rect: x=%.2f, y=%.2f, w=%.2f", child.rect.x,
                child.rect.y, child.rect.w))
        end

        -- Calcula layout do filho relativo
        if child._updateLayout then
            if self.debug then print("        -> Calling child:_updateLayout()") end
            child:_updateLayout()
            if self.debug then
                print(string.format("        -> Child layout updated. New child height: %.2f",
                    child.rect.h or -1))
            end
        end

        maxHeightInRow = math.max(maxHeightInRow, child.rect.h or 0)

        -- Avança para a próxima posição
        local isLastColumn = (currentColumn == self.columns)
        local isLastChild = (i == #relativeChildren)

        if isLastColumn or isLastChild then
            if self.debug then
                print(string.format(
                    "      -> End of row (lastCol=%s, lastChild=%s). Moving to next row. MaxHeight=%.2f",
                    tostring(isLastColumn), tostring(isLastChild), maxHeightInRow))
            end
            currentY = currentY + maxHeightInRow + self.gap.vertical
            currentX = startX
            maxHeightInRow = 0
            currentColumn = 0
        else
            currentX = currentX + cellWidth + self.gap.horizontal
        end
    end

    -- Calcula altura total da Grid baseada nos filhos RELATIVOS
    -- Se terminou exatamente na última coluna, currentY já está na posição Y da *próxima* linha.
    -- Se terminou antes da última coluna (último filho), currentY também está na posição Y da *próxima* linha.
    -- A altura do conteúdo é currentY (início da próxima linha) - startY (início da primeira linha) - gap da última linha (que foi adicionado desnecessariamente)
    local contentHeight = currentY - startY - self.gap.vertical
    if #relativeChildren == 0 then contentHeight = 0 end -- Evita altura negativa se não houver filhos
    self.rect.h = contentHeight + self.padding.top + self.padding.bottom
    if self.debug then
        print(string.format(
            "  [Grid _updateLayout %s] Calculated contentHeight=%.2f. Final grid height=%.2f", self._debug_id or "?",
            contentHeight, self.rect.h))
    end

    Component._updateLayout(self)
end

--- Desenha a grid e seus filhos.
function Grid:draw()
    self:_updateLayout()
    if self.debug then print(string.format("[Grid draw %s] START. Drawing base component...", self._debug_id or "?")) end
    Component.draw(self) -- Desenha debug da Grid (rect, padding, etc.)

    if self.debug then
        print(string.format("  [Grid draw %s] Iterating %d children...", self._debug_id or "?",
            #self.children))
    end
    for i, child in ipairs(self.children) do
        if child.draw then
            if self.debug then
                print(string.format(
                    "    [Grid draw %s] Calling draw() for child %d (%s) at x=%.2f, y=%.2f", self._debug_id or "?", i,
                    child._debug_id or "?", child.rect.x, child.rect.y))
            end
            child:draw()
        else
            if self.debug then
                print(string.format("    [Grid draw %s] Skipping draw for child %d (no draw method)",
                    self._debug_id or "?", i))
            end
        end
    end
    if self.debug then print(string.format("[Grid draw %s] END.", self._debug_id or "?")) end
end

--- Atualiza os filhos.
function Grid:update(dt, mx, my, allowHover)
    self:_updateLayout()
    for _, child in ipairs(self.children) do
        if child.update then
            child:update(dt, mx, my, allowHover)
        end
    end
end

--- Delega clique do mouse para os filhos.
---@return boolean consumed
function Grid:handleMousePress(x, y, button)
    self:_updateLayout()
    for _, child in ipairs(self.children) do
        if child.handleMousePress and
            x >= child.rect.x and x < child.rect.x + child.rect.w and
            y >= child.rect.y and y < child.rect.y + child.rect.h then
            -- Passa coordenadas relativas ao filho?
            -- Não, a verificação de clique é feita com coords relativas ao pai (Grid),
            -- mas o handler do filho espera coords relativas ao seu próprio canto (0,0)?
            -- Depende da implementação do filho. Vamos passar as coords relativas à Grid por enquanto.
            if child:handleMousePress(x, y, button) then
                return true -- Consome se o filho consumiu
            end
        end
    end
    return false
end

--- Delega soltar do mouse para os filhos.
---@return boolean consumed
function Grid:handleMouseRelease(x, y, button)
    self:_updateLayout()
    -- O release pode acontecer fora do filho que foi pressionado,
    -- então delegamos para todos os filhos que implementam o handler.
    -- O filho (ex: Button) é responsável por verificar seu estado.
    local consumed = false
    for _, child in ipairs(self.children) do
        if child.handleMouseRelease then
            -- Passa coordenadas relativas à Grid?
            if child:handleMouseRelease(x, y, button) then
                consumed = true
            end
        end
    end
    return consumed
end

-- Outros handlers podem ser delegados de forma similar (scroll, keypress)

return Grid
