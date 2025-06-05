---@class ProgressLevelBar
---@field x number Posição X do canto superior esquerdo.
---@field y number Posição Y do canto superior esquerdo.
---@field width number Largura total do componente.
---@field height number Altura total do componente (pode ser calculada).
---@field padding table {top, right, bottom, left} Espaçamento interno.
---@field realXP number XP real/lógico atual do jogador.
---@field displayXP number XP visualmente exibido pela barra principal.
---@field trailTargetXP number XP alvo para o rastro/buffer.
---@field maxXP number XP necessário para o próximo nível.
---@field currentLevel number Nível atual do jogador.
---@field xpForNextLevelFunc function Função que calcula o XP para o próximo nível. Recebe o nível atual e retorna o XP necessário.
-- Elementos de texto (vamos usar LÖVE Font e print/printf)
---@field fontMain love.Font Fonte principal para os textos.
---@field fontLevelNumber love.Font Fonte para o número do nível.
---@field fontXpGain love.Font Fonte para o texto de ganho de XP.
---@field fontLevelUp love.Font Fonte para o texto "LEVEL UP!".
-- Cores (exemplo, ajuste conforme seu sistema de cores)
---@field colorLevelText table {r, g, b, a} Cor para "LEVEL".
---@field colorLevelNumber table {r, g, b, a} Cor para o número do nível.
---@field colorXpText table {r, g, b, a} Cor para "XP atual / XP máxima".
---@field colorProgressBarBase table {r, g, b, a} Cor da base da barra de progresso (linha branca).
---@field colorProgressBarFill table {r, g, b, a} Cor do preenchimento da barra de progresso.
---@field colorXpGainText table {r, g, b, a} Cor para o texto de ganho de XP.
---@field colorLevelUpText table {r, g, b, a} Cor para o texto "LEVEL UP!".
---@field colorTrailBar table {r, g, b, a} Cor para o rastro da barra de XP.
-- Animação de ganho de XP
---@field xpGainAnimation table { active, duration, progress, text, currentY, initialY, deltaY, alpha }
---@field levelUpAnimation table { active, stayDuration, moveDuration, timer, text, currentY, initialY, deltaY, alpha, phase }
---@field trailDecayFactor number Fator de decaimento do rastro por segundo.
---@field isBarAnimating boolean Flag para controlar a animação de preenchimento da barra.
---@field barFillSpeed number Velocidade de preenchimento da barra (XP por segundo).
-- Variáveis de layout interno
---@field internalLayout table Armazena posições e dimensões calculadas dos elementos internos.
local ProgressLevelBar = {}
ProgressLevelBar.__index = ProgressLevelBar

--- Função helper para parsear padding, similar à de Component.lua mas local.
local function parseSpacing(value)
    local spacing = { top = 0, right = 0, bottom = 0, left = 0 }
    if type(value) == "number" then
        spacing.top, spacing.right, spacing.bottom, spacing.left = value, value, value, value
    elseif type(value) == "table" then
        if value.vertical ~= nil or value.horizontal ~= nil then
            local v = value.vertical or 0
            local h = value.horizontal or 0
            spacing.top, spacing.right, spacing.bottom, spacing.left = v, h, v, h
        else
            spacing.top = value.top or value[1] or 0
            spacing.right = value.right or value[2] or value.left or value[1] or 0
            spacing.bottom = value.bottom or value[3] or value.top or value[1] or 0
            spacing.left = value.left or value[4] or value.right or value[2] or 0
        end
    end
    return spacing
end

--- Cria uma nova ProgressLevelBar.
---@param config table Tabela de configuração.
---@param config.x number Posição X.
---@param config.y number Posição Y.
---@param config.w number Largura.
---@param config.h number Altura (opcional, será calculada se não fornecida).
---@param config.fontMain love.Font Fonte principal.
---@param config.fontLevelNumber love.Font Fonte para o número do nível.
---@param config.fontXpGain love.Font Fonte para o texto de ganho de XP.
---@param config.fontLevelUp love.Font Fonte para o texto "LEVEL UP!".
---@param config.initialLevel number Nível inicial.
---@param config.initialXP number XP inicial.
---@param config.xpForNextLevel function Função que retorna o XP para o próximo nível.
---@param config.padding table|number Configuração do padding.
---@param config.colors table Tabela de cores (opcional, com defaults).
---@param config.trailDecayFactor number Fator de decaimento do rastro por segundo (opcional, default 2.0).
---@param config.barFillSpeed number Velocidade de preenchimento da barra (XP por segundo) (opcional, default 100).
---@return ProgressLevelBar
function ProgressLevelBar:new(config)
    local instance = setmetatable({}, ProgressLevelBar)

    instance.x = config.x or 0
    instance.y = config.y or 0
    instance.width = config.w or 200 -- Largura padrão

    instance.fontMain = config.fontMain or love.graphics.getFont()
    instance.fontLevelNumber = config.fontLevelNumber or love.graphics.getFont() -- Idealmente uma fonte maior/diferente
    instance.fontXpGain = config.fontXpGain or instance.fontMain
    instance.fontLevelUp = config.fontLevelUp or instance.fontMain               -- Fonte para LEVEL UP!

    instance.currentLevel = config.initialLevel or 1
    instance.realXP = config.initialXP or 0
    instance.displayXP = instance.realXP     -- Inicialmente, displayXP = realXP
    instance.trailTargetXP = instance.realXP -- Inicialmente, trailTargetXP = realXP

    instance.isBarAnimating = false
    instance.barFillSpeed = config.barFillSpeed or 100 -- Ex: 100 XP por segundo de preenchimento

    instance.xpForNextLevelFunc = config.xpForNextLevel or function(level) return level * 100 + 50 end
    instance.maxXP = instance.xpForNextLevelFunc(instance.currentLevel)

    instance.padding = parseSpacing(config.padding or { vertical = 5, horizontal = 10 })

    local defaultColors = {
        levelText = { 200, 200, 200, 255 },       -- Cinza claro
        levelNumber = { 255, 100, 100, 255 },     -- Vermelho/Laranja da imagem
        xpText = { 180, 180, 180, 255 },          -- Cinza um pouco mais escuro
        progressBarBase = { 220, 220, 220, 255 }, -- Quase branco
        progressBarFill = { 255, 80, 80, 255 },   -- Vermelho/Laranja da imagem
        xpGainText = { 50, 205, 50, 255 },        -- Verde para ganho de XP (LimeGreen)
        levelUpText = { 255, 255, 255, 255 },     -- Branco para LEVEL UP!
        trailBar = { 255, 150, 150, 200 },        -- Laranja/Vermelho claro para o rastro
    }
    instance.colors = {}
    for k, v in pairs(defaultColors) do
        instance.colors[k] = config.colors and config.colors[k] or v
    end

    instance.xpGainAnimation = {
        active = false,
        stayDuration = 1.0, -- Duração da fase "parado"
        moveDuration = 0.8, -- Duração da fase "movimento e fade"
        timer = 0,          -- Timer geral da animação
        text = "",
        currentY = 0,
        initialY = 0,  -- Será calculado no updateLayout
        deltaY = -20,  -- Deslocamento vertical durante a fase de movimento
        alpha = 0,
        phase = "stay" -- pode ser "stay" ou "move"
    }

    instance.levelUpAnimation = {
        active = false,
        stayDuration = 1.0,
        moveDuration = 0.8,
        timer = 0,
        text = "LEVEL UP!", -- Texto fixo
        currentY = 0,
        initialY = 0,
        deltaY = -20,
        alpha = 0,
        phase = "stay"
    }

    instance.internalLayout = {} -- Será preenchido por _updateLayout
    instance:_updateLayout()     -- Calcula layout inicial e altura se necessário

    -- Se a altura não foi fornecida, calcula com base no layout
    if config.h == nil or config.h == 0 then
        instance.height = instance.internalLayout.totalHeight
    else
        instance.height = config.h
    end

    ---@type ProgressLevelBar
    return instance
end

--- Atualiza o layout dos elementos internos. Chamado quando necessário.
function ProgressLevelBar:_updateLayout()
    local layout = self.internalLayout

    local contentX = self.x + self.padding.left
    local contentY = self.y + self.padding.top
    local contentWidth = self.width - self.padding.left - self.padding.right
    -- contentHeight não é usado diretamente para definir posições, mas para calcular a altura total

    local currentDrawingY = contentY -- Posição Y inicial para desenhar as linhas
    local lineSpacing = 5            -- Espaçamento entre as linhas de texto e a barra

    -- Linha para "LEVEL UP!" (se ativa, ou para cálculo de altura)
    love.graphics.setFont(self.fontLevelUp)
    layout.levelUpTextHeight = self.fontLevelUp:getHeight()
    layout.levelUpTextWidth = self.fontLevelUp:getWidth(self.levelUpAnimation.text)

    -- Posição do texto "LEVEL UP!"
    layout.levelUpTextX = contentX + (contentWidth - layout.levelUpTextWidth) / 2 -- Centralizado
    layout.levelUpTextY = currentDrawingY
    self.levelUpAnimation.initialY = layout.levelUpTextY                          -- Define initialY para a animação

    currentDrawingY = currentDrawingY + layout.levelUpTextHeight + lineSpacing

    -- Linha 1: "LEVEL", Número, "XP/MAX"
    layout.levelLabelText = "LEVEL"
    local tempFont = love.graphics.getFont()
    love.graphics.setFont(self.fontMain)
    layout.levelLabelWidth = self.fontMain:getWidth(layout.levelLabelText)
    layout.levelLabelHeight = self.fontMain:getHeight()

    love.graphics.setFont(self.fontLevelNumber)
    layout.levelNumberText = tostring(self.currentLevel)
    layout.levelNumberWidth = self.fontLevelNumber:getWidth(layout.levelNumberText)
    layout.levelNumberHeight = self.fontLevelNumber:getHeight()

    love.graphics.setFont(self.fontMain)                                                 -- Reverte para a fonte principal para o texto de XP e para o XP GAIN
    layout.xpInfoText = string.format("%d / %d", math.floor(self.displayXP), self.maxXP) -- Usa displayXP para o texto
    layout.xpInfoWidth = self.fontMain:getWidth(layout.xpInfoText)
    layout.xpInfoHeight = self.fontMain:getHeight()

    layout.xpGainTextHeight = self.fontXpGain:getHeight() -- Altura do texto de ganho de XP

    local firstLineMaxHeight = math.max(layout.levelLabelHeight, layout.levelNumberHeight, layout.xpInfoHeight,
        layout.xpGainTextHeight)
    layout.firstLineY = currentDrawingY -- << ATUALIZADO: Y da primeira linha agora considera a linha "LEVEL UP!" acima

    -- Posicionamento Linha 1
    layout.levelLabelX = contentX
    layout.levelLabelY = layout.firstLineY + (firstLineMaxHeight - layout.levelLabelHeight) / 2

    layout.levelNumberX = layout.levelLabelX + layout.levelLabelWidth + 5 -- 5px de espaçamento
    layout.levelNumberY = layout.firstLineY + (firstLineMaxHeight - layout.levelNumberHeight) / 2

    layout.xpInfoX = contentX + contentWidth - layout.xpInfoWidth
    layout.xpInfoY = layout.firstLineY + (firstLineMaxHeight - layout.xpInfoHeight) / 2

    -- Centro da primeira linha para animação de XP
    -- A posição Y inicial do texto de ganho de XP será alinhada com os outros textos da primeira linha.
    self.xpGainAnimation.initialY = layout.firstLineY + (firstLineMaxHeight - layout.xpGainTextHeight) / 2

    -- Linha 2: Barra de Progresso
    layout.fillBarHeight = 6                                                   -- Altura da parte preenchida da barra
    layout.emptyBarHeight = layout.fillBarHeight *
        0.6                                                                    -- Altura da parte vazia (ex: 60% da preenchida)

    layout.progressBarY = layout.firstLineY + firstLineMaxHeight + lineSpacing -- << ATUALIZADO: Y da barra de progresso
    layout.progressBarX = contentX
    layout.progressBarW = contentWidth

    -- A altura total do componente agora considera a maior das alturas da barra
    layout.totalHeight = (layout.progressBarY - self.y) + layout.fillBarHeight + self.padding.bottom
end

--- Adiciona XP e atualiza a barra.
---@param amount number Quantidade de XP a ser adicionada.
function ProgressLevelBar:addXP(amount)
    local originalAmount = amount -- Guarda a quantidade original de XP adicionada
    if amount == 0 then return end

    -- XP real é atualizado
    self.realXP = self.realXP + amount
    self.trailTargetXP = self.realXP -- O rastro/buffer salta para o novo XP real ANTES do level up
    -- Se houver level up, trailTargetXP será ajustado novamente.

    self:showXPGainAnimation((originalAmount > 0 and "+" or "") .. originalAmount)
    self.isBarAnimating = false -- Barra não começa a animar até o texto +XP se mover

    local leveledUp = false
    while self.realXP >= self.maxXP do
        self.realXP = self.realXP - self.maxXP
        self.currentLevel = self.currentLevel + 1
        self.maxXP = self.xpForNextLevelFunc(self.currentLevel)
        leveledUp = true
        self:showLevelUpAnimation()
        self.trailTargetXP = self.realXP -- Após level up, o alvo do rastro é o XP residual
        -- O displayXP eventualmente alcançará este novo trailTargetXP (que é o realXP)
    end

    if leveledUp or amount ~= 0 then
        self:_updateLayout() -- Recalcula layout se textos de nível/maxXP mudarem
    end
end

--- Mostra a animação de ganho de XP.
---@param text string Texto a ser exibido (ex: "+50").
function ProgressLevelBar:showXPGainAnimation(text)
    local anim = self.xpGainAnimation
    anim.text = text
    anim.active = true
    anim.timer = 0                -- Reseta o timer da animação
    anim.alpha = 255              -- Começa totalmente visível
    anim.currentY = anim.initialY -- Posição Y inicial
    anim.phase = "stay"           -- Começa na fase "parado"

    -- Força _updateLayout para garantir que o texto de ganho de XP seja medido e posicionado corretamente, se necessário
    self:_updateLayout()
end

--- Mostra a animação de "LEVEL UP!".
function ProgressLevelBar:showLevelUpAnimation()
    local anim = self.levelUpAnimation
    anim.active = true
    anim.timer = 0
    anim.alpha = 255
    anim.currentY = anim.initialY
    anim.phase = "stay"
    self:_updateLayout() -- Garante que as posições estejam corretas
end

--- Atualiza o estado do componente.
---@param dt number Delta time.
function ProgressLevelBar:update(dt)
    if self.xpGainAnimation.active then
        local anim = self.xpGainAnimation
        anim.timer = anim.timer + dt

        if anim.phase == "stay" then
            anim.currentY = anim.initialY -- Mantém Y fixo
            anim.alpha = 255
            if anim.timer >= anim.stayDuration then
                anim.phase = "move"        -- Transita para a fase de movimento
                anim.timer = 0             -- Reseta o timer para a nova fase
                self.isBarAnimating = true -- << SINALIZA PARA BARRA COMEÇAR A ANIMAR
            end
        elseif anim.phase == "move" then
            local moveProgress = math.min(1, anim.timer / anim.moveDuration)
            anim.currentY = anim.initialY + (anim.deltaY * moveProgress) -- Interpola Y
            anim.alpha = 255 * (1 - moveProgress)                        -- Fade out

            if moveProgress >= 1 then
                anim.active = false -- Termina a animação
            end
        end
    else
        -- Garante que o texto não seja visível se a animação não estiver ativa
        local anim = self.xpGainAnimation
        anim.alpha = 0
    end

    -- Atualiza animação de LEVEL UP!
    if self.levelUpAnimation.active then
        local anim = self.levelUpAnimation
        anim.timer = anim.timer + dt

        if anim.phase == "stay" then
            anim.currentY = anim.initialY
            anim.alpha = 255
            if anim.timer >= anim.stayDuration then
                anim.phase = "move"
                anim.timer = 0
            end
        elseif anim.phase == "move" then
            local moveProgress = math.min(1, anim.timer / anim.moveDuration)
            anim.currentY = anim.initialY + (anim.deltaY * moveProgress)
            anim.alpha = 255 * (1 - moveProgress)

            if moveProgress >= 1 then
                anim.active = false
            end
        end
    else
        local anim = self.levelUpAnimation
        anim.alpha = 0
    end

    -- Atualiza o preenchimento animado da barra de XP (displayXP)
    if self.isBarAnimating then
        if self.displayXP < self.trailTargetXP then
            local diff = self.trailTargetXP - self.displayXP
            local increase = self.barFillSpeed * dt
            self.displayXP = self.displayXP + math.min(increase, diff) -- Evita ultrapassar
            if self.displayXP >= self.trailTargetXP then
                self.displayXP = self.trailTargetXP                    -- Garante valor exato
                self.isBarAnimating = false
            end
            self:_updateLayout()        -- Atualiza o texto "XP/MAX" que usa displayXP
        else
            self.isBarAnimating = false -- Já alcançou ou ultrapassou (caso de setLevel)
        end
    end

    -- Se não estiver animando e displayXP for diferente de trailTargetXP (ex: após setLevel)
    if not self.isBarAnimating and self.displayXP ~= self.trailTargetXP then
        if self.displayXP > self.trailTargetXP then -- Apenas ajusta para baixo imediatamente
            self.displayXP = self.trailTargetXP
            self:_updateLayout()
        end
        -- Se displayXP < trailTargetXP e não está animando, fica esperando o sinal da animação do texto.
    end
end

--- Desenha o componente.
function ProgressLevelBar:draw()
    local layout = self.internalLayout
    local originalFont = love.graphics.getFont()
    local r, g, b, a

    -- Linha 1
    -- "LEVEL"
    love.graphics.setFont(self.fontMain)
    r, g, b, a = unpack(self.colors.levelText)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.print(layout.levelLabelText, layout.levelLabelX, layout.levelLabelY)

    -- Número do Nível
    love.graphics.setFont(self.fontLevelNumber)
    r, g, b, a = unpack(self.colors.levelNumber)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.print(layout.levelNumberText, layout.levelNumberX, layout.levelNumberY)

    -- "XP atual / XP máxima"
    love.graphics.setFont(self.fontMain)
    r, g, b, a = unpack(self.colors.xpText)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.print(layout.xpInfoText, layout.xpInfoX, layout.xpInfoY)

    -- Desenha texto "LEVEL UP!" se ativo
    if self.levelUpAnimation.active or self.levelUpAnimation.alpha > 0 then
        local anim = self.levelUpAnimation
        love.graphics.setFont(self.fontLevelUp)
        r, g, b, baseAlpha = unpack(self.colors.levelUpText)
        love.graphics.setColor(r / 255, g / 255, b / 255, (baseAlpha / 255) * (anim.alpha / 255))
        love.graphics.print(anim.text, math.floor(layout.levelUpTextX), math.floor(anim.currentY))
    end

    -- Linha 2: Barra de Progresso
    local displayProgressPercentage = 0
    if self.maxXP > 0 then
        displayProgressPercentage = math.max(0, math.min(1, self.displayXP / self.maxXP))
    end
    local displayFillWidth = layout.progressBarW * displayProgressPercentage

    local trailProgressPercentage = 0
    if self.maxXP > 0 then
        trailProgressPercentage = math.max(0, math.min(1, self.trailTargetXP / self.maxXP))
    end
    local trailFillWidth = layout.progressBarW * trailProgressPercentage

    -- Desenha a parte de FUNDO/VAZIA primeiro, com altura menor e centralizada
    local emptyPartX = layout.progressBarX
    local emptyPartW = layout.progressBarW
    local emptyPartY = layout.progressBarY + (layout.fillBarHeight - layout.emptyBarHeight) / 2

    if emptyPartW > 0 then
        r, g, b, a = unpack(self.colors.progressBarBase)
        love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
        love.graphics.rectangle("fill", emptyPartX, emptyPartY, emptyPartW, layout.emptyBarHeight)
    end

    -- Desenha o RASTRO/BUFFER (diferença entre trailTargetXP e displayXP)
    if self.trailTargetXP > self.displayXP and trailFillWidth > displayFillWidth then
        local rastroWidth = trailFillWidth - displayFillWidth
        r, g, b, a = unpack(self.colors.trailBar)
        love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
        love.graphics.rectangle("fill", layout.progressBarX + displayFillWidth, layout.progressBarY, rastroWidth,
            layout.fillBarHeight)
    end

    -- Desenha a parte PREENCHIDA (displayXP)
    if displayFillWidth > 0 then
        r, g, b, a = unpack(self.colors.progressBarFill)
        love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
        love.graphics.rectangle("fill", layout.progressBarX, layout.progressBarY, displayFillWidth, layout.fillBarHeight)
    end

    -- Animação de Ganho de XP
    if self.xpGainAnimation.active or self.xpGainAnimation.alpha > 0 then -- Desenha se ativo ou ainda desaparecendo
        local anim = self.xpGainAnimation
        love.graphics.setFont(self.fontXpGain)                            -- Usa a fonte definida para o texto de ganho de XP
        r, g, b, baseAlpha = unpack(self.colors.xpGainText)
        love.graphics.setColor(r / 255, g / 255, b / 255, (baseAlpha / 255) * (anim.alpha / 255))

        local textWidth = self.fontXpGain:getWidth(anim.text)
        local textX = self.x + self.padding.left + ((self.width - self.padding.left - self.padding.right) / 2) -
            (textWidth / 2)
        love.graphics.print(anim.text, math.floor(textX), math.floor(anim.currentY))
    end

    love.graphics.setFont(originalFont) -- Restaura a fonte original
    love.graphics.setColor(1, 1, 1, 1)  -- Restaura a cor padrão
end

--- Define o nível atual do jogador.
--- Útil para carregar o estado do jogo.
---@param level number Novo nível.
---@param currentXPInNewLevel number XP atual neste novo nível (opcional, default 0).
function ProgressLevelBar:setLevel(level, currentXPInNewLevel)
    self.currentLevel = level
    self.realXP = currentXPInNewLevel or 0
    self.displayXP = self.realXP     -- Sincronia imediata para setLevel
    self.trailTargetXP = self.realXP -- Sincronia imediata
    self.maxXP = self.xpForNextLevelFunc(self.currentLevel)
    self.isBarAnimating = false      -- Para qualquer animação de barra pendente
    self:_updateLayout()
end

--- Define a posição da barra de progresso.
---@param x number Nova posição X.
---@param y number Nova posição Y.
function ProgressLevelBar:setPosition(x, y)
    local dx = x - self.x
    local dy = y - self.y
    self.x = x
    self.y = y
    -- Atualiza posições internas baseadas no delta para não recalcular tudo se não for necessário
    -- No entanto, _updateLayout é mais seguro se as dimensões puderem mudar ou se for mais simples
    self:_updateLayout()
end

--- Define a largura da barra de progresso.
---@param w number Nova largura.
function ProgressLevelBar:setWidth(w)
    if self.width ~= w then
        self.width = w
        self:_updateLayout()
    end
end

return ProgressLevelBar
