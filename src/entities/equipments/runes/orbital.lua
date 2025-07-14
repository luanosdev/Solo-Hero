--[[
    Runa Orbital
    Herda de BaseRune para funcionalidades comuns
    Cria orbes que orbitam ao redor do jogador e causam dano aos inimigos próximos

    Atributos Específicos:
    - damage: Dano dos orbes
    - orbitRadius: Raio da órbita dos orbes
    - orbCount: Número de orbes
    - orbRadius: Raio visual/colisão dos orbes
    - rotationSpeed: Velocidade de rotação dos orbes
    - orbDamageCooldown: Cooldown geral do orbe
    - enemyCooldownPerOrb: Cooldown por inimigo
]]

local BaseRune = require("src.entities.equipments.runes.base_rune")
local TablePool = require("src.utils.table_pool")
local CombatHelpers = require("src.utils.combat_helpers")

---@class OrbitalConfig : BaseRuneConfig
---@field damage number Dano dos orbes
---@field orbitRadius number Raio da órbita dos orbes
---@field orbCount number Número de orbes
---@field orbRadius number Raio visual/colisão dos orbes
---@field rotationSpeed number Velocidade de rotação dos orbes
---@field orbDamageCooldown number Cooldown geral do orbe
---@field enemyCooldownPerOrb number Cooldown por inimigo

---@class OrbitalOrb
---@field angle number Ângulo atual do orbe (em radianos)
---@field damagedEnemies table<string, number> Inimigos danificados e seus cooldowns
---@field lastDamageTime number Tempo desde o último dano aplicado
---@field position Vector2D Posição atual do orbe no mundo

---@class OrbitalAnimation
---@field scale number Escala da animação baseada no raio do orbe
---@field globalFrames love.Image[] Frames globais da animação
---@field loaded boolean Se os frames foram carregados
---@field width number Largura base do frame
---@field height number Altura base do frame

---@class OrbitalInstance : BaseRuneInstance
---@field baseConfig OrbitalConfig Configuração base específica da orbital
---@field currentConfig OrbitalConfig Configuração atual específica da orbital
---@field orbs OrbitalOrb[] Lista de orbes ativos
---@field orbitalAnimation OrbitalAnimation Configuração da animação orbital
---@field lastDamageStatistics table<string, number> Cache de estatísticas de dano

---@class Orbital : BaseRune
local Orbital = setmetatable({}, { __index = BaseRune })
Orbital.__index = Orbital

-- Configurações específicas da Orbital
Orbital.identifier = "rune_orbital"
Orbital.animationPath = "assets/abilities/orbital/orbital_"
Orbital.animationFrameCount = 7
Orbital.animationFrameTime = 0.1
Orbital.animationWidth = 67
Orbital.animationHeight = 67

-- Valores padrão específicos
Orbital.defaultDamage = 100
Orbital.defaultOrbitRadius = 90
Orbital.defaultOrbCount = 3
Orbital.defaultOrbRadius = 20
Orbital.defaultRotationSpeed = 2.0
Orbital.defaultOrbDamageCooldown = 0.1
Orbital.defaultEnemyCooldownPerOrb = 2.0

-- Configuração global da animação (compartilhada entre instâncias)
local globalAnimationConfig = {
    frames = {},
    loaded = false,
    width = Orbital.animationWidth,
    height = Orbital.animationHeight,
    frameCount = Orbital.animationFrameCount
}

--- Carrega frames da animação globalmente (uma vez)
--- @return boolean success True se todos os frames foram carregados
local function loadGlobalAnimationFrames()
    if globalAnimationConfig.loaded then return true end

    local success = true
    globalAnimationConfig.frames = TablePool.getArray()

    for i = 1, globalAnimationConfig.frameCount do
        local framePath = Orbital.animationPath .. i .. ".png"
        local frameSuccess, frame = pcall(love.graphics.newImage, framePath)

        if frameSuccess then
            globalAnimationConfig.frames[i] = frame
            Logger.debug("orbital.animation.load_frame",
                string.format("[Orbital:loadGlobalAnimationFrames] Frame %d carregado: %s", i, framePath))
        else
            Logger.error("orbital.animation.load_failed",
                string.format("[Orbital:loadGlobalAnimationFrames] Erro ao carregar frame %d: %s", i, framePath))
            success = false
        end
    end

    globalAnimationConfig.loaded = success
    return success
end

--- Cria configuração base específica da Orbital
--- @param runeBaseData table Dados base da runa do ItemDataManager
--- @return OrbitalConfig Configuração base da orbital
function Orbital:createBaseConfig(runeBaseData)
    local config = TablePool.getGeneric()

    config.damage = runeBaseData.damage or self.defaultDamage
    config.orbitRadius = runeBaseData.orbitRadius or self.defaultOrbitRadius
    config.orbCount = runeBaseData.orbCount or self.defaultOrbCount
    config.orbRadius = runeBaseData.orbRadius or self.defaultOrbRadius
    config.rotationSpeed = runeBaseData.rotationSpeed or self.defaultRotationSpeed
    config.orbDamageCooldown = runeBaseData.orb_damage_cooldown or self.defaultOrbDamageCooldown
    config.enemyCooldownPerOrb = runeBaseData.enemy_cooldown_per_orb or self.defaultEnemyCooldownPerOrb

    return config
end

--- Construtor da Orbital
--- @param playerManager PlayerManager Instância do gerenciador do jogador
--- @param itemData RuneItemInstance Dados da instância do item da runa
--- @return OrbitalInstance Instância da runa orbital
function Orbital:new(playerManager, itemData)
    -- Carrega animações globais
    loadGlobalAnimationFrames()

    local instance = BaseRune.new(self, playerManager, itemData)

    -- Inicializa dados específicos da Orbital
    instance.orbs = TablePool.getArray()
    instance.lastDamageStatistics = TablePool.getGeneric()

    -- Configuração da animação orbital
    instance.orbitalAnimation = TablePool.getGeneric()
    instance.orbitalAnimation.scale = instance.currentConfig.orbRadius / (globalAnimationConfig.width / 2)
    instance.orbitalAnimation.globalFrames = globalAnimationConfig.frames
    instance.orbitalAnimation.loaded = globalAnimationConfig.loaded
    instance.orbitalAnimation.width = globalAnimationConfig.width
    instance.orbitalAnimation.height = globalAnimationConfig.height

    -- Cria orbes iniciais
    instance:createOrbs()

    -- Aplica upgrades se existirem
    instance:applyUpgrades()

    Logger.info("orbital.create",
        string.format("[Orbital:new] Orbital criada: Dano=%d, Orbes=%d, Raio=%.1f",
            instance.currentConfig.damage, instance.currentConfig.orbCount, instance.currentConfig.orbitRadius))

    return instance
end

--- Cria orbes baseado na configuração atual
function Orbital:createOrbs()
    -- Limpa orbes existentes
    if self.orbs then
        for _, orb in ipairs(self.orbs) do
            if orb.damagedEnemies then
                TablePool.releaseGeneric(orb.damagedEnemies)
            end
            TablePool.releaseGeneric(orb)
        end
        TablePool.releaseArray(self.orbs)
    end

    -- Cria novos orbes
    self.orbs = TablePool.getArray()
    for i = 1, self.currentConfig.orbCount do
        local orb = TablePool.getGeneric()
        orb.angle = (i - 1) * (2 * math.pi / self.currentConfig.orbCount)
        orb.damagedEnemies = TablePool.getGeneric()
        orb.lastDamageTime = 0
        orb.position = { x = 0, y = 0 }

        table.insert(self.orbs, orb)
    end

    Logger.debug("orbital.orbs.create",
        string.format("[Orbital:createOrbs] Criados %d orbes", self.currentConfig.orbCount))
end

--- Aplica efeito específico de upgrade da Orbital
--- @param effect table Efeito do upgrade
--- @param count number Quantidade de aplicações
function Orbital:applyUpgradeEffect(effect, count)
    local effectType = effect.type
    local value = effect.value
    local isPercentage = effect.is_percentage

    if effectType == "extra_orb" then
        -- Upgrade especial que adiciona orbes extras
        local newOrbCount = self.baseConfig.orbCount + (value * count)
        if newOrbCount > self.currentConfig.orbCount then
            self.currentConfig.orbCount = newOrbCount
            self:createOrbs()
        end
        return
    end

    if effectType == "orb_size" then
        -- Aplica modificação no tamanho do orbe
        if isPercentage then
            self.currentConfig.orbRadius = self.baseConfig.orbRadius * (1 + (value * count / 100))
        else
            self.currentConfig.orbRadius = self.baseConfig.orbRadius + (value * count)
        end

        -- Atualiza escala da animação
        self.orbitalAnimation.scale = self.currentConfig.orbRadius / (globalAnimationConfig.width / 2)
        return
    end

    -- Aplica efeitos padrão
    if not self.currentConfig[effectType] or not self.baseConfig[effectType] then
        Logger.warn("orbital.upgrade.unknown_effect",
            string.format("[Orbital:applyUpgradeEffect] Efeito desconhecido: %s", effectType))
        return
    end

    if isPercentage then
        self.currentConfig[effectType] = self.baseConfig[effectType] * (1 + (value * count / 100))
    else
        self.currentConfig[effectType] = self.baseConfig[effectType] + (value * count)
    end

    Logger.debug("orbital.upgrade.effect",
        string.format("[Orbital:applyUpgradeEffect] %s: %.2f", effectType, self.currentConfig[effectType]))
end

--- Atualiza posições dos orbes
--- @param dt number Delta time
function Orbital:updateOrbPositions(dt)
    local playerPos = self.playerManager:getPlayerPosition()
    if not playerPos then return end

    for _, orb in ipairs(self.orbs) do
        -- Atualiza ângulo do orbe
        orb.angle = orb.angle + (self.currentConfig.rotationSpeed * dt)

        -- Calcula posição do orbe
        orb.position.x = playerPos.x + math.cos(orb.angle) * self.currentConfig.orbitRadius
        orb.position.y = playerPos.y + 25 + math.sin(orb.angle) * self.currentConfig.orbitRadius

        -- Atualiza cooldowns
        orb.lastDamageTime = orb.lastDamageTime + dt

        -- Limpa cooldowns expirados usando TablePool
        local expiredEnemies = TablePool.getArray()
        for enemyId, cooldown in pairs(orb.damagedEnemies) do
            local newCooldown = cooldown - dt
            if newCooldown <= 0 then
                table.insert(expiredEnemies, enemyId)
            else
                orb.damagedEnemies[enemyId] = newCooldown
            end
        end

        for _, enemyId in ipairs(expiredEnemies) do
            orb.damagedEnemies[enemyId] = nil
        end
        TablePool.releaseArray(expiredEnemies)
    end
end

--- Aplica dano orbital aos inimigos
--- @param enemies BaseEnemy[] Lista de inimigos
--- @param finalStats FinalStats Estatísticas finais do jogador
function Orbital:applyOrbitalDamage(enemies, finalStats)
    local enemiesHitThisTick = 0
    local cooldownReduction = finalStats.cooldownReduction or 1

    for _, orb in ipairs(self.orbs) do
        -- Verifica cooldown geral do orbe
        local finalOrbCooldown = self.currentConfig.orbDamageCooldown / cooldownReduction
        if orb.lastDamageTime < finalOrbCooldown then
            goto continue
        end

        -- Encontra inimigos em alcance usando CombatHelpers
        local enemiesInRange = CombatHelpers.findEnemiesInCircularArea(
            orb.position,
            self.currentConfig.orbRadius,
            self.playerManager:getPlayerSprite()
        )

        local orbHitEnemy = false
        for _, enemy in ipairs(enemiesInRange) do
            if enemy.isAlive and enemy.isAlive and enemy.id then
                local enemyId = enemy.id

                -- Verifica cooldown específico do inimigo
                if not orb.damagedEnemies[enemyId] then
                    -- Aplica dano usando BaseRune
                    if self:applyDamageToTarget(enemy, self.currentConfig.damage, "orbital") then
                        enemiesHitThisTick = enemiesHitThisTick + 1
                        orbHitEnemy = true

                        -- Aplica cooldown específico do inimigo
                        local finalEnemyCooldown = self.currentConfig.enemyCooldownPerOrb / cooldownReduction
                        orb.damagedEnemies[enemyId] = finalEnemyCooldown
                    end
                end
            end
        end

        TablePool.releaseArray(enemiesInRange)

        -- Reseta cooldown geral do orbe se atingiu algum inimigo
        if orbHitEnemy then
            orb.lastDamageTime = 0
        end

        ::continue::
    end

    -- Registra estatísticas
    if enemiesHitThisTick > 0 and self.playerManager.gameStatisticsManager then
        self.playerManager.gameStatisticsManager:registerEnemiesHit(enemiesHitThisTick)
    end

    Logger.debug("orbital.damage",
        string.format("[Orbital:applyOrbitalDamage] Orbitais atingiram %d inimigos", enemiesHitThisTick))
end

--- Atualiza a lógica da Orbital
--- @param dt number Delta time
--- @param enemies BaseEnemy[] Lista de inimigos
--- @param finalStats FinalStats Estatísticas finais do jogador
function Orbital:update(dt, enemies, finalStats)
    -- Chama update da base (cooldown e animação)
    BaseRune.update(self, dt, enemies, finalStats)

    -- Atualiza posições dos orbes
    self:updateOrbPositions(dt)

    -- Aplica dano orbital
    self:applyOrbitalDamage(enemies, finalStats)
end

--- Desenha os orbes da Orbital
function Orbital:draw()
    if not self.orbitalAnimation.loaded or not self.orbitalAnimation.globalFrames then return end

    local frameToDraw = self.orbitalAnimation.globalFrames[self.animation.currentFrame]
    if not frameToDraw then return end

    love.graphics.setColor(1, 1, 1, 1)
    for _, orb in ipairs(self.orbs) do
        love.graphics.draw(
            frameToDraw,
            orb.position.x,
            orb.position.y,
            0,
            self.orbitalAnimation.scale,
            self.orbitalAnimation.scale,
            self.orbitalAnimation.width / 2,
            self.orbitalAnimation.height / 2
        )
    end
end

--- Executa a habilidade da Orbital (as orbitais são passivas)
--- @param x number|nil Posição X (não usado pela Orbital)
--- @param y number|nil Posição Y (não usado pela Orbital)
--- @return boolean success True se executada com sucesso
function Orbital:cast(x, y)
    -- Orbitais são passivas, sempre retorna true
    Logger.debug("orbital.cast", "[Orbital:cast] Orbital é passiva, sempre ativa")
    return true
end

--- Coleta renderáveis para o pipeline de renderização
--- @param renderPipeline RenderPipeline Pipeline de renderização
--- @param sortY number Y base para ordenação
function Orbital:collectRenderables(renderPipeline, sortY)
    if not self.orbitalAnimation.loaded then return end

    for _, orb in ipairs(self.orbs) do
        -- Adiciona cada orbe como renderável independente
        renderPipeline:addRenderable(
            orb.position.x,
            orb.position.y,
            sortY,
            self.defaultDepth,
            function()
                self:drawSingleOrb(orb)
            end
        )
    end
end

--- Desenha um único orbe
--- @param orb OrbitalOrb Orbe a ser desenhado
function Orbital:drawSingleOrb(orb)
    if not self.orbitalAnimation.loaded or not self.orbitalAnimation.globalFrames then return end

    local frameToDraw = self.orbitalAnimation.globalFrames[self.animation.currentFrame]
    if not frameToDraw then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        frameToDraw,
        orb.position.x,
        orb.position.y,
        0,
        self.orbitalAnimation.scale,
        self.orbitalAnimation.scale,
        self.orbitalAnimation.width / 2,
        self.orbitalAnimation.height / 2
    )
end

--- Limpa recursos específicos da Orbital
function Orbital:cleanup()
    -- Limpa orbes e seus recursos
    if self.orbs then
        for _, orb in ipairs(self.orbs) do
            if orb.damagedEnemies then
                TablePool.releaseGeneric(orb.damagedEnemies)
            end
            TablePool.releaseGeneric(orb)
        end
        TablePool.releaseArray(self.orbs)
        self.orbs = nil
    end

    -- Limpa animação orbital
    if self.orbitalAnimation then
        TablePool.releaseGeneric(self.orbitalAnimation)
        self.orbitalAnimation = nil
    end

    -- Limpa estatísticas
    if self.lastDamageStatistics then
        TablePool.releaseGeneric(self.lastDamageStatistics)
        self.lastDamageStatistics = nil
    end

    -- Chama cleanup da base
    BaseRune.cleanup(self)

    Logger.debug("orbital.cleanup", "[Orbital:cleanup] Recursos específicos da Orbital liberados")
end

return Orbital
