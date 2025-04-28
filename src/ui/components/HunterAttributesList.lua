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
local attributesToShow = {
    { label = "Vida",            key = "health",            format = "%d" },
    { label = "Defesa",          key = "defense",           format = "%d" },
    { label = "Velocidade",      key = "moveSpeed",         format = "%.1f",   suffix = " m/s" },
    { label = "Chance Crítico",  key = "critChance",        format = "%.1f%%", multiplier = 100 },
    { label = "Dano Crítico",    key = "critDamage",        format = "%.0fx",  multiplier = 100 },
    { label = "Regen. Vida/s",   key = "healthPerTick",     format = "%.1f/s" },
    { label = "Delay Regen.",    key = "healthRegenDelay",  format = "%.1fs" },
    { label = "Atq. Múltiplo",   key = "multiAttackChance", format = "%.1f%%", multiplier = 100 },
    { label = "Vel. Ataque",     key = "attackSpeed",       format = "%.2f/s" },
    { label = "Bônus Exp",       key = "expBonus",          format = "%.0f%%", multiplier = 100 },
    { label = "Redução Recarga", key = "cooldownReduction", format = "%.0f%%", isReduction = true },
    { label = "Alcance",         key = "range",             format = "x%.1f" },
    { label = "Área Ataque",     key = "attackArea",        format = "x%.1f" },
    { label = "Raio Coleta",     key = "pickupRadius",      format = "%d" },
    { label = "Bônus Cura",      key = "healingBonus",      format = "%.0f%%", multiplier = 100 },
    { label = "Slots Runa",      key = "runeSlots",         format = "%d" },
    { label = "Sorte",           key = "luck",              format = "%.1f%%", multiplier = 100 },
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

    local finalStats = self.attributes     -- Usa os atributos guardados
    local lineHeight = fonts.main:getHeight() * 1.2

    for _, attrDef in ipairs(attributesToShow) do
        local finalValue = finalStats[attrDef.key]
        local defaultValue = baseStats[attrDef.key]

        if finalValue ~= nil and defaultValue ~= nil then
            -- Calcula valor final formatado
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

            -- Cria o XStack para esta linha
            local lineXStack = XStack:new({ x = 0, y = 0, height = lineHeight })

            -- Cria o Label (Text)
            local labelText = Text:new({
                text = attrDef.label,
                width = self.rect.w * 0.6, -- Estima largura para o label
                align = "left",
                variant = "default"        -- Cor será atualizada no update/draw
                -- x, y são definidos pelo XStack pai
            })
            labelText.attributeKey = attrDef.key -- Guarda a chave para hover

            -- Cria o Valor (Text)
            local valueText = Text:new({
                text = finalStr,
                width = self.rect.w * 0.4, -- Estima largura para o valor
                align = "right",
                variant = "default"        -- Cor será atualizada no update/draw
                -- x, y são definidos pelo XStack pai
            })
            valueText.attributeKey = attrDef.key -- Guarda a chave para hover

            -- Adiciona Labels ao XStack da linha
            lineXStack:addChild(labelText)
            lineXStack:addChild(valueText)

            -- Adiciona o XStack da linha ao YStack principal
            self.mainYStack:addChild(lineXStack)
        end
    end
    self.mainYStack:_updateLayout()      -- Calcula layout inicial
    self.rect.h = self.mainYStack.rect.h -- Ajusta altura do container
    self.needsLayout = false             -- Marca como layout feito
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
    if not hoveredKey then return end -- Sai se nada em hover

    local attrDefinition = nil
    for _, ad in ipairs(attributesToShow) do
        if ad.key == hoveredKey then
            attrDefinition = ad
            break
        end
    end

    if not attrDefinition then return end

    local baseStats = Constants.HUNTER_DEFAULT_STATS
    if not baseStats then return end

    local finalStats = self.attributes
    local archetypeIds = self.archetypes -- Usa a lista de IDs de arquétipos
    local archetypeManager = self.archetypeManager

    local finalValue = finalStats[hoveredKey]
    local defaultValue = baseStats[hoveredKey]
    if finalValue == nil or defaultValue == nil then return end -- Segurança

    -- Formata valor final (para linha 'Final:' do tooltip)
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

    -- 1. Linha Base
    local baseDisplayValue = defaultValue
    local baseFormat = attrDefinition.format
    local baseMultiplier = displayMultiplier
    if attrDefinition.isReduction then
        baseDisplayValue = (1 - defaultValue) * 100
    elseif attrDefinition.key == "critDamage" then
        baseDisplayValue = defaultValue * 100
    else
        baseDisplayValue = defaultValue * baseMultiplier
    end
    local baseStr = string.format(baseFormat, baseDisplayValue) .. (attrDefinition.suffix or "")
    table.insert(self.tooltipLines, { text = "Base: " .. baseStr, color = colors.text_label })

    -- 2. Linhas de Arquétipos
    local hasArchetypeBonus = false
    -- Verifica se archetypeManager e archetypeIds existem
    if archetypeManager and archetypeIds then
        table.insert(self.tooltipLines, { text = "Arquétipos:", color = colors.text_highlight })
        -- Itera sobre os DADOS dos arquétipos, não só IDs
        for _, archData in ipairs(archetypeIds) do
            -- Verificação extra se archData é válido e tem modifiers
            if archData and archData.modifiers then
                for _, mod in ipairs(archData.modifiers) do
                    if mod.stat == hoveredKey then
                        local modifierText = ""
                        local combinedKey = ""
                        if mod.baseValue then
                            combinedKey = mod.stat .. "_add"
                            modifierText = modifierText ..
                                Formatters.formatArchetypeModifierForTooltip(combinedKey, mod.baseValue)
                        end
                        if mod.multValue then
                            if #modifierText > 0 then modifierText = modifierText .. " | " end
                            combinedKey = mod.stat .. "_mult"
                            modifierText = modifierText ..
                                Formatters.formatArchetypeModifierForTooltip(combinedKey, mod.multValue + 1)
                        end
                        if #modifierText > 0 then
                            table.insert(self.tooltipLines, {
                                text = " - " .. (archData.name or archData.id) .. modifierText, -- Usa archData.id se name não existir
                                color = colors.rank[archData.rank or 'E']
                            })
                            hasArchetypeBonus = true
                        end
                    end
                end
            end
        end
        if not hasArchetypeBonus then
            table.insert(self.tooltipLines, { text = " (Nenhum)", color = colors.text_label })
        end
    else
        -- Remove "Arquétipos:" se não houver dados para mostrar
        if #self.tooltipLines > 0 and self.tooltipLines[#self.tooltipLines].text == "Arquétipos:" then
            table.remove(self.tooltipLines)
        end
    end

    -- Remove a linha "Arquétipos:" se nenhum bônus foi adicionado e ela existe
    if not hasArchetypeBonus and #self.tooltipLines > 1 and self.tooltipLines[2].text == "Arquétipos:" then
        table.remove(self.tooltipLines, 2)
    end

    -- 3. Linha Final
    if #self.tooltipLines > 0 then
        table.insert(self.tooltipLines, { text = "-----------", color = colors.text_label })
        table.insert(self.tooltipLines, { text = "Final: " .. finalStr, color = colors.text_highlight })
    end
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
