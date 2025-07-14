--[[
    Runa do Trovão
    Herda de BaseRune para funcionalidades comuns
    Faz raios caírem em inimigos aleatórios periodicamente

    Atributos Específicos:
    - damage: Dano do raio
    - cooldown: Intervalo entre raios
    - range: Alcance para selecionar inimigos
    - num_targets: Número de alvos simultâneos
    - chain_chance: Chance de encadeamento
    - chain_damage_reduction: Redução de dano por salto
    - chain_max_jumps: Máximo de saltos do raio
]]

local BaseRune = require("src.entities.equipments.runes.base_rune")
local TablePool = require("src.utils.table_pool")

---@class ThunderConfig : BaseRuneConfig
---@field damage number Dano do raio
---@field cooldown number Intervalo entre raios
---@field range number Alcance para selecionar inimigos
---@field num_targets number Número de alvos simultâneos
---@field chain_chance number Chance de encadeamento (0-1)
---@field chain_damage_reduction number Redução de dano por salto (0-1)
---@field chain_max_jumps number Máximo de saltos do raio

---@class ThunderStrike
---@field x number Posição X do raio
---@field y number Posição Y do raio
---@field timer number Timer do raio
---@field currentFrame number Frame atual da animação
---@field target BaseEnemy|nil Alvo do raio (para chains)

---@class ThunderInstance : BaseRuneInstance
---@field baseConfig ThunderConfig Configuração base específica do trovão
---@field currentConfig ThunderConfig Configuração atual específica do trovão
---@field activeStrikes ThunderStrike[] Raios ativos na tela
---@field lastTargets BaseEnemy[] Cache dos últimos alvos (para chains)

---@class Thunder : BaseRune
local Thunder = setmetatable({}, { __index = BaseRune })
Thunder.__index = Thunder

-- Configurações específicas da Thunder
Thunder.identifier = "rune_thunder"
Thunder.animationPath = "assets/abilities/thunder/spell_bluetop_1_"
Thunder.animationFrameCount = 22
Thunder.animationFrameTime = 0.02
Thunder.animationWidth = 128
Thunder.animationHeight = 128

-- Valores padrão específicos
Thunder.defaultDamage = 200
Thunder.defaultCooldown = 2.0
Thunder.defaultRange = 400
Thunder.defaultNumTargets = 1
Thunder.defaultChainChance = 0.0
Thunder.defaultChainDamageReduction = 0.3
Thunder.defaultChainMaxJumps = 3

--- Cria configuração base específica da Thunder
--- @param runeBaseData table Dados base da runa do ItemDataManager
--- @return ThunderConfig Configuração base da thunder
function Thunder:createBaseConfig(runeBaseData)
    local config = TablePool.getGeneric()

    config.damage = runeBaseData.damage or self.defaultDamage
    config.cooldown = runeBaseData.tick_interval or self.defaultCooldown
    config.range = runeBaseData.range or self.defaultRange
    config.num_targets = runeBaseData.num_targets or self.defaultNumTargets
    config.chain_chance = runeBaseData.chain_chance or self.defaultChainChance
    config.chain_damage_reduction = runeBaseData.chain_damage_reduction or self.defaultChainDamageReduction
    config.chain_max_jumps = runeBaseData.chain_max_jumps or self.defaultChainMaxJumps

    return config
end

--- Construtor da Thunder
--- @param playerManager PlayerManager Instância do gerenciador do jogador
--- @param itemData RuneItemInstance Dados da instância do item da runa
--- @return ThunderInstance Instância da runa de trovão
function Thunder:new(playerManager, itemData)
    local instance = BaseRune.new(self, playerManager, itemData)

    -- Inicializa dados específicos da Thunder
    instance.activeStrikes = TablePool.getArray()
    instance.lastTargets = TablePool.getArray()

    -- Aplica upgrades se existirem
    instance:applyUpgrades()

    Logger.info("thunder.create",
        string.format("[Thunder:new] Thunder criada: Dano=%d, CD=%.2f, Alcance=%.1f",
            instance.currentConfig.damage, instance.currentConfig.cooldown, instance.currentConfig.range))

    return instance
end

--- Aplica efeito específico de upgrade da Thunder
--- @param effect table Efeito do upgrade
--- @param count number Quantidade de aplicações
function Thunder:applyUpgradeEffect(effect, count)
    local effectType = effect.type
    local value = effect.value
    local isPercentage = effect.is_percentage

    if not self.currentConfig[effectType] or not self.baseConfig[effectType] then
        Logger.warn("thunder.upgrade.unknown_effect",
            string.format("[Thunder:applyUpgradeEffect] Efeito desconhecido: %s", effectType))
        return
    end

    if isPercentage then
        self.currentConfig[effectType] = self.baseConfig[effectType] * (1 + (value * count / 100))
    else
        self.currentConfig[effectType] = self.baseConfig[effectType] + (value * count)
    end

    Logger.debug("thunder.upgrade.effect",
        string.format("[Thunder:applyUpgradeEffect] %s: %.2f (%.1f%%)",
            effectType, self.currentConfig[effectType],
            isPercentage and value * count or (value * count / self.baseConfig[effectType] * 100)))
end

--- Atualiza a lógica da Thunder
--- @param dt number Delta time
--- @param enemies BaseEnemy[] Lista de inimigos
--- @param finalStats FinalStats Estatísticas finais do jogador
function Thunder:update(dt, enemies, finalStats)
    -- Chama update da base (cooldown e animação)
    BaseRune.update(self, dt, enemies, finalStats)

    -- Atualiza raios ativos
    self:updateActiveStrikes(dt)

    -- Executa lógica de disparo
    if self.currentCooldown <= 0 then
        self:executeThunderStrike(enemies, finalStats)

        -- Aplica redução de cooldown das estatísticas finais
        local cooldownReduction = finalStats.cooldownReduction or 1
        if cooldownReduction <= 0 then cooldownReduction = 0.01 end
        local finalCooldown = self.currentConfig.cooldown / cooldownReduction
        self.currentCooldown = finalCooldown
    end
end

--- Atualiza raios ativos na tela
--- @param dt number Delta time
function Thunder:updateActiveStrikes(dt)
    for i = #self.activeStrikes, 1, -1 do
        local strike = self.activeStrikes[i]
        strike.timer = strike.timer + dt

        if strike.timer >= self.animation.frameTime then
            strike.timer = 0
            strike.currentFrame = strike.currentFrame + 1

            if strike.currentFrame > self.animation.frameCount then
                -- Remove strike finalizado
                TablePool.releaseGeneric(table.remove(self.activeStrikes, i))
            end
        end
    end
end

--- Executa disparo de raio
--- @param enemies BaseEnemy[] Lista de inimigos
--- @param finalStats FinalStats Estatísticas finais do jogador
function Thunder:executeThunderStrike(enemies, finalStats)
    local playerPos = self.playerManager:getPlayerPosition()
    if not playerPos then return end

    -- Encontra alvos usando CombatHelpers otimizado
    local potentialTargets = self:findEnemiesInRadius(playerPos, self.currentConfig.range)

    if #potentialTargets == 0 then
        TablePool.releaseArray(potentialTargets)
        return
    end

    -- Seleciona alvos baseado em num_targets
    local selectedTargets = self:selectTargets(potentialTargets, self.currentConfig.num_targets)
    TablePool.releaseArray(potentialTargets)

    -- Aplica dano e cria efeitos visuais para cada alvo
    for _, target in ipairs(selectedTargets) do
        self:strikeTarget(target, self.currentConfig.damage)

        -- Processa chains se aplicável
        if self.currentConfig.chain_chance > 0 and math.random() < self.currentConfig.chain_chance then
            self:processChainLightning(target, self.currentConfig.damage, 0)
        end
    end

    TablePool.releaseArray(selectedTargets)
end

--- Seleciona alvos aleatórios da lista
--- @param targets BaseEnemy[] Lista de alvos potenciais
--- @param maxTargets number Número máximo de alvos
--- @return BaseEnemy[] Lista de alvos selecionados (do TablePool)
function Thunder:selectTargets(targets, maxTargets)
    local selected = TablePool.getArray()
    local targetCount = math.min(#targets, maxTargets)

    if targetCount <= 0 then return selected end

    -- Cria lista de índices para seleção aleatória
    local indices = TablePool.getArray()
    for i = 1, #targets do
        indices[i] = i
    end

    -- Seleciona alvos aleatórios
    for i = 1, targetCount do
        local randomIndex = math.random(1, #indices)
        local targetIndex = indices[randomIndex]
        table.insert(selected, targets[targetIndex])
        table.remove(indices, randomIndex)
    end

    TablePool.releaseArray(indices)
    return selected
end

--- Atinge um alvo específico com raio
--- @param target BaseEnemy Alvo a ser atingido
--- @param damage number Dano a aplicar
function Thunder:strikeTarget(target, damage)
    if not target or not target.position then return end

    -- Aplica dano usando método otimizado da BaseRune
    self:applyDamageToTarget(target, damage, "thunder")

    -- Cria efeito visual do raio
    local strike = TablePool.getGeneric()
    strike.x = target.position.x
    strike.y = target.position.y
    strike.timer = 0
    strike.currentFrame = 1
    strike.target = target

    table.insert(self.activeStrikes, strike)

    Logger.debug("thunder.strike",
        string.format("[Thunder:strikeTarget] Raio atingiu alvo na posição (%.1f, %.1f)", strike.x, strike.y))
end

--- Processa encadeamento de raios
--- @param sourceTarget BaseEnemy Alvo fonte do encadeamento
--- @param baseDamage number Dano base (será reduzido)
--- @param currentJumps number Número atual de saltos
function Thunder:processChainLightning(sourceTarget, baseDamage, currentJumps)
    if currentJumps >= self.currentConfig.chain_max_jumps then return end

    -- Encontra próximo alvo para o chain
    local chainTargets = self:findEnemiesInRadius(sourceTarget.position, self.currentConfig.range * 0.6)

    -- Remove alvos já atingidos neste chain
    local validTargets = TablePool.getArray()
    for _, target in ipairs(chainTargets) do
        if target ~= sourceTarget and not self:wasTargetHitInChain(target) then
            table.insert(validTargets, target)
        end
    end

    TablePool.releaseArray(chainTargets)

    if #validTargets > 0 then
        -- Seleciona alvo mais próximo
        local nextTarget = self:findClosestTarget(sourceTarget.position, validTargets)

        -- Calcula dano reduzido
        local chainDamage = baseDamage * (1 - self.currentConfig.chain_damage_reduction)

        -- Atinge próximo alvo
        self:strikeTarget(nextTarget, chainDamage)
        table.insert(self.lastTargets, nextTarget)

        -- Continua o chain recursivamente
        self:processChainLightning(nextTarget, chainDamage, currentJumps + 1)
    end

    TablePool.releaseArray(validTargets)
end

--- Verifica se alvo já foi atingido neste chain
--- @param target BaseEnemy Alvo a verificar
--- @return boolean True se já foi atingido
function Thunder:wasTargetHitInChain(target)
    for _, hitTarget in ipairs(self.lastTargets) do
        if hitTarget == target then return true end
    end
    return false
end

--- Encontra alvo mais próximo de uma posição
--- @param position Vector2D Posição de referência
--- @param targets BaseEnemy[] Lista de alvos
--- @return BaseEnemy|nil Alvo mais próximo
function Thunder:findClosestTarget(position, targets)
    local closest = nil
    local closestDistSq = math.huge

    for _, target in ipairs(targets) do
        if target.position then
            local dx = target.position.x - position.x
            local dy = target.position.y - position.y
            local distSq = dx * dx + dy * dy

            if distSq < closestDistSq then
                closestDistSq = distSq
                closest = target
            end
        end
    end

    return closest
end

--- Desenha os efeitos visuais da Thunder
function Thunder:draw()
    for _, strike in ipairs(self.activeStrikes) do
        self:drawAnimation(strike.x, strike.y)
    end
end

--- Executa a habilidade da Thunder (cast manual)
--- @param x number|nil Posição X (não usado pela Thunder)
--- @param y number|nil Posição Y (não usado pela Thunder)
--- @return boolean success True se executada com sucesso
function Thunder:cast(x, y)
    -- Thunder é automática, mas pode ser forçada
    if self.currentCooldown > 0 then return false end

    local enemies = self.playerManager.enemyManager:getAllEnemies()
    local finalStats = self.playerManager:getCurrentFinalStats()

    self:executeThunderStrike(enemies, finalStats)
    self.currentCooldown = self.currentConfig.cooldown

    return true
end

--- Limpa recursos específicos da Thunder
function Thunder:cleanup()
    -- Limpa arrays específicos
    if self.activeStrikes then
        for _, strike in ipairs(self.activeStrikes) do
            TablePool.releaseGeneric(strike)
        end
        TablePool.releaseArray(self.activeStrikes)
        self.activeStrikes = nil
    end

    if self.lastTargets then
        TablePool.releaseArray(self.lastTargets)
        self.lastTargets = nil
    end

    -- Chama cleanup da base
    BaseRune.cleanup(self)

    Logger.debug("thunder.cleanup", "[Thunder:cleanup] Recursos específicos da Thunder liberados")
end

return Thunder
