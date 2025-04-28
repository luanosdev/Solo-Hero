local Component = require("src.ui.components.Component")
local YStack = require("src.ui.components.YStack")
local Text = require("src.ui.components.Text")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Formatters = require("src.utils.formatters")

-- Mapeamento de IDs de Stats para Nomes Legíveis (Exemplo)
local statDisplayNames = {
    ["max_hp"] = "Vida Máxima",
    ["hp_regen"] = "Regen. Vida",
    ["defense"] = "Defesa",
    ["damage"] = "Dano",
    ["attack_speed"] = "Vel. Ataque",
    ["critical_chance"] = "Chance Crítica",
    ["critical_multiplier"] = "Mult. Crítico",
    ["movement_speed"] = "Vel. Movimento",
    ["area"] = "Área",
    ["range"] = "Alcance",
    ["projectile_speed"] = "Vel. Projétil",
    ["luck"] = "Sorte",
    -- Adicione outros stats conforme necessário
}

---@class ArchetypeDetails : Component
---@field archetypeData table Dados do arquétipo a ser exibido.
---@field internalStack YStack Stack interna para organizar o conteúdo.
local ArchetypeDetails = setmetatable({}, { __index = Component })
ArchetypeDetails.__index = ArchetypeDetails

--- Cria uma nova instância de ArchetypeDetails.
---@param config table Configuração:
---  archetypeData (table) - Obrigatório. Dados do arquétipo.
---  x, y, width, padding, margin, debug - Passados para o Component base.
---@return ArchetypeDetails
function ArchetypeDetails:new(config)
    if not config or not config.archetypeData then
        error("ArchetypeDetails:new - Configuração inválida. 'archetypeData' é obrigatório.", 2)
    end
    -- Chama construtor base (Component)
    local instance = Component:new(config)
    setmetatable(instance, ArchetypeDetails)

    instance.archetypeData = config.archetypeData

    -- Cria a YStack interna
    instance.internalStack = YStack:new({
        x = 0,
        y = 0,                 -- Posição será controlada pelo _updateLayout do ArchetypeDetails
        width = 0,             -- Largura será controlada pelo _updateLayout do ArchetypeDetails
        padding = 0,           -- Padding principal é do ArchetypeDetails, stack interna não precisa
        gap = 3,               -- Gap entre elementos internos
        alignment = "left",
        debug = instance.debug -- Propaga flag de debug
    })

    instance:_buildLayoutInternal()

    -- Marca para layout (Component base já faz isso, mas reforça)
    instance.needsLayout = true

    return instance
end

-- Função interna para construir os filhos da internalStack
function ArchetypeDetails:_buildLayoutInternal()
    local data = self.archetypeData
    self.internalStack.children = {} -- Limpa filhos da stack interna

    -- 1. Cabeçalho (Nome, Tipo, Rank)
    local headerText = data.name or "Arquétipo Desconhecido"
    local typeRankInfo = {}
    if data.rank then table.insert(typeRankInfo, data.rank) end
    if #typeRankInfo > 0 then
        headerText = headerText .. string.format(" (%s)", table.concat(typeRankInfo, " - "))
    end

    self.internalStack:addChild(Text:new({
        text = headerText,
        width = 0, -- Stack interna definirá a largura
        size = "h3",
        variant = "rank_" .. data.rank,
        fontWeight = "bold",
        align = "left"
    }))

    --[[
    -- 2. Descrição
    if data.description and data.description ~= "" then
        self.internalStack:addChild(Text:new({
            text = data.description,
            width = 0,
            size = "small",
            variant = "text_muted",
            align = "left"
        }))
    end
    --]]

    -- 3. Modificadores
    if data.modifiers and #data.modifiers > 0 then
        -- Adiciona um pequeno espaço ANTES dos modificadores
        local spacer = YStack:new({ x = 0, y = 0, width = 0 })
        spacer.rect.h = 5
        self.internalStack:addChild(spacer)

        for _, mod in ipairs(data.modifiers) do
            local statName = statDisplayNames[mod.stat] or mod.stat or "???"
            local valueText = ""
            local value = 0
            local isMultiplier = false
            local formattedKey = ""

            if mod.baseValue ~= nil then
                value = mod.baseValue
                isMultiplier = false
                formattedKey = mod.stat .. "_add"
            elseif mod.multValue ~= nil then
                value = mod.multValue
                isMultiplier = true
                formattedKey = mod.stat .. "_mult"
            else
                print(string.format("AVISO (ArchetypeDetails): Modificador inválido para stat '%s' em '%s'", mod.stat,
                    data.id or data.name))
                goto continue_mod_loop
            end

            local tooltipFormatted = Formatters.formatArchetypeModifierForTooltip(formattedKey,
                isMultiplier and (value + 1) or value)
            valueText = tooltipFormatted:gsub("^: %s*", "")

            local colorVariant = "text_muted"
            if value > 0 then colorVariant = "positive" end
            if value < 0 then colorVariant = "negative" end

            self.internalStack:addChild(Text:new({
                text = string.format("%s: %s", statName, valueText),
                width = 0,
                size = "small",
                variant = colorVariant,
                align = "left"
            }))
            ::continue_mod_loop::
        end
    end

    -- Marca a stack interna para recalcular seu layout
    self.internalStack.needsLayout = true
    -- Marca o próprio componente ArchetypeDetails para recalcular SEU layout (altura)
    self.needsLayout = true
end

--- Sobrescreve _updateLayout de Component
function ArchetypeDetails:_updateLayout()
    if not self.needsLayout then return end

    -- Define posição e largura da stack interna baseado no rect e padding do ArchetypeDetails
    self.internalStack.rect.x = self.rect.x + self.padding.left
    self.internalStack.rect.y = self.rect.y + self.padding.top
    self.internalStack.rect.w = self.rect.w - self.padding.left - self.padding.right

    -- Calcula o layout da stack interna (isso definirá sua altura self.internalStack.rect.h)
    self.internalStack:_updateLayout()

    -- Define a altura do ArchetypeDetails baseado na altura da stack interna + padding
    self.rect.h = self.internalStack.rect.h + self.padding.top + self.padding.bottom

    -- Chama o _updateLayout da classe base (Component) para marcar needsLayout = false
    Component._updateLayout(self)
end

--- Sobrescreve draw de Component
function ArchetypeDetails:draw()
    self:_updateLayout() -- Garante que o layout (principalmente altura) esteja atualizado

    -- Desenha debug do Component base (rect, padding, margin)
    Component.draw(self)

    -- Desenha a stack interna (que contém os Text)
    self.internalStack:draw()
end

--[[ Se precisar de interatividade no futuro, delegar para internalStack:
function ArchetypeDetails:handleMousePress(x, y, button)
    -- Precisa verificar se o clique está DENTRO da internalStack
    if x >= self.internalStack.rect.x and x < self.internalStack.rect.x + self.internalStack.rect.w and
       y >= self.internalStack.rect.y and y < self.internalStack.rect.y + self.internalStack.rect.h then
        return self.internalStack:handleMousePress(x, y, button)
    end
    return false
end

function ArchetypeDetails:handleMouseRelease(x, y, button)
    -- O release pode acontecer fora, então delegamos direto
    return self.internalStack:handleMouseRelease(x, y, button)
end
]]

return ArchetypeDetails
