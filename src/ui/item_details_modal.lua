---@class ItemDetailsModal
local ItemDetailsModal = {}

local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local elements = require("src.ui.ui_elements")
local Formatters = require("src.utils.formatters")
local Constants = require("src.config.constants")

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

-- Constantes para altura mínima e valor fixo
local MIN_MODAL_HEIGHT = 200    -- Altura mínima do modal
local VALUE_SECTION_HEIGHT = 40 -- Altura fixa da seção de valor

--- Desenha o tooltip do item.
--- @param item BaseItem|BaseWeapon A instância do item a ser exibida.
--- @param baseItemData table Os dados base do item (do itemDataManager).
--- @param x number Posição X onde desenhar o tooltip.
--- @param y number Posição Y onde desenhar o tooltip.
--- @param playerStats table|nil Stats atuais do jogador (para comparação, opcional).
--- @param equippedItem table|nil Item atualmente equipado no slot correspondente (para comparação, opcional).
function ItemDetailsModal.draw(item, baseItemData, x, y, playerStats, equippedItem)
    if not item or not baseItemData then
        error("[ItemDetailsModal.draw] ERRO: item ou baseItemData não fornecidos.")
    end

    -- Dimensões e cálculos preliminares (serão ajustados)
    local tooltipLines = {}
    local tooltipWidth = 300         -- Largura inicial, será recalculada
    local currentYInternal = PADDING -- Usar uma variável interna para o cálculo de altura das linhas
    local baseAttributesSection = {} -- Novo: para armazenar atributos base a serem movidos

    -- Define a cor do texto baseado na raridade do item
    local rankStyleData = colors.rankDetails[item.rarity or item.rank] or colors.rankDetails["E"]
    local rankTextColor = rankStyleData.text or colors.text_label

    local iconColumnWidth = tooltipWidth * 0.4          -- 40% para o ícone
    local textColumnWidth = tooltipWidth * 0.6          -- 60% para o texto ao lado
    local textColumnXOffset = iconColumnWidth + PADDING -- Offset para a coluna de texto, PADDING entre ícone e texto

    Logger.info("item_details_modal.draw.fd",
        "[ItemDetailsModal.draw] Desenhando tooltip para item: " .. Logger.dumpTable(baseItemData, 2))
    -- 1. Nome do Item (ocupa a largura total do tooltip)
    table.insert(tooltipLines, {
        text = baseItemData:getLocalizedName(),
        font = fonts.title_large or fonts.title,
        color = colors.rankDetails[item.rarity or "E"].text or colors.text_title,
        alignment = "center",
        height = (fonts.title_large or fonts.title):getHeight() + SECTION_SPACING
    })
    currentYInternal = currentYInternal + (fonts.title_large or fonts.title):getHeight() + SECTION_SPACING
    local headerEndY = currentYInternal -- Guardar Y onde o cabeçalho (nome) termina

    -- Seção Principal: Icone à esquerda, Detalhes à direita
    local mainSectionContentStartY = currentYInternal
    local mainSectionTextLines = {} -- Linhas de texto para a coluna da direita

    -- Coluna da Direita (Tipo, Raridade, Dano, APS)
    local rankColor = colors.rankDetails[item.rarity].text or colors.text_main
    local rankText = _T("item.type.item")
    if item.type == "weapon" then
        rankText = _T("item.type.weapon")
    elseif item.type == "artefact" then
        rankText = _T("item.type.artefact")
    elseif item.type == "rune" then
        rankText = _T("item.type.rune")
    elseif item.type == "teleport_stone" then
        rankText = _T("item.type.teleport_stone")
    end

    table.insert(mainSectionTextLines, {
        text = _T("ui.item_details_modal.type_and_rank", { type_t = rankText, rank = item.rarity }),
        font = fonts.main_small,
        color = rankColor,
        height = LINE_HEIGHT_SMALL,
    })

    if baseItemData.damage then
        local damageDisplay = tostring(baseItemData.damage)
        local damageFont = fonts.getFittingBoldFont(
            damageDisplay,
            textColumnWidth - PADDING * 2,
            LINE_HEIGHT_DAMAGE * 1.3,
            42,
            28
        )
        table.insert(mainSectionTextLines, {
            text = damageDisplay,
            font = damageFont,
            color = colors.text_value,
            height = damageFont:getHeight() + SUB_SECTION_SPACING,
            is_main_damage_value = true
        })
        table.insert(mainSectionTextLines, {
            text = _T("ui.item_details_modal.damage"),
            font = fonts.main_small,
            color = colors.text_label,
            height = LINE_HEIGHT_SMALL,
        })

        if baseItemData.type == "weapon" then
            local attacksPerSecond = baseItemData.cooldown
            if attacksPerSecond then
                table.insert(mainSectionTextLines, {
                    text = _P("ui.item_details_modal.attacks_per_second", { attacksPerSecond = attacksPerSecond }),
                    font = fonts.main_small_bold,
                    color = colors.text_default,
                    height = LINE_HEIGHT_NORMAL,
                })
            end
            local damagePerSecond = baseItemData.damage / baseItemData.cooldown
            damagePerSecond = Formatters.formatCompactNumber(damagePerSecond, 2)
            table.insert(mainSectionTextLines, {
                text = _P("ui.item_details_modal.damage_per_second", { damagePerSecond = damagePerSecond }),
                font = fonts.main_small_bold,
                color = colors.text_default,
                height = LINE_HEIGHT_NORMAL,
            })
        end
    end

    local mainSectionTextHeight = 0
    for _, line in ipairs(mainSectionTextLines) do mainSectionTextHeight = mainSectionTextHeight + line.height end

    local mainSectionHeight = math.max(mainSectionTextHeight, ICON_SIZE) + PADDING * 2
    currentYInternal = mainSectionContentStartY + mainSectionHeight
    local mainSectionEndY = currentYInternal

    -- Stats Base da Arma (coletados para baseAttributesSection como antes)
    if baseItemData.type == "weapon" then
        local attackClass = baseItemData.attackClass or "N/A"
        table.insert(baseAttributesSection, {
            text = _P("ui.item_details_modal.attack_type", { attackType_t = _T("attack_types." .. attackClass) }),
            font = fonts.main_small,
            color = colors.text_label,
            height = LINE_HEIGHT_SMALL
        })

        if baseItemData.range then
            table.insert(baseAttributesSection, {
                text = _P("item.attributes.range", { range = string.format("%.1f", baseItemData.range) }),
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL
            })
        end

        local areaStat = baseItemData.baseAreaEffectRadius
        if areaStat then
            local areaStatText = Constants.pixelsToMeters(areaStat)
            table.insert(baseAttributesSection, {
                text = _P("item.attributes.base_area_effect_radius",
                    { baseAreaEffectRadius = string.format("%.1f", areaStatText) }),
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL
            })
        end

        if baseItemData.angle then
            local angleDegrees = math.deg(baseItemData.angle)
            table.insert(baseAttributesSection, {
                text = _P("item.attributes.angle", { angle = angleDegrees }),
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL
            })
        end

        if baseItemData.knockbackPower then
            local knockbackPowerText = Constants.knockbackPowerToText(baseItemData.knockbackPower)
            table.insert(baseAttributesSection, {
                text = _P("item.attributes.knockback", { knockbackPower = knockbackPowerText }),
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL
            })
        end

        if baseItemData.projectiles then
            table.insert(baseAttributesSection, {
                text = _P("item.attributes.projectiles", { projectiles = baseItemData.projectiles }),
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL
            })
        end

        if baseItemData.chainCount then
            table.insert(baseAttributesSection, {
                text = _P("item.attributes.chain_count", { chainCount = baseItemData.chainCount }),
                font = fonts.main_small,
                color = colors.text_label,
                height = LINE_HEIGHT_SMALL
            })
        end
    end

    -- Reorganiza tooltipLines para inserir as linhas da seção principal calculadas
    -- Nome do Item já está em tooltipLines[1]
    for _, line in ipairs(mainSectionTextLines) do
        line.is_main_section_text = true -- Marcar para posicionamento correto no draw
        table.insert(tooltipLines, line)
    end

    -- Descrição do Item (se houver)
    local descriptionSectionStartY = currentYInternal
    local descriptionTextLines = {}
    local descriptionContentHeight = 0 -- Altura apenas do CONTEÚDO de texto da descrição
    if baseItemData:getLocalizedDescription() and string.len(baseItemData:getLocalizedDescription()) > 0 then
        local descFont = fonts.tooltip or fonts.main_small
        local _, numDescLines = descFont:getWrap(baseItemData:getLocalizedDescription(), tooltipWidth - PADDING * 4) -- PADDING*2 de cada lado da descrição
        for i = 1, #numDescLines do
            table.insert(descriptionTextLines, {
                text = numDescLines[i],
                font = descFont,
                color = rankTextColor,
                height = LINE_HEIGHT_SMALL
            })
            descriptionContentHeight = descriptionContentHeight + LINE_HEIGHT_SMALL
        end
        if #descriptionTextLines > 0 then
            -- descriptionHeight (altura total da caixa de descrição) agora é calculada separadamente
            table.insert(tooltipLines, {
                type = "description_marker_start",
                calculated_text_height = descriptionContentHeight,
                height = 0
            })
            for _, line in ipairs(descriptionTextLines) do table.insert(tooltipLines, line) end
            table.insert(tooltipLines, { type = "description_marker_end", height = 0 })
            -- A altura total da seção de descrição (descriptionHeightVisual) será descriptionContentHeight + PADDING * 2 (para paddings internos)
            -- currentYInternal é avançado pela altura visual da seção de descrição
            currentYInternal = currentYInternal + descriptionContentHeight + PADDING * 2 + SECTION_SPACING / 2
        end
    end
    local descriptionSectionEndY = currentYInternal -- Este Y é após a seção de descrição + seu espaçamento inferior


    -- Stats da Arma (se aplicável)
    if item.modifiers and #item.modifiers > 0 then
        for _, mod in ipairs(item.modifiers) do
            local statLabel = Formatters.getStatLabel(mod.stat) or mod.stat
            local statValueStr = Formatters.formatStatValue(mod.stat, mod.value, mod.type)

            local valueColor = colors.positive
            local prefix = mod.value >= 0 and "+" or ""
            if mod.value < 0 then
                valueColor = colors.negative
            end

            table.insert(baseAttributesSection, {
                type = "multi-part",
                height = LINE_HEIGHT_SMALL,
                parts = {
                    {
                        text = statLabel .. ": ",
                        font = fonts.hud,
                        color = colors.text_label
                    },
                    {
                        text = " " .. prefix .. statValueStr,
                        font = fonts.hud,
                        color = valueColor
                    }
                }
            })
        end
    end

    -- Adicionar Atributos Base (movidos para tooltipLines)
    if #baseAttributesSection > 0 then
        table.insert(tooltipLines, { type = "spacer", height = SECTION_SPACING }) -- Espaço antes dos atributos
        currentYInternal = currentYInternal + SECTION_SPACING
        for _, attrLine in ipairs(baseAttributesSection) do
            table.insert(tooltipLines, attrLine)
            currentYInternal = currentYInternal + attrLine.height
        end
        table.insert(tooltipLines, { type = "spacer", height = STAT_SPACING })
        currentYInternal = currentYInternal + STAT_SPACING
    end

    -- Atributos (Afixes)
    if item.affixes and #item.affixes > 0 then
        table.insert(tooltipLines, { type = "spacer", height = SECTION_SPACING / 2 })
        currentYInternal = currentYInternal + SECTION_SPACING / 2
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

    if baseItemData.type == "consumable" and baseItemData.useDetails then
        table.insert(tooltipLines, { type = "spacer", height = SECTION_SPACING / 2 })
        currentYInternal = currentYInternal + SECTION_SPACING / 2
        table.insert(tooltipLines, {
            text = _T("ui.item_details_modal.use_details"),
            font = fonts.main_small,
            color = colors.text_label,
            alignment = "center",
            height = LINE_HEIGHT_SMALL
        })
        currentYInternal = currentYInternal + LINE_HEIGHT_SMALL
    end

    -- Calcular informações do valor (será tratado separadamente no final)
    local hasValueSection = baseItemData.value and baseItemData.value > 0
    local sellPrice = 0
    local formattedPrice = ""
    if hasValueSection then
        local quantity = item.quantity or 1
        sellPrice = baseItemData.value * quantity
        formattedPrice = Formatters.formatCompactNumber(sellPrice, 2)
    end

    -- Calcular altura total e largura máxima real usando currentYInternal (que já contém toda a altura do conteúdo)
    local contentHeight = currentYInternal -- currentYInternal já contém toda a altura do conteúdo acumulada
    local maxLineWidth = 0

    -- Recalcula maxLineWidth baseado no tooltipLines final
    maxLineWidth = tooltipWidth -- Definido inicialmente, mas o texto pode expandir

    for lineIdx = #tooltipLines, 1, -1 do
        local lineInfo = tooltipLines[lineIdx]
        local currentLineW = 0
        if lineInfo.text and lineInfo.font then
            currentLineW = (lineInfo.font):getWidth(lineInfo.text)
        elseif lineInfo.parts then
            for _, part in ipairs(lineInfo.parts) do
                currentLineW = currentLineW + (part.font):getWidth(part.text)
            end
        end

        local totalLineW = (lineInfo.x_offset or 0) + currentLineW + PADDING * 2
        if lineInfo.is_main_section_text then
            totalLineW = textColumnXOffset + (lineInfo.x_offset_in_column or 0) + currentLineW + PADDING
        end
        if lineInfo.alignment == "center" then totalLineW = currentLineW + PADDING * 2 end
        maxLineWidth = math.max(maxLineWidth, totalLineW)
    end

    -- Calcula altura total: conteúdo atual + seção de valor (se existir) + padding final
    local totalHeight = contentHeight + PADDING -- Conteúdo + padding final

    -- Adiciona espaçamento e altura da seção de valor se existir
    if hasValueSection then
        totalHeight = totalHeight + SECTION_SPACING + VALUE_SECTION_HEIGHT
    end

    -- Aplica altura mínima
    totalHeight = math.max(totalHeight, MIN_MODAL_HEIGHT)

    tooltipWidth = maxLineWidth -- Ajusta a largura do tooltip para o conteúdo
    iconColumnWidth = tooltipWidth * 0.4
    textColumnXOffset = iconColumnWidth + PADDING

    local screenW, screenH = ResolutionUtils.getGameDimensions()
    if x + tooltipWidth > screenW then x = screenW - tooltipWidth end
    if y + totalHeight > screenH then y = screenH - totalHeight end
    x = math.max(0, x)
    y = math.max(0, y)

    local gradStartColor = rankStyleData.gradientStart
    local gradEndColor = rankStyleData.gradientEnd
    local cornerRadius = 5

    local rarityBorderWidths = { E = 1, D = 1, C = 2, B = 2, A = 3, S = 3, SS = 4 }
    local borderWidth = rarityBorderWidths[item.rarity or "E"] or 1

    -- Recalcula headerHeight com base apenas no nome do item (primeira linha em tooltipLines)
    headerHeight = PADDING + (tooltipLines[1] and tooltipLines[1].height or 0)
    local descriptionHeightVisual = 0 -- Altura visual da caixa de descrição
    if descriptionContentHeight > 0 then
        descriptionHeightVisual = descriptionContentHeight + PADDING * 2
    end

    local defaultBgColor = colors.window_bg or { 0.05, 0.05, 0.08, 0.95 }
    love.graphics.setColor(defaultBgColor)
    love.graphics.rectangle("fill", x, y, tooltipWidth, totalHeight, cornerRadius, cornerRadius)

    local useGradientForHeader = elements.drawVerticalGradientRect and
        type(gradStartColor) == "table" and #gradStartColor >= 3 and
        type(gradEndColor) == "table" and #gradEndColor >= 3

    local fallbackHeaderBg

    -- Desenha fundo do header
    if useGradientForHeader then
        elements.drawVerticalGradientRect(x, y, tooltipWidth, headerHeight, gradStartColor, gradEndColor)
    else
        fallbackHeaderBg = gradStartColor
        if not (type(fallbackHeaderBg) == "table" and #fallbackHeaderBg >= 3) then
            fallbackHeaderBg = { rankTextColor[1], rankTextColor[2], rankTextColor[3], 0.85 }
        end
        love.graphics.setColor(fallbackHeaderBg)
        love.graphics.rectangle("fill", x, y, tooltipWidth, headerHeight)
    end

    -- Desenha fundo da seção de valor (igual ao header)
    if hasValueSection then
        local valueSectionY = y + contentHeight + SECTION_SPACING
        if useGradientForHeader then
            elements.drawVerticalGradientRect(
                x,
                valueSectionY,
                tooltipWidth,
                VALUE_SECTION_HEIGHT,
                gradStartColor,
                gradEndColor
            )
        else
            love.graphics.setColor(fallbackHeaderBg)
            love.graphics.rectangle("fill", x, valueSectionY, tooltipWidth, VALUE_SECTION_HEIGHT)
        end
    end

    -- <<< NOVO: Desenhar fundo da seção de descrição >>>
    local descriptionBgDrawn = false
    if descriptionHeightVisual > 0 then              -- Usa descriptionHeightVisual
        local descBgY = y + descriptionSectionStartY -- Y inicial da caixa de fundo da descrição
        local descBgH = descriptionHeightVisual      -- Altura total da caixa de fundo
        local descGradStart = { gradStartColor[1], gradStartColor[2], gradStartColor[3], (gradStartColor[4] or 1) * 0.5 }
        local descGradEnd = { gradEndColor[1], gradEndColor[2], gradEndColor[3], (gradEndColor[4] or 1) * 0.5 }

        if useGradientForHeader then -- Usa o mesmo tipo de fundo do cabeçalho mas com transparência
            elements.drawVerticalGradientRect(x, descBgY, tooltipWidth, descBgH, descGradStart, descGradEnd)
            descriptionBgDrawn = true
        else
            local descFallbackColor = fallbackHeaderBg or
                { rankTextColor[1], rankTextColor[2], rankTextColor[3], 0.85 } -- Garante um fallback caso não seja gradiente
            local fallbackDescBg = { descFallbackColor[1], descFallbackColor[2], descFallbackColor[3], (descFallbackColor[4] or 1) *
            0.5 }
            love.graphics.setColor(fallbackDescBg)
            love.graphics.rectangle("fill", x, descBgY, tooltipWidth, descBgH)
            descriptionBgDrawn = true
        end
    end

    love.graphics.setLineWidth(borderWidth)
    love.graphics.setColor(rankTextColor)
    love.graphics.rectangle("line", x, y, tooltipWidth, totalHeight, cornerRadius, cornerRadius)
    love.graphics.setLineWidth(1)

    local showGlow = (item.rarity == "S" or item.rarity == "SS" or item.rarity == "A")
    if showGlow and elements.setGlowShader and love.graphics.getShader() then
        local glowColor = rankTextColor
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.3)
        love.graphics.setLineWidth(math.min(3, borderWidth + 1))
        love.graphics.rectangle("line", x - (borderWidth / 2), y - (borderWidth / 2), tooltipWidth + borderWidth,
            totalHeight + borderWidth, cornerRadius + borderWidth / 2)
        love.graphics.setLineWidth(1)
    end

    -- Desenhar Ícone do Item (Coluna Esquerda)
    if item.icon and type(item.icon) == "userdata" then
        local iconAvailableW = iconColumnWidth -
            PADDING *
            2 -- Largura disponível para o ícone, considerando padding interno da coluna
        local iconAvailableH = mainSectionHeight -
            PADDING *
            2 -- Altura disponível para o ícone (altura da seção principal - paddings verticais)

        local aspectRatio = item.icon:getWidth() / item.icon:getHeight()
        local drawW, drawH

        -- Tentar escalar pela altura máxima disponível primeiro
        drawH = iconAvailableH
        drawW = drawH * aspectRatio

        -- Se a largura calculada exceder a largura disponível, escalar pela largura máxima disponível
        if drawW > iconAvailableW then
            drawW = iconAvailableW
            drawH = drawW / aspectRatio -- Recalcula a altura para manter a proporção
        end

        -- Centraliza o ícone no espaço disponível (iconAvailableW, iconAvailableH) dentro da sua coluna
        -- O PADDING externo da coluna já foi considerado em iconColumnWidth
        -- O PADDING interno da seção principal (mainSectionContentStartY + PADDING) é o início do container do ícone
        local iconContainerX = x +
            PADDING                                                   -- Posição X do container do ícone (borda esquerda da coluna do ícone + padding externo)
        local iconContainerY = y + mainSectionContentStartY + PADDING -- Posição Y do container do ícone

        local iconDrawX = iconContainerX + (iconAvailableW - drawW) / 2
        local iconDrawY = iconContainerY + (iconAvailableH - drawH) / 2

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(item.icon, iconDrawX, iconDrawY, 0, drawW / item.icon:getWidth(),
            drawH / item.icon:getHeight())
    end

    local currentDrawY = y + PADDING
    local shadowColor = colors.black_transparent_more or { 0, 0, 0, 0.6 }

    local accumulatedDescTextOffset = 0 -- Para empilhar linhas da descrição

    for lineIdx, lineInfo in ipairs(tooltipLines) do
        if lineInfo.type == "divider" then
            -- Esta seção não será mais atingida se todos os divisores forem removidos da criação de tooltipLines
        elseif lineInfo.type == "spacer" then
            currentDrawY = currentDrawY + lineInfo.height
        elseif lineInfo.type == "description_marker_start" then
            -- Calcula o Y inicial para o *texto* da descrição, para centralizá-lo
            local textBlockActualHeight = lineInfo.calculated_text_height
            -- descriptionHeightVisual é a altura total da caixa de fundo da descrição, incluindo seus paddings internos.
            -- descBoxInnerHeight é o espaço vertical DENTRO dos paddings da caixa de descrição.
            local descBoxInnerHeight = descriptionHeightVisual - PADDING * 2
            local verticalOffsetForText = (descBoxInnerHeight - textBlockActualHeight) / 2

            -- currentDrawY agora aponta para o início da CAIXA de descrição (com seu fundo)
            -- Adicionamos o PADDING superior da caixa e o offset para centralizar o TEXTO
            currentDrawY = y + descriptionSectionStartY + PADDING + verticalOffsetForText
            accumulatedDescTextOffset = 0 -- Reseta para o início do bloco de texto da descrição
        elseif lineInfo.type == "description_marker_end" then
            -- Avança currentDrawY para após toda a caixa de descrição VISUAL,
            -- preparando para o próximo elemento abaixo dela.
            currentDrawY = y + descriptionSectionStartY + descriptionHeightVisual + (SECTION_SPACING / 2)
        elseif lineInfo.parts then
            local currentPartX = x + PADDING + (lineInfo.x_offset or 0)
            local printY = currentDrawY
            local totalWidth = 0
            for _, part in ipairs(lineInfo.parts) do
                totalWidth = totalWidth + (part.font or fonts.main_small):getWidth(part.text)
            end

            local printX = x + PADDING
            if lineInfo.alignment == "center" then
                printX = x + (tooltipWidth - totalWidth) / 2
            elseif lineInfo.alignment == "right" then
                printX = x + tooltipWidth - PADDING - totalWidth
            end
            currentPartX = printX

            -- Desenha sombra para todas as partes primeiro
            love.graphics.setColor(shadowColor)
            local shadowX = currentPartX
            for _, part in ipairs(lineInfo.parts) do
                love.graphics.setFont(part.font or fonts.main_small)
                love.graphics.print(part.text, shadowX + SHADOW_OFFSET_X, printY + SHADOW_OFFSET_Y)
                shadowX = shadowX + (part.font or fonts.main_small):getWidth(part.text)
            end

            -- Desenha o texto de todas as partes
            local textX = currentPartX
            for _, part in ipairs(lineInfo.parts) do
                love.graphics.setFont(part.font or fonts.main_small)
                love.graphics.setColor(part.color or colors.text_main)
                love.graphics.print(part.text, textX, printY)
                textX = textX + (part.font or fonts.main_small):getWidth(part.text)
            end

            currentDrawY = currentDrawY + lineInfo.height
        elseif lineInfo.text then
            love.graphics.setFont(lineInfo.font or fonts.main_small)

            local textX = x + PADDING
            if lineInfo.is_main_section_text then
                textX = x + textColumnXOffset + (lineInfo.x_offset_in_column or 0)
            elseif lineInfo.x_offset then
                textX = x + PADDING + (lineInfo.x_offset or 0)
                -- Para texto da descrição, o X é PADDING*2 por causa do padding da caixa + padding do texto
            elseif descriptionBgDrawn and currentDrawY >= (y + descriptionSectionStartY + PADDING) and currentDrawY < (y + descriptionSectionEndY) and not lineInfo.is_main_section_text and not lineInfo.x_offset and lineInfo.alignment ~= "center" then
                textX = x + PADDING * 2
            end

            local printX = textX
            local textW_for_align = (lineInfo.font or fonts.main_small):getWidth(lineInfo.text)

            if lineInfo.alignment == "center" then
                printX = x + (tooltipWidth - textW_for_align) / 2
            elseif lineInfo.alignment == "right" then
                printX = x + tooltipWidth - PADDING - textW_for_align - (lineInfo.x_offset or 0)
            end

            local printY = currentDrawY
            local isDescriptionTextLine = false

            if lineInfo.is_main_section_text then
                printY = y + mainSectionContentStartY + PADDING + (lineInfo.accumulated_text_height or 0)
                -- Verifica se é uma linha de texto da descrição
            elseif descriptionBgDrawn and (tooltipLines[lineIdx - 1] and tooltipLines[lineIdx - 1].type == "description_marker_start" or (descriptionTextLines and #descriptionTextLines > 0 and lineInfo.font == (fonts.tooltip or fonts.main_small) and lineInfo.color == rankTextColor)) or (accumulatedDescTextOffset > 0 and lineInfo.height == LINE_HEIGHT_SMALL and lineInfo.font == (fonts.tooltip or fonts.main_small)) then
                printY = currentDrawY + accumulatedDescTextOffset
                isDescriptionTextLine = true
            else
                -- Para outras linhas (atributos, rodapé, etc.), printY é o currentDrawY atual antes de qualquer incremento para esta linha
                printY = currentDrawY
            end

            love.graphics.setColor(shadowColor)
            love.graphics.print(lineInfo.text, printX + SHADOW_OFFSET_X, printY + SHADOW_OFFSET_Y)

            love.graphics.setColor(lineInfo.color or colors.text_main)
            love.graphics.print(lineInfo.text, printX, printY)

            if isDescriptionTextLine then
                if printY + lineInfo.height < y + descriptionSectionStartY + descriptionHeightVisual - PADDING then
                    accumulatedDescTextOffset = accumulatedDescTextOffset + lineInfo.height
                end
            elseif not lineInfo.is_main_section_text then
                -- Para todas as outras linhas que não são da seção principal nem da descrição,
                -- avançamos currentDrawY globalmente. A próxima linha desse tipo usará este novo currentDrawY.
                currentDrawY = currentDrawY + lineInfo.height
            end

            if lineInfo.is_main_section_text then
                -- Atualiza a altura acumulada para a próxima linha de texto da seção principal
                if not tooltipLines[lineIdx + 1] or not tooltipLines[lineIdx + 1].is_main_section_text then
                    -- Se a próxima linha não pertence à seção principal de texto, não acumula mais
                else
                    tooltipLines[lineIdx + 1].accumulated_text_height = (lineInfo.accumulated_text_height or 0) +
                        lineInfo.height
                end
            end
        end
    end

    -- Desenha o valor fixo na parte inferior
    if hasValueSection then
        local valueSectionY = y + contentHeight + SECTION_SPACING
        local valueText = _P("ui.item_details_modal.value", { value = formattedPrice })
        local valueFont = fonts.main_small
        local valueColor = colors.text_gold or colors.white

        love.graphics.setFont(valueFont)
        local textWidth = valueFont:getWidth(valueText)
        local textX = x + (tooltipWidth - textWidth) / 2
        local textY = valueSectionY + (VALUE_SECTION_HEIGHT - valueFont:getHeight()) / 2

        -- Desenha sombra
        love.graphics.setColor(shadowColor)
        love.graphics.print(valueText, textX + SHADOW_OFFSET_X, textY + SHADOW_OFFSET_Y)

        -- Desenha texto
        love.graphics.setColor(valueColor)
        love.graphics.print(valueText, textX, textY)
    end

    love.graphics.setColor(colors.white)
end

return ItemDetailsModal
