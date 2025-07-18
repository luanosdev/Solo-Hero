----------------------------------------------------------------------------
-- Base Attack Ability
-- Classe base unificada para todas as habilidades de ataque.
-- Centraliza cache, cooldown, multi-attack e lógica comum para máxima performance.
----------------------------------------------------------------------------

local SpritePlayer = require("src.animations.sprite_player")
local Colors = require("src.ui.colors")

---@class BaseAttackAbilityVisual
---@field preview { active: boolean, lineLength: number, color: table }
---@field attack AlternatingConeStrikeVisualAttack|CircularSmashVisualAttack|ConeVisualAttack|FlameStreamVisualAttack|SpreadProjectileVisualAttack|SequentialProjectileVisualAttack|ChainLightningVisualAttack

---@class BaseAttackAbility
---@field playerManager PlayerManager
---@field weaponInstance BaseWeapon
---@field attackType string "melee"|"ranged"|"area"|"projectile"
---@field cooldownRemaining number
---@field cachedStats FinalStats
---@field cachedBaseData CircularSmashWeapon|ConeSlashWeapon|FlameStreamWeapon|SpreadProjectileWeapon|SequentialProjectileWeapon|ChainLightningWeapon
---@field lastStatsUpdateTime number
---@field playerPosition Vector2D
---@field knockbackData KnockbackData
---@field visual BaseAttackAbilityVisual
---@field currentAngle number
---@field name string
---@field description string
---@field damageType string
local BaseAttackAbility = {}
BaseAttackAbility.__index = BaseAttackAbility

-- Constantes globais de otimização
local STATS_CACHE_TIME = 0.1
local MIN_ATTACK_SPEED = 0.01

---@class AttackConfig
---@field name string
---@field description string
---@field damageType string
---@field attackType string
---@field visual BaseAttackAbilityVisual?
---@field constants table

--- Cria nova instância da classe base
---@generic W : BaseWeapon|CircularSmashWeapon|ConeSlashWeapon|FlameStreamWeapon|SpreadProjectileWeapon|SequentialProjectileWeapon|ChainLightningWeapon
---@param playerManager PlayerManager
---@param weaponInstance W
---@param config AttackConfig
---@return BaseAttackAbility
function BaseAttackAbility:new(playerManager, weaponInstance, config)
    local o = setmetatable({}, self)

    if not playerManager or not weaponInstance then
        error("BaseAttackAbility:new - playerManager e weaponInstance são obrigatórios.")
    end

    o.playerManager = playerManager
    o.weaponInstance = weaponInstance
    o.attackType = config.attackType or "melee"

    -- Cache otimizado de dados da arma (imutável durante o jogo)
    o.cachedBaseData = weaponInstance:getBaseData()
    if not o.cachedBaseData then
        error("BaseAttackAbility:new - BaseData não encontrado.")
    end

    -- Cache de stats (mutável, throttled)
    o.cachedStats = nil
    o.lastStatsUpdateTime = 0
    o.playerPosition = { x = 0, y = 0 } -- Reutiliza a mesma tabela

    -- Pre-aloca tabela de knockback para reutilização
    o.knockbackData = {
        power = o.cachedBaseData.knockbackPower or 0,
        force = o.cachedBaseData.knockbackForce or 0,
        attackerPosition = o.playerPosition -- Referência direta
    }

    o.cooldownRemaining = 0
    o.currentAngle = 0

    -- Configurações da habilidade
    o.name = config.name
    o.description = config.description
    o.damageType = config.damageType
    o.visual = config.visual or {}

    return o
end

--- Sistema de cache unificado e otimizado
---@param currentTime number Tempo atual
function BaseAttackAbility:updateCaches(currentTime)
    -- Atualiza posição do jogador (sempre necessário)
    local newPos = self.playerManager:getPlayerPosition()
    self.playerPosition.x = newPos.x
    self.playerPosition.y = newPos.y

    -- Throttled stats update (apenas se necessário)
    if not self.cachedStats or (currentTime - self.lastStatsUpdateTime) > STATS_CACHE_TIME then
        self.cachedStats = self.playerManager:getCurrentFinalStats()
        self.lastStatsUpdateTime = currentTime
        self:onStatsUpdated() -- Hook para subclasses
    end
end

--- Hook para subclasses reagirem a mudanças de stats
--- Implementado pelas subclasses quando necessário
function BaseAttackAbility:onStatsUpdated()
    -- Implementado pelas subclasses
end

--- Sistema de cooldown unificado e otimizado
function BaseAttackAbility:applyCooldown()
    local baseCooldown = self.cachedBaseData.cooldown or 1.0
    local attackSpeed = math.max(self.cachedStats.attackSpeed, MIN_ATTACK_SPEED)
    self.cooldownRemaining = baseCooldown / attackSpeed
end

--- Sistema de multi-attack unificado
---@return number totalAttacks, number extraAttacks, number decimalChance
function BaseAttackAbility:calculateMultiAttacks()
    local multiAttackChance = self.cachedStats.multiAttackChance or 0
    local extraAttacks = math.floor(multiAttackChance)
    local decimalChance = multiAttackChance - extraAttacks

    local totalAttacks = 1 + extraAttacks
    if decimalChance > 0 and math.random() < decimalChance then
        totalAttacks = totalAttacks + 1
    end

    return totalAttacks, extraAttacks, decimalChance
end

--- Update base unificado
---@param dt number Delta time
---@param angle number Ângulo atual da mira
function BaseAttackAbility:update(dt, angle)
    -- Cooldown update
    if self.cooldownRemaining > 0 then
        self.cooldownRemaining = self.cooldownRemaining - dt
    end

    -- Cache update otimizado
    self:updateCaches(love.timer.getTime())
    self.currentAngle = angle

    -- Hook para lógica específica da subclasse
    self:updateSpecific(dt, angle)
end

--- Cast base unificado
---@param args table Argumentos do cast
---@return boolean success
function BaseAttackAbility:cast(args)
    if self.cooldownRemaining > 0 then
        return false
    end

    -- Garante stats atualizados para o cast
    if not self.cachedStats then
        self.cachedStats = self.playerManager:getCurrentFinalStats()
    end

    -- Dispara animação de ataque no sprite do player
    self:triggerPlayerAttackAnimation()

    self:applyCooldown()
    return self:castSpecific(args) -- Implementado pelas subclasses
end

--- Dispara animação de ataque do player se um PlayerManager existir
function BaseAttackAbility:triggerPlayerAttackAnimation()
    -- Verifica se o player está se movendo
    local movementController = self.playerManager.movementController
    local isMoving = false
    if movementController then
        local velocity = movementController:getVelocity()
        isMoving = (math.abs(velocity.x) > 1 or math.abs(velocity.y) > 1)
    end

    -- Obtém dados da arma equipada
    local weaponController = self.playerManager.weaponController
    local equippedWeapon = weaponController and weaponController:getEquippedWeapon()
    local animationType = "melee" -- padrão

    if equippedWeapon then
        animationType = equippedWeapon:getBaseData().animationType or "melee"
    end

    -- Dispara animação do sprite do player
    local spriteConfig = movementController and movementController.player
    if spriteConfig then
        SpritePlayer.startAttackAnimation(spriteConfig, animationType, isMoving)

        Logger.debug(
            "base_attack_ability.trigger_animation",
            string.format(
                "Animação de ataque disparada: tipo=%s, movendo=%s",
                animationType, tostring(isMoving)
            )
        )
    end
end

-- Hooks abstratos (implementados pelas subclasses)
--- Hook para update específico da subclasse
---@param dt number Delta time
---@param angle number Ângulo atual
function BaseAttackAbility:updateSpecific(dt, angle)
    -- Implementado pelas subclasses
end

--- Hook para cast específico da subclasse
---@param args table Argumentos do cast
---@return boolean success
function BaseAttackAbility:castSpecific(args)
    -- Implementado pelas subclasses
    return true
end

--- Hook para desenho específico da subclasse
function BaseAttackAbility:draw()
    -- Implementado pelas subclasses
end

function BaseAttackAbility:drawPreviewOptimized()
    if not self.playerPosition then return end

    local maxLineLength = 300
    local spawnPos = self:calculateSpawnPosition(self.currentAngle)

    love.graphics.setColor(Colors.white)

    local cx, cy = spawnPos.x, spawnPos.y

    -- Linha central
    local endX = cx + math.cos(self.currentAngle) * maxLineLength
    local endY = cy + math.sin(self.currentAngle) * maxLineLength
    love.graphics.setLineWidth(2)
    love.graphics.line(cx, cy, endX, endY)
    love.graphics.setLineWidth(1)
end

-- Utilitários comuns
function BaseAttackAbility:getCooldownRemaining()
    return self.cooldownRemaining or 0
end

function BaseAttackAbility:togglePreview()
    if self.visual.preview then
        self.visual.preview.active = not self.visual.preview.active
    end
end

function BaseAttackAbility:getPreview()
    return self.visual.preview and self.visual.preview.active or false
end

--- Calcula posição de spawn do ataque, considerando raio do player + offset
---@param angle number Ângulo do ataque
---@return Vector2D spawnPosition
function BaseAttackAbility:calculateSpawnPosition(angle)
    local offset = 10

    -- Obtém raio do player do movementController
    local playerRadius = 15 -- Valor padrão
    if self.playerManager.movementController then
        playerRadius = self.playerManager.movementController.radius
    end

    -- Calcula distância total do centro do player
    local spawnDistance = playerRadius + offset

    -- Calcula posição de spawn
    local spawnX = self.playerPosition.x + math.cos(angle) * spawnDistance
    local spawnY = self.playerPosition.y + math.sin(angle) * spawnDistance

    return { x = spawnX, y = spawnY }
end

return BaseAttackAbility
