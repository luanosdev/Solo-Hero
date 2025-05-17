--[[
    Aura Ability
    Uma aura que causa dano aos inimigos próximos periodicamente
]]

local Aura = {}
Aura.__index = Aura -- Para permitir que instâncias herdem métodos

-- Propriedades padrão da classe
Aura.defaultDamagePerTick = 80
Aura.defaultTickInterval = 1.0
Aura.defaultRadius = 100
Aura.defaultColor = { 0.8, 0, 0.8, 0.03 } -- Cor roxa suave para a aura base
Aura.defaultPulseDuration = 0.3
Aura.defaultShockwaveDuration = 0.5
Aura.defaultShockwaveThickness = 4
Aura.defaultShockwaveParticleCount = 32
Aura.defaultShockwaveParticleSize = 3

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- Construtor para uma instância da habilidade da Aura.
--- @param playerManager PlayerManager Instância do gerenciador do jogador.
--- @param runeItemData table Dados da instância do item da runa.
--- @return table Instância da habilidade da runa.
function Aura:new(playerManager, runeItemData)
    local instance = setmetatable({}, self)

    instance.playerManager = playerManager
    instance.runeItemData = runeItemData

    instance.name = runeItemData.name or "Aura de Dano (Instância)"
    instance.damage_per_tick = runeItemData.damage or self.defaultDamagePerTick
    instance.tick_interval = runeItemData.tick_interval or self.defaultTickInterval
    instance.radius = runeItemData.radius or self.defaultRadius
    instance.color = runeItemData.color or deepcopy(self.defaultColor) -- Copia para evitar modificação global
    instance.pulseDuration = runeItemData.pulseDuration or self.defaultPulseDuration

    instance.cooldownRemaining = instance.tick_interval -- Começa no cooldown para não disparar imediatamente

    -- Estado da aura (específico da instância)
    instance.auraState = {
        active = true, -- Aura geralmente está sempre ativa se a runa está equipada
        pulseTime = 0,
        pulseActive = false
    }

    -- Configuração da onda de choque (específico da instância)
    instance.shockwave = {
        currentRadius = 0,
        maxRadius = instance.radius, -- Usa o raio da instância
        duration = self.defaultShockwaveDuration,
        timer = 0,
        thickness = self.defaultShockwaveThickness,
        isActive = false,
        alpha = 0.8,
        particleCount = self.defaultShockwaveParticleCount,
        particleSize = self.defaultShockwaveParticleSize
    }

    print(string.format("Instância de Aura criada: Dmg/Tick=%d, Interval=%.2f, Radius=%.1f", instance.damage_per_tick,
        instance.tick_interval, instance.radius))
    return instance
end

function Aura:update(dt, enemies)
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = math.max(0, self.cooldownRemaining - dt)
    end

    if self.shockwave.isActive then
        self.shockwave.timer = self.shockwave.timer + dt
        local progress = self.shockwave.timer / self.shockwave.duration

        if progress <= 1 then
            local easeProgress = progress * (2 - progress)
            self.shockwave.currentRadius = self.shockwave.maxRadius * easeProgress
            self.shockwave.alpha = 0.8 * (1 - progress)
        else
            self.shockwave.isActive = false
            self.shockwave.currentRadius = 0
            self.shockwave.timer = 0
        end
    end

    -- A aura está "sempre ativa" se a runa estiver equipada. O dano ocorre em intervalos.
    if self.auraState.active then
        if self.cooldownRemaining <= 0 then
            self.shockwave.isActive = true
            self.shockwave.currentRadius = 0
            self.shockwave.timer = 0

            self:applyAuraDamage(enemies)

            self.cooldownRemaining = self.tick_interval
        end
    end
end

function Aura:draw()
    if not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    if self.auraState.active then
        local playerX = self.playerManager.player.position.x
        local playerY = self.playerManager.player.position.y + 25

        love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.color[4] or 0.03) -- Usa cor da instância
        love.graphics.circle("fill", playerX, playerY, self.radius)

        if self.shockwave.isActive then
            local previousLineWidth = love.graphics.getLineWidth()

            love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.shockwave.alpha) -- Usa cor base da aura para shockwave
            love.graphics.setLineWidth(self.shockwave.thickness)
            love.graphics.circle("line", playerX, playerY, self.shockwave.currentRadius)

            local angleStep = (2 * math.pi) / self.shockwave.particleCount
            for i = 1, self.shockwave.particleCount do
                local angle = i * angleStep
                local particleX = playerX + math.cos(angle) * self.shockwave.currentRadius
                local particleY = playerY + math.sin(angle) * self.shockwave.currentRadius

                local particleScale = 1 - (self.shockwave.timer / self.shockwave.duration)
                local currentParticleSize = self.shockwave.particleSize * particleScale

                love.graphics.circle("fill", particleX, particleY, currentParticleSize)
            end

            love.graphics.setLineWidth(previousLineWidth)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- O método cast pode não ser diretamente chamado pelo PlayerManager para auras passivas,
-- mas pode ser útil para uma ativação inicial ou algum efeito especial.
function Aura:cast()
    -- A aura é ativada na criação da instância.
    -- Este método pode ser usado para reativar ou forçar um pulso se necessário.
    self.auraState.active = true
    -- Força um pulso imediato se desejado (opcional)
    -- self.cooldownRemaining = 0
    -- print("Aura cast (ativada ou pulso forçado)")
    return true
end

-- Função auxiliar para aplicar dano a um único alvo.
-- O dano principal da aura é feito em applyAuraDamage.
function Aura:applyDamageToTarget(target) -- Renomeado para clareza
    if not target then return false end

    if target.takeDamage then
        return target:takeDamage(self.damage_per_tick)
    elseif target.receiveDamage then
        target:receiveDamage(self.damage_per_tick, "aura")
        return true
    else
        print("AVISO [Aura:applyDamageToTarget]: Alvo inválido ou sem método de dano.")
    end
    return false
end

function Aura:applyAuraDamage(enemies)
    if not enemies or not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    local playerPos = self.playerManager.player.position
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.position.x - playerPos.x
            local dy = enemy.position.y - playerPos.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= self.radius then
                self:applyDamageToTarget(enemy)
            end
        end
    end
end

return Aura
