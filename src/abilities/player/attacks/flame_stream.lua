--[[----------------------------------------------------------------------------
    Flame Stream Ability
    Gerencia a criação de um fluxo contínuo de partículas de fogo.
----------------------------------------------------------------------------]] --
local FireParticle = require("src.projectiles.fire_particle")                  -- Precisaremos criar este arquivo

---@class FlameStream
local FlameStream = {}
FlameStream.__index = FlameStream -- Necessário para métodos de instância

-- Configurações Visuais (podem ser movidas ou mantidas)
FlameStream.visual = {
    preview = {
        active = false,
        lineLength = 50
        -- color será definido no :new
    },
    attack = {
        particleSpeed = 150,   -- Velocidade lenta das partículas
        particleLifetime = 1.2 -- Tempo de vida base (será recalculado)
        -- color será definido no :new
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
        return nil                 -- Retorna nil em caso de erro
    end
    o.baseDamage = baseData.damage -- Mantido, mas o dano final virá de finalStats.weaponDamage
    o.baseCooldown = baseData.cooldown
    o.baseRange = baseData.range
    o.baseAngleWidth = baseData.angle -- Armazena o ângulo base

    -- Define cores (usando as da arma ou padrão)
    o.visual.preview.color = o.weaponInstance.previewColor or { 1, 0.5, 0, 0.2 }
    o.visual.attack.color = o.weaponInstance.attackColor or { 1, 0.3, 0, 0.7 }

    -- Inicializa valores que serão atualizados no update
    o.currentPosition = { x = 0, y = 0 }
    o.currentAngle = 0
    o.currentRange = o.baseRange
    o.currentAngleWidth = o.baseAngleWidth
    -- currentLifetime será calculado no primeiro update

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

    if not self.visual.attack.particleSpeed or self.visual.attack.particleSpeed <= 0 then
        error("[FlameStream:update] ERRO: particleSpeed inválido ou zero.")
        self.currentLifetime = 1 -- Fallback de lifetime
    elseif self.currentRange and self.currentRange > 0 then
        self.currentLifetime = self.currentRange / self.visual.attack.particleSpeed
    else
        -- print("[FlameStream:update] AVISO: currentRange inválido para cálculo de lifetime. Usando lifetime de 1s.")
        self.currentLifetime = 1 -- Fallback de lifetime
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
        return false
    end

    -- Aplica cooldown
    local totalAttackSpeed = finalStats.attackSpeed
    if not totalAttackSpeed or totalAttackSpeed <= 0 then
        print(string.format(
            "[FlameStream:cast] AVISO: totalAttackSpeed inválido (%s). Usando fallback de 0.01.",
            tostring(totalAttackSpeed)))
        totalAttackSpeed = 0.01 -- Evita divisão por zero, mas é um erro de stat
    end
    if self.baseCooldown and totalAttackSpeed then
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
        return false -- Não dispara se o dano não puder ser calculado
    end
    if criticalChance == nil then
        print("[FlameStream:cast] AVISO: finalStats.critChance é nil. Chance de crítico será 0.")
        criticalChance = 0
    end
    if criticalMultiplier == nil then
        print("[FlameStream:cast] AVISO: finalStats.critDamage é nil. Multiplicador de crítico será 1.")
        criticalMultiplier = 1 -- Dano crítico não terá efeito
    end

    -- Calcula o ângulo da partícula com uma pequena dispersão aleatória dentro de currentAngleWidth
    local halfWidth = (self.currentAngleWidth or self.baseAngleWidth or 0) / 2 -- Usa o valor atualizado ou fallback
    local particleAngleOffset = math.random() * halfWidth - math.random() * halfWidth
    local particleAngle = baseAngle + particleAngleOffset

    -- Calcula se é crítico (por partícula)
    local isCritical = criticalChance > 0 and (math.random() <= criticalChance) -- Ajustado para usar fração
    local finalDamage = damagePerParticle
    if isCritical then
        finalDamage = math.floor(finalDamage * criticalMultiplier)
    end

    -- Calcula a posição inicial da partícula (à frente do jogador, na borda do raio)
    -- self.playerManager.radius é o raio de colisão do player, não um stat de alcance.
    local startDist = (self.playerManager.radius or 10) * 1.2 -- Fallback para radius se não existir
    local startX = self.currentPosition.x + math.cos(particleAngle) * startDist
    local startY = self.currentPosition.y + math.sin(particleAngle) * startDist

    -- Verifica se currentLifetime é válido antes de criar a partícula
    if not self.currentLifetime or self.currentLifetime <= 0 then
        error(string.format("[FlameStream:cast] ERRO: currentLifetime inválido (%s). Não é possível criar partícula.",
            tostring(self.currentLifetime)))
        return false
    end

    -- Cria a partícula de fogo a partir da posição inicial calculada
    local particle = FireParticle:new(
        startX, startY,                   -- Usa as coordenadas iniciais calculadas
        particleAngle,                    -- Usa o ângulo disperso calculado
        self.visual.attack.particleSpeed, -- particleSpeed é da config da habilidade, não um stat do jogador
        self.currentLifetime,             -- Usa o lifetime atualizado
        finalDamage,                      -- Dano final calculado
        isCritical,
        self.playerManager.enemyManager,
        self.visual.attack.color
    )
    table.insert(self.activeParticles, particle)

    -- Multi-ataque não implementado para lança-chamas, a alta cadência faz o trabalho.

    return true
end

function FlameStream:draw()
    -- Desenha a prévia (um cone estreito)
    if self.visual.preview.active then
        if self.currentPosition and self.currentRange and self.currentAngle and self.currentAngleWidth then
            self:drawPreviewCone(self.visual.preview.color) -- Passa a cor correta
        else
            -- print("[FlameStream:draw] AVISO: Não é possível desenhar preview, dados de posição/dimensão ausentes.")
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
