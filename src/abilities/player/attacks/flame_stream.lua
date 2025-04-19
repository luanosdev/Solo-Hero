--[[----------------------------------------------------------------------------
    Flame Stream Ability
    Gerencia a criação de um fluxo contínuo de partículas de fogo.
----------------------------------------------------------------------------]]--
local FireParticle = require("src.projectiles.fire_particle") -- Precisaremos criar este arquivo

local FlameStream = {}

-- Configurações
FlameStream.name = "Fluxo de Chamas"
FlameStream.description = "Cria um fluxo de partículas de fogo."
FlameStream.damageType = "fire" -- Se tiver tipos de dano
FlameStream.visual = {
    preview = {
        active = false,
        lineLength = 50
    },
    attack = {
        particleSpeed = 150, -- Velocidade lenta das partículas
        particleLifetime = 1.2 -- Tempo de vida base (será calculado a partir do range)
    }
}

function FlameStream:init(playerManager)
    self.playerManager = playerManager
    self.cooldownRemaining = 0
    self.activeParticles = {} -- Tabela para guardar as partículas ativas

    -- Cores
    self.visual.preview.color = self.previewColor or {1, 0.5, 0, 0.2}
    self.visual.attack.color = self.attackColor or {1, 0.3, 0, 0.7}

    -- Atributos da arma
    local weapon = self.playerManager.equippedWeapon
    self.area = {
        position = {x = 0, y = 0}, -- Posição do jogador
        angle = 0,                -- Ângulo da mira
        range = weapon.range + self.playerManager.state:getTotalRange(), -- Distância/Alcance das partículas
        angleWidth = weapon.angle + self.playerManager.state:getTotalArea() -- Dispersão do fluxo
    }
    self.baseDamage = weapon.damage
    self.baseCooldown = weapon.cooldown

    -- Calcula o tempo de vida baseado no range e velocidade
    self.visual.attack.particleLifetime = self.area.range / self.visual.attack.particleSpeed
    
    self.area.position = self.playerManager.player.position
end

function FlameStream:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza posição, ângulo e parâmetros da área
    if self.area then
        self.area.position = self.playerManager.player.position
        self.area.angle = angle
        -- Recalcula range e largura com bônus atuais
        local weapon = self.playerManager.equippedWeapon
        self.area.range = weapon.range + self.playerManager.state:getTotalRange()
        self.area.angleWidth = weapon.angle + self.playerManager.state:getTotalArea()
        -- Recalcula tempo de vida se o range mudar
        self.visual.attack.particleLifetime = self.area.range / self.visual.attack.particleSpeed
    end

    -- Atualiza as partículas ativas
    for i = #self.activeParticles, 1, -1 do
        local particle = self.activeParticles[i]
        particle:update(dt)
        if not particle.isActive then 
            table.remove(self.activeParticles, i)
        end
    end
end

function FlameStream:cast() -- Cast é chamado muito rapidamente
    if self.cooldownRemaining > 0 then
        return false
    end

    -- Aplica cooldown (já é muito baixo)
    local attackSpeed = self.playerManager.state:getTotalAttackSpeed()
    self.cooldownRemaining = self.baseCooldown / attackSpeed 

    -- Calcula atributos no momento do disparo
    local damagePerParticle = self.playerManager.state:getTotalDamage(self.baseDamage)
    local criticalChance = self.playerManager.state:getTotalCriticalChance()
    local criticalMultiplier = self.playerManager.state:getTotalCriticalMultiplier()
    
    -- Calcula o ângulo da partícula com uma pequena dispersão aleatória dentro de angleWidth
    local halfWidth = self.area.angleWidth / 2
    local currentAngle = self.area.angle + math.random() * halfWidth - math.random() * halfWidth

    -- Calcula se é crítico (por partícula)
    local isCritical = math.random() * 100 <= criticalChance
    local damage = damagePerParticle
    if isCritical then
        damage = math.floor(damage * criticalMultiplier)
    end

    -- Calcula a posição inicial da partícula (à frente do jogador, na borda do raio)
    local startDist = self.playerManager.radius * 1.2
    local startX = self.area.position.x + math.cos(currentAngle) * startDist
    local startY = self.area.position.y + math.sin(currentAngle) * startDist

    -- Cria a partícula de fogo a partir da posição inicial calculada
    local particle = FireParticle:new(
        startX, startY, -- Usa as coordenadas iniciais calculadas
        currentAngle,
        self.visual.attack.particleSpeed,
        self.visual.attack.particleLifetime, 
        damage,
        isCritical,
        self.playerManager.enemyManager, 
        self.visual.attack.color
        -- Poderíamos adicionar pierce count aqui se quiséssemos
    )
    table.insert(self.activeParticles, particle)
    
    -- Multi-ataque para lança-chamas? Poderia disparar 2 partículas de uma vez?
    -- Por simplicidade, vamos ignorar multi-ataque por enquanto, a alta cadência já faz o trabalho.

    return true
end

function FlameStream:draw()
    if not self.area then return end

    -- Desenha a prévia (um cone estreito)
    if self.visual.preview.active then
        self:drawPreviewCone(self.visual.preview.color)
    end

    -- Desenha as partículas ativas
    for _, particle in ipairs(self.activeParticles) do
        particle:draw()
    end
end

function FlameStream:drawPreviewCone(color)
    local segments = 16
    love.graphics.setColor(color)
    local cx, cy = self.area.position.x, self.area.position.y
    local range = self.area.range -- Usa o alcance das partículas para o tamanho do cone
    local startAngle = self.area.angle - self.area.angleWidth / 2
    local endAngle = self.area.angle + self.area.angleWidth / 2

    love.graphics.arc("line", "open", cx, cy, range, startAngle, endAngle, segments)
    love.graphics.line(cx, cy, cx + range * math.cos(startAngle), cy + range * math.sin(startAngle))
    love.graphics.line(cx, cy, cx + range * math.cos(endAngle), cy + range * math.sin(endAngle))
end

function FlameStream:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

function FlameStream:togglePreview()
    self.visual.preview.active = not self.visual.preview.active
end

function FlameStream:getPreview()
    return self.visual.preview.active
end

return FlameStream 