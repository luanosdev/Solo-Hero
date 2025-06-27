local colors = require("src.ui.colors")
local fonts = require("src.ui.fonts")
local ReputationConfig = require("src.config.reputation_config")
local elements = require("src.ui.ui_elements")

---@class LobbyNavbar
---@field hunterManager HunterManager
---@field agencyManager AgencyManager
---@field reputationManager ReputationManager
local LobbyNavbar = {}
LobbyNavbar.__index = LobbyNavbar

-- Constantes
local NAVBAR_HEIGHT = 60
local PADDING = 20
local SECTION_SPACING = 40

--- Cria uma nova instância da LobbyNavbar
---@param hunterManager HunterManager
---@param agencyManager AgencyManager
---@param reputationManager ReputationManager
---@return LobbyNavbar
function LobbyNavbar:new(hunterManager, agencyManager, reputationManager)
    local instance = setmetatable({}, LobbyNavbar)
    instance.hunterManager = hunterManager
    instance.agencyManager = agencyManager
    instance.reputationManager = reputationManager
    return instance
end

--- Calcula a próxima reputação necessária para rankear
---@param currentRank string
---@param currentReputation number
---@return number|nil nextThreshold
---@return string|nil nextRank
function LobbyNavbar:_getNextReputationThreshold(currentRank, currentReputation)
    local rankIndex = ReputationConfig.getRankIndex(currentRank)
    if not rankIndex or rankIndex >= #ReputationConfig.rankOrder then
        return nil, nil -- Já é o rank máximo
    end

    local nextRank = ReputationConfig.rankOrder[rankIndex + 1]
    local nextThreshold = ReputationConfig.rankThresholds[nextRank]
    return nextThreshold, nextRank
end

--- Desenha texto com sombra
---@param text string
---@param x number
---@param y number
---@param textColor table
---@param shadowColor table
---@param shadowOffset number
local function drawTextWithShadow(text, x, y, textColor, shadowColor, shadowOffset)
    shadowOffset = shadowOffset or 1

    -- Sombra
    love.graphics.setColor(shadowColor)
    love.graphics.print(text, x + shadowOffset, y + shadowOffset)

    -- Texto principal
    love.graphics.setColor(textColor)
    love.graphics.print(text, x, y)
end

--- Desenha a seção do caçador (lado esquerdo)
---@param x number
---@param y number
---@param sectionWidth number
function LobbyNavbar:_drawHunterSection(x, y, sectionWidth)
    local activeHunterId = self.hunterManager:getActiveHunterId()

    if not activeHunterId then
        -- Nenhum caçador ativo
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.red)
        love.graphics.printf("Nenhum Caçador Ativo", x, y + 10, sectionWidth, "left")
        love.graphics.printf("Recrute um caçador!", x, y + 30, sectionWidth, "left")
        return
    end

    local hunterData = self.hunterManager:getHunterData(activeHunterId)
    if not hunterData then
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.red)
        love.graphics.printf("Erro: Caçador não encontrado", x, y + 15, sectionWidth, "left")
        return
    end

    local hunterName = hunterData.name or "Caçador Desconhecido"
    local hunterRank = hunterData.finalRankId or "E"
    local rankDetails = colors.rankDetails[hunterRank]
    local rankColor = rankDetails and rankDetails.text or colors.text_default
    local shadowColor = colors.black_transparent_more or { 0, 0, 0, 0.7 }

    -- Nome do caçador com cor do ranking e sombra
    love.graphics.setFont(fonts.main_large or fonts.main)
    drawTextWithShadow(hunterName, x, y + 8, rankColor, shadowColor, 1)

    -- Rank do caçador com cor do ranking e sombra
    love.graphics.setFont(fonts.main)
    local rankText = "Rank " .. hunterRank
    drawTextWithShadow(rankText, x, y + 32, rankColor, shadowColor, 1)
end

--- Desenha a seção da agência (centro)
---@param x number
---@param y number
---@param sectionWidth number
function LobbyNavbar:_drawAgencySection(x, y, sectionWidth)
    local agencyData = self.agencyManager:getAgencyData()

    if not agencyData then
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.red)
        love.graphics.printf("Agência não encontrada", x, y + 15, sectionWidth, "center")
        return
    end

    local agencyName = agencyData.name or "Agência Desconhecida"
    local agencyRank = agencyData.rank or "E"
    local currentReputation = agencyData.reputation or 0
    local rankDetails = colors.rankDetails[agencyRank]
    local rankColor = rankDetails and rankDetails.text or colors.text_default
    local shadowColor = colors.black_transparent_more or { 0, 0, 0, 0.7 }

    -- Nome da agência e ranking na mesma linha com cor do ranking e sombra
    local agencyText = agencyName .. " • Rank " .. agencyRank
    love.graphics.setFont(fonts.main_large or fonts.main)
    local currentFont = fonts.main_large or fonts.main
    local textWidth = currentFont:getWidth(agencyText)
    local textX = x + (sectionWidth - textWidth) / 2
    drawTextWithShadow(agencyText, textX, y + 8, rankColor, shadowColor, 1)

    -- Barra de progresso da reputação mais minimalista
    local nextThreshold, nextRank = self:_getNextReputationThreshold(agencyRank, currentReputation)
    if nextThreshold and nextRank then
        local currentThreshold = ReputationConfig.rankThresholds[agencyRank] or 0
        local progress = (currentReputation - currentThreshold) / (nextThreshold - currentThreshold)
        progress = math.max(0, math.min(1, progress))

        local barWidth = sectionWidth * 0.9
        local barHeight = 3
        local barX = x + (sectionWidth - barWidth) / 2
        local barY = y + 50

        -- Fundo da barra (mais escuro)
        love.graphics.setColor(colors.bar_bg[1] * 0.5, colors.bar_bg[2] * 0.5, colors.bar_bg[3] * 0.5, 0.8)
        love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

        -- Progresso da barra
        love.graphics.setColor(colors.xp_fill)
        love.graphics.rectangle("fill", barX, barY, barWidth * progress, barHeight)

        -- Textos de reputação
        love.graphics.setFont(fonts.main_small or fonts.main)

        -- Reputação que faz cair (esquerda)
        local previousRankIndex = ReputationConfig.getRankIndex(agencyRank)
        if previousRankIndex and previousRankIndex > 1 then
            local previousRank = ReputationConfig.rankOrder[previousRankIndex - 1]
            local previousThreshold = ReputationConfig.rankThresholds[agencyRank] or 0
            love.graphics.setColor(colors.text_muted)
            love.graphics.print(tostring(previousThreshold), barX - 8, barY - 20)
        end

        -- Reputação atual (centro)
        love.graphics.setColor(colors.text_value)
        local currentText = tostring(currentReputation)
        local currentTextWidth = (fonts.main_small or fonts.main):getWidth(currentText)
        love.graphics.print(currentText, barX + (barWidth - currentTextWidth) / 2, barY - 20)

        -- Próxima reputação necessária (direita)
        love.graphics.setColor(colors.text_muted)
        local nextText = tostring(nextThreshold)
        local nextTextWidth = (fonts.main_small or fonts.main):getWidth(nextText)
        love.graphics.print(nextText, barX + barWidth - nextTextWidth + 8, barY - 20)
    else
        -- Rank máximo
        love.graphics.setFont(fonts.main_small or fonts.main)
        love.graphics.setColor(colors.text_muted)
        love.graphics.printf("RANK MÁXIMO", x, y + 38, sectionWidth, "center")
    end
end

--- Desenha um card de recurso
---@param x number
---@param y number
---@param w number
---@param h number
---@param label string
---@param icon string
---@param value number
---@param color table
local function drawResourceCard(x, y, w, h, label, icon, value, color)
    -- Label centralizado na parte de cima
    love.graphics.setFont(fonts.main_small or fonts.main)
    love.graphics.setColor(color)
    love.graphics.printf(label, x, y + 3, w, "center")

    -- Ícone e valor na parte de baixo
    love.graphics.setFont(fonts.resource_value or fonts.main)
    local valueText = icon .. " " .. elements.formatNumber(value)
    -- usa o drawTextWithShadow e centraliza o texto
    drawTextWithShadow(valueText, x + (w / 2) - 20, y + h - 30, color, color, 1)
end

--- Desenha a seção de recursos (lado direito)
---@param x number
---@param y number
---@param sectionWidth number
function LobbyNavbar:_drawResourceSection(x, y, sectionWidth)
    -- TODO: Implementar sistema de moeda quando necessário
    local patrimonio = 0 -- Placeholder
    local tickets = 0    -- Placeholder

    local cardWidth = (sectionWidth - 10) / 2
    local cardHeight = NAVBAR_HEIGHT - 10

    -- Card do Patrimônio
    drawResourceCard(x, y + 5, cardWidth, cardHeight, "PATRIMÔNIO", "$", patrimonio, colors.navbar_money)

    -- Card dos Tickets
    local ticketCardX = x + cardWidth + 10
    drawResourceCard(ticketCardX, y + 5, cardWidth, cardHeight, "TICKETS", "§", tickets, colors.navbar_tickets)
end

--- Desenha a navbar completa
---@param screenWidth number
---@param screenHeight number
function LobbyNavbar:draw(screenWidth, screenHeight)
    -- Fundo da navbar
    love.graphics.setColor(colors.window_bg)
    love.graphics.rectangle("fill", 0, 0, screenWidth, NAVBAR_HEIGHT)

    -- Calcula divisões das seções
    local usableWidth = screenWidth - (PADDING * 2)
    local sectionWidth = (usableWidth - (SECTION_SPACING * 2)) / 3

    local hunterSectionX = PADDING
    local agencySectionX = hunterSectionX + sectionWidth + SECTION_SPACING
    local resourceSectionX = agencySectionX + sectionWidth + SECTION_SPACING

    -- Desenha as seções
    self:_drawHunterSection(hunterSectionX, 0, sectionWidth)
    self:_drawAgencySection(agencySectionX, 0, sectionWidth)
    self:_drawResourceSection(resourceSectionX, 0, sectionWidth)

    -- Reset cor
    love.graphics.setColor(colors.white)
end

--- Retorna a altura da navbar
---@return number
function LobbyNavbar:getHeight()
    return NAVBAR_HEIGHT
end

return LobbyNavbar
