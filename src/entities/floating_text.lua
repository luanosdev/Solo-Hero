local Fonts = require("src.ui.fonts")

---@class FloatingText
---@field position {x: number, y: number} Posição ATUAL na TELA.
---@field text string O texto a ser exibido.
---@field color {r: number, g: number, b: number, a: number} Cor do texto.
---@field scale number Escala do texto.
---@field velocityY number Velocidade vertical do movimento (pixels por segundo, negativo para cima).
---@field lifetime number Tempo de vida total do texto em segundos.
---@field currentTime number Tempo atual desde a criação.
---@field alpha number Alpha atual do texto (0-1).
---@field isCritical boolean Se é um hit crítico (para estilização).
---@field currentSpeedFactor number Multiplicador de velocidade atual (para slow motion).
---@field offsetY number Deslocamento vertical ATUAL em pixels de TELA (animado por velocityY).
---@field initialDelay number Atraso inicial antes do texto começar a se mover e aparecer.
---@field initialDelayCorrected number Atraso inicial corrigido pelo speedFactor.
---@field initialStackOffsetY number Deslocamento vertical adicional devido ao empilhamento (em pixels de tela).
local FloatingText = {
    position = {
        x = 0,
        y = 0
    },
    text = "",
    color = { 1, 1, 1, 1 },
    scale = 1,
    velocityY = -50,
    lifetime = 1,
    currentTime = 0,
    alpha = 1,
    isCritical = false,
    currentSpeedFactor = 1,
    offsetY = 0,
    initialDelay = 0,
    initialDelayCorrected = 0,
    initialStackOffsetY = 0
}

--- Construtor base para FloatingText.
---@param initialScreenPosition {x: number, y: number} Posição inicial já convertida para TELA {x, y}.
---@param text string O conteúdo do texto.
---@param props table Tabela de propriedades (color, scale, velocityY, lifetime, isCritical, baseOffsetY, baseOffsetX, etc.).
---@param initialDelay number Atraso em segundos antes de começar.
---@param initialStackOffsetY number Deslocamento Y de empilhamento (em pixels de tela).
function FloatingText:new(initialScreenPosition, text, props, initialDelay, initialStackOffsetY)
    local instance = {}
    setmetatable(instance, { __index = self })

    instance.position = {
        x = initialScreenPosition.x + (props.baseOffsetX or 0),
        -- Aplica os offsets base e de stack diretamente à posição Y inicial do mundo.
        -- Assume que baseOffsetY e initialStackOffsetY são valores do mundo.
        y = initialScreenPosition.y + (props.baseOffsetY or 0) + (initialStackOffsetY or 0)
    }
    instance.text = text
    instance.color = props.textColor or props.color or { 1, 1, 1, 1 } -- Adicionado props.textColor como fallback
    instance.scale = props.scale or 1
    instance.velocityY = props.velocityY or -50
    instance.lifetime = props.lifetime or 1
    instance.isCritical = props.isCritical or false
    instance.currentSpeedFactor = 1
    instance.currentTime = -(initialDelay or 0)            -- Começa negativo para representar o delay
    instance.initialDelay = initialDelay or 0
    instance.initialDelayCorrected = instance.initialDelay -- Será ajustado por speedFactor se necessário
    instance.initialStackOffsetY = initialStackOffsetY or 0

    -- offsetY agora só contém o stackOffsetY, pois baseOffsetY já foi aplicado à posição.
    -- Este offsetY será o ponto de partida para a animação de velocityY.
    instance.offsetY = instance.initialStackOffsetY

    instance.alpha = 1 -- Começa totalmente visível (se não houver delay)
    return instance
end

--- Atualiza o estado do texto flutuante (posição, alfa, tempo de vida).
---@param dt number Delta time.
---@return boolean Retorna false se o texto deve ser removido, true caso contrário.
function FloatingText:update(dt)
    self.currentTime = self.currentTime + (dt * self.currentSpeedFactor)

    if self.currentTime < 0 then -- Ainda no delay inicial (currentTime começou negativo)
        return true              -- Continua vivo, mas não faz nada
    end

    -- A posição X base é a posição X inicial.
    -- A posição Y base é a posição Y inicial menos o offsetY total (que inclui baseOffsetY e initialStackOffsetY).
    -- Em seguida, o offsetY animado é aplicado.
    local baseScreenYInitial = self.position.y -
        self
        .offsetY -- Reverte o offsetY atual para obter a base Y original da tela

    -- Atualiza o deslocamento vertical animado (em pixels de tela)
    self.offsetY = self.offsetY + (self.velocityY * dt * self.currentSpeedFactor)

    -- Define a posição final na tela
    -- self.position.x permanece o mesmo (a menos que props.velocityX seja adicionado no futuro)
    self.position.y = baseScreenYInitial + self.offsetY

    -- Atualiza alfa baseado no tempo de vida
    -- O tempo de vida começa a contar APÓS o initialDelay (currentTime >= 0)
    local lifetimeProgress = self.currentTime / self.lifetime
    if lifetimeProgress >= 1 then
        self.alpha = 0
        return false                    -- Marca para remoção
    elseif lifetimeProgress >= 0.7 then -- Começa a desaparecer nos últimos 30%
        self.alpha = 1 - ((lifetimeProgress - 0.7) / 0.3)
    else
        self.alpha = 1
    end
    self.alpha = math.max(0, math.min(1, self.alpha)) -- Garante que alfa esteja entre 0 e 1

    return true                                       -- Continua vivo
end

--- Desenha o texto flutuante.
function FloatingText:draw()
    if self.alpha <= 0 then return end -- Não desenha se invisível

    love.graphics.push()
    love.graphics.setFont(Fonts.main)
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)

    -- Centraliza o texto horizontalmente
    local textWidth = Fonts.main:getWidth(self.text)
    local drawX = self.position.x - (textWidth * self.scale / 2)
    -- self.position.y já foi atualizado em update() para incluir o offsetY correto
    local drawY = self.position.y

    love.graphics.print(self.text, drawX, drawY, 0, self.scale, self.scale)
    love.graphics.pop()
end

return FloatingText
