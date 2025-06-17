------------------------------------------------------------------------------
-- Flame Stream Ability
-- Gerencia a criação de um fluxo contínuo de partículas de fogo.
------------------------------------------------------------------------------

local FireParticle = require("src.entities.projectiles.fire_particle")
local ManagerRegistry = require("src.managers.manager_registry") -- Adicionado

---@class FlameStream
local FlameStream = {}
FlameStream.__index = FlameStream -- Necessário para métodos de instância
FlameStream.name = "Fluxo de Fogo"
FlameStream.description = "Atira um fluxo de chamas que causa dano em área."
FlameStream.damageType = "fire"
-- Configurações Visuais (podem ser movidas ou mantidas)
FlameStream.visual = {
    preview = {
        active = false,
        lineLength = 50
        -- color será definido no :new
    },
    attack = {
        particleSpeed = 150,            -- Velocidade lenta das partículas
        particleLifetime = 1.2,         -- Tempo de vida base (será recalculado)
        baseHitLoss = 0.8,              -- Valor padrão da perda na colisão (ex.: 80%)
        piercingReductionFactor = 0.01, -- Quanto piercing reduz do hitLoss (ex.: 1 piercing = 1%)
        minHitLoss = 0.2,               -- Perda mínima ao atingir (ex: 20%)
        baseScale = 0.8,                -- Escala base da partícula, pode ser ajustada pela arma
        strengthLifetimeFactor = 0.01   -- Cada ponto de força aumenta o lifetime em 1%
        -- color será definido no :new
    },
    multiAttack = {
        angleSpread = 5,            -- Graus de desvio para cada partícula extra
        colors = {                  -- Cores para partículas extras (índice = número de partículas extras - 1)
            { 0.2, 0.8, 1,   0.7 }, -- Azul claro
            { 0.2, 1,   0.2, 0.7 }, -- Verde claro
            { 1,   1,   1,   0.7 }  -- Branco
        }
    }
}

--- Cria uma nova instância da habilidade FlameStream.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon Instância da arma (Flamethrower) que está usando esta habilidade.
function FlameStream:new(playerManager, weaponInstance)
    local o = setmetatable({}, FlameStream) -- Cria a instância

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance
    o.cooldownRemaining = 0
    o.activeParticles = {} -- Tabela para guardar as partículas ativas

    -- Busca dados base da arma uma vez
    local baseData = o.weaponInstance:getBaseData()
    if not baseData then
        error(string.format("FlameStream:new - Falha ao obter dados base para %s",
            o.weaponInstance.itemBaseId or "arma desconhecida"))
    end
    o.baseDamage = baseData.damage -- Mantido, mas o dano final virá de finalStats.weaponDamage
    o.baseCooldown = baseData.cooldown
    o.baseRange = baseData.range
    o.baseAngleWidth = baseData.angle -- Armazena o ângulo base
    o.baseLifetime = baseData.lifetime or
        FlameStream.visual.attack
        .particleLifetime -- Usa o da arma ou o padrão da habilidade
    o.baseParticleScale = baseData.particleScale or
        FlameStream.visual.attack
        .baseScale -- Escala base da partícula vinda da arma

    -- Knockback properties from weapon
    o.knockbackPower = baseData.knockbackPower or 0
    o.knockbackForce = baseData.knockbackForce or 0

    -- Define cores (usando as da arma ou padrão)
    o.visual.preview.color = o.weaponInstance.previewColor or { 1, 0.5, 0, 0.2 }
    o.visual.attack.color = o.weaponInstance.attackColor or { 1, 0.3, 0, 0.7 }

    -- Inicializa valores que serão atualizados no update
    o.currentPosition = { x = 0, y = 0 }
    o.currentAngle = 0
    o.currentRange = o.baseRange
    o.currentAngleWidth = o.baseAngleWidth
    -- currentLifetime será calculado no primeiro update
    o.currentAreaMultiplier = 1.0 -- Adicionado para área
    o.currentPiercing = 0         -- Adicionado para piercing

    print("[FlameStream:new] Instância criada.")
    return o
end

function FlameStream:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza valores dinâmicos baseados no estado atual do jogador e da arma
    if not self.playerManager or not self.playerManager.player or not self.playerManager.player.position then
        error("[FlameStream:update] ERRO: Posição do jogador não disponível.")
    end
    self.currentPosition = self.playerManager.player.position
    self.currentAngle = angle -- Ângulo da mira

    local finalStats = self.playerManager:getCurrentFinalStats()
    if not finalStats then
        error("[FlameStream:update] ERRO: finalStats não disponíveis do PlayerManager.")
    end

    -- Calcula valores FINAIS para este frame
    local calculatedRange = self.baseRange and finalStats.range and (self.baseRange * finalStats.range)
    local calculatedAngleWidth = self.baseAngleWidth and finalStats.attackArea and
        (self.baseAngleWidth * finalStats.attackArea)
    local calculatedAreaMultiplier = finalStats.attackArea or 1.0 -- Multiplicador de área
    local calculatedPiercing = finalStats.piercing or 0           -- Pontos de Piercing
    local calculatedStrength = finalStats.strength or 0           -- Pontos de Força

    if calculatedRange == nil or calculatedRange <= 0 then
        -- print(string.format(
        --    "[FlameStream:update] AVISO: currentRange inválido (%s). Base: %s, FS.range: %s. Usando baseRange.",
        --    tostring(calculatedRange), tostring(self.baseRange), tostring(finalStats.range)))
        self.currentRange = self.baseRange -- Fallback para o valor base, mas logado como aviso
    else
        self.currentRange = calculatedRange
    end

    if calculatedAngleWidth == nil or calculatedAngleWidth <= 0 then
        -- print(string.format(
        --    "[FlameStream:update] AVISO: currentAngleWidth inválido (%s). Base: %s, FS.area: %s. Usando baseAngleWidth.",
        --    tostring(calculatedAngleWidth), tostring(self.baseAngleWidth), tostring(finalStats.attackArea)))
        self.currentAngleWidth = self.baseAngleWidth -- Fallback para o valor base
    else
        self.currentAngleWidth = calculatedAngleWidth
    end

    self.currentAreaMultiplier = calculatedAreaMultiplier -- Atualiza o multiplicador de área
    self.currentPiercing = calculatedPiercing             -- Atualiza o piercing

    -- Lifetime calculation based on range and speed, and now strength
    if not self.visual.attack.particleSpeed or self.visual.attack.particleSpeed <= 0 then
        error("[FlameStream:update] ERRO: particleSpeed inválido ou zero.")
        self.currentLifetime = self.baseLifetime -- Fallback para o lifetime base da arma/habilidade
    elseif self.currentRange and self.currentRange > 0 then
        local baseCalculatedLifetime = self.currentRange / self.visual.attack.particleSpeed
        local strengthMultiplier = 1 + (calculatedStrength * self.visual.attack.strengthLifetimeFactor)
        self.currentLifetime = baseCalculatedLifetime * strengthMultiplier
    else
        -- print("[FlameStream:update] AVISO: currentRange inválido para cálculo de lifetime. Usando baseLifetime.")
        self.currentLifetime = self.baseLifetime -- Fallback para o lifetime base da arma/habilidade
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

function FlameStream:cast(args)                            -- Cast é chamado muito rapidamente
    args = args or {}
    local baseAngle = args.angle or self.currentAngle or 0 -- Usa ângulo do arg, ou o último do update

    if self.cooldownRemaining > 0 then
        return false
    end

    local finalStats = self.playerManager:getCurrentFinalStats()
    if not finalStats then
        error("[FlameStream:cast] ERRO: finalStats não disponíveis do PlayerManager. Não é possível disparar.")
    end

    -- Aplica cooldown (considerando multiAttack para effectiveFireRate)
    -- effectiveFireRate = baseFireRate * (1 + multiAttack)
    -- Cooldown = baseCooldown / effectiveFireRate
    local multiAttackCount = math.floor(finalStats.multiAttack or 0)
    local effectiveFireRateMultiplier = 1 + multiAttackCount

    local totalAttackSpeed = finalStats.attackSpeed
    if not totalAttackSpeed or totalAttackSpeed <= 0 then
        error(string.format(
            "[FlameStream:cast] AVISO: totalAttackSpeed inválido (%s). Usando fallback de 0.01.",
            tostring(totalAttackSpeed)))
        totalAttackSpeed = 0.01 -- Fallback para evitar divisão por zero
    end

    if self.baseCooldown and totalAttackSpeed then
        -- O cooldown base já deve refletir 1 disparo. multiAttack aumenta a cadência.
        -- Se multiAttack significa mais partículas POR disparo, o cooldown não muda.
        -- Se multiAttack aumenta a frequência dos disparos em si, então o cooldown é reduzido.
        -- Pela descrição "Aumenta a cadência: effectiveFireRate = baseFireRate * (1 + multiAttack)"
        -- E "Cada inteiro de multiAttack gera uma partícula extra por disparo."
        -- Parece que são duas coisas: cadência maior E mais projéteis por rajada.
        -- Vamos assumir que attackSpeed afeta o cooldown entre rajadas, e multiAttack as partículas por rajada.
        self.cooldownRemaining = self.baseCooldown / totalAttackSpeed
    else
        error(string.format(
            "[FlameStream:cast] ERRO: baseCooldown (%s) ou totalAttackSpeed processado (%s) é nil/inválido. Cooldown não aplicado.",
            tostring(self.baseCooldown), tostring(totalAttackSpeed)))
        self.cooldownRemaining = 2 -- Cooldown de emergência
    end

    -- Calcula atributos no momento do disparo
    local damagePerParticle = finalStats.weaponDamage
    local criticalChance = finalStats.critChance
    local criticalMultiplier = finalStats.critDamage

    if damagePerParticle == nil then
        error("[FlameStream:cast] ERRO: finalStats.weaponDamage é nil. Não é possível calcular o dano da partícula.")
    end
    if criticalChance == nil then
        error("[FlameStream:cast] AVISO: finalStats.critChance é nil. Chance de crítico será 0.")
    end
    if criticalMultiplier == nil then
        error("[FlameStream:cast] AVISO: finalStats.critDamage é nil. Multiplicador de crítico será 1.")
    end

    -- Referência ao SpatialGrid
    local enemyManager = ManagerRegistry:get("enemyManager")
    if not enemyManager then error("FlameStream:cast - enemyManager não encontrado via ManagerRegistry.") end
    local spatialGrid = enemyManager.spatialGrid
    if not spatialGrid then
        error("FlameStream:cast - spatialGrid não encontrado no enemyManager.")
    end

    -- Número de partículas a serem criadas (1 base + extras do multiAttack)
    local numParticlesToSpawn = 1 + multiAttackCount

    for i = 1, numParticlesToSpawn do
        local particleAngleOffset = 0
        local particleColor = self.visual.attack.color

        if i > 1 then -- Esta é uma partícula extra do multiAttack
            -- Calcula desvio angular para partículas extras
            -- Ex: para 2 extras (i=2, i=3), desvios de +spread, -spread. Para 3 (i=2,3,4), +s, -s, +2s etc.
            -- Uma forma simples: alternar lados e aumentar o desvio
            local spreadDirection = (i % 2 == 0) and 1 or -1 -- Alterna direção
            local spreadMagnitude = math.ceil((i - 1) / 2)   -- Aumenta magnitude a cada par
            particleAngleOffset = math.rad(self.visual.multiAttack.angleSpread * spreadMagnitude * spreadDirection)

            -- Define cor alternativa para partículas extras
            local colorIndex = (i - 2) % #self.visual.multiAttack.colors + 1
            particleColor = self.visual.multiAttack.colors[colorIndex] or self.visual.attack.color
        else
            -- Partícula principal: pequena dispersão aleatória original
            local halfWidth = (self.currentAngleWidth or self.baseAngleWidth or 0) / 2
            particleAngleOffset = math.random() * halfWidth - math.random() * halfWidth
        end

        local particleAngle = baseAngle + particleAngleOffset

        local isCritical = (criticalChance or 0) > 0 and (math.random() <= (criticalChance or 0))
        local finalDamage = damagePerParticle
        if isCritical then
            finalDamage = math.floor(finalDamage * (criticalMultiplier or 1))
        end

        local startDist = (self.playerManager.radius or 10) * 1.2 -- Adicionado fallback para playerManager.radius
        local startX = self.currentPosition.x + math.cos(particleAngle) * startDist
        local startY = self.currentPosition.y + math.sin(particleAngle) * startDist

        if not self.currentLifetime or self.currentLifetime <= 0 then
            error(string.format(
                "[FlameStream:cast] ERRO: currentLifetime inválido (%s) para partícula %d. Não é possível criar.",
                tostring(self.currentLifetime), i))
            goto continue_loop -- Pula para a próxima iteração do loop
        end

        -- Cria a partícula de fogo
        local particle = FireParticle:new({
            x = self.currentPosition.x,
            y = self.currentPosition.y,
            angle = particleAngle,
            speed = self.visual.attack.particleSpeed,
            lifetime = self.currentLifetime,
            damage = finalDamage,
            isCritical = isCritical,
            owner = self.playerManager.player,    -- Para referência, se necessário
            playerManager = self.playerManager,   -- Para stats e callbacks
            weaponInstance = self.weaponInstance, -- Para callbacks como onHit
            color = particleColor,
            scale = self.baseParticleScale * (self.currentAreaMultiplier or 1.0),
            piercing = self.currentPiercing, -- Passa o piercing calculado
            spatialGrid = spatialGrid,       -- Passa o spatialGrid
            baseHitLoss = self.visual.attack.baseHitLoss,
            piercingReductionFactor = self.visual.attack.piercingReductionFactor,
            minHitLoss = self.visual.attack.minHitLoss,
            knockbackPower = self.knockbackPower,     -- Passa o knockback power da arma/habilidade
            knockbackForce = self.knockbackForce,     -- Passa o knockback force da arma/habilidade
            playerStrength = finalStats.strength or 0 -- Passa a força atual do jogador
        })

        if particle then
            table.insert(self.activeParticles, particle)
        end

        ::continue_loop::
    end

    return true
end

function FlameStream:draw()
    -- Desenha a prévia (um cone estreito)
    if self.visual.preview.active then
        if self.currentPosition and self.currentRange and self.currentAngle and self.currentAngleWidth then
            self:drawPreviewCone(self.visual.preview.color) -- Passa a cor correta
        end
    end

    -- Desenha as partículas ativas
    for _, particle in ipairs(self.activeParticles) do
        particle:draw()
    end
end

function FlameStream:drawPreviewCone(color)
    -- local segments = 16 -- Não usado para linhas
    love.graphics.setColor(color)
    -- Usa os valores atuais calculados em update
    local cx, cy = self.currentPosition.x, self.currentPosition.y
    local range = self.currentRange
    local angle = self.currentAngle
    local halfAngleWidth = self.currentAngleWidth / 2

    local startAnglePreview = angle - halfAngleWidth
    local endAnglePreview = angle + halfAngleWidth

    love.graphics.line(cx, cy, cx + range * math.cos(startAnglePreview), cy + range * math.sin(startAnglePreview))
    love.graphics.line(cx, cy, cx + range * math.cos(endAnglePreview), cy + range * math.sin(endAnglePreview))
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
