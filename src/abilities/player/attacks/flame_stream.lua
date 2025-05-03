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
        return nil -- Retorna nil em caso de erro
    end
    o.baseDamage = baseData.damage
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
    o.currentLifetime = o.currentRange / o.visual.attack.particleSpeed

    print("[FlameStream:new] Instância criada.")
    return o
end

function FlameStream:update(dt, angle)
    -- Atualiza cooldown
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Atualiza valores dinâmicos baseados no estado atual do jogador e da arma
    self.currentPosition = self.playerManager.player.position
    self.currentAngle = angle -- Ângulo da mira

    -- Busca dados base novamente? Ou confiar nos armazenados?
    -- Por ora, vamos recalcular com base nos armazenados + bônus.
    -- Se os stats BASE da arma pudessem mudar, precisaríamos buscar self.weaponInstance:getBaseData() aqui.
    local state = self.playerManager.state
    local areaBonus = state:getTotalArea()
    local rangeBonus = state:getTotalRange() -- Supondo que getTotalRange retorna bônus percentual

    -- Calcula valores FINAIS para este frame
    self.currentRange = self.baseRange * (1 + rangeBonus)
    self.currentAngleWidth = self.baseAngleWidth *
    (1 + areaBonus)                                                             -- Correção: Aplica bônus como multiplicador
    self.currentLifetime = self.currentRange / self.visual.attack.particleSpeed -- Recalcula lifetime com range final

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

    -- Aplica cooldown (já é muito baixo)
    local attackSpeed = self.playerManager.state:getTotalAttackSpeed()
    self.cooldownRemaining = self.baseCooldown / attackSpeed

    -- Calcula atributos no momento do disparo
    local damagePerParticle = self.playerManager.state:getTotalDamage(self.baseDamage)
    local criticalChance = self.playerManager.state:getTotalCritChance()
    local criticalMultiplier = self.playerManager.state:getTotalDamageMultiplier()

    -- Calcula o ângulo da partícula com uma pequena dispersão aleatória dentro de currentAngleWidth
    local halfWidth = self.currentAngleWidth / 2 -- Usa o valor atualizado
    local particleAngle = baseAngle + math.random() * halfWidth -
        math.random() * halfWidth                -- Renomeado para evitar confusão

    -- Calcula se é crítico (por partícula)
    local isCritical = math.random() * 100 <= criticalChance
    local damage = damagePerParticle
    if isCritical then
        damage = math.floor(damage * criticalMultiplier)
    end

    -- Calcula a posição inicial da partícula (à frente do jogador, na borda do raio)
    local startDist = self.playerManager.radius * 1.2
    local startX = self.currentPosition.x + math.cos(particleAngle) * startDist -- Usa a posição e angulo atualizados
    local startY = self.currentPosition.y + math.sin(particleAngle) * startDist -- Usa a posição e angulo atualizados

    -- Cria a partícula de fogo a partir da posição inicial calculada
    local particle = FireParticle:new(
        startX, startY,       -- Usa as coordenadas iniciais calculadas
        particleAngle,        -- Usa o ângulo disperso calculado
        self.visual.attack.particleSpeed,
        self.currentLifetime, -- Usa o lifetime atualizado
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
    -- Não precisa mais checar self.area

    -- Desenha a prévia (um cone estreito)
    if self.visual.preview.active then
        self:drawPreviewCone(self.visual.preview.color) -- Passa a cor correta
    end

    -- Desenha as partículas ativas
    for _, particle in ipairs(self.activeParticles) do
        particle:draw()
    end
end

function FlameStream:drawPreviewCone(color)
    local segments = 16
    love.graphics.setColor(color)
    -- Usa os valores atuais calculados em update
    local cx, cy = self.currentPosition.x, self.currentPosition.y
    local range = self.currentRange
    local startAngle = self.currentAngle - self.currentAngleWidth / 2
    local endAngle = self.currentAngle + self.currentAngleWidth / 2

    -- love.graphics.arc("line", "open", cx, cy, range, startAngle, endAngle, segments) -- Comentado para remover o arco
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
