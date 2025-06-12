-- src/ui/components/ReputationSummaryColumn.lua
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")

---@class ReputationSummaryColumn
--- Componente estático para desenhar a coluna de resumo de reputação na tela de extração.
local ReputationSummaryColumn = {}

local function drawStatLine(x, y, w, label, value, valueColor)
    love.graphics.setFont(fonts.main_small or fonts.main)
    love.graphics.setColor(colors.text_main)
    love.graphics.printf(label, x, y, w, "left")

    love.graphics.setFont(fonts.main_small_bold or fonts.main)
    love.graphics.setColor(valueColor or colors.text_value)
    love.graphics.printf(value, x, y, w, "right")

    return (fonts.main_small or fonts.main):getHeight()
end

--- Desenha a coluna de resumo de reputação.
---@param x number Posição X inicial da coluna.
---@param y number Posição Y inicial do conteúdo da coluna.
---@param w number Largura da coluna.
---@param h number Altura da coluna.
---@param details table A tabela `reputationDetails` retornada pelo ReputationManager.
function ReputationSummaryColumn.draw(x, y, w, h, details)
    if not details then return end

    local currentY = y + 10
    local lineSpacing = 8
    local lineHeight = 0

    if details.wasSuccess then
        -- Exibição de SUCESSO
        lineHeight = drawStatLine(x, currentY, w, "Pontos Base (Portal)", string.format("+%d", details.basePoints),
            colors.green)
        currentY = currentY + lineHeight + lineSpacing

        local bonusSign = details.rankBonusPoints >= 0 and "+" or ""
        local bonusColor = details.rankBonusPoints >= 0 and colors.green or colors.red
        local bonusText = string.format("%s%d", bonusSign, details.rankBonusPoints)
        local bonusLabel = string.format("Bônus de Rank (x%.2f)", details.rankBonusMultiplier)
        lineHeight = drawStatLine(x, currentY, w, bonusLabel, bonusText, bonusColor)
        currentY = currentY + lineHeight + lineSpacing

        if details.lootPoints > 0 then
            lineHeight = drawStatLine(x, currentY, w, "Pontos de Loot", string.format("+%d", details.lootPoints),
                colors.green)
            currentY = currentY + lineHeight + lineSpacing
        end
    else
        -- Exibição de FALHA
        lineHeight = drawStatLine(x, currentY, w, "Pontos Base (Portal)", string.format("%d", details.basePoints),
            colors.text_main)
        currentY = currentY + lineHeight + lineSpacing

        local penaltyText = string.format("x %.2f", details.penaltyMultiplier)
        lineHeight = drawStatLine(x, currentY, w, "Multiplicador de Penalidade", penaltyText, colors.red)
        currentY = currentY + lineHeight + lineSpacing
    end

    -- Linha Total
    currentY = currentY + 15 -- Espaço antes do total
    love.graphics.setColor(colors.text_muted)
    love.graphics.line(x, currentY, x + w, currentY)
    currentY = currentY + 15

    local totalSign = details.totalChange >= 0 and "+" or ""
    local totalColor = details.totalChange > 0 and colors.green or
        (details.totalChange < 0 and colors.red or colors.text_value)
    local totalText = string.format("%s%d", totalSign, details.totalChange)
    lineHeight = drawStatLine(x, currentY, w, "Total de Reputação:", totalText, totalColor)
    currentY = currentY + lineHeight
end

return ReputationSummaryColumn
