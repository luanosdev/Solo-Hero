local Colors = require("src.ui.colors")
local Fonts = require("src.ui.fonts")
local Formatters = require("src.utils.formatters")
local LevelUpBonusesData = require("src.data.level_up_bonuses_data")
local lume = require("src.libs.lume")
local adaptiveFonts = Fonts.getAdaptive()
local Constants = require("src.config.constants")

local BonusTypeColors = {
    common = Colors.text_muted,
    weapon = Colors.rarity.A,
    rune = Colors.rarity.B,
    ultimate = Colors.rarity.S,
}

---@class LevelUpCard
--------------------------------------------------------------------------------
-- LevelUpCard (Componente de UI)
-- Componente de UI "puro" que representa um único card de bônus.
-- É responsável apenas por exibir os dados que recebe, sem lógica de jogo.
--------------------------------------------------------------------------------
---@field x number Posição X do card.
---@field y number Posição Y do card.
---@field width number Largura do card.
---@field height number Altura do card.
---@field image love.Image|nil Ícone representando o bônus.
---@field currentLevel number Nível atual do bônus.
---@field data LevelUpBonus Os dados a serem exibidos.
---@field onSelect fun() Callback a ser chamado quando o card for selecionado.
---@field isMouseOver boolean Se o mouse está sobre o card.
---@field scale number
---@field alpha number
---@field animationComplete boolean
local LevelUpCard = {}
LevelUpCard.__index = LevelUpCard

-- Constantes de layout do card
local CardW, CardH = ResolutionUtils.scaleUI(400, 600)
LevelUpCard.WIDTH = CardW
LevelUpCard.HEIGHT = CardH
LevelUpCard.PADDING = ResolutionUtils.scaleSpacing(12)
LevelUpCard.BORDER_WIDTH = ResolutionUtils.scaleSpacing(1)

---@public Cria uma nova instância de um card de level up.
---@param x number Posição X inicial.
---@param y number Posição Y inicial.
---@param data LevelUpBonus Os dados a serem exibidos no card.
---@param image love.Image|nil Ícone representando o bônus.
---@param currentLevel number Nível atual do bônus.
---@return LevelUpCard
function LevelUpCard:new(x, y, data, image, currentLevel)
    local instance = setmetatable({}, LevelUpCard)

    instance.x = x
    instance.y = y
    instance.width = LevelUpCard.WIDTH
    instance.height = LevelUpCard.HEIGHT
    instance.data = data
    instance.image = image
    instance.currentLevel = currentLevel
    instance.onSelect = function() end -- Callback vazio por padrão
    instance.isMouseOver = false
    instance.scale = 1.0
    instance.alpha = 0.0
    instance.animationComplete = false

    return instance
end

---@public Registra uma função de callback para quando o card for selecionado.
---@param callback fun() A função a ser chamada.
function LevelUpCard:setOnSelect(callback)
    self.onSelect = callback
end

---Verifica se as coordenadas do mouse estão sobre o card.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
---@return boolean
function LevelUpCard:isHovered(mx, my)
    -- Calcula bounds com escala
    local scaledWidth = self.width * self.scale
    local scaledHeight = self.height * self.scale
    local scaledX = self.x + self.width / 2 - scaledWidth / 2
    local scaledY = self.y + self.height / 2 - scaledHeight / 2

    return mx >= scaledX and mx <= scaledX + scaledWidth and
        my >= scaledY and my <= scaledY + scaledHeight
end

---Atualiza o estado do card (ex: hover, animações).
---@param dt number Delta time.
---@param mx number Posição X do mouse.
---@param my number Posição Y do mouse.
function LevelUpCard:update(dt, mx, my)
    self.isMouseOver = self:isHovered(mx, my)

    -- Animação de fade-in
    if not self.animationComplete then
        self.alpha = math.min(1.0, self.alpha + dt * 3.0)
        if self.alpha >= 1.0 then
            self.animationComplete = true
        end
    end

    -- Animação de escala no hover
    local targetScale = self.isMouseOver and 1.1 or 1.0
    self.scale = lume.lerp(self.scale, targetScale, dt * 8.0)
end

---@private Retorna a cor apropriada para o bônus com base em seu tipo.
---@return table Cor no formato LÖVE {r, g, b, a}.
function LevelUpCard:_getBonusColor()
    if self.data.is_ultimate then
        return BonusTypeColors.ultimate
    end
    -- A categoria será "weapon", "rune", ou "common" (se não for nenhum dos outros)
    local bonusType = self:_getImprovementType()
    if bonusType == "Melhoria de Arma" then
        return BonusTypeColors.weapon
    elseif bonusType == "Melhoria de Runa" then
        return BonusTypeColors.rune
    else
        return BonusTypeColors.common
    end
end

---Desenha o card na tela.
function LevelUpCard:draw()
    if self.alpha <= 0 then return end

    local isUltimate = self.data.is_ultimate
    local categoryColor = self:_getBonusColor()

    love.graphics.push()
    love.graphics.translate(self.x + self.width / 2, self.y + self.height / 2)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-(self.x + self.width / 2), -(self.y + self.height / 2))

    -- Efeito especial para melhorias ultimate
    if isUltimate then
        self:_drawUltimateEffects(self.alpha, categoryColor)
    end

    -- Fundo do card (apenas para não-ultimate)
    if not isUltimate then
        local bgColor = self.isMouseOver and Colors.window_bg or Colors.solo_leveling.shadow_monarch
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], self.alpha * 0.9)
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    end

    -- Borda do card
    local borderColor = categoryColor
    local borderWidth = LevelUpCard.BORDER_WIDTH

    if isUltimate then
        borderWidth = 3
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], self.alpha * 0.7)
        love.graphics.setLineWidth(borderWidth + 2)
        love.graphics.rectangle("line", self.x - 1, self.y - 1, self.width + 2, self.height + 2)
    end

    love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], self.alpha)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)

    -- Conteúdo do card
    self:_drawContent(self.alpha, categoryColor)

    love.graphics.pop()
end

---@private Desenha os efeitos especiais para melhorias ultimate.
---@param cardAlpha number Alfa do card.
---@param categoryColor table Cor da categoria do bônus.
function LevelUpCard:_drawUltimateEffects(cardAlpha, categoryColor)
    local time = love.timer.getTime()
    local ultimateGlow = categoryColor
    local ultimateBright = { categoryColor[1] * 1.2, categoryColor[2] * 1.2, categoryColor[3] * 1.2, 1.0 }

    local bgPulse = 0.2 + 0.1 * math.sin(time * 2)
    local bgAlpha = cardAlpha * bgPulse
    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], bgAlpha)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    local pulseIntensity = 0.5 + 0.4 * math.sin(time * 3)
    local glowAlpha = cardAlpha * pulseIntensity

    love.graphics.setColor(ultimateGlow[1], ultimateGlow[2], ultimateGlow[3], glowAlpha * 0.6)
    for i = 1, 5 do
        local glowOffset = i * 2
        love.graphics.setLineWidth(1 + i * 0.5)
        love.graphics.rectangle(
            "line",
            self.x - glowOffset,
            self.y - glowOffset,
            self.width + glowOffset * 2,
            self.height + glowOffset * 2
        )
    end

    local particleCount = 15
    for i = 1, particleCount do
        local particleLife = (time * 0.5 + i * 0.1) % 2
        local particleProgress = particleLife / 2
        local particleX = self.x + (self.width * ((i * 0.618) % 1))
        local particleY = self.y + self.height - (particleProgress * (self.height + 50))
        local particleAlpha = cardAlpha * (1 - particleProgress) * 0.8
        local particleSize = 5 * (1 - particleProgress)

        if particleAlpha > 0.1 then
            love.graphics.setColor(ultimateBright[1], ultimateBright[2], ultimateBright[3], particleAlpha)
            love.graphics.circle("fill", particleX, particleY, particleSize)
        end
    end

    local pulseSize = 4 + 3 * math.sin(time * 4)
    local pulseAlpha = cardAlpha * (0.3 + 0.2 * math.sin(time * 6))
    love.graphics.setColor(ultimateGlow[1], ultimateGlow[2], ultimateGlow[3], pulseAlpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle(
        "line",
        self.x - pulseSize,
        self.y - pulseSize,
        self.width + pulseSize * 2,
        self.height + pulseSize * 2
    )
end

---@private Desenha o conteúdo do card.
---@param alpha number Alfa do card.
---@param categoryColor table Cor da categoria do bônus.
function LevelUpCard:_drawContent(alpha, categoryColor)
    local _, headerHeight = ResolutionUtils.scaleUI(LevelUpCard.WIDTH, 72)
    local currentY = self.y

    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha * 0.8)
    love.graphics.rectangle("fill", self.x, currentY, self.width, headerHeight)

    if self.image then
        love.graphics.setColor(1, 1, 1, alpha)
        local imageSize = ResolutionUtils.scaleSpacing(96)
        local imageX = self.x + (self.width - imageSize) / 2
        local imageY = currentY - imageSize / 2
        local scaleX = imageSize / self.image:getWidth()
        local scaleY = imageSize / self.image:getHeight()
        love.graphics.draw(
            self.image,
            imageX + imageSize / 2,
            imageY + imageSize / 2,
            0,
            scaleX,
            scaleY,
            self.image:getWidth() / 2,
            self.image:getHeight() / 2
        )
    end

    local currentLevel = self.currentLevel or 0
    local maxLevel = self.data.max_level or 1
    local nextLevel = currentLevel + 1

    love.graphics.setFont(adaptiveFonts.main_bold)
    love.graphics.setColor(Colors.white)
    local progressText = string.format("%d/%d", currentLevel, maxLevel)
    love.graphics.printf(progressText, self.x + 8, currentY + headerHeight - 20, self.width - 16, "right")

    currentY = currentY + headerHeight

    local _, progressBarHeight = ResolutionUtils.scaleUI(LevelUpCard.WIDTH, 8)
    local progressBarX = self.x
    local progressBarWidth = self.width

    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha * 0.3)
    love.graphics.rectangle("fill", progressBarX, currentY, progressBarWidth, progressBarHeight)

    local progress = currentLevel / maxLevel
    local fillWidth = progressBarWidth * progress
    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha)
    love.graphics.rectangle("fill", progressBarX, currentY, fillWidth, progressBarHeight)

    currentY = currentY + progressBarHeight + ResolutionUtils.scaleSpacing(10)

    local contentX = self.x + LevelUpCard.PADDING
    local contentWidth = self.width - (LevelUpCard.PADDING * 2)

    love.graphics.setFont(adaptiveFonts.title_large)
    local nameText = _T("bonuses." .. self.data.id .. ".name") .. " " .. Formatters.formatRomanNumber(nextLevel)

    if self.data.is_ultimate then
        local time = love.timer.getTime()
        local glowIntensity = 0.6 + 0.4 * math.sin(time * 3)
        for i = 1, 3 do
            local glowOffset = i * 0.5
            local glowAlpha = alpha * glowIntensity * (0.3 / i)
            love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], glowAlpha)
            love.graphics.printf(nameText, contentX - glowOffset, currentY - glowOffset, contentWidth, "center")
            love.graphics.printf(nameText, contentX + glowOffset, currentY - glowOffset, contentWidth, "center")
            love.graphics.printf(nameText, contentX - glowOffset, currentY + glowOffset, contentWidth, "center")
            love.graphics.printf(nameText, contentX + glowOffset, currentY + glowOffset, contentWidth, "center")
        end
        local brightColor = { categoryColor[1] * 1.3, categoryColor[2] * 1.3, categoryColor[3] * 1.3, 1.0 }
        love.graphics.setColor(brightColor[1], brightColor[2], brightColor[3], alpha)
    else
        love.graphics.setColor(Colors.text_title[1], Colors.text_title[2], Colors.text_title[3], alpha)
    end
    love.graphics.printf(nameText, contentX, currentY, contentWidth, "center")

    if not self.data.is_ultimate then
        love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha * 0.5)
        love.graphics.printf(nameText, contentX + 1, currentY + 1, contentWidth, "center")
    end
    currentY = currentY + adaptiveFonts.title_large:getHeight() + 2

    love.graphics.setFont(adaptiveFonts.main_small)
    love.graphics.setColor(categoryColor[1], categoryColor[2], categoryColor[3], alpha)
    local improvementType = self:_getImprovementType()
    love.graphics.printf(improvementType, contentX, currentY, contentWidth, "center")
    currentY = currentY + adaptiveFonts.main_small:getHeight() + 8

    local conceptTextColor = Colors.text_main
    love.graphics.setFont(adaptiveFonts.main_small)
    love.graphics.setColor(conceptTextColor[1], conceptTextColor[2], conceptTextColor[3], alpha)
    local conceptText = _T("bonuses." .. self.data.id .. ".concept")
    love.graphics.printf(conceptText, contentX, currentY, contentWidth, "center")
    currentY = currentY + adaptiveFonts.main_small:getHeight() + 8

    love.graphics.setFont(adaptiveFonts.main_large)
    currentY = currentY + self:_drawColoredDescription(contentX, currentY, contentWidth, alpha)

    love.graphics.setFont(adaptiveFonts.main_small_bold)
    local modifiers = self:_getModifiersData()
    if modifiers and #modifiers > 0 then
        currentY = currentY + self:_drawColoredModifiers(contentX, currentY, contentWidth, modifiers, alpha)
    end
end

function LevelUpCard:_drawColoredModifiers(x, y, width, modifiers, alpha)
    local lineHeight = adaptiveFonts.main_small_bold:getHeight()
    local currentY = 0
    for _, modifier in ipairs(modifiers) do
        if modifier.value >= 0 then
            love.graphics.setColor(0.4, 1.0, 0.4, alpha) -- Verde
        else
            love.graphics.setColor(1.0, 0.4, 0.4, alpha) -- Vermelho
        end
        love.graphics.printf(modifier.text, x, y + currentY, width, "left")
        currentY = currentY + lineHeight
    end
    return currentY
end

function LevelUpCard:_getModifiersData()
    local modifiers = {}
    if self.data.modifiers_per_level then
        for _, mod in ipairs(self.data.modifiers_per_level) do
            local valueString = ""
            local prefix = (mod.value >= 0) and "+" or ""

            if mod.type == Constants.STAT_MODIFIERS.FLAT then
                valueString = prefix .. string.format("%.1f", mod.value):gsub("%.0$", "")
            elseif mod.type == Constants.STAT_MODIFIERS.PERCENTAGE then
                valueString = prefix .. string.format("%.1f", mod.value):gsub("%.0$", "") .. "%"
            end

            if mod.stat then
                local statName = Formatters.getStatDisplayName(mod.stat) or mod.stat
                if statName == mod.stat then
                    statName = mod.stat:gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end)
                end
                table.insert(modifiers, { text = valueString .. " " .. statName, value = mod.value })
            end
        end
    end
    return modifiers
end

function LevelUpCard:_getImprovementType()
    if self.data.is_ultimate then
        return "MELHORIA ULTIMATE"
    end
    local bonusId = self.data.id or ""
    if string.find(bonusId, "rune") then
        return "Melhoria de Runa"
    elseif string.find(bonusId, "path") then
        return "Melhoria de Arma"
    else
        return "Melhoria de Nível"
    end
end

function LevelUpCard:_drawColoredDescription(x, y, width, alpha)
    -- 1. Obter o template de descrição traduzido
    local descriptionTemplate = _T("bonuses." .. self.data.id .. ".description")

    -- 2. Substituir placeholders pelos valores dos modificadores
    local finalDescription = descriptionTemplate
    if self.data.modifiers_per_level then
        for i, mod in ipairs(self.data.modifiers_per_level) do
            local valueString = ""
            local absValue = math.abs(mod.value)

            if mod.type == Constants.STAT_MODIFIERS.FLAT then
                valueString = string.format("%.1f", absValue):gsub("%.0$", "")
            elseif mod.type == Constants.STAT_MODIFIERS.PERCENTAGE then
                valueString = string.format("%.1f", absValue):gsub("%.0$", "") .. "%"
            end

            finalDescription = finalDescription:gsub("{value_" .. i .. "}", valueString)
            if i == 1 then
                finalDescription = finalDescription:gsub("{value}", valueString)
            end
        end
    end

    -- 3. Parsear e desenhar
    local fontNormal = adaptiveFonts.main_large
    local fontBold = adaptiveFonts.main_large_bold
    local lineHeight = math.max(fontNormal:getHeight(), fontBold:getHeight())
    local currentY = 0

    local segments = {}
    local textToParse = finalDescription
    while #textToParse > 0 do
        local s, e, tag, content = textToParse:find("%[(.-)%](.-)%[/%1%]")
        if s then
            if s > 1 then table.insert(segments, { text = textToParse:sub(1, s - 1) }) end
            table.insert(segments, { text = content, tag = tag })
            textToParse = textToParse:sub(e + 1)
        else
            table.insert(segments, { text = textToParse })
            break
        end
    end

    local lineSegments = {}
    local currentLineWidth = 0

    local function renderLine()
        local currentX = x
        for _, seg in ipairs(lineSegments) do
            local font = seg.tag and fontBold or fontNormal
            love.graphics.setFont(font)

            local color = Colors.text_main
            if seg.tag == "stat" then
                color = Colors.text_highlight
            elseif seg.tag == "value_positive" then
                color = Colors.feedback.success
            elseif seg.tag == "value_negative" then
                color = Colors.feedback.error
            end
            love.graphics.setColor(color[1], color[2], color[3], alpha)

            love.graphics.print(seg.text, currentX, y + currentY)
            currentX = currentX + font:getWidth(seg.text)
        end
        currentY = currentY + lineHeight
        lineSegments = {}
        currentLineWidth = 0
    end

    for _, segment in ipairs(segments) do
        local words = {}
        for word in segment.text:gmatch("%S+") do table.insert(words, word) end

        for _, word in ipairs(words) do
            local font = segment.tag and fontBold or fontNormal
            local wordWidth = font:getWidth(word .. " ")

            if currentLineWidth + wordWidth > width and #lineSegments > 0 then
                renderLine()
            end

            if #lineSegments > 0 and lineSegments[#lineSegments].tag == segment.tag then
                lineSegments[#lineSegments].text = lineSegments[#lineSegments].text .. " " .. word
            else
                table.insert(lineSegments, { text = word, tag = segment.tag })
            end
            currentLineWidth = currentLineWidth + font:getWidth(word) + font:getWidth(" ")
        end
    end

    if #lineSegments > 0 then
        renderLine()
    end

    return currentY + 8
end

function LevelUpCard:_renderColoredLine(x, y, segments, alpha)
    local currentX = x
    local fontNormal = Fonts.main
    local fontBold = Fonts.main_bold
    for _, segment in ipairs(segments) do
        local segmentFont = segment.colored and fontBold or fontNormal
        love.graphics.setFont(segmentFont)
        if segment.colored then
            local isNumber = false
            local text = segment.text or ""
            if text:match("^[%+%-]?%d") or text:match("^%d") or text:match("%%$") or text:match("^%-") then
                isNumber = true
                if text:match("^%-") or text:find("%-") then
                    love.graphics.setColor(1.0, 0.4, 0.4, alpha) -- Vermelho
                else
                    love.graphics.setColor(0.4, 1.0, 0.4, alpha) -- Verde
                end
            end
            if not isNumber then
                local keywordColor = LevelUpBonusesData.KeywordColors[segment.keyword]
                if keywordColor then
                    love.graphics.setColor(keywordColor[1], keywordColor[2], keywordColor[3], alpha)
                else
                    love.graphics.setColor(1.0, 1.0, 1.0, alpha)
                end
            end
        else
            love.graphics.setColor(Colors.text_main[1], Colors.text_main[2], Colors.text_main[3], alpha)
        end
        love.graphics.print(segment.text, currentX, y)
        currentX = currentX + segmentFont:getWidth(segment.text)
    end
end

return LevelUpCard
