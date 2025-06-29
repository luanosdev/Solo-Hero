-------------------------------------------------
--- Area Explosion Attack Ability
-------------------------------------------------
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local CameraEffects = require("src.utils.camera_effects")

---@class AreaExplosionParams
---@field telegraphDuration number Duração do aviso antes da explosão.
---@field explosionRadius number Raio da explosão.
---@field stunDuration number Duração do "stun" após o ataque.
---@field damageMultiplier number Multiplicador de dano baseado no dano do boss.
---@field followUpChances table Array de chances para cada follow-up (ex: {0.8, 0.5}).
---@field followUpRadiusIncrease number Multiplicador do aumento do raio (ex: 1.2 para 20%).
---@field followUpStunIncrease number Segundos a adicionar ao stun por follow-up.
---@field telegraphReductionPerFollowUp number|nil Redução do tempo de telegraph por follow-up (padrão: 0.15).
---@field lowHealthSpeedMultiplier number|nil Multiplicador de velocidade quando vida < 50% (padrão: 0.5).

---@class AreaExplosionAttack
---@field boss BaseBoss
---@field params AreaExplosionParams Cópia local dos parâmetros para modificação.
---@field originalParams AreaExplosionParams Parâmetros originais e imutáveis.
---@field state string
---@field timer number
---@field cameraEffects CameraEffects
---@field playbackDirection number 1 para frente, -1 para trás
---@field damageApplied boolean
---@field attackFrameDelay number
---@field followUpCount number Contador de follow-ups executados.
local AreaExplosionAttack = {}
AreaExplosionAttack.__index = AreaExplosionAttack

-- Estados da habilidade
local STATE = {
    TAUNT = "taunt",
    ATTACK = "attack",
    STUNNED = "stunned",
    DONE = "done"
}

--- Constructor
--- @param boss BaseBoss A instância do boss que está usando a habilidade.
--- @param params AreaExplosionParams Parâmetros da habilidade.
--- @return AreaExplosionAttack
function AreaExplosionAttack:new(boss, params)
    local self = setmetatable({}, AreaExplosionAttack)

    self.cameraEffects = CameraEffects:new()
    self.boss = boss
    -- Armazena os parâmetros originais e cria uma cópia para ser modificada durante a execução.
    self.originalParams = params
    self.params = {}
    for k, v in pairs(params) do
        self.params[k] = v
    end

    self.state = STATE.TAUNT
    self.timer = 0
    self.playbackDirection = 1
    self.damageApplied = false
    self.attackFrameDelay = 0
    self.followUpCount = 0

    return self
end

--- Inicia a habilidade.
function AreaExplosionAttack:start()
    self.timer = 0
    self.state = STATE.TAUNT
    self.boss.isImmobile = true
    self.damageApplied = false
    self.playbackDirection = 1
    self.followUpCount = 0

    -- Reseta os parâmetros para os valores originais no início de uma nova sequência.
    self.params.explosionRadius = self.originalParams.explosionRadius
    self.params.stunDuration = self.originalParams.stunDuration
    self.params.telegraphDuration = self.originalParams.telegraphDuration

    -- Aplica modificadores baseados no estado do boss
    self:applyBossStateModifiers()

    -- Inicia a animação de "taunt" e reseta para o primeiro frame.
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "taunt", self.boss.unitType, true)
end

--- Aplica modificadores baseados no estado atual do boss (vida baixa, etc).
function AreaExplosionAttack:applyBossStateModifiers()
    -- Verifica se o boss está com vida baixa (< 50%)
    local isLowHealth = false
    if self.boss.currentHealth and self.boss.maxHealth then
        isLowHealth = (self.boss.currentHealth / self.boss.maxHealth) < 0.5
    end

    -- Se vida baixa, aplica multiplicador de velocidade
    if isLowHealth then
        local speedMultiplier = self.originalParams.lowHealthSpeedMultiplier or 0.5
        self.params.telegraphDuration = self.originalParams.telegraphDuration * speedMultiplier
        self.params.stunDuration = self.originalParams.stunDuration * speedMultiplier
    end
end

--- Atualiza a lógica da habilidade.
--- @param dt number Delta time.
--- @param playerManager PlayerManager O gerenciador do jogador.
function AreaExplosionAttack:update(dt, playerManager)
    self.timer = self.timer + dt

    if self.state == STATE.TAUNT then
        self:updateTaunt(dt)
        if self.timer >= self.params.telegraphDuration then
            self:startAttack(playerManager)
        end
    elseif self.state == STATE.ATTACK then
        self:updateAttack(dt, playerManager)
    elseif self.state == STATE.STUNNED then
        if self.timer >= self.params.stunDuration then
            self:finish()
        end
    end
end

--- Atualiza a animação de "taunt" com efeito ping-pong.
--- @param dt number Delta time
function AreaExplosionAttack:updateTaunt(dt)
    local animConfig = AnimatedSpritesheet.configs[self.boss.unitType]
    local animAssets = AnimatedSpritesheet.assets[self.boss.unitType]
    if not animConfig or not animAssets or not animConfig.frameTimes.taunt or not animAssets.maxFrames.taunt then
        return
    end

    local tauntFrameTime = animConfig.frameTimes.taunt
    local tauntMaxFrames = animAssets.maxFrames.taunt

    self.boss.sprite.animation.timer = self.boss.sprite.animation.timer + dt
    while self.boss.sprite.animation.timer >= tauntFrameTime do
        self.boss.sprite.animation.timer = self.boss.sprite.animation.timer - tauntFrameTime

        local currentFrame = self.boss.sprite.animation.currentFrame + self.playbackDirection
        if currentFrame > tauntMaxFrames then
            currentFrame = tauntMaxFrames
            self.playbackDirection = -1
        elseif currentFrame < 1 then
            currentFrame = 1
            self.playbackDirection = 1
        end
        self.boss.sprite.animation.currentFrame = currentFrame
    end
end

--- Inicia a fase de ataque.
--- @param playerManager PlayerManager
function AreaExplosionAttack:startAttack(playerManager)
    self.state = STATE.ATTACK
    self.timer = 0
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "attack", self.boss.unitType, true)

    local animConfig = AnimatedSpritesheet.configs[self.boss.unitType]
    if not animConfig or not animConfig.frameTimes.attack then return end

    -- Calcula o delay para o dano no 9º frame (8 intervalos de frame).
    local attackFrameTime = animConfig.frameTimes.attack
    self.attackFrameDelay = attackFrameTime * 8
end

--- Atualiza a lógica do ataque, verifica dano e fim da animação.
--- @param dt number
--- @param playerManager PlayerManager
function AreaExplosionAttack:updateAttack(dt, playerManager)
    if not self.damageApplied and self.timer >= self.attackFrameDelay then
        self:applyDamageAndEffects(playerManager)
    end

    local animConfig = AnimatedSpritesheet.configs[self.boss.unitType]
    local animAssets = AnimatedSpritesheet.assets[self.boss.unitType]
    if not animConfig or not animAssets or not animConfig.frameTimes.attack or not animAssets.maxFrames.attack then
        self:decideNextAction() -- Failsafe se a animação não existir
        return
    end

    local attackFrameTime = animConfig.frameTimes.attack
    local attackMaxFrames = animAssets.maxFrames.attack
    local attackDuration = attackFrameTime * attackMaxFrames

    if self.timer >= attackDuration then
        self:decideNextAction()
    end
end

--- Aplica dano e efeitos visuais.
--- @param playerManager PlayerManager
function AreaExplosionAttack:applyDamageAndEffects(playerManager)
    local playerPos = playerManager:getCollisionPosition().position
    local dx = playerPos.x - self.boss.position.x
    local dy = playerPos.y - self.boss.position.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance <= self.params.explosionRadius then
        local calculatedDamage = self.boss.damage * self.params.damageMultiplier
        local damageSource = {
            name = self.boss.name,
            isBoss = true,
            isMVP = false,
            unitType = self.boss.unitType
        }
        playerManager:receiveDamage(calculatedDamage, damageSource)
    end

    self.cameraEffects:shake(0.5, 10) -- Duração de 0.5s, magnitude de 10
    self.damageApplied = true
end

--- Decide se executa um follow-up ou entra em stun.
function AreaExplosionAttack:decideNextAction()
    local chances = self.params.followUpChances or {}
    local maxFollowUps = #chances

    if self.followUpCount < maxFollowUps then
        local chance = chances[self.followUpCount + 1]
        if math.random() < chance then
            self:startFollowUp()
            return -- Sai da função para iniciar o follow-up
        end
    end

    -- Se não houver follow-up, calcula o stun final e inicia o estado.
    local stunIncrease = self.params.followUpStunIncrease or 1
    self.params.stunDuration = self.originalParams.stunDuration + (self.followUpCount * stunIncrease)
    self:startStun()
end

--- Inicia um ataque de follow-up.
function AreaExplosionAttack:startFollowUp()
    self.followUpCount = self.followUpCount + 1

    -- Aumenta o raio do ataque de forma cumulativa
    local radiusMultiplier = self.params.followUpRadiusIncrease or 1.2
    self.params.explosionRadius = self.params.explosionRadius * radiusMultiplier

    -- Reduz o tempo de telegraph baseado no número de follow-ups
    local telegraphReduction = self.originalParams.telegraphReductionPerFollowUp or 0.15
    local newTelegraphDuration = self.originalParams.telegraphDuration - (self.followUpCount * telegraphReduction)
    -- Garante um tempo mínimo de telegraph
    self.params.telegraphDuration = math.max(newTelegraphDuration, 0.3)

    -- Aplica modificadores do estado do boss (vida baixa)
    self:applyBossStateModifiers()

    -- Reinicia o estado para um novo ciclo de telegraph -> attack
    self.timer = 0
    self.state = STATE.TAUNT
    self.damageApplied = false
    self.playbackDirection = 1

    -- A animação de taunt é reiniciada para o novo ciclo
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "taunt", self.boss.unitType, true)
end

--- Inicia a fase de stun.
function AreaExplosionAttack:startStun()
    self.state = STATE.STUNNED
    self.timer = 0
    -- Retorna para a animação "idle"
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "idle", self.boss.unitType)
end

--- Finaliza a habilidade.
function AreaExplosionAttack:finish()
    self.state = STATE.DONE
    self.boss.isImmobile = false -- Permite que o boss se mova novamente
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "walk", self.boss.unitType)
end

--- Desenha a prévia do ataque (o círculo de expansão).
function AreaExplosionAttack:draw()
    if self.state == STATE.TAUNT then
        local expansionRatio = math.min(self.timer / self.params.telegraphDuration, 1.0)
        local currentRadius = self.params.explosionRadius * expansionRatio

        love.graphics.setColor(1, 0, 0, 0.3) -- Vermelho translúcido
        love.graphics.circle("fill", self.boss.position.x, self.boss.position.y, currentRadius)
        love.graphics.setColor(1, 1, 1, 1)
    elseif self.state == STATE.ATTACK then
        local radius = self.params.explosionRadius
        if not self.damageApplied then
            love.graphics.setColor(1, 0, 0, 0.3) -- Translúcido antes do dano
        else
            love.graphics.setColor(1, 0, 0, 1)   -- Opaco após o dano
        end
        love.graphics.circle("fill", self.boss.position.x, self.boss.position.y, radius)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

--- Retorna se a habilidade terminou.
---@return boolean
function AreaExplosionAttack:isDone()
    return self.state == STATE.DONE
end

return AreaExplosionAttack
