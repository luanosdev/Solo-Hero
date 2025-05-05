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
    beamCount = 1,
    glowEffect = true,
    glowTimer = 0,
    animation = nil
}

function DropEntity:new(position, config, beamColor, beamHeight, glowScale, beamCount)
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
    drop.beamCount = beamCount or 1

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
  Função de desenho principal - Refatorada para novos efeitos de feixe
----------------------------------------------------------------------------]]
function DropEntity:draw()
    if self.collected then return end

    if self.collectionProgress > 0 then
        self:_drawCollectionEffect()
    else
        local x, y = self.position.x, self.position.y
        local r, g, b = self.beamColor[1], self.beamColor[2], self.beamColor[3]
        local beamWidth = 2.5 -- Largura do feixe
        local baseBeamHeight = self.beamHeight
        local beamCount = self.beamCount * 2
        local glowTimer = self.glowTimer
        local radius = self.radius

        if beamCount % 2 == 0 and beamCount > 0 then beamCount = beamCount - 1 end
        if beamCount <= 0 then beamCount = 1 end
        local numSideBeamPairs = (beamCount - 1) / 2
        local globalPulse = 0.95 + math.sin(glowTimer * 1.8) * 0.05

        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.scale(1, 0.5) -- Escala isométrica

        -- 1. Desenha os Feixes de Luz (CONTÍNUOS)
        local alphaBase = 0.85 * globalPulse -- Alfa base (um pouco mais opaco)
        local baseSpacing = beamWidth * 0.8  -- Espaçamento base (ajustado)
        local heightReductionFactor = 0.08   -- Redução de altura (ajustado)
        local alphaReductionFactor = 0.15    -- Redução de alfa (ajustado)

        -- Desenha de trás para frente (laterais mais distantes primeiro)
        for pairIndex = numSideBeamPairs, 0, -1 do
            local isCentral = (pairIndex == 0)
            local currentHeight, currentMaxAlpha

            if isCentral then
                currentHeight = baseBeamHeight
                currentMaxAlpha = alphaBase
            else
                currentHeight = baseBeamHeight * (1 - pairIndex * heightReductionFactor)
                currentMaxAlpha = alphaBase * (1 - pairIndex * alphaReductionFactor)
                currentHeight = math.max(currentHeight, baseBeamHeight * 0.15)
                currentMaxAlpha = math.max(currentMaxAlpha, alphaBase * 0.08)
            end

            if currentHeight <= 0 then goto continue_beam_loop end

            -- Desenha o par de feixes laterais (ou o central)
            for beamSide = -1, 1, (isCentral and 2 or 1) do
                if isCentral and beamSide == 1 then goto continue_side_loop end

                local offsetX = 0
                if not isCentral then
                    local tremor = math.sin(glowTimer * 3 + pairIndex * 1.5) * radius * 0.05
                    offsetX = beamSide * (pairIndex * baseSpacing + tremor)
                end

                -- Define a cor base para o retângulo
                local rectR, rectG, rectB
                if isCentral then
                    -- Para o central, podemos usar uma cor média ou a cor da raridade
                    -- Usar branco na base fica complexo sem gradiente real. Usaremos a cor média.
                    rectR = (1 + r) / 2
                    rectG = (1 + g) / 2
                    rectB = (1 + b) / 2
                else
                    rectR, rectG, rectB = r, g, b -- Laterais usam cor da raridade
                end

                -- Define o alfa médio para o retângulo (simples fade out)
                local rectAlpha = currentMaxAlpha * 0.6 -- Alfa médio (ajuste conforme necessário)
                rectAlpha = math.max(0, rectAlpha)

                love.graphics.setColor(rectR, rectG, rectB, rectAlpha)

                -- Desenha o retângulo contínuo
                love.graphics.rectangle(
                    "fill",
                    offsetX - beamWidth / 2, -- X do canto superior esquerdo
                    -currentHeight,          -- Y do canto superior esquerdo
                    beamWidth,               -- Largura
                    currentHeight            -- Altura
                )

                -- Opcional: Desenhar uma linha central mais brilhante para dar definição
                local coreAlpha = currentMaxAlpha *
                    0.5                                                 -- Linha central mais opaca (<<< VALOR ALTERADO DE 0.9)
                local coreR, coreG, coreB = 1, 1, 1                     -- Linha central branca (ou cor da raridade?)
                if not isCentral then coreR, coreG, coreB = r, g, b end -- Laterais usam cor da raridade
                love.graphics.setColor(coreR, coreG, coreB, coreAlpha)
                love.graphics.setLineWidth(beamWidth * 0.4)             -- Linha fina
                love.graphics.line(offsetX, 0, offsetX, -currentHeight) -- Linha do centro
                love.graphics.setLineWidth(1)                           -- Reseta

                ::continue_side_loop::
            end
            ::continue_beam_loop::
        end

        -- 2. Desenha a Onda de Choque na Base
        local shockwaveColor = { r, g, b, 0.6 * globalPulse }
        self:_drawShockwave(shockwaveColor, glowTimer, radius * 1.2, self.glowScale)

        -- 3. Desenha o Item Base (Efeito esfera)
        if self.animation then
            self.animation:draw(0, 0, self.config.rarity)
        else
            love.graphics.setColor(r, g, b, 1 * globalPulse)
            love.graphics.circle("fill", 0, 0, radius)
            love.graphics.setColor(1, 1, 1, 0.75 * globalPulse)
            local highlightRadius = radius * 0.7
            love.graphics.arc("fill", 0, 0, highlightRadius, math.pi * 1.1, math.pi * 1.9, 20)
        end

        love.graphics.pop() -- Restaura transformação
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return DropEntity
