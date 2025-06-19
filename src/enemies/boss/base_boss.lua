-------------------------------------------------
--- Base Boss
-------------------------------------------------
local BaseEnemy = require("src.enemies.base_enemy")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")

-- Estados do Boss
local BOSS_STATE = {
    CHASING = "chasing",
    CASTING = "casting",
}

---@class BaseBoss : BaseEnemy
---@field isBoss boolean
---@field abilities table
---@field currentAbilityIndex number
---@field abilityCooldown number
---@field abilityTimer number
---@field bossState string
---@field currentAbility table
local BaseBoss = setmetatable({}, { __index = BaseEnemy })

-- Configurações base para todos os bosses
BaseBoss.isBoss = true

-- Sistema de habilidades
BaseBoss.abilities = {}          -- Tabela de habilidades do boss
BaseBoss.currentAbilityIndex = 1 -- Índice da habilidade atual
BaseBoss.abilityCooldown = 0     -- Cooldown entre habilidades
BaseBoss.abilityTimer = 0        -- Timer para controle de habilidades

--- Constructor
--- @param position table Posição inicial {x, y}.
--- @param id number | string ID único do boss.
--- @return BaseBoss
function BaseBoss:new(position, id)
    ---@type BaseBoss
    local boss = BaseEnemy.new(self, position, id)
    setmetatable(boss, { __index = self })

    -- Inicializa o sistema de habilidades
    boss.abilityTimer = math.random() * boss.abilityCooldown
    boss.currentAbilityIndex = 1
    boss.bossState = BOSS_STATE.CHASING
    boss.currentAbility = nil

    return boss
end

--- Atualiza a lógica do boss.
--- @param dt number Delta time.
--- @param playerManager PlayerManager Manager do jogador.
--- @param enemyManager EnemyManager Manager de inimigos.
function BaseBoss:update(dt, playerManager, enemyManager)
    if not self.isAlive or self.isDying then
        -- Se estiver morrendo, apenas atualiza a animação de morte
        if self.isDying then
            BaseEnemy.update(self, dt, playerManager, enemyManager, false)
        end
        return
    end

    if self.bossState == BOSS_STATE.CASTING then
        -- Se estiver usando uma habilidade, delega o update para ela
        if self.currentAbility and not self.currentAbility:isDone() then
            self.currentAbility:update(dt, playerManager)
        else
            -- Habilidade terminou, volta a perseguir
            self.currentAbility = nil
            self.bossState = BOSS_STATE.CHASING
            self.abilityTimer = 0 -- Reseta o timer para o cooldown
        end

        -- Enquanto está usando uma habilidade, a animação ainda precisa ser atualizada,
        -- já que o BaseEnemy.update() não é chamado.
        if self.sprite then
            local targetPos = nil
            -- Se a habilidade em andamento define um alvo, a animação deve usá-lo.
            if self.currentAbility and self.currentAbility.targetPosition then
                targetPos = self.currentAbility.targetPosition
            elseif playerManager.player and playerManager.state.isAlive then
                targetPos = playerManager.player.position
            end
            AnimatedSpritesheet.update(self.unitType, self.sprite, dt, targetPos)
        end
    elseif self.bossState == BOSS_STATE.CHASING then
        -- Atualiza o timer de habilidades
        self.abilityTimer = self.abilityTimer + dt

        -- Verifica se pode usar uma habilidade
        if self.abilityTimer >= self.abilityCooldown then
            self:useAbility(playerManager)
        end

        -- Chama o update da classe base para movimento e colisão
        if not self.isImmobile then
            BaseEnemy.update(self, dt, playerManager, enemyManager, false)
        end
    end
end

--- Usa uma habilidade do boss.
--- @param playerManager table Manager do jogador.
function BaseBoss:useAbility(playerManager)
    if not self.abilities or #self.abilities == 0 then return end

    -- TODO: Implementar seleção de habilidade baseada em peso. Por agora, usa a próxima da lista.
    local ability_data = self.abilities[self.currentAbilityIndex]

    if ability_data and ability_data.classPath then
        local AbilityClass = require(ability_data.classPath)
        if AbilityClass then
            local params = table.copy(ability_data.params or {})
            params.damage = ability_data.damage -- Adiciona o dano aos parâmetros

            self.currentAbility = AbilityClass:new(self, params)
            self.currentAbility:start(playerManager)
            self.bossState = BOSS_STATE.CASTING

            -- Avança para a próxima habilidade
            self.currentAbilityIndex = (self.currentAbilityIndex % #self.abilities) + 1
        end
    end
end

--- Desenha elementos do boss (como a prévia de habilidades)
function BaseBoss:draw()
    if self.bossState == BOSS_STATE.CASTING and self.currentAbility and self.currentAbility.draw then
        self.currentAbility:draw()
    end
end

return BaseBoss
