--[[
    Aura Ability
    Herda de BaseRune para funcionalidades comuns
    Uma aura que causa dano aos inimigos próximos periodicamente

    Atributos Específicos:
    - damage_per_tick: Dano por tick da aura
    - cooldown: Intervalo entre aplicações de dano
    - radius: Raio da aura
]]

local BaseRune = require("src.entities.equipments.runes.base_rune")
local AuraEffect = require("src.effects.aura_effect")
local TablePool = require("src.utils.table_pool")

---@class AuraConfig : BaseRuneConfig
---@field damage_per_tick number Dano por tick da aura
---@field cooldown number Intervalo entre aplicações de dano
---@field radius number Raio da aura
---@field pulseDuration number Duração do pulso visual
---@field shockwaveDuration number Duração da onda de choque
---@field shockwaveThickness number Espessura da onda de choque
---@field shockwaveParticleCount number Número de partículas da onda
---@field shockwaveParticleSize number Tamanho das partículas
---@field color ColorRGBA Cor da aura no formato {r, g, b, a}

---@class AuraShockwave
---@field currentRadius number Raio atual da onda de choque
---@field maxRadius number Raio máximo da onda de choque
---@field duration number Duração da onda de choque
---@field timer number Timer da onda de choque
---@field thickness number Espessura da onda de choque
---@field isActive boolean Se a onda de choque está ativa
---@field alpha number Transparência da onda (0-1)
---@field particleCount number Número de partículas
---@field particleSize number Tamanho das partículas em pixels

---@class AuraState
---@field active boolean Se a aura está ativa
---@field pulseTime number Tempo do pulso em segundos
---@field pulseActive boolean Se o pulso está ativo

---@class AuraInstance : BaseRuneInstance
---@field baseConfig AuraConfig Configuração base específica da aura
---@field currentConfig AuraConfig Configuração atual específica da aura
---@field auraState AuraState Estado da aura
---@field shockwave AuraShockwave Configuração da onda de choque
---@field visualEffect AuraEffect Efeito visual da aura
---@field lastDamageTargets BaseEnemy[]|nil Cache dos últimos alvos atingidos

---@class Aura : BaseRune
local Aura = setmetatable({}, { __index = BaseRune })
Aura.__index = Aura

-- Configurações específicas da Aura
Aura.identifier = "rune_aura"

-- Valores padrão específicos
Aura.defaultDamagePerTick = 80
Aura.defaultCooldown = 1.0
Aura.defaultRadius = 100
Aura.defaultColor = { 0.8, 0, 0.8, 0.03 }
Aura.defaultPulseDuration = 0.3
Aura.defaultShockwaveDuration = 0.5
Aura.defaultShockwaveThickness = 4
Aura.defaultShockwaveParticleCount = 32
Aura.defaultShockwaveParticleSize = 3

--- Cria configuração base específica da Aura
--- @param runeBaseData table Dados base da runa do ItemDataManager
--- @return AuraConfig Configuração base da aura
function Aura:createBaseConfig(runeBaseData)
    local config = TablePool.getGeneric()

    config.damage_per_tick = runeBaseData.damage or self.defaultDamagePerTick
    config.cooldown = runeBaseData.tick_interval or self.defaultCooldown
    config.radius = runeBaseData.radius or self.defaultRadius
    config.pulseDuration = runeBaseData.pulseDuration or self.defaultPulseDuration
    config.shockwaveDuration = self.defaultShockwaveDuration
    config.shockwaveThickness = self.defaultShockwaveThickness
    config.shockwaveParticleCount = self.defaultShockwaveParticleCount
    config.shockwaveParticleSize = self.defaultShockwaveParticleSize
    config.color = runeBaseData.color or self.defaultColor

    return config
end

--- Construtor da Aura
--- @param playerManager PlayerManager Instância do gerenciador do jogador
--- @param itemData RuneItemInstance Dados da instância do item da runa
--- @return AuraInstance Instância da runa de aura
function Aura:new(playerManager, itemData)
    local instance = BaseRune.new(self, playerManager, itemData)

    -- Inicializa dados específicos da Aura
    instance.lastDamageTargets = TablePool.getArray()

    -- Estado da aura (específico da instância)
    instance.auraState = TablePool.getGeneric()
    instance.auraState.active = true
    instance.auraState.pulseTime = 0
    instance.auraState.pulseActive = false

    -- Configuração da onda de choque (específico da instância)
    instance.shockwave = TablePool.getGeneric()
    instance.shockwave.currentRadius = 0
    instance.shockwave.maxRadius = instance.currentConfig.radius
    instance.shockwave.duration = instance.currentConfig.shockwaveDuration
    instance.shockwave.timer = 0
    instance.shockwave.thickness = instance.currentConfig.shockwaveThickness
    instance.shockwave.isActive = false
    instance.shockwave.alpha = 0.8
    instance.shockwave.particleCount = instance.currentConfig.shockwaveParticleCount
    instance.shockwave.particleSize = instance.currentConfig.shockwaveParticleSize

    -- Cria o efeito visual da aura
    instance.visualEffect = AuraEffect:new(
        { x = 0, y = 0 },
        {
            radius = instance.currentConfig.radius,
            rotationSpeed = 0.8
        }
    )

    -- Aplica upgrades se existirem
    instance:applyUpgrades()

    Logger.info(
        "aura.create",
        string.format("[Aura:new] Aura criada: Dano=%d, CD=%.2f, Raio=%.1f",
            instance.currentConfig.damage_per_tick, instance.currentConfig.cooldown, instance.currentConfig.radius)
    )

    return instance
end

--- Aplica efeito específico de upgrade da Aura
--- @param effect table Efeito do upgrade
--- @param count number Quantidade de aplicações
function Aura:applyUpgradeEffect(effect, count)
    local effectType = effect.type
    local value = effect.value
    local isPercentage = effect.is_percentage

    if not self.currentConfig[effectType] or not self.baseConfig[effectType] then
        Logger.warn("aura.upgrade.unknown_effect",
            string.format("[Aura:applyUpgradeEffect] Efeito desconhecido: %s", effectType))
        return
    end

    if isPercentage then
        self.currentConfig[effectType] = self.baseConfig[effectType] * (1 + (value * count / 100))
    else
        self.currentConfig[effectType] = self.baseConfig[effectType] + (value * count)
    end

    -- Atualiza componentes dependentes
    if effectType == "radius" then
        -- Atualiza o raio máximo da onda de choque
        self.shockwave.maxRadius = self.currentConfig.radius

        -- Atualiza o efeito visual
        if self.visualEffect then
            self.visualEffect.radius = self.currentConfig.radius
        end
    end

    Logger.debug("aura.upgrade.effect",
        string.format("[Aura:applyUpgradeEffect] %s: %.2f", effectType, self.currentConfig[effectType]))
end

--- Atualiza a lógica da Aura
--- @param dt number Delta time
--- @param enemies BaseEnemy[] Lista de inimigos
--- @param finalStats FinalStats Estatísticas finais do jogador
function Aura:update(dt, enemies, finalStats)
    -- Chama update da base (cooldown)
    BaseRune.update(self, dt, enemies, finalStats)

    -- Atualiza posição do efeito visual
    local playerPos = self.playerManager:getPlayerPosition()
    if playerPos then
        self.visualEffect.position.x = playerPos.x
        self.visualEffect.position.y = playerPos.y + 25
    end

    -- Atualiza o efeito visual
    self.visualEffect:update(dt)

    -- Atualiza onda de choque
    self:updateShockwave(dt)

    -- Prepara efeito visual conforme se aproxima do dano
    if self.currentCooldown > 0 then
        local timeUntilDamage = self.currentCooldown
        if timeUntilDamage <= 1.0 then
            self.visualEffect:prepareDamage(timeUntilDamage)
        end
    end

    -- Executa dano da aura
    if self.auraState.active and self.currentCooldown <= 0 then
        self:executeAuraDamage(enemies, finalStats)

        -- Aplica redução de cooldown das estatísticas finais
        local cooldownReduction = finalStats.cooldownReduction or 1
        if cooldownReduction <= 0 then cooldownReduction = 0.01 end
        local finalCooldown = self.currentConfig.cooldown / cooldownReduction
        self.currentCooldown = finalCooldown
    end
end

--- Atualiza a onda de choque
--- @param dt number Delta time
function Aura:updateShockwave(dt)
    if not self.shockwave.isActive then return end

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

--- Executa dano da aura
--- @param enemies BaseEnemy[] Lista de inimigos
--- @param finalStats FinalStats Estatísticas finais do jogador
function Aura:executeAuraDamage(enemies, finalStats)
    local playerPos = self.playerManager:getPlayerPosition()
    if not playerPos then return end

    -- Ativa efeitos visuais
    self.shockwave.isActive = true
    self.shockwave.currentRadius = 0
    self.shockwave.timer = 0
    self.visualEffect:triggerDamagePulse()

    -- Encontra inimigos na área da aura usando CombatHelpers otimizado
    local enemiesInRange = self:findEnemiesInRadius(playerPos, self.currentConfig.radius)

    -- Limpa cache de alvos anteriores
    for i = #self.lastDamageTargets, 1, -1 do
        self.lastDamageTargets[i] = nil
    end

    -- Aplica dano a todos os inimigos na área
    local enemiesHit = 0
    for _, enemy in ipairs(enemiesInRange) do
        if self:applyDamageToTarget(enemy, self.currentConfig.damage_per_tick, "aura") then
            enemiesHit = enemiesHit + 1
            table.insert(self.lastDamageTargets, enemy)
        end
    end

    -- Registra estatísticas
    if enemiesHit > 0 and self.playerManager.gameStatisticsManager then
        self.playerManager.gameStatisticsManager:registerEnemiesHit(enemiesHit)
    end

    TablePool.releaseArray(enemiesInRange)

    Logger.debug("aura.damage",
        string.format("[Aura:executeAuraDamage] Aura atingiu %d inimigos", enemiesHit))
end

--- Desenha a aura
function Aura:draw()
    if not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    if self.auraState.active then
        local playerX = self.playerManager.player.position.x
        local playerY = self.playerManager.player.position.y + 25

        -- Desenha o efeito visual da aura
        self.visualEffect:draw()

        -- Desenha onda de choque se ativa
        if self.shockwave.isActive then
            self:drawShockwave(playerX, playerY)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

--- Desenha a onda de choque
--- @param centerX number Posição X central
--- @param centerY number Posição Y central
function Aura:drawShockwave(centerX, centerY)
    local previousLineWidth = love.graphics.getLineWidth()

    love.graphics.setColor(1, 1, 1, self.shockwave.alpha)
    love.graphics.setLineWidth(self.shockwave.thickness)
    love.graphics.circle("line", centerX, centerY, self.shockwave.currentRadius)

    -- Desenha partículas da onda
    local angleStep = (2 * math.pi) / self.shockwave.particleCount
    for i = 1, self.shockwave.particleCount do
        local angle = i * angleStep
        local particleX = centerX + math.cos(angle) * self.shockwave.currentRadius
        local particleY = centerY + math.sin(angle) * self.shockwave.currentRadius

        local particleScale = 1 - (self.shockwave.timer / self.shockwave.duration)
        local currentParticleSize = self.shockwave.particleSize * particleScale

        love.graphics.circle("fill", particleX, particleY, currentParticleSize)
    end

    love.graphics.setLineWidth(previousLineWidth)
end

--- Executa a habilidade da Aura (ativação/desativação manual)
--- @param x number|nil Posição X (não usado pela Aura)
--- @param y number|nil Posição Y (não usado pela Aura)
--- @return boolean success True se executada com sucesso
function Aura:cast(x, y)
    -- A aura é ativada na criação da instância.
    -- Este método pode ser usado para reativar ou forçar um pulso se necessário.
    self.auraState.active = true
    -- Força um pulso imediato se desejado (opcional)
    self.currentCooldown = 0

    Logger.debug("aura.cast", "[Aura:cast] Aura ativada/pulso forçado")
    return true
end

--- Coleta renderáveis para o pipeline de renderização
--- @param renderPipeline RenderPipeline Pipeline de renderização
--- @param sortY number Y base para ordenação
function Aura:collectRenderables(renderPipeline, sortY)
    if not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then return end

    if self.auraState.active then
        -- Adiciona o efeito visual da aura ao pipeline
        self.visualEffect:collectRenderables(renderPipeline)
    end
end

--- Limpa recursos específicos da Aura
function Aura:cleanup()
    -- Limpa arrays e objetos específicos
    if self.lastDamageTargets then
        TablePool.releaseArray(self.lastDamageTargets)
        self.lastDamageTargets = nil
    end

    if self.auraState then
        TablePool.releaseGeneric(self.auraState)
        self.auraState = nil
    end

    if self.shockwave then
        TablePool.releaseGeneric(self.shockwave)
        self.shockwave = nil
    end

    -- Limpa efeito visual (se tiver método de cleanup)
    if self.visualEffect and self.visualEffect.cleanup then
        self.visualEffect:cleanup()
    end
    self.visualEffect = nil

    -- Chama cleanup da base
    BaseRune.cleanup(self)

    Logger.debug("aura.cleanup", "[Aura:cleanup] Recursos específicos da Aura liberados")
end

return Aura
