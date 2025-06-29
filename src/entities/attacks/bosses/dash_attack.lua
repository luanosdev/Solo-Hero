-------------------------------------------------
--- Dash Attack Ability
-------------------------------------------------
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")

---@class DashAttackParams
---@field telegraphDuration number Duração da animação "taunt" e do aviso.
---@field dashSpeedMultiplier number Multiplicador de velocidade durante o avanço.
---@field stunDuration number Duração do "stun" após o avanço.
---@field range number Alcance fixo do avanço.
---@field damageMultiplier number Multiplicador de dano baseado no dano do boss.
---@field followUpChances table Array de chances para cada follow-up.
---@field followUpRangeIncrease number Multiplicador do aumento do alcance.
---@field followUpStunIncrease number Segundos a adicionar ao stun por follow-up.
---@field telegraphReductionPerFollowUp number|nil Redução do tempo de telegraph por follow-up (padrão: 0.15).
---@field lowHealthSpeedMultiplier number|nil Multiplicador de velocidade quando vida < 50% (padrão: 0.5).

---@class DashAttack
---@field boss BaseBoss
---@field params DashAttackParams
---@field originalParams DashAttackParams
---@field state string
---@field timer number
---@field targetPosition table
---@field dashVector table
---@field isDone boolean
---@field followUpCount number
---@field hitPlayer boolean
local DashAttack = {}
DashAttack.__index = DashAttack

-- Estados da habilidade
local STATE = {
    TELEGRAPH = "telegraph",
    DASHING = "dashing",
    STUNNED = "stunned",
    DONE = "done"
}

--- Constructor
--- @param boss BaseBoss A instância do boss que está usando a habilidade.
--- @param params DashAttackParams Parâmetros da habilidade (damage, telegraphDuration, etc.).
--- @return DashAttack
function DashAttack:new(boss, params)
    local self = setmetatable({}, DashAttack)

    self.boss = boss
    self.originalParams = params
    self.params = {}
    for k, v in pairs(params) do
        self.params[k] = v
    end

    self.state = STATE.TELEGRAPH
    self.timer = 0
    self.targetPosition = nil
    self.dashVector = nil
    self.followUpCount = 0
    self.hitPlayer = false

    return self
end

--- Inicia a habilidade.
--- @param playerManager PlayerManager O gerenciador do jogador.
function DashAttack:start(playerManager)
    self.timer = 0
    self.state = STATE.TELEGRAPH
    self.boss.isImmobile = true
    self.followUpCount = 0
    self.hitPlayer = false

    -- Reseta os parâmetros para os valores originais no início de uma nova sequência.
    self.params.range = self.originalParams.range
    self.params.stunDuration = self.originalParams.stunDuration
    self.params.telegraphDuration = self.originalParams.telegraphDuration

    -- Aplica modificadores baseados no estado do boss
    self:applyBossStateModifiers()

    -- Toca a animação de "taunt"
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "taunt", self.boss.unitType)

    -- Calcula a direção para o jogador para determinar o vetor do dash
    self:calculateDashVector(playerManager)
end

--- Calcula o vetor do dash e a posição alvo.
function DashAttack:calculateDashVector(playerManager)
    local playerPos = playerManager:getCollisionPosition().position
    local dx = playerPos.x - self.boss.position.x
    local dy = playerPos.y - self.boss.position.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        self.dashVector = { x = dx / len, y = dy / len }
    else
        self.dashVector = { x = 1, y = 0 } -- Caso o boss esteja sobre o jogador, avança para a direita
    end

    -- Calcula a posição final do dash com base no alcance
    local dashRange = self.params.range
    self.targetPosition = {
        x = self.boss.position.x + self.dashVector.x * dashRange,
        y = self.boss.position.y + self.dashVector.y * dashRange
    }
end

--- Aplica modificadores baseados no estado atual do boss (vida baixa, etc).
function DashAttack:applyBossStateModifiers()
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
function DashAttack:update(dt, playerManager)
    self.timer = self.timer + dt

    if self.state == STATE.TELEGRAPH then
        if self.timer >= self.params.telegraphDuration then
            self:startDash()
        end
    elseif self.state == STATE.DASHING then
        self:updateDash(dt, playerManager)
    elseif self.state == STATE.STUNNED then
        if self.timer >= self.params.stunDuration then
            self:finish()
        end
    end
end

--- Inicia a fase de avanço.
function DashAttack:startDash()
    self.state = STATE.DASHING
    self.timer = 0
    -- Toca a animação de "run"
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "run", self.boss.unitType)
end

--- Atualiza a lógica do avanço.
--- @param dt number Delta time.
--- @param playerManager PlayerManager O gerenciador do jogador.
function DashAttack:updateDash(dt, playerManager)
    -- Movimenta o boss
    local speed = self.boss.speed * self.params.dashSpeedMultiplier
    self.boss.position.x = self.boss.position.x + self.dashVector.x * speed * dt
    self.boss.position.y = self.boss.position.y + self.dashVector.y * speed * dt

    -- Verifica colisão com o jogador
    if not self.hitPlayer then
        if self.boss:checkPlayerCollisionOptimized(dt, playerManager) then -- Passa `true` para evitar dano duplicado
            self.hitPlayer = true
            local calculatedDamage = self.boss.damage * self.params.damageMultiplier
            local damageSource = {
                name = self.boss.name,
                isBoss = true,
                isMVP = false,
                unitType = self.boss.unitType
            }
            playerManager:receiveDamage(calculatedDamage, damageSource)
        end
    end

    -- Verifica se chegou perto o suficiente do alvo para parar
    local dx = self.targetPosition.x - self.boss.position.x
    local dy = self.targetPosition.y - self.boss.position.y
    if dx * self.dashVector.x + dy * self.dashVector.y <= 0 then
        self:decideNextAction(playerManager)
    end
end

--- Decide a próxima ação: follow-up ou stun.
--- @param playerManager PlayerManager
function DashAttack:decideNextAction(playerManager)
    local chances = self.params.followUpChances or {}
    local maxFollowUps = #chances

    if self.followUpCount < maxFollowUps then
        local chance = chances[self.followUpCount + 1]
        if math.random() < chance then
            self:startFollowUp(playerManager)
            return
        end
    end

    -- Se não houver follow-up, calcula o stun final e inicia o estado.
    local stunIncrease = self.params.followUpStunIncrease or 1
    self.params.stunDuration = self.originalParams.stunDuration + (self.followUpCount * stunIncrease)
    self:startStun()
end

--- Inicia um ataque de follow-up.
--- @param playerManager PlayerManager
function DashAttack:startFollowUp(playerManager)
    self.followUpCount = self.followUpCount + 1

    -- Aumenta o alcance do ataque de forma cumulativa
    local rangeMultiplier = self.params.followUpRangeIncrease or 1.2
    self.params.range = self.params.range * rangeMultiplier

    -- Reduz o tempo de telegraph baseado no número de follow-ups
    local telegraphReduction = self.originalParams.telegraphReductionPerFollowUp or 0.15
    local newTelegraphDuration = self.originalParams.telegraphDuration - (self.followUpCount * telegraphReduction)
    -- Garante um tempo mínimo de telegraph
    self.params.telegraphDuration = math.max(newTelegraphDuration, 0.3)

    -- Aplica modificadores do estado do boss (vida baixa)
    self:applyBossStateModifiers()

    -- Reinicia o estado para um novo ciclo
    self.timer = 0
    self.state = STATE.TELEGRAPH
    self.hitPlayer = false

    AnimatedSpritesheet.setMovementType(self.boss.sprite, "taunt", self.boss.unitType)
    self:calculateDashVector(playerManager)
end

--- Inicia a fase de stun.
function DashAttack:startStun()
    self.state = STATE.STUNNED
    self.timer = 0
    -- Retorna para a animação "walk", que atuará como "idle" enquanto o boss estiver parado.
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "idle", self.boss.unitType)
end

--- Finaliza a habilidade.
function DashAttack:finish()
    self.state = STATE.DONE
    self.boss.isImmobile = false -- Permite que o boss se mova novamente
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "walk", self.boss.unitType)
end

--- Desenha a prévia do ataque.
function DashAttack:draw()
    if self.state == STATE.TELEGRAPH and self.targetPosition then
        love.graphics.setColor(1, 0, 0, 0.2)

        local startX, startY = self.boss.position.x, self.boss.position.y
        local endX, endY = self.targetPosition.x, self.targetPosition.y

        local dx = endX - startX
        local dy = endY - startY
        local angle = math.atan2(dy, dx)
        local length = math.sqrt(dx * dx + dy * dy)
        local width = self.boss.radius * 2

        love.graphics.push()
        love.graphics.translate(startX, startY)
        love.graphics.rotate(angle)
        love.graphics.rectangle("fill", 0, -width / 2, length, width)
        love.graphics.pop()

        love.graphics.setColor(1, 1, 1, 1)
    end
end

--- Retorna se a habilidade terminou.
---@return boolean
function DashAttack:isDone()
    return self.state == STATE.DONE
end

return DashAttack
