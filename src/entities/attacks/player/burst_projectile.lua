--------------------------------------------------------------------------------
-- BurstProjectileAbility
-- Habilidade que dispara múltiplos projéteis de uma só vez em um leque (spread).
-- Ex: Escopetas, arcos de múltiplas flechas.
--------------------------------------------------------------------------------

local BaseProjectileAttack = require("src.entities.attacks.player.base_projectile_attack")

---@class BurstProjectile : BaseProjectileAttack
local BurstProjectile = setmetatable({}, { __index = BaseProjectileAttack })
BurstProjectile.__index = BurstProjectile

--- Cria uma nova instância da habilidade de projétil em rajada.
---@param playerManager PlayerManager
---@param weaponInstance BaseWeapon
---@return BurstProjectile
function BurstProjectile:new(playerManager, weaponInstance)
    local projectileClassPath = "src.entities.projectiles." .. weaponInstance:getBaseData().projectileClass
    local projectileClass = require(projectileClassPath)

    -- Chama o construtor da classe base
    local o = BaseProjectileAttack.new(self, playerManager, weaponInstance, projectileClass)
    setmetatable(o, self) -- Re-estabelece a metatable para a classe filha

    -- Carrega configurações específicas do Burst
    local baseData = o.weaponInstance:getBaseData()
    o.baseAngleWidth = baseData.angle or math.rad(15) -- Ângulo total do leque

    return o
end

--- Atira uma rajada de projéteis.
---@param args table Argumentos de disparo.
---@return boolean success
---@return string reason
function BurstProjectile:cast(args)
    -- 1. Verifica o cooldown na classe base
    local canFire, reason = BaseProjectileAttack.cast(self, args)
    if not canFire then
        return false, reason
    end

    -- 2. Calcula o número de projéteis
    local totalProjectiles = self:_getTotalProjectiles()
    if totalProjectiles <= 0 then
        return false, "no_projectiles"
    end

    -- 3. Calcula os ângulos para cada projétil
    local angles = {}
    local baseAngle = self.currentAngle
    local totalAngleWidth = self.baseAngleWidth * (self.finalStats.attackArea or 1)

    if totalProjectiles == 1 then
        table.insert(angles, baseAngle)
    else
        local angleStep = totalAngleWidth / (totalProjectiles - 1)
        local startAngle = baseAngle - totalAngleWidth / 2
        for i = 0, totalProjectiles - 1 do
            table.insert(angles, startAngle + i * angleStep)
        end
    end

    -- 4. Dispara cada projétil
    for _, fireAngle in ipairs(angles) do
        self:_fireSingleProjectile(fireAngle)
    end

    return true, "fired"
end

return BurstProjectile
