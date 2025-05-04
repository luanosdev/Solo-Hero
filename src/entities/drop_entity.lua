--[[
    Drop Entity
    Representa um item dropado no mundo que pode ser coletado pelo jogador
]]

local runeAnimation = require("src.animations.rune_animation")

local DropEntity = {
    position = {
        x = 0,
        y = 0
    },
    initialPosition = {
        x = 0,
        y = 0
    },
    radius = 10,
    config = nil,
    collected = false,
    collectionProgress = 0,
    collectionSpeed = 3,
    initialY = 0,
    beamColor = { 1, 1, 1 },
    beamHeight = 50,
    glowScale = 1.0,
    glowEffect = true,
    glowTimer = 0,
    animation = nil
}

function DropEntity:new(position, config, beamColor, beamHeight, glowScale)
    local drop = setmetatable({}, { __index = self })
    drop.initialPosition = { x = position.x, y = position.y }
    drop.position = { x = position.x, y = position.y }
    drop.config = config
    drop.collected = false
    drop.collectionProgress = 0
    drop.glowTimer = love.math.random() * 10

    drop.beamColor = beamColor or { 1, 1, 1 }
    drop.beamHeight = beamHeight or 50
    drop.glowScale = glowScale or 1.0

    if config.type == "rune" then
        drop.animation = runeAnimation
    end

    return drop
end

function DropEntity:update(dt, playerManager)
    if self.collected then return true end

    self.glowTimer = self.glowTimer + dt

    if self.animation then
        self.animation:update(dt)
    end

    local dx = playerManager.player.position.x - self.position.x
    local dy = playerManager.player.position.y - self.position.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance <= playerManager.collectionRadius then
        self.collectionProgress = self.collectionProgress + dt * self.collectionSpeed

        local t = math.min(self.collectionProgress, 1)
        local easeOutQuad = 1 - (1 - t) * (1 - t)

        self.position.x = self.initialPosition.x +
            (playerManager.player.position.x - self.initialPosition.x) * easeOutQuad
        self.position.y = self.initialPosition.y +
            (playerManager.player.position.y - self.initialPosition.y) * easeOutQuad

        if self.collectionProgress >= 1 then
            self.collected = true
            return true
        end
    end

    return false
end

--[[--------------------------------------------------------------------------
  Função auxiliar para desenhar a onda de choque na base do drop (Isométrica)
----------------------------------------------------------------------------]]
function DropEntity:_drawShockwave(color, glowTimer, baseRadius, glowScale)
    local shockwaveDuration = 1.5   -- Duração da animação da onda (segundos)
    local progress = math.fmod(glowTimer, shockwaveDuration) / shockwaveDuration
    local maxRadiusMultiplier = 2.0 -- O quão maior a onda fica em relação ao raio base
    -- Aumenta o raio MÍNIMO para a onda não desaparecer completamente
    local currentRadius = baseRadius * 0.3 + baseRadius * (progress * (maxRadiusMultiplier - 0.3))
    local alpha = color[4] or 0.6                   -- Usa alfa da cor base ou um padrão
    local currentAlpha = alpha * (1 - progress ^ 2) -- Fade out
    local thickness = 3 * (1 - progress) + 1

    -- Ajusta o brilho geral da onda com glowScale (afetando o alfa)
    currentAlpha = currentAlpha * glowScale

    if currentRadius > baseRadius * 0.1 and currentAlpha > 0.05 then -- Evita desenhar no início/fim
        love.graphics.setColor(color[1], color[2], color[3], currentAlpha)
        love.graphics.setLineWidth(thickness)
        -- Desenha em (0,0) pois estamos no espaço transformado
        love.graphics.circle("line", 0, 0, currentRadius, 32)
        love.graphics.setLineWidth(1)
    end
end

--[[--------------------------------------------------------------------------
  Função auxiliar para desenhar o efeito durante a coleta (Esfera + Rastro)
----------------------------------------------------------------------------]]
function DropEntity:_drawCollectionEffect()
    local x, y = self.position.x, self.position.y
    local initialX, initialY = self.initialPosition.x, self.initialPosition.y
    local r, g, b = self.beamColor[1], self.beamColor[2], self.beamColor[3]

    -- 1. Desenha o Rastro
    local trailAlpha = 0.3 * (1 - self.collectionProgress) -- Rastro some conforme chega perto
    if trailAlpha > 0.05 then
        love.graphics.setColor(r, g, b, trailAlpha)
        love.graphics.setLineWidth(3) -- Largura do rastro
        love.graphics.line(initialX, initialY, x, y)
        love.graphics.setLineWidth(1)
    end

    -- 2. Desenha a Esfera Pulsante
    local pulse = (1 + math.sin(self.glowTimer * 5) * 0.15)                        -- Fator de pulsação (mais rápido)
    local sphereRadius = self.radius * pulse * (1 + self.collectionProgress * 0.5) -- Aumenta um pouco ao coletar
    local sphereAlpha = 0.8 + math.sin(self.glowTimer * 5) * 0.2
    sphereAlpha = math.max(0.5, math.min(1, sphereAlpha))                          -- Garante um alfa mínimo

    -- Desenha a esfera externa (cor principal)
    love.graphics.setColor(r, g, b, sphereAlpha)
    love.graphics.circle("fill", x, y, sphereRadius)

    -- Desenha um núcleo interno mais brilhante
    love.graphics.setColor(1, 1, 1, sphereAlpha * 0.8) -- Branco com alfa ligeiramente menor
    love.graphics.circle("fill", x, y, sphereRadius * 0.6)
end

--[[--------------------------------------------------------------------------
  Função de desenho principal - Decide qual efeito mostrar
----------------------------------------------------------------------------]]
function DropEntity:draw()
    if self.collected then return end

    -- Verifica se está no processo de coleta
    if self.collectionProgress > 0 then
        self:_drawCollectionEffect()
    else
        -- Se não estiver coletando, desenha o efeito no chão (Feixe + Onda + Base)
        local x, y = self.position.x, self.position.y
        local r, g, b = self.beamColor[1], self.beamColor[2], self.beamColor[3]
        local beamWidth = 4

        -- Aplica transformação isométrica para tudo no chão
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(1, 0.5)

        -- 1. Desenha o Feixe de Luz (Vertical no espaço escalado)
        local segments = 5
        local heightStep = self.beamHeight / segments
        local alphaBase = 0.8
        local alphaStep = alphaBase / segments

        love.graphics.setLineWidth(beamWidth)
        for i = 0, segments - 1 do
            local startY = -(i * heightStep)
            local endY = -((i + 1) * heightStep)
            local startX = 0
            local endX = 0
            local currentAlpha = alphaBase - (i * alphaStep)
            love.graphics.setColor(r, g, b, currentAlpha)
            love.graphics.line(startX, startY, endX, endY)
        end
        love.graphics.setLineWidth(1)

        -- 2. Desenha a Onda de Choque na Base (SUBSTITUI o glowEffect anterior)
        -- Usa a cor do feixe com um alfa base para a onda
        local shockwaveColor = { r, g, b, 0.6 }
        -- O raio base da onda pode ser um pouco maior que o raio do item
        -- Passa glowScale para ajustar a intensidade da onda
        self:_drawShockwave(shockwaveColor, self.glowTimer, self.radius * 1.2, self.glowScale)

        -- 3. Desenha o Item Base (Círculo ou Animação)
        if self.animation then
            -- A animação deve ser desenhada no espaço transformado (0,0)
            -- Pode precisar de ajustes de escala/posição internos se a animação não for afetada pelo scale global
            self.animation:draw(0, 0, self.config.rarity)
        else
            -- Desenha os círculos base em (0,0) no espaço transformado
            love.graphics.setColor(r, g, b, 1)
            love.graphics.circle("fill", 0, 0, self.radius)

            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.circle("fill", 0, 0, self.radius * 0.6)
        end

        love.graphics.pop() -- Restaura transformação
    end

    -- Reseta a cor padrão globalmente
    love.graphics.setColor(1, 1, 1, 1)
end

return DropEntity
