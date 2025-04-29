local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local StatsSection = require("src.ui.inventory.sections.stats_section")
local Formatters = require("src.utils.formatters")
local Constants = require("src.config.constants") -- Para BASE_HUNTER_STATS se necessário no tooltip

-- Necessário para a lista de arquétipos
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
}

local HunterStatsColumn = {}

--- Desenha a coluna de Atributos e Arquétipos.
---@param x number Posição X da coluna.
---@param y number Posição Y inicial do conteúdo da coluna.
---@param w number Largura da coluna.
---@param h number Altura total disponível para o conteúdo da coluna.
---@param hunterManager HunterManager (ou apenas os dados necessários passados separadamente)
---@param finalStats table Tabela com os status finais calculados.
---@param archetypeIds table Lista de IDs/Info dos arquétipos do caçador.
---@param archetypeManager ArchetypeManager Instância do ArchetypeManager.
---@param mx number Posição X do mouse (para tooltip).
---@param my number Posição Y do mouse (para tooltip).
function HunterStatsColumn.draw(x, y, w, h, finalStats, archetypeIds, archetypeManager, mx, my)
    -- Layout VERTICAL interno para a coluna (copiado/adaptado de equipment_screen)
    local statsSectionH = math.floor(h * 0.50)           -- Stats ficam com 50% da altura da coluna
    local archetypesTitleH = fonts.hud:getHeight() * 1.5 -- Altura para o título "Arquétipos"
    local archetypesGapY = 5
    local archetypesTitleY = y + statsSectionH + archetypesGapY
    local archetypesListStartY = archetypesTitleY + archetypesTitleH

    local rankOrder = { S = 1, A = 2, B = 3, C = 4, D = 5, E = 6 }
    local sortedArchetypes = {}
    for _, archIdInfo in ipairs(archetypeIds) do
        local finalArchId = type(archIdInfo) == 'table' and archIdInfo.id or archIdInfo
        if type(finalArchId) == 'string' then
            local data = archetypeManager:getArchetypeData(finalArchId)
            if data then
                -- Adiciona o rank original aqui para consistência, se disponível
                data.rank = (type(archIdInfo) == 'table' and archIdInfo.rank) or data.rank or 'E'
                table.insert(sortedArchetypes, data)
            end
        end
    end
    table.sort(sortedArchetypes, function(a, b)
        local orderA = rankOrder[a.rank or 'E'] or 99
        local orderB = rankOrder[b.rank or 'E'] or 99
        if orderA == orderB then
            return (a.name or "") < (b.name or "") -- Comparação segura por nome
        end
        return orderA < orderB
    end)

    -- 1. Desenha Seção de Stats
    if finalStats and next(finalStats) and sortedArchetypes and archetypeManager then
        StatsSection.drawBaseStats(x, y, w, statsSectionH,
            finalStats, sortedArchetypes, archetypeManager, mx, my)
    else
        -- Mensagem de erro se faltar dados
        love.graphics.setColor(colors.red)
        local errorMsg = "Dados insuficientes para Stats"
        love.graphics.printf(errorMsg, x, y + statsSectionH / 2, w, "center")
    end

    -- 2. Desenha Seção de Arquétipos ABAIXO dos Stats
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ARQUÉTIPOS", x, archetypesTitleY, w, "left")

    -- <<< Lógica de ordenação e desenho dos arquétipos (copiada de equipment_screen) >>>
    if archetypeIds and archetypeManager then
        if #sortedArchetypes > 0 then
            local itemsPerRow = 3
            local hGap = 15
            local vGap = 10
            local padding = 5 -- Padding interno da coluna para a lista
            local availableWidth = w - padding * 2
            local itemWidth = (availableWidth - (hGap * (itemsPerRow - 1))) / itemsPerRow
            if itemWidth <= 0 then itemWidth = availableWidth end -- Evita divisão por zero ou largura negativa

            local currentX = x                                    -- Começa dentro do padding da coluna
            local startListY = archetypesListStartY               -- Y onde a lista começa
            local currentY = startListY
            local maxHeightInRow = 0
            local nameFont = fonts.main_small_bold or fonts.main
            local modFont = fonts.main_small or fonts.main
            local nameFontHeight = nameFont:getHeight()
            local modFontHeight = modFont:getHeight()
            local lineSpacing = 2

            for i, archetypeData in ipairs(sortedArchetypes) do
                -- Verifica se há espaço vertical restante antes de desenhar
                if currentY + nameFontHeight > y + h then break end -- Para se não couber mais

                local startItemY = currentY                         -- Guarda a posição Y inicial para este arquétipo

                -- Cabeçalho
                local nameText = archetypeData.name or "??"
                local rankText = archetypeData.rank or "?"
                local headerText = string.format("%s (%s)", nameText, rankText)
                local rankColor = colors.rank[rankText] or colors.text_default
                love.graphics.setFont(nameFont)
                love.graphics.setColor(rankColor)
                love.graphics.printf(headerText, currentX, currentY, itemWidth, "left") -- Usa itemWidth
                currentY = currentY + nameFontHeight

                -- Modificadores
                love.graphics.setFont(modFont)
                if archetypeData.modifiers and #archetypeData.modifiers > 0 then
                    currentY = currentY + lineSpacing
                    for _, mod in ipairs(archetypeData.modifiers) do
                        -- Verifica espaço antes de desenhar modificador
                        if currentY + modFontHeight > y + h then break end

                        local statId = mod.stat or "???"
                        local value = mod.baseValue ~= nil and mod.baseValue or mod.multValue
                        local isMultiplier = mod.multValue ~= nil
                        local valueForFormatter = isMultiplier and (value + 1) or value

                        -- <<< MODIFICADO: Usa Formatters.getStatDisplayName >>>
                        local statName = Formatters.getStatDisplayName(statId)
                        -- <<< MODIFICADO: Usa Formatters.formatStatValue >>>
                        local formattedValueText = Formatters.formatStatValue(statId, valueForFormatter)

                        -- Adiciona sinal de '+' se for um bônus positivo
                        if value > 0 and not (isMultiplier and value == 0) then
                            formattedValueText = "+" .. formattedValueText
                        end

                        local modText = string.format("%s: %s", statName, formattedValueText)
                        local modColor = colors.text_muted
                        if value > 0 then modColor = colors.positive end
                        if value < 0 then modColor = colors.negative end

                        love.graphics.setColor(modColor)
                        love.graphics.printf(modText, currentX, currentY, itemWidth, "left") -- Usa itemWidth
                        currentY = currentY + modFontHeight + lineSpacing
                    end
                    if currentY + modFontHeight > y + h then goto break_outer_loop end -- Sai do loop externo se não couber mais
                end

                local itemHeight = currentY - startItemY
                maxHeightInRow = math.max(maxHeightInRow, itemHeight)
                local nextItemX = currentX + itemWidth + hGap

                if i % itemsPerRow == 0 or i == #sortedArchetypes then
                    currentY = startItemY + maxHeightInRow + vGap
                    currentX = x
                    maxHeightInRow = 0
                else
                    currentX = nextItemX
                    currentY = startItemY -- Reset Y para o início da linha
                end
            end
            ::break_outer_loop:: -- Label para o goto
        else
            love.graphics.setFont(fonts.main)
            love.graphics.setColor(colors.text_muted)
            love.graphics.printf("Nenhum arquétipo.", x + padding, archetypesListStartY + 5, w - padding * 2, "left")
        end
    else
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_muted)
        love.graphics.printf("Arquétipos indisponíveis.", x + padding, archetypesListStartY + 5, w - padding * 2, "left")
    end
    -- <<< Fim da lógica dos arquétipos >>>

    love.graphics.setColor(colors.white) -- Reset final
end

return HunterStatsColumn
