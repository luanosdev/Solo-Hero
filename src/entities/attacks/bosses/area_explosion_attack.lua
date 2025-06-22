-------------------------------------------------
--- Area Explosion Attack Ability
-------------------------------------------------
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local CameraEffects = require("src.utils.camera_effects")

---@class AreaExplosionParams
---@field telegraphDuration number Duração do aviso antes da explosão.
---@field explosionRadius number Raio da explosão.
---@field stunDuration number Duração do "stun" após o ataque.
---@field damage number Dano da habilidade.

---@class AreaExplosionAttack
---@field boss BaseBoss
---@field params AreaExplosionParams
---@field state string
---@field timer number
---@field cameraEffects CameraEffects
---@field playbackDirection number 1 para frente, -1 para trás
---@field damageApplied boolean
---@field attackFrameDelay number
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
    self.params = params
    self.state = STATE.TAUNT
    self.timer = 0
    self.playbackDirection = 1
    self.damageApplied = false
    self.attackFrameDelay = 0

    return self
end

--- Inicia a habilidade.
function AreaExplosionAttack:start()
    self.timer = 0
    self.state = STATE.TAUNT
    self.boss.isImmobile = true -- Impede o movimento normal do boss
    self.damageApplied = false
    self.playbackDirection = 1

    -- Inicia a animação de "taunt" e reseta para o primeiro frame.
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "taunt", self.boss.unitType, true)
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
        self:startStun() -- Failsafe se a animação não existir
        return
    end

    local attackFrameTime = animConfig.frameTimes.attack
    local attackMaxFrames = animAssets.maxFrames.attack
    local attackDuration = attackFrameTime * attackMaxFrames

    if self.timer >= attackDuration then
        self:startStun()
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
        playerManager:receiveDamage(self.params.damage, "ability")
    end

    self.cameraEffects:shake(0.5, 10) -- Duração de 0.5s, magnitude de 10
    self.damageApplied = true
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
