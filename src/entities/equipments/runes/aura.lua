--[[
    Aura Ability
    Uma aura que causa dano aos inimigos próximos periodicamente
]]

local RenderPipeline = require("src.core.render_pipeline")
local AuraEffect = require("src.effects.aura_effect")

local Aura = {}
Aura.__index = Aura -- Para permitir que instâncias herdem métodos

-- Propriedades padrão da classe
Aura.identifier = "rune_aura"
Aura.defaultDepth = RenderPipeline.DEPTH_DROPS
Aura.defaultDamagePerTick = 80
Aura.defaultCooldown = 1.0
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

    -- Obtém dados base da runa para configurações visuais
    local runeBaseData = nil
    if runeItemData.itemBaseId and playerManager.itemDataManager then
        runeBaseData = playerManager.itemDataManager:getBaseItemData(runeItemData.itemBaseId)
    end

    if not runeBaseData then
        error("Runa base não encontrada para " .. runeItemData.name)
    end

    instance.name = runeBaseData.name
    instance.damage_per_tick = runeBaseData.damage or self.defaultDamagePerTick
    instance.cooldown = runeBaseData.tick_interval or self.defaultCooldown
    instance.radius = runeBaseData.radius or self.defaultRadius

    -- Usa cor dos dados base se disponível, depois do runeItemData, e por último a cor padrão
    local colorToUse = runeBaseData.color or self.defaultColor
    instance.color = deepcopy(colorToUse) -- Copia para evitar modificação global

    instance.pulseDuration = runeItemData.pulseDuration or self.defaultPulseDuration

    instance.currentCooldown = instance.cooldown -- Começa no cooldown para não disparar imediatamente

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

    -- Cria o efeito visual da aura
    instance.visualEffect = AuraEffect:new(
        { x = 0, y = 0 },             -- Posição será atualizada dinamicamente
        {
            radius = instance.radius, -- Passa o raio para calcular escala correta
            rotationSpeed = 0.8
        }
    )

    return instance
end

--- Atualiza a habilidade da Aura.
--- @param dt number Tempo de atualização.
--- @param enemies BaseEnemy[] Lista de inimigos.
--- @param finalStats table Estatísticas finais do jogador.
function Aura:update(dt, enemies, finalStats)
    -- Atualiza posição do efeito visual
    if self.playerManager and self.playerManager.player and self.playerManager.player.position then
        self.visualEffect.position.x = self.playerManager.player.position.x
        self.visualEffect.position.y = self.playerManager.player.position.y + 25
    end

    -- Atualiza o efeito visual
    self.visualEffect:update(dt)

    if self.currentCooldown > 0 then
        self.currentCooldown = math.max(0, self.currentCooldown - dt)

        -- Prepara o efeito visual conforme se aproxima do dano
        local timeUntilDamage = self.currentCooldown
        if timeUntilDamage <= 1.0 then -- Prepara nos últimos 1 segundo
            self.visualEffect:prepareDamage(timeUntilDamage)
        end
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
            -- Retorna efeito visual ao normal depois do shockwave
            self.visualEffect:resetToNormal()
        end
    end

    -- A aura está "sempre ativa" se a runa estiver equipada. O dano ocorre em intervalos.
    if self.auraState.active then
        if self.currentCooldown <= 0 then
            self.shockwave.isActive = true
            self.shockwave.currentRadius = 0
            self.shockwave.timer = 0

            -- Triggera o pulso visual no momento do dano
            self.visualEffect:triggerDamagePulse()

            self:applyAuraDamage(enemies)
            local cooldownReduction = finalStats.cooldownReduction
            if cooldownReduction <= 0 then cooldownReduction = 0.01 end
            local finalCooldown = self.cooldown / cooldownReduction
            self.currentCooldown = finalCooldown
        end
    end
end

function Aura:draw()
    if not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    if self.auraState.active then
        local playerX = self.playerManager.player.position.x
        local playerY = self.playerManager.player.position.y + 25

        -- Desenha o novo efeito visual da aura
        self.visualEffect:draw()

        if self.shockwave.isActive then
            local previousLineWidth = love.graphics.getLineWidth()

            love.graphics.setColor(1, 1, 1, self.shockwave.alpha) -- Usa cor base da aura para shockwave
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

--- Coleta renderizáveis para o render pipeline
--- @param renderPipeline RenderPipeline
function Aura:collectRenderables(renderPipeline)
    if not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    if self.auraState.active then
        -- Adiciona o efeito visual da aura ao pipeline
        self.visualEffect:collectRenderables(renderPipeline)
    end
end

-- O método cast pode não ser diretamente chamado pelo PlayerManager para auras passivas,
-- mas pode ser útil para uma ativação inicial ou algum efeito especial.
function Aura:cast()
    -- A aura é ativada na criação da instância.
    -- Este método pode ser usado para reativar ou forçar um pulso se necessário.
    self.auraState.active = true
    -- Força um pulso imediato se desejado (opcional)
    -- self.currentCooldown = 0
    -- print("Aura cast (ativada ou pulso forçado)")
    return true
end

-- Função auxiliar para aplicar dano a um único alvo.
-- O dano principal da aura é feito em applyAuraDamage.
function Aura:applyDamageToTarget(target)
    if not target then return false end

    local damageAmount = self.damage_per_tick
    local died = false

    if target.takeDamage then
        died = target:takeDamage(damageAmount)
        if self.playerManager and self.playerManager.registerDamageDealt then
            self.playerManager:registerDamageDealt(damageAmount, false, { abilityId = self.identifier })
        end
        return died
    elseif target.receiveDamage then
        target:receiveDamage(damageAmount, "aura")
        if self.playerManager and self.playerManager.registerDamageDealt then
            self.playerManager:registerDamageDealt(damageAmount, false, { abilityId = self.identifier })
        end
        return true
    else
        print("AVISO [Aura:applyDamageToTarget]: Alvo inválido ou sem método de dano.")
    end
    return false
end

function Aura:applyAuraDamage(enemies)
    if not enemies or not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    local playerPos = self.playerManager.player.position
    local enemiesHitCount = 0
    for _, enemy in ipairs(enemies) do
        if enemy.isAlive then
            local dx = enemy.position.x - playerPos.x
            local dy = enemy.position.y - playerPos.y
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= self.radius then
                self:applyDamageToTarget(enemy)
                enemiesHitCount = enemiesHitCount + 1
            end
        end
    end

    if enemiesHitCount > 0 and self.playerManager.gameStatisticsManager then
        self.playerManager.gameStatisticsManager:registerEnemiesHit(enemiesHitCount)
    end
end

return Aura
