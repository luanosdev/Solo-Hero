local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local Constants = require("src.config.constants")
local Formatters = require("src.utils.formatters")
local YStack = require("src.ui.components.YStack")
local XStack = require("src.ui.components.XStack")
local Text = require("src.ui.components.Text")
local Component = require("src.ui.components.Component")

---@class HunterAttributesList : Component -- Indica herança no LDoc
local HunterAttributesList = setmetatable({}, { __index = Component }) -- Define Component como fallback
HunterAttributesList.__index = HunterAttributesList

--- Estrutura definindo quais atributos mostrar e como formatá-los (AINDA USADO para tooltip)
local ATTRIBUTES_DISPLAY_ORDER = {
    { label = "HP Máximo",      key = "health",            format = "%d" },
    { label = "Defesa",         key = "defense",           format = "%d" },
    { label = "Vel. Movimento", key = "moveSpeed",         format = "%.2f" },
    { label = "Chance Crítico", key = "critChance",        format = "%.1f%%",  multiplier = 100 },
    { label = "Dano Crítico",   key = "critDamage",        format = "+%.0f%%", multiplier = 100 },
    { label = "Regen. Vida",    key = "healthPerTick",     format = "%.2f/s" },
    { label = "Vel. Ataque",    key = "attackSpeed",       format = "%.2f/s" },
    { label = "Multi-Ataque",   key = "multiAttackChance", format = "%.1f%%",  multiplier = 100 },
    { label = "Red. Recarga",   key = "cooldownReduction", format = "%.0f%%",  multiplier = 100 },
    { label = "Alcance",        key = "range",             format = "+%.0f%%", multiplier = 100 },
    { label = "Área de Efeito", key = "attackArea",        format = "+%.0f%%", multiplier = 100 },
    { label = "Bônus EXP",      key = "expBonus",          format = "+%.0f%%", multiplier = 100 },
    { label = "Área de Coleta", key = "pickupRadius",      format = "%d" },
    { label = "Bônus Cura",     key = "healingBonus",      format = "%.0f%%",  multiplier = 100 },
    { label = "Slots Runa",     key = "runeSlots",         format = "%d" },
    { label = "Sorte",          key = "luck",              format = "%.1f%%",  multiplier = 100 },
}

--- Cria uma nova instância da lista de atributos.
---@param config table Configuração:
---  attributes (table) - Obrigatório. Tabela com os atributos finais do caçador.
---  archetypes (table|nil) - Opcional (para tooltip). Lista de dados dos arquétipos.
---  archetypeManager (ArchetypeManager|nil) - Opcional (para tooltip).
---  x, y, width, height, padding - Passados para o Component base.
---@return HunterAttributesList
function HunterAttributesList:new(config)
    -- Chama o construtor da classe base (Component)
    local instance = Component:new(config) ---@type HunterAttributesList
    -- Define o metatable da instância para HunterAttributesList
    setmetatable(instance, HunterAttributesList)

    if not config.attributes then
        error("HunterAttributesList:new - 'attributes' são obrigatórios na configuração.", 2)
    end

    instance.attributes = config.attributes
    instance.archetypes = config.archetypes             -- Pode ser nil
    instance.archetypeManager = config.archetypeManager -- Pode ser nil

    instance.mainYStack = nil                           -- Será criado em buildLayout
    instance.tooltipLines = {}
    instance.tooltipX = 0
    instance.tooltipY = 0
    instance.lastAttributes = nil -- Para detectar mudanças
    instance.lastArchetypes = nil
    instance.lastWidth = instance.rect.w
    instance.hoveredAttributeKey = nil

    -- Dispara a primeira construção do layout
    instance.needsLayout = true
    instance:_buildLayout()

    return instance
end

--- Constrói/Reconstrói a estrutura de componentes (YStack -> XStack -> Text).
--- Chamado quando os dados ou a largura mudam.
function HunterAttributesList:_buildLayout()
    -- Limpa stack antiga se existir
    self.mainYStack = YStack:new({ x = self.rect.x, y = self.rect.y, width = self.rect.w, gap = 0, padding = { top = 0, bottom = 0, left = 5, right = 5 } })

    local baseStats = Constants.HUNTER_DEFAULT_STATS
    if not baseStats then return end       -- Não constrói sem base
    if not self.attributes then return end -- Não constrói sem atributos

    local finalStats = self.attributes
    local lineHeight = fonts.main:getHeight() * 1.2

    local innerWidth = self.rect.w -
        (self.mainYStack.padding.left + self.mainYStack.padding.right)
    if innerWidth < 0 then innerWidth = 0 end

    for _, attrDef in ipairs(ATTRIBUTES_DISPLAY_ORDER) do
        local finalValue = finalStats[attrDef.key]
        local defaultValue = baseStats[attrDef.key]

        if finalValue ~= nil and defaultValue ~= nil then
            local displayMultiplier = attrDef.multiplier or 1
            local finalDisplayValue = finalValue
            if attrDef.isReduction then
                finalDisplayValue = (1 - finalValue) * 100
            elseif attrDef.key == "critDamage" then
                finalDisplayValue = finalValue * 100
            else
                finalDisplayValue = finalValue * displayMultiplier
            end
            local finalStr = string.format(attrDef.format, finalDisplayValue) .. (attrDef.suffix or "")

            local lineXStack = XStack:new({ x = 0, y = 0, height = lineHeight })
            local labelWidth = innerWidth * 0.6
            local valueWidth = innerWidth * 0.4

            -- Determina a cor/variante do valor
            local valueVariant = "default"
            if finalValue > defaultValue then
                -- Para 'isReduction' (como cooldownReduction), um valor MENOR é melhor.
                -- E para healthRegenDelay, um valor MENOR também é melhor.
                if attrDef.isReduction or attrDef.key == "healthRegenDelay" then
                    valueVariant = "negative_is_good" -- Verde para reduções que são boas
                else
                    valueVariant = "positive"         -- Verde para aumentos que são bons
                end
            elseif finalValue < defaultValue then
                if attrDef.isReduction or attrDef.key == "healthRegenDelay" then
                    valueVariant = "positive_is_bad" -- Vermelho para aumentos que são ruins (redução menor = ruim)
                else
                    valueVariant = "negative"        -- Vermelho para diminuições que são ruins
                end
            end

            local labelText = Text:new({
                text = attrDef.label,
                width = labelWidth,
                align = "left",
                variant = "default"
            })
            labelText.attributeKey = attrDef.key

            local valueText = Text:new({
                text = finalStr,
                width = valueWidth,
                align = "right",
                variant = valueVariant -- Usa a variante determinada
            })
            valueText.attributeKey = attrDef.key

            lineXStack:addChild(labelText)
            lineXStack:addChild(valueText)
            self.mainYStack:addChild(lineXStack)
        end
    end
    self.mainYStack:_updateLayout()
    self.rect.h = self.mainYStack.rect.h
    self.needsLayout = false
end

--- Atualiza o estado e detecta hover.
function HunterAttributesList:update(dt, mx, my, allowHover)
    -- Verifica se dados ou largura mudaram para reconstruir layout
    local needsRebuild = false
    -- Usa self.attributes e self.archetypes
    if self.lastAttributes ~= self.attributes or self.lastArchetypes ~= self.archetypes or self.lastWidth ~= self.rect.w then
        needsRebuild = true
        self.lastAttributes = self.attributes
        self.lastArchetypes = self.archetypes
        self.lastWidth = self.rect.w
    end

    if needsRebuild then
        if self.attributes then
            self:_buildLayout()   -- Usa self.attributes e self.archetypes
        else
            self.mainYStack = nil -- Limpa se não houver dados
        end
    end

    -- Se não houver stack, não há o que fazer
    if not self.mainYStack then return end

    -- Atualiza a stack principal (que atualizará os filhos)
    -- Passa allowHover para a stack
    self.mainYStack:update(dt, mx, my, allowHover)

    -- Encontra qual linha de atributo está em hover (se hover for permitido)
    self.hoveredAttributeKey = nil
    if allowHover then
        for _, lineXStack in ipairs(self.mainYStack.children) do
            -- Verifica hover nos Text filhos (Label e Valor)
            if lineXStack.children and #lineXStack.children > 0 then
                -- Assume que ambos os Text cobrem a área da linha horizontalmente
                -- Verifica se o mouse está na altura Y do XStack da linha
                if my >= lineXStack.rect.y and my < lineXStack.rect.y + lineXStack.rect.h and
                    mx >= lineXStack.rect.x and mx < lineXStack.rect.x + lineXStack.rect.w then
                    -- Pega a chave do primeiro filho (Label) - ambos devem ter a mesma
                    self.hoveredAttributeKey = lineXStack.children[1].attributeKey
                    break -- Encontrou o hover
                end
            end
        end
    end

    -- Prepara tooltip se houver hover e dados necessários
    self.tooltipLines = {}
    if self.hoveredAttributeKey and self.archetypeManager and self.attributes and self.archetypes then
        -- Atualiza posição do tooltip
        self.tooltipX = mx + 15
        self.tooltipY = my
        self:_prepareTooltip()
    end
end

--- Prepara as linhas do tooltip (separado para clareza).
-- USA DADOS DE self: hoveredKey, attributes, archetypes, archetypeManager
function HunterAttributesList:_prepareTooltip()
    local hoveredKey = self.hoveredAttributeKey
    if not hoveredKey then return end

    local attrDefinition = nil
    for _, ad in ipairs(ATTRIBUTES_DISPLAY_ORDER) do
        if ad.key == hoveredKey then
            attrDefinition = ad
            break
        end
    end

    if not attrDefinition then return end

    local baseStats = Constants.HUNTER_DEFAULT_STATS
    if not baseStats then return end

    local finalStats = self.attributes
    local candidateArchetypesData = self.archetypes

    local finalValue = finalStats[hoveredKey]
    local defaultValue = baseStats[hoveredKey]
    if finalValue == nil or defaultValue == nil then return end

    local baseColor = colors.text_label
    local fixedBonusColor = colors.positive
    local percentBonusColor = colors.warning
    local sourceColor = colors.text_muted
    local finalValueColor = colors.text_highlight

    local displayMultiplier = attrDefinition.multiplier or 1
    local finalDisplayValue = finalValue
    local displayFormat = attrDefinition.format
    if attrDefinition.isReduction then
        finalDisplayValue = (1 - finalValue) * 100
    elseif attrDefinition.key == "critDamage" then
        finalDisplayValue = finalValue * 100
    else
        finalDisplayValue = finalValue * displayMultiplier
    end
    local finalStr = string.format(displayFormat, finalDisplayValue) .. (attrDefinition.suffix or "")

    self.tooltipLines = {}

    local baseDisplayValue = defaultValue
    if attrDefinition.isReduction then
        baseDisplayValue = (1 - defaultValue) * 100
    elseif attrDefinition.key == "critDamage" then
        baseDisplayValue = defaultValue * 100
    else
        baseDisplayValue = defaultValue *
            (attrDefinition.baseMultiplier or displayMultiplier)
    end
    local baseStr = string.format(displayFormat, baseDisplayValue) .. (attrDefinition.suffix or "")
    table.insert(self.tooltipLines, { text = "Base: " .. baseStr, color = baseColor })

    local fixedBonuses = {}
    local percentBonuses = {}

    if candidateArchetypesData then
        for _, archData in ipairs(candidateArchetypesData) do
            if archData and archData.modifiers then
                for _, modifierData in ipairs(archData.modifiers) do
                    if modifierData.stat == hoveredKey then
                        local sourceText = "(" .. (archData.name or archData.id) .. ")"
                        local modStr = ""
                        local val = modifierData.value

                        if modifierData.type == "fixed" then
                            if hoveredKey == "critChance" or hoveredKey == "expBonus" or hoveredKey == "healingBonus" or hoveredKey == "multiAttackChance" then
                                modStr = string.format("%+.1f", val):gsub("\\.0$", "")
                                if attrDefinition.suffix and hoveredKey ~= "critDamage" then
                                    modStr = modStr ..
                                        attrDefinition.suffix:match("^%s*(.+)")
                                end
                            elseif hoveredKey == "critDamage" then
                                modStr = string.format("%+.2fx", val)
                            elseif hoveredKey == "runeSlots" then
                                modStr = string.format("%+d", val)
                            else
                                modStr = string.format("%+.1f", val):gsub("\\.0$", "")
                                if attrDefinition.suffix then modStr = modStr .. attrDefinition.suffix:match("^%s*(.+)") end
                            end
                            table.insert(fixedBonuses,
                                { text = "Arq. " .. sourceText .. ": " .. modStr, color = fixedBonusColor })
                        elseif modifierData.type == "percentage" then
                            modStr = string.format("%+.0f%%", val)
                            table.insert(percentBonuses,
                                { text = "Arq. " .. sourceText .. ": " .. modStr, color = percentBonusColor })
                        elseif modifierData.type == "fixed_percentage_as_fraction" then
                            if hoveredKey == "critDamage" then
                                modStr = string.format("%+.0fx", val * 100)
                            else
                                modStr = string.format("%+.0f%%", val * 100)
                            end
                            table.insert(percentBonuses,
                                { text = "Arq. " .. sourceText .. ": " .. modStr, color = percentBonusColor })
                        end
                    end
                end
            end
        end
    end

    if #fixedBonuses > 0 then
        if #self.tooltipLines > 1 or (#self.tooltipLines == 1 and self.tooltipLines[1].text ~= "Base: " .. baseStr) then
            table.insert(self.tooltipLines, { text = "", color = baseColor })
        end
        table.insert(self.tooltipLines, { text = "Bônus Fixos (Arquétipos):", color = sourceColor })
        for _, bonusLine in ipairs(fixedBonuses) do
            table.insert(self.tooltipLines, bonusLine)
        end
    end

    if #fixedBonuses > 0 and #percentBonuses > 0 then
        table.insert(self.tooltipLines, { text = "-------------", color = colors.text_muted })
    end

    if #percentBonuses > 0 then
        if (#self.tooltipLines > 1 or (#self.tooltipLines == 1 and self.tooltipLines[1].text ~= "Base: " .. baseStr)) and #fixedBonuses == 0 then
            table.insert(self.tooltipLines, { text = "", color = baseColor })
        end
        table.insert(self.tooltipLines, { text = "Bônus Percentuais (Arquétipos):", color = sourceColor })
        for _, bonusLine in ipairs(percentBonuses) do
            table.insert(self.tooltipLines, bonusLine)
        end
    end

    local hasAnyArchetypeBonus = #fixedBonuses > 0 or #percentBonuses > 0
    if not hasAnyArchetypeBonus and #self.tooltipLines == 1 then
        -- Não faz nada, só a base será mostrada
    elseif not hasAnyArchetypeBonus and #self.tooltipLines > 1 then -- Se tinha header mas nenhum bônus
        table.insert(self.tooltipLines, { text = " (Nenhum bônus de arquétipo)", color = colors.text_label })
    end

    if #self.tooltipLines > 0 then
        table.insert(self.tooltipLines, { text = "-------------", color = colors.text_muted })
    end
    table.insert(self.tooltipLines, { text = "Final: " .. finalStr, color = finalValueColor })
end

--- Desenha a lista de atributos e o tooltip.
function HunterAttributesList:draw()
    -- Se o layout ainda não foi feito, tenta construí-lo agora
    if self.needsLayout then
        self:_buildLayout()
    end

    -- Verifica se a stack existe antes de desenhar
    if not self.mainYStack then
        -- Opcional: Desenhar mensagem de "Sem dados" se necessário
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_label)
        love.graphics.printf("Carregando stats...", self.rect.x, self.rect.y + self.rect.h / 2, self.rect.w, "center")
        return
    end

    -- Itera sobre as linhas (XStacks) e depois sobre os Textos (label, value) para aplicar a cor correta
    for _, lineXStack in ipairs(self.mainYStack.children or {}) do
        if lineXStack.children and #lineXStack.children == 2 then
            local labelTextComponent = lineXStack.children[1] -- Componente Text do label
            local valueTextComponent = lineXStack.children[2] -- Componente Text do valor

            -- Define a cor do label (pode ser sempre default ou mudar no hover)
            if self.hoveredAttributeKey == labelTextComponent.attributeKey then
                labelTextComponent.variant = "highlight" -- Supondo que Text tem uma variante highlight
            else
                labelTextComponent.variant = "default"
            end

            -- A variante do valor já foi definida em _buildLayout
            -- Se o componente Text não lida com variantes de cor diretamente,
            -- teríamos que fazer: valueTextComponent:setColor(colors[valueTextComponent.variant] or colors.text_default)
            -- Mas vamos assumir que Text:draw() usa Text.variant para pegar a cor de `colors`
        end
    end

    -- Desenha a stack principal (que desenhará os filhos)
    self.mainYStack:draw()

    -- Desenha o tooltip se houver linhas preparadas
    if #self.tooltipLines > 0 then
        elements.drawTooltipBox(self.tooltipX, self.tooltipY, self.tooltipLines)
    end

    -- Reset final (embora os componentes filhos devam resetar)
    love.graphics.setColor(colors.white)
end

--- Atualiza o layout interno (se necessário). Neste caso, apenas chama o base.
function HunterAttributesList:_updateLayout()
    Component._updateLayout(self)
    -- Marca para reconstruir o layout interno também, se a largura mudou.
    if self.lastWidth ~= self.rect.w then
        self.needsLayout = true
    end
end

return HunterAttributesList
