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
---@field showModifiers boolean|nil Flag para mostrar/esconder detalhes dos modificadores.
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

    -- print(string.format("[ArchetypeDetails:new PRE-COMPONENT] Config recebido: x=%s, y=%s, width=%s, height=%s, showModifiers=%s", -- COMENTADO
    --     tostring(config.x), tostring(config.y), tostring(config.width), tostring(config.height), tostring(config.showModifiers))) -- Log do config

    -- Chama construtor base (Component)
    local instance = Component:new(config)

    -- Define a metatable da INSTÂNCIA para ArchetypeDetails
    setmetatable(instance, ArchetypeDetails)

    -- TENTATIVA DE CORREÇÃO: Forçar a largura do rect após construtor base
    if config.width then -- MANTIDO - PODE SER NECESSÁRIO
        instance.rect.w = config.width
        -- print(string.format("[ArchetypeDetails:new POST-COMPONENT] Forçando instance.rect.w para: %s", tostring(instance.rect.w))) -- COMENTADO
    end

    instance.archetypeData = config.archetypeData
    instance.showModifiers = config.showModifiers == nil and true or
        config
        .showModifiers -- Padrão para true se não fornecido

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

    -- print(string.format("[ArchetypeDetails:_buildLayoutInternal] ID: %s, ShowModifiers: %s", -- COMENTADO
    --     tostring(data and data.id), tostring(self.showModifiers))) -- Log no início do build

    -- 1. Cabeçalho (Nome, Rank)
    local headerText = data.name or "Arquétipo Desconhecido"

    -- Adiciona o card estilizado de título
    local RankedCardTitle = require("src.ui.components.RankedCardTitle")
    self.internalStack:addChild(RankedCardTitle:new({
        text = headerText,
        rank = data.rank or 'E',
        width = self.rect.w > 0 and self.rect.w or 220, -- A YStack pai ajustará esta largura
        height = 40,                                    -- Altura fixa para o card do título
        config = {
            padding = 8,                                -- Ajuste o padding conforme necessário para a nova altura
            -- font = fonts.title -- Removido, pois RankedCardTitle agora usa dynamicFont
        }
    }))

    -- print(string.format("[ArchetypeDetails:_buildLayoutInternal] Added Header Text: '%s', Font Size: h3, Variant: %s", -- COMENTADO
    --     headerText, "rank_" .. (data.rank or 'E'))) -- Log para o texto do header

    --[[ Descrição Removida
    if data.description and data.description ~= "" then
        self.internalStack:addChild(Text:new({ ... }))
    end
    --]]

    -- 2. Modificadores (Condicionado pela flag)
    if self.showModifiers and data.modifiers and #data.modifiers > 0 then
        local spacer = YStack:new({ x = 0, y = 0, width = 0, height = 5 })
        self.internalStack:addChild(spacer)

        for _, mod in ipairs(data.modifiers) do
            local statName = statDisplayNames[mod.stat] or mod.stat or "??"
            local valueText = "?"

            if mod.type and mod.value ~= nil then
                local val = mod.value
                local originalValueForSign = val -- Guarda o valor original para checar sinal > 0 ou < 0

                if mod.type == "fixed" then
                    valueText = string.format("%.1f", val):gsub("%%.0$", "")
                elseif mod.type == "percentage" then
                    valueText = string.format("%.1f", val):gsub("%%.0$", "") .. "%"
                elseif mod.type == "fixed_percentage_as_fraction" then
                    if mod.stat == "critDamage" then -- Dano crítico é um caso especial, queremos mostrar como +0.xx
                        valueText = string.format("%.2fx", val)
                    else                             -- Outros "fixed_percentage_as_fraction" são mostrados como %
                        valueText = string.format("%.1f", val * 100):gsub("%%.0$", "") .. "%"
                    end
                else
                    print(string.format("AVISO (ArchetypeDetails): Tipo de modificador desconhecido '%s' para stat '%s'",
                        mod.type, mod.stat))
                    valueText = tostring(val) -- Fallback
                end

                -- Adiciona sinal de + explicitamente para valores positivos, exceto se já tiver (como em x para critDamage)
                if originalValueForSign > 0 and not string.match(valueText, "^%+") and not string.match(valueText, "x$") then
                    valueText = "+" .. valueText
                end
                -- Valores negativos já terão o sinal de - pela formatação string.format

                local colorVariant = "text_muted"
                if originalValueForSign > 0 then colorVariant = "positive" end
                if originalValueForSign < 0 then colorVariant = "negative" end

                self.internalStack:addChild(Text:new({
                    text = string.format("%s: %s", statName, valueText),
                    width = 0,
                    size = "small",
                    variant = colorVariant,
                    align = "left"
                }))
            else
                print(string.format(
                    "AVISO (ArchetypeDetails): Modificador inválido (sem type ou value) para stat '%s' em '%s'",
                    mod.stat or "N/A", data.id or data.name))
            end
        end
    end

    self.internalStack.needsLayout = true
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

    local innerWidth = self.rect.w - self.padding.left - self.padding.right
    self.internalStack.rect.w = innerWidth
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
