local elements = require("src.ui.ui_elements")
local fonts = require("src.ui.fonts")
local colors = require("src.ui.colors")
local LevelUpBonusesData = require("src.data.level_up_bonuses_data")
local Formatters = require("src.utils.formatters")
local lume = require("src.libs.lume")

---@class LevelUpModal
---@field visible boolean
---@field options table
---@field selectedOption number|nil
---@field playerManager PlayerManager|nil
---@field inputManager InputManager|nil
---@field hoveredOption number|nil
---@field onCloseCallback function|nil
---@field cards table<number, LevelUpCard>
---@field scales table<number, number>
---@field backgroundColors table<number, {number, number, number}>
---@field cardAnimationTimer number
---@field cardsAnimated number
---@field canChoose boolean
---@field appearanceSequenceCompleted boolean
---@field loadedImages table<string, love.Image>
local LevelUpModal = {
    visible = false,
    options = {},
    selectedOption = nil,
    playerManager = nil,
    inputManager = nil,
    hoveredOption = nil,
    onCloseCallback = nil,
    cards = {},
    scales = {},
    backgroundColors = {},
    cardAnimationTimer = 0.0,
    cardsAnimated = 0,
    canChoose = false,
    appearanceSequenceCompleted = false,
    loadedImages = {},
}

---@class LevelUpCard
---@field rect {x: number, y: number, w: number, h: number}
---@field optionData LevelUpBonus
---@field alpha number
---@field animationComplete boolean
---@field skillImage love.Image|nil
local LevelUpCard = {}
LevelUpCard.__index = LevelUpCard

function LevelUpCard:new(rect, optionData)
    local instance = setmetatable({}, LevelUpCard)
    instance.rect = rect
    instance.optionData = optionData
    instance.alpha = 0.0
    instance.animationComplete = false
    instance.skillImage = nil
    return instance
end

function LevelUpCard:loadImage()
    if self.optionData.image_path and love.filesystem.getInfo(self.optionData.image_path) then
        local success, imageOrError = pcall(love.graphics.newImage, self.optionData.image_path)
        if success then
            self.skillImage = imageOrError
            Logger.debug("level_up_card.load_image", "Imagem carregada: " .. self.optionData.image_path)
        else
            Logger.debug("level_up_card.load_image_error",
                "Erro ao carregar: " .. self.optionData.image_path .. " - " .. tostring(imageOrError))
        end
    else
        Logger.debug("level_up_card.load_image_missing",
            "Arquivo não encontrado: " .. (self.optionData.image_path or "nil"))
    end
end

function LevelUpCard:update(dt)
    if not self.animationComplete then
        -- Animação de fade-in
        self.alpha = math.min(1.0, self.alpha + dt * 3.0)
        if self.alpha >= 1.0 then
            self.animationComplete = true
        end
    end
end

function LevelUpCard:draw(scale, bgColor, isHovered, isSelected, globalAlpha)
    local rect = self.rect
    local cardAlpha = self.alpha * globalAlpha
    local isUltimate = self.optionData.is_ultimate

    if cardAlpha <= 0 then return end

    love.graphics.push()
    love.graphics.translate(rect.x + rect.w / 2, rect.y + rect.h / 2)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-(rect.x + rect.w / 2), -(rect.y + rect.h / 2))

    -- Efeito especial para melhorias ultimate
    if isUltimate then
        self:drawUltimateEffects(rect, cardAlpha)
    end

    -- Fundo do card
    local finalBgColor = bgColor
    if isUltimate then
        -- Fundo especial para ultimate com gradiente dourado
        finalBgColor = {
            colors.rankDetails.S[1] * 0.15,
            colors.rankDetails.S[2] * 0.15,
            colors.rankDetails.S[3] * 0.15
        }
    end

    love.graphics.setColor(finalBgColor[1], finalBgColor[2], finalBgColor[3], cardAlpha * 0.9)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)

    -- Borda do card
    local categoryColor = self.optionData.color
    local borderColor = categoryColor
    local borderWidth = 1

    if isUltimate then
        borderColor = colors.rankDetails.S
        borderWidth = 3
        -- Efeito de brilho na borda para ultimate
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], cardAlpha * 0.5)
        love.graphics.setLineWidth(borderWidth + 2)
        love.graphics.rectangle("line", rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2)
    end

    if isSelected then
        borderColor = colors.border_active
        borderWidth = 3
    elseif isHovered then
        borderWidth = 0
    end

    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], cardAlpha)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)

    -- Conteúdo do card
    self:drawContent(cardAlpha)

    love.graphics.pop()
end

function LevelUpCard:drawUltimateEffects(rect, cardAlpha)
    local time = love.timer.getTime()

    -- Efeito de brilho pulsante
    local pulseIntensity = 0.5 + 0.3 * math.sin(time * 3)
    local glowAlpha = cardAlpha * pulseIntensity * 0.8

    -- Glow exterior
    love.graphics.setColor(colors.rankDetails.S[1], colors.rankDetails.S[2], colors.rankDetails.S[3], glowAlpha * 0.3)
    for i = 1, 3 do
        local glowOffset = i * 3
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line",
            rect.x - glowOffset, rect.y - glowOffset,
            rect.w + glowOffset * 2, rect.h + glowOffset * 2)
    end

    -- Partículas de luz (efeito simulado)
    local particleCount = 8
    for i = 1, particleCount do
        local angle = (time * 0.5 + i * (math.pi * 2 / particleCount)) % (math.pi * 2)
        local particleX = rect.x + rect.w / 2 + math.cos(angle) * (rect.w / 2 + 20)
        local particleY = rect.y + rect.h / 2 + math.sin(angle) * (rect.h / 2 + 20)
        local particleAlpha = cardAlpha * (0.3 + 0.2 * math.sin(time * 2 + i))

        love.graphics.setColor(colors.rankDetails.S[1], colors.rankDetails.S[2], colors.rankDetails.S[3], particleAlpha)
        love.graphics.circle("fill", particleX, particleY, 2)
    end

    -- Efeito de raios de luz nos cantos
    local rayAlpha = cardAlpha * (0.4 + 0.2 * math.sin(time * 4))
    love.graphics.setColor(colors.rankDetails.S[1], colors.rankDetails.S[2], colors.rankDetails.S[3], rayAlpha)
    love.graphics.setLineWidth(2)

    -- Raios nos cantos
    local cornerOffset = 15
    -- Canto superior esquerdo
    love.graphics.line(rect.x - cornerOffset, rect.y, rect.x, rect.y - cornerOffset)
    love.graphics.line(rect.x, rect.y - cornerOffset, rect.x + cornerOffset, rect.y)

    -- Canto superior direito
    love.graphics.line(rect.x + rect.w - cornerOffset, rect.y, rect.x + rect.w, rect.y - cornerOffset)
    love.graphics.line(rect.x + rect.w, rect.y - cornerOffset, rect.x + rect.w + cornerOffset, rect.y)

    -- Canto inferior esquerdo
    love.graphics.line(rect.x - cornerOffset, rect.y + rect.h, rect.x, rect.y + rect.h + cornerOffset)
    love.graphics.line(rect.x, rect.y + rect.h + cornerOffset, rect.x + cornerOffset, rect.y + rect.h)

    -- Canto inferior direito
    love.graphics.line(rect.x + rect.w - cornerOffset, rect.y + rect.h, rect.x + rect.w, rect.y + rect.h + cornerOffset)
    love.graphics.line(rect.x + rect.w, rect.y + rect.h + cornerOffset, rect.x + rect.w + cornerOffset, rect.y + rect.h)
end

function LevelUpCard:drawContent(alpha)
    local rect = self.rect
    local headerHeight = 72 -- Reduzido de 120 para 72 (40% menor)
    local currentY = rect.y

    -- Cabeçalho colorido
    local categoryColor = self.optionData.color
    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha * 0.8)
    love.graphics.rectangle("fill", rect.x, currentY, rect.w, headerHeight)

    -- Imagem da skill no cabeçalho
    if self.skillImage then
        love.graphics.setColor(1, 1, 1, alpha)
        local imageSize = 96
        local imageX = rect.x + (rect.w - imageSize) / 2
        local imageY = currentY - imageSize / 2

        local scaleX = imageSize / self.skillImage:getWidth()
        local scaleY = imageSize / self.skillImage:getHeight()
        love.graphics.draw(
            self.skillImage,
            imageX + imageSize / 2,
            imageY + imageSize / 2,
            0,
            scaleX,
            scaleY,
            self.skillImage:getWidth() / 2,
            self.skillImage:getHeight() / 2
        )
    else
        -- Fallback: ícone de texto
        love.graphics.setFont(fonts.hud)
        love.graphics.setColor(1, 1, 1, alpha)
        local iconText = "N/A"
        love.graphics.printf(iconText, rect.x, currentY + 15, rect.w, "center")
    end

    -- Contador de nível dentro do cabeçalho
    local currentLevel = self.optionData.current_level_for_display or 0
    local maxLevel = self.optionData.max_level or 1
    local nextLevel = currentLevel + 1

    love.graphics.setFont(fonts.main_bold)
    love.graphics.setColor(colors.white)
    local progressText = string.format("%d/%d", nextLevel, maxLevel)
    love.graphics.printf(progressText, rect.x + 8, currentY + headerHeight - 20, rect.w - 16, "right")

    currentY = currentY + headerHeight

    -- Barra de progresso (colada ao cabeçalho, largura total)
    local progressBarHeight = 8
    local progressBarPadding = 0
    local progressBarX = rect.x + progressBarPadding
    local progressBarWidth = rect.w - (progressBarPadding * 2)

    -- Fundo da barra
    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha * 0.5)
    love.graphics.rectangle("fill", progressBarX, currentY, progressBarWidth, progressBarHeight)

    -- Preenchimento da barra
    local progress = currentLevel / maxLevel
    local fillWidth = progressBarWidth * progress
    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha)
    love.graphics.rectangle("fill", progressBarX, currentY, fillWidth, progressBarHeight)

    currentY = currentY + progressBarHeight + 10

    -- Conteúdo principal com padding
    local padding = 12
    local contentX = rect.x + padding
    local contentWidth = rect.w - (padding * 2)

    -- Indicador ULTIMATE se aplicável
    if self.optionData.is_ultimate then
        love.graphics.setFont(fonts.main_small_bold)
        love.graphics.setColor(colors.rankDetails.S[1], colors.rankDetails.S[2], colors.rankDetails.S[3], alpha)
        local ultimateText = "✦ ULTIMATE ✦"
        love.graphics.printf(ultimateText, contentX, currentY, contentWidth, "center")
        -- Sombra dourada para o texto ULTIMATE
        love.graphics.setColor(colors.rankDetails.S[1] * 0.7, colors.rankDetails.S[2] * 0.7,
            colors.rankDetails.S[3] * 0.7, alpha * 0.8)
        love.graphics.printf(ultimateText, contentX + 1, currentY + 1, contentWidth, "center")
        currentY = currentY + fonts.main_small_bold:getHeight() + 4
    end

    -- Nome da melhoria (negrito)
    love.graphics.setFont(fonts.title_large)
    local nameColor = self.optionData.is_ultimate and colors.rankDetails.S or colors.text_title
    love.graphics.setColor(nameColor[1], nameColor[2], nameColor[3], alpha)
    local nameText = self.optionData.name or "Melhoria Desconhecida"
    love.graphics.printf(nameText, contentX, currentY, contentWidth, "center")
    -- Adiciona sombra ao nome da melhoria
    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha * 0.5)
    love.graphics.printf(nameText, contentX + 1, currentY + 1, contentWidth, "center")
    currentY = currentY + fonts.title_large:getHeight() + 2

    -- Tipo de melhoria
    love.graphics.setFont(fonts.main_small)
    love.graphics.setColor(colors.text_muted[1], colors.text_muted[2], colors.text_muted[3], alpha)
    local improvementType = self:getImprovementType()
    love.graphics.printf(improvementType, contentX, currentY, contentWidth, "center")
    currentY = currentY + fonts.main_small:getHeight() + 8

    -- Descrição com palavras-chave coloridas
    love.graphics.setFont(fonts.main_large)
    currentY = currentY + self:drawColoredDescription(contentX, currentY, contentWidth, alpha)

    -- Modificadores resumidos com cores
    love.graphics.setFont(fonts.main_small_bold)
    local modifiers = self:getModifiersData()
    if modifiers and #modifiers > 0 then
        currentY = currentY + self:drawColoredModifiers(contentX, currentY, contentWidth, modifiers, alpha)
    end
end

function LevelUpCard:drawColoredModifiers(x, y, width, modifiers, alpha)
    local lineHeight = fonts.main_small_bold:getHeight()
    local currentY = 0

    for _, modifier in ipairs(modifiers) do
        -- Define a cor baseada no valor
        if modifier.value >= 0 then
            love.graphics.setColor(0.4, 1.0, 0.4, alpha) -- Verde para positivos
        else
            love.graphics.setColor(1.0, 0.4, 0.4, alpha) -- Vermelho para negativos
        end

        love.graphics.printf(modifier.text, x, y + currentY, width, "left")
        currentY = currentY + lineHeight
    end

    return currentY
end

function LevelUpCard:getModifiersData()
    local modifiers = {}
    if self.optionData.modifiers_per_level then
        for _, mod in ipairs(self.optionData.modifiers_per_level) do
            local valueString = ""
            local prefix = (mod.value >= 0) and "+" or ""

            if mod.type == "fixed" then
                valueString = prefix .. string.format("%.1f", mod.value):gsub("%.0$", "")
            elseif mod.type == "percentage" then
                valueString = prefix .. string.format("%.1f", mod.value):gsub("%.0$", "") .. "%"
            elseif mod.type == "fixed_percentage_as_fraction" then
                valueString = prefix .. string.format("%.1f", mod.value * 100):gsub("%.0$", "") .. "%"
            else
                valueString = prefix .. tostring(mod.value)
            end

            if mod.stat then
                -- Usa o Formatters para traduzir o nome do stat
                local statName = Formatters.getStatDisplayName(mod.stat) or mod.stat
                -- Se não encontrou no Formatters, tenta formatar manualmente
                if statName == mod.stat then
                    statName = mod.stat:gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end)
                end

                table.insert(modifiers, {
                    text = valueString .. " " .. statName,
                    value = mod.value
                })
            end
        end
    end
    return modifiers
end

function LevelUpCard:getImprovementType()
    -- Determina o tipo baseado no ID ou outros campos
    if self.optionData.is_ultimate then
        return "Melhoria Ultimate - Rank S"
    end

    local bonusId = self.optionData.id or ""
    if string.find(bonusId, "rune") then
        return "Melhoria de Runa"
    elseif string.find(bonusId, "weapon") then
        return "Melhoria de Arma"
    else
        return "Melhoria de Nível"
    end
end

function LevelUpCard:drawColoredDescription(x, y, width, alpha)
    local description = self.optionData.description or ""
    local fontNormal = fonts.main_large
    local fontBold = fonts.main_large_bold
    local lineHeight = math.max(fontNormal:getHeight(), fontBold:getHeight())
    local currentY = 0

    -- Parse do texto para encontrar palavras-chave entre |palavra|
    local segments = {}
    local currentPos = 1

    while currentPos <= #description do
        local pipeStart = description:find("|", currentPos)
        if not pipeStart then
            -- Resto do texto sem formatação
            if currentPos <= #description then
                table.insert(segments, {
                    text = description:sub(currentPos),
                    colored = false
                })
            end
            break
        end

        -- Texto antes da primeira pipe
        if pipeStart > currentPos then
            table.insert(segments, {
                text = description:sub(currentPos, pipeStart - 1),
                colored = false
            })
        end

        -- Procura a pipe de fechamento
        local pipeEnd = description:find("|", pipeStart + 1)
        if not pipeEnd then
            -- Pipe sem fechamento, trata como texto normal
            table.insert(segments, {
                text = description:sub(pipeStart),
                colored = false
            })
            break
        end

        -- Palavra-chave entre pipes
        local keyword = description:sub(pipeStart + 1, pipeEnd - 1)
        table.insert(segments, {
            text = keyword,
            colored = true,
            keyword = keyword
        })

        currentPos = pipeEnd + 1
    end

    -- Renderiza os segmentos com quebra de linha
    local currentLine = ""
    local lineSegments = {}

    for _, segment in ipairs(segments) do
        local words = {}
        for word in segment.text:gmatch("%S+") do
            table.insert(words, word)
        end

        for i, word in ipairs(words) do
            -- Calcula a largura da palavra usando a fonte apropriada
            local wordFont = segment.colored and fontBold or fontNormal
            local wordWidth = wordFont:getWidth(word)

            -- Testa se a linha atual + nova palavra cabe na largura
            local testLineWidth = 0
            local testSegments = {}

            -- Copia segmentos atuais
            for _, seg in ipairs(lineSegments) do
                table.insert(testSegments, seg)
            end

            -- Adiciona a nova palavra
            if #testSegments > 0 and testSegments[#testSegments].colored == segment.colored then
                -- Mesmo tipo de formatação - junta na mesma segment
                local lastSeg = testSegments[#testSegments]
                lastSeg.text = lastSeg.text .. " " .. word
            else
                -- Novo segmento
                table.insert(testSegments, {
                    text = (#currentLine > 0 and " " or "") .. word,
                    colored = segment.colored,
                    keyword = segment.keyword
                })
            end

            -- Calcula largura total da linha de teste
            for _, seg in ipairs(testSegments) do
                local segFont = seg.colored and fontBold or fontNormal
                testLineWidth = testLineWidth + segFont:getWidth(seg.text)
            end

            if testLineWidth > width and #currentLine > 0 then
                -- Quebra a linha
                self:renderColoredLine(x, y + currentY, lineSegments, alpha)
                currentY = currentY + lineHeight
                currentLine = word
                lineSegments = { { text = word, colored = segment.colored, keyword = segment.keyword } }
            else
                currentLine = currentLine .. (#currentLine > 0 and " " or "") .. word
                lineSegments = testSegments
            end
        end

        -- Adiciona espaço entre segmentos se necessário
        --if segment ~= segments[#segments] then
        --    currentLine = currentLine .. " "
        --    if #lineSegments > 0 then
        --        lineSegments[#lineSegments].text = lineSegments[#lineSegments].text .. " "
        --    end
        --end
    end

    -- Renderiza a última linha
    if #lineSegments > 0 then
        self:renderColoredLine(x, y + currentY, lineSegments, alpha)
        currentY = currentY + lineHeight
    end

    return currentY + 8 -- Adiciona espaçamento
end

function LevelUpCard:renderColoredLine(x, y, segments, alpha)
    local currentX = x
    local fontNormal = fonts.main
    local fontBold = fonts.main_bold

    for _, segment in ipairs(segments) do
        local segmentFont = segment.colored and fontBold or fontNormal
        love.graphics.setFont(segmentFont)

        if segment.colored then
            -- Primeiro verifica se é um número (prioridade sobre palavras-chave)
            local isNumber = false
            local text = segment.text or ""

            -- Verifica padrões de números
            if text:match("^[%+%-]?%d") or text:match("^%d") or text:match("%%$") or text:match("^%-") then
                isNumber = true
                -- Cor baseada no valor numérico
                if text:match("^%-") or text:find("%-") then
                    -- Valores negativos (começam com - ou contêm -)
                    love.graphics.setColor(1.0, 0.4, 0.4, alpha) -- Vermelho
                else
                    -- Valores positivos
                    love.graphics.setColor(0.4, 1.0, 0.4, alpha) -- Verde
                end
            end

            if not isNumber then
                -- Se não é número, verifica palavras-chave
                local keywordColor = LevelUpBonusesData.KeywordColors[segment.keyword]
                if keywordColor then
                    love.graphics.setColor(keywordColor[1], keywordColor[2], keywordColor[3], alpha)
                else
                    -- Fallback: branco para palavras-chave não encontradas
                    love.graphics.setColor(1.0, 1.0, 1.0, alpha)
                end
            end
        else
            -- Cor normal do texto
            love.graphics.setColor(colors.text_main[1], colors.text_main[2], colors.text_main[3], alpha)
        end

        love.graphics.print(segment.text, currentX, y)
        currentX = currentX + segmentFont:getWidth(segment.text)
    end
end

function LevelUpCard:getModifiersSummary()
    local summary = {}
    if self.optionData.modifiers_per_level then
        for _, mod in ipairs(self.optionData.modifiers_per_level) do
            local valueString = ""
            local prefix = (mod.value >= 0) and "+" or ""

            if mod.type == "fixed" then
                valueString = prefix .. string.format("%.1f", mod.value):gsub("%.0$", "")
            elseif mod.type == "percentage" then
                valueString = prefix .. string.format("%.1f", mod.value):gsub("%.0$", "") .. "%"
            elseif mod.type == "fixed_percentage_as_fraction" then
                valueString = prefix .. string.format("%.1f", mod.value * 100):gsub("%.0$", "") .. "%"
            else
                valueString = prefix .. tostring(mod.value)
            end

            if mod.stat then
                -- Usa o Formatters para traduzir o nome do stat
                local statName = Formatters.getStatDisplayName(mod.stat) or mod.stat
                -- Se não encontrou no Formatters, tenta formatar manualmente
                if statName == mod.stat then
                    statName = mod.stat:gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end)
                end
                table.insert(summary, valueString .. " " .. statName)
            end
        end
    end
    return table.concat(summary, "\n")
end

--- Inicializa o LevelUpModal.
--- @param playerManager PlayerManager Instância do PlayerManager.
--- @param inputManager InputManager Instância do InputManager.
function LevelUpModal:init(playerManager, inputManager)
    self.playerManager = playerManager
    self.inputManager = inputManager
    Logger.debug("level_up_modal.init", "[LevelUpModal] Inicializado")
end

function LevelUpModal:show(onCloseCallback)
    self.visible = true
    self.selectedOption = nil
    self.hoveredOption = nil
    self.canChoose = false
    self.appearanceSequenceCompleted = false
    self.cardAnimationTimer = 0.0
    self.cardsAnimated = 0
    self.onCloseCallback = onCloseCallback
    self.cards = {}
    self.scales = {}
    self.backgroundColors = {}

    self:generateOptions()
    self:createCards()

    Logger.debug("level_up_modal.show", "[LevelUpModal] Modal aberto com animação sequencial")
end

function LevelUpModal:hide()
    self.visible = false
    love.graphics.setFont(fonts.main)

    if self.onCloseCallback then
        Logger.debug("level_up_modal.hide.callback", "[LevelUpModal] Chamando callback de fechamento")
        self.onCloseCallback()
        self.onCloseCallback = nil
    end
end

function LevelUpModal:generateOptions()
    self.options = {}
    local availableBonuses = {}
    local availableUltimates = {}

    if not self.playerManager or not self.playerManager.stateController or not self.playerManager.stateController:getLearnedLevelUpBonuses() then
        error(
            "ERRO [LevelUpModal:generateOptions]: PlayerManager, PlayerStateController ou learnedLevelUpBonuses não está pronto.")
    end

    local learned = self.playerManager.stateController:getLearnedLevelUpBonuses()

    -- Primeiro, coleta melhorias normais disponíveis
    for bonusId, bonusData in pairs(LevelUpBonusesData.Bonuses) do
        if not bonusData.is_ultimate then
            local currentLevel = learned[bonusId] or 0
            if currentLevel < bonusData.max_level then
                local optionData = {}
                for k, v in pairs(bonusData) do optionData[k] = v end
                optionData.current_level_for_display = currentLevel
                table.insert(availableBonuses, optionData)
            end
        end
    end

    -- Verifica se há melhorias ultimate disponíveis
    for bonusId, bonusData in pairs(LevelUpBonusesData.Bonuses) do
        if bonusData.is_ultimate then
            local currentLevel = learned[bonusId] or 0
            if currentLevel < bonusData.max_level then
                -- Verifica se o jogador tem a melhoria base específica no nível máximo (sistema um-para-um)
                local hasMaxedBaseBonuses = false
                if bonusData.base_bonuses and #bonusData.base_bonuses == 1 then
                    local baseBonusId = bonusData.base_bonuses[1]
                    local baseBonusData = LevelUpBonusesData.Bonuses[baseBonusId]
                    if baseBonusData then
                        local baseBonusLevel = learned[baseBonusId] or 0
                        if baseBonusLevel >= baseBonusData.max_level then
                            hasMaxedBaseBonuses = true
                        end
                    end
                end

                if hasMaxedBaseBonuses then
                    local optionData = {}
                    for k, v in pairs(bonusData) do optionData[k] = v end
                    optionData.current_level_for_display = currentLevel
                    table.insert(availableUltimates, optionData)
                end
            end
        end
    end

    -- Sempre inclui uma melhoria ultimate se disponível
    local numUltimateSlots = 0
    if #availableUltimates > 0 then
        numUltimateSlots = 1
        local randomUltimateIndex = love.math.random(1, #availableUltimates)
        table.insert(self.options, availableUltimates[randomUltimateIndex])
        Logger.debug("level_up_modal.generate_options.ultimate_added",
            string.format("Melhoria ultimate adicionada: %s", availableUltimates[randomUltimateIndex].name))
    end

    -- Preenche o resto com melhorias normais
    local numNormalSlots = math.min(4 - numUltimateSlots, #availableBonuses)
    for i = 1, numNormalSlots do
        if #availableBonuses > 0 then
            local randomIndex = love.math.random(1, #availableBonuses)
            table.insert(self.options, availableBonuses[randomIndex])
            table.remove(availableBonuses, randomIndex)
        else
            break
        end
    end

    if #self.options == 0 then
        Logger.debug("level_up_modal.generate_options.no_options", "Nenhuma opção de bônus disponível")
    else
        Logger.debug("level_up_modal.generate_options.summary",
            string.format("Opções geradas: %d normais, %d ultimate", #self.options - numUltimateSlots, numUltimateSlots))
    end
end

function LevelUpModal:createCards()
    local screenW, screenH = ResolutionUtils.getGameDimensions()
    local numOptions = #self.options

    if numOptions == 0 then return end

    -- Configurações dos cards
    local cardWidth = 400
    local cardHeight = 600
    local cardGap = 40
    local totalWidth = (cardWidth * numOptions) + (cardGap * (numOptions - 1))
    local startX = (screenW - totalWidth) / 2
    local startY = (screenH - cardHeight) / 2

    for i, optionData in ipairs(self.options) do
        local cardX = startX + (i - 1) * (cardWidth + cardGap)
        local cardRect = {
            x = cardX,
            y = startY,
            w = cardWidth,
            h = cardHeight
        }

        local card = LevelUpCard:new(cardRect, optionData)
        card:loadImage() -- Carrega a imagem da skill
        self.cards[i] = card
        self.scales[i] = 1.0
        local r, g, b = unpack(colors.window_bg)
        self.backgroundColors[i] = { r, g, b }
    end
end

function LevelUpModal:update(dt)
    if not self.visible then return end

    -- Animação sequencial de aparição dos cards
    if not self.appearanceSequenceCompleted then
        self.cardAnimationTimer = self.cardAnimationTimer + dt

        local cardAppearanceDelay = 0.15
        local targetCardsAnimated = math.floor(self.cardAnimationTimer / cardAppearanceDelay) + 1

        for i = self.cardsAnimated + 1, math.min(targetCardsAnimated, #self.cards) do
            -- Inicia a animação do card i
            self.cardsAnimated = i
            Logger.debug("level_up_modal.card_animation", string.format("Iniciando animação do card %d", i))
        end

        -- Verifica se todas as animações completaram
        local allAnimated = true
        for i = 1, self.cardsAnimated do
            if self.cards[i] then
                self.cards[i]:update(dt)
                if not self.cards[i].animationComplete then
                    allAnimated = false
                end
            end
        end

        if self.cardsAnimated >= #self.cards and allAnimated then
            self.appearanceSequenceCompleted = true
            self.canChoose = true
            Logger.debug("level_up_modal.animation_complete", "Animação sequencial completa, cliques habilitados")
        end
    end

    if self.canChoose and self.inputManager then
        -- Hover detection e animações
        local mouseX, mouseY = self.inputManager:getMousePosition()
        self.hoveredOption = self:getCardAtPosition(mouseX, mouseY)

        -- Anima escalas e cores
        local lerpFactor = dt * 8.0
        for i = 1, #self.cards do
            local targetScale = (i == self.hoveredOption) and 1.1 or 1.0
            self.scales[i] = lume.lerp(self.scales[i], targetScale, lerpFactor)

            local targetColor = (i == self.hoveredOption) and colors.slot_hover_bg or colors.window_bg
            local currentColor = self.backgroundColors[i]
            currentColor[1] = lume.lerp(currentColor[1], targetColor[1], lerpFactor)
            currentColor[2] = lume.lerp(currentColor[2], targetColor[2], lerpFactor)
            currentColor[3] = lume.lerp(currentColor[3], targetColor[3], lerpFactor)
        end
    end

    -- Sempre atualiza os cards visíveis
    for i = 1, self.cardsAnimated do
        if self.cards[i] then
            self.cards[i]:update(dt)
        end
    end
end

function LevelUpModal:getCardAtPosition(x, y)
    for i, card in ipairs(self.cards) do
        if i <= self.cardsAnimated and card then
            local rect = card.rect
            local scale = self.scales[i] or 1.0

            -- Calcula bounds com escala
            local scaledWidth = rect.w * scale
            local scaledHeight = rect.h * scale
            local scaledX = rect.x + rect.w / 2 - scaledWidth / 2
            local scaledY = rect.y + rect.h / 2 - scaledHeight / 2

            if x >= scaledX and x <= scaledX + scaledWidth and
                y >= scaledY and y <= scaledY + scaledHeight then
                return i
            end
        end
    end
    return nil
end

function LevelUpModal:applyUpgrade(optionData)
    if not self.playerManager or not self.playerManager.stateController then
        error("ERRO [LevelUpModal:applyUpgrade]: PlayerManager ou PlayerStateController não está pronto.")
    end
    if not optionData or not optionData.id then
        error("ERRO [LevelUpModal:applyUpgrade]: optionData inválido ou sem ID.")
    end

    LevelUpBonusesData.ApplyBonus(self.playerManager.stateController, optionData.id)

    local bonusId = optionData.id
    local learnedBonuses = self.playerManager.stateController:getLearnedLevelUpBonuses()
    learnedBonuses[bonusId] = (learnedBonuses[bonusId] or 0) + 1
    self.playerManager:invalidateStatsCache()

    -- Registra a escolha para as estatísticas
    local gameStatsManager = self.playerManager.gameStatisticsManager
    if gameStatsManager then
        local choiceText = optionData.name or "Melhoria Desconhecida"
        gameStatsManager:registerLevelUpChoice(learnedBonuses[bonusId], choiceText)
    end

    Logger.debug("level_up_modal.apply_upgrade", string.format("Bônus '%s' (ID: %s) aplicado. Novo nível: %d",
        optionData.name, bonusId, learnedBonuses[bonusId]))
end

function LevelUpModal:draw()
    if not self.visible then return end

    -- Fundo escuro semi-transparente
    love.graphics.setColor(0, 0, 0, 0.8)
    local gameW, gameH = ResolutionUtils.getGameDimensions()
    love.graphics.rectangle("fill", 0, 0, gameW, gameH)

    -- Desenha apenas os cards que já começaram a animação
    for i = 1, self.cardsAnimated do
        local card = self.cards[i]
        if card then
            local scale = self.scales[i] or 1.0
            local bgColor = self.backgroundColors[i]
            local isHovered = (i == self.hoveredOption)
            local isSelected = (i == self.selectedOption)
            local globalAlpha = self.canChoose and 1.0 or 0.8

            card:draw(scale, bgColor, isHovered, isSelected, globalAlpha)
        end
    end

    -- Texto de instrução se ainda não pode escolher
    if not self.canChoose then
        love.graphics.setFont(fonts.main)
        love.graphics.setColor(colors.text_default[1], colors.text_default[2], colors.text_default[3], 0.8)
        love.graphics.printf("Aguarde...", 0, gameH - 50, gameW, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function LevelUpModal:mousepressed(x, y, button)
    if not self.visible or not self.canChoose or button ~= 1 then
        return false
    end

    local clickedCardIndex = self:getCardAtPosition(x, y)
    if clickedCardIndex then
        self.selectedOption = clickedCardIndex
        self:applyUpgrade(self.options[clickedCardIndex])
        self:hide()
        Logger.debug("level_up_modal.mouse_click", string.format("Card %d clicado e aplicado", clickedCardIndex))
        return true
    end
    return false
end

function LevelUpModal:keypressed(key)
    if not self.visible or not self.canChoose then
        return false
    end

    if key == "left" or key == "a" then
        if #self.options > 0 then
            if self.selectedOption == nil then
                self.selectedOption = #self.options
            else
                self.selectedOption = math.max(1, self.selectedOption - 1)
            end
            self.hoveredOption = nil
            Logger.debug("level_up_modal.keyboard_nav", "Navegou para esquerda. Índice: " .. self.selectedOption)
        end
        return true
    elseif key == "right" or key == "d" then
        if #self.options > 0 then
            if self.selectedOption == nil then
                self.selectedOption = 1
            else
                self.selectedOption = math.min(#self.options, self.selectedOption + 1)
            end
            self.hoveredOption = nil
            Logger.debug("level_up_modal.keyboard_nav", "Navegou para direita. Índice: " .. self.selectedOption)
        end
        return true
    elseif key == "return" or key == "kpenter" or key == "space" then
        if self.selectedOption and self.options[self.selectedOption] then
            Logger.debug("level_up_modal.keyboard_confirm", "Confirmando opção: " .. self.selectedOption)
            self:applyUpgrade(self.options[self.selectedOption])
            self:hide()
            return true
        end
        return true
    end
    return false
end

return LevelUpModal
