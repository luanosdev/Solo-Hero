-------------------------------------------------
--- Dash Attack Ability
-------------------------------------------------
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")

---@class DashAttackParams
---@field telegraphDuration number Duração da animação "taunt" e do aviso.
---@field dashSpeedMultiplier number Multiplicador de velocidade durante o avanço.
---@field stunDuration number Duração do "stun" após o avanço.
---@field range number Alcance fixo do avanço.
---@field damage number Dano da habilidade.

---@class DashAttack
---@field boss BaseBoss
---@field params DashAttackParams
---@field state string
---@field timer number
---@field targetPosition table
---@field dashVector table
---@field isDone boolean
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
    self.params = params
    self.state = STATE.TELEGRAPH
    self.timer = 0

    -- Alvo inicial
    self.targetPosition = nil
    self.dashVector = nil

    return self
end

--- Inicia a habilidade.
--- @param playerManager PlayerManager O gerenciador do jogador.
function DashAttack:start(playerManager)
    self.timer = 0
    self.state = STATE.TELEGRAPH
    self.boss.isImmobile = true -- Impede o movimento normal do boss

    -- Toca a animação de "taunt"
    AnimatedSpritesheet.setMovementType(self.boss.sprite, "taunt", self.boss.unitType)

    -- Calcula a direção para o jogador para determinar o vetor do dash
    local playerPos = playerManager:getCollisionPosition().position
    local dx = playerPos.x - self.boss.position.x
    local dy = playerPos.y - self.boss.position.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        self.dashVector = { x = dx / len, y = dy / len }
    else
        self.dashVector = { x = 1, y = 0 } -- Caso o boss esteja sobre o jogador, avança para a direita
    end

    -- Calcula a posição final do dash com base no alcance fixo
    local dashRange = self.params.range or 500 -- Usa o parâmetro ou um fallback
    self.targetPosition = {
        x = self.boss.position.x + self.dashVector.x * dashRange,
        y = self.boss.position.y + self.dashVector.y * dashRange
    }
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
    -- Temporariamente aumenta o dano do boss para o dano da habilidade
    local baseBossDamage = self.boss.damage
    self.boss.damage = self.params.damage
    self.boss:checkPlayerCollision(dt, playerManager) -- Reutilizando a colisão padrão
    self.boss.damage = baseBossDamage

    -- Verifica se chegou perto o suficiente do alvo para parar
    local dx = self.targetPosition.x - self.boss.position.x
    local dy = self.targetPosition.y - self.boss.position.y
    if dx * self.dashVector.x + dy * self.dashVector.y <= 0 then
        self:startStun()
    end
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
