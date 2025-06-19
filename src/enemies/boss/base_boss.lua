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
---@field isPresented boolean
---@field isPresentationFinished boolean
---@field isUnderPresentation boolean
---@field presentationAnimState string
---@field presentationFrameTimer number
---@field presentationPingPongDir number
local BaseBoss = setmetatable({}, { __index = BaseEnemy })

-- Configurações base para todos os bosses
BaseBoss.isBoss = true
BaseBoss.isPresented = false            -- Se a cena de apresentação já foi triggada
BaseBoss.isPresentationFinished = false -- Se a cena de apresentação já terminou
BaseBoss.isUnderPresentation = false    -- Se está ATIVAMENTE na cena de apresentação.
BaseBoss.presentationAnimState = nil    -- Estado da animação durante a apresentação ('idle', 'taunt_once', 'taunt_loop')
BaseBoss.presentationFrameTimer = 0
BaseBoss.presentationPingPongDir = 1

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
    boss.isPresented = false
    boss.isPresentationFinished = false
    boss.isUnderPresentation = false
    boss.presentationAnimState = nil
    boss.presentationFrameTimer = 0
    boss.presentationPingPongDir = 1

    return boss
end

--- Atualiza a lógica do boss.
--- @param dt number Delta time.
--- @param playerManager PlayerManager Manager do jogador.
--- @param enemyManager EnemyManager Manager de inimigos.
function BaseBoss:update(dt, playerManager, enemyManager)
    -- Lógica especial de animação durante a apresentação
    if self.isUnderPresentation then
        local animState = self.sprite.animation
        local TAUNT_FRAMES = 15 -- Suposição sobre o número de frames. Ajuste se necessário.
        local TAUNT_DURATION = 1
        local frameDuration = TAUNT_DURATION / TAUNT_FRAMES

        if self.presentationAnimState == 'idle' then
            AnimatedSpritesheet.setMovementType(self.sprite, 'idle', self.unitType)
            AnimatedSpritesheet.update(self.unitType, self.sprite, dt, nil)
        elseif self.presentationAnimState == 'taunt_once' then
            AnimatedSpritesheet.setMovementType(self.sprite, 'taunt', self.unitType)

            self.presentationFrameTimer = self.presentationFrameTimer + dt
            if self.presentationFrameTimer >= frameDuration then
                self.presentationFrameTimer = self.presentationFrameTimer - frameDuration
                if animState.currentFrame < TAUNT_FRAMES then
                    animState.currentFrame = animState.currentFrame + 1
                end
            end
        elseif self.presentationAnimState == 'taunt_loop' then
            AnimatedSpritesheet.setMovementType(self.sprite, 'taunt', self.unitType)
            self.presentationFrameTimer = self.presentationFrameTimer + dt
            if animState.frameDuration and animState.frameDuration > 0 and self.presentationFrameTimer >= animState.frameDuration then
                self.presentationFrameTimer = self.presentationFrameTimer - animState.frameDuration
                animState.currentFrame = animState.currentFrame + self.presentationPingPongDir
                if animState.currentFrame >= TAUNT_FRAMES then
                    animState.currentFrame = TAUNT_FRAMES
                    self.presentationPingPongDir = -1
                elseif animState.currentFrame <= 1 then
                    animState.currentFrame = 1
                    self.presentationPingPongDir = 1
                end
            end
        end
        return -- Interrompe o update normal durante a apresentação
    end

    if not self.isAlive or self.isDying then
        -- Se estiver morrendo, apenas atualiza a animação de morte
        if self.isDying then
            BaseEnemy.update(self, dt, playerManager, enemyManager, false)
            AnimatedSpritesheet.setMovementType(self.sprite, "taunt", self.unitType)
            self.isImmobile = true
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
            elseif playerManager.player and playerManager.player.isAlive then
                targetPos = playerManager.player.position
            end
            AnimatedSpritesheet.update(self.unitType, self.sprite, dt, targetPos)
        end
    elseif self.bossState == BOSS_STATE.CHASING then
        -- Atualiza o timer de habilidades
        self.abilityTimer = self.abilityTimer + dt

        -- Verifica se pode usar uma habilidade (só ataca após a apresentação)
        if self.isPresentationFinished and self.abilityTimer >= self.abilityCooldown then
            self:useAbility(playerManager)
        end

        -- Chama o update da classe base para movimento e colisão
        if not self.isImmobile then
            BaseEnemy.update(self, dt, playerManager, enemyManager, false)
        end
    end
end

--- Ativa a animação de provocação (taunt) do boss.
function BaseBoss:taunt()
    AnimatedSpritesheet.setMovementType(self.sprite, "taunt", self.unitType)
    self.isImmobile = true
end

--- Usa uma habilidade do boss.
--- @param playerManager table Manager do jogador.
function BaseBoss:useAbility(playerManager)
    if not self.abilities or #self.abilities == 0 then return end

    -- TODO: Implementar seleção de habilidade baseada em peso. Por agora, usa a próxima da lista.
    local ability_data = self.abilities[self.currentAbilityIndex]

    if not ability_data then return end

    -- Verifica a distância mínima, se especificada
    local playerPos = playerManager:getCollisionPosition().position
    local distanceToPlayer = math.sqrt((self.position.x - playerPos.x) ^ 2 + (self.position.y - playerPos.y) ^ 2)

    if ability_data.params and distanceToPlayer > ability_data.params.range then
        -- O jogador está muito longe para esta habilidade, então o boss continua a perseguição
        return
    end

    if ability_data.classPath then
        local AbilityClass = require(ability_data.classPath)
        if AbilityClass then
            -- Passa a tabela de parâmetros diretamente
            local params = ability_data.params or {}

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
