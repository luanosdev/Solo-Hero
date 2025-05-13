local Colors = require("src.ui.colors")
local Camera = require("src.config.camera")
local Fonts = require("src.ui.fonts")

---@class FloatingText
---@field position {x: number, y: number} Posição ATUAL na TELA.
---@field text string O texto a ser exibido.
---@field color {number, number, number, number} Cor do texto {r, g, b, a}.
---@field scale number Escala do texto.
---@field velocityY number Velocidade vertical do movimento (pixels por segundo, negativo para cima).
---@field lifetime number Tempo de vida total do texto em segundos.
---@field currentTime number Tempo atual desde a criação.
---@field alpha number Alpha atual do texto (0-1).
---@field isCritical boolean Se é um hit crítico (para estilização).
---@field currentSpeedFactor number Multiplicador de velocidade atual (para slow motion).
---@field offsetY number Deslocamento vertical ATUAL em pixels de TELA (animado por velocityY).
---@field targetPosition table|nil Referência à tabela de posição do MUNDO do alvo NO MOMENTO DA CRIAÇÃO.
---@field initialDelay number Atraso inicial antes do texto começar a se mover e aparecer.
---@field initialDelayCorrected number Atraso inicial corrigido pelo speedFactor.
---@field initialStackOffsetY number Deslocamento vertical adicional devido ao empilhamento (em pixels de tela).
---@field targetNameForLog string|nil Nome do alvo para logs.
---@field targetEntity table|nil Referência à ENTIDADE ALVO (ex: inimigo, jogador).
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
    targetPosition = nil, -- Posição original do MUNDO
    initialDelay = 0,
    initialDelayCorrected = 0,
    initialStackOffsetY = 0,
    targetNameForLog = "UnknownTarget",
    targetEntity = nil -- << NOVO: Referência à entidade alvo
}

--- Construtor base para FloatingText.
---@param initialScreenPosition {x: number, y: number} Posição inicial já convertida para TELA {x, y}.
---@param text string O conteúdo do texto.
---@param props table Tabela de propriedades (color, scale, velocityY, lifetime, isCritical, baseOffsetY, etc.).
---@param initialWorldPosition table|nil Posição original no MUNDO {x,y} (para referência, se targetEntity for perdido).
---@param initialDelay number Atraso em segundos antes de começar.
---@param initialStackOffsetY number Deslocamento Y de empilhamento (em pixels de tela).
---@param targetNameForLog string Nome do alvo para logs.
---@param targetEntity table|nil A entidade alvo (jogador, inimigo).
function FloatingText:new(initialScreenPosition, text, props, initialWorldPosition, initialDelay, initialStackOffsetY,
                          targetNameForLog, targetEntity)
    local instance = {}
    setmetatable(instance, { __index = self })

    instance.position = { x = initialScreenPosition.x, y = initialScreenPosition.y }
    instance.text = text
    instance.color = props.color or { 1, 1, 1, 1 }
    instance.scale = props.scale or 1
    instance.velocityY = props.velocityY or -50
    instance.lifetime = props.lifetime or 1
    instance.isCritical = props.isCritical or false
    instance.currentSpeedFactor = 1
    instance.currentTime = -(initialDelay or 0)
    instance.initialDelay = initialDelay or 0
    instance.initialDelayCorrected = instance.initialDelay
    instance.offsetY = (props.baseOffsetY or 0) + (initialStackOffsetY or 0)
    instance.targetPosition = initialWorldPosition
    instance.targetEntity = targetEntity
    instance.targetNameForLog = targetNameForLog or (targetEntity and targetEntity.name) or
        (targetEntity and "id_" .. tostring(targetEntity.id)) or "UnknownTarget_FT_New"
    instance.alpha = 1
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

    -- Determinar a posição base na tela a partir do alvo (se houver)
    local baseScreenX, baseScreenY

    if self.targetEntity and self.targetEntity.isAlive and self.targetEntity.position then
        -- Alvo primário: seguir a entidade viva
        baseScreenX, baseScreenY = Camera:worldToScreen(self.targetEntity.position.x, self.targetEntity.position.y)
        -- DEBUG: Log quando segue entidade
        -- print(string.format("[FT:update %s] Following Entity. World (%.2f, %.2f) -> Screen (%.2f, %.2f)", self.targetNameForLog, self.targetEntity.position.x, self.targetEntity.position.y, baseScreenX, baseScreenY))
    elseif self.targetPosition then
        -- Fallback: usar a posição de MUNDO inicial se a entidade não estiver disponível
        baseScreenX, baseScreenY = Camera:worldToScreen(self.targetPosition.x, self.targetPosition.y)
        -- DEBUG: Log quando usa targetPosition (fallback)
        -- print(string.format("[FT:update %s] Fallback to targetPosition. World (%.2f, %.2f) -> Screen (%.2f, %.2f)", self.targetNameForLog, self.targetPosition.x, self.targetPosition.y, baseScreenX, baseScreenY))
    else
        -- Sem alvo: o texto usa sua própria self.position.x como base horizontal
        -- e sua self.position.y (menos o offsetY acumulado) como base vertical.
        -- Isso significa que ele continuará de onde estava na tela.
        baseScreenX = self.position.x
        baseScreenY = self.position.y - self.offsetY -- Remove o offset para adicionar o novo
        -- DEBUG: Log quando estático
        -- print(string.format("[FT:update %s] Static on screen. BaseScreen (%.2f, %.2f)", self.targetNameForLog, baseScreenX, baseScreenY))
    end

    -- Atualiza o deslocamento vertical animado (em pixels de tela)
    self.offsetY = self.offsetY + (self.velocityY * dt * self.currentSpeedFactor)

    -- Define a posição final na tela
    if baseScreenX then
        self.position.x = baseScreenX
    end
    if baseScreenY then
        self.position.y = baseScreenY + self.offsetY
    end
    -- DEBUG: Log da posição final na tela
    -- print(string.format("[FT:update %s] Final screen pos: (%.2f, %.2f). OffsetY: %.2f", self.targetNameForLog, self.position.x, self.position.y, self.offsetY))


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
    local drawY = self.position.y -- self.position.y já inclui o offsetY

    love.graphics.print(self.text, drawX, drawY, 0, self.scale, self.scale)
    love.graphics.pop()

    -- DEBUG: Log de desenho
    -- print(string.format("[FT:draw %s] Drawing at screen: (%.2f, %.2f), Alpha: %.2f, Text: \'%s\'", self.targetNameForLog, drawX, drawY, self.alpha, self.text))
end

--- Cria um texto flutuante para dano em inimigo.
---@param initialScreenPosition {x: number, y: number} Posição inicial na TELA.
---@param text string Texto do dano.
---@param targetEntity table|nil Entidade alvo.
---@param initialDelay number Atraso.
---@param initialStackOffsetY number Deslocamento de empilhamento.
---@param props table Propriedades específicas (deve conter isCritical, e pode sobrescrever color, scale etc. de FloatingText:new).
---@return FloatingText
function FloatingText:newEnemyDamage(initialScreenPosition, text, targetEntity, initialDelay, initialStackOffsetY, props)
    props = props or {}
    local baseProps = {
        color = Colors.damage_enemy,
        scale = 1,
        velocityY = -45,
        lifetime = 0.8,
        isCritical = props.isCritical or false, -- Pega de props se fornecido
        baseOffsetY = -50
    }
    if baseProps.isCritical then
        baseProps.color = Colors.damage_crit
        baseProps.scale = props.scale or 1.3 -- Permite override
        baseProps.lifetime = props.lifetime or 1.1
        baseProps.velocityY = props.velocityY or -55
        baseProps.baseOffsetY = props.baseOffsetY or -55
    end
    -- Mescla props fornecidas com baseProps, dando prioridade às fornecidas
    for k, v in pairs(props) do baseProps[k] = v end

    local worldPos = targetEntity and targetEntity.position
    local nameLog = (targetEntity and targetEntity.name) or (targetEntity and "id_" .. tostring(targetEntity.id))
    return self:new(initialScreenPosition, text, baseProps, worldPos, initialDelay, initialStackOffsetY, nameLog,
        targetEntity)
end

--- Cria um texto flutuante para dano no jogador.
---@param initialScreenPosition {x: number, y: number} Posição inicial na TELA.
---@param text string Texto do dano.
---@param targetEntity table|nil Entidade alvo (o jogador).
---@param initialDelay number Atraso.
---@param initialStackOffsetY number Deslocamento de empilhamento.
---@param props table Propriedades específicas.
---@return FloatingText
function FloatingText:newPlayerDamage(initialScreenPosition, text, targetEntity, initialDelay, initialStackOffsetY, props)
    props = props or {}
    local baseProps = {
        color = Colors.damage_player,
        scale = 1.1,
        velocityY = -40,
        lifetime = 0.9,
        baseOffsetY = -45,
        isCritical = false -- Dano no jogador geralmente não é crítico desta forma
    }
    for k, v in pairs(props) do baseProps[k] = v end
    local worldPos = targetEntity and targetEntity.position
    local nameLog = (targetEntity and targetEntity.name) or (targetEntity and "id_" .. tostring(targetEntity.id))
    return self:new(initialScreenPosition, text, baseProps, worldPos, initialDelay, initialStackOffsetY, nameLog,
        targetEntity)
end

--- Cria um texto flutuante genérico (ex: cura, "MISS", "LVL UP").
---@param initialScreenPosition {x: number, y: number} Posição inicial na TELA.
---@param text string Texto.
---@param targetEntity table|nil Entidade alvo.
---@param initialDelay number Atraso.
---@param initialStackOffsetY number Deslocamento de empilhamento.
---@param props table Propriedades (DEVE conter textColor, pode ter scale, velocityY, etc.).
---@return FloatingText
function FloatingText:newText(initialScreenPosition, text, targetEntity, initialDelay, initialStackOffsetY, props)
    props = props or {}
    local baseProps = {
        color = props.textColor or Colors.floating_text_default, -- Pega de props.textColor
        scale = 1,
        velocityY = -35,
        lifetime = 1.0,
        baseOffsetY = -40,
        isCritical = false
    }
    -- Mescla props específicas (como scale, velocityY etc.) se fornecidas em props
    for k, v in pairs(props) do if k ~= "textColor" then baseProps[k] = v end end

    local worldPos = targetEntity and targetEntity.position
    local nameLog = (targetEntity and targetEntity.name) or (targetEntity and "id_" .. tostring(targetEntity.id))
    return self:new(initialScreenPosition, text, baseProps, worldPos, initialDelay, initialStackOffsetY, nameLog,
        targetEntity)
end

return FloatingText
