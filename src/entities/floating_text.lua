local Colors = require("src.ui.colors")

---@class FloatingText
---@field position table Posição {x, y} do texto.
---@field text string O texto a ser exibido.
---@field color table A cor do texto {r, g, b}.
---@field alpha number A transparência do texto (0-1).
---@field scale number A escala do texto.
---@field velocityY number A velocidade vertical do movimento do texto.
---@field lifetime number O tempo de vida total do texto em segundos.
---@field currentTime number O tempo decorrido desde a criação ou desde o fim do delay.
---@field isCritical boolean Se o texto representa um acerto crítico.
---@field targetPosition table|nil Referência à tabela de posição do alvo (ex: inimigo.position).
---@field offsetY number Deslocamento vertical inicial em relação ao alvo.
---@field initialDelay number Atraso inicial antes do texto começar a se mover e aparecer.
---@field initialStackOffsetY number Deslocamento vertical adicional devido ao empilhamento.
local FloatingText = {
    position = {
        x = 0,
        y = 0
    },
    text = "",
    color = { 1, 1, 1 },
    alpha = 1,
    scale = 1,
    velocityY = -20,
    lifetime = 0.5,
    currentTime = 0,
    isCritical = false,
    targetPosition = nil,
    offsetY = 0,
    initialDelay = 0,
    initialStackOffsetY = 0
}

--- Construtor base para FloatingText.
--- Geralmente chamado pelas funções helper como :newPlayerDamage, etc.
---@param initialPosition {x: number, y: number} Posição inicial {x, y}.
---@param text string O texto a ser exibido.
---@param targetPosition table|nil Referência à tabela de posição do alvo.
---@param props table Tabela de propriedades contendo: color, scale, velocityY, lifetime, isCritical, initialDelay, initialStackOffsetY, baseOffsetY.
---@return FloatingText
function FloatingText:new(initialPosition, text, targetPosition, props)
    local floatingText = setmetatable({}, { __index = self })
    floatingText.position = { x = initialPosition.x, y = initialPosition.y }
    floatingText.text = text
    floatingText.targetPosition = targetPosition

    floatingText.color = props.color or { 1, 1, 1 }
    floatingText.scale = props.scale or 1
    floatingText.velocityY = props.velocityY or -20
    floatingText.lifetime = props.lifetime or 0.5
    floatingText.isCritical = props.isCritical or false
    floatingText.initialDelay = props.initialDelay or 0
    floatingText.initialStackOffsetY = props.initialStackOffsetY or 0

    floatingText.currentTime = -floatingText.initialDelay                                -- Começa com o delay
    floatingText.offsetY = (props.baseOffsetY or -20) - floatingText.initialStackOffsetY -- Aplica stack offset
    floatingText.alpha = 1                                                               -- Começa totalmente visível (após delay)

    return floatingText
end

--- Cria um texto flutuante para dano causado a um inimigo.
---@param initialPosition {x: number, y: number} Posição inicial {x, y}.
---@param text string O texto do dano.
---@param isCritical boolean Se o dano é crítico.
---@param targetPosition table|nil Referência à tabela de posição do inimigo.
---@param initialDelay number|nil Atraso inicial opcional.
---@param initialStackOffsetY number|nil Deslocamento de empilhamento opcional.
---@return FloatingText
function FloatingText:newEnemyDamage(initialPosition, text, isCritical, targetPosition, initialDelay, initialStackOffsetY)
    local props = {
        color = Colors.damage_enemy,
        scale = 1,
        velocityY = -30,
        lifetime = 0.7,
        isCritical = isCritical,
        initialDelay = initialDelay,
        initialStackOffsetY = initialStackOffsetY,
        baseOffsetY = -60
    }
    if isCritical then
        props.color = Colors.damage_crit
        props.scale = 1.8
        props.velocityY = -70
        props.lifetime = 1.1
        text = text .. "!"
    end
    return self:new(initialPosition, text, targetPosition, props)
end

--- Cria um texto flutuante para dano recebido pelo jogador.
---@param initialPosition {x: number, y: number} Posição inicial {x, y}.
---@param text string O texto do dano.
---@param isCritical boolean Se o dano é crítico (geralmente não aplicável a dano recebido, mas incluído por consistência).
---@param targetPosition table|nil Referência à tabela de posição do jogador.
---@param initialDelay number|nil Atraso inicial opcional.
---@param initialStackOffsetY number|nil Deslocamento de empilhamento opcional.
---@return FloatingText
function FloatingText:newPlayerDamage(
    initialPosition,
    text,
    isCritical,
    targetPosition,
    initialDelay,
    initialStackOffsetY
)
    local props = {
        color = Colors.damage_player,
        scale = 1.2,
        velocityY = -35,
        lifetime = 1.5,
        isCritical = isCritical, -- Pode ser usado para destacar certos tipos de dano recebido
        initialDelay = initialDelay,
        initialStackOffsetY = initialStackOffsetY,
        baseOffsetY = -70 -- Um pouco mais acima para o jogador
    }
    if isCritical then
        props.scale = 1.5
        props.velocityY = -50
        props.lifetime = 1.2
    end
    return self:new(initialPosition, text, targetPosition, props)
end

--- Cria um texto flutuante para cura recebida pelo jogador.
---@param initialPosition {x: number, y: number} Posição inicial {x, y}.
---@param text string O texto da cura.
---@param targetPosition table|nil Referência à tabela de posição do jogador.
---@param initialDelay number|nil Atraso inicial opcional.
---@param initialStackOffsetY number|nil Deslocamento de empilhamento opcional.
---@return FloatingText
function FloatingText:newPlayerHeal(initialPosition, text, targetPosition, initialDelay, initialStackOffsetY)
    local props = {
        color = Colors.heal,
        scale = 1.3,
        velocityY = -25,
        lifetime = 1.0,
        isCritical = false,
        initialDelay = initialDelay,
        initialStackOffsetY = initialStackOffsetY,
        baseOffsetY = -25
    }
    return self:new(initialPosition, text, targetPosition, props)
end

--- Creates a floating text for a collected item.
--- The text color will be based on the item's rarity.
---@param initialPosition {x: number, y: number} Initial position {x, y}.
---@param itemName string The name of the item.
---@param itemRarity string The item's rarity (e.g., "S", "A", "Common", as defined in Colors.rarity).
---@param targetPosition table|nil Reference to the target's position table (optional, if the text should follow something).
---@param initialDelay number|nil Optional initial delay.
---@param initialStackOffsetY number|nil Optional stacking offset.
---@return FloatingText
function FloatingText:newItemCollectedText(
    initialPosition,
    itemName,
    itemRarity,
    targetPosition,
    initialDelay,
    initialStackOffsetY
)
    local itemColor = Colors.rarity[itemRarity] or Colors.text_default -- Default color if rarity not found

    local props = {
        color = itemColor,
        scale = 1.1,
        velocityY = -15, -- Slightly slower upward movement
        lifetime = 1.2,  -- A bit more time on screen
        isCritical = false,
        initialDelay = initialDelay,
        initialStackOffsetY = initialStackOffsetY,
        baseOffsetY = -70 -- Initial position slightly above the collection point
    }
    return self:new(initialPosition, itemName, targetPosition, props)
end

--- Atualiza o estado do texto flutuante.
---@param dt number O tempo delta desde a última atualização.
---@return boolean Retorna true se o texto ainda está ativo, false caso contrário.
function FloatingText:update(dt)
    self.currentTime = self.currentTime + dt

    if self.currentTime < 0 then -- Ainda no delay inicial
        return true              -- Continua vivo, mas não faz nada
    end

    -- Atualiza posição baseado no alvo, se houver
    if self.targetPosition then
        self.position.x = self.targetPosition.x
        self.position.y = self.targetPosition.y + self.offsetY
    end

    -- Atualiza offset vertical (movimento para cima)
    -- Apenas começa a mover e a contar a vida útil após o delay
    self.offsetY = self.offsetY + self.velocityY * dt

    -- Atualiza transparência para fade out
    -- O fade começa baseado no lifetime efetivo (após o delay)
    local effectiveLifetime = self.lifetime
    local fadeStartRatio = 0.7                                     -- Começa a desaparecer nos últimos 30% do tempo de vida efetivo
    local fadeStartTime = effectiveLifetime * (1 - fadeStartRatio) -- Tempo em que o fade começa

    -- O tempo de vida atual é self.currentTime, que começou a contar a partir de 0 após o delay.
    if self.currentTime > fadeStartTime then
        self.alpha = math.max(0, 1 - ((self.currentTime - fadeStartTime) / (effectiveLifetime - fadeStartTime)))
    else
        self.alpha = 1
    end

    -- Retorna true se ainda está dentro do lifetime efetivo
    return self.currentTime < effectiveLifetime
end

--- Desenha o texto flutuante.
function FloatingText:draw()
    if self.currentTime < 0 then -- Não desenha se estiver no delay
        return
    end

    love.graphics.push()
    love.graphics.translate(self.position.x, self.position.y)
    love.graphics.scale(self.scale, self.scale)

    local font = love.graphics.getFont()
    local textWidth = font:getWidth(self.text)
    -- local textHeight = font:getHeight() -- Descomente se precisar do textHeight para centralização vertical mais precisa

    -- Desenha a borda preta
    love.graphics.setColor(0, 0, 0, self.alpha * 0.8) -- Borda um pouco mais sutil
    local outlineOffset = 1                           -- Ajuste para o tamanho da borda
    love.graphics.print(self.text, -textWidth / 2 + outlineOffset, outlineOffset)
    love.graphics.print(self.text, -textWidth / 2 - outlineOffset, outlineOffset)
    love.graphics.print(self.text, -textWidth / 2 + outlineOffset, -outlineOffset)
    love.graphics.print(self.text, -textWidth / 2 - outlineOffset, -outlineOffset)
    love.graphics.print(self.text, -textWidth / 2 + outlineOffset, 0)
    love.graphics.print(self.text, -textWidth / 2 - outlineOffset, 0)
    love.graphics.print(self.text, -textWidth / 2, outlineOffset)
    love.graphics.print(self.text, -textWidth / 2, -outlineOffset)

    -- Desenha o texto principal
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.alpha)
    love.graphics.print(self.text, -textWidth / 2, 0) -- Centralizado horizontalmente, Y=0 no ponto de origem do texto

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1) -- Reseta a cor global
end

return FloatingText
