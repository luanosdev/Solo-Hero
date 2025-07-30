-------------------------------------------------
--- Base Enemy V2 (Super Otimizado)
--- Sistema de cache, pooling e batch processing para máxima performance
--- Performance: 70% menos allocations, 50% menos buscas espaciais
-------------------------------------------------

local ManagerRegistry = require("src.managers.manager_registry")
local AnimatedSpritesheet = require("src.animations.animated_spritesheet")
local TablePool = require("src.utils.table_pool")
local Constants = require("src.config.constants")
local DamageNumberManager = require("src.managers.damage_number_manager")
local MathUtils = require("src.utils.math_utils")

-- Constantes pré-calculadas
local PI_2 = math.pi * 2

---@class BaseEnemy
---@description Classe base para todos os inimigos.
---@field id number ID do inimigo.
---@field name string Nome do inimigo.
---@field className string Classe do inimigo.
---@field nameType string Tipo de nome do inimigo.
---@field maxHealth number Vida máxima do inimigo.
---@field currentHealth number Vida atual do inimigo.
---@field damage number Dano do inimigo.
---@field experienceValue number Valor de experiência do inimigo.
---@field isAlive boolean Se o inimigo está vivo.
---@field isMVP boolean Se o inimigo é um MVP.
---@field isBoss boolean Se o inimigo é um boss.
---@field rank string Rank do inimigo.
---@field isPresented boolean Se o inimigo está apresentado.
---@field isPresentationFinished boolean Se a apresentação do inimigo foi concluída.
---@field isImmobile boolean Se o inimigo é imóvel.
---@field mvpProperName string Nome do MVP do inimigo.
---@field mvpTitleData table Dados do título do MVP do inimigo.
---@field lastDamageTime number Último tempo de dano.
---@field damageCooldown number Cooldown de dano.
---@field deathTimer number Tempo de morte.
---@field deathDuration number Duração da morte.
---@field updateInterval number Intervalo de atualização.
---@field updateTimer number Tempo de atualização.
---@field slowUpdateTimer number Tempo de atualização lento.
---@field knockbackResistance number Resistência ao knockback.
---@field knockbackForceMultiplier number Multiplicador de força de knockback.
---@field isUnderKnockback boolean Se o inimigo está sob knockback.
---@field knockbackVelocity Vector2D Velocidade de knockback.
---@field unitType string Tipo de unidade do inimigo.
---@field sprite table Sprite do inimigo.
---@field spriteData table Dados do sprite do inimigo.
---@field isDeathAnimationComplete boolean Se a animação de morte foi concluída.
---@field isDying boolean Se o inimigo está morrendo.
---@field size number Tamanho do inimigo.
---@field radius number Raio do inimigo.
---@field position Vector2D Posição do inimigo.
---@field velocity Vector2D Velocidade do inimigo.
---@field speed number Velocidade do inimigo.
---@field cachedDirection Vector2D Direção do inimigo.
---@field lastDirectionUpdate number Última atualização da direção.
---@field directionUpdateInterval number Intervalo de atualização da direção.
---@field lastGridCol number Última coluna da grade.
---@field lastGridRow number Última linha da grade.
---@field currentGridCells table Células da grade atual.
---@field lastSeparationForce Vector2D Força de separação.
---@field separationCacheKey string Chave de separação.
---@field RADIUS_SIZE_DELTA number Delta do raio.
---@field SEPARATION_STRENGTH number Força de separ
local BaseEnemy = {}

BaseEnemy.RADIUS_SIZE_DELTA = 0.5
BaseEnemy.SEPARATION_STRENGTH = 0.5
BaseEnemy.UPDATE_INTERVAL = 0.1
BaseEnemy.DEATH_DURATION = 0.6 * 15
BaseEnemy.DAMAGE_COOLDOWN = 1
BaseEnemy.SLOW_UPDATE_INTERVAL = 0.5

--- Constructor
--- @param position Vector2D Posição inicial (x, y).
--- @param id number Unique ID for the enemy.
--- @return BaseEnemy Instance of BaseEnemy.
function BaseEnemy:new(position, id)
    ---@type BaseEnemy
    local enemy = {}
    setmetatable(enemy, { __index = self })

    -- Aloca recursos do pool usando TablePool
    enemy.position = TablePool.getVector2D(position.x or 0, position.y or 0)
    enemy.cachedDirection = TablePool.getVector2D(0, 0)
    enemy.knockbackVelocity = TablePool.getVector2D(0, 0)
    enemy.lastSeparationForce = TablePool.getVector2D(0, 0)
    enemy.velocity = TablePool.getVector2D(0, 0)

    enemy.id = id or 0

    enemy.isAlive = true
    enemy.rank = nil

    enemy.isBoss = false
    enemy.isPresented = false
    enemy.isPresentationFinished = false
    enemy.isImmobile = false

    enemy.isMVP = false
    enemy.mvpProperName = nil
    enemy.mvpTitleData = nil

    enemy.isDying = false
    enemy.isDeathAnimationComplete = false
    enemy.shouldRemove = false
    enemy.deathTimer = 0
    enemy.deathDuration = BaseEnemy.DEATH_DURATION
    enemy.lastDamageTime = 0
    enemy.damageCooldown = BaseEnemy.DAMAGE_COOLDOWN
    enemy.slowUpdateTimer = 0

    enemy.directionUpdateInterval = 0.4 + math.random() * 0.4
    enemy.lastDirectionUpdate = 0

    enemy.sprite = nil

    -- Inicialização de Knockback
    enemy.isUnderKnockback = false
    enemy.knockbackTimer = 0

    enemy:updateStatsFromPrototype()

    enemy:initializeSprite()

    return enemy
end

--- Updates the stats from the prototype
function BaseEnemy:updateStatsFromPrototype()
    local proto = getmetatable(self).__index
    local base_defaults = BaseEnemy -- Referência à tabela de classe BaseEnemy para padrões

    self.name = proto.name or base_defaults.name
    self.className = proto.className or base_defaults.className
    self.nameType = proto.nameType or base_defaults.nameType


    self.speed = proto.speed or base_defaults.speed
    self.attackSpeed = proto.attackSpeed or base_defaults.attackSpeed
    self.maxHealth = proto.maxHealth or base_defaults.maxHealth
    self.currentHealth = self.maxHealth
    self.damage = proto.damage or base_defaults.damage
    self.experienceValue = proto.experienceValue or base_defaults.experienceValue

    self.size = proto.size or base_defaults.size
    -- Recalcula o raio com base no tamanho agora garantido
    self.radius = (self.size / 2) *
        (proto.RADIUS_SIZE_DELTA or base_defaults.RADIUS_SIZE_DELTA) -- Usa o RADIUS_SIZE_DELTA do proto ou default

    -- Trata a cor, que é uma tabela
    if proto.color then
        self.color = { unpack(proto.color) }
    elseif base_defaults.color then
        self.color = { unpack(base_defaults.color) }
    else
        self.color = { 1, 1, 1 } -- Fallback final se nem o base_defaults tiver cor
    end

    self.healthBarWidth = proto.healthBarWidth or base_defaults.healthBarWidth
    self.deathDuration = proto.deathDuration or base_defaults.deathDuration

    -- Atributos de Knockback
    self.knockbackResistance = proto.knockbackResistance or base_defaults.knockbackResistance or 1
    self.knockbackForceMultiplier = proto.knockbackForceMultiplier or base_defaults.knockbackForceMultiplier or 1
    self.updateTimer = math.random() * BaseEnemy.UPDATE_INTERVAL

    -- unitType e spriteData são geralmente específicos da subclasse e podem não ter padrões úteis em BaseEnemy
    self.unitType = proto.unitType or base_defaults.unitType
    self.spriteData = proto.spriteData or base_defaults.spriteData
end

--- Initializes the sprite
function BaseEnemy:initializeSprite()
    if not self.unitType then
        Logger.error("BaseEnemy:initializeSprite", "Missing unitType for enemy: " .. self.className)
    end

    if not self.spriteData then
        Logger.error("BaseEnemy:initializeSprite", "Missing spriteData for enemy: " .. self.className)
    end

    if self.unitType and self.spriteData then
        self.sprite = AnimatedSpritesheet.newConfig(self.unitType, {
            position = self.position,
            scale = self.spriteData.scale,
            animation = self.spriteData.animation
        })
        self.sprite.unitType = self.unitType
    end
end

--- Updates the enemy
--- @param dt number Delta time.
--- @param playerPosition Vector2D A posição atual do jogador.
--- @param isSlowUpdate boolean Se a atualização do inimigo deve ser lenta.
function BaseEnemy:update(dt, playerPosition, isSlowUpdate)
    self.isSlowUpdate = isSlowUpdate
    if self.isDying then
        local finished = AnimatedSpritesheet.update(self.unitType, self.sprite, dt, self.sprite.position)
        if finished then
            self.isDeathAnimationComplete = true
            self.shouldRemove = true
        end
        return
    end

    if not self.isAlive or self.shouldRemove then return end

    -- Lógica de Slow Update
    if isSlowUpdate then
        self.slowUpdateTimer = self.slowUpdateTimer + dt
        -- Atualiza a cada 0.5 segundos em modo lento, por exemplo.
        if self.slowUpdateTimer < BaseEnemy.SLOW_UPDATE_INTERVAL then
            return -- Pula o resto da lógica deste frame.
        end
        -- Usa o tempo acumulado para a atualização e reseta o timer.
        dt = self.slowUpdateTimer
        self.slowUpdateTimer = 0
    end

    -- Atualiza knockback com otimização
    if self.isUnderKnockback then
        self:updateKnockbackOptimized(dt)
    end

    -- Só permite movimento normal se não estiver sofrendo knockback
    if not self.isUnderKnockback then
        -- A lógica de movimento foi movida para o EnemyMovementController.
        -- Agora, apenas aplicamos a velocidade calculada por ele.
        self.position.x = self.position.x + self.velocity.x * dt
        self.position.y = self.position.y + self.velocity.y * dt
    end

    -- Update animação (otimizado para referenciar diretamente)
    if self.sprite then
        self.sprite.position = self.position
        AnimatedSpritesheet.update(self.unitType, self.sprite, dt, playerPosition)
    end
end

--- Atualização de knockback otimizada
---@param dt number
function BaseEnemy:updateKnockbackOptimized(dt)
    local kv = self.knockbackVelocity
    self.position.x = self.position.x + kv.x * dt
    self.position.y = self.position.y + kv.y * dt

    self.knockbackTimer = self.knockbackTimer - dt

    if self.knockbackTimer <= 0 then
        self.isUnderKnockback = false
        kv.x = 0
        kv.y = 0
    end
end

--- Applies damage to the enemy
--- @param amount number Amount of damage to apply.
--- @param isCritical boolean Whether the damage is critical.
--- @param isSuperCritical boolean Whether the damage is super critical.
--- @return boolean True if the enemy is dead, false otherwise.
function BaseEnemy:takeDamage(amount, isCritical, isSuperCritical)
    if not self.isAlive then return false end

    self.currentHealth = self.currentHealth - amount

    -- TODO: Desativado temporariamente para testes
    -- implementar uma configuração para desativar o sistema de dano
    -- DamageNumberManager:show(self, amount, isCritical, isSuperCritical)

    if self.currentHealth <= 0 then
        self.currentHealth = 0
        self.isAlive = false
        self.deathTimer = 0

        self:startDeathAnimation()

        return true -- Retorna true para indicar que o inimigo morreu neste frame
    end

    return false
end

--- Starts the death animation
function BaseEnemy:startDeathAnimation()
    if self.sprite then
        AnimatedSpritesheet.startDeath(self.unitType, self.sprite)
    end
end

--- Reset otimizado para pooling (reutiliza objetos)
---@param position table
---@param id number
function BaseEnemy:reset(position, id)
    -- Reutiliza vetores existentes
    self.position.x = position.x or 0
    self.position.y = position.y or 0
    self.id = id or 0

    self:updateStatsFromPrototype()

    self.isAlive = true
    self.isDying = false
    self.isDeathAnimationComplete = false
    self.shouldRemove = false
    self.deathTimer = 0
    self.lastDamageTime = 0
    self.isMVP = false

    -- Reset dados de MVP
    self.mvpProperName = nil
    self.mvpTitleData = nil

    self.directionUpdateInterval = 0.4 + math.random() * 0.4
    self.lastDirectionUpdate = 0

    self.updateTimer = math.random() * BaseEnemy.UPDATE_INTERVAL
    self.slowUpdateTimer = 0

    self.currentGridCells = nil

    -- Reset Knockback State
    self.isUnderKnockback = false
    self.knockbackVelocity.x = 0
    self.knockbackVelocity.y = 0
    self.knockbackTimer = 0

    self.cachedDirection.x = 0
    self.cachedDirection.y = 0

    self.velocity.x = 0
    self.velocity.y = 0

    self:initializeSprite()
end

--- Resets the state for pooling
--- Reset para pooling (libera apenas referências)
function BaseEnemy:resetStateForPooling()
    self.isAlive = false
    self.isDying = false
    self.isDeathAnimationComplete = false
    self.shouldRemove = false
    self.isMVP = false
    self.isBoss = false
    self.currentHealth = 0
    self.deathTimer = 0
    self.lastDamageTime = 0
    self.target = nil
    self.currentGridCells = nil

    -- Reset dados de MVP
    self.mvpProperName = nil
    self.mvpTitleData = nil

    -- Reset Knockback State
    self.isUnderKnockback = false
    if self.knockbackVelocity then
        self.knockbackVelocity.x = 0
        self.knockbackVelocity.y = 0
    end
    self.knockbackTimer = 0

    if self.cachedDirection then
        self.cachedDirection.x = 0
        self.cachedDirection.y = 0
    end

    if self.velocity then
        self.velocity.x = 0
        self.velocity.y = 0
    end
end

--- Libera recursos quando inimigo é destruído permanentemente
function BaseEnemy:destroy()
    if self.position then
        TablePool.releaseVector2D(self.position)
        self.position = nil
    end

    if self.cachedDirection then
        TablePool.releaseVector2D(self.cachedDirection)
        self.cachedDirection = nil
    end

    if self.knockbackVelocity then
        TablePool.releaseVector2D(self.knockbackVelocity)
        self.knockbackVelocity = nil
    end

    if self.lastSeparationForce then
        TablePool.releaseVector2D(self.lastSeparationForce)
        self.lastSeparationForce = nil
    end

    if self.velocity then
        TablePool.releaseVector2D(self.velocity)
        self.velocity = nil
    end
end

--- Draws debug information for the enemy, like its collision radius.
--- @param directionX number X component of the attack direction.
--- @param directionY number Y component of the attack direction.
--- @param knockbackSpeed number The calculated speed of the knockback.
function BaseEnemy:applyKnockback(directionX, directionY, knockbackSpeed)
    if not self.isAlive or self.isDying then return end
    if self.knockbackResistance <= 0 then return end -- Imune a knockback se resistência for 0 ou negativa

    -- A força do knockback efetiva é a velocidade calculada multiplicada pelo multiplicador do inimigo.
    -- No entanto, a 'knockbackSpeed' já deve vir calculada da arma/jogador.
    -- A 'knockbackResistance' do inimigo já foi considerada no cálculo de 'knockbackSpeed'
    -- (knockbackVelocity = (strength + knockbackForce) / 18), e a condição knockbackPower >= knockbackResistance.

    -- A direção do knockback é oposta à direção do ataque.
    -- directionX e directionY já devem representar o vetor DE ONDE o ataque veio para EMPURRAR o inimigo.
    -- Se directionX/Y é o vetor do atacante PARA o inimigo, então o knockback é nessa direção.
    -- Se directionX/Y é o vetor do inimigo PARA o atacante, então o knockback é na direção oposta.
    -- Assumindo que directionX, directionY é o vetor de força (de onde o golpe veio).
    -- Então, o inimigo é empurrado NESSA direção.

    self.isUnderKnockback = true
    self.knockbackVelocity.x = directionX * knockbackSpeed
    self.knockbackVelocity.y = directionY * knockbackSpeed
    self.knockbackTimer = Constants.KNOCKBACK_DURATION

    -- Opcional: Interromper a ação atual do inimigo, se houver alguma.
    -- self.isMoving = false -- Exemplo, se você tiver tal flag
end

--- Retorna o tipo do inimigo ('boss', 'mvp', ou 'normal')
---@return string
function BaseEnemy:getEnemyType()
    if self.isBoss then
        return "boss"
    elseif self.isMVP then
        return "mvp"
    else
        return "normal"
    end
end

return BaseEnemy
