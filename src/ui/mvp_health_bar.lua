local Colors = require("src.ui.colors")
local Fonts = require("src.ui.fonts")
local Camera = require("src.config.camera")

---@class MvpHealthBar
local MvpHealthBar = {
    isVisible = false,
    target = nil, -- O inimigo MVP
    width = 400,
    height = 20,
    nameHeight = 25,
    yOffset = 30, -- Distância do topo da tela
}

function MvpHealthBar:init()
    self.isVisible = false
    self.target = nil
    -- Carregar fontes, se ainda não foram carregadas
    Fonts.load()
end

--- Mostra a barra de vida para um alvo MVP específico.
---@param mvpTarget BaseEnemy
function MvpHealthBar:show(mvpTarget)
    if not mvpTarget or not mvpTarget.isMVP then
        -- Esconde a barra se o alvo for inválido
        self:hide()
        return
    end
    self.target = mvpTarget
    self.isVisible = true
end

function MvpHealthBar:hide()
    self.isVisible = false
    self.target = nil
end

function MvpHealthBar:update(dt)
    if not self.isVisible or not self.target or not self.target.isAlive then
        self:hide()
    end
end

function MvpHealthBar:draw()
    -- A barra principal fixa no topo não é mais necessária.
    -- Toda a lógica de desenho agora está em drawOnMvp.
end

--- Desenha uma versão simplificada da barra de HP sobre o MVP.
---@param entityX number Posição X central da entidade na tela.
---@param entityY number Posição Y (topo) da entidade na tela.
function MvpHealthBar:drawOnMvp(entityX, entityY)
    if not self.isVisible or not self.target then
        return
    end

    -- Configurações
    local barWidth = 120
    local barHeight = 8
    local nameToBarSpacing = 6 -- Espaço entre o texto e a barra

    -- Informações de Rank e Cor
    local titleData = self.target.mvpTitleData
    local rank = titleData and titleData.rank or "E"
    local rankColors = Colors.rankDetails[rank] or Colors.rankDetails["E"]

    -- 1. Preparar texto e fonte
    local fullName = string.format("%s, %s", self.target.mvpProperName, titleData.name)
    love.graphics.setFont(Fonts.main_large)
    local font = love.graphics.getFont()

    -- 2. Calcular a altura exata do texto, considerando a quebra de linha
    local widestLine, wrappedLines = font:getWrap(fullName, barWidth)
    local textHeight = #wrappedLines * font:getHeight()

    -- 3. Calcular o posicionamento vertical de forma coesa
    -- Define um espaço fixo acima do sprite do inimigo
    local spaceAboveSprite = 15
    -- Encontra o topo do sprite do inimigo
    local spriteTopY = entityY - (self.target.radius or 32)

    -- A barra de vida é posicionada primeiro, abaixo do topo do sprite
    local barY = spriteTopY - spaceAboveSprite - barHeight

    -- O texto é posicionado acima da barra de vida
    local textY = barY - nameToBarSpacing - textHeight

    -- Posição X (horizontal)
    local barX = entityX - (barWidth / 2)
    local nameX = barX -- `printf` usa a borda esquerda para o alinhamento centralizado

    -- 4. Desenhar o Nome (primeiro para ficar no fundo)
    love.graphics.setColor(rankColors.gradientStart)
    love.graphics.printf(fullName, nameX + 1, textY + 1, barWidth, "center")
    love.graphics.setColor(rankColors.text)
    love.graphics.printf(fullName, nameX, textY, barWidth, "center")

    -- 5. Desenhar a Barra de Vida (na frente do texto, se houver sobreposição acidental)
    local healthRatio = self.target.currentHealth / self.target.maxHealth
    healthRatio = math.max(0, math.min(1, healthRatio))
    local currentHPFillWidth = barWidth * healthRatio

    -- Fundo da barra
    love.graphics.setColor(Colors.bar_bg[1], Colors.bar_bg[2], Colors.bar_bg[3], 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)

    -- Preenchimento da vida
    if currentHPFillWidth > 0 then
        love.graphics.setColor(unpack(Colors.hp_fill))
        love.graphics.rectangle("fill", barX, barY, currentHPFillWidth, barHeight)
    end

    -- Borda
    love.graphics.setLineWidth(1)
    love.graphics.setColor(unpack(Colors.bar_border))
    love.graphics.rectangle("line", barX, barY, barWidth, barHeight)

    -- Resetar cor
    love.graphics.setColor(Colors.white)
end

return MvpHealthBar
