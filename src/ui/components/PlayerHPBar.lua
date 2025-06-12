local DamageNumberManager = require("src.managers.damage_number_manager")

---@class PlayerHPBar
---@field x number Posição X do canto superior esquerdo.
---@field y number Posição Y do canto superior esquerdo.
---@field width number Largura total do componente.
---@field height number Altura total do componente (será calculada).
---@field padding table {top, right, bottom, left} Espaçamento interno.
---@field currentHP number HP real e atual do jogador (muda instantaneamente).
---@field visualHP number HP que é visualmente animado para baixo ao perder HP (o "rastro" fica entre este e currentHP).
---@field maxHP number HP máximo do jogador.
---@field hunterName string Nome do caçador.
---@field hunterRank string Ranking do caçador (ex: "S", "A", etc.).
---@field fontName love.Font Fonte para o nome do caçador.
---@field fontRank love.Font Fonte para o texto do ranking.
---@field fontHPValues love.Font Fonte para os textos "HP atual / HP máximo".
---@field fontHPChange love.Font Fonte para o texto de ganho/perda de HP.
---@field colors table Tabela de cores.
---@field colorName table {r,g,b,a} Cor para o nome do caçador.
---@field colorRank table {r,g,b,a} Cor para o texto do ranking.
---@field colorHPValues table {r,g,b,a} Cor para "HP atual / HP máximo".
---@field colorHPChangeGain table {r,g,b,a} Cor para o texto de ganho de HP.
---@field colorHPChangeLoss table {r,g,b,a} Cor para o texto de perda de HP.
---@field colorHPBarBase table {r,g,b,a} Cor da base da barra de HP (fundo/vazio).
---@field colorHPBarFill table {r,g,b,a} Cor do preenchimento da barra de HP.
---@field colorHPBarDamageTrail table {r,g,b,a} Cor para o rastro de dano na barra de HP.
---@field colorSegmentLine table {r,g,b,a} Cor para as linhas de segmento.
---@field hpChangeAnimationQueue table Fila de DADOS para animações de texto +/- HP.
---@field activeTextAnimations table Lista de animações de texto +/- HP ATIVAS e visíveis.
---@field isHPBarAnimatingDown boolean Flag que indica se a visualHP está animando para baixo.
---@field hpBarAnimationDownDelay number Delay para iniciar a animação de descida da barra de HP.
---@field hpBarAnimationDownTimer number Timer para o delay de descida da barra de HP.
---@field hpBarAnimationSpeed number Velocidade com que a visualHP diminui (HP por segundo).
---@field segmentHPInterval number Intervalo de HP para desenhar um segmento vertical.
---@field internalLayout table Armazena posições e dimensões calculadas.
---@field hpChangeAnimationInitialY number Posição Y inicial para as animações de texto.
---@field baseStayDuration number Duração base da fase "parado" da animação de texto.
---@field baseMoveDuration number Duração base da fase "mover e sumir" da animação de texto.
---@field maxQueueForSpeedAdjust number Tamanho da fila para redução máxima do stayDuration.
---@field stayDurationSpeedUpPercentage number Percentual máximo de redução do stayDuration.
local PlayerHPBar = {}
PlayerHPBar.__index = PlayerHPBar

local function parseSpacing(value)
    local spacing = { top = 0, right = 0, bottom = 0, left = 0 }
    if type(value) == "number" then
        spacing.top, spacing.right, spacing.bottom, spacing.left = value, value, value, value
    elseif type(value) == "table" then
        if value.vertical ~= nil or value.horizontal ~= nil then
            local v = value.vertical or 0; local h = value.horizontal or 0
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

--- Cria uma nova PlayerHPBar.
---@param config table Tabela de configuração.
---@param config.x number Posição X.
---@param config.y number Posição Y.
---@param config.w number Largura.
---@param config.hunterName string Nome do caçador.
---@param config.hunterRank string Ranking do caçador.
---@param config.initialHP number HP inicial.
---@param config.initialMaxHP number HP máximo inicial.
---@param config.fontName love.Font Fonte para o nome.
---@param config.fontRank love.Font Fonte para o ranking.
---@param config.fontHPValues love.Font Fonte para os valores de HP.
---@param config.fontHPChange love.Font Fonte para o texto +/- HP.
---@param config.colors table (opcional) Tabela de cores.
---@param config.padding table|number (opcional) Configuração do padding.
---@param config.hpBarAnimationSpeed number (opcional) Velocidade da animação de perda de HP.
---@param config.hpBarAnimationDownDelay number (opcional) Delay para iniciar a animação de perda de HP.
---@param config.segmentHPInterval number (opcional) Intervalo para os segmentos da barra.
---@return PlayerHPBar
function PlayerHPBar:new(config)
    local instance = setmetatable({}, PlayerHPBar)

    instance.x = config.x or 0
    instance.y = config.y or 0
    instance.width = config.w or 250
    instance.padding = parseSpacing(config.padding or { vertical = 8, horizontal = 12 })

    instance.hunterName = config.hunterName or "Player"
    instance.hunterRank = config.hunterRank or "Novato"
    instance.maxHP = config.initialMaxHP or 100
    instance.currentHP = math.min(config.initialHP or instance.maxHP, instance.maxHP) -- HP real
    instance.visualHP = instance
        .currentHP                                                                    -- HP que anima (começa igual ao real)

    instance.fontName = config.fontName or love.graphics.getFont()
    instance.fontRank = config.fontRank or love.graphics.newFont(instance.fontName:getHeight() * 0.7)
    instance.fontHPValues = config.fontHPValues or love.graphics.newFont(instance.fontName:getHeight() * 0.9)
    instance.fontHPChange = config.fontHPChange or instance.fontName

    local defaultColors = {
        name = { 230, 230, 230, 255 },
        rank = { 190, 190, 190, 255 },
        hpValues = { 210, 210, 210, 255 },
        hpChangeGain = { 0, 255, 0, 255 },
        hpChangeLoss = { 255, 0, 0, 255 },
        hpBarBase = { 50, 50, 50, 255 },
        hpBarFill = { 220, 50, 50, 255 },
        hpBarDamageTrail = { 160, 80, 80, 200 }, -- Cor do rastro (entre visualHP e currentHP)
        segmentLine = { 0, 0, 0, 128 }
    }
    instance.colors = {}
    for k, v in pairs(defaultColors) do
        instance.colors[k] = (config.colors and config.colors[k]) or v
    end

    instance.hpChangeAnimationQueue = {}
    instance.activeTextAnimations = {}

    instance.baseStayDuration = 0.8
    instance.baseMoveDuration = 0.6
    instance.maxQueueForSpeedAdjust = 5
    instance.stayDurationSpeedUpPercentage = 0.5

    instance.isHPBarAnimatingDown = false
    instance.hpBarAnimationDownDelay = config.hpBarAnimationDownDelay or 1 -- 1 segundo
    instance.hpBarAnimationDownTimer = 0
    instance.hpBarAnimationSpeed = config.hpBarAnimationSpeed or
        (instance.maxHP * 0.25) -- Velocidade para visualHP seguir currentHP (reduzida)
    instance.segmentHPInterval = config.segmentHPInterval or 0

    instance.internalLayout = {}
    instance.hpChangeAnimationInitialY = 0 -- Será definido em _updateLayout
    instance:_updateLayout()
    instance.height = instance.internalLayout.totalHeight

    return instance
end

function PlayerHPBar:_updateLayout()
    local layout = self.internalLayout
    local contentX = self.x + self.padding.left
    local contentY = self.y + self.padding.top
    local contentWidth = self.width - self.padding.left - self.padding.right
    local currentDrawingY = contentY
    local nameRankSpacing = -2

    love.graphics.setFont(self.fontName)
    layout.hunterNameText = self.hunterName
    layout.hunterNameWidth = self.fontName:getWidth(layout.hunterNameText)
    layout.hunterNameHeight = self.fontName:getHeight()
    layout.hunterNameX = contentX
    layout.hunterNameY = currentDrawingY

    currentDrawingY = currentDrawingY + layout.hunterNameHeight + nameRankSpacing
    love.graphics.setFont(self.fontRank)
    layout.hunterRankText = "Caçador Ranking " .. self.hunterRank
    layout.hunterRankWidth = self.fontRank:getWidth(layout.hunterRankText)
    layout.hunterRankHeight = self.fontRank:getHeight()
    layout.hunterRankX = contentX
    layout.hunterRankY = currentDrawingY

    local leftBlockHeight = (layout.hunterRankY + layout.hunterRankHeight) - layout.hunterNameY

    love.graphics.setFont(self.fontHPValues)
    layout.hpInfoText = string.format("%d / %d", math.floor(self.visualHP + 0.5), self.maxHP)
    layout.hpInfoWidth = self.fontHPValues:getWidth(layout.hpInfoText)
    layout.hpInfoHeight = self.fontHPValues:getHeight()
    layout.hpInfoX = contentX + contentWidth - layout.hpInfoWidth
    layout.hpInfoY = layout.hunterNameY + (leftBlockHeight / 2) - (layout.hpInfoHeight / 2)

    local firstSectionHeight = math.max(leftBlockHeight, layout.hpInfoHeight)
    if layout.hunterNameY + firstSectionHeight < layout.hpInfoY + layout.hpInfoHeight then -- Garante que firstSectionHeight cubra ambos
        firstSectionHeight = (layout.hpInfoY + layout.hpInfoHeight) - layout.hunterNameY
    end

    love.graphics.setFont(self.fontHPChange)
    layout.hpChangeTextHeight = self.fontHPChange:getHeight()
    self.hpChangeAnimationInitialY = layout.hunterNameY + (firstSectionHeight - layout.hpChangeTextHeight) / 2

    local textToBarPadding = 10 -- Aumentado padding entre textos e barra
    currentDrawingY = layout.hunterNameY + firstSectionHeight + textToBarPadding

    layout.hpBarActualFillHeight = 12
    layout.hpBarEmptyVisualHeight = layout.hpBarActualFillHeight * 0.1
    layout.hpBarY = currentDrawingY
    layout.hpBarX = contentX
    layout.hpBarW = contentWidth

    layout.totalHeight = (layout.hpBarY - self.y) + layout.hpBarActualFillHeight + self.padding.bottom
end

--- Atualiza informações base da barra: nome, rank e MaxHP.
--- Re-escala currentHP e visualHP proporcionalmente à mudança de MaxHP.
--- Pode iniciar animação de rastro se MaxHP diminuir e currentHP for cortado.
---@param hunterName string Novo nome do caçador.
---@param hunterRank string Novo rank do caçador.
---@param newMaxHP number Novo MaxHP.
function PlayerHPBar:updateBaseInfo(hunterName, hunterRank, newMaxHP)
    self.hunterName = hunterName or self.hunterName
    self.hunterRank = hunterRank or self.hunterRank
    local oldMaxHP = self.maxHP

    if newMaxHP ~= nil and newMaxHP ~= oldMaxHP then
        self.maxHP = newMaxHP > 0 and newMaxHP or 1

        -- Cap HP atual e visual ao novo MaxHP se MaxHP diminuiu
        self.currentHP = math.min(self.currentHP, self.maxHP)
        self.visualHP = math.min(self.visualHP, self.maxHP)

        if self.visualHP > self.currentHP then
            -- Isso pode acontecer se maxHP diminuiu e cortou currentHP mais do que visualHP,
            -- ou se currentHP já era baixo e visualHP foi apenas limitado pelo novo maxHP.
            self.isHPBarAnimatingDown = true
            self.hpBarAnimationDownTimer = 0
        elseif newMaxHP > oldMaxHP then
            -- Se MaxHP aumentou, e currentHP (que será setado por setCurrentHP em breve) aumentar,
            -- o visualHP deve acompanhar. Por enquanto, se não há rastro, alinha visual com current.
            -- Isso evita que visualHP fique para trás momentaneamente.
            self.visualHP = math.max(self.visualHP, self.currentHP) -- Garante que visual não fique para trás do real.
            self.isHPBarAnimatingDown = false
            self.hpBarAnimationDownTimer = 0
        else
            self.isHPBarAnimatingDown = false
            self.hpBarAnimationDownTimer = 0
        end
    end
    self:_updateLayout()
end

--- Define o HP atual do jogador na barra.
--- A barra decidirá internamente se isso é dano ou cura em relação ao seu self.currentHP,
--- e como animar o visualHP.
---@param newHPValue number O novo valor de HP atual do jogador.
function PlayerHPBar:setCurrentHP(newHPValue)
    newHPValue = math.max(0, math.min(newHPValue, self.maxHP))
    local previousCurrentHP = self.currentHP -- HP real antes da mudança
    local amountChanged = newHPValue - previousCurrentHP

    self.currentHP = newHPValue -- Define o HP real para o novo valor

    if self.currentHP < self.visualHP then
        -- Dano: currentHP desceu abaixo do visualHP (que estava no valor antigo de currentHP)
        -- Ou MaxHP diminuiu, currentHP foi ajustado, e visualHP ainda está alto.
        self.isHPBarAnimatingDown = true
        self.hpBarAnimationDownTimer = 0
        -- Não alteramos visualHP aqui, ele vai animar em update()
    else -- self.currentHP >= self.visualHP
        -- Cura: currentHP subiu, ou ficou igual mas visualHP estava mais baixo (improável com a lógica atual).
        -- Ou MaxHP aumentou e currentHP subiu (via PlayerManager), visualHP deve acompanhar.
        self.visualHP = self.currentHP -- VisualHP acompanha o novo currentHP instantaneamente
        self.isHPBarAnimatingDown = false
        self.hpBarAnimationDownTimer = 0
    end

    if amountChanged ~= 0 then
        self:showHPChangeAnimation(amountChanged)
    end

    self:_updateLayout()
end

function PlayerHPBar:showHPChangeAnimation(amount)
    if amount == 0 then return end
    local newAnimData = {
        -- text = (amount > 0 and "+" or "") .. math.floor(math.abs(amount)),
        text = "" .. math.floor(math.abs(amount)),
        color = amount > 0 and self.colors.hpChangeGain or self.colors.hpChangeLoss,
        deltaY = -25 -- Deslocamento para cima
    }
    table.insert(self.hpChangeAnimationQueue, newAnimData)
end

function PlayerHPBar:update(dt)
    for i = #self.activeTextAnimations, 1, -1 do
        local anim = self.activeTextAnimations[i]
        anim.timer = anim.timer + dt

        if anim.phase == "stay" then
            local queueSizeFactor = math.min(#self.hpChangeAnimationQueue, self.maxQueueForSpeedAdjust) /
                self.maxQueueForSpeedAdjust
            local actualStayDuration = self.baseStayDuration *
                (1 - (queueSizeFactor * self.stayDurationSpeedUpPercentage))

            anim.offsetY = 0
            anim.alpha = 255
            if anim.timer >= actualStayDuration then
                anim.phase = "move"
                anim.timer = 0
                if #self.hpChangeAnimationQueue > 0 then
                    local nextAnimData = table.remove(self.hpChangeAnimationQueue, 1)
                    local newActiveAnim = {
                        text = nextAnimData.text,
                        color = nextAnimData.color,
                        deltaY = nextAnimData.deltaY,
                        timer = 0,
                        alpha = 255,
                        phase = "stay",
                        offsetY = 0
                    }
                    table.insert(self.activeTextAnimations, newActiveAnim)
                end
            end
        elseif anim.phase == "move" then
            local moveProgress = math.min(1, anim.timer / self.baseMoveDuration)
            anim.offsetY = anim.deltaY * moveProgress
            anim.alpha = 255 * (1 - moveProgress)
            if moveProgress >= 1 then
                table.remove(self.activeTextAnimations, i) -- Remove a animação concluída
            end
        end
    end

    if #self.activeTextAnimations == 0 and #self.hpChangeAnimationQueue > 0 then
        local nextAnimData = table.remove(self.hpChangeAnimationQueue, 1)
        local newActiveAnim = {
            text = nextAnimData.text,
            color = nextAnimData.color,
            deltaY = nextAnimData.deltaY,
            timer = 0,
            alpha = 255,
            phase = "stay",
            offsetY = 0
        }
        table.insert(self.activeTextAnimations, newActiveAnim)
    end

    if self.isHPBarAnimatingDown then
        if self.visualHP <= self.currentHP then
            -- Condição para parar a animação é atendida (por exemplo, o jogador se curou enquanto o rastro de dano estava visível)
            self.visualHP = self.currentHP
            self.isHPBarAnimatingDown = false
            self.hpBarAnimationDownTimer = 0
            self:_updateLayout()
        else
            -- Estamos em um estado em que o rastro de dano deve ser mostrado/animado
            self.hpBarAnimationDownTimer = self.hpBarAnimationDownTimer + dt
            if self.hpBarAnimationDownTimer >= self.hpBarAnimationDownDelay then
                -- O atraso terminou, comece a animar
                local diff = self.visualHP - self.currentHP
                local decrease = self.hpBarAnimationSpeed * dt
                self.visualHP = self.visualHP - math.min(decrease, diff)
                if self.visualHP <= self.currentHP then
                    self.visualHP = self.currentHP
                    self.isHPBarAnimatingDown = false
                    self.hpBarAnimationDownTimer = 0
                end
                self:_updateLayout()
            end
        end
    end
end

function PlayerHPBar:draw()
    local layout = self.internalLayout
    local originalFont = love.graphics.getFont()
    local r, g, b, a

    love.graphics.setFont(self.fontName)
    r, g, b, a = unpack(self.colors.name)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.print(layout.hunterNameText, layout.hunterNameX, layout.hunterNameY)

    love.graphics.setFont(self.fontRank)
    r, g, b, a = unpack(self.colors.rank)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.print(layout.hunterRankText, layout.hunterRankX, layout.hunterRankY)

    love.graphics.setFont(self.fontHPValues)
    r, g, b, a = unpack(self.colors.hpValues)
    love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    love.graphics.print(layout.hpInfoText, layout.hpInfoX, layout.hpInfoY)

    local DamageNumberManager = require("src.managers.damage_number_manager")
    for i, anim in ipairs(self.activeTextAnimations) do
        if anim.alpha > 0 then -- Desenha apenas se estiver visível
            local r, g, b = unpack(anim.color);
            local textX = self.x + self.padding.left + (self.internalLayout.hpBarW / 2)
            local textY = self.hpChangeAnimationInitialY + anim.offsetY
            DamageNumberManager:drawText(anim.text, textX, textY, 0.6, { r, g, b }, anim.alpha)
        end
    end

    local currentHPPercentage = 0
    if self.maxHP > 0 then currentHPPercentage = math.max(0, math.min(1, self.currentHP / self.maxHP)) end
    local currentHPFillWidth = layout.hpBarW * currentHPPercentage

    local visualHPPercentage = 0
    if self.maxHP > 0 then visualHPPercentage = math.max(0, math.min(1, self.visualHP / self.maxHP)) end
    local visualHPFillWidth = layout.hpBarW * visualHPPercentage

    r, g, b, a = unpack(self.colors.hpBarBase); love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
    local emptyBarY = layout.hpBarY + (layout.hpBarActualFillHeight - layout.hpBarEmptyVisualHeight)
    love.graphics.rectangle("fill", layout.hpBarX, emptyBarY, layout.hpBarW, layout.hpBarEmptyVisualHeight)

    if self.visualHP > self.currentHP and visualHPFillWidth > currentHPFillWidth then
        local trailWidth = visualHPFillWidth - currentHPFillWidth
        r, g, b, a = unpack(self.colors.hpBarDamageTrail); love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
        love.graphics.rectangle("fill", layout.hpBarX + currentHPFillWidth, layout.hpBarY, trailWidth,
            layout.hpBarActualFillHeight)
    end

    if currentHPFillWidth > 0 then
        r, g, b, a = unpack(self.colors.hpBarFill); love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
        love.graphics.rectangle("fill", layout.hpBarX, layout.hpBarY, currentHPFillWidth, layout.hpBarActualFillHeight)
    end

    if self.segmentHPInterval and self.segmentHPInterval > 0 and self.maxHP > 0 then
        r, g, b, a = unpack(self.colors.segmentLine)
        love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
        local numSegments = math.floor(self.maxHP / self.segmentHPInterval)
        for i = 1, numSegments do
            local hpVal = i * self.segmentHPInterval
            if hpVal < self.maxHP then
                local segmentX = layout.hpBarX + (hpVal / self.maxHP) * layout.hpBarW
                love.graphics.setLineWidth(2)
                love.graphics.line(
                    math.floor(segmentX),
                    emptyBarY - (layout.hpBarActualFillHeight / 2),
                    math.floor(segmentX),
                    emptyBarY + 1
                )
            end
        end
    end

    love.graphics.setFont(originalFont)
    love.graphics.setColor(1, 1, 1, 1)
end

--- Define a largura da barra de HP e recalcula o layout.
---@param newWidth number Nova largura.
function PlayerHPBar:setWidth(newWidth)
    if self.width ~= newWidth then
        self.width = newWidth
        self:_updateLayout()
    end
end

function PlayerHPBar:setHunterName(name)
    if self.hunterName ~= name then
        self.hunterName = name
        self:_updateLayout()
    end
end

function PlayerHPBar:setHunterRank(rank)
    if self.hunterRank ~= rank then
        self.hunterRank = rank
        self:_updateLayout()
    end
end

--- Define a posição da barra de progresso.
---@param x number Nova posição X.
---@param y number Nova posição Y.
function PlayerHPBar:setPosition(x, y)
    self.x = x; self.y = y
    self:_updateLayout()
end

--- Desenha uma versão simplificada da barra de HP sobre uma entidade (ex: jogador).
--- Só desenha se o HP não estiver no máximo.
---@param entityX number Posição X central da entidade.
---@param entityY number Posição Y (topo) da entidade.
---@param isPaused boolean Se o jogo está pausado.
function PlayerHPBar:drawOnPlayer(entityX, entityY, isPaused)
    if self.currentHP >= self.maxHP or isPaused then
        return
    end

    local barWidth = 60
    local barHeight = 5
    local barX = entityX - (barWidth / 2)
    local barY = entityY - barHeight - 40 -- 40 pixels above the entity's top

    -- Percentages
    local currentHPPercentage = self.currentHP / self.maxHP
    local currentHPFillWidth = barWidth * currentHPPercentage

    -- Draw base/background
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

    -- Draw current HP fill
    if currentHPFillWidth > 0 then
        local r, g, b, a = unpack(self.colors.hpBarFill)
        love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
        love.graphics.rectangle("fill", barX, barY, currentHPFillWidth, barHeight)
    end

    local onPlayerAnimBaseY = barY - 25 -- Inicia o texto da animação 5px acima da barra
    for i, anim in ipairs(self.activeTextAnimations) do
        if anim.alpha > 0 then          -- Desenha apenas se estiver visível
            local r, g, b = unpack(anim.color);
            local textX = barX + (barWidth / 2)
            local textY = onPlayerAnimBaseY + anim.offsetY
            DamageNumberManager:drawText(anim.text, textX, textY, 0.5, { r, g, b }, anim.alpha)
        end
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

return PlayerHPBar
