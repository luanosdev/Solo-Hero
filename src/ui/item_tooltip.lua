---@class ItemTooltip
local ItemTooltip = {}

local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")

-- Constantes para layout
local PADDING = 10
local ICON_SIZE = 64
local LINE_HEIGHT_SMALL = fonts.tooltip and fonts.tooltip:getHeight() * 1.1 or 14
local LINE_HEIGHT_NORMAL = fonts.main_small and fonts.main_small:getHeight() * 1.1 or 16
local LINE_HEIGHT_LARGE = fonts.main and fonts.main:getHeight() * 1.2 or 18
local LINE_HEIGHT_DAMAGE = fonts.title and fonts.title:getHeight() * 0.9 or 24 -- Fonte para o Dano principal
local TEXT_INDENT = 15                                                         -- Novo: para recuar os atributos movidos

local SECTION_SPACING = 8
local STAT_SPACING = 3
local SUB_SECTION_SPACING = 2 -- Reduzido de 5 para aproximar o rótulo "Dano"
local SHADOW_OFFSET_X = 1
local SHADOW_OFFSET_Y = 1

--- Desenha o tooltip do item.
--- @param item table A instância do item a ser exibida.
--- @param baseItemData table Os dados base do item (do itemDataManager).
--- @param x number Posição X onde desenhar o tooltip.
--- @param y number Posição Y onde desenhar o tooltip.
--- @param playerStats table|nil Stats atuais do jogador (para comparação, opcional).
--- @param equippedItem table|nil Item atualmente equipado no slot correspondente (para comparação, opcional).
function ItemTooltip.draw(item, baseItemData, x, y, playerStats, equippedItem)
    if not item or not baseItemData then
        return
    end

    -- Dimensões e cálculos preliminares (serão ajustados)
    local tooltipLines = {}
    local tooltipWidth = 300         -- Largura inicial, será recalculada
    local currentYInternal = PADDING -- Usar uma variável interna para o cálculo de altura das linhas
    local baseAttributesSection = {} -- Novo: para armazenar atributos base a serem movidos

    -- 1. Nome do Item
    table.insert(tooltipLines, {
        text = baseItemData.name or "Nome Desconhecido",
        font = fonts.title_large or fonts.title, -- Usar uma fonte de título maior
        color = colors.rankDetails[item.rarity or "E"].text or colors.text_title,
        alignment = "center",
        height = (fonts.title_large or fonts.title):getHeight() + SECTION_SPACING
    })
    currentYInternal = currentYInternal + (fonts.title_large or fonts.title):getHeight() + SECTION_SPACING

    -- Linha Divisória Fina
    table.insert(tooltipLines, { type = "divider", height = SECTION_SPACING / 2 })
    currentYInternal = currentYInternal + SECTION_SPACING / 2

    -- Seção Principal: Icone à esquerda, Detalhes à direita
    local mainSectionTextStartY = currentYInternal
    local textColumnXOffset = ICON_SIZE +
        PADDING *
        2 -- Offset para a coluna de texto, adicionado PADDING extra entre ícone e texto

    -- Coluna da Direita (Tipo, Raridade, Dano, APS)
    -- Nova Linha: Ranking do Item
    local rankColor = colors.rankDetails[item.rarity].text or colors.text_main

    table.insert(tooltipLines, {
        text = "Arma Ranking " .. item.rarity,
        font = fonts.main_small,
        color = rankColor,
        x_offset_in_column = 0,
        height = LINE_HEIGHT_SMALL,
        is_main_section_text = true
    })
    currentYInternal = currentYInternal + LINE_HEIGHT_SMALL + SUB_SECTION_SPACING -- Espaço após ranking

    -- Linha 3: DANO (Grande)
    local damageDisplay = "-"
    if baseItemData.minDamage and baseItemData.maxDamage then
        damageDisplay = string.format("%d-%d", baseItemData.minDamage, baseItemData.maxDamage)
    elseif baseItemData.damage then
        damageDisplay = tostring(baseItemData.damage)
    end
    local damageFont = fonts.getFittingBoldFont(damageDisplay, 150, LINE_HEIGHT_DAMAGE * 1.3, 42, 28) or
        fonts.title_large

    table.insert(tooltipLines, {
        text = damageDisplay,
        font = damageFont,
        color = colors.text_value,
        x_offset_in_column = 0,
        height = damageFont:getHeight() + SUB_SECTION_SPACING, -- Espaço para o rótulo "Dano" abaixo
        is_main_section_text = true,
        is_main_damage_value = true                            -- Flag para o rótulo "Dano"
    })
    currentYInternal = currentYInternal + damageFont:getHeight() + SUB_SECTION_SPACING

    table.insert(tooltipLines, {
        text = "Dano", -- Rótulo para o valor de dano acima
        font = fonts.main_small,
        color = colors.text_label,
        x_offset_in_column = 0,
        height = LINE_HEIGHT_SMALL,
        is_main_section_text = true
    })
    currentYInternal = currentYInternal + LINE_HEIGHT_SMALL + SUB_SECTION_SPACING / 2 -- Pequeno espaço extra

    -- Ataques por Segundo (permanece na seção principal)
    if baseItemData.type == "weapon" then
        local attacksPerSecond = item.attacksPerSecond or
            baseItemData
            .cooldown -- usa cooldown como fallback se attacksPerSecond não estiver na instância
        if attacksPerSecond then
            table.insert(tooltipLines, {
                text = string.format("%.2f Ataques por Segundo", attacksPerSecond),
                font = fonts.main,
                color = colors.text_default,
                x_offset_in_column = 0,
                height = LINE_HEIGHT_NORMAL,
                is_main_section_text = true
            })
            currentYInternal = currentYInternal + LINE_HEIGHT_NORMAL + SUB_SECTION_SPACING
        end
    end

    -- Stats Base da Arma (a serem movidos para baixo da descrição)
    -- São coletados aqui e adicionados a 'tooltipLines' mais tarde
    if baseItemData.type == "weapon" then
        local attackClass = baseItemData.attackClass or "N/A"
        table.insert(baseAttributesSection, {
            text = "Tipo de Ataque: " .. attackClass,
            font = fonts.main_small,
            color = colors.text_label,
            height = LINE_HEIGHT_SMALL,
            x_offset = TEXT_INDENT -- Recuo
        })

        if baseItemData.range then
            table.insert(baseAttributesSection, {
                text = "Alcance: " .. string.format("%.1f", baseItemData.range),
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL,
                x_offset = TEXT_INDENT -- Recuo
            })
        end

        local areaStat = baseItemData.area or baseItemData.baseAreaEffectRadius
        if areaStat then
            table.insert(baseAttributesSection, {
                text = "Área: " .. string.format("%.1f", areaStat),
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL,
                x_offset = TEXT_INDENT -- Recuo
            })
        end

        if baseItemData.angle then
            local angleText = "Ângulo de Ataque: " .. baseItemData.angle .. "°"
            if baseItemData.maxAngle and baseItemData.maxAngle ~= baseItemData.angle then
                angleText = string.format("Ângulo de Ataque: %sº..%sº", baseItemData.angle, baseItemData.maxAngle)
            end
            table.insert(baseAttributesSection, {
                text = angleText,
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL,
                x_offset = TEXT_INDENT -- Recuo
            })
        end
    end

    local mainSectionTextHeight = currentYInternal - mainSectionTextStartY
    -- Ajuste para o Y do ícone: deve considerar o PADDING superior do tooltip e o mainSectionTextStartY
    -- local iconMinY = y + mainSectionTextStartY -- Removido PADDING extra aqui, será tratado no draw
    local iconSectionHeight = ICON_SIZE -- Altura real reservada para o ícone
    -- A altura da seção principal agora depende do texto OU do ícone, o que for maior.
    -- O ícone tem PADDING acima e abaixo dele dentro do seu espaço de ICON_SIZE + PADDING*2 na coluna esquerda
    currentYInternal = mainSectionTextStartY + math.max(mainSectionTextHeight, iconSectionHeight + PADDING)

    -- Linha Divisória (após seção principal)
    table.insert(tooltipLines, { type = "divider", height = SECTION_SPACING })
    currentYInternal = currentYInternal + SECTION_SPACING

    -- Descrição do Item (se houver)
    if baseItemData.description and string.len(baseItemData.description) > 0 then
        local descFont = fonts.tooltip or fonts.main_small
        local wrappedDesc, numDescLines = descFont:getWrap(baseItemData.description, tooltipWidth - PADDING * 2)
        for i = 1, #numDescLines do
            table.insert(tooltipLines, {
                text = numDescLines[i],
                font = descFont,
                color = colors.text_muted,
                height = LINE_HEIGHT_SMALL
            })
            currentYInternal = currentYInternal + LINE_HEIGHT_SMALL
        end
        table.insert(tooltipLines, { type = "spacer", height = SECTION_SPACING / 2 })
        currentYInternal = currentYInternal + SECTION_SPACING / 2
    end

    -- Adicionar Atributos Base (movidos)
    if #baseAttributesSection > 0 then
        if (baseItemData.description and string.len(baseItemData.description) > 0) or (item.affixes and #item.affixes > 0) then
            -- Adiciona divisor apenas se houver descrição ou afixos antes
            table.insert(tooltipLines, { type = "divider", height = SECTION_SPACING })
            currentYInternal = currentYInternal + SECTION_SPACING
        end
        for _, attrLine in ipairs(baseAttributesSection) do
            table.insert(tooltipLines, attrLine)
            currentYInternal = currentYInternal + attrLine.height
        end
        table.insert(tooltipLines, { type = "spacer", height = STAT_SPACING })
        currentYInternal = currentYInternal + STAT_SPACING
    end

    -- Atributos (Afixes)
    if item.affixes and #item.affixes > 0 then
        -- Divisor antes dos afixos (se já não houver um da seção de atributos base)
        if #baseAttributesSection == 0 and not (baseItemData.description and string.len(baseItemData.description) > 0) then
            table.insert(tooltipLines, { type = "divider", height = SECTION_SPACING / 2 })
            currentYInternal = currentYInternal + SECTION_SPACING / 2
        elseif #baseAttributesSection > 0 then
            -- Se já tivemos atributos base, não precisamos de outro divisor grosso aqui, a menos que não houvesse descrição
            if not (baseItemData.description and string.len(baseItemData.description) > 0) then
                table.insert(tooltipLines, { type = "divider", height = SECTION_SPACING / 2 })
                currentYInternal = currentYInternal + SECTION_SPACING / 2
            end
        end

        for _, affix in ipairs(item.affixes) do
            local affixColor = colors.text_highlight
            if affix.modifier and affix.modifier > 0 then
                affixColor = colors.positive
            elseif affix.modifier and affix.modifier < 0 then
                affixColor = colors.negative
            end

            table.insert(tooltipLines, {
                text = affix.description or "Atributo desconhecido",
                font = fonts.main_small,
                color = affixColor,
                height = LINE_HEIGHT_SMALL
            })
            currentYInternal = currentYInternal + LINE_HEIGHT_SMALL
        end
        table.insert(tooltipLines, { type = "spacer", height = STAT_SPACING })
        currentYInternal = currentYInternal + STAT_SPACING
    end

    -- Divisor antes do Rodapé (se houver afixos)
    if item.affixes and #item.affixes > 0 then
        table.insert(tooltipLines, { type = "divider", height = SECTION_SPACING })
        currentYInternal = currentYInternal + SECTION_SPACING
    end

    -- Rodapé (Requerimentos, Valor, Durabilidade)
    if baseItemData.requiredLevel and baseItemData.requiredLevel > 0 then
        local reqMet = true -- Placeholder
        local reqColor = reqMet and colors.text_label or colors.red
        table.insert(tooltipLines, {
            text = "Nível Requerido: " .. baseItemData.requiredLevel,
            font = fonts.main_small,
            color = reqColor,
            height = LINE_HEIGHT_SMALL
        })
        currentYInternal = currentYInternal + LINE_HEIGHT_SMALL
    end

    if item.sellValue and item.sellValue > 0 then
        table.insert(tooltipLines, {
            text = "Valor: " .. item.sellValue,
            font = fonts.main_small,
            color = colors.text_gold or colors.text_label,
            height = LINE_HEIGHT_SMALL
        })
        currentYInternal = currentYInternal + LINE_HEIGHT_SMALL
    end

    if item.durability and item.maxDurability then
        table.insert(tooltipLines, {
            text = string.format("Durabilidade: %d/%d", item.durability, item.maxDurability),
            font = fonts.main_small,
            color = colors.text_label,
            height = LINE_HEIGHT_SMALL
        })
        currentYInternal = currentYInternal + LINE_HEIGHT_SMALL
    end

    -- Calcular altura total e largura máxima real
    local totalHeight = PADDING
    local maxLineWidth = 0
    for _, lineInfo in ipairs(tooltipLines) do
        totalHeight = totalHeight + lineInfo.height
        if lineInfo.text then
            love.graphics.setFont(lineInfo.font or fonts.main_small)
            local textW = (lineInfo.font or fonts.main_small):getWidth(lineInfo.text)
            local currentLineW = (lineInfo.x_offset_in_column and textColumnXOffset + PADDING or PADDING) + textW
            if lineInfo.alignment == "center" then
                currentLineW = textW + PADDING * 2 -- Assume que centralizado usa a largura toda
            end
            maxLineWidth = math.max(maxLineWidth, currentLineW)
        end
    end
    totalHeight = totalHeight + PADDING
    tooltipWidth = math.max(tooltipWidth, maxLineWidth + PADDING)
    if ICON_SIZE > 0 then                                                        -- Garante espaço para o ícone se ele existir
        tooltipWidth = math.max(tooltipWidth, textColumnXOffset + PADDING + 150) -- 150 é uma estimativa para a largura da coluna de texto
    end

    -- Ajuste de posição para não sair da tela
    local screenW, screenH = love.graphics.getDimensions()
    if x + tooltipWidth > screenW then x = screenW - tooltipWidth end
    if y + totalHeight > screenH then y = screenH - totalHeight end
    x = math.max(0, x)
    y = math.max(0, y)

    -- Desenhar Fundo e Borda
    local rankStyleData = colors.rankDetails[item.rarity or "E"] or colors.rankDetails["E"]
    local gradStartColor = rankStyleData.gradientStart
    local gradEndColor = rankStyleData.gradientEnd
    local borderColor = rankStyleData.border or colors.tooltip_border or { 0.4, 0.45, 0.5, 0.8 }
    local cornerRadius = 5

    -- Verificar se as cores de gradiente são válidas tabelas de cores
    local useGradient = elements.drawVerticalGradientRect and
        type(gradStartColor) == "table" and #gradStartColor >= 3 and
        type(gradEndColor) == "table" and #gradEndColor >= 3

    if useGradient then
        elements.drawVerticalGradientRect(x, y, tooltipWidth, totalHeight, gradStartColor, gradEndColor, cornerRadius)
    else
        -- Fallback para cor sólida se drawVerticalGradientRect não estiver disponível ou cores inválidas
        local fallbackBg = colors.tooltip_bg or { 0.1, 0.1, 0.15, 0.95 }
        if type(gradStartColor) == "table" and #gradStartColor >= 3 then -- Tenta usar pelo menos a cor inicial do gradiente
            fallbackBg = { gradStartColor[1], gradStartColor[2], gradStartColor[3], gradStartColor[4] or 0.95 }
        end
        love.graphics.setColor(fallbackBg)
        love.graphics.rectangle("fill", x, y, tooltipWidth, totalHeight, cornerRadius, cornerRadius)
    end

    local showGlow = (item.rarity == "S" or item.rarity == "SS" or item.rarity == "A")
    if showGlow and elements.setGlowShader and love.graphics.getShader() then
        -- Usa a cor do texto da raridade para o brilho, se disponível e válida
        local glowColor = rankStyleData.text
        if type(glowColor) ~= "table" or #glowColor < 3 then
            glowColor = { borderColor[1], borderColor[2], borderColor[3] } -- Fallback para cor da borda
        end
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.3)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 1, y - 1, tooltipWidth + 2, totalHeight + 2, cornerRadius + 1)
        love.graphics.setLineWidth(1)
    else
        love.graphics.setColor(borderColor)
        love.graphics.rectangle("line", x, y, tooltipWidth, totalHeight, cornerRadius)
    end

    -- Desenhar Ícone do Item (Coluna Esquerda)
    if item.icon and type(item.icon) == "userdata" then
        -- O Y do ícone deve ser alinhado com o início da seção de texto principal (mainSectionTextStartY)
        -- mas relativo ao Y do tooltip (y) e centralizado no espaço ICON_SIZE.
        local iconDisplayContainerY = y + mainSectionTextStartY
        local iconDisplayContainerHeight = ICON_SIZE -- A altura do contêiner para o ícone

        local aspectRatio = item.icon:getWidth() / item.icon:getHeight()
        local drawW, drawH
        if aspectRatio > 1 then -- Mais largo que alto
            drawW = ICON_SIZE
            drawH = ICON_SIZE / aspectRatio
        else -- Mais alto que largo ou quadrado
            drawH = ICON_SIZE
            drawW = ICON_SIZE * aspectRatio
        end
        -- Centraliza horizontalmente o ícone dentro do espaço PADDING + ICON_SIZE + PADDING
        local iconDrawX = x + PADDING + (ICON_SIZE - drawW) / 2
        -- Centraliza verticalmente o ícone dentro do 'iconDisplayContainerHeight'
        local iconDrawY = iconDisplayContainerY + (iconDisplayContainerHeight - drawH) / 2

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(item.icon, iconDrawX, iconDrawY, 0, drawW / item.icon:getWidth(),
            drawH / item.icon:getHeight())
    end

    -- Desenhar Linhas de Texto
    local currentDrawY = y + PADDING
    local shadowColor = colors.black_transparent_more or { 0, 0, 0, 0.6 }

    for _, lineInfo in ipairs(tooltipLines) do
        if lineInfo.type == "divider" then
            love.graphics.setColor(colors.window_border or { 0.3, 0.3, 0.3, 0.7 })
            love.graphics.rectangle("fill", x + PADDING, currentDrawY + lineInfo.height / 2 - 0.5,
                tooltipWidth - PADDING * 2, 1)
            currentDrawY = currentDrawY + lineInfo.height
        elseif lineInfo.type == "spacer" then
            currentDrawY = currentDrawY + lineInfo.height
        elseif lineInfo.text then
            love.graphics.setFont(lineInfo.font or fonts.main_small)

            local textX = x + PADDING
            if lineInfo.is_main_section_text then
                textX = x + textColumnXOffset + (lineInfo.x_offset_in_column or 0)
            elseif lineInfo.x_offset then
                textX = x + PADDING + (lineInfo.x_offset or 0)
            end

            local printX = textX
            local textW_for_align = (lineInfo.font or fonts.main_small):getWidth(lineInfo.text)

            if lineInfo.alignment == "center" then
                printX = x + (tooltipWidth - textW_for_align) / 2
            elseif lineInfo.alignment == "right" then
                printX = x + tooltipWidth - PADDING - textW_for_align - (lineInfo.x_offset or 0)
            end

            -- Desenha Sombra
            love.graphics.setColor(shadowColor)
            if lineInfo.is_main_damage_value then
                love.graphics.print(lineInfo.text, printX + SHADOW_OFFSET_X, currentDrawY + SHADOW_OFFSET_Y)
            else
                love.graphics.print(lineInfo.text, printX + SHADOW_OFFSET_X, currentDrawY + SHADOW_OFFSET_Y)
            end

            -- Desenha Texto Principal
            love.graphics.setColor(lineInfo.color or colors.text_main)
            if lineInfo.is_main_damage_value then                        -- Desenha "Dano" abaixo do valor principal
                love.graphics.print(lineInfo.text, printX, currentDrawY) -- Imprime o valor do dano
                -- O rótulo "Dano" será impresso pela próxima entrada em tooltipLines
            else
                love.graphics.print(lineInfo.text, printX, currentDrawY)
            end
            currentDrawY = currentDrawY + lineInfo.height
        end
    end

    love.graphics.setColor(colors.white) -- Reset
end

return ItemTooltip
