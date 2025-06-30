-------------------------------------------------
--- Charging Run Attack Ability
-------------------------------------------------
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")

---@class ChargingRunParams
---@field telegraphDuration number Duração da animação "taunt" e do aviso.
---@field initialSpeedMultiplier number Multiplicador de velocidade inicial.
---@field maxSpeedMultiplier number Multiplicador de velocidade máxima.
---@field accelerationRate number Taxa de aceleração por segundo.
---@field maxTurnAngle number Ângulo máximo de curva por segundo (em radianos).
---@field stunDuration number Duração do "stun" após o ataque.
---@field damageMultiplier number Multiplicador de dano baseado no dano do boss.
---@field maxChargeDuration number Duração máxima da corrida antes de parar automaticamente.
---@field followUpChance number Chance de fazer follow-up após perder o jogador.
---@field followUpDistance number Distância mínima do jogador para ativar follow-up.
---@field followUpTurnMultiplier number Multiplicador do ângulo de curva no follow-up.
---@field playerDetectionRadius number Raio para detectar colisão com o jogador.

---@class ChargingRunAttack
---@field boss BaseBoss
---@field params ChargingRunParams
---@field originalParams ChargingRunParams
---@field state string
---@field timer number
---@field currentSpeed number
---@field currentAngle number Ângulo atual de movimento em radianos
---@field hitPlayer boolean
---@field followUpActive boolean
---@field targetPosition table Posição alvo para animação
local ChargingRunAttack = {}
ChargingRunAttack.__index = ChargingRunAttack

-- Estados da habilidade
local STATE = {
    TELEGRAPH = "telegraph",
    CHARGING = "charging",
    STUNNED = "stunned",
    DONE = "done"
}

--- Constructor
--- @param boss BaseBoss A instância do boss que está usando a habilidade.
--- @param params ChargingRunParams Parâmetros da habilidade.
--- @return ChargingRunAttack
function ChargingRunAttack:new(boss, params)
    local self = setmetatable({}, ChargingRunAttack)

    self.boss = boss
    self.originalParams = params
    self.params = {}
    for k, v in pairs(params) do
        self.params[k] = v
    end

    self.state = STATE.TELEGRAPH
    self.timer = 0
    self.currentSpeed = 0
    self.currentAngle = 0
    self.hitPlayer = false
    self.followUpActive = false
    self.targetPosition = { x = 0, y = 0 }

    return self
end

--- Inicia a habilidade.
--- @param playerManager PlayerManager O gerenciador do jogador.
function ChargingRunAttack:start(playerManager)
    self.timer = 0
    self.state = STATE.TELEGRAPH
    self.boss.isImmobile = true
    self.hitPlayer = false
    self.followUpActive = false

    -- Calcula o ângulo inicial em direção ao jogador
    local playerPos = playerManager:getCollisionPosition().position
    local dx = playerPos.x - self.boss.position.x
    local dy = playerPos.y - self.boss.position.y
    self.currentAngle = math.atan2(dy, dx)

    -- Define o target position inicial para animação
    local range = 200
    self.targetPosition.x = self.boss.position.x + math.cos(self.currentAngle) * range
    self.targetPosition.y = self.boss.position.y + math.sin(self.currentAngle) * range

    -- Inicia velocidade no valor inicial
    self.currentSpeed = self.params.initialSpeedMultiplier

    -- Toca a animação de "taunt"
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "taunt", self.boss.unitType)
end

--- Atualiza a lógica da habilidade.
--- @param dt number Delta time.
--- @param playerManager PlayerManager O gerenciador do jogador.
function ChargingRunAttack:update(dt, playerManager)
    self.timer = self.timer + dt

    if self.state == STATE.TELEGRAPH then
        if self.timer >= self.params.telegraphDuration then
            self:startCharging()
        end
    elseif self.state == STATE.CHARGING then
        self:updateCharging(dt, playerManager)

        -- Verifica se excedeu a duração máxima
        if self.timer >= self.params.maxChargeDuration then
            self:startStun()
        end
    elseif self.state == STATE.STUNNED then
        if self.timer >= self.params.stunDuration then
            self:finish()
        end
    end
end

--- Inicia a fase de corrida.
function ChargingRunAttack:startCharging()
    self.state = STATE.CHARGING
    self.timer = 0
    self.boss.isImmobile = false

    -- Toca a animação de "run"
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "run", self.boss.unitType)
end

--- Atualiza a lógica da corrida.
--- @param dt number Delta time.
--- @param playerManager PlayerManager O gerenciador do jogador.
function ChargingRunAttack:updateCharging(dt, playerManager)
    local playerPos = playerManager:getCollisionPosition().position

    -- Acelera a velocidade gradualmente até o máximo
    if self.currentSpeed < self.params.maxSpeedMultiplier then
        self.currentSpeed = math.min(
            self.currentSpeed + self.params.accelerationRate * dt,
            self.params.maxSpeedMultiplier
        )
    end

    -- Calcula o ângulo desejado em direção ao jogador
    local dx = playerPos.x - self.boss.position.x
    local dy = playerPos.y - self.boss.position.y
    local desiredAngle = math.atan2(dy, dx)

    -- Calcula a diferença angular considerando a continuidade circular
    local angleDiff = desiredAngle - self.currentAngle

    -- Normaliza a diferença para o range [-π, π]
    while angleDiff > math.pi do
        angleDiff = angleDiff - 2 * math.pi
    end
    while angleDiff < -math.pi do
        angleDiff = angleDiff + 2 * math.pi
    end

    -- Aplica limitação do ângulo de curva
    local maxTurnThisFrame = self.params.maxTurnAngle * dt
    if self.followUpActive then
        maxTurnThisFrame = maxTurnThisFrame * self.params.followUpTurnMultiplier
    end

    local actualTurn = math.max(-maxTurnThisFrame, math.min(maxTurnThisFrame, angleDiff))
    self.currentAngle = self.currentAngle + actualTurn

    -- Atualiza o target position para animação baseado na direção atual
    local range = 200
    self.targetPosition.x = self.boss.position.x + math.cos(self.currentAngle) * range
    self.targetPosition.y = self.boss.position.y + math.sin(self.currentAngle) * range

    -- Move o boss na direção atual
    local speed = self.boss.speed * self.currentSpeed
    local moveX = math.cos(self.currentAngle) * speed * dt
    local moveY = math.sin(self.currentAngle) * speed * dt

    self.boss.position.x = self.boss.position.x + moveX
    self.boss.position.y = self.boss.position.y + moveY

    -- Verifica colisão com o jogador
    if not self.hitPlayer then
        local distanceToPlayer = math.sqrt(dx * dx + dy * dy)
        if distanceToPlayer <= (self.params.playerDetectionRadius or self.boss.radius * 2) then
            self.hitPlayer = true
            local calculatedDamage = self.boss.damage * self.params.damageMultiplier
            local damageSource = {
                name = self.boss.name,
                isBoss = true,
                isMVP = false,
                unitType = self.boss.unitType
            }
            playerManager:receiveDamage(calculatedDamage, damageSource)
            self:startStun()
            return
        end
    end

    -- Verifica se deve ativar follow-up (sem parar o ataque)
    if not self.followUpActive and not self.hitPlayer then
        local distanceToPlayer = math.sqrt(dx * dx + dy * dy)
        if distanceToPlayer > self.params.followUpDistance then
            if math.random() < self.params.followUpChance then
                self.followUpActive = true
                Logger.info("charging_run_attack.update.follow_up_activated",
                    "[ChargingRunAttack:updateCharging] Follow-up ativado - distância: " .. distanceToPlayer)
            end
            -- Não para o ataque, continua correndo até atingir duração máxima
        end
    end
end

--- Inicia a fase de stun.
function ChargingRunAttack:startStun()
    self.state = STATE.STUNNED
    self.timer = 0
    self.boss.isImmobile = true

    -- Retorna para a animação "idle"
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "idle", self.boss.unitType)
end

--- Finaliza a habilidade.
function ChargingRunAttack:finish()
    self.state = STATE.DONE
    self.boss.isImmobile = false
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "walk", self.boss.unitType)
end

--- Desenha efeitos do ataque.
function ChargingRunAttack:draw()
    -- Não desenha elementos de debug, apenas efeitos visuais no próprio boss
    -- A tonalidade vermelha é aplicada diretamente no enemy_manager durante a renderização
end

--- Retorna se a habilidade terminou.
---@return boolean
function ChargingRunAttack:isDone()
    return self.state == STATE.DONE
end

--- Retorna o tipo da habilidade para identificação.
---@return string
function ChargingRunAttack:getAbilityType()
    return "ChargingRunAttack"
end

return ChargingRunAttack
