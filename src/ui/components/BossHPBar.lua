------------------------------------------------------------------------------------------------
-- Gerencia a barra de vida de um boss.
------------------------------------------------------------------------------------------------

local Colors = require("src.ui.colors")
local Fonts = require("src.ui.fonts")
local lume = require("src.libs.lume")

---@class BossHPBar
---@field boss BaseBoss O chefe associado a esta barra.
---@field x number Posição X do centro da barra.
---@field y number Posição Y do topo da barra.
---@field width number Largura total do componente.
---@field visualHP number HP que é visualmente animado para baixo.
---@field rankColors table Cores baseadas no rank do chefe.
---@field animationState string Estado da animação de entrada ('hidden', 'fading_in_text', 'fading_in_bar', 'visible').
---@field animationTimer number Timer para as animações.
---@field textAlpha number Alpha do texto (0-255).
---@field barAlpha number Alpha da barra (0-255).
---@field hpBarAnimationSpeed number Velocidade de animação da "trilha de dano".
---@field hpBarAnimationDownDelay number Delay para a "trilha de dano" começar a seguir.
---@field hpBarAnimationDownTimer number Timer para o delay da "trilha de dano".
---@field isHPBarAnimatingDown boolean Flag se a trilha de dano está ativa.
---@field internalLayout table Cache de posições e dimensões.
---@field segmentHPInterval number Intervalo de HP para desenhar um segmento vertical.
local BossHPBar = {}
BossHPBar.__index = BossHPBar

--- Cria uma nova barra de vida para um chefe.
---@param boss BaseBoss O chefe.
---@param yPosition number A posição Y inicial para desenhar a barra.
---@return BossHPBar
function BossHPBar:new(boss, yPosition)
    local instance = setmetatable({}, BossHPBar)

    instance.boss = boss
    instance.y = yPosition
    instance.width = 800
    instance.x = ResolutionUtils.getGameWidth() / 2 -- Centralizado

    instance.visualHP = boss.currentHealth
    instance.rankColors = Colors.rankDetails[boss.rank or "E"] or Colors.rankDetails["E"]

    instance.animationState = "hidden"
    instance.animationTimer = 0
    instance.textAlpha = 0
    instance.barAlpha = 0

    instance.hpBarAnimationSpeed = boss.maxHealth * 0.3
    instance.hpBarAnimationDownDelay = 0.8
    instance.hpBarAnimationDownTimer = 0
    instance.isHPBarAnimatingDown = false
    instance.segmentHPInterval = boss.maxHealth / 10 -- Intervalo de 1000 HP por segmento

    instance.internalLayout = {}
    instance:_updateLayout()

    return instance
end

--- Inicia a animação de fade-in da barra.
function BossHPBar:show()
    if self.animationState == "hidden" then
        self.animationState = "fading_in_text"
        self.animationTimer = 0
    end
end

function BossHPBar:_updateLayout()
    local layout = self.internalLayout
    local boss = self.boss

    layout.fontName = Fonts.title_large
    layout.fontRank = Fonts.title
    layout.fontHPValues = Fonts.title

    layout.bossNameText = boss.mvpProperName or boss.name
    layout.bossRankText = "Ranking " .. boss.rank
    layout.fullTitleText = layout.bossNameText .. ", " .. layout.bossRankText

    love.graphics.setFont(layout.fontName)
    layout.titleWidth = layout.fontName:getWidth(layout.fullTitleText)
    layout.titleHeight = layout.fontName:getHeight()

    layout.hpBarHeight = 30
    layout.hpBarEmptyVisualHeight = layout.hpBarHeight * 0.2
    layout.nameToBarSpacing = 6
    layout.barToHpTextSpacing = 4

    love.graphics.setFont(layout.fontHPValues)
    layout.hpInfoHeight = layout.fontHPValues:getHeight()

    layout.totalHeight = layout.titleHeight + layout.nameToBarSpacing + layout.hpBarHeight + layout.barToHpTextSpacing +
        layout.hpInfoHeight
end

--- Atualiza a lógica da barra de vida.
---@param dt number Delta time.
function BossHPBar:update(dt)
    -- Atualiza animação de entrada
    if self.animationState ~= "visible" and self.animationState ~= "hidden" then
        self.animationTimer = self.animationTimer + dt
        if self.animationState == "fading_in_text" then
            self.textAlpha = lume.clamp(self.animationTimer / 0.5, 0, 1) * 255
            if self.animationTimer >= 0.5 then
                self.animationState = "fading_in_bar"
                self.animationTimer = 0
            end
        elseif self.animationState == "fading_in_bar" then
            self.barAlpha = lume.clamp(self.animationTimer / 0.5, 0, 1) * 255
            if self.animationTimer >= 0.5 then
                self.animationState = "visible"
                self.animationTimer = 0
            end
        end
    end

    -- Sincroniza HP, mas apenas se a barra estiver visível
    if self.animationState == "visible" then
        if self.boss.currentHealth < self.visualHP and not self.isHPBarAnimatingDown then
            self.isHPBarAnimatingDown = true
            self.hpBarAnimationDownTimer = 0
        elseif self.boss.currentHealth > self.visualHP then
            -- Cura ou aumento de vida, visualHP acompanha instantaneamente
            self.visualHP = self.boss.currentHealth
            self.isHPBarAnimatingDown = false
        end
    end


    -- Animação da "trilha de dano"
    if self.isHPBarAnimatingDown then
        if self.visualHP <= self.boss.currentHealth then
            self.visualHP = self.boss.currentHealth
            self.isHPBarAnimatingDown = false
        else
            self.hpBarAnimationDownTimer = self.hpBarAnimationDownTimer + dt
            if self.hpBarAnimationDownTimer >= self.hpBarAnimationDownDelay then
                local diff = self.visualHP - self.boss.currentHealth
                local decrease = self.hpBarAnimationSpeed * dt
                self.visualHP = self.visualHP - math.min(decrease, diff)
                if self.visualHP <= self.boss.currentHealth then
                    self.visualHP = self.boss.currentHealth
                    self.isHPBarAnimatingDown = false
                end
            end
        end
    end
end

--- Desenha a barra de vida.
function BossHPBar:draw()
    if self.animationState == "hidden" then return end

    local layout = self.internalLayout
    local shadowColor = self.rankColors.text

    -- Desenha o Título
    if self.textAlpha > 0 then
        love.graphics.setFont(layout.fontName)

        -- Sombra do título
        love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], self.textAlpha / 255)
        love.graphics.printf(layout.fullTitleText, self.x - self.width / 2 - 2, self.y - 2, self.width, "center")

        -- Texto principal (branco)
        love.graphics.setColor(1, 1, 1, self.textAlpha / 255)
        love.graphics.printf(layout.fullTitleText, self.x - self.width / 2, self.y, self.width, "center")
    end

    -- Desenha a Barra de Vida
    if self.barAlpha > 0 then
        local barY = self.y + layout.titleHeight + layout.nameToBarSpacing
        local barX = self.x - self.width / 2

        local hpRatio = self.boss.maxHealth > 0 and lume.clamp(self.boss.currentHealth / self.boss.maxHealth, 0, 1) or 0
        local visualHpRatio = self.boss.maxHealth > 0 and lume.clamp(self.visualHP / self.boss.maxHealth, 0, 1) or 0

        -- Mapeia as cores do rank para os conceitos da barra
        local colorFill = self.rankColors.text
        local colorBase = { colorFill[1], colorFill[2], colorFill[3], 0.3 } -- Usa a cor de preenchimento com menos opacidade
        local colorSegment = { 0, 0, 0, 0.5 }                               -- Segmentos pretos semi-transparentes

        -- 1. Desenha a base da barra (fundo/vazio)
        local baseAlpha = (self.barAlpha / 255)
        love.graphics.setColor(colorBase[1], colorBase[2], colorBase[3], baseAlpha)
        local emptyBarY = barY + (layout.hpBarHeight - layout.hpBarEmptyVisualHeight)
        love.graphics.rectangle("fill", barX, emptyBarY, self.width, layout.hpBarEmptyVisualHeight)

        -- 2. Desenha a Trilha de Dano
        if visualHpRatio > hpRatio then
            local trailWidth = (visualHpRatio - hpRatio) * self.width
            love.graphics.setColor(colorFill[1], colorFill[2], colorFill[3], 0.3)
            love.graphics.rectangle("fill", barX + hpRatio * self.width, barY, trailWidth, layout.hpBarHeight)
        end

        -- 3. Desenha o Preenchimento Principal
        if hpRatio > 0 then
            love.graphics.setColor(colorFill[1], colorFill[2], colorFill[3], baseAlpha)
            love.graphics.rectangle("fill", barX, barY, self.width * hpRatio, layout.hpBarHeight)
        end

        -- 4. Desenha os segmentos
        if self.segmentHPInterval and self.segmentHPInterval > 0 and self.boss.maxHealth > 0 then
            love.graphics.setColor(colorSegment[1], colorSegment[2], colorSegment[3], colorSegment[4] * baseAlpha)
            local numSegments = math.floor(self.boss.maxHealth / self.segmentHPInterval)
            for i = 1, numSegments do
                local hpVal = i * self.segmentHPInterval
                if hpVal < self.boss.maxHealth then
                    local segmentX = barX + (hpVal / self.boss.maxHealth) * self.width
                    love.graphics.setLineWidth(2)
                    love.graphics.line(
                        math.floor(segmentX),
                        emptyBarY - (layout.hpBarHeight / 2),
                        math.floor(segmentX),
                        emptyBarY - 1
                    )
                end
            end
        end

        -- 5. Desenha o texto de HP (current/max)
        love.graphics.setFont(layout.fontHPValues)
        local hpInfoText = string.format("%d / %d", math.floor(self.boss.currentHealth + 0.5), self.boss.maxHealth)
        local hpInfoWidth = layout.fontHPValues:getWidth(hpInfoText)
        local hpInfoX = barX + self.width - hpInfoWidth
        local hpInfoY = barY + layout.hpBarHeight + layout.barToHpTextSpacing

        -- Texto principal de HP (Branco)
        love.graphics.setColor(1, 1, 1, baseAlpha)
        love.graphics.print(hpInfoText, hpInfoX, hpInfoY)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function BossHPBar:isFinished()
    return self.boss.shouldRemove or not self.boss.isAlive and self.visualHP <= 0
end

function BossHPBar:getY()
    return self.y
end

function BossHPBar:getHeight()
    return self.internalLayout.totalHeight
end

function BossHPBar:setY(newY)
    self.y = newY
end

return BossHPBar
