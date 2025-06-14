--- Componente que exibe as estatísticas do jogo em uma coluna.
--- @class GameStatsColumn
local GameStatsColumn = {}

local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local Formatters = require("src.utils.formatters")

--- Desenha a coluna de estatísticas do jogo.
--- @param x number Posição X da coluna
--- @param y number Posição Y da coluna
--- @param width number Largura da coluna
--- @param height number Altura da coluna
--- @param stats table Estatísticas do jogo (dados brutos do GameStatisticsManager)
function GameStatsColumn.draw(x, y, width, height, stats)
    if not stats then return end

    local font = fonts.main
    local smallFont = fonts.main_small
    local lineHeight = font:getHeight()
    local smallLineHeight = 4
    local padding = 10
    local currentY = y

    -- Função auxiliar para desenhar uma linha de estatística
    local function drawStatLine(label, value, isSmall, customColor)
        local useFont = isSmall and smallFont or font
        local useLineHeight = isSmall and smallLineHeight or lineHeight

        love.graphics.setFont(useFont)
        love.graphics.setColor(colors.text_label)
        love.graphics.printf(label, x, currentY, width * 0.7, "left") -- Mais espaço para o label
        love.graphics.setColor(customColor or colors.text_value)
        value = Formatters.formatCompactNumber(value)
        love.graphics.printf(tostring(value), x + width * 0.7, currentY, width * 0.3, "right")
        currentY = currentY + useLineHeight + padding
    end

    -- Função auxiliar para desenhar um cabeçalho de seção
    local function drawSectionHeader(text)
        currentY = currentY + padding -- Espaço extra antes de cada seção
        love.graphics.setFont(font)
        love.graphics.setColor(colors.text_value)
        love.graphics.printf(text, x, currentY, width, "left")
        currentY = currentY + lineHeight + padding
        love.graphics.setColor(colors.bar_border)
        love.graphics.rectangle("fill", x, currentY - (padding / 2), width, 1)
    end

    -- Resumo Geral
    drawSectionHeader("Resumo da Partida")
    drawStatLine("Tempo de Jogo", Formatters.formatTime(stats.playTime), true)
    drawStatLine("Níveis Ganhos", tostring(stats.levelsGained or 0), true)
    drawStatLine("XP Total Coletado", tostring(stats.totalXpCollected or 0), true)

    -- Combate
    drawSectionHeader("Estatísticas de Combate")
    drawStatLine("Dano Total Causado", tostring(stats.totalDamageDealt or 0), true)
    drawStatLine("Dano Total Recebido", tostring(stats.totalDamageTaken or 0), true, colors.damage_player)
    drawStatLine("Dano Reduzido", tostring(stats.totalDamageReduced or 0), true)
    drawStatLine("Maior Dano Causado", tostring(stats.highestDamageDealt or 0), true)
    drawStatLine("Maior Dano Recebido", tostring(stats.highestDamageTaken or 0), true, colors.damage_player)
    drawStatLine("Inimigos Derrotados", tostring(stats.enemiesDefeated or 0), true)
    drawStatLine("MVPs Derrotados", tostring(stats.mvpsDefeated or 0), true)
    drawStatLine("Chefes Derrotados", tostring(stats.bossesDefeated or 0), true)
    drawStatLine("Máx. Inimigos Atingidos", tostring(stats.maxEnemiesHitAtOnce or 0), true)


    -- Críticos
    drawSectionHeader("Acertos Críticos")
    drawStatLine("Total de Golpes Críticos", tostring(stats.criticalHits or 0), true, colors.damage_crit)
    drawStatLine("Danos Críticos Totais", tostring(stats.totalCriticalDamage or 0), true, colors.damage_crit)
    drawStatLine("Total de Super Críticos", tostring(stats.superCriticalHits or 0), true, colors.damage_crit)
    drawStatLine("Danos Super Críticos Totais", tostring(stats.totalSuperCriticalDamage or 0), true, colors.damage_crit)


    -- Sobrevivência
    drawSectionHeader("Sobrevivência")
    drawStatLine("Vida Recuperada", tostring(stats.healthRecovered or 0), true, colors.heal)
    drawStatLine("Maior Cura de uma vez", tostring(stats.maxHealthRecovered or 0), true, colors.heal)
    drawStatLine("Total de Curas", tostring(stats.timesHealed or 0), true)
    drawStatLine("Vezes Atingido", tostring(stats.timesHit or 0), true)
    drawStatLine("Maior Tempo Ileso", Formatters.formatTime(stats.longestTimeWithoutTakingDamage or 0), true)

    -- Outros
    drawSectionHeader("Diversos")
    -- Presumindo que 1 unidade de distância = 1/50 de um metro para um valor razoável.
    local distanceInMeters = (stats.distanceTraveled or 0) / 50
    drawStatLine("Distância Percorrida", string.format("%.1f m", distanceInMeters), true)
    drawStatLine("Itens Coletados", tostring(stats.itemsCollected or 0), true)


    -- Estatísticas de Armas
    if stats.weaponStats and next(stats.weaponStats) then
        drawSectionHeader("Detalhes por Arma")
        for weaponId, weaponStats in pairs(stats.weaponStats) do
            -- TODO: Pegar o nome da arma a partir do ID
            drawStatLine(string.format("Dano (%s)", weaponId), string.format("%d", weaponStats.damage), true)
            drawStatLine(string.format("Crits (%s)", weaponId), string.format("%d", weaponStats.crits), true,
                colors.critical)
            drawStatLine(string.format("S.Crits (%s)", weaponId), string.format("%d", weaponStats.sCrits or 0), true,
                colors.super_critical)
        end
    end

    -- Melhorias de Nível
    if stats.levelUpChoices and #stats.levelUpChoices > 0 then
        drawSectionHeader("Melhorias Adquiridas")
        for _, choiceData in ipairs(stats.levelUpChoices) do
            local label = string.format("Nv. %d: %s", choiceData.level, choiceData.choice)
            -- Usar um valor vazio pois o label já contém toda a informação
            drawStatLine(label, "", true)
        end
    end
end

return GameStatsColumn
