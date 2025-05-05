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
---@param config table Tabela de configuração contendo os dados necessários:
---
---	  currentHp = number?,          -- Opcional: HP atual (Gameplay)
---	  level = number?,              -- Opcional: Nível atual (Gameplay)
---	  currentXp = number?,          -- Opcional: XP atual (Gameplay)
---	  xpToNextLevel = number?,      -- Opcional: XP para próx nível (Gameplay)
---	  finalStats = table,           -- Obrigatório: Tabela com status finais (lobby ou gameplay)
---	  archetypeIds = table,         -- Obrigatório: Lista de IDs/Info dos arquétipos
---	  archetypeManager = ArchetypeManager, -- Obrigatório: Instância do ArchetypeManager
---	  mouseX = number,              -- Obrigatório: Posição X do mouse
---	  mouseY = number               -- Obrigatório: Posição Y do mouse
---
function HunterStatsColumn.draw(x, y, w, h, config)
    -- Extrai dados da config para facilitar
    local currentHp = config.currentHp
    local level = config.level
    local currentXp = config.currentXp
    local xpToNextLevel = config.xpToNextLevel
    local finalStats = config.finalStats
    local archetypeIds = config.archetypeIds
    local archetypeManager = config.archetypeManager
    local mx = config.mouseX or 0
    local my = config.mouseY or 0

    -- Validações básicas
    if not finalStats or not archetypeIds or not archetypeManager then
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Dados essenciais ausentes na configuração de HunterStatsColumn!", x, y + h / 2, w,
            "center")
        love.graphics.setColor(colors.white)
        return
    end

    -- >>> SEÇÃO OPCIONAL: Status Gerais (HP, Nível, XP) <<<
    local generalSectionH = 0
    -- Só desenha se os dados de gameplay foram passados
    if currentHp ~= nil and level ~= nil and currentXp ~= nil and xpToNextLevel ~= nil then
        -- Tenta obter maxHp dos stats finais, senão usa um fallback (pode ser 0 se stats não tiver health)
        local maxHp = finalStats.health or 0

        local lineH = fonts.main:getHeight()
        local padding = 5
        generalSectionH = (lineH * 2) + (padding * 3) -- Altura para 2 linhas + paddings

        -- Linha 1: HP e Nível
        love.graphics.setFont(fonts.hud) -- Usa fonts.hud (existente e bold)
        love.graphics.setColor(colors.text_default)
        -- Arredonda HP para exibição
        local hpText = string.format("HP: %d / %d", math.floor(currentHp), math.floor(maxHp))
        local levelText = string.format("Nível: %d", level)
        love.graphics.print(hpText, x + padding, y + padding)
        love.graphics.printf(levelText, x + padding, y + padding, w - padding * 2, "right")

        -- Linha 2: XP
        love.graphics.setFont(fonts.main)
        -- Arredonda XP para exibição
        local xpText = string.format("XP: %d / %d", math.floor(currentXp), math.floor(xpToNextLevel))
        love.graphics.printf(xpText, x + padding, y + padding + lineH + padding, w - padding * 2, "left")

        -- Linha divisória (opcional)
        love.graphics.setColor(colors.window_border) -- Usa colors.window_border (existente)
        love.graphics.rectangle("fill", x, y + generalSectionH - 1, w, 1)
        love.graphics.setColor(colors.white)         -- Reset color
    else
        -- Se não passou dados de gameplay, a seção não ocupa espaço
        generalSectionH = 0
    end
    -- >>> FIM SEÇÃO OPCIONAL <<<

    -- Ajusta Y e H para as seções seguintes, considerando se a seção geral foi desenhada
    local remainingH = h - generalSectionH
    local statsY = y + generalSectionH
    local statsSectionH = math.floor(remainingH * 0.50) -- 50% do espaço *restante*
    local archetypesGapY = 5
    local archetypesTitleH = fonts.hud:getHeight() * 1.5
    local archetypesTitleY = statsY + statsSectionH + archetypesGapY
    local archetypesListStartY = archetypesTitleY + archetypesTitleH

    -- Ordena arquétipos (lógica movida para cá para garantir execução)
    local rankOrder = { S = 1, A = 2, B = 3, C = 4, D = 5, E = 6 }
    local sortedArchetypes = {}
    if archetypeIds then -- Garante que archetypeIds não seja nil
        for _, archIdInfo in ipairs(archetypeIds) do
            local finalArchId = type(archIdInfo) == 'table' and archIdInfo.id or archIdInfo
            if type(finalArchId) == 'string' then
                local data = archetypeManager:getArchetypeData(finalArchId)
                if data then
                    data.rank = (type(archIdInfo) == 'table' and archIdInfo.rank) or data.rank or 'E'
                    table.insert(sortedArchetypes, data)
                end
            end
        end
        table.sort(sortedArchetypes, function(a, b)
            local orderA = rankOrder[a.rank or 'E'] or 99
            local orderB = rankOrder[b.rank or 'E'] or 99
            if orderA == orderB then
                return (a.name or "") < (b.name or "")
            end
            return orderA < orderB
        end)
    end

    -- 1. Desenha Seção de Stats (usando finalStats da config)
    if finalStats and next(finalStats) then
        -- Passa sortedArchetypes e archetypeManager para StatsSection poder calcular tooltips
        StatsSection.drawBaseStats(x, statsY, w, statsSectionH,
            finalStats, sortedArchetypes, archetypeManager, mx, my)
    else
        -- Mensagem de erro se faltar dados de stats
        love.graphics.setColor(colors.red)
        local errorMsg = "Dados insuficientes para Stats"
        love.graphics.printf(errorMsg, x, statsY + statsSectionH / 2, w, "center")
    end

    -- 2. Desenha Seção de Arquétipos ABAIXO dos Stats
    love.graphics.setFont(fonts.hud)
    love.graphics.setColor(colors.text_highlight)
    love.graphics.printf("ARQUÉTIPOS", x, archetypesTitleY, w, "left")
    local padding = 5 -- Padding interno da coluna para a lista

    -- Desenha a lista de arquétipos
    if #sortedArchetypes > 0 then
        local itemsPerRow = 3
        local hGap = 15
        local vGap = 10
        local availableWidth = w - padding * 2
        local itemWidth = (availableWidth - (hGap * (itemsPerRow - 1))) / itemsPerRow
        if itemWidth <= 0 then itemWidth = availableWidth end

        local currentX = x + padding -- Começa dentro do padding da coluna
        local startListY = archetypesListStartY
        local currentY = startListY
        local maxHeightInRow = 0
        local nameFont = fonts.hud or fonts.main
        local modFont = fonts.main_small or fonts.main
        local nameFontHeight = nameFont:getHeight()
        local modFontHeight = modFont:getHeight()
        local lineSpacing = 2

        for i, archetypeData in ipairs(sortedArchetypes) do
            -- Verifica se há espaço vertical restante antes de desenhar
            if currentY + nameFontHeight > y + h then break end

            local startItemY = currentY

            -- Cabeçalho
            local nameText = archetypeData.name or "??"
            local rankText = archetypeData.rank or "?"
            local headerText = string.format("%s (%s)", nameText, rankText)
            local rankColor = colors.rank[rankText] or colors.text_default
            love.graphics.setFont(nameFont)
            love.graphics.setColor(rankColor)
            love.graphics.printf(headerText, currentX, currentY, itemWidth, "left")
            currentY = currentY + nameFontHeight

            -- Modificadores
            love.graphics.setFont(modFont)
            if archetypeData.modifiers and #archetypeData.modifiers > 0 then
                currentY = currentY + lineSpacing
                for _, mod in ipairs(archetypeData.modifiers) do
                    if currentY + modFontHeight > y + h then break end

                    local statId = mod.stat or "???"
                    local value = mod.baseValue ~= nil and mod.baseValue or mod.multValue
                    local isMultiplier = mod.multValue ~= nil
                    local valueForFormatter = isMultiplier and (value + 1) or value

                    local statName = Formatters.getStatDisplayName(statId)
                    local formattedValueText = Formatters.formatStatValue(statId, valueForFormatter)

                    if value > 0 and not (isMultiplier and value == 0) then
                        formattedValueText = "+" .. formattedValueText
                    end

                    local modText = string.format("%s: %s", statName, formattedValueText)
                    local modColor = colors.text_muted
                    if value > 0 then modColor = colors.positive end
                    if value < 0 then modColor = colors.negative end

                    love.graphics.setColor(modColor)
                    love.graphics.printf(modText, currentX, currentY, itemWidth, "left")
                    currentY = currentY + modFontHeight + lineSpacing
                end
                if currentY + modFontHeight > y + h then goto break_outer_loop end
            end

            local itemHeight = currentY - startItemY
            maxHeightInRow = math.max(maxHeightInRow, itemHeight)
            local nextItemX = currentX + itemWidth + hGap

            if i % itemsPerRow == 0 or i == #sortedArchetypes then
                currentY = startItemY + maxHeightInRow + vGap
                currentX = x + padding
                maxHeightInRow = 0
            else
                currentX = nextItemX
                currentY = startItemY
            end
        end
        ::break_outer_loop::
    else
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_muted)
        love.graphics.printf("Nenhum arquétipo.", x + padding, archetypesListStartY + 5, w - padding * 2, "left")
    end

    love.graphics.setColor(colors.white) -- Reset final
end

return HunterStatsColumn
