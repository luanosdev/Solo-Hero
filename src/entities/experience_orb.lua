--[[
    Experience Orb
    Representa um orbe de experiência que pode ser coletado pelo jogador
]]

local ManagerRegistry = require("src.managers.manager_registry")

local ExperienceOrb = {
    position = {
        x = 0,
        y = 0
    },
    initialPosition = {
        x = 0,
        y = 0
    },
    radius = 5,
    experience = 0,
    color = { 0.5, 0, 0.5 }, -- Cor roxa base
    collected = false,
    collectionProgress = 0,  -- Progresso da animação de coleta (0 a 1)
    collectionSpeed = 0.05,  -- Velocidade da animação
    initialX = 0,            -- Posição X inicial
    initialY = 0,            -- Posição Y inicial

    -- Novas propriedades para animação
    levitationHeight = 5,   -- Altura máxima da levitação
    levitationSpeed = 2,    -- Velocidade da levitação
    levitationTime = 0,     -- Timer para a animação de levitação
    flameParticles = {},    -- Partículas da chama
    maxFlameParticles = 8,  -- Número máximo de partículas
    particleLifetime = 0.5, -- Tempo de vida das partículas
}

function ExperienceOrb:new(x, y, exp)
    local orb = setmetatable({}, { __index = self })
    orb.initialPosition = {
        x = x,
        y = y
    }
    orb.position = orb.initialPosition
    orb.experience = exp
    orb.collected = false
    orb.collectionProgress = 0
    orb.levitationTime = math.random() * math.pi * 2 -- Inicia em um ponto aleatório da animação
    orb.flameParticles = {}
    return orb
end

function ExperienceOrb:update(dt)
    if self.collected then return end

    -- Atualiza a animação de levitação
    self.levitationTime = self.levitationTime + dt * self.levitationSpeed
    local levitationOffset = math.sin(self.levitationTime) * self.levitationHeight

    -- Atualiza as partículas da chama
    for i = #self.flameParticles, 1, -1 do
        local particle = self.flameParticles[i]
        particle.lifetime = particle.lifetime - dt
        particle.y = particle.y - dt * 20        -- Move para cima
        particle.alpha = particle.alpha - dt * 2 -- Fade out

        if particle.lifetime <= 0 then
            table.remove(self.flameParticles, i)
        end
    end

    -- Adiciona novas partículas se necessário
    if #self.flameParticles < self.maxFlameParticles then
        local angle = math.random() * math.pi * 2
        local distance = math.random() * self.radius * 0.5
        table.insert(self.flameParticles, {
            x = math.cos(angle) * distance,
            y = math.sin(angle) * distance,
            lifetime = self.particleLifetime,
            alpha = 1,
            size = math.random(2, 4)
        })
    end

    local playerManager = ManagerRegistry:get("playerManager") ---@type PlayerManager

    -- Calcula a distância até o jogador
    local dx = playerManager.player.position.x - self.position.x
    local dy = playerManager.player.position.y - (self.position.y + levitationOffset)
    local distance = math.sqrt(dx * dx + dy * dy)

    local currentFinalStats = playerManager:getCurrentFinalStats()
    -- Se estiver dentro do raio de coleta do jogador
    if distance <= currentFinalStats.pickupRadius then
        -- Considera o toque se a distância for menor/igual ao raio do orbe
        local immediateCollectionThreshold = self.radius
        if distance <= immediateCollectionThreshold then
            self.collected = true
            return true
        end

        -- Inicia a animação de coleta
        self.collectionProgress = self.collectionProgress + dt * self.collectionSpeed

        -- Atualiza a posição do orbe
        local t = math.min(self.collectionProgress, 1) -- Garante que t não exceda 1
        -- Função de easing para movimento suave
        local easeOutQuad = 1 - (1 - t) * (1 - t)

        -- Atualiza a posição com a animação
        self.position.x = self.initialPosition.x +
            (playerManager.player.position.x - self.initialPosition.x) * easeOutQuad
        self.position.y = self.initialPosition.y +
            (playerManager.player.position.y - self.initialPosition.y) * easeOutQuad

        -- Se a animação terminou
        if self.collectionProgress >= 1 then
            self.collected = true
            return true
        end
    end

    return false
end

--- Função auxiliar para desenhar o efeito durante a coleta (Rastro + Orbe)
function ExperienceOrb:_drawCollectionEffect()
    local x, y = self.position.x, self.position.y
    local initialX, initialY = self.initialPosition.x, self.initialPosition.y
    local r, g, b = self.color[1], self.color[2], self.color[3] -- Usa a cor do orbe

    -- 1. Desenha o Rastro
    local trailAlpha = 0.5 * (1 - self.collectionProgress) -- Rastro some conforme chega perto (0.5 de alfa máx)
    if trailAlpha > 0.05 then
        love.graphics.setColor(r, g, b, trailAlpha)
        love.graphics.setLineWidth(3) -- Largura do rastro
        love.graphics.line(initialX, initialY, x, y)
        love.graphics.setLineWidth(1)
    end

    -- 2. Desenha o Orbe (simplificado durante a coleta, sem levitação/partículas complexas)
    -- Pode ajustar isso se quiser manter mais efeitos visuais durante a coleta
    local currentRadius = self.radius *
        (1 + self.collectionProgress * 0.3) -- Aumenta um pouco ao coletar
    local currentAlpha = 0.8 +
        math.sin(self.levitationTime * 5) *
        0.2                                                                                       -- Leve pulsação no alfa
    currentAlpha = math.max(0.6, math.min(1, currentAlpha)) * (1 - self.collectionProgress * 0.5) -- Fade out leve

    -- Desenha o orbe principal
    love.graphics.setColor(r, g, b, currentAlpha)
    love.graphics.circle("fill", x, y, currentRadius)

    -- Desenha o brilho interno
    love.graphics.setColor(1, 1, 1, currentAlpha * 0.6) -- Branco com alfa ajustado
    love.graphics.circle("fill", x, y, currentRadius * 0.7)
end

function ExperienceOrb:draw()
    if self.collected then return end

    if self.collectionProgress > 0 then
        -- Desenha o efeito de coleta (rastro + orbe simplificado)
        self:_drawCollectionEffect()
    else
        -- Desenho normal quando não está sendo coletado
        local levitationOffset = math.sin(self.levitationTime) * self.levitationHeight

        -- Desenha a sombra
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.circle("fill", self.position.x, self.position.y + 3, self.radius * 0.8)

        -- Desenha as partículas da chama
        for _, particle in ipairs(self.flameParticles) do
            love.graphics.setColor(0.2, 0.6, 1, particle.alpha) -- Cor azul para a chama
            love.graphics.circle("fill",
                self.position.x + particle.x,
                self.position.y + particle.y + levitationOffset,
                particle.size
            )
        end

        -- Desenha o orbe principal
        love.graphics.setColor(self.color)
        love.graphics.circle("fill", self.position.x, self.position.y + levitationOffset, self.radius)

        -- Desenha o brilho interno
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.circle("fill", self.position.x, self.position.y + levitationOffset, self.radius * 0.7)

        -- Desenha o brilho externo (aura)
        love.graphics.setColor(0.2, 0.6, 1, 0.3) -- Cor azul para a aura
        love.graphics.circle("fill", self.position.x, self.position.y + levitationOffset, self.radius * 1.5)
    end
    love.graphics.setColor(1, 1, 1, 1) -- Reseta a cor no final
end

return ExperienceOrb
