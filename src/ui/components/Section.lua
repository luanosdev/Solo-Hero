-- src/ui/components/Section.lua
local Component = require("src.ui.components.Component")
local Text = require("src.ui.components.Text")

---@class Section : Component
---@field titleComponent Text Componente de texto para o título.
---@field contentComponent Component Componente que representa o conteúdo da seção.
---@field gap number Espaçamento vertical entre o título e o conteúdo.
local Section = setmetatable({}, { __index = Component })
Section.__index = Section

--- Cria uma nova instância de Section.
---@param config table Configuração:
---  titleConfig (table) - Obrigatório. Configuração para o Text do título (ex: { text="Título", size="h2" }).
---  contentComponent (Component) - Obrigatório. A instância do componente de conteúdo.
---  gap (number|nil) - Opcional. Espaçamento entre título e conteúdo (padrão 5).
---  x, y, width, padding, margin, debug - Passados para o Component base.
---@return Section
function Section:new(config)
    if not config or not config.titleConfig or not config.contentComponent then
        error("Section:new - Configuração inválida. 'titleConfig' e 'contentComponent' são obrigatórios.", 2)
    end

    -- Chama construtor base (Component)
    local instance = Component:new(config) ---@class Section
    setmetatable(instance, Section)

    -- Cria o componente de título
    -- Garante que tenha uma largura inicial (será ajustada no layout)
    config.titleConfig.width = config.titleConfig.width or 0
    instance.titleComponent = Text:new(config.titleConfig)

    -- Armazena o componente de conteúdo
    instance.contentComponent = config.contentComponent

    -- Define o espaçamento
    instance.gap = config.gap or 5

    -- Garante que o componente de conteúdo também propague a flag de debug, se aplicável
    if instance.debug and instance.contentComponent.debug ~= nil then
        instance.contentComponent.debug = true
    end

    instance.needsLayout = true
    return instance
end

--- Calcula o layout do título e do conteúdo.
function Section:_updateLayout()
    if not self.needsLayout then return end

    local innerWidth = self.rect.w - self.padding.left - self.padding.right
    local currentX = self.rect.x + self.padding.left
    local currentY = self.rect.y + self.padding.top

    -- 1. Layout Título
    self.titleComponent.rect.x = currentX
    self.titleComponent.rect.y = currentY
    self.titleComponent.rect.w = innerWidth -- Título ocupa toda a largura interna
    self.titleComponent:_updateLayout()     -- Calcula altura do texto com a largura definida
    currentY = currentY + self.titleComponent.rect.h

    -- Adiciona espaçamento (gap)
    currentY = currentY + self.gap

    -- 2. Layout Conteúdo
    self.contentComponent.rect.x = currentX
    self.contentComponent.rect.y = currentY
    self.contentComponent.rect.w = innerWidth -- Conteúdo também ocupa a largura interna
    self.contentComponent:_updateLayout()     -- Calcula layout interno do conteúdo
    currentY = currentY + self.contentComponent.rect.h

    -- 3. Calcula altura total da Section
    local contentHeight = currentY - (self.rect.y + self.padding.top)
    self.rect.h = contentHeight + self.padding.bottom

    -- Finaliza o layout
    Component._updateLayout(self)
end

--- Atualiza o conteúdo.
function Section:update(dt, mx, my, allowHover)
    self:_updateLayout() -- Garante layout antes de update
    if self.contentComponent.update then
        -- Passa allowHover diretamente, o filho decide se usa
        self.contentComponent:update(dt, mx, my, allowHover)
    end
    -- Title geralmente não precisa de update
end

--- Desenha o título e o conteúdo.
function Section:draw()
    self:_updateLayout() -- Garante posições corretas antes de desenhar

    -- Desenha debug da Section (rect, padding, margin)
    Component.draw(self)

    -- Desenha Título
    self.titleComponent:draw()

    -- Desenha Conteúdo
    self.contentComponent:draw()
end

--- Delega eventos de mouse para o conteúdo.
function Section:handleMousePress(x, y, button)
    self:_updateLayout() -- Garante rects atualizados
    -- Verifica se o clique está dentro dos limites do CONTEÚDO
    local content = self.contentComponent
    if content.handleMousePress and
        x >= content.rect.x and x < content.rect.x + content.rect.w and
        y >= content.rect.y and y < content.rect.y + content.rect.h then
        return content:handleMousePress(x, y, button)
    end
    return false
end

--- Delega eventos de mouse para o conteúdo.
function Section:handleMouseRelease(x, y, button)
    self:_updateLayout()
    local content = self.contentComponent
    if content.handleMouseRelease then
        -- O release pode ocorrer fora, então delegamos sem verificar bounds aqui
        -- (O componente filho, como Button, fará a verificação necessária)
        return content:handleMouseRelease(x, y, button)
    end
    return false
end

-- Delega outros handlers se necessário (scroll, keypress, etc.)
function Section:handleMouseScroll(dx, dy)
    if self.contentComponent.handleMouseScroll then
        return self.contentComponent:handleMouseScroll(dx, dy)
    end
end

return Section
