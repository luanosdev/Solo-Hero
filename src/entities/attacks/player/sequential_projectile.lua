--------------------------------------------------------------------------------
-- SequentialProjectileAbility
-- Habilidade que dispara múltiplos projéteis em sequência após um único comando.
-- Ex: Rifles de rajada, varinhas mágicas que disparam 3 orbes.
--------------------------------------------------------------------------------

local BaseProjectileAttack = require("src.entities.attacks.player.base_projectile_attack")

---@class SequentialProjectile : BaseProjectileAttack
---@field isSequenceActive boolean Se uma sequência de disparos está em andamento.
---@field projectilesLeftInSequence number Quantos projéteis ainda faltam na sequência.
---@field timeToNextShot number Temporizador para o próximo disparo na sequência.
---@field sequenceCadence number O tempo entre disparos na sequência.
local SequentialProjectile = setmetatable({}, { __index = BaseProjectileAttack })
SequentialProjectile.__index = SequentialProjectile
SequentialProjectile.name = "Disparo de Projéteis"
SequentialProjectile.description = "Dispara múltiplos projéteis em sequência."
SequentialProjectile.damageType = "melee"

--- Cria uma nova instância da habilidade de projétil sequencial.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon
---@return SequentialProjectile
function SequentialProjectile:new(playerManager, weaponInstance)
    local projectileClassPath = "src.entities.projectiles." .. weaponInstance:getBaseData().projectileClass
    local projectileClass = require(projectileClassPath)

    local o = BaseProjectileAttack.new(self, playerManager, weaponInstance, projectileClass)
    setmetatable(o, self)

    local baseData = o.weaponInstance:getBaseData()
    -- Cadence: tempo entre os disparos da sequência. Valor baixo = alta cadência.
    o.sequenceCadence = baseData.cadence or 0.1

    o.isSequenceActive = false
    o.projectilesLeftInSequence = 0
    o.timeToNextShot = 0

    return o
end

--- Inicia a sequência de disparos.
---@param args table Argumentos de disparo.
function SequentialProjectile:cast(args)
    -- Não pode iniciar uma nova sequência se outra já estiver ativa.
    if self.isSequenceActive then
        return false, "sequence_active"
    end

    -- 1. Verifica o cooldown principal na classe base.
    local canFire, reason = BaseProjectileAttack.cast(self, args)
    if not canFire then
        return false, reason
    end

    -- 2. Inicia a sequência.
    self.isSequenceActive = true
    self.projectilesLeftInSequence = self:_getTotalProjectiles()
    self.timeToNextShot = 0 -- O primeiro tiro é imediato.

    return true, "sequence_started"
end

--- Atualiza a habilidade, gerenciando a sequência de disparos.
---@param dt number Delta time.
---@param angle number Ângulo atual (da mira).
function SequentialProjectile:update(dt, angle)
    -- Chama o update da classe base para gerenciar cooldown principal e projéteis.
    BaseProjectileAttack.update(self, dt, angle)

    -- Gerencia a lógica da sequência.
    if self.isSequenceActive then
        self.timeToNextShot = self.timeToNextShot - dt

        if self.timeToNextShot <= 0 then
            if self.projectilesLeftInSequence > 0 then
                -- Dispara um projétil na direção ATUAL da mira.
                self:_fireSingleProjectile(self.currentAngle)

                self.projectilesLeftInSequence = self.projectilesLeftInSequence - 1
                self.timeToNextShot = self.sequenceCadence -- Reseta o timer para o próximo.
            else
                -- Termina a sequência se acabaram os projéteis.
                self.isSequenceActive = false
            end
        end
    end
end

return SequentialProjectile
