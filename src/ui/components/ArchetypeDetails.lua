local Component = require("src.ui.components.Component")
local YStack = require("src.ui.components.YStack")
local Text = require("src.ui.components.Text")
local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local Formatters = require("src.utils.formatters")

-- Mapeamento de IDs de Stats para Nomes Legíveis (Exemplo)
local statDisplayNames = {
    ["health"] = "Vida",
    ["defense"] = "Defesa",
    ["moveSpeed"] = "Vel. Movimento",
    ["critChance"] = "Chance Crítica",
    ["critDamage"] = "Mult. Crítico",
    ["healthPerTick"] = "Regen. Vida/s",
    ["healthRegenDelay"] = "Delay Regen.",
    ["multiAttackChance"] = "Atq. Múltiplo",
    ["attackSpeed"] = "Vel. Ataque",
    ["expBonus"] = "Bônus Exp",
    ["cooldownReduction"] = "Red. Recarga",
    ["range"] = "Alcance",
    ["attackArea"] = "Área",
    ["pickupRadius"] = "Raio Coleta",
    ["healingBonus"] = "Bônus Cura",
    ["runeSlots"] = "Slots Runa",
    ["luck"] = "Sorte",
    -- Adicione outros stats conforme necessário
}

---@class ArchetypeDetails : Component
---@field archetypeData table Dados do arquétipo a ser exibido.
---@field internalStack YStack Stack interna para organizar o conteúdo.
local ArchetypeDetails = {}
ArchetypeDetails.__index = ArchetypeDetails

-- Estabelece a herança da CLASSE ArchetypeDetails em relação a Component
setmetatable(ArchetypeDetails, {
    __index = Component -- Métodos não encontrados em ArchetypeDetails serão procurados em Component
})

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

    -- Define a metatable da INSTÂNCIA para ArchetypeDetails
    setmetatable(instance, ArchetypeDetails)

    instance.archetypeData = config.archetypeData

    -- Cria a YStack interna
    instance.internalStack = YStack:new({
        x = 0,
        y = 0,
        width = 0,   -- Largura será definida pelo pai
        padding = 5, -- Adiciona um padding interno ao card do arquétipo
        gap = 3,
        alignment = "left",
        debug = instance.debug
    })

    instance:_buildLayoutInternal()
    instance.needsLayout = true
    return instance
end

-- Função interna para construir os filhos da internalStack
function ArchetypeDetails:_buildLayoutInternal()
    local data = self.archetypeData
    self.internalStack.children = {} -- Limpa filhos da stack interna

    -- 1. Cabeçalho (Nome, Rank)
    local headerText = data.name or "Arquétipo Desconhecido"
    if data.rank then
        headerText = headerText .. string.format(" (%s)", data.rank)
    end

    self.internalStack:addChild(Text:new({
        text = headerText,
        width = 0,                               -- Stack interna definirá a largura
        size = "h3",
        variant = "rank_" .. (data.rank or 'E'), -- Garante fallback se rank for nil
        fontWeight = "bold",
        align = "left"
    }))

    --[[ Descrição Removida
    if data.description and data.description ~= "" then
        self.internalStack:addChild(Text:new({ ... }))
    end
    --]]

    -- 2. Modificadores
    if data.modifiers and #data.modifiers > 0 then
        -- Adiciona um pequeno espaço ANTES dos modificadores
        local spacer = YStack:new({ x = 0, y = 0, width = 0, height = 5 }) -- Usa height direto
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

            -- Usa o formatador para tooltip, pois ele já lida com _add e _mult corretamente
            local tooltipFormatted = Formatters.formatArchetypeModifierForTooltip(formattedKey,
                isMultiplier and (value + 1) or value)
            valueText = tooltipFormatted:gsub("^: %s*", "") -- Remove ": " do início

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

    -- 1. Define a área disponível para a stack interna (dentro do padding)
    local innerX = self.rect.x + self.padding.left
    local innerY = self.rect.y + self.padding.top
    local innerWidth = self.rect.w - self.padding.left - self.padding.right

    -- 2. Atualiza a posição e largura da stack interna
    self.internalStack.rect.x = innerX
    self.internalStack.rect.y = innerY
    self.internalStack.rect.w = innerWidth -- YStack precisa da largura para seus filhos

    -- 3. Força o layout da stack interna para calcular sua altura e posicionar filhos
    self.internalStack.needsLayout = true
    self.internalStack:_updateLayout()

    -- 4. Define a altura DESTE componente (ArchetypeDetails) com base na altura
    --    calculada da stack interna + padding vertical deste componente.
    self.rect.h = self.internalStack.rect.h + self.padding.top + self.padding.bottom

    -- Marca o layout como concluído para este componente
    self.needsLayout = false
end

--- Sobrescreve draw de Component
function ArchetypeDetails:draw()
    self:_updateLayout() -- Garante que o layout (principalmente altura) esteja atualizado

    -- Desenha debug do Component base (rect, padding, margin)
    Component.draw(self)

    -- Desenha a stack interna (que contém os Text)
    self.internalStack:draw()
end

return ArchetypeDetails
